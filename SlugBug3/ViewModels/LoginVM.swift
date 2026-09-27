//
//  LoginVm.swift
//  SlugBug3
//
//  Created by Kevin Leckenby on 10/2/25.
//
import Foundation
import FirebaseAuth
import GoogleSignIn
import Combine
import AuthenticationServices
import CryptoKit


@MainActor
final class LoginVM: NSObject, ObservableObject {
    // MARK: - Inputs
    @Published var email: String = ""
    @Published var password: String = ""

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?

    // Simple form validation
    var canSubmitEmail: Bool { !email.isEmpty && !password.isEmpty }

    // MARK: - Actions

    /// Email + password sign-in. SessionVM's auth listener will flip the UI.
    func signInEmail() async {
        guard canSubmitEmail else {
            errorMessage = "Enter your email and password."
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    /// Register a new account, then sends verification email.
    func register() async {
        guard canSubmitEmail else {
            errorMessage = "Enter your email and a stronger password."
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await result.user.sendEmailVerification()
            errorMessage = "Verification email sent. Please check your inbox."
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    /// Sends password reset email.
    func sendPasswordReset() async {
        guard !email.isEmpty else {
            errorMessage = "Enter your email to reset your password."
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "Password reset email sent."
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    /// Google Sign-In → exchanges tokens for Firebase credential.
    /// Call from the view with a presenter (top UIViewController).
    func signInWithGoogle(presenter: UIViewController) async {
        isLoading = true; defer { isLoading = false }
        do {
            // 1) Present Google UI
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)

            // 2) Build Firebase credential
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "LoginVM", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
            }
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)

            // 3) Sign in to Firebase
            _ = try await Auth.auth().signIn(with: credential)
            print("LOGIN OK: Firebase signIn returned")
            errorMessage = nil
        } catch {
            errorMessage = mapAuthError(error)
        }
    }
    func startAppleSignIn() {
        errorMessage = nil
        isLoading = true

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()

        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(
            authorizationRequests: [request]
        )

        controller.delegate = self
        controller.performRequests()
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
    }

    // MARK: - Error mapping (friendly messages)
    private func mapAuthError(_ error: Error) -> String {
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
}
extension LoginVM: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleCredential =
                authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleCredential.identityToken,
              let idTokenString =
                String(data: appleIDToken, encoding: .utf8) else {

            isLoading = false
            errorMessage = "Unable to obtain Apple credentials."
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        Task {
            do {
                _ = try await Auth.auth().signIn(with: credential)

                print("LOGIN OK: Apple Firebase signIn returned")
                errorMessage = nil

            } catch {
                print("APPLE FIREBASE LOGIN ERROR:", error)
                errorMessage = mapAuthError(error)
            }

            currentNonce = nil
            isLoading = false
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("APPLE AUTHORIZATION ERROR:", error)

        currentNonce = nil
        isLoading = false

        let nsError = error as NSError

        if nsError.code != ASAuthorizationError.canceled.rawValue {
            errorMessage = error.localizedDescription
        }
    }
}
