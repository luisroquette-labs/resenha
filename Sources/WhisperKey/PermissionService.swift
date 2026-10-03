import AppKit
import ApplicationServices
import AVFoundation

enum RequiredPermission: Hashable {
    case microphone
    case inputMonitoring

    static var requiredCases: [RequiredPermission] {
        [.microphone, .inputMonitoring]
    }

    var name: String {
        switch self {
        case .microphone: "Microfone"
        case .inputMonitoring: "Monitoramento de Entrada"
        }
    }

    var purpose: String {
        switch self {
        case .microphone: "Necessário para capturar sua voz."
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
    let microphone: Bool
    let inputMonitoring: Bool

    var isReady: Bool { microphone && inputMonitoring }

    var presentations: [PermissionPresentation] {
        RequiredPermission.requiredCases.map { permission in
            let granted: Bool
            switch permission {
            case .microphone: granted = microphone
            case .inputMonitoring: granted = inputMonitoring
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
        return "Permissões prontas"
    }
}

enum PermissionGate {
    static func shouldStartHotkey(
        microphone: Bool,
        inputMonitoring: Bool,
        hotkeyRunning: Bool
    ) -> Bool {
        microphone && inputMonitoring && !hotkeyRunning
    }
}

struct PermissionService {
    var isMicrophoneGranted: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    var isInputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    var snapshot: PermissionSnapshot {
        PermissionSnapshot(
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

    func requestMicrophone() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }
}
