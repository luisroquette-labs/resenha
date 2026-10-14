import AppKit
#if !RESENHA_APP_STORE
import ApplicationServices
#endif
import AVFoundation

enum RequiredPermission: Hashable {
    case microphone
    #if !RESENHA_APP_STORE
    case inputMonitoring
    case accessibility
    #endif

    static func requiredCases(for channel: ResenhaDistributionChannel) -> [RequiredPermission] {
        #if RESENHA_APP_STORE
        [.microphone]
        #else
        channel.requiresAccessibility
            ? [.microphone, .inputMonitoring, .accessibility]
            : [.microphone]
        #endif
    }

    var name: String {
        switch self {
        case .microphone: "Microfone"
        #if !RESENHA_APP_STORE
        case .inputMonitoring: "Monitoramento de Entrada"
        case .accessibility: "Acessibilidade"
        #endif
        }
    }

    var purpose: String {
        switch self {
        case .microphone: "Necessário para capturar sua voz."
        #if !RESENHA_APP_STORE
        case .inputMonitoring: "Necessário para detectar o atalho em outros aplicativos."
        case .accessibility: "Necessário para inserir o texto no aplicativo ativo."
        #endif
        }
    }

    var settingsActionTitle: String { "Abrir Ajustes de \(name)" }

    var manualRecovery: String {
        "Ajustes do Sistema → Privacidade e Segurança → \(name): ative o Resenha. Se o acesso continuar ausente, encerre e reabra o Resenha."
    }

    var settingsDestination: URL {
        let pane: String
        switch self {
        case .microphone: pane = "Privacy_Microphone"
        #if !RESENHA_APP_STORE
        case .inputMonitoring: pane = "Privacy_ListenEvent"
        case .accessibility: pane = "Privacy_Accessibility"
        #endif
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }
}

struct PermissionPresentation: Equatable {
    let permission: RequiredPermission
    let isGranted: Bool

    var status: String { "\(permission.name): \(isGranted ? "ativada" : "permissão necessária")" }
}

struct PermissionSnapshot: Equatable {
    let microphone: Bool
    let inputMonitoring: Bool
    let accessibility: Bool
    let requiresAccessibility: Bool

    init(
        microphone: Bool,
        inputMonitoring: Bool,
        accessibility: Bool = true,
        requiresAccessibility: Bool = ResenhaDistributionChannel.current.requiresAccessibility
    ) {
        self.microphone = microphone
        self.inputMonitoring = inputMonitoring
        self.accessibility = accessibility
        self.requiresAccessibility = requiresAccessibility
    }

    var isReady: Bool {
        #if RESENHA_APP_STORE
        microphone
        #else
        microphone && (!requiresAccessibility || (inputMonitoring && accessibility))
        #endif
    }

    var presentations: [PermissionPresentation] {
        RequiredPermission.requiredCases(for: requiresAccessibility ? .direct : .appStore).map { permission in
            let granted: Bool
            switch permission {
            case .microphone: granted = microphone
            #if !RESENHA_APP_STORE
            case .inputMonitoring: granted = inputMonitoring
            case .accessibility: granted = accessibility
            #endif
            }
            return PermissionPresentation(permission: permission, isGranted: granted)
        }
    }

    var missingPermissions: [RequiredPermission] {
        presentations.filter { !$0.isGranted }.map(\.permission)
    }

    var missingPermissionMessage: String {
        if !microphone { return "Acesso ao Microfone necessário" }
        #if !RESENHA_APP_STORE
        if requiresAccessibility && !inputMonitoring { return "Acesso ao Monitoramento de Entrada necessário" }
        if requiresAccessibility && !accessibility { return "Acesso à Acessibilidade necessário" }
        #endif
        return "Permissões prontas"
    }
}

enum PermissionGate {
    static func shouldStartHotkey(
        microphone: Bool,
        inputMonitoring: Bool,
        accessibility: Bool = true,
        hotkeyRunning: Bool
    ) -> Bool {
        microphone && inputMonitoring && accessibility && !hotkeyRunning
    }
}

struct PermissionService {
    var isMicrophoneGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    #if !RESENHA_APP_STORE
    var isInputMonitoringGranted: Bool { CGPreflightListenEventAccess() }
    #endif

    #if !RESENHA_APP_STORE
    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }
    #endif

    var snapshot: PermissionSnapshot {
        #if RESENHA_APP_STORE
        PermissionSnapshot(
            microphone: isMicrophoneGranted,
            inputMonitoring: true,
            accessibility: true,
            requiresAccessibility: false
        )
        #else
        PermissionSnapshot(
            microphone: isMicrophoneGranted,
            inputMonitoring: isInputMonitoringGranted,
            accessibility: isAccessibilityGranted,
            requiresAccessibility: true
        )
        #endif
    }

    var missingPermissionMessage: String { snapshot.missingPermissionMessage }

    @MainActor
    @discardableResult
    func openSettings(for permission: RequiredPermission) -> Bool {
        NSWorkspace.shared.open(permission.settingsDestination)
    }

    func requestMicrophone() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    #if !RESENHA_APP_STORE
    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }
    #endif

    #if !RESENHA_APP_STORE
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    #endif
}
