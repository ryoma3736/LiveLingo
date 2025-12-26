import SwiftUI
import UIKit

// MARK: - Recording Button

/// Animated recording button for starting/stopping speech recognition
/// Features: Haptic feedback, smooth animations, audio level visualization
public struct RecordingButton: View {
    @Binding public var isRecording: Bool
    public let onTap: () -> Void

    /// Optional audio levels for integrated waveform display
    public var audioLevels: [Float]?

    @State private var animationAmount: CGFloat = 1.0
    @State private var pressScale: CGFloat = 1.0
    @State private var isPressed: Bool = false

    // Haptic feedback generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    public init(isRecording: Binding<Bool>, audioLevels: [Float]? = nil, onTap: @escaping () -> Void) {
        self._isRecording = isRecording
        self.audioLevels = audioLevels
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            triggerHapticFeedback()
            onTap()
        }) {
            ZStack {
                // Outer pulse rings (multiple layers when recording)
                if isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(lineWidth: 2)
                            .foregroundColor(.red.opacity(0.3 - Double(index) * 0.1))
                            .scaleEffect(animationAmount + CGFloat(index) * 0.15)
                            .opacity(2 - animationAmount - Double(index) * 0.2)
                            .frame(width: 80, height: 80)
                    }
                }

                // Outer ring (static when not recording)
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(isRecording ? .red.opacity(0.5) : DesignSystem.Colors.primaryFallback.opacity(0.3))
                    .scaleEffect(isRecording ? animationAmount : 1.0)
                    .opacity(isRecording ? (2 - animationAmount) : 1.0)
                    .frame(width: 80, height: 80)

                // Inner circle with press animation
                Circle()
                    .fill(isRecording ? Color.red : DesignSystem.Colors.primaryFallback)
                    .frame(width: 64, height: 64)
                    .scaleEffect(pressScale)
                    .shadow(
                        color: isRecording ? .red.opacity(0.4) : DesignSystem.Colors.primaryFallback.opacity(0.4),
                        radius: isPressed ? 4 : 8,
                        y: isPressed ? 2 : 4
                    )

                // Integrated mini waveform inside button when recording
                if isRecording, let levels = audioLevels, !levels.isEmpty {
                    MiniWaveformView(levels: Array(levels.suffix(5)))
                        .frame(width: 36, height: 20)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Icon
                    Image(systemName: isRecording ? DesignSystem.Icons.microphoneSlash : DesignSystem.Icons.microphone)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            pressScale = 0.92
                        }
                        selectionFeedback.selectionChanged()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        pressScale = 1.0
                    }
                }
        )
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
                notificationFeedback.notificationOccurred(.success)
            } else {
                stopPulseAnimation()
                notificationFeedback.notificationOccurred(.warning)
            }
        }
        .onAppear {
            // Prepare haptic generators for reduced latency
            impactFeedback.prepare()
            selectionFeedback.prepare()
            notificationFeedback.prepare()
        }
    }

    private func triggerHapticFeedback() {
        impactFeedback.impactOccurred()
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            animationAmount = 1.3
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            animationAmount = 1.0
        }
    }
}

// MARK: - Mini Waveform View (inside button)

/// Compact waveform visualization for inside the recording button
private struct MiniWaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: CGFloat(4 + level * 16))
                    .animation(
                        .spring(response: 0.15, dampingFraction: 0.6),
                        value: level
                    )
            }
        }
    }
}

// MARK: - Audio Level Indicator

/// Visual indicator for audio input level
public struct AudioLevelIndicator: View {
    public let level: Float
    public let barCount: Int

    @State private var animatedLevels: [Float] = []

    public init(level: Float, barCount: Int = 5) {
        self.level = level
        self.barCount = barCount
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(DesignSystem.Animation.quick, value: level)
            }
        }
        .frame(height: 32)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        let normalizedLevel = min(max(level, 0), 1)

        if normalizedLevel > threshold {
            return CGFloat(12 + (normalizedLevel - threshold) * 20)
        } else {
            return 8
        }
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)

        if level > threshold {
            if index >= barCount - 1 {
                return .red
            } else if index >= barCount - 2 {
                return .orange
            } else {
                return .green
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Waveform View

/// Animated waveform visualization
public struct WaveformView: View {
    public let levels: [Float]
    public let color: Color

    public init(levels: [Float], color: Color = .blue) {
        self.levels = levels
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(Double(0.5 + level * 0.5)))
                    .frame(width: 3, height: CGFloat(4 + level * 28))
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7)
                        .delay(Double(index) * 0.02),
                        value: level
                    )
            }
        }
        .frame(height: 32)
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            RecordingButton(isRecording: .constant(false)) {}

            RecordingButton(isRecording: .constant(true)) {}

            AudioLevelIndicator(level: 0.6)

            WaveformView(
                levels: [0.2, 0.5, 0.8, 0.3, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3],
                color: .blue
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
