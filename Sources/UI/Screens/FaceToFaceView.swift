import SwiftUI
import Dependencies

// MARK: - Face-to-Face Translation View

/// Main view for Face-to-Face translation supporting both Portrait and Landscape modes
@MainActor
public struct FaceToFaceView: View {
    @StateObject private var viewModel: ConversationViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showMenu = false
    @State private var showSettings = false
    @State private var showHistory = false

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    public init(viewModel: ConversationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public init() {
        self._viewModel = StateObject(wrappedValue: ConversationViewModel())
    }

    public var body: some View {
        GeometryReader { geometry in
            Group {
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: isLandscape)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .confirmationDialog("メニュー", isPresented: $showMenu) {
            Button("設定") { showSettings = true }
            Button("履歴") { showHistory = true }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
            if viewModel.canRetry {
                Button("再試行") { viewModel.retry() }
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            // Top panel - Translation (180° rotated for other person)
            translationPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Control bar (horizontal)
            horizontalControlBar
                .frame(height: 80)

            // Bottom panel - Original speech (normal orientation)
            originalSpeechPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Left panel - Target language (e.g., English)
            leftLanguagePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Vertical control bar
            verticalControlBar
                .frame(width: 80)

            // Right panel - Source language (e.g., Japanese)
            rightLanguagePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Translation Panel (Portrait Top - 180° rotated)

    private var translationPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.transcripts.reversed()) { item in
                        TranslationBubble(text: item.translatedText)
                            .rotationEffect(.degrees(180))
                            .id(item.id)
                    }

                    // Streaming translation
                    if !viewModel.currentTranslationText.isEmpty {
                        TranslationBubble(text: viewModel.currentTranslationText)
                            .rotationEffect(.degrees(180))
                            .opacity(0.8)
                            .id("streaming-translation")
                    }
                }
                .padding()
            }
            .rotationEffect(.degrees(180))  // Entire panel rotated
            .background(DesignSystem.FaceToFace.translationBackground)
            .onChange(of: viewModel.transcripts.count) { _, _ in
                withAnimation {
                    if let last = viewModel.transcripts.last {
                        proxy.scrollTo(last.id, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Original Speech Panel (Portrait Bottom - normal)

    private var originalSpeechPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.transcripts) { item in
                        OriginalBubble(text: item.originalText)
                            .id("original-\(item.id)")
                    }

                    // Streaming original (if available)
                    if !viewModel.currentRecognitionText.isEmpty {
                        OriginalBubble(text: viewModel.currentRecognitionText)
                            .opacity(0.7)
                            .id("streaming-original")
                    }
                }
                .padding()
            }
            .background(DesignSystem.FaceToFace.originalBackground)
            .onChange(of: viewModel.transcripts.count) { _, _ in
                withAnimation {
                    if let last = viewModel.transcripts.last {
                        proxy.scrollTo("original-\(last.id)", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Left Language Panel (Landscape - English)

    private var leftLanguagePanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.transcripts) { item in
                        LeftBubble(text: item.translatedText)
                            .id("left-\(item.id)")
                    }

                    if !viewModel.currentTranslationText.isEmpty {
                        LeftBubble(text: viewModel.currentTranslationText)
                            .opacity(0.7)
                            .id("left-streaming")
                    }
                }
                .padding()
            }
            .background(Color.white)
            .onChange(of: viewModel.transcripts.count) { _, _ in
                withAnimation {
                    if let last = viewModel.transcripts.last {
                        proxy.scrollTo("left-\(last.id)", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Right Language Panel (Landscape - Japanese)

    private var rightLanguagePanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 12) {
                    ForEach(viewModel.transcripts) { item in
                        RightBubble(text: item.originalText)
                            .id("right-\(item.id)")
                    }

                    if !viewModel.currentRecognitionText.isEmpty {
                        RightBubble(text: viewModel.currentRecognitionText)
                            .opacity(0.7)
                            .id("right-streaming")
                    }
                }
                .padding()
            }
            .background(Color.white)
            .onChange(of: viewModel.transcripts.count) { _, _ in
                withAnimation {
                    if let last = viewModel.transcripts.last {
                        proxy.scrollTo("right-\(last.id)", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Horizontal Control Bar (Portrait)

    private var horizontalControlBar: some View {
        HStack(spacing: 16) {
            FlagLanguageSelector(
                sourceLanguage: $viewModel.sourceLanguage,
                targetLanguage: $viewModel.targetLanguage,
                isVertical: false,
                onSwap: { viewModel.swapLanguages() }
            )

            FaceToFaceStopButton(
                isRecording: viewModel.isRecognizing,
                onTap: {
                    Task { await viewModel.toggleRecording() }
                }
            )

            FaceToFaceMuteButton(isMuted: $viewModel.isMuted)

            FaceToFaceMenuButton(onTap: { showMenu = true })
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.FaceToFace.controlBarBackground)
    }

    // MARK: - Vertical Control Bar (Landscape)

    private var verticalControlBar: some View {
        VStack(spacing: 16) {
            FlagLanguageSelector(
                sourceLanguage: $viewModel.sourceLanguage,
                targetLanguage: $viewModel.targetLanguage,
                isVertical: true,
                onSwap: { viewModel.swapLanguages() }
            )

            Spacer()

            FaceToFaceStopButton(
                isRecording: viewModel.isRecognizing,
                onTap: {
                    Task { await viewModel.toggleRecording() }
                }
            )

            Spacer()

            FaceToFaceMuteButton(isMuted: $viewModel.isMuted)

            FaceToFaceMenuButton(onTap: { showMenu = true })
        }
        .padding(.vertical, 20)
        .frame(maxHeight: .infinity)
        .background(DesignSystem.FaceToFace.controlBarBackground)
    }
}

// MARK: - Translation Bubble (Portrait Top)

private struct TranslationBubble: View {
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(DesignSystem.FaceToFace.translationText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.FaceToFace.translationBubble)
                .cornerRadius(12)
        }
    }
}

// MARK: - Original Bubble (Portrait Bottom)

private struct OriginalBubble: View {
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(DesignSystem.FaceToFace.originalText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.FaceToFace.originalBubble)
                .cornerRadius(12)
        }
    }
}

// MARK: - Left Bubble (Landscape Left - Target Language)

private struct LeftBubble: View {
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(DesignSystem.FaceToFace.originalText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.FaceToFace.leftPanelBubble)
                .cornerRadius(12)
        }
    }
}

// MARK: - Right Bubble (Landscape Right - Source Language)

private struct RightBubble: View {
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
                .font(.system(size: 17))
                .foregroundColor(DesignSystem.FaceToFace.originalText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.FaceToFace.rightPanelBubble)
                .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FaceToFaceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Portrait
            FaceToFaceView()
                .previewDisplayName("Portrait")

            // Landscape
            FaceToFaceView()
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("Landscape")
        }
    }
}
#endif
