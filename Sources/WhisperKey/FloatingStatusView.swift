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
    @Published var feedbackPhase: FeedbackBubblePhase = .hidden

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

struct FeedbackBubbleVisualState: Equatable {
    let opacity: Double
    let offset: CGFloat
    let bubbleScale: CGFloat
}

enum FeedbackBubblePhase: Equatable {
    case hidden, entering, resting, exiting

    var elapsed: TimeInterval {
        switch self {
        case .entering: 0
        case .resting: 3.25
        case .hidden, .exiting: 4
        }
    }
}

enum FeedbackBubbleMotion {
    static let targetSize: CGFloat = 44
    static let visualSize: CGFloat = 32
    static let duration: TimeInterval = 4

    static func state(elapsed: TimeInterval, index: Int, reduceMotion: Bool) -> FeedbackBubbleVisualState {
        let time = max(0, min(duration, elapsed.isFinite ? elapsed : 0))
        let restingProgress = min(1, time / 3.25)
        let exitProgress = max(0, min(1, (time - 3.25) / 0.75))
        return FeedbackBubbleVisualState(
            opacity: 1 - exitProgress,
            offset: reduceMotion ? 0 : 8 - 12 * restingProgress - 8 * exitProgress,
            bubbleScale: 1
        )
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
    var fixtureFeedbackElapsed: TimeInterval? = nil
    var feedbackIsVisualOnly = false
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
            if model.status != .feedback {
                let shape = RoundedRectangle(cornerRadius: model.status == .listening ? 32 : 18)
                if fixtureReduceTransparency ?? reduceTransparency {
                    shape.fill(colorScheme == .dark ? ResenhaTheme.ink : ResenhaTheme.paper)
                } else {
                    shape.fill(.regularMaterial)
                        .overlay(shape.fill((colorScheme == .dark ? ResenhaTheme.ink : ResenhaTheme.paper).opacity(0.28)))
                }
            }
        }
        .overlay {
            if model.status != .feedback {
                RoundedRectangle(cornerRadius: model.status == .listening ? 32 : 18)
                    .stroke(
                        (model.status == .listening || model.status.isFailure ? ResenhaTheme.signal : Color.primary)
                            .opacity((fixtureContrast ?? contrast) == .increased ? 0.78 : 0.18),
                        lineWidth: (fixtureContrast ?? contrast) == .increased ? 1.5 : 1
                    )
            }
        }
        .padding(4)
        .animation((fixtureReduceMotion ?? reduceMotion) ? nil : .easeOut(duration: 0.12),
                   value: model.status == .feedback)
        .transaction {
            if (fixtureReduceMotion ?? reduceMotion) && model.status != .feedback {
                $0.animation = nil; $0.disablesAnimations = true
            }
        }
        .accessibilityElement(children: model.status == .feedback ? .contain : .ignore)
        .accessibilityLabel(model.status.accessibilityLabel)
    }

    private var feedbackContent: some View {
        FeedbackBubblesView(
            actions: feedbackActions,
            reduceMotion: fixtureReduceMotion ?? reduceMotion,
            increasedContrast: (fixtureContrast ?? contrast) == .increased,
            fixtureElapsed: fixtureFeedbackElapsed,
            phase: model.feedbackPhase
        )
        .accessibilityHidden(feedbackIsVisualOnly)
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

private struct FeedbackBubblesView: View {
    let actions: [TranscriptionFeedbackAction]
    let reduceMotion: Bool
    let increasedContrast: Bool
    let fixtureElapsed: TimeInterval?
    let phase: FeedbackBubblePhase

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                let state = FeedbackBubbleMotion.state(
                    elapsed: fixtureElapsed ?? phase.elapsed, index: index, reduceMotion: reduceMotion
                )
                Button(action: action.perform) {
                    FeedbackBubble(index: index, increasedContrast: increasedContrast)
                        .scaleEffect(state.bubbleScale)
                        .frame(width: FeedbackBubbleMotion.targetSize, height: FeedbackBubbleMotion.targetSize)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .opacity(state.opacity)
                .offset(y: state.offset)
                .animation(fixtureElapsed != nil ? nil :
                    (phase == .resting ? .easeOut(duration: 3.25) :
                        (phase == .exiting ? .easeIn(duration: 0.75) : nil)),
                    value: phase)
                .accessibilityLabel(action.label)
                .accessibilityHint(action.label == FloatingStatusView.approveLabel
                    ? "Encerra a avaliação sem salvar dados."
                    : "Abre os campos Saiu como e Correto é para uma correção local.")
            }
        }
    }
}

private struct FeedbackBubble: View {
    let index: Int
    let increasedContrast: Bool

    var body: some View {
        Text(index == 0 ? "👍" : "👎")
            .font(.system(size: 30))
            .shadow(color: .white.opacity(increasedContrast ? 0.44 : 0.24), radius: 0.5, y: -0.5)
            .shadow(color: .black.opacity(increasedContrast ? 0.42 : 0.28), radius: 2, y: 2)
            .frame(width: FeedbackBubbleMotion.visualSize, height: FeedbackBubbleMotion.visualSize)
            .accessibilityHidden(true)
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
                    Text("Salvar adiciona somente o termo correto ao vocabulário local, sem criar uma substituição para o texto ouvido. O reconhecimento pode variar.")
                        .font(.callout)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Field.heard.label)
                        TextField(Field.heard.label, text: $heard)
                            .labelsHidden()
                            .accessibilityLabel(Field.heard.label)
                            .accessibilityHint(invalidField == .heard ? errorMessage ?? "" : "")
                            .focused($focusedField, equals: .heard)
                        Text("\(heard.count)/\(TranscriptionGlossary.maximumCorrectionFieldCharacters) caracteres · até 2.560 bytes")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Field.canonical.label)
                        TextField(Field.canonical.label, text: $canonical)
                            .labelsHidden()
                            .accessibilityLabel(Field.canonical.label)
                            .accessibilityHint(invalidField == .canonical ? errorMessage ?? "" : "")
                            .focused($focusedField, equals: .canonical)
                        Text("\(canonical.count)/\(TranscriptionGlossary.maximumCorrectionFieldCharacters) caracteres · até 2.560 bytes")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Não foi possível salvar. \(errorMessage)")
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
