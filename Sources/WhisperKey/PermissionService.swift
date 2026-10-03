import AppKit
import ApplicationServices
import AVFoundation

enum RequiredPermission: Hashable {
    case microphone
    case inputMonitoring
    case accessibility

    static var requiredCases: [RequiredPermission] {
        [.microphone, .inputMonitoring, .accessibility]
    }

    var name: String {
        switch self {
        case .microphone: "Microfone"
        case .inputMonitoring: "Monitoramento de Entrada"
        case .accessibility: "Acessibilidade"
        }
    }

    var purpose: String {
        switch self {
        case .microphone: "Necessário para capturar sua voz."
        case .inputMonitoring: "Necessário para detectar o atalho em outros aplicativos."
        case .accessibility: "Necessário para inserir o texto no aplicativo ativo."
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
        case .inputMonitoring: pane = "Privacy_ListenEvent"
        case .accessibility: pane = "Privacy_Accessibility"
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

    init(microphone: Bool, inputMonitoring: Bool, accessibility: Bool = true) {
        self.microphone = microphone
        self.inputMonitoring = inputMonitoring
        self.accessibility = accessibility
    }

    var isReady: Bool { microphone && inputMonitoring && accessibility }

    var presentations: [PermissionPresentation] {
        RequiredPermission.requiredCases.map { permission in
            let granted: Bool
            switch permission {
            case .microphone: granted = microphone
            case .inputMonitoring: granted = inputMonitoring
            case .accessibility: granted = accessibility
            }
            return PermissionPresentation(permission: permission, isGranted: granted)
        }
    }

    var missingPermissions: [RequiredPermission] {
        presentations.filter { !$0.isGranted }.map(\.permission)
    }

    var missingPermissionMessage: String {
        if !microphone { return "Acesso ao Microfone necessário" }
        if !inputMonitoring { return "Acesso ao Monitoramento de Entrada necessário" }
        if !accessibility { return "Acesso à Acessibilidade necessário" }
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
    var isInputMonitoringGranted: Bool { CGPreflightListenEventAccess() }
    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    var snapshot: PermissionSnapshot {
        PermissionSnapshot(
            microphone: isMicrophoneGranted,
            inputMonitoring: isInputMonitoringGranted,
            accessibility: isAccessibilityGranted
        )
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

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
