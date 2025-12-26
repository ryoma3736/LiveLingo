import SwiftUI
import UIKit

// MARK: - Device Size Category

/// iPhone screen size categories for adaptive layout
/// Covers all iPhone models from SE to Pro Max
public enum DeviceSizeCategory: CaseIterable {
    case compact      // iPhone SE, iPhone mini (320-375pt width)
    case standard     // iPhone 14/15 base models (390pt width)
    case large        // iPhone Plus/Pro Max (428-430pt width)

    /// Determine category from screen width
    public static func from(width: CGFloat) -> DeviceSizeCategory {
        switch width {
        case ..<380:
            return .compact
        case 380..<415:
            return .standard
        default:
            return .large
        }
    }

    /// Determine category from screen height (for portrait orientation)
    public static func from(height: CGFloat) -> DeviceSizeCategory {
        switch height {
        case ..<700:
            return .compact   // iPhone SE (667pt)
        case 700..<860:
            return .standard  // iPhone 14 (844pt), iPhone 15 (852pt)
        default:
            return .large     // iPhone Plus/Pro Max (926-932pt)
        }
    }
}

// MARK: - Adaptive Layout Values

/// Provides adaptive values based on device size category
public struct AdaptiveLayout {
    public let category: DeviceSizeCategory

    public init(category: DeviceSizeCategory) {
        self.category = category
    }

    // MARK: - Font Sizes

    /// Adaptive font size for primary text (transcripts, translations)
    public var primaryFontSize: CGFloat {
        switch category {
        case .compact:
            return 15
        case .standard:
            return 17
        case .large:
            return 19
        }
    }

    /// Adaptive font size for secondary text (timestamps, labels)
    public var secondaryFontSize: CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 14
        case .large:
            return 15
        }
    }

    /// Adaptive font size for flag emojis
    public var flagEmojiSize: CGFloat {
        switch category {
        case .compact:
            return 20
        case .standard:
            return 24
        case .large:
            return 28
        }
    }

    /// Adaptive font size for button labels
    public var buttonFontSize: CGFloat {
        switch category {
        case .compact:
            return 14
        case .standard:
            return 16
        case .large:
            return 17
        }
    }

    // MARK: - Control Bar Heights

    /// Adaptive control bar height for portrait mode
    public var controlBarHeight: CGFloat {
        switch category {
        case .compact:
            return 64
        case .standard:
            return 80
        case .large:
            return 88
        }
    }

    /// Adaptive control bar width for landscape mode
    public var controlBarWidth: CGFloat {
        switch category {
        case .compact:
            return 64
        case .standard:
            return 80
        case .large:
            return 88
        }
    }

    // MARK: - Panel Ratios

    /// Translation panel ratio (top panel in portrait)
    public var translationPanelRatio: CGFloat {
        switch category {
        case .compact:
            return 0.45  // Smaller top panel for compact screens
        case .standard:
            return 0.48
        case .large:
            return 0.50  // Equal split for large screens
        }
    }

    /// Original panel ratio (bottom panel in portrait)
    public var originalPanelRatio: CGFloat {
        return 1.0 - translationPanelRatio - controlBarRatio
    }

    /// Control bar ratio in portrait
    private var controlBarRatio: CGFloat {
        switch category {
        case .compact:
            return 0.12
        case .standard:
            return 0.10
        case .large:
            return 0.09
        }
    }

    // MARK: - Spacing

    /// Adaptive horizontal padding
    public var horizontalPadding: CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 16
        case .large:
            return 20
        }
    }

    /// Adaptive vertical padding
    public var verticalPadding: CGFloat {
        switch category {
        case .compact:
            return 8
        case .standard:
            return 12
        case .large:
            return 16
        }
    }

    /// Adaptive button padding (horizontal)
    public var buttonHorizontalPadding: CGFloat {
        switch category {
        case .compact:
            return 14
        case .standard:
            return 20
        case .large:
            return 24
        }
    }

    /// Adaptive button padding (vertical)
    public var buttonVerticalPadding: CGFloat {
        switch category {
        case .compact:
            return 8
        case .standard:
            return 12
        case .large:
            return 14
        }
    }

    /// Adaptive bubble spacing
    public var bubbleSpacing: CGFloat {
        switch category {
        case .compact:
            return 8
        case .standard:
            return 12
        case .large:
            return 14
        }
    }

    // MARK: - Button Sizes

    /// Adaptive circular button size (mute, menu)
    public var circularButtonSize: CGFloat {
        switch category {
        case .compact:
            return 40
        case .standard:
            return 48
        case .large:
            return 52
        }
    }

    /// Adaptive corner radius for bubbles
    public var bubbleCornerRadius: CGFloat {
        switch category {
        case .compact:
            return 10
        case .standard:
            return 12
        case .large:
            return 14
        }
    }

    /// Adaptive corner radius for buttons
    public var buttonCornerRadius: CGFloat {
        switch category {
        case .compact:
            return 20
        case .standard:
            return 24
        case .large:
            return 28
        }
    }
}

