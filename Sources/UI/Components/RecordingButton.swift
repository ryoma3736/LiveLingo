import SwiftUI

// MARK: - Recording Button

/// Animated recording button for starting/stopping speech recognition
public struct RecordingButton: View {
    @Binding public var isRecording: Bool
    public let onTap: () -> Void

    @State private var animationAmount: CGFloat = 1.0

    public init(isRecording: Binding<Bool>, onTap: @escaping () -> Void) {
        self._isRecording = isRecording
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer ring (animates when recording)
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(isRecording ? .red.opacity(0.5) : DesignSystem.Colors.primaryFallback.opacity(0.3))
                    .scaleEffect(isRecording ? animationAmount : 1.0)
                    .opacity(isRecording ? (2 - animationAmount) : 1.0)
                    .frame(width: 80, height: 80)

                // Inner circle
                Circle()
                    .fill(isRecording ? Color.red : DesignSystem.Colors.primaryFallback)
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: isRecording ? .red.opacity(0.4) : DesignSystem.Colors.primaryFallback.opacity(0.4),
                        radius: 8,
                        y: 4
                    )

                // Icon
                Image(systemName: isRecording ? DesignSystem.Icons.microphoneSlash : DesignSystem.Icons.microphone)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
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
