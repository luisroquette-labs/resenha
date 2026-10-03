import AppKit
import ApplicationServices
import AVFoundation

enum RequiredPermission: CaseIterable, Hashable {
    case microphone
    case accessibility
    case inputMonitoring

    var name: String {
        switch self {
        case .microphone: "Microfone"
        case .accessibility: "Acessibilidade"
        case .inputMonitoring: "Monitoramento de Entrada"
        }
    }

    var purpose: String {
        switch self {
        case .microphone: "Necessário para capturar sua voz."
        case .accessibility: "Necessário para inserir texto no aplicativo original."
        case .inputMonitoring: "Necessário para detectar o atalho em outros aplicativos."
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
        case .accessibility: pane = "Privacy_Accessibility"
        case .inputMonitoring: pane = "Privacy_ListenEvent"
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
    let accessibility: Bool
    let microphone: Bool
    let inputMonitoring: Bool

    var isReady: Bool { accessibility && microphone && inputMonitoring }

    var presentations: [PermissionPresentation] {
        RequiredPermission.allCases.map { permission in
            let granted: Bool
            switch permission {
            case .microphone: granted = microphone
            case .accessibility: granted = accessibility
            case .inputMonitoring: granted = inputMonitoring
            }
            return PermissionPresentation(permission: permission, isGranted: granted)
        }
    }

    var missingPermissions: [RequiredPermission] {
        presentations.filter { !$0.isGranted }.map(\.permission)
    }

    var missingPermissionMessage: String {
        if !accessibility { return "Acesso à Acessibilidade necessário" }
        if !microphone { return "Acesso ao Microfone necessário" }
        if !inputMonitoring { return "Acesso ao Monitoramento de Entrada necessário" }
        return "Permissões prontas"
    }
}

enum PermissionGate {
    static func shouldStartHotkey(
        accessibility: Bool,
        microphone: Bool,
        inputMonitoring: Bool,
        hotkeyRunning: Bool
    ) -> Bool {
        accessibility && microphone && inputMonitoring && !hotkeyRunning
    }
}

struct PermissionService {
    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }
    var isMicrophoneGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    var isInputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    var snapshot: PermissionSnapshot {
        PermissionSnapshot(
            accessibility: isAccessibilityGranted,
            microphone: isMicrophoneGranted,
            inputMonitoring: isInputMonitoringGranted
        )
    }

    var missingPermissionMessage: String { snapshot.missingPermissionMessage }

    @MainActor
    @discardableResult
    func openSettings(for permission: RequiredPermission) -> Bool {
        NSWorkspace.shared.open(permission.settingsDestination)
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func requestMicrophone() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }
}
