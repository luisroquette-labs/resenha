import SwiftUI

enum RecordingResonance {
    static func normalized(_ level: Float) -> CGFloat {
        level.isFinite ? CGFloat(max(0, min(1, level))) : 0
    }

    static func markScale(level: Float, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : 0.84 + normalized(level) * 0.32
    }

    static func haloScale(level: Float, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : 1 + normalized(level) * 0.52
    }

    static func haloOpacity(level: Float, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 0 : normalized(level) * 0.30
    }

    static func menuStep(level: Float) -> Int {
        Int((normalized(level) * 4).rounded())
    }
}

struct RecordingMeter: Equatable {
    static let barCount = 48
    private(set) var levels = Array(repeating: Float.zero, count: barCount)
    private(set) var currentLevel: Float = 0
    private(set) var elapsedSeconds = 0
    private var startedAt: TimeInterval?
    var isRecording: Bool { startedAt != nil }
    var elapsedText: String { String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60) }

    static func normalizedDecibels(_ power: Float) -> Float {
        power.isFinite ? max(0, min(1, (power + 60) / 60)) : 0
    }

    mutating func start(at now: TimeInterval) {
        self = Self()
        startedAt = now.isFinite ? now : 0
    }

    mutating func append(level: Float, at now: TimeInterval) {
        guard let startedAt else { return }
        let target = level.isFinite ? max(0, min(1, level)) : 0
        let coefficient: Float = target > currentLevel ? 0.65 : 0.18
        currentLevel += (target - currentLevel) * coefficient
        levels.removeFirst()
        levels.append(currentLevel)
        if now.isFinite, let seconds = Int(exactly: max(0, floor(now - startedAt))) {
            elapsedSeconds = max(elapsedSeconds, seconds)
        }
    }

    func displayLevels(reduceMotion: Bool) -> [Float] {
        reduceMotion ? Array(repeating: currentLevel, count: Self.barCount) : levels
    }
}

struct RecordingWaveformView: View {
    let meter: RecordingMeter
    var fixtureReduceMotion: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            resonatingMark
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle().fill(ResenhaTheme.signal).frame(width: 7, height: 7)
                    Text("Ouvindo").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Text(meter.elapsedText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
            let levels = meter.displayLevels(reduceMotion: fixtureReduceMotion ?? reduceMotion)
            HStack(spacing: 1.5) {
                ForEach(0..<RecordingMeter.barCount, id: \.self) { index in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.primary.opacity(0.72), ResenhaTheme.signal],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3 + CGFloat(levels[index]) * 29)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
        }
        .foregroundStyle(.primary)
        .transaction { $0.animation = nil }
        .accessibilityHidden(true)
    }

    private var resonatingMark: some View {
        let shouldReduceMotion = fixtureReduceMotion ?? reduceMotion
        let level = RecordingResonance.normalized(meter.currentLevel)
        return ZStack {
            Circle()
                .fill(Color(red: 0.36, green: 0.24, blue: 0.95)
                    .opacity(0.22 + Double(RecordingResonance.haloOpacity(
                        level: meter.currentLevel, reduceMotion: shouldReduceMotion
                    ))))
                .blur(radius: 7)
                .scaleEffect(RecordingResonance.haloScale(
                    level: meter.currentLevel, reduceMotion: shouldReduceMotion
                ))
            Circle()
                .fill(AngularGradient(
                    colors: [
                        Color(red: 0.61, green: 0.26, blue: 1),
                        Color(red: 0.30, green: 0.76, blue: 0.91),
                        Color(red: 0.06, green: 0.08, blue: 0.60),
                        Color(red: 0.61, green: 0.26, blue: 1)
                    ],
                    center: .center
                ))
                .overlay {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.78), .clear],
                            center: .init(x: 0.37, y: 0.32),
                            startRadius: 0,
                            endRadius: 24
                        ))
                }
                .scaleEffect(RecordingResonance.markScale(level: meter.currentLevel, reduceMotion: shouldReduceMotion))
                .rotationEffect(.degrees(shouldReduceMotion ? 0 : Double(level) * 90))
                .shadow(color: Color(red: 0.30, green: 0.76, blue: 0.91).opacity(0.35), radius: 5)
        }
        .frame(width: 44, height: 44)
    }
}
