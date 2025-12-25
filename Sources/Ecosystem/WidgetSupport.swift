import Foundation
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry

/// Timeline entry for LiveLingo widgets
public struct LiveLingoWidgetEntry: TimelineEntry {
    public let date: Date
    public let configuration: LiveLingoWidgetConfiguration
    public let state: WidgetState

    public init(
        date: Date,
        configuration: LiveLingoWidgetConfiguration,
        state: WidgetState
    ) {
        self.date = date
        self.configuration = configuration
        self.state = state
    }
}

// MARK: - Widget State

/// Current state of the app for widget display
public struct WidgetState: Sendable {
    public let isInterpreting: Bool
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let recentTranslations: [WidgetTranslation]

    public init(
        isInterpreting: Bool = false,
        sourceLanguage: SupportedLanguage = .japanese,
        targetLanguage: SupportedLanguage = .englishUS,
        recentTranslations: [WidgetTranslation] = []
    ) {
        self.isInterpreting = isInterpreting
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.recentTranslations = recentTranslations
    }

    public static let placeholder = WidgetState()
}

/// Translation item for widget display
public struct WidgetTranslation: Sendable, Identifiable {
    public let id: UUID
    public let original: String
    public let translated: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        original: String,
        translated: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.original = original
        self.translated = translated
        self.timestamp = timestamp
    }
}

// MARK: - Widget Configuration

/// Configuration options for the widget
public struct LiveLingoWidgetConfiguration: Sendable {
    public let sourceLanguage: SupportedLanguage?
    public let targetLanguage: SupportedLanguage?
    public let showRecentTranslations: Bool

    public init(
        sourceLanguage: SupportedLanguage? = nil,
        targetLanguage: SupportedLanguage? = nil,
        showRecentTranslations: Bool = true
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.showRecentTranslations = showRecentTranslations
    }

    public static let `default` = LiveLingoWidgetConfiguration()
}

// MARK: - Timeline Provider

/// Provides timeline entries for the widget
public struct LiveLingoTimelineProvider: TimelineProvider {
    public typealias Entry = LiveLingoWidgetEntry

    public init() {}

    public func placeholder(in context: Context) -> Entry {
        LiveLingoWidgetEntry(
            date: Date(),
            configuration: .default,
            state: .placeholder
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let entry = LiveLingoWidgetEntry(
            date: Date(),
            configuration: .default,
            state: loadCurrentState()
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let state = loadCurrentState()

        // Create entries for the next hour
        var entries: [Entry] = []

        for minuteOffset in stride(from: 0, to: 60, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = LiveLingoWidgetEntry(
                date: entryDate,
                configuration: .default,
                state: state
            )
            entries.append(entry)
        }

        // Refresh after an hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadCurrentState() -> WidgetState {
        // Load state from shared container
        let defaults = UserDefaults(suiteName: "group.com.livelingo.shared")

        let isInterpreting = defaults?.bool(forKey: "widget.isInterpreting") ?? false
        let sourceRaw = defaults?.string(forKey: "widget.sourceLanguage") ?? "ja-JP"
        let targetRaw = defaults?.string(forKey: "widget.targetLanguage") ?? "en-US"

        let sourceLanguage = SupportedLanguage(rawValue: sourceRaw) ?? .japanese
        let targetLanguage = SupportedLanguage(rawValue: targetRaw) ?? .englishUS

        // Load recent translations
        var recentTranslations: [WidgetTranslation] = []
        if let translationsData = defaults?.data(forKey: "widget.recentTranslations"),
           let translations = try? JSONDecoder().decode([StoredTranslation].self, from: translationsData) {
            recentTranslations = translations.map { stored in
                WidgetTranslation(
                    id: stored.id,
                    original: stored.original,
                    translated: stored.translated,
                    timestamp: stored.timestamp
                )
            }
        }

        return WidgetState(
            isInterpreting: isInterpreting,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            recentTranslations: recentTranslations
        )
    }
}

// MARK: - Stored Translation (for UserDefaults)

private struct StoredTranslation: Codable {
    let id: UUID
    let original: String
    let translated: String
    let timestamp: Date
}

// MARK: - Widget Data Manager

/// Manages data shared between app and widget
public actor WidgetDataManager {
    public static let shared = WidgetDataManager()

    private let defaults: UserDefaults?
    private let maxRecentTranslations = 5

    private init() {
        self.defaults = UserDefaults(suiteName: "group.com.livelingo.shared")
    }

    /// Update interpretation state
    public func updateInterpretationState(_ isInterpreting: Bool) {
        defaults?.set(isInterpreting, forKey: "widget.isInterpreting")
        reloadWidget()
    }

    /// Update language pair
    public func updateLanguages(source: SupportedLanguage, target: SupportedLanguage) {
        defaults?.set(source.rawValue, forKey: "widget.sourceLanguage")
        defaults?.set(target.rawValue, forKey: "widget.targetLanguage")
        reloadWidget()
    }

    /// Add a new translation
    public func addTranslation(original: String, translated: String) {
        var translations = loadStoredTranslations()

        let newTranslation = StoredTranslation(
            id: UUID(),
            original: original,
            translated: translated,
            timestamp: Date()
        )

        translations.insert(newTranslation, at: 0)

        // Keep only recent translations
        if translations.count > maxRecentTranslations {
            translations = Array(translations.prefix(maxRecentTranslations))
        }

        saveStoredTranslations(translations)
        reloadWidget()
    }

    /// Clear all translations
    public func clearTranslations() {
        defaults?.removeObject(forKey: "widget.recentTranslations")
        reloadWidget()
    }

    private func loadStoredTranslations() -> [StoredTranslation] {
        guard let data = defaults?.data(forKey: "widget.recentTranslations"),
              let translations = try? JSONDecoder().decode([StoredTranslation].self, from: data) else {
            return []
        }
        return translations
    }

    private func saveStoredTranslations(_ translations: [StoredTranslation]) {
        if let data = try? JSONEncoder().encode(translations) {
            defaults?.set(data, forKey: "widget.recentTranslations")
        }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "LiveLingoWidget")
    }
}

// MARK: - Widget Views

/// Small widget view - Quick launch button
public struct SmallWidgetView: View {
    let entry: LiveLingoWidgetEntry

