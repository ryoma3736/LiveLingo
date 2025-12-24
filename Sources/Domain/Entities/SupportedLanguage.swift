import Foundation

/// Supported languages for interpretation
public enum SupportedLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case japanese = "ja-JP"
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"
    case korean = "ko-KR"
    case vietnamese = "vi-VN"
    case portuguese = "pt-BR"

    public var id: String { rawValue }

    /// Display name in the language itself
    public var nativeName: String {
        switch self {
        case .japanese: return "日本語"
        case .englishUS: return "English (US)"
        case .englishUK: return "English (UK)"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .korean: return "한국어"
        case .vietnamese: return "Tiếng Việt"
        case .portuguese: return "Português"
        }
    }

    /// Localized display name
    public var localizedName: String {
        Locale.current.localizedString(forIdentifier: rawValue) ?? nativeName
    }

    /// Flag emoji (for display purposes - SVG preferred in production)
    public var flagEmoji: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .englishUS: return "🇺🇸"
        case .englishUK: return "🇬🇧"
        case .chineseSimplified: return "🇨🇳"
        case .chineseTraditional: return "🇹🇼"
        case .korean: return "🇰🇷"
        case .vietnamese: return "🇻🇳"
        case .portuguese: return "🇧🇷"
        }
    }

    /// BCP 47 language code
    public var languageCode: String {
        String(rawValue.prefix(2))
    }

    /// Locale for this language
    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Whether on-device translation is supported
    public var supportsOnDeviceTranslation: Bool {
        // Phase 1 languages
        switch self {
        case .japanese, .englishUS, .chineseSimplified, .korean:
            return true
        default:
            return false
        }
    }
}

/// Speaker identification in bidirectional mode
public enum SpeakerID: String, Codable, Sendable {
    case speaker1 = "speaker_1"
    case speaker2 = "speaker_2"
    case unknown = "unknown"
}
