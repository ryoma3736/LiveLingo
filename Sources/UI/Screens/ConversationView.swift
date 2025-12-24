import SwiftUI
import Dependencies

// MARK: - Conversation View

/// Main conversation screen for real-time translation
public struct ConversationView: View {
    @StateObject private var viewModel: ConversationViewModel

    @State private var showSettings = false
    @State private var showHistory = false

    public init(viewModel: ConversationViewModel = ConversationViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Language selector
                languageSelector
                    .padding(.horizontal)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.background)

                Divider()

                // Transcript list
                transcriptList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Recording controls
                recordingControls
                    .padding()
                    .background(DesignSystem.Colors.background)
            }
            .navigationTitle("LiveLingo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: DesignSystem.Icons.history)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: DesignSystem.Icons.settings)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
                if viewModel.canRetry {
                    Button("Retry") {
                        viewModel.retry()
                    }
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        LanguageSelector(
            sourceLanguage: $viewModel.sourceLanguage,
            targetLanguage: $viewModel.targetLanguage
        ) {
            viewModel.swapLanguages()
        }
    }

    // MARK: - Transcript List

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(viewModel.transcripts) { item in
                        TranscriptBubble(
                            item: item,
                            onCopy: {
                                viewModel.copyToClipboard(item)
                            },
                            onSpeak: {
                                Task {
                                    await viewModel.speak(item)
                                }
                            }
                        )
                        .id(item.id)
                    }

                    // Live recognition indicator
                    if viewModel.isRecognizing, !viewModel.currentRecognitionText.isEmpty {
                        liveRecognitionBubble
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .onChange(of: viewModel.transcripts.count) { _, _ in
                withAnimation {
                    if let lastItem = viewModel.transcripts.last {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var liveRecognitionBubble: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Listening...")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Text(viewModel.currentRecognitionText)
                .font(DesignSystem.Typography.transcriptText)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .opacity(0.7)
                .padding(DesignSystem.Spacing.md)
                .background(Color.green.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.large)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Audio level indicator
            if viewModel.isRecognizing {
                WaveformView(
                    levels: viewModel.audioLevels,
                    color: DesignSystem.Colors.primaryFallback
                )
                .frame(height: 32)
            }

            HStack(spacing: DesignSystem.Spacing.xl) {
                // Speaker toggle
                Button {
                    viewModel.toggleSpeaker()
                } label: {
                    Image(systemName: viewModel.isSpeakerEnabled
                        ? DesignSystem.Icons.speaker
                        : DesignSystem.Icons.speakerSlash)
                    .font(.title2)
                    .foregroundColor(viewModel.isSpeakerEnabled
                        ? DesignSystem.Colors.primaryFallback
                        : DesignSystem.Colors.textSecondary)
                }

                // Main recording button
                RecordingButton(
                    isRecording: $viewModel.isRecognizing
                ) {
                    Task {
                        await viewModel.toggleRecording()
                    }
                }

                // Stop/Clear button
                Button {
                    viewModel.stopAndClear()
                } label: {
                    Image(systemName: DesignSystem.Icons.stop)
                        .font(.title2)
                        .foregroundColor(viewModel.isRecognizing
                            ? .red
                            : DesignSystem.Colors.textSecondary)
                }
                .disabled(!viewModel.isRecognizing)
            }

            // Status text
            Text(viewModel.statusText)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Conversation View Model

@MainActor
public final class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var sourceLanguage: SupportedLanguage = .japanese
    @Published public var targetLanguage: SupportedLanguage = .englishUS
    @Published public var transcripts: [TranscriptItem] = []
    @Published public var currentRecognitionText: String = ""
    @Published public var audioLevels: [Float] = Array(repeating: 0, count: 20)

    @Published public var isRecognizing: Bool = false
    @Published public var isSpeakerEnabled: Bool = true
    @Published public var showError: Bool = false
    @Published public var errorMessage: String = ""
    @Published public var canRetry: Bool = false

    public var statusText: String {
        if isRecognizing {
            return "Listening... Tap to stop"
        } else if transcripts.isEmpty {
            return "Tap the microphone to start"
        } else {
            return "\(transcripts.count) messages"
        }
    }

    // MARK: - Dependencies

    @Dependency(\.sttService) private var sttService
    @Dependency(\.translationService) private var translationService
    @Dependency(\.ttsService) private var ttsService

    private var recognitionTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    public func toggleRecording() async {
        if isRecognizing {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    public func startRecording() async {
        guard !isRecognizing else { return }

        do {
            isRecognizing = true
            currentRecognitionText = ""

            let stream = try await sttService.startRecognition(language: sourceLanguage)

            recognitionTask = Task {
                for await result in stream {
                    await handleRecognitionResult(result)
                }
            }
        } catch {
            handleError(error)
        }
    }

    public func stopRecording() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        await sttService.stopRecognition()
        isRecognizing = false

        // Finalize any pending recognition
        if !currentRecognitionText.isEmpty {
            await finalizeRecognition()
        }
    }

    public func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }

    public func toggleSpeaker() {
        isSpeakerEnabled.toggle()
    }

    public func stopAndClear() {
        Task {
            await stopRecording()
            transcripts.removeAll()
            currentRecognitionText = ""
        }
    }

    public func copyToClipboard(_ item: TranscriptItem) {
        #if os(iOS)
        let text = "\(item.originalText)\n\(item.translatedText ?? "")"
        UIPasteboard.general.string = text
        #endif
    }

    public func speak(_ item: TranscriptItem) async {
        guard isSpeakerEnabled else { return }

        if let translation = item.translatedText {
            let voice = await ttsService.availableVoices(for: item.targetLanguage).first
            if let voice = voice {
                do {
                    let data = try await ttsService.synthesize(translation, voice: voice)
                    try await ttsService.play(data)
                } catch {
                    // Ignore TTS errors silently
                }
            }
        }
    }

    public func retry() {
        Task {
            await startRecording()
        }
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(_ result: RecognitionResult) async {
        currentRecognitionText = result.text
        updateAudioLevels(confidence: result.confidence)

        if result.isFinal {
            await finalizeRecognition()
        }
    }

    private func finalizeRecognition() async {
        guard !currentRecognitionText.isEmpty else { return }

        do {
            let translationResult = try await translationService.translate(
                currentRecognitionText,
                from: sourceLanguage,
                to: targetLanguage
            )

            let transcript = TranscriptItem(
                speaker: .speaker1,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                originalText: currentRecognitionText,
                translatedText: translationResult.translatedText
            )

            transcripts.append(transcript)

            // Auto-speak translation
            if isSpeakerEnabled {
                await speak(transcript)
            }

            currentRecognitionText = ""
        } catch {
            handleError(error)
        }
    }

    private func updateAudioLevels(confidence: Float) {
        // Shift levels and add new one
        audioLevels.removeFirst()
        audioLevels.append(confidence)
    }

    private func handleError(_ error: Error) {
        isRecognizing = false

        if let lingoError = error as? LiveLingoError {
            errorMessage = lingoError.errorDescription ?? "Unknown error"
            canRetry = true
        } else {
            errorMessage = error.localizedDescription
            canRetry = false
        }

        showError = true
    }
}

// MARK: - Preview

#if DEBUG
struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationView()
    }
}
#endif
