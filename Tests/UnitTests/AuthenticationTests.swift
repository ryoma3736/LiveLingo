import XCTest
@testable import LiveLingo

final class AuthenticationTests: XCTestCase {
    // MARK: - User Tests

    func testUserCreation() {
        let user = User(
            id: "test-user-id",
            email: "test@example.com",
            displayName: "Test User",
            isAnonymous: false
        )

        XCTAssertEqual(user.id, "test-user-id")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertFalse(user.isAnonymous)
    }

    func testAnonymousUserCreation() {
        let user = User(
            id: "anonymous-id",
            isAnonymous: true
        )

        XCTAssertTrue(user.isAnonymous)
        XCTAssertNil(user.email)
        XCTAssertNil(user.displayName)
    }

    func testUserEquality() {
        let user1 = User(id: "same-id", email: "a@b.com")
        let user2 = User(id: "same-id", email: "c@d.com")
        let user3 = User(id: "different-id", email: "a@b.com")

        XCTAssertEqual(user1, user2) // Same ID
        XCTAssertNotEqual(user1, user3) // Different ID
    }

    // MARK: - Authentication State Tests

    func testAuthenticationStateEquality() {
        XCTAssertEqual(AuthenticationState.unauthenticated, AuthenticationState.unauthenticated)
        XCTAssertEqual(AuthenticationState.authenticating, AuthenticationState.authenticating)
        XCTAssertNotEqual(AuthenticationState.unauthenticated, AuthenticationState.authenticating)

        let user = User(id: "test")
        XCTAssertEqual(
            AuthenticationState.authenticated(user),
            AuthenticationState.authenticated(user)
        )

        XCTAssertEqual(
            AuthenticationState.error("Test error"),
            AuthenticationState.error("Test error")
        )
    }

    // MARK: - Auth Provider Tests

    func testAuthProviderRawValues() {
        XCTAssertEqual(AuthProvider.anonymous.rawValue, "anonymous")
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.email.rawValue, "email")
    }

    // MARK: - String Extension Tests

    func testNilIfEmpty() {
        XCTAssertNil("".nilIfEmpty)
        XCTAssertEqual("Hello".nilIfEmpty, "Hello")
        XCTAssertEqual(" ".nilIfEmpty, " ") // Space is not empty
    }
}

// MARK: - Keychain Integration Tests

final class KeychainIntegrationTests: XCTestCase {
    func testKeychainKeys() {
        // Verify all keychain keys have unique values
        let keys: [KeychainKey] = [
            .openAIAPIKey,
            .anthropicAPIKey,
            .coeFontAPIKey,
            .accessToken,
            .refreshToken,
            .userId
        ]

        let rawValues = keys.map { $0.rawValue }
        let uniqueValues = Set(rawValues)

        XCTAssertEqual(rawValues.count, uniqueValues.count, "All keychain keys should have unique raw values")
    }

    func testKeychainErrorMessages() {
        let errors: [KeychainError] = [
            .itemNotFound,
            .duplicateItem,
            .unexpectedStatus(-25300),
            .encodingFailed,
            .decodingFailed,
            .accessDenied
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
}

// MARK: - API Key Manager Tests

final class APIKeyManagerTests: XCTestCase {
    func testTranslationProviderKeyMapping() async {
        let keyManager = APIKeyManager()

        // Check hasAPIKey for providers that don't need keys
        let hasAppleKey = await keyManager.hasAPIKey(for: .apple)
        let hasCacheKey = await keyManager.hasAPIKey(for: .cache)

        XCTAssertTrue(hasAppleKey, "Apple provider should always return true")
        XCTAssertTrue(hasCacheKey, "Cache provider should always return true")
    }
}
