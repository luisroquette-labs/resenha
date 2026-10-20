import AppKit
import SwiftUI

enum FloatingStatus: Equatable {
    case ready
    case listening
    case transcribing
    case inserting
    case feedback
    case feedbackNotice(String)
    case failure(String)

    var title: String {
        switch self {
        case .ready: "Pronto"
        case .listening: "Ouvindo…"
        case .transcribing: "Transcrevendo…"
        case .inserting: "Inserindo…"
        case .feedback: "Avaliar transcrição"
        case .feedbackNotice(let message): message
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
        case .feedbackNotice: "info.circle"
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

struct TranscriptionFeedbackAction: Identifiable {
    let label: String
    var symbol: String? = nil
    var isEnabled = true
    let handler: () -> Void
    var id: String { label }

    func perform() {
        if isEnabled { handler() }
    }
}

struct FloatingStatusView: View {
    static let approveLabel = "Transcrição correta"
    static let correctLabel = "Corrigir transcrição"
    @ObservedObject var model: FloatingPanelModel
    // Internal capture overrides; production uses the native environment values below.
    var fixtureContrast: ColorSchemeContrast? = nil
    var fixtureReduceTransparency: Bool? = nil
    var fixtureReduceMotion: Bool? = nil
    var onApprove: () -> Void = {}
    var onCorrect: () -> Void = {}
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    var feedbackActions: [TranscriptionFeedbackAction] {
        [.init(label: Self.approveLabel, symbol: "hand.thumbsup", handler: onApprove),
         .init(label: Self.correctLabel, symbol: "hand.thumbsdown", handler: onCorrect)]
    }

    @MainActor
    static func panelSize(for status: FloatingStatus, available: CGSize) -> CGSize {
        if status == .listening { return CGSize(width: 340, height: 72) }
        guard status.isFailure else { return CGSize(width: 280, height: 64) }
        let width = min(360, max(0, available.width - 24))
        let textWidth = max(1, width - 76)
        let titleHeight = (status.title as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]
        ).height
        return CGSize(width: width, height: min(104, max(64, min(titleHeight, 36) + 41)))
    }

    var body: some View {
        Group {
            if model.status == .listening {
                RecordingWaveformView(meter: model.recording, fixtureReduceMotion: fixtureReduceMotion)
            } else if model.status == .feedback {
                feedbackContent
                    .transition(.opacity)
            } else { statusContent }
        }
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
        .animation((fixtureReduceMotion ?? reduceMotion) ? nil : .easeOut(duration: 0.12),
                   value: model.status == .feedback)
        .transaction {
            if fixtureReduceMotion ?? reduceMotion { $0.animation = nil; $0.disablesAnimations = true }
        }
        .accessibilityElement(children: model.status == .feedback ? .contain : .ignore)
        .accessibilityLabel(model.status.accessibilityLabel)
    }

    private var feedbackContent: some View {
        HStack(spacing: 16) {
            ForEach(feedbackActions) { action in
                Button(action: action.perform) {
                    Label(action.label, systemImage: action.symbol ?? "")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel(action.label)
                .accessibilityHint(action.label == Self.approveLabel
                    ? "Encerra a avaliação sem salvar dados."
                    : "Abre os campos Saiu como e Correto é para uma correção local.")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .foregroundStyle(.primary)
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let secondary = model.status.secondary {
                    Text(secondary)
                        .font(.system(size: 12))
                        .foregroundStyle((fixtureContrast ?? contrast) == .increased ? Color.primary : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TranscriptionCorrectionView: View {
    enum Field: Hashable {
        case heard, canonical
        var label: String { self == .heard ? "Saiu como" : "Correto é" }
    }
    static let saveLabel = "Salvar"
    static let cancelLabel = "Cancelar"

    @Binding var heard: String
    @Binding var canonical: String
    var errorMessage: String?
    var invalidField: Field? = nil
    var isSaveEnabled: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    // Capture overrides mirror the HUD; production reads the native accessibility environment.
    var fixtureContrast: ColorSchemeContrast? = nil
    var fixtureReduceTransparency: Bool? = nil
    var fixtureReduceMotion: Bool? = nil
    @FocusState private var focusedField: Field?
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var actions: [TranscriptionFeedbackAction] {
        [.init(label: Self.saveLabel, isEnabled: isSaveEnabled, handler: {
            onSave()
            if errorMessage != nil { focusedField = invalidField ?? .heard }
        }), .init(label: Self.cancelLabel, handler: onCancel)]
    }

    static func panelSize(available: CGSize) -> CGSize {
        CGSize(width: min(440, max(0, available.width - 24)), height: min(360, max(0, available.height - 24)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Corrigir transcrição")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Field.heard.label)
                        TextField(Field.heard.label, text: $heard)
                            .labelsHidden()
                            .accessibilityLabel(Field.heard.label)
                            .accessibilityHint(invalidField == .heard ? errorMessage ?? "" : "")
                            .focused($focusedField, equals: .heard)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Field.canonical.label)
                        TextField(Field.canonical.label, text: $canonical)
                            .labelsHidden()
                            .accessibilityLabel(Field.canonical.label)
                            .accessibilityHint(invalidField == .canonical ? errorMessage ?? "" : "")
                            .focused($focusedField, equals: .canonical)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Não foi possível salvar. \(errorMessage)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                ForEach(actions) { action in
                    Button(action.label, action: action.perform)
                        .keyboardShortcut(action.label == Self.saveLabel ? .defaultAction : .cancelAction)
                        .disabled(!action.isEnabled)
                }
                Spacer(minLength: 0)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .background {
            if fixtureReduceTransparency ?? reduceTransparency {
                (colorScheme == .dark ? ResenhaTheme.ink : ResenhaTheme.paper)
            } else { ResenhaBackdrop() }
        }
        .overlay {
            if (fixtureContrast ?? contrast) == .increased {
                Rectangle().stroke(Color.primary.opacity(0.78), lineWidth: 1.5)
                    .accessibilityHidden(true)
            }
        }
        .transaction {
            if fixtureReduceMotion ?? reduceMotion { $0.animation = nil; $0.disablesAnimations = true }
        }
        .accessibilityElement(children: .contain)
        .onAppear { focusedField = invalidField ?? .heard }
        .onChange(of: errorMessage) { _, error in
            if error != nil { focusedField = invalidField ?? .heard }
        }
        .onChange(of: invalidField) { _, field in
            if errorMessage != nil { focusedField = field ?? .heard }
        }
    }
}
