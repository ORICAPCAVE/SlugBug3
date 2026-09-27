//
//  SessionVM.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 9/30/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import GoogleSignIn
import Combine
import Network
import AuthenticationServices
import CryptoKit

@MainActor
final class SessionVM: NSObject, ObservableObject {
    // MARK: - Published UI state
    @Published var user: FirebaseAuth.User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var emailVerified = false
    @Published var canUseApp = false
    
    // Derivatives
    var uid: String? { user?.uid }
    var displayEmail: String { user?.email ?? "" }
    var isAuthenticated: Bool { user != nil }
    var currentSignInProvider: String? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }

        return user.providerData
            .map { $0.providerID }
            .first { $0 != "firebase" }
    }
    
    // MARK: - Private
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let dbRoot = Database.database().reference()
    @Published var isRTDBConnected = false
    private var rtdbConnectedHandle: DatabaseHandle?
    private let connectedRef = Database.database().reference(withPath: ".info/connected")
    private var appleReauthNonce: String?
    private var appleReauthContinuation: CheckedContinuation<Bool, Never>?
    private var appleAuthorizationCode: String?
    
    
    // MARK: - Init / Deinit
    override init() {
        super .init()
        // Single global auth state listener
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print(" Auth state changed: \(user?.uid ?? "nil")")
            Task { await self?.handleAuthChange(user) }
        }
        rtdbConnectedHandle = connectedRef.observe(.value) { [weak self] snap in
            let connected = (snap.value as? Bool) ?? false
            print("RTDB connected =", connected)
            Task { @MainActor in self?.isRTDBConnected = connected }
        }
    }
    deinit {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: - Core Handlers
    @MainActor
    private func handleAuthChange(_ user: FirebaseAuth.User?) async {
        
        let previous = self
        self.user = user
        self.errorMessage = nil
        guard let u = user else {
            self.emailVerified = false
            self.canUseApp = false
            return
            
        }

        // Refresh verification/claims
        do { try await u.reload() } catch { /* non-fatal */ }
        self.emailVerified = u.isEmailVerified

        // Gate if you want: canUseApp = emailVerified
        self.canUseApp = true

        // Ensure profile node exists in RTDB
        do {
            try await ensureUserBootstrap(uid: u.uid, email: u.email)
        } catch {
            self.errorMessage = map(error)
        }
    }

    private func ensureUserBootstrap(uid: String, email: String?) async throws {
        let userRef = dbRoot.child("users").child(uid).child("profile")
        let snap = try await userRef.getData()
        let now = Int(Date().timeIntervalSince1970 * 1000)

        if !snap.exists() {
            var payload: [String: Any] = ["createdAt": now, "updatedAt": now]
            if let email = email { payload["email"] = email }
            try await userRef.setValue(payload)
        } else {
            try await userRef.updateChildValues(["updatedAt": now])
        }
    }

    // MARK: - Public Auth API
    func signIn(email: String, password: String) async {
        await run {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }
    

    func register(email: String, password: String) async {
        await run {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await result.user.sendEmailVerification()
        }
    }

    func sendPasswordReset(email: String) async {
        await run { try await Auth.auth().sendPasswordReset(withEmail: email) }
    }

    func sendVerificationEmail() async {
        guard let u = Auth.auth().currentUser else { return }
        await run { try await u.sendEmailVerification() }
    }

    func reloadUser() async {
        guard let u = Auth.auth().currentUser else { return }
        await run {
            try await u.reload()
            self.emailVerified = u.isEmailVerified
        }
    }

    /// Logs out of Firebase & Google; optionally reset Landing.
    func signOut(resetLanding: Bool = false) {
        do { try Auth.auth().signOut() }
        catch { self.errorMessage = map(error) }

        GIDSignIn.sharedInstance.signOut()

        // Clear local state immediately (UI flips right away)
        self.user = nil
        self.emailVerified = false
        self.canUseApp = false
        self.isLoading = false

        if resetLanding {
            UserDefaults.standard.set(false, forKey: "didDismissLanding")
        }
    }
    func reauthenticate(password: String) async -> Bool {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "Unable to identify the current user."
            return false
        }
        

        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )

        do {
            try await user.reauthenticate(with: credential)
            errorMessage = nil
            print("✅ ACCOUNT DELETE: reauthentication successful")
            return true
        } catch {
            errorMessage = mapAuthError(error)
            print("❌ ACCOUNT DELETE: reauthentication failed:", error)
            return false
        }
    }
    func reauthenticateWithApple() async -> Bool {
        guard Auth.auth().currentUser != nil else {
            errorMessage = "No signed-in account was found."
            return false
        }

        let nonce = randomNonceString()
        appleReauthNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()

        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(
            authorizationRequests: [request]
        )

        controller.delegate = self

        return await withCheckedContinuation { continuation in
            appleReauthContinuation = continuation
            controller.performRequests()
        }
    }
    func reauthenticateWithGoogle(presenter: UIViewController) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No signed-in account was found."
            return false
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter
            )

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Unable to obtain Google ID token."
                return false
            }

            let accessToken = result.user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            try await user.reauthenticate(with: credential)

            print("✅ ACCOUNT DELETE: Google reauthentication successful")
            errorMessage = nil
            return true

        } catch {
            print("❌ ACCOUNT DELETE: Google reauthentication failed:", error)
            errorMessage = mapAuthError(error)
            return false
        }
    }
    // MARK: - Helper runner
    private func run(_ op: @escaping () async throws -> Void) async {
        self.errorMessage = nil
        self.isLoading = true
        defer { self.isLoading = false }
        do { try await op() }
        catch { self.errorMessage = map(error) }
    }

    /// Destructive: requires recent login
    /// Permanently deletes the user's RTDB data and Firebase account.
    /// Firebase may require the user to have signed in recently.
    func deleteAccount() async {
        guard let u = Auth.auth().currentUser else {
            errorMessage = "No signed-in account was found."
            return
        }

        let uid = u.uid

        await run {
            // 1. Delete this user's uploaded photos from Firebase Storage.
            try await self.deleteStoredPhotos(for: uid)

            // 2. Remove this user's data from Realtime Database.
            try await self.dbRoot
                .child("users")
                .child(uid)
                .removeValue()
            
            // Revoke Apple authorization before deleting Firebase Auth.
            if self.currentSignInProvider == "apple.com",
               let authorizationCode = self.appleAuthorizationCode {

                print("🗑️ ACCOUNT DELETE: revoking Apple authorization")

                try await Auth.auth().revokeToken(
                    withAuthorizationCode: authorizationCode
                )

                print("✅ ACCOUNT DELETE: Apple authorization revoked")

                self.appleAuthorizationCode = nil
            }            // 3. Delete the Firebase Authentication account.
            
            print("🗑️ ACCOUNT DELETE: attempting Firebase Auth deletion")

            do {
                try await u.delete()
                print("✅ ACCOUNT DELETE: Firebase Auth user deleted")
            } catch {
                print("❌ ACCOUNT DELETE: Firebase Auth deletion failed")
                print("❌ Error:", error)
                throw error
            }
          

            // 4. Sign out of Google if it was used.
            GIDSignIn.sharedInstance.signOut()

            // 5. Reset the landing screen.
            UserDefaults.standard.set(false, forKey: "didDismissLanding")
        }
    }
    private func deleteStoredPhotos(for uid: String) async throws {
        let photosRef = Storage.storage().reference()
            .child("users")
            .child(uid)
            .child("photos")

        print("🗑️ ACCOUNT DELETE: listing Storage path:", photosRef.fullPath)

        let result = try await photosRef.listAll()

        print("🗑️ ACCOUNT DELETE: found \(result.items.count) photo(s)")

        for item in result.items {
            print("🗑️ ACCOUNT DELETE: deleting:", item.fullPath)

            try await item.delete()

            print("✅ ACCOUNT DELETE: deleted:", item.fullPath)
        }

        print("✅ ACCOUNT DELETE: Storage cleanup finished")
    }
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)

        let charset =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0

            let errorCode = SecRandomCopyBytes(
                kSecRandomDefault,
                1,
                &random
            )

            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce.")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }    // MARK: - Error mapping
    func mapAuthError(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: ns.code) else {
            return ns.localizedDescription
        }
        switch code {
        case .invalidEmail:        return "That email address looks invalid."
        case .userDisabled:        return "This account has been disabled."
        case .wrongPassword:       return "Incorrect password. Try again."
        case .userNotFound:        return "No account found for that email."
        case .emailAlreadyInUse:   return "That email is already in use."
        case .weakPassword:        return "Please choose a stronger password."
        case .requiresRecentLogin: return "Please sign in again to continue."
        case .networkError:        return "Network error. Check your connection."
        default:                   return ns.localizedDescription
        }
    }

    private func map(_ error: Error) -> String {
        mapAuthError(error)
    }
}
extension SessionVM: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleCredential =
                authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = appleReauthNonce,
              let appleIDToken = appleCredential.identityToken,
              let idTokenString =
                String(data: appleIDToken, encoding: .utf8),
              let user = Auth.auth().currentUser else {

            errorMessage = "Unable to reauthenticate with Apple."
            appleReauthNonce = nil

            appleReauthContinuation?.resume(returning: false)
            appleReauthContinuation = nil
            return
        }
        
        // ADD IT HERE
        if let authorizationCode = appleCredential.authorizationCode,
           let codeString = String(
               data: authorizationCode,
               encoding: .utf8
           ) {

            appleAuthorizationCode = codeString
            print("✅ ACCOUNT DELETE: Apple authorization code received")
        } else {
            appleAuthorizationCode = nil
            print("⚠️ ACCOUNT DELETE: No Apple authorization code received")
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        Task {
            do {
                try await user.reauthenticate(with: credential)

                print("✅ ACCOUNT DELETE: Apple reauthentication successful")
                errorMessage = nil

                appleReauthContinuation?.resume(returning: true)

            } catch {
                print("❌ ACCOUNT DELETE: Apple reauthentication failed:", error)
                errorMessage = mapAuthError(error)

                appleReauthContinuation?.resume(returning: false)
            }

            appleReauthNonce = nil
            appleReauthContinuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("❌ ACCOUNT DELETE: Apple authorization failed:", error)

        let nsError = error as NSError

        if nsError.code != ASAuthorizationError.canceled.rawValue {
            errorMessage = error.localizedDescription
        }

        appleReauthNonce = nil

        appleReauthContinuation?.resume(returning: false)
        appleReauthContinuation = nil
    }
}
