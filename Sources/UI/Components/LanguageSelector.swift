import SwiftUI

// MARK: - Language Selector

/// Compact language selection with swap functionality
public struct LanguageSelector: View {
    @Binding public var sourceLanguage: SupportedLanguage
    @Binding public var targetLanguage: SupportedLanguage

    public let onSwap: () -> Void
    public let availableLanguages: [SupportedLanguage]

    @State private var showingSourcePicker = false
    @State private var showingTargetPicker = false

    public init(
        sourceLanguage: Binding<SupportedLanguage>,
        targetLanguage: Binding<SupportedLanguage>,
        availableLanguages: [SupportedLanguage] = SupportedLanguage.allCases,
        onSwap: @escaping () -> Void
    ) {
        self._sourceLanguage = sourceLanguage
        self._targetLanguage = targetLanguage
        self.availableLanguages = availableLanguages
        self.onSwap = onSwap
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Source language button
            LanguageButton(
                language: sourceLanguage,
                label: "From"
            ) {
                showingSourcePicker = true
            }

            // Swap button
            Button(action: swapLanguages) {
                Image(systemName: DesignSystem.Icons.swap)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.primaryFallback.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Target language button
            LanguageButton(
                language: targetLanguage,
                label: "To"
            ) {
                showingTargetPicker = true
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            LanguagePickerSheet(
                selectedLanguage: $sourceLanguage,
                availableLanguages: availableLanguages.filter { $0 != targetLanguage },
                title: "Source Language"
            )
        }
        .sheet(isPresented: $showingTargetPicker) {
            LanguagePickerSheet(
                selectedLanguage: $targetLanguage,
                availableLanguages: availableLanguages.filter { $0 != sourceLanguage },
                title: "Target Language"
            )
        }
    }

    private func swapLanguages() {
        withAnimation(DesignSystem.Animation.spring) {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
            onSwap()
        }
    }
}

// MARK: - Language Button

/// Individual language selection button
public struct LanguageButton: View {
    public let language: SupportedLanguage
    public let label: String
    public let action: () -> Void

    public var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(language.flagEmoji)
                        .font(.title2)

                    Text(language.nativeName)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Picker Sheet

/// Full-screen language picker
public struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding public var selectedLanguage: SupportedLanguage
    public let availableLanguages: [SupportedLanguage]
    public let title: String

    public var body: some View {
        NavigationView {
            List {
                ForEach(availableLanguages) { language in
                    LanguageRow(
                        language: language,
                        isSelected: language == selectedLanguage
                    ) {
                        selectedLanguage = language
                        dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Language Row

/// Language selection row
public struct LanguageRow: View {
    public let language: SupportedLanguage
    public let isSelected: Bool
    public let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(language.flagEmoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(language.localizedName)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                if language.supportsOnDeviceTranslation {
                    Image(systemName: "iphone")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                if isSelected {
                    Image(systemName: DesignSystem.Icons.checkmark)
                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Language Chip

/// Small language indicator chip
public struct LanguageChip: View {
    public let language: SupportedLanguage
    public let isSource: Bool

    public init(language: SupportedLanguage, isSource: Bool = true) {
        self.language = language
        self.isSource = isSource
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(language.flagEmoji)

            Text(language.languageCode.uppercased())
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            isSource
                ? DesignSystem.Colors.primaryFallback.opacity(0.1)
                : DesignSystem.Colors.secondaryFallback.opacity(0.1)
        )
        .foregroundColor(
            isSource
                ? DesignSystem.Colors.primaryFallback
                : DesignSystem.Colors.secondaryFallback
        )
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
}

// MARK: - Preview

#if DEBUG
struct LanguageSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            LanguageSelector(
                sourceLanguage: .constant(.japanese),
                targetLanguage: .constant(.englishUS)
            ) {}

            HStack {
                LanguageChip(language: .japanese, isSource: true)
                Image(systemName: "arrow.right")
                LanguageChip(language: .englishUS, isSource: false)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
