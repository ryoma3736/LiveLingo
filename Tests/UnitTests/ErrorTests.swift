import XCTest
@testable import LiveLingo

final class ErrorTests: XCTestCase {
    // MARK: - Error Description Tests

    func testSTTErrorDescriptions() {
        let error1 = LiveLingoError.sttNotAvailable(reason: "Device not supported")
        XCTAssertTrue(error1.errorDescription?.contains("not available") == true)

        let error2 = LiveLingoError.sttPermissionDenied
        XCTAssertTrue(error2.errorDescription?.contains("permission") == true)
    }

    func testTranslationErrorDescriptions() {
        let error = LiveLingoError.translationProviderUnavailable(.openAI)
        XCTAssertTrue(error.errorDescription?.contains("openai") == true)

        let pairError = LiveLingoError.translationLanguagePairNotSupported(
            from: .japanese,
            to: .vietnamese
        )
        XCTAssertTrue(pairError.errorDescription?.contains("not supported") == true)
    }

    func testNetworkErrorDescriptions() {
        let error1 = LiveLingoError.networkUnavailable
        XCTAssertTrue(error1.errorDescription?.contains("connection") == true)

        let error2 = LiveLingoError.networkRequestFailed(statusCode: 500, message: "Internal error")
        XCTAssertTrue(error2.errorDescription?.contains("500") == true)
    }

    func testPermissionErrorDescriptions() {
        let error = LiveLingoError.permissionDenied(permission: .microphone)
        XCTAssertTrue(error.errorDescription?.contains("Microphone") == true)
    }

    // MARK: - Recovery Suggestion Tests

    func testRecoverySuggestions() {
        let permissionError = LiveLingoError.sttPermissionDenied
        XCTAssertNotNil(permissionError.recoverySuggestion)
        XCTAssertTrue(permissionError.recoverySuggestion?.contains("Settings") == true)

        let networkError = LiveLingoError.networkUnavailable
        XCTAssertNotNil(networkError.recoverySuggestion)
        XCTAssertTrue(networkError.recoverySuggestion?.contains("connection") == true)
    }

    // MARK: - Permission Tests

    func testPermissionDisplayNames() {
        XCTAssertEqual(Permission.microphone.displayName, "Microphone")
        XCTAssertEqual(Permission.speechRecognition.displayName, "Speech Recognition")
        XCTAssertEqual(Permission.notifications.displayName, "Notifications")
    }
}
