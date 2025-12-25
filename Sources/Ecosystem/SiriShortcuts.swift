import Foundation
import AppIntents
import SwiftUI

// MARK: - Start Interpretation Intent

/// Siri Shortcut to start real-time interpretation
@available(iOS 16.0, *)
public struct StartInterpretationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Interpretation"
    public static var description = IntentDescription(
        "Start real-time interpretation with LiveLingo",
        categoryName: "Interpretation"
    )

    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Source Language", description: "The language to translate from")
    public var sourceLanguage: LanguageEntity?

    @Parameter(title: "Target Language", description: "The language to translate to")
    public var targetLanguage: LanguageEntity?

    public static var parameterSummary: some ParameterSummary {
        Summary("Start interpreting from \(\.$sourceLanguage) to \(\.$targetLanguage)")
    }

    public init() {}

    public init(sourceLanguage: LanguageEntity?, targetLanguage: LanguageEntity?) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        // Store the intent parameters for the app to pick up
        let defaults = UserDefaults.standard

        if let source = sourceLanguage?.language {
            defaults.set(source.rawValue, forKey: "siri.startInterpretation.sourceLanguage")
        }

        if let target = targetLanguage?.language {
            defaults.set(target.rawValue, forKey: "siri.startInterpretation.targetLanguage")
        }

        defaults.set(true, forKey: "siri.startInterpretation.pending")

        return .result(opensIntent: OpenAppIntent())
    }
}

// MARK: - Stop Interpretation Intent

@available(iOS 16.0, *)
public struct StopInterpretationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Stop Interpretation"
    public static var description = IntentDescription(
        "Stop the current interpretation session",
        categoryName: "Interpretation"
    )

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Stop interpretation via notification
        NotificationCenter.default.post(
            name: Notification.Name("LiveLingo.StopInterpretation"),
            object: nil
        )

        return .result(dialog: "Interpretation stopped.")
    }
}

// MARK: - Switch Languages Intent

@available(iOS 16.0, *)
public struct SwitchLanguagesIntent: AppIntent {
    public static var title: LocalizedStringResource = "Switch Languages"
    public static var description = IntentDescription(
        "Switch source and target languages",
        categoryName: "Interpretation"
    )

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(
            name: Notification.Name("LiveLingo.SwitchLanguages"),
            object: nil
        )

        return .result(dialog: "Languages switched.")
    }
}

// MARK: - Read Last Translation Intent

@available(iOS 16.0, *)
public struct ReadLastTranslationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Read Last Translation"
    public static var description = IntentDescription(
        "Read the most recent translation aloud",
        categoryName: "Translation"
    )

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get last translation from UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.livelingo.shared")

        guard let lastOriginal = defaults?.string(forKey: "lastTranslation.original"),
              let lastTranslated = defaults?.string(forKey: "lastTranslation.translated") else {
            return .result(dialog: "No recent translations available.")
        }

        return .result(dialog: "\(lastOriginal) translates to \(lastTranslated)")
    }
}

// MARK: - Open App Intent

@available(iOS 16.0, *)
public struct OpenAppIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open LiveLingo"
    public static var description = IntentDescription("Open the LiveLingo app")
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Language Entity

/// Entity representing a supported language for App Intents
@available(iOS 16.0, *)
public struct LanguageEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Language")
    }

    public static var defaultQuery = LanguageQuery()

    public let id: String
    public let language: SupportedLanguage

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(language.flagEmoji) \(language.nativeName)",
            subtitle: LocalizedStringResource(stringLiteral: language.localizedName)
        )
    }

    public init(language: SupportedLanguage) {
        self.id = language.rawValue
        self.language = language
    }
}

/// Query for finding languages
@available(iOS 16.0, *)
public struct LanguageQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [LanguageEntity] {
        identifiers.compactMap { id in
            guard let language = SupportedLanguage(rawValue: id) else { return nil }
            return LanguageEntity(language: language)
        }
    }

    public func suggestedEntities() async throws -> [LanguageEntity] {
        // Return Phase 1 languages first, then others
        let phase1: [SupportedLanguage] = [.japanese, .englishUS, .chineseSimplified, .korean]
        let others = SupportedLanguage.allCases.filter { !phase1.contains($0) }

        return (phase1 + others).map { LanguageEntity(language: $0) }
    }

    public func defaultResult() async -> LanguageEntity? {
        LanguageEntity(language: .japanese)
    }
}

// MARK: - App Shortcuts Provider