// MARK: - Safe Area Detection

/// Safe area information for adaptive layouts
public struct SafeAreaInfo {
    public let top: CGFloat
    public let bottom: CGFloat
    public let leading: CGFloat
    public let trailing: CGFloat

    /// Check if device has Dynamic Island or notch
    public var hasDynamicIslandOrNotch: Bool {
        top > 44
    }

    /// Check if device has home indicator
    public var hasHomeIndicator: Bool {
        bottom > 20
    }

    /// Effective safe area considering device type
    public var effectiveTopPadding: CGFloat {
        hasDynamicIslandOrNotch ? top : 20
    }

    /// Effective bottom padding
    public var effectiveBottomPadding: CGFloat {
        hasHomeIndicator ? bottom : 20
    }
}

// MARK: - Environment Key

private struct DeviceSizeCategoryKey: EnvironmentKey {
    static let defaultValue: DeviceSizeCategory = .standard
}

private struct AdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue: AdaptiveLayout = AdaptiveLayout(category: .standard)
}

extension EnvironmentValues {
    public var deviceSizeCategory: DeviceSizeCategory {
        get { self[DeviceSizeCategoryKey.self] }
        set { self[DeviceSizeCategoryKey.self] = newValue }
    }

    public var adaptiveLayout: AdaptiveLayout {
        get { self[AdaptiveLayoutKey.self] }
        set { self[AdaptiveLayoutKey.self] = newValue }
    }
}

// MARK: - View Modifier

/// Modifier that injects device size category into environment
public struct DeviceSizeModifier: ViewModifier {
    @State private var sizeCategory: DeviceSizeCategory = .standard

    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .onAppear {
                    updateCategory(from: geometry)
                }
                .onChange(of: geometry.size) { _, newSize in
                    updateCategory(width: newSize.width, height: newSize.height)
                }
                .environment(\.deviceSizeCategory, sizeCategory)
                .environment(\.adaptiveLayout, AdaptiveLayout(category: sizeCategory))
        }
    }

    private func updateCategory(from geometry: GeometryProxy) {
        updateCategory(width: geometry.size.width, height: geometry.size.height)
    }

    private func updateCategory(width: CGFloat, height: CGFloat) {
        // Use height for portrait, width for landscape
        if height > width {
            sizeCategory = DeviceSizeCategory.from(height: height)
        } else {
            sizeCategory = DeviceSizeCategory.from(width: height) // Use the smaller dimension
        }
    }
}

extension View {
    /// Apply device size detection to this view
    public func withDeviceSizeDetection() -> some View {
        self.modifier(DeviceSizeModifier())
    }
}

// MARK: - Preview Helper

#if DEBUG
struct DeviceSizePreview: View {
    @Environment(\.deviceSizeCategory) private var category
    @Environment(\.adaptiveLayout) private var layout

    var body: some View {
        VStack(spacing: 20) {
            Text("Device Category: \(String(describing: category))")
                .font(.system(size: layout.primaryFontSize))

            Text("Primary Font: \(Int(layout.primaryFontSize))pt")
            Text("Control Bar: \(Int(layout.controlBarHeight))pt")
            Text("Button Size: \(Int(layout.circularButtonSize))pt")

            HStack(spacing: layout.bubbleSpacing) {
                Text("🇺🇸")
                    .font(.system(size: layout.flagEmojiSize))
                Text("/")
                Text("🇯🇵")
                    .font(.system(size: layout.flagEmojiSize))
            }
            .padding(.horizontal, layout.buttonHorizontalPadding)
            .padding(.vertical, layout.buttonVerticalPadding)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(layout.buttonCornerRadius)
        }
        .padding()
    }
}

struct DeviceSize_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DeviceSizePreview()
                .withDeviceSizeDetection()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE (Compact)")

            DeviceSizePreview()
                .withDeviceSizeDetection()
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone 15 (Standard)")

            DeviceSizePreview()
                .withDeviceSizeDetection()
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max (Large)")
        }
    }
}
#endif
