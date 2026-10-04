import AppKit
import SwiftUI

enum FloatingStatus: Equatable {
    case ready
    case listening
    case transcribing
    case inserting
    case failure(String)

    var title: String {
        switch self {
        case .ready: "Pronto"
        case .listening: "Ouvindo…"
        case .transcribing: "Transcrevendo…"
        case .inserting: "Inserindo…"
        case .failure(let message): message
        }
    }

    var isBusy: Bool { self == .transcribing || self == .inserting }

    var secondary: String? {
        switch self {
        case .ready: "Segure seu atalho para ditar"
        case .listening: "Solte o atalho para concluir"
        case .failure: "Abra o menu do Resenha para obter ajuda"
        default: nil
        }
    }

    var symbol: String? {
        switch self {
        case .ready: "waveform"
        case .listening: "mic.fill"
        case .failure: "exclamationmark.triangle.fill"
        default: nil
        }
    }

    var isFailure: Bool { if case .failure = self { return true }; return false }
    var accessibilityLabel: String { [title, secondary].compactMap { $0 }.joined(separator: ". ") }
}

@MainActor
final class FloatingPanelModel: ObservableObject {
    @Published var status: FloatingStatus = .ready
    @Published var recording = RecordingMeter()

    func show(_ status: FloatingStatus, now: TimeInterval) {
        if status == .listening {
            if self.status != status || !recording.isRecording { recording.start(at: now) }
        } else { recording = RecordingMeter() }
        self.status = status
    }
}

struct FloatingStatusView: View {
    @ObservedObject var model: FloatingPanelModel
    // Internal capture overrides; production uses the native environment values below.
    var fixtureContrast: ColorSchemeContrast? = nil
    var fixtureReduceTransparency: Bool? = nil
    var fixtureReduceMotion: Bool? = nil
    var fixtureDynamicTypeSize: DynamicTypeSize? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @MainActor
    static func panelSize(
        for status: FloatingStatus,
        available: CGSize,
        dynamicTypeSize: DynamicTypeSize? = nil
    ) -> CGSize {
        let scale = textScale(for: dynamicTypeSize)
        let preferredHeadline = NSFont.preferredFont(forTextStyle: .headline)
        let accessibilityLayout = (dynamicTypeSize?.isAccessibilitySize)
            ?? (preferredHeadline.pointSize >= 20)
        let maximumWidth = max(0, available.width - 24)
        if status == .listening {
            return CGSize(
                width: min(accessibilityLayout ? 420 : 340, maximumWidth),
                height: min(accessibilityLayout ? 128 : 72, max(0, available.height - 24))
            )
        }
        if !status.isFailure {
            return CGSize(
                width: min(accessibilityLayout ? 360 : 280, maximumWidth),
                height: min(accessibilityLayout ? 96 : 64, max(0, available.height - 24))
            )
        }
        let width = min(accessibilityLayout ? 420 : 360, maximumWidth)
        let textWidth = max(1, width - (accessibilityLayout ? 56 : 76))
        let titleFont = NSFont.systemFont(
            ofSize: preferredHeadline.pointSize * scale,
            weight: .semibold
        )
        let bodyFont = NSFont.systemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize * scale
        )
        let titleHeight = (status.title as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleFont]
        ).height
        let secondaryHeight = ((status.secondary ?? "") as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bodyFont]
        ).height
        let height = max(accessibilityLayout ? 96 : 64, titleHeight + secondaryHeight + 35)
        return CGSize(width: width, height: min(height, max(0, available.height - 24)))
    }

    private static func textScale(for dynamicTypeSize: DynamicTypeSize?) -> CGFloat {
        switch dynamicTypeSize {
        case .accessibility1: 1.25
        case .accessibility2: 1.4
        case .accessibility3: 1.6
        case .accessibility4: 1.8
        case .accessibility5: 2
        default: 1
        }
    }

    var body: some View {
        let resolvedDynamicTypeSize = fixtureDynamicTypeSize ?? dynamicTypeSize
        Group {
            if model.status == .listening {
                RecordingWaveformView(
                    meter: model.recording,
                    fixtureReduceMotion: fixtureReduceMotion,
                    accessibilityLayout: resolvedDynamicTypeSize.isAccessibilitySize
                )
            } else { statusContent }
        }
        .dynamicTypeSize(resolvedDynamicTypeSize)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: model.status == .listening ? 32 : 18)
            if fixtureReduceTransparency ?? reduceTransparency {
                shape.fill(colorScheme == .dark ? ResenhaTheme.ink : ResenhaTheme.paper)
            } else {
                shape.fill(.regularMaterial)
                    .overlay(shape.fill((colorScheme == .dark ? ResenhaTheme.ink : ResenhaTheme.paper).opacity(0.28)))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: model.status == .listening ? 32 : 18)
                .stroke(
                    (model.status == .listening || model.status.isFailure ? ResenhaTheme.signal : Color.primary)
                        .opacity((fixtureContrast ?? contrast) == .increased ? 0.78 : 0.18),
                    lineWidth: (fixtureContrast ?? contrast) == .increased ? 1.5 : 1
                )
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.status.accessibilityLabel)
    }

    private var statusContent: some View {
        HStack(spacing: 12) {
            Group {
                if model.status.isBusy {
                    ProgressView().controlSize(.small).tint(ResenhaTheme.signal).accessibilityLabel(model.status.title)
                } else if let symbol = model.status.symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(model.status.isFailure ? ResenhaTheme.signal : Color.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.status.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let secondary = model.status.secondary {
                    Text(secondary)
                        .font(.callout)
                        .foregroundStyle((fixtureContrast ?? contrast) == .increased ? Color.primary : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
