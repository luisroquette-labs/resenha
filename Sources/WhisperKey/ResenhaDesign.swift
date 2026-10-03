import SwiftUI

enum ResenhaTheme {
    static let accent = Color(red: 0.43, green: 0.64, blue: 0.59)
    static let accentSoft = Color(red: 0.72, green: 0.82, blue: 0.79)
    static let signal = accent
    static let ink = Color(red: 0.09, green: 0.105, blue: 0.10)
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.86)
    static let fog = Color(red: 0.80, green: 0.85, blue: 0.82)
    static let success = Color(red: 0.38, green: 0.61, blue: 0.52)
    static let warning = Color(red: 0.70, green: 0.50, blue: 0.34)

    static func canvas(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.09, green: 0.105, blue: 0.10), Color(red: 0.065, green: 0.073, blue: 0.07)]
                : [paper, Color(red: 0.89, green: 0.91, blue: 0.87)],
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
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(ResenhaTheme.accent)
            Text(title)
                .font(.system(size: 29, weight: .semibold, design: .serif))
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
            .font(.system(size: 11, weight: .medium, design: .monospaced))
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
                .font(.system(size: 10, weight: .medium, design: .monospaced))
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