/// Provides shortcuts that appear in the Shortcuts app
@available(iOS 16.0, *)
public struct LiveLingoShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartInterpretationIntent(),
            phrases: [
                "Start interpreting with \(.applicationName)",
                "Start \(.applicationName)",
                "Begin interpretation with \(.applicationName)",
                "\(.applicationName)で通訳を開始",
                "\(.applicationName)を起動して通訳"
            ],
            shortTitle: "Start Interpretation",
            systemImageName: "waveform.circle"
        )

        AppShortcut(
            intent: StopInterpretationIntent(),
            phrases: [
                "Stop interpreting with \(.applicationName)",
                "Stop \(.applicationName)",
                "End interpretation with \(.applicationName)",
                "\(.applicationName)の通訳を停止",
                "\(.applicationName)の通訳を止めて"
            ],
            shortTitle: "Stop Interpretation",
            systemImageName: "stop.circle"
        )

        AppShortcut(
            intent: SwitchLanguagesIntent(),
            phrases: [
                "Switch languages in \(.applicationName)",
                "Swap languages with \(.applicationName)",
                "\(.applicationName)の言語を切り替え"
            ],
            shortTitle: "Switch Languages",
            systemImageName: "arrow.left.arrow.right"
        )

        AppShortcut(
            intent: ReadLastTranslationIntent(),
            phrases: [
                "Read last translation from \(.applicationName)",
                "What was the last translation in \(.applicationName)",
                "\(.applicationName)で最後の翻訳を読んで"
            ],
            shortTitle: "Read Translation",
            systemImageName: "text.bubble"
        )
    }
}

// MARK: - Quick Actions

/// Quick action options for app launch
public struct QuickAction: Identifiable, Sendable {
    public let id: String
    public let type: QuickActionType
    public let title: String
    public let iconName: String

    public enum QuickActionType: String, Sendable {
        case startJapaneseEnglish = "start_ja_en"
        case startEnglishJapanese = "start_en_ja"
        case openHistory = "open_history"
        case openSettings = "open_settings"
    }

    public static let availableActions: [QuickAction] = [
        QuickAction(
            id: "ja_en",
            type: .startJapaneseEnglish,
            title: "Japanese → English",
            iconName: "arrow.right.circle"
        ),
        QuickAction(
            id: "en_ja",
            type: .startEnglishJapanese,
            title: "English → Japanese",
            iconName: "arrow.left.circle"
        ),
        QuickAction(
            id: "history",
            type: .openHistory,
            title: "History",
            iconName: "clock"
        ),
        QuickAction(
            id: "settings",
            type: .openSettings,
            title: "Settings",
            iconName: "gear"
        )
    ]
}

// MARK: - Siri Integration Manager

/// Manages Siri integration and shortcut donations
public actor SiriIntegrationManager {
    public static let shared = SiriIntegrationManager()

    private init() {}

    /// Check if Siri is available
    public nonisolated func isSiriAvailable() -> Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    /// Donate a shortcut based on user action
    public func donateShortcut(for action: ShortcutDonationType) async {
        guard #available(iOS 16.0, *) else { return }

        switch action {
        case .startInterpretation(let source, let target):
            let intent = StartInterpretationIntent(
                sourceLanguage: LanguageEntity(language: source),
                targetLanguage: LanguageEntity(language: target)
            )
            // Donate happens automatically for AppIntents
            _ = intent

        case .stopInterpretation:
            let intent = StopInterpretationIntent()
            _ = intent

        case .switchLanguages:
            let intent = SwitchLanguagesIntent()
            _ = intent
        }
    }

    /// Update Siri phrase suggestions
    @available(iOS 16.0, *)
    public func updateShortcutSuggestions() {
        // Shortcuts are automatically suggested based on AppShortcutsProvider
        // This method can be used for additional donation logic
    }

    public enum ShortcutDonationType {
        case startInterpretation(source: SupportedLanguage, target: SupportedLanguage)
        case stopInterpretation
        case switchLanguages
    }
}

// MARK: - Shortcut Phrase Suggestions

/// Suggested phrases for Siri shortcuts in multiple languages
public struct ShortcutPhraseSuggestions: Sendable {
    public static let startInterpretation: [String: [String]] = [
        "en": [
            "Start interpreting",
            "Begin interpretation",
            "Translate for me"
        ],
        "ja": [
            "通訳を開始",
            "翻訳して",
            "通訳をお願い"
        ]
    ]

    public static let stopInterpretation: [String: [String]] = [
        "en": [
            "Stop interpreting",
            "End interpretation",
            "Stop translation"
        ],
        "ja": [
            "通訳を停止",
            "翻訳を止めて",
            "終わり"
        ]
    ]

    public static let switchLanguages: [String: [String]] = [
        "en": [
            "Switch languages",
            "Swap languages",
            "Change direction"
        ],
        "ja": [
            "言語を切り替え",
            "言語を入れ替え",
            "方向を変えて"
        ]
    ]
}
