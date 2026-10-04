import AppKit
import SwiftUI

enum PermissionOnboardingPolicy {
    static let presentedKey = "resenha.permissionOnboarding.presented"

    static func shouldPresent(snapshot: PermissionSnapshot, hasPresented: Bool, modelReady: Bool = true) -> Bool {
        (!snapshot.isReady && !hasPresented) || !modelReady
    }
}

private extension RequiredPermission {
    var onboardingTitle: String {
        switch self {
        case .microphone: "Microfone"
        case .inputMonitoring: "Monitoramento de Entrada"
        case .accessibility: "Acessibilidade"
        }
    }

    var onboardingPurpose: String {
        switch self {
        case .microphone: "Captura sua voz enquanto a tecla estiver pressionada."
        case .inputMonitoring: "Detecta o atalho escolhido mesmo em outros aplicativos."
        case .accessibility: "Insere a transcrição no campo em que você estava digitando."
        }
    }

    var onboardingIcon: String {
        switch self {
        case .microphone: "mic.fill"
        case .inputMonitoring: "keyboard"
        case .accessibility: "text.cursor"
        }
    }
}

private struct PermissionOnboardingView: View {
    let snapshot: PermissionSnapshot
    let isRequesting: Bool
    let requestPermissions: () -> Void
    let openSettings: (RequiredPermission) -> Void
    let close: () -> Void
    @ObservedObject private var modelManager = WhisperModelManager.shared

    private var modelReady: Bool {
        if case .ready = modelManager.state { return true }
        return false
    }

    private var setupReady: Bool { snapshot.isReady && modelReady }

    private var introText: String {
        let count = snapshot.requiresAccessibility ? "Três permissões" : "Duas permissões"
        return "\(count) conectam voz, atalho e inserção automática. O áudio nunca sai deste Mac."
    }
    var body: some View {
        ZStack {
            ResenhaBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 20) {
                                introduction
                                Spacer(minLength: 16)
                                ResenhaStatusPill(title: "100% local", symbol: "lock.fill", active: true)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                introduction
                                ResenhaStatusPill(title: "100% local", symbol: "lock.fill", active: true)
                            }
                        }

                        VStack(spacing: 0) {
                            Divider()
                            ForEach(Array(snapshot.presentations.enumerated()), id: \.element.permission) { index, presentation in
                                permissionRow(presentation, index: index)
                                if index < snapshot.presentations.count - 1 {
                                    Divider().padding(.leading, 52)
                                }
                            }
                            Divider()
                        }

                        ViewThatFits(in: .horizontal) {
                            modelRow
                            VStack(alignment: .leading, spacing: 12) {
                                modelDescriptionView
                                modelAction
                            }
                        }
                    }
                    .padding(30)
                }

                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        setupStatus
                        Spacer()
                        footerActions
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        setupStatus
                        footerActions
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
            }
        }
        .frame(minWidth: 620, minHeight: 480)
        .tint(ResenhaTheme.controlTint)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("ResenhaLockup")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 164, height: 42, alignment: .leading)
                .foregroundStyle(.primary)
                .accessibilityLabel("Resenha")
            Text("Sua voz, em qualquer campo.")
                .font(.system(.title, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(introText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelDescriptionView: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("AI")
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(modelReady ? ResenhaTheme.success : ResenhaTheme.accent)
                .frame(width: 34, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Modelo de voz local").fontWeight(.semibold)
                Text(modelDescription).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var modelRow: some View {
        HStack(alignment: .center, spacing: 14) {
            modelDescriptionView
            Spacer(minLength: 12)
            modelAction
        }
    }

    private var setupStatus: some View {
        ResenhaStatusPill(
            title: setupReady ? "Pronto para usar" : "Configuração pendente",
            symbol: setupReady ? "checkmark.circle.fill" : "circle.dotted",
            active: setupReady
        )
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button(setupReady ? "Começar a usar" : "Agora não", action: close)
            if !snapshot.isReady {
                Button(isRequesting ? "Solicitando…" : "Ativar permissões", action: requestPermissions)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(ResenhaTheme.onControl)
                    .disabled(isRequesting)
                    .accessibilityHint("Solicita Microfone e abre os Ajustes para Monitoramento de Entrada")
            }
        }
    }

    private var modelDescription: String {
        switch modelManager.state {
        case .missing:
            modelManager.hasResumableDownload
                ? "Download pausado. Retome sem perder o progresso disponível."
                : "Download único de 181 MB, verificado antes de instalar."
        case .downloading(let progress): "Baixando… \(progress.formatted(.percent.precision(.fractionLength(0))))"
        case .verifying: "Verificando a integridade do arquivo…"
        case .ready: "Instalado, verificado e pronto para transcrever."
        case .failed(let message): message
        }
    }

    @ViewBuilder
    private var modelAction: some View {
        switch modelManager.state {
        case .missing:
            Button(modelManager.hasResumableDownload ? "Retomar" : "Baixar") { modelManager.download() }
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress).frame(width: 82)
                Button("Pausar") { modelManager.cancelDownload() }
            }
        case .verifying:
            ProgressView().controlSize(.small)
        case .ready:
            Label("Pronto", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium)).foregroundStyle(ResenhaTheme.success)
        case .failed:
            Button("Tentar novamente") { modelManager.retry() }
        }
    }

    private func permissionRow(_ presentation: PermissionPresentation, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(presentation.isGranted ? ResenhaTheme.success : ResenhaTheme.accent)
                .frame(width: 34, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.permission.onboardingTitle).fontWeight(.semibold)
                Text(presentation.permission.onboardingPurpose)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if presentation.isGranted {
                Label("Ativada", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ResenhaTheme.success)
            } else {
                Button("Abrir Ajustes") { openSettings(presentation.permission) }
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 76)
        .accessibilityElement(children: .contain)
    }
}

@MainActor
final class PermissionOnboardingController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private var snapshot = PermissionSnapshot(microphone: false, inputMonitoring: false, accessibility: false)
    private var isRequesting = false
    private let requestPermissions: () -> Void
    private let openSettings: (RequiredPermission) -> Void

    init(requestPermissions: @escaping () -> Void, openSettings: @escaping (RequiredPermission) -> Void) {
        self.requestPermissions = requestPermissions
        self.openSettings = openSettings
    }

    func show(snapshot: PermissionSnapshot, isRequesting: Bool) {
        self.snapshot = snapshot
        self.isRequesting = isRequesting
        let window = window ?? makeWindow()
        render()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func update(snapshot: PermissionSnapshot, isRequesting: Bool) {
        self.snapshot = snapshot
        self.isRequesting = isRequesting
        if window?.isVisible == true { render() }
    }

    func close() { window?.orderOut(nil) }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configurar Resenha"
        window.contentMinSize = NSSize(width: 620, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window
        return window
    }

    private func render() {
        window?.contentView = NSHostingView(rootView: PermissionOnboardingView(
            snapshot: snapshot,
            isRequesting: isRequesting,
            requestPermissions: requestPermissions,
            openSettings: openSettings,
            close: { [weak self] in self?.close() }
        ))
        window?.contentMinSize = NSSize(width: 620, height: 480)
    }
}
