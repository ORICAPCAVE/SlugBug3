//
//  SessionVM.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 9/30/25.
//
import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import GoogleSignIn
import Combine
import Network

@MainActor
final class SessionVM: ObservableObject {
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
    
    // MARK: - Private
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let dbRoot = Database.database().reference()
    @Published var isRTDBConnected = false
    private var rtdbConnectedHandle: DatabaseHandle?
    private let connectedRef = Database.database().reference(withPath: ".info/connected")
    
    // MARK: - Init / Deinit
    init() {
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

    // MARK: - Helper runner
    private func run(_ op: @escaping () async throws -> Void) async {
        self.errorMessage = nil
        self.isLoading = true
        defer { self.isLoading = false }
        do { try await op() }
        catch { self.errorMessage = map(error) }
    }

    /// Destructive: requires recent login
    func deleteAccount() async {
        guard let u = Auth.auth().currentUser else { return }
        await run { try await u.delete() }
    }

    // MARK: - Error mapping
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
