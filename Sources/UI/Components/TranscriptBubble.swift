import SwiftUI

// MARK: - Transcript Bubble

/// Speech bubble component for displaying transcript items
public struct TranscriptBubble: View {
    public let item: TranscriptItem
    public let showTranslation: Bool
    public let onCopy: (() -> Void)?
    public let onSpeak: (() -> Void)?

    @State private var isExpanded = false

    public init(
        item: TranscriptItem,
        showTranslation: Bool = true,
        onCopy: (() -> Void)? = nil,
        onSpeak: (() -> Void)? = nil
    ) {
        self.item = item
        self.showTranslation = showTranslation
        self.onCopy = onCopy
        self.onSpeak = onSpeak
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: DesignSystem.Spacing.xs) {
            // Speaker indicator
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(speakerColor)
                    .frame(width: 8, height: 8)

                Text(speakerLabel)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Text(timeString)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            // Original text bubble
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.originalText)
                    .font(DesignSystem.Typography.transcriptText)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                // Language indicator
                HStack {
                    Text(item.sourceLanguage.flagEmoji)
                    Text(item.sourceLanguage.nativeName)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(bubbleBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)

            // Translation (if available and showing)
            if showTranslation, !item.translatedText.isEmpty {
                let translation = item.translatedText
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(translation)
                        .font(DesignSystem.Typography.translationText)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    // Target language indicator
                    HStack {
                        Text(item.targetLanguage.flagEmoji)
                        Text(item.targetLanguage.nativeName)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(translationBackground)
                .cornerRadius(DesignSystem.CornerRadius.large)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            }

            // Action buttons (shown when expanded)
            if isExpanded {
                HStack(spacing: DesignSystem.Spacing.md) {
                    if let onCopy = onCopy {
                        Button(action: onCopy) {
                            Label("Copy", systemImage: DesignSystem.Icons.copy)
                                .font(DesignSystem.Typography.caption1)
                        }
                    }

                    if let onSpeak = onSpeak {
                        Button(action: onSpeak) {
                            Label("Speak", systemImage: DesignSystem.Icons.speaker)
                                .font(DesignSystem.Typography.caption1)
                        }
                    }
                }
                .foregroundColor(DesignSystem.Colors.primaryFallback)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.quick) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Private Properties

    private var alignment: HorizontalAlignment {
        item.speaker == .speaker1 ? .leading : .trailing
    }

    private var speakerColor: Color {
        DesignSystem.Colors.speaker(item.speaker)
    }

    private var speakerLabel: String {
        switch item.speaker {
        case .speaker1:
            return "You"
        case .speaker2:
            return "Partner"
        case .unknown:
            return "Unknown"
        }
    }

    private var bubbleBackground: Color {
        switch item.speaker {
        case .speaker1:
            return DesignSystem.Colors.primaryFallback.opacity(0.1)
        case .speaker2:
            return DesignSystem.Colors.secondaryFallback.opacity(0.1)
        case .unknown:
            return DesignSystem.Colors.tertiaryBackground
        }
    }

    private var translationBackground: Color {
        DesignSystem.Colors.secondaryBackground
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.timestamp)
    }
}

// MARK: - Preview

#if DEBUG
struct TranscriptBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            TranscriptBubble(
                item: TranscriptItem(
                    speaker: .speaker1,
                    sourceLanguage: .japanese,
                    targetLanguage: .englishUS,
                    originalText: "こんにちは、今日はいい天気ですね。",
                    translatedText: "Hello, it's nice weather today."
                )
            )

            TranscriptBubble(
                item: TranscriptItem(
                    speaker: .speaker2,
                    sourceLanguage: .englishUS,
                    targetLanguage: .japanese,
                    originalText: "Yes, it's beautiful! Would you like to go for a walk?",
                    translatedText: "はい、素晴らしいですね！散歩に行きませんか？"
                )
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
