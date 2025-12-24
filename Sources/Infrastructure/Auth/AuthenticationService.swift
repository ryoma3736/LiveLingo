import Foundation
import AuthenticationServices

// MARK: - Authentication State

/// Current authentication state
public enum AuthenticationState: Equatable, Sendable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(String)
}

// MARK: - User

/// Authenticated user model
public struct User: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let email: String?
    public let displayName: String?
    public let photoURL: URL?
    public let isAnonymous: Bool
    public let createdAt: Date

    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        photoURL: URL? = nil,
        isAnonymous: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isAnonymous = isAnonymous
        self.createdAt = createdAt
    }
}

// MARK: - Authentication Provider

/// Supported authentication providers
public enum AuthProvider: String, Codable, Sendable {
    case anonymous
    case apple
    case email
}

// MARK: - Authentication Service Protocol

/// Protocol for authentication operations
public protocol AuthenticationServiceProtocol: Sendable {
    var currentUser: User? { get async }
    var authenticationState: AuthenticationState { get async }

    func signInAnonymously() async throws -> User
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
    func refreshToken() async throws -> String
}

// MARK: - Authentication Service

/// Main authentication service implementation
public actor AuthenticationService: AuthenticationServiceProtocol {
    private let keychain: KeychainManagerProtocol
    private let networkClient: NetworkClientProtocol

    private var _currentUser: User?
    private var _authenticationState: AuthenticationState = .unauthenticated

    public var currentUser: User? { _currentUser }
    public var authenticationState: AuthenticationState { _authenticationState }

    public init(
        keychain: KeychainManagerProtocol = KeychainManager.shared,
        networkClient: NetworkClientProtocol? = nil
    ) {
        self.keychain = keychain
        self.networkClient = networkClient ?? NetworkClient()
    }

    // MARK: - Sign In

    public func signInAnonymously() async throws -> User {
        _authenticationState = .authenticating

        do {
            // Generate anonymous user
            let user = User(
                id: UUID().uuidString,
                isAnonymous: true
            )

            // Store user ID
            try keychain.save(user.id, for: .userId)

            _currentUser = user
            _authenticationState = .authenticated(user)

            return user
        } catch {
            _authenticationState = .error(error.localizedDescription)
            throw error
        }
    }

    public func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> User {
        _authenticationState = .authenticating

        do {
            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                throw LiveLingoError.authenticationRequired
            }

            // In production, send token to backend for verification
            let user = User(
                id: credential.user,
                email: credential.email,
                displayName: [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .nilIfEmpty
            )

            // Store credentials
            try keychain.save(user.id, for: .userId)
            try keychain.save(tokenString, for: .accessToken)

            _currentUser = user
            _authenticationState = .authenticated(user)

            return user
        } catch {
            _authenticationState = .error(error.localizedDescription)
            throw error
        }
    }

    public func signInWithEmail(email: String, password: String) async throws -> User {
        _authenticationState = .authenticating

        do {
            // In production, call authentication API
            // For now, create mock user
            let user = User(
                id: UUID().uuidString,
                email: email
            )

            try keychain.save(user.id, for: .userId)

            _currentUser = user
            _authenticationState = .authenticated(user)

            return user
        } catch {
            _authenticationState = .error(error.localizedDescription)
            throw error
        }
    }

    public func signUp(email: String, password: String) async throws -> User {
        // Validate email and password
        guard isValidEmail(email) else {
            throw LiveLingoError.authenticationFailed(reason: "Invalid email address")
        }

        guard isValidPassword(password) else {
            throw LiveLingoError.authenticationFailed(reason: "Password must be at least 8 characters")
        }

        // In production, call signup API
        return try await signInWithEmail(email: email, password: password)
    }

    // MARK: - Sign Out

    public func signOut() async throws {
        try keychain.delete(key: .userId)
        try keychain.delete(key: .accessToken)
        try keychain.delete(key: .refreshToken)

        _currentUser = nil
        _authenticationState = .unauthenticated
    }

    public func deleteAccount() async throws {
        // In production, call delete account API
        try await signOut()
    }

    // MARK: - Token Management

    public func refreshToken() async throws -> String {
        guard let refreshToken = try? keychain.loadString(key: .refreshToken) else {
            throw LiveLingoError.authenticationRequired
        }

        // In production, call token refresh API
        return refreshToken
    }

    public func restoreSession() async -> Bool {
        guard let userId = try? keychain.loadString(key: .userId) else {
            return false
        }

        // In production, validate token with backend
        let user = User(id: userId, isAnonymous: true)
        _currentUser = user
        _authenticationState = .authenticated(user)

        return true
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }
}

// MARK: - String Extension

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Sign in with Apple Coordinator

#if os(iOS)
import UIKit

@MainActor
public final class SignInWithAppleCoordinator: NSObject {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    public func signIn() async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: LiveLingoError.authenticationFailed(reason: "Invalid credential"))
        }
        continuation = nil
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
#endif
