import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum ServiceError: Error {
    case notAuthenticated
    case permissionDenied
    case notFound
    case invalidRequest
    case invalidResponse
    case network(URLError.Code)
    case server(status: Int, body: String?)
    case decoding(underlying: Error)
    case firebaseAuth(code: AuthErrorCode)
    case cancelled
    case unknown(underlying: Error?)
}

extension ServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:       return "You need to sign in."
        case .permissionDenied:       return "You don’t have permission for this action."
        case .notFound:               return "The requested item wasn’t found."
        case .invalidRequest:         return "This request is invalid."
        case .invalidResponse:        return "Got an invalid response from the server."
        case .network(let code):      return "Network error: \(code.rawValue)."
        case .server(let status, _):  return "Server error (status \(status))."
        case .decoding:               return "Couldn’t read the server data."
        case .firebaseAuth(let code): return "Auth error: \(code)."
        case .cancelled:              return "The operation was cancelled."
        case .unknown:                return "An unknown error occurred."
        }
    }
}

/// Map common errors into `ServiceError`
extension ServiceError {
    static func map(_ error: Error) -> ServiceError {
        if let e = error as? ServiceError { return e }

        // URLSession / networking
        if let urlErr = error as? URLError {
            if urlErr.code == .cancelled { return .cancelled }
            return .network(urlErr.code)
        }

        // Firebase Auth
        #if canImport(FirebaseAuth)
        let ns = error as NSError
        if ns.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .userNotFound:                return .notAuthenticated
            case .networkError:                return .network(.notConnectedToInternet)
            default:                           return .firebaseAuth(code: code)
            }
        }
        #endif

        return .unknown(underlying: error)
    }
}

//  ServiceError.swift
//  Slug Bug
//
//  Created by Kevin Leckenby on 9/22/25.
//

