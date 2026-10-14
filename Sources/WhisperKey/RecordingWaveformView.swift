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
            voiceOrb
            listeningSummary
        }
        .foregroundStyle(.primary)
        .transaction { $0.animation = nil }
        .accessibilityHidden(true)
    }

    private var listeningSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(ResenhaTheme.signal).frame(width: 7, height: 7)
                Text("Ouvindo").font(.caption.weight(.semibold))
            }
            Text(meter.elapsedText)
                .font(.title3.weight(.medium).monospaced())
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var voiceOrb: some View {
        let shouldReduceMotion = fixtureReduceMotion ?? reduceMotion
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: shouldReduceMotion)) { timeline in
            VoiceOrbView(
                level: shouldReduceMotion ? 0 : RecordingResonance.normalized(meter.currentLevel),
                time: shouldReduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            )
        }
        .frame(width: 64, height: 64)
    }
}

private struct VoiceOrbRing: Shape {
    let level: CGFloat
    let time: TimeInterval

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.34
        let wave = 1.5 + level * 4
        let phase = CGFloat(time)
        var path = Path()
        for index in 0...120 {
            let angle = CGFloat(index) * .pi / 60
            let radius = baseRadius + wave * (
                0.55 * sin(angle * 3 + phase * 1.3) +
                0.30 * sin(angle * 5 - phase * 0.8) +
                0.15 * sin(angle * 9 + phase * 1.7)
            )
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct VoiceOrbView: View {
    let level: CGFloat
    let time: TimeInterval

    private var colors: [Color] {
        [Color(red: 0.61, green: 0.26, blue: 1),
         Color(red: 0.30, green: 0.76, blue: 0.91),
         Color(red: 0.06, green: 0.08, blue: 0.60),
         Color(red: 0.88, green: 0.30, blue: 0.91),
         Color(red: 0.61, green: 0.26, blue: 1)]
    }

    var body: some View {
        let phase = CGFloat(time)
        let gradient = AngularGradient(colors: colors, center: .center, angle: .radians(time * 0.7))
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.clear, colors[2].opacity(0.65), .clear],
                                     center: .center, startRadius: 5, endRadius: 32))
            VoiceOrbRing(level: level, time: time)
                .stroke(gradient, lineWidth: 15 + level * 4)
                .blur(radius: 6)
                .opacity(0.7)
            VoiceOrbRing(level: level, time: time)
                .stroke(gradient, lineWidth: 9 + level * 3)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 5 + level * 4, height: 5 + level * 4)
                .blur(radius: 2)
                .offset(x: 21 * cos(phase), y: 21 * sin(phase))
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}
