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

@MainActor
final class LoginVM: ObservableObject {
    // MARK: - Inputs
    @Published var email: String = ""
    @Published var password: String = ""

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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
