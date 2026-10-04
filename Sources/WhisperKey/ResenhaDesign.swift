import AppKit
import SwiftUI

struct ResenhaRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
    }

    var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(against other: Self) -> Double {
        let light = max(relativeLuminance, other.relativeLuminance)
        let dark = min(relativeLuminance, other.relativeLuminance)
        return (light + 0.05) / (dark + 0.05)
    }
}

enum ResenhaTheme {
    static let lightAccentRGB = ResenhaRGB(hex: 0x416D64)
    static let darkAccentRGB = ResenhaRGB(hex: 0x8CB8AE)
    static let lightPaperRGB = ResenhaRGB(hex: 0xF1EEE4)
    static let lightCanvasEndRGB = ResenhaRGB(hex: 0xE3E8DE)
    static let darkInkRGB = ResenhaRGB(hex: 0x181B1A)
    static let darkCanvasStartRGB = ResenhaRGB(hex: 0x171B1A)
    static let darkCanvasEndRGB = ResenhaRGB(hex: 0x111312)
    static let lightSuccessRGB = ResenhaRGB(hex: 0x3B6E5E)
    static let darkSuccessRGB = ResenhaRGB(hex: 0x8BC4A9)
    static let lightWarningRGB = ResenhaRGB(hex: 0x86502C)
    static let darkWarningRGB = ResenhaRGB(hex: 0xF0B37E)
    static let lightHighContrastAccentRGB = ResenhaRGB(hex: 0x365C54)
    static let darkHighContrastAccentRGB = ResenhaRGB(hex: 0xB0DCD2)
    static let lightHighContrastSuccessRGB = ResenhaRGB(hex: 0x315D50)
    static let darkHighContrastSuccessRGB = ResenhaRGB(hex: 0xA9E0C5)
    static let lightHighContrastWarningRGB = ResenhaRGB(hex: 0x754221)
    static let darkHighContrastWarningRGB = ResenhaRGB(hex: 0xFFD0A2)

    static let accent = adaptive(
        light: lightAccentRGB,
        dark: darkAccentRGB,
        lightHighContrast: lightHighContrastAccentRGB,
        darkHighContrast: darkHighContrastAccentRGB
    )
    static let accentSoft = adaptive(light: ResenhaRGB(hex: 0xB7D1CB), dark: ResenhaRGB(hex: 0x35564F))
    static let controlTintRGB = ResenhaRGB(hex: 0x47786E)
    static let controlTint = color(controlTintRGB)
    static let signal = accent
    static let ink = color(darkInkRGB)
    static let paper = color(lightPaperRGB)
    static let fog = Color(red: 0.80, green: 0.85, blue: 0.82)
    static let success = adaptive(
        light: lightSuccessRGB,
        dark: darkSuccessRGB,
        lightHighContrast: lightHighContrastSuccessRGB,
        darkHighContrast: darkHighContrastSuccessRGB
    )
    static let warning = adaptive(
        light: lightWarningRGB,
        dark: darkWarningRGB,
        lightHighContrast: lightHighContrastWarningRGB,
        darkHighContrast: darkHighContrastWarningRGB
    )
    static let onControl = color(ResenhaRGB(hex: 0xFFFFFF))

    private static func color(_ rgb: ResenhaRGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private static func adaptive(
        light: ResenhaRGB,
        dark: ResenhaRGB,
        lightHighContrast: ResenhaRGB? = nil,
        darkHighContrast: ResenhaRGB? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastAqua,
                .darkAqua,
                .aqua
            ])
            let value: ResenhaRGB
            switch match {
            case .accessibilityHighContrastDarkAqua: value = darkHighContrast ?? dark
            case .accessibilityHighContrastAqua: value = lightHighContrast ?? light
            case .darkAqua: value = dark
            default: value = light
            }
            return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
        })
    }

    static func canvas(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.09, green: 0.105, blue: 0.10), Color(red: 0.065, green: 0.073, blue: 0.07)]
                : [paper, color(lightCanvasEndRGB)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.14) : ink.opacity(0.14)
    }
}

struct ResenhaPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold).monospaced())
                .tracking(1.8)
                .foregroundStyle(ResenhaTheme.accent)
            Text(title)
                .font(.system(.title, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ResenhaStatusPill: View {
    let title: String
    let symbol: String
    let active: Bool

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium).monospaced())
            .tracking(0.35)
            .foregroundStyle(active ? ResenhaTheme.success : .secondary)
    }
}

struct ResenhaBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ResenhaTheme.canvas(colorScheme)
            Canvas { context, size in
                for index in 0..<5 {
                    let inset = CGFloat(index) * 24
                    let rect = CGRect(
                        x: size.width * 0.62 + inset,
                        y: -size.height * 0.34 + inset,
                        width: size.width * 0.62 - inset * 2,
                        height: size.height * 0.82 - inset * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(ResenhaTheme.accent.opacity(0.08 - Double(index) * 0.009)),
                        lineWidth: 1
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct ResenhaRuleSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.medium).monospaced())
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Divider()
            content
        }
    }
}

struct ResenhaToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let detail { Text(detail).font(.callout).foregroundStyle(.secondary) }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.vertical, 6)
    }
}
