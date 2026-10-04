import AppKit

enum ResenhaBrand {
    private static let resonanceFrames: [NSImage?] = (0...4).map { step in
        guard let source = NSImage(named: "ResenhaMenuBar") else { return nil }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            let side = 12 + CGFloat(step) * 1.5
            let rect = NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
            source.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func menuBarImage() -> NSImage? {
        guard let image = NSImage(named: "ResenhaMenuBar")?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    static func resonatingMenuBarImage(level: Float) -> NSImage? {
        resonanceFrames[RecordingResonance.menuStep(level: level)]
    }
}

@MainActor
final class NativeMenuController {
    private weak var delegate: AppDelegate?
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var permissionsMenuItem: NSMenuItem!
    private var detailsMenuItem: NSMenuItem!
    private var enableMenuItem: NSMenuItem!
    private var instructionMenuItem: NSMenuItem!
    private var recentMenuItem: NSMenuItem!
    private var languageMenuItem: NSMenuItem!
    private var renderedSnapshot: PermissionSnapshot?
    private var renderedError: DictationErrorPresentation?
    private var isRecording = false
    private var recordingStep = -1
    private var settingsNavigationFailures: Set<RequiredPermission> = []

    init(delegate: AppDelegate) { self.delegate = delegate }

    func update(_ presentation: MenuStatusPresentation, isRequestingPermission: Bool) {
        let snapshot = presentation.snapshot
        isRecording = presentation.phase == .recording
        if !isRecording {
            recordingStep = -1
            statusItem?.button?.image = ResenhaBrand.menuBarImage()
        }
        statusMenuItem?.title = "Resenha — \(presentation.activity)"
        instructionMenuItem?.title = "Segure \(ResenhaServiceShortcut.displayName) para ditar"
        statusItem?.button?.toolTip = presentation.accessibleStatus
        statusItem?.button?.setAccessibilityLabel(presentation.accessibleStatus)
        enableMenuItem?.isEnabled = !snapshot.isReady && !isRequestingPermission
        if snapshot != renderedSnapshot {
            renderedSnapshot = snapshot
            settingsNavigationFailures = settingsNavigationFailures.intersection(snapshot.missingPermissions)
            permissionsMenuItem?.isHidden = snapshot.isReady
            permissionsMenuItem?.submenu = makePermissionsMenu(snapshot)
        }
        if presentation.error != renderedError {
            renderedError = presentation.error
            detailsMenuItem?.isHidden = renderedError == nil
            detailsMenuItem?.submenu = renderedError.map(makeDetailsMenu)
        }
    }

    func settingsNavigationFinished(_ opened: Bool, for permission: RequiredPermission) {
        if opened {
            settingsNavigationFailures.remove(permission)
        } else {
            settingsNavigationFailures.insert(permission)
        }
        renderedSnapshot = nil
    }

    func configure() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = ResenhaBrand.menuBarImage()
        let menu = NSMenu()
        menu.delegate = delegate
        menu.autoenablesItems = false
        statusMenuItem = menu.addItem(withTitle: "Resenha", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        instructionMenuItem = menu.addItem(withTitle: "Segure seu atalho para ditar", action: nil, keyEquivalent: "")
        instructionMenuItem.isEnabled = false
        languageMenuItem = menu.addItem(withTitle: "Idioma", action: nil, keyEquivalent: "")
        languageMenuItem.image = menuSymbol("globe")
        languageMenuItem.submenu = makeLanguageMenu(selected: .portuguese)
        recentMenuItem = menu.addItem(withTitle: "Textos recentes", action: nil, keyEquivalent: "")
        recentMenuItem.image = menuSymbol("clock.arrow.circlepath")
        recentMenuItem.submenu = makeRecentMenu([])
        detailsMenuItem = menu.addItem(withTitle: "Detalhes do status", action: nil, keyEquivalent: "")
        detailsMenuItem.image = menuSymbol("exclamationmark.triangle")
        detailsMenuItem.isHidden = true
        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "Ajustes…", action: #selector(AppDelegate.showSettings), keyEquivalent: "")
        settingsItem.target = delegate
        settingsItem.image = menuSymbol("slider.horizontal.3")
        let setupItem = menu.addItem(withTitle: "Configurar Resenha…", action: #selector(AppDelegate.showPermissionSetup), keyEquivalent: "")
        setupItem.target = delegate
        setupItem.image = menuSymbol("checklist")
        permissionsMenuItem = menu.addItem(withTitle: "Permissões", action: nil, keyEquivalent: "")
        permissionsMenuItem.image = menuSymbol("lock.shield")
        permissionsMenuItem.isHidden = true
        enableMenuItem = menu.addItem(withTitle: "Ativar permissões", action: #selector(AppDelegate.enablePermissions), keyEquivalent: "")
        enableMenuItem.target = delegate
        enableMenuItem.image = menuSymbol("hand.raised")
        let checkItem = menu.addItem(withTitle: "Verificar permissões", action: #selector(AppDelegate.checkPermissions), keyEquivalent: "")
        checkItem.target = delegate
        checkItem.image = menuSymbol("arrow.clockwise")
        menu.addItem(.separator())
        let aboutItem = menu.addItem(withTitle: "Sobre o Resenha", action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        aboutItem.target = delegate
        aboutItem.image = menuSymbol("info.circle")
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Encerrar Resenha", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        quitItem.target = delegate
        quitItem.image = menuSymbol("power")
        statusItem.menu = menu
    }

    func updateRecentTranscripts(_ items: [TranscriptHistoryItem], storageAvailable: Bool = true) {
        recentMenuItem?.submenu = makeRecentMenu(items, storageAvailable: storageAvailable)
    }

    func updateLanguage(_ language: TranscriptionLanguage) {
        languageMenuItem?.title = "Idioma — \(language.displayName)"
        languageMenuItem?.submenu = makeLanguageMenu(selected: language)
    }

    func updateRecordingLevel(_ level: Float) {
        guard isRecording else { return }
        let step = RecordingResonance.menuStep(level: level)
        guard step != recordingStep else { return }
        recordingStep = step
        statusItem?.button?.image = ResenhaBrand.resonatingMenuBarImage(level: level)
    }

    private func makeLanguageMenu(selected: TranscriptionLanguage) -> NSMenu {
        let menu = NSMenu(title: "Idioma")
        menu.delegate = delegate
        menu.autoenablesItems = false
        for language in TranscriptionLanguage.allCases {
            let item = menu.addItem(withTitle: language.displayName,
                action: #selector(AppDelegate.selectTranscriptionLanguage), keyEquivalent: "")
            item.target = delegate
            item.representedObject = language.rawValue
            item.state = language == selected ? .on : .off
        }
        return menu
    }

    private func makeRecentMenu(_ items: [TranscriptHistoryItem], storageAvailable: Bool = true) -> NSMenu {
        let menu = NSMenu(title: "Textos recentes")
        menu.delegate = delegate
        menu.autoenablesItems = false
        if !storageAvailable {
            menu.addItem(NativeMenuText.item("Histórico local indisponível. O texto atual continua no clipboard."))
            if !items.isEmpty { menu.addItem(.separator()) }
        }
        if items.isEmpty {
            if storageAvailable {
                menu.addItem(withTitle: "Nenhum texto recente", action: nil, keyEquivalent: "").isEnabled = false
            }
            return menu
        }
        for item in items {
            let normalized = item.text.replacingOccurrences(of: "\n", with: " ")
            let preview = normalized.count > 64 ? String(normalized.prefix(61)) + "…" : normalized
            let menuItem = menu.addItem(withTitle: preview,
                action: #selector(AppDelegate.copyRecentTranscript), keyEquivalent: "")
            menuItem.target = delegate
            menuItem.representedObject = item.text
        }
        menu.addItem(.separator())
        let clear = menu.addItem(withTitle: "Limpar textos recentes…",
            action: #selector(AppDelegate.confirmClearHistory), keyEquivalent: "")
        clear.target = delegate
        return menu
    }

    func makePermissionsMenu(_ snapshot: PermissionSnapshot) -> NSMenu {
        let menu = NSMenu(title: "Permissões")
        menu.delegate = delegate
        menu.autoenablesItems = false
        for (index, presentation) in snapshot.presentations.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            menu.addItem(withTitle: presentation.status, action: nil, keyEquivalent: "").isEnabled = false
            guard !presentation.isGranted else { continue }
            let permission = presentation.permission
            menu.addItem(NativeMenuText.item(permission.purpose))
            let item = menu.addItem(withTitle: permission.settingsActionTitle,
                action: #selector(AppDelegate.openPermissionSettings), keyEquivalent: "")
            item.target = delegate
            item.representedObject = permission
            if settingsNavigationFailures.contains(permission) {
                menu.addItem(NativeMenuText.item("Não foi possível abrir os Ajustes. \(permission.manualRecovery)"))
            } else {
                menu.addItem(NativeMenuText.item(permission.manualRecovery))
            }
        }
        return menu
    }

    func makeDetailsMenu(_ error: DictationErrorPresentation) -> NSMenu {
        let menu = NSMenu(title: "Detalhes do status")
        menu.delegate = delegate
        menu.autoenablesItems = false
        menu.addItem(NativeMenuText.item("Causa: \(error.title)"))
        if let diagnostic = error.diagnostic {
            menu.addItem(withTitle: "Diagnóstico", action: nil, keyEquivalent: "").isEnabled = false
            // Each item fits on screen; native menu scrolling exposes the complete safe path.
            var remainder = diagnostic[...]
            while !remainder.isEmpty {
                let end = remainder.index(remainder.startIndex, offsetBy: min(180, remainder.count))
                menu.addItem(NativeMenuText.item(String(remainder[..<end])))
                remainder = remainder[end...]
            }
        }
        menu.addItem(.separator())
        menu.addItem(NativeMenuText.item("Recuperação: \(error.recovery)"))
        return menu
    }

    private func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
}