    public init(entry: LiveLingoWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.state.isInterpreting ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 40))
                .foregroundColor(entry.state.isInterpreting ? .green : .blue)

            Text(entry.state.isInterpreting ? "Interpreting..." : "Tap to Start")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text(entry.state.sourceLanguage.flagEmoji)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(entry.state.targetLanguage.flagEmoji)
            }
            .font(.caption)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Medium widget view - Recent translations
public struct MediumWidgetView: View {
    let entry: LiveLingoWidgetEntry

    public init(entry: LiveLingoWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.state.isInterpreting ? "waveform.circle.fill" : "waveform.circle")
                    .foregroundColor(entry.state.isInterpreting ? .green : .blue)

                Text("LiveLingo")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Text(entry.state.sourceLanguage.flagEmoji)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(entry.state.targetLanguage.flagEmoji)
                }
            }

            if entry.state.recentTranslations.isEmpty {
                Text("No recent translations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(entry.state.recentTranslations.prefix(2)) { translation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(translation.original)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(translation.translated)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Large widget view - Full controls
public struct LargeWidgetView: View {
    let entry: LiveLingoWidgetEntry

    public init(entry: LiveLingoWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("LiveLingo")
                    .font(.headline)

                Spacer()

                if entry.state.isInterpreting {
                    Label("Active", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Language selection (iOS 17+ interactive)
            HStack(spacing: 16) {
                WidgetLanguageButton(language: entry.state.sourceLanguage, label: "From")
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)
                WidgetLanguageButton(language: entry.state.targetLanguage, label: "To")
            }

            Divider()

            // Recent translations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if entry.state.recentTranslations.isEmpty {
                    Text("No recent translations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entry.state.recentTranslations.prefix(3)) { translation in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(translation.original)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text(translation.translated)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(translation.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Language selection button
private struct WidgetLanguageButton: View {
    let language: SupportedLanguage
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(language.flagEmoji)
                .font(.title2)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(language.languageCode.uppercased())
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - App Intents for Interactive Widgets (iOS 17+)

@available(iOS 17.0, *)
public struct StartInterpretationWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Interpretation"
    public static var description = IntentDescription("Start real-time interpretation")

    public init() {}

    public func perform() async throws -> some IntentResult {
        // This would trigger the app to start interpretation
        await WidgetDataManager.shared.updateInterpretationState(true)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct StopInterpretationWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Stop Interpretation"
    public static var description = IntentDescription("Stop real-time interpretation")

    public init() {}

    public func perform() async throws -> some IntentResult {
        await WidgetDataManager.shared.updateInterpretationState(false)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct SwapLanguagesWidgetIntent: AppIntent {
    public static var title: LocalizedStringResource = "Swap Languages"
    public static var description = IntentDescription("Swap source and target languages")

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Load current languages and swap
        let defaults = UserDefaults(suiteName: "group.com.livelingo.shared")
        let sourceRaw = defaults?.string(forKey: "widget.sourceLanguage") ?? "ja-JP"
        let targetRaw = defaults?.string(forKey: "widget.targetLanguage") ?? "en-US"

        guard let source = SupportedLanguage(rawValue: sourceRaw),
              let target = SupportedLanguage(rawValue: targetRaw) else {
            return .result()
        }

        await WidgetDataManager.shared.updateLanguages(source: target, target: source)
        return .result()
    }
}
