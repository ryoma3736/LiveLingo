import SwiftUI
import UIKit

// MARK: - Flag Language Selector

/// Language selector with flag emojis for Face-to-Face translation UI
/// Supports both horizontal (Portrait) and vertical (Landscape) layouts
public struct FlagLanguageSelector: View {
    @Binding public var sourceLanguage: SupportedLanguage
    @Binding public var targetLanguage: SupportedLanguage
    @Environment(\.adaptiveLayout) private var layout

    public var isVertical: Bool = false
    public var onSwap: () -> Void

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    public init(
        sourceLanguage: Binding<SupportedLanguage>,
        targetLanguage: Binding<SupportedLanguage>,
        isVertical: Bool = false,
        onSwap: @escaping () -> Void
    ) {
        self._sourceLanguage = sourceLanguage
        self._targetLanguage = targetLanguage
        self.isVertical = isVertical
        self.onSwap = onSwap
    }

    public var body: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            onSwap()
        }) {
            if isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            impactFeedback.prepare()
        }
    }

    // MARK: - Horizontal Layout (Portrait mode)

    private var horizontalLayout: some View {
        HStack(spacing: 8) {
            Text(sourceLanguage.flagEmoji)
                .font(.system(size: layout.flagEmojiSize))

            Text("/")
                .font(.system(size: layout.secondaryFontSize))
                .foregroundColor(.gray)

            Text(targetLanguage.flagEmoji)
                .font(.system(size: layout.flagEmojiSize))
        }
        .padding(.horizontal, layout.buttonHorizontalPadding)
        .padding(.vertical, layout.buttonVerticalPadding)
        .background(DesignSystem.FaceToFace.buttonBackground)
        .cornerRadius(layout.buttonCornerRadius)
    }

    // MARK: - Vertical Layout (Landscape mode)

    private var verticalLayout: some View {
        VStack(spacing: 4) {
            Text(sourceLanguage.flagEmoji)
                .font(.system(size: layout.flagEmojiSize))

            Text("/")
                .font(.system(size: layout.secondaryFontSize - 2))
                .foregroundColor(.gray)

            Text(targetLanguage.flagEmoji)
                .font(.system(size: layout.flagEmojiSize))
        }
        .padding(layout.verticalPadding)
        .background(DesignSystem.FaceToFace.buttonBackground)
        .clipShape(Circle())
    }
}

// MARK: - Stop Button

/// Stop/Start button for Face-to-Face translation
public struct FaceToFaceStopButton: View {
    public var isRecording: Bool
    public var onTap: () -> Void
    @Environment(\.adaptiveLayout) private var layout

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    public init(isRecording: Bool, onTap: @escaping () -> Void) {
        self.isRecording = isRecording
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isRecording ? DesignSystem.Icons.stopSquare : DesignSystem.Icons.microphone)
                    .font(.system(size: layout.buttonFontSize))

                Text(isRecording ? "停止" : "開始")
                    .font(.system(size: layout.buttonFontSize, weight: .medium))
            }
            .foregroundColor(DesignSystem.FaceToFace.tealAccent)
            .padding(.horizontal, layout.buttonHorizontalPadding)
            .padding(.vertical, layout.buttonVerticalPadding)
            .background(Color.white)
            .cornerRadius(layout.buttonCornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            impactFeedback.prepare()
        }
    }
}

// MARK: - Mute Button

/// Mute button for Face-to-Face translation
public struct FaceToFaceMuteButton: View {
    @Binding public var isMuted: Bool
    @Environment(\.adaptiveLayout) private var layout

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    public init(isMuted: Binding<Bool>) {
        self._isMuted = isMuted
    }

    public var body: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            isMuted.toggle()
        }) {
            Image(systemName: isMuted ? DesignSystem.Icons.speakerSlash : DesignSystem.Icons.speaker)
                .font(.system(size: layout.buttonFontSize + 2))
                .foregroundColor(isMuted ? DesignSystem.FaceToFace.muteActiveColor : DesignSystem.FaceToFace.tealAccent)
                .frame(width: layout.circularButtonSize, height: layout.circularButtonSize)
                .background(DesignSystem.FaceToFace.buttonBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onAppear {
            impactFeedback.prepare()
        }
    }
}

// MARK: - Menu Button

/// Menu button for Face-to-Face translation
public struct FaceToFaceMenuButton: View {
    public var onTap: () -> Void
    @Environment(\.adaptiveLayout) private var layout

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            onTap()
        }) {
            Image(systemName: DesignSystem.Icons.grid)
                .font(.system(size: layout.buttonFontSize + 2))
                .foregroundColor(DesignSystem.FaceToFace.tealAccent)
                .frame(width: layout.circularButtonSize, height: layout.circularButtonSize)
                .background(DesignSystem.FaceToFace.buttonBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onAppear {
            impactFeedback.prepare()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FlagLanguageSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Horizontal (Portrait mode)
            FlagLanguageSelector(
                sourceLanguage: .constant(.englishUS),
                targetLanguage: .constant(.japanese),
                isVertical: false
            ) {}

            // Vertical (Landscape mode)
            FlagLanguageSelector(
                sourceLanguage: .constant(.englishUS),
                targetLanguage: .constant(.japanese),
                isVertical: true
            ) {}

            // Stop Button
            HStack(spacing: 20) {
                FaceToFaceStopButton(isRecording: false) {}
                FaceToFaceStopButton(isRecording: true) {}
            }

            // Mute & Menu
            HStack(spacing: 20) {
                FaceToFaceMuteButton(isMuted: .constant(false))
                FaceToFaceMuteButton(isMuted: .constant(true))
                FaceToFaceMenuButton {}
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
