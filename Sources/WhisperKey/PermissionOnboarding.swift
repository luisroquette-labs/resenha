import AppKit
import SwiftUI

enum PermissionOnboardingPolicy {
    static let presentedKey = "resenha.permissionOnboarding.presented"

    static func shouldPresent(snapshot: PermissionSnapshot, hasPresented: Bool) -> Bool {
        !snapshot.isReady && !hasPresented
    }
}

private extension RequiredPermission {
    var onboardingTitle: String {
        switch self {
        case .microphone: "Microfone"
        case .accessibility: "Acessibilidade"
        case .inputMonitoring: "Monitoramento de Entrada"
        }
    }

    var onboardingPurpose: String {
        switch self {
        case .microphone: "Captura sua voz enquanto a tecla estiver pressionada."
        case .accessibility: "Insere a transcrição no campo em que você estava escrevendo."
        case .inputMonitoring: "Detecta o atalho escolhido mesmo em outros aplicativos."
        }
    }

    var onboardingIcon: String {
        switch self {
        case .microphone: "mic.fill"
        case .accessibility: "text.cursor"
        case .inputMonitoring: "keyboard"
        }
    }
}

private struct PermissionOnboardingView: View {
    let snapshot: PermissionSnapshot
    let isRequesting: Bool
    let requestPermissions: () -> Void
    let openSettings: (RequiredPermission) -> Void
    let close: () -> Void
    var body: some View {
        ZStack {
            ResenhaBackdrop().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image("ResenhaLockup")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 164, height: 42, alignment: .leading)
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                        Text("Sua voz, em qualquer campo.")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                        Text("Três permissões conectam o atalho, o microfone e o cursor. O áudio nunca sai deste Mac.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    ResenhaStatusPill(title: "100% local", symbol: "lock.fill", active: true)
                }

                VStack(spacing: 0) {
                    Divider()
                    ForEach(Array(snapshot.presentations.enumerated()), id: \.element.permission) { index, presentation in
                        permissionRow(presentation, index: index)
                        if presentation.permission != .inputMonitoring {
                            Divider().padding(.leading, 52)
                        }
                    }
                    Divider()
                }

                Spacer(minLength: 0)

                HStack {
                    ResenhaStatusPill(
                        title: snapshot.isReady ? "Pronto para usar" : "Configuração pendente",
                        symbol: snapshot.isReady ? "checkmark.circle.fill" : "circle.dotted",
                        active: snapshot.isReady
                    )
                    Spacer()
                    Button(snapshot.isReady ? "Começar a usar" : "Agora não", action: close)
                    if !snapshot.isReady {
                        Button(isRequesting ? "Solicitando…" : "Ativar permissões", action: requestPermissions)
                            .buttonStyle(.borderedProminent)
                            .tint(ResenhaTheme.signal)
                            .disabled(isRequesting)
                    }
                }
            }
            .padding(30)
        }
        .frame(width: 680, height: 500)
        .tint(ResenhaTheme.signal)
    }

    private func permissionRow(_ presentation: PermissionPresentation, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(presentation.isGranted ? ResenhaTheme.success : ResenhaTheme.accent)
                .frame(width: 34, alignment: .leading)
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
    }
}

@MainActor
final class PermissionOnboardingController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private var snapshot = PermissionSnapshot(accessibility: false, microphone: false, inputMonitoring: false)
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
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configurar Resenha"
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
    }
}
