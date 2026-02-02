// AuthService.swift
// AuthService.swift
import Foundation
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class AuthService {
    // Cache last seen UID for quick reuse
    @Published private(set) var uid: String?

    init() {
        #if canImport(FirebaseAuth)
        // Keep uid in sync with auth state
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.uid = user?.uid
        }
        #endif
    }

    /// Returns the current UID if signed in; otherwise nil.
    func currentUID() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    /// Ensure we have a UID; if missing, sign in anonymously and return it.
    func ensureUID() async throws -> String {
        #if canImport(FirebaseAuth)
        if let id = Auth.auth().currentUser?.uid { return id }
        let result = try await Auth.auth().signInAnonymously()
        uid = result.user.uid
        return result.user.uid
        #else
        // In non-Firebase builds, throw or return a fixed debug value
        throw ServiceError.notImplemented
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        uid = nil
        #endif
    }
}
