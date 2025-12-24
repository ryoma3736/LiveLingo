import SwiftUI

// MARK: - Design System

/// LiveLingo Design System
public enum DesignSystem {
    // MARK: - Colors

    public enum Colors {
        // Primary Colors
        public static let primary = Color("Primary", bundle: .main)
        public static let primaryLight = Color("PrimaryLight", bundle: .main)
        public static let primaryDark = Color("PrimaryDark", bundle: .main)

        // Fallback colors for when assets aren't available
        public static var primaryFallback: Color { Color(hex: "007AFF") }
        public static var secondaryFallback: Color { Color(hex: "5856D6") }

        // Semantic Colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue

        // Background Colors
        public static let background = Color(uiColor: .systemBackground)
        public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

        // Text Colors
        public static let textPrimary = Color(uiColor: .label)
        public static let textSecondary = Color(uiColor: .secondaryLabel)
        public static let textTertiary = Color(uiColor: .tertiaryLabel)

        // Speaker Colors
        public static let speaker1 = Color.blue
        public static let speaker2 = Color.purple

        public static func speaker(_ id: SpeakerID) -> Color {
            switch id {
            case .speaker1:
                return speaker1
            case .speaker2:
                return speaker2
            case .unknown:
                return .gray
            }
        }
    }

    // MARK: - Typography

    public enum Typography {
        public static let largeTitle = Font.largeTitle.weight(.bold)
        public static let title1 = Font.title.weight(.semibold)
        public static let title2 = Font.title2.weight(.semibold)
        public static let title3 = Font.title3.weight(.medium)
        public static let headline = Font.headline
        public static let body = Font.body
        public static let callout = Font.callout
        public static let subheadline = Font.subheadline
        public static let footnote = Font.footnote
        public static let caption1 = Font.caption
        public static let caption2 = Font.caption2

        // Custom sizes for transcript display
        public static let transcriptText = Font.system(size: 18, weight: .regular, design: .default)
        public static let translationText = Font.system(size: 16, weight: .regular, design: .default)
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let extraLarge: CGFloat = 16
        public static let pill: CGFloat = 9999
    }

    // MARK: - Shadow

    public enum Shadow {
        public static let small = ShadowStyle(radius: 2, y: 1, opacity: 0.1)
        public static let medium = ShadowStyle(radius: 4, y: 2, opacity: 0.15)
        public static let large = ShadowStyle(radius: 8, y: 4, opacity: 0.2)
    }

    // MARK: - Animation

    public enum Animation {
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        public static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Icons

    public enum Icons {
        public static let microphone = "mic.fill"
        public static let microphoneSlash = "mic.slash.fill"
        public static let speaker = "speaker.wave.2.fill"
        public static let speakerSlash = "speaker.slash.fill"
        public static let play = "play.fill"
        public static let pause = "pause.fill"
        public static let stop = "stop.fill"
        public static let settings = "gearshape.fill"
        public static let history = "clock.fill"
        public static let language = "globe"
        public static let swap = "arrow.left.arrow.right"
        public static let close = "xmark"
        public static let checkmark = "checkmark"
        public static let warning = "exclamationmark.triangle.fill"
        public static let error = "xmark.circle.fill"
        public static let info = "info.circle.fill"
        public static let copy = "doc.on.doc"
        public static let share = "square.and.arrow.up"
        public static let trash = "trash.fill"
        public static let edit = "pencil"
        public static let add = "plus"
    }
}

// MARK: - Shadow Style

public struct ShadowStyle {
    public let radius: CGFloat
    public let y: CGFloat
    public let opacity: Double

    public init(radius: CGFloat, y: CGFloat, opacity: Double) {
        self.radius = radius
        self.y = y
        self.opacity = opacity
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    public func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadow(
                color: .black.opacity(DesignSystem.Shadow.small.opacity),
                radius: DesignSystem.Shadow.small.radius,
                y: DesignSystem.Shadow.small.y
            )
    }

    public func primaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primaryFallback)
            .cornerRadius(DesignSystem.CornerRadius.pill)
    }

    public func secondaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.primaryFallback)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primaryFallback.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.pill)
    }
}
