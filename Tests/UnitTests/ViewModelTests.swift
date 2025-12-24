import XCTest
@testable import LiveLingo

final class ViewModelTests: XCTestCase {
    // MARK: - Conversation ViewModel Tests

    @MainActor
    func testConversationViewModelInitialState() {
        let viewModel = ConversationViewModel()

        XCTAssertEqual(viewModel.sourceLanguage, .japanese)
        XCTAssertEqual(viewModel.targetLanguage, .englishUS)
        XCTAssertTrue(viewModel.transcripts.isEmpty)
        XCTAssertFalse(viewModel.isRecognizing)
        XCTAssertTrue(viewModel.isSpeakerEnabled)
    }

    @MainActor
    func testConversationViewModelSwapLanguages() {
        let viewModel = ConversationViewModel()
        viewModel.sourceLanguage = .japanese
        viewModel.targetLanguage = .englishUS

        viewModel.swapLanguages()

        XCTAssertEqual(viewModel.sourceLanguage, .englishUS)
        XCTAssertEqual(viewModel.targetLanguage, .japanese)
    }

    @MainActor
    func testConversationViewModelToggleSpeaker() {
        let viewModel = ConversationViewModel()
        XCTAssertTrue(viewModel.isSpeakerEnabled)

        viewModel.toggleSpeaker()
        XCTAssertFalse(viewModel.isSpeakerEnabled)

        viewModel.toggleSpeaker()
        XCTAssertTrue(viewModel.isSpeakerEnabled)
    }

    @MainActor
    func testConversationViewModelStatusText() {
        let viewModel = ConversationViewModel()

        // Initial state
        XCTAssertTrue(viewModel.statusText.contains("Tap"))

        // Add a transcript
        let transcript = TranscriptItem(
            speaker: .speaker1,
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            originalText: "Test",
            translatedText: "Test"
        )
        viewModel.transcripts.append(transcript)

        XCTAssertTrue(viewModel.statusText.contains("1"))
    }

    // MARK: - History ViewModel Tests

    @MainActor
    func testHistoryViewModelInitialState() {
        let viewModel = HistoryViewModel()

        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Settings ViewModel Tests

    @MainActor
    func testSettingsViewModelAppVersion() {
        let viewModel = SettingsViewModel()

        XCTAssertFalse(viewModel.appVersion.isEmpty)
    }

    @MainActor
    func testSettingsViewModelInitialSettings() {
        let viewModel = SettingsViewModel()

        XCTAssertEqual(viewModel.settings.preferredSourceLanguage, .japanese)
        XCTAssertEqual(viewModel.settings.preferredTargetLanguage, .englishUS)
    }
}

// MARK: - App State Tests

final class AppStateTests: XCTestCase {
    @MainActor
    func testAppStateInitialState() {
        let appState = AppState()

        XCTAssertEqual(appState.launchState, .loading)
    }

    @MainActor
    func testAppStateCompleteOnboarding() {
        let appState = AppState()

        appState.completeOnboarding()

        XCTAssertEqual(appState.launchState, .permissionRequest)
    }
}

// MARK: - Launch State Tests

final class LaunchStateTests: XCTestCase {
    func testLaunchStateEquality() {
        XCTAssertEqual(LaunchState.loading, LaunchState.loading)
        XCTAssertEqual(LaunchState.onboarding, LaunchState.onboarding)
        XCTAssertNotEqual(LaunchState.loading, LaunchState.ready)
    }
}
