import SwiftUI
import Dependencies

// MARK: - Conversation View

/// Main conversation screen for real-time translation
@MainActor
public struct ConversationView: View {
    @StateObject private var viewModel: ConversationViewModel

    @State private var showSettings = false
    @State private var showHistory = false

    public init(viewModel: ConversationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public init() {
        self._viewModel = StateObject(wrappedValue: ConversationViewModel())
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

                    // Live recognition/translation indicator
                    if viewModel.isRecognizing {
                        if viewModel.useStreamingMode {
                            // Streaming mode: show live translation
                            if !viewModel.currentTranslationText.isEmpty {
                                liveTranslationBubble
                            } else {
                                listeningIndicator
                            }
                        } else {
                            // Batch mode: show recognition text
                            if !viewModel.currentRecognitionText.isEmpty {
                                liveRecognitionBubble
                            }
                        }
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

    /// Listening indicator (no text yet)
    private var listeningIndicator: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .scaleEffect(viewModel.audioLevels.last ?? 0 > 0.1 ? 1.5 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevels.last)

            Text("🎙️ Listening...")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .transition(.opacity)
    }

    /// Live streaming translation bubble
    private var liveTranslationBubble: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.audioLevels.last ?? 0 > 0.1 ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevels.last)

                Text("🌐 Translating...")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Text(viewModel.currentTranslationText)
                .font(DesignSystem.Typography.transcriptText)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.md)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.large)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentTranslationText)
    }

    /// Live recognition bubble (batch mode)
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
    @Published public var currentTranslationText: String = ""  // Streaming translation
    @Published public var audioLevels: [Float] = Array(repeating: 0, count: 20)

    @Published public var isRecognizing: Bool = false
    @Published public var isSpeakerEnabled: Bool = true
    @Published public var showError: Bool = false
    @Published public var errorMessage: String = ""
    @Published public var canRetry: Bool = false

    /// Use streaming mode (Gemini Live API) or batch mode (STT + Translation + TTS)
    @Published public var useStreamingMode: Bool = true

    public var statusText: String {
        if isRecognizing {
            return useStreamingMode ? "🎙️ Live translating..." : "Listening... Tap to stop"
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

    // Streaming mode service
    private var liveTranslationService: LiveTranslationService?

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

        if useStreamingMode {
            await startStreamingMode()
        } else {
            await startBatchMode()
        }
    }

    public func stopRecording() async {
        if useStreamingMode {
            await stopStreamingMode()
        } else {
            await stopBatchMode()
        }
    }

    // MARK: - Streaming Mode (Gemini Live API)

    private func startStreamingMode() async {
        do {
            isRecognizing = true
            currentRecognitionText = ""
            currentTranslationText = ""
            print("[ConversationVM] Starting streaming mode (Gemini Live)...")

            // Create and configure LiveTranslationService
            let service = LiveTranslationService()

            // Setup callbacks
            service.onStreamingText = { [weak self] text in
                Task { @MainActor in
                    self?.currentTranslationText = text
                }
            }

            service.onTranscript = { [weak self] item in
                Task { @MainActor in
                    self?.transcripts.append(item)
                    self?.currentTranslationText = ""
                    print("[ConversationVM] Final transcript: \(item.translatedText)")
                }
            }

            service.onAudioLevel = { [weak self] level in
                Task { @MainActor in
                    self?.updateAudioLevels(confidence: level)
                }
            }

            service.onError = { [weak self] error in
                Task { @MainActor in
                    print("[ConversationVM] Streaming error: \(error)")
                    self?.handleError(error)
                }
            }

            service.onStateChange = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .active:
                        print("[ConversationVM] State: Active")
                    case .processing:
                        print("[ConversationVM] State: Processing")
                    case .error:
                        print("[ConversationVM] State: Error")
                    default:
                        break
                    }
                }
            }

            self.liveTranslationService = service

            // Start session
            try await service.startSession(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                bidirectional: true
            )

            print("[ConversationVM] Streaming mode started successfully")

        } catch {
            print("[ConversationVM] Failed to start streaming: \(error)")
            handleError(error)
        }
    }

    private func stopStreamingMode() async {
        print("[ConversationVM] Stopping streaming mode...")
        await liveTranslationService?.stopSession()
        liveTranslationService = nil
        isRecognizing = false
        currentTranslationText = ""
        print("[ConversationVM] Streaming mode stopped")
    }

    // MARK: - Batch Mode (STT + Translation + TTS)

    private func startBatchMode() async {
        do {
            isRecognizing = true
            currentRecognitionText = ""
            print("[ConversationVM] Starting batch mode (STT)...")

            let stream = try await sttService.startRecognition(language: sourceLanguage)

            recognitionTask = Task {
                for await result in stream {
                    await handleRecognitionResult(result)
                }
            }
        } catch {
            print("[ConversationVM] STT Error: \(error)")
            handleError(error)
        }
    }

    private func stopBatchMode() async {
        print("[ConversationVM] Stopping batch mode...")
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
        let text = "\(item.originalText)\n\(item.translatedText)"
        UIPasteboard.general.string = text
        #endif
    }

    public func speak(_ item: TranscriptItem) async {
        print("[ConversationVM] speak() called")
        guard isSpeakerEnabled else {
            print("[ConversationVM] Speaker disabled")
            return
        }

        let text = item.translatedText
        guard !text.isEmpty else { return }

        // Get voice for target language
        if let voice = await ttsService.defaultVoice(for: item.targetLanguage) {
            do {
                print("[ConversationVM] Speaking: '\(text.prefix(30))...' with voice: \(voice.name)")
                try await ttsService.speak(text, voice: voice)
                print("[ConversationVM] TTS completed")
            } catch {
                print("[ConversationVM] TTS error: \(error)")
            }
        } else {
            print("[ConversationVM] No voice available for \(item.targetLanguage)")
        }
    }

    public func retry() {
        Task {
            await startRecording()
        }
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(_ result: RecognitionResult) async {
        if !result.text.isEmpty {
            currentRecognitionText = result.text
        }
        updateAudioLevels(confidence: result.confidence)

        if result.isFinal {
            await finalizeRecognition()
        }
    }

    private func finalizeRecognition() async {
        print("[ConversationVM] finalizeRecognition: '\(currentRecognitionText)'")
        guard !currentRecognitionText.isEmpty else { return }

        do {
            print("[ConversationVM] Translating...")
            let result = try await translationService.translate(
                currentRecognitionText,
                from: sourceLanguage,
                to: targetLanguage
            )
            print("[ConversationVM] Translation: '\(result.translatedText)'")

            let transcript = TranscriptItem(
                speaker: .speaker1,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                originalText: currentRecognitionText,
                translatedText: result.translatedText
            )

            transcripts.append(transcript)
            currentRecognitionText = ""

            // Auto-speak
            if isSpeakerEnabled {
                await speak(transcript)
            }
        } catch {
            print("[ConversationVM] Translation error: \(error)")
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
