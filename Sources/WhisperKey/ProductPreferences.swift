import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt"
    case english = "en"
    case spanish = "es"

    var id: Self { self }
    var displayName: String {
        switch self {
        case .portuguese: "PT-BR"
        case .english: "EN"
        case .spanish: "ES"
        }
    }
}

struct HotkeyShortcut: RawRepresentable, CaseIterable, Identifiable, Hashable {
    static let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn]

    let keyCode: Int64
    let requiredFlags: CGEventFlags
    let keyLabel: String
    let isModifierOnly: Bool

    static let rightOption = Self(keyCode: 61, flags: .maskAlternate, keyLabel: "Option direita", isModifierOnly: true)
    static let leftOption = Self(keyCode: 58, flags: .maskAlternate, keyLabel: "Option esquerda", isModifierOnly: true)
    static let controlSpace = Self(keyCode: 49, flags: .maskControl, keyLabel: "Espaço")
    static let optionSpace = Self(keyCode: 49, flags: .maskAlternate, keyLabel: "Espaço")
    static let controlOptionSpace = Self(keyCode: 49, flags: [.maskControl, .maskAlternate], keyLabel: "Espaço")
    static let commandShiftSpace = Self(keyCode: 49, flags: [.maskCommand, .maskShift], keyLabel: "Espaço")
    static let allCases = [rightOption, leftOption, controlSpace, optionSpace, controlOptionSpace, commandShiftSpace]

    var id: String { rawValue }

    init(keyCode: Int64, flags: CGEventFlags, keyLabel: String, isModifierOnly: Bool = false) {
        self.keyCode = keyCode
        requiredFlags = flags.intersection(Self.relevantFlags)
        self.keyLabel = keyLabel
        self.isModifierOnly = isModifierOnly
    }

    var rawValue: String {
        let label = Data(keyLabel.utf8).base64EncodedString()
        return "v1|\(keyCode)|\(requiredFlags.rawValue)|\(isModifierOnly ? 1 : 0)|\(label)"
    }

    init?(rawValue: String) {
        let legacy: [String: Self] = [
            "rightOption": .rightOption, "leftOption": .leftOption,
            "controlSpace": .controlSpace, "optionSpace": .optionSpace,
            "controlOptionSpace": .controlOptionSpace, "commandShiftSpace": .commandShiftSpace
        ]
        if let shortcut = legacy[rawValue] { self = shortcut; return }
        let parts = rawValue.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[0] == "v1",
              let keyCode = Int64(parts[1]), let flags = UInt64(parts[2]),
              let modifierOnly = Int(parts[3]),
              let labelData = Data(base64Encoded: String(parts[4])),
              let label = String(data: labelData, encoding: .utf8), !label.isEmpty else { return nil }
        self.init(keyCode: keyCode, flags: CGEventFlags(rawValue: flags), keyLabel: label, isModifierOnly: modifierOnly == 1)
    }

    func isPressed(
        eventType: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        modifierKeyDown: Bool? = nil
    ) -> Bool? {
        guard keyCode == self.keyCode else { return nil }
        if isModifierOnly {
            guard eventType == .flagsChanged else { return nil }
            return modifierKeyDown ?? flags.contains(requiredFlags)
        }
        guard eventType == .keyDown || eventType == .keyUp else { return nil }
        guard eventType == .keyDown else { return false }
        return flags.intersection(Self.relevantFlags) == requiredFlags
    }
    var displayName: String {
        if isModifierOnly { return keyLabel }
        var parts: [String] = []
        if requiredFlags.contains(.maskControl) { parts.append("Control") }
        if requiredFlags.contains(.maskAlternate) { parts.append("Option") }
        if requiredFlags.contains(.maskShift) { parts.append("Shift") }
        if requiredFlags.contains(.maskCommand) { parts.append("Command") }
        if requiredFlags.contains(.maskSecondaryFn) { parts.append("Fn") }
        parts.append(keyLabel)
        return parts.joined(separator: " + ")
    }
}

@MainActor
final class ProductPreferences: ObservableObject {
    static let maximumGlossaryCharacters = 20_000
    private enum Key {
        static let shortcut = "resenha.shortcut"
        static let showsHUD = "resenha.showsHUD"
        static let soundsEnabled = "resenha.soundsEnabled"
        static let keepsHistory = "resenha.keepsHistory"
        static let transcriptionLanguage = "resenha.transcriptionLanguage"
        static let transcriptionGlossary = "resenha.transcriptionGlossary"
        static let readySoundID = "resenha.readySoundID"
    }
    private let defaults: UserDefaults
    var onShortcutChange: ((HotkeyShortcut) -> Void)?
    var onHUDChange: ((Bool) -> Void)?
    var onHistoryChange: ((Bool) -> Void)?
    var onLanguageChange: ((TranscriptionLanguage) -> Void)?

    @Published var shortcut: HotkeyShortcut {
        didSet {
            defaults.set(shortcut.rawValue, forKey: Key.shortcut)
            if oldValue != shortcut { onShortcutChange?(shortcut) }
        }
    }
    @Published var showsHUD: Bool {
        didSet {
            defaults.set(showsHUD, forKey: Key.showsHUD)
            if oldValue != showsHUD { onHUDChange?(showsHUD) }
        }
    }
    @Published var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Key.soundsEnabled) }
    }
    @Published var keepsHistory: Bool {
        didSet {
            defaults.set(keepsHistory, forKey: Key.keepsHistory)
            if oldValue != keepsHistory { onHistoryChange?(keepsHistory) }
        }
    }
    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            defaults.set(transcriptionLanguage.rawValue, forKey: Key.transcriptionLanguage)
            if oldValue != transcriptionLanguage { onLanguageChange?(transcriptionLanguage) }
        }
    }
    @Published var transcriptionGlossary: String {
        didSet {
            if transcriptionGlossary.count > Self.maximumGlossaryCharacters {
                transcriptionGlossary = String(transcriptionGlossary.prefix(Self.maximumGlossaryCharacters))
            }
            defaults.set(transcriptionGlossary, forKey: Key.transcriptionGlossary)
        }
    }
    @Published var readySoundID: Int {
        didSet { defaults.set(readySoundID, forKey: Key.readySoundID) }
    }
    var readySound: ResenhaSound {
        ResenhaSoundCatalog.sound(id: readySoundID) ?? ResenhaSoundCatalog.defaultSound
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultShortcut = HotkeyShortcut.rightOption
        shortcut = HotkeyShortcut(rawValue: defaults.string(forKey: Key.shortcut) ?? "") ?? defaultShortcut
        showsHUD = defaults.object(forKey: Key.showsHUD) as? Bool ?? true
        soundsEnabled = defaults.object(forKey: Key.soundsEnabled) as? Bool ?? true
        keepsHistory = defaults.object(forKey: Key.keepsHistory) as? Bool ?? true
        transcriptionLanguage = TranscriptionLanguage(
            rawValue: defaults.string(forKey: Key.transcriptionLanguage) ?? ""
        ) ?? .portuguese
        transcriptionGlossary = String(
            (defaults.string(forKey: Key.transcriptionGlossary) ?? TranscriptionGlossary.defaultText)
                .prefix(Self.maximumGlossaryCharacters)
        )
        let storedSoundID = defaults.integer(forKey: Key.readySoundID)
        readySoundID = ResenhaSoundCatalog.sound(id: storedSoundID)?.id ?? ResenhaSoundCatalog.defaultSoundID
    }
}

struct ProductSettingsView: View {
    @ObservedObject var preferences: ProductPreferences
    @State private var selection = ProductSettingsSection.general

    init(preferences: ProductPreferences, initialSection: ProductSettingsSection = .general) {
        self.preferences = preferences
        _selection = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image("ResenhaLockup")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 116, height: 34, alignment: .leading)
                Spacer()
                Label("local neste Mac", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 15)

            Divider()

            HStack(spacing: 0) {
                ForEach(ProductSettingsSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        VStack(spacing: 3) {
                            Text(section.index)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(section.title)
                                .font(.system(size: 12, weight: selection == section ? .semibold : .regular))
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Abrir ajustes de \(section.title)")
                    .accessibilityHint(selection == section ? "Seção atual" : "Troca a seção exibida")
                    .foregroundStyle(selection == section ? ResenhaTheme.accent : Color.primary)
                    .overlay(alignment: .bottom) {
                        if selection == section {
                            Rectangle().fill(ResenhaTheme.accent).frame(height: 2)
                        }
                    }
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }

            Divider()

            Group {
                switch selection {
                case .general: GeneralSettingsPane(preferences: preferences)
                case .shortcut: ShortcutSettingsPane(preferences: preferences)
                case .sounds: SoundLibrarySettingsPane(preferences: preferences)
                case .audio: AudioSettingsPane()
                case .transcription: TranscriptionSettingsPane(preferences: preferences)
                case .about: AboutSettingsPane()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(ResenhaBackdrop())
        .tint(ResenhaTheme.accent)
    }
}

enum ProductSettingsSection: String, CaseIterable, Identifiable {
    case general, shortcut, sounds, audio, transcription, about
    var id: Self { self }
    var index: String { String(format: "%02d", Self.allCases.firstIndex(of: self)! + 1) }
    var title: String {
        switch self {
        case .general: "Geral"
        case .shortcut: "Atalho"
        case .sounds: "Sons"
        case .audio: "Áudio"
        case .transcription: "Transcrição"
        case .about: "Sobre"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcut: "keyboard"
        case .sounds: "speaker.wave.2"
        case .audio: "mic"
        case .transcription: "text.bubble"
        case .about: "info.circle"
        }
    }
}

@MainActor
private final class SoundPreviewModel: ObservableObject {
    private let player = DictationCuePlayer()
    func play(_ sound: ResenhaSound) { player.preview(sound) }
}

private struct SoundLibrarySettingsPane: View {
    @ObservedObject var preferences: ProductPreferences
    @StateObject private var preview = SoundPreviewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResenhaPageHeader(
                eyebrow: "Personalidade",
                title: "Sons",
                subtitle: "Escolha a assinatura que confirma: agora pode falar."
            )
            HStack(alignment: .center, spacing: 12) {
                    Image(systemName: preferences.readySound.category.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(ResenhaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(ResenhaTheme.accent.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FALE AGORA")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(ResenhaTheme.accent)
                        Text(preferences.readySound.numberedName).fontWeight(.semibold)
                    }
                    Spacer()
                    Toggle("Sons ativos", isOn: $preferences.soundsEnabled)
            }
            .padding(.vertical, 4)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(ResenhaSoundCategory.allCases) { category in
                        Section {
                            ForEach(ResenhaSoundCatalog.sounds(in: category)) { sound in
                                soundRow(sound)
                                Divider().opacity(0.7)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: category.symbol)
                                Text(category.title.uppercased())
                                    .tracking(1.2)
                                Spacer()
                                Text("10 TOQUES")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(ResenhaTheme.accent)
                            .padding(.vertical, 9)
                            .background(.background.opacity(0.94))
                        }
                    }
                }
            }

            Text("Clique para ouvir e selecionar. Todos os sons são locais e têm menos de meio segundo.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func soundRow(_ sound: ResenhaSound) -> some View {
        Button {
            preferences.readySoundID = sound.id
            preview.play(sound)
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", sound.id))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                Text(sound.name)
                Spacer()
                if preferences.readySoundID == sound.id {
                    Text("EM USO")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(ResenhaTheme.accent)
                }
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvir e selecionar \(sound.numberedName)")
        .accessibilityValue(preferences.readySoundID == sound.id ? "Selecionado" : "Não selecionado")
        .accessibilityAddTraits(preferences.readySoundID == sound.id ? .isSelected : [])
    }
}

private struct TranscriptionSettingsPane: View {
    @ObservedObject var preferences: ProductPreferences
    @ObservedObject private var modelManager = WhisperModelManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
            ResenhaPageHeader(eyebrow: "Motor local", title: "Transcrição", subtitle: "Idioma, modelo e palavras que o Resenha precisa reconhecer.")
                ResenhaRuleSection("Idioma da fala") {
                    HStack {
                        Text("Idioma principal")
                        Spacer()
                Picker("Idioma", selection: $preferences.transcriptionLanguage) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                Text("PT-BR mantém palavras em inglês quando elas fazem parte da frase.")
                    .font(.callout).foregroundStyle(.secondary)
                }
                ResenhaRuleSection("Modelo local") {
                    modelStatus
                }
                ResenhaRuleSection("Vocabulário pessoal") {
                TextEditor(text: $preferences.transcriptionGlossary)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130)
                    .padding(8)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.10)))
                Text("\(TranscriptionGlossary(text: preferences.transcriptionGlossary).terms.count) termos. Use: forma ouvida = forma final.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Restaurar vocabulário padrão") {
                    preferences.transcriptionGlossary = TranscriptionGlossary.defaultText
                }
                }
            }
        }
    }

    @ViewBuilder
    private var modelStatus: some View {
        switch modelManager.state {
        case .missing:
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Modelo", value: "Ainda não instalado")
                Text("Download único de 181 MB. O modelo fica neste Mac e a voz nunca é enviada.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Baixar modelo local") { modelManager.download() }
                    .buttonStyle(.borderedProminent)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Baixando", value: progress.formatted(.percent.precision(.fractionLength(0))))
                ProgressView(value: progress)
                Text("Pode continuar usando o Mac. O download será verificado antes da instalação.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        case .verifying:
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Modelo", value: "Verificando integridade…")
                ProgressView()
            }
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Modelo", value: modelManager.model.displayName)
                Label("Instalado e verificado", systemImage: "checkmark.seal.fill")
                    .font(.callout.weight(.medium)).foregroundStyle(ResenhaTheme.success)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label("Download interrompido", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(ResenhaTheme.warning)
                Text(message).font(.callout).foregroundStyle(.secondary)
                Button("Tentar novamente") { modelManager.retry() }
            }
        }
    }
}

@MainActor
final class ProductSettingsWindowController {
    private(set) var window: NSWindow?
    private let preferences: ProductPreferences

    init(preferences: ProductPreferences) { self.preferences = preferences }

    func show() {
        let window = window ?? makeWindow()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ajustes do Resenha"
        window.minSize = NSSize(width: 700, height: 500)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ProductSettingsView(preferences: preferences))
        window.center()
        self.window = window
        return window
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var preferences: ProductPreferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
            ResenhaPageHeader(eyebrow: "Comportamento", title: "Geral", subtitle: "Controle como o Resenha aparece e guarda seus ditados.")
                ResenhaRuleSection("Inicialização") {
                    ResenhaToggleRow("Iniciar ao ligar o Mac", detail: "Fica disponível na barra de menus.", isOn: Binding(
                    get: { launchAtLogin },
                    set: updateLaunchAtLogin
                ))
                if let loginError { Text(loginError).font(.callout).foregroundStyle(ResenhaTheme.warning) }
            }
                ResenhaRuleSection("Durante o ditado") {
                    ResenhaToggleRow("Mostrar o HUD", detail: "O ditado funciona mesmo com o HUD oculto.", isOn: $preferences.showsHUD)
                    Divider()
                    ResenhaToggleRow("Sons de funcionamento", detail: "Abertura, início e fim da gravação.", isOn: $preferences.soundsEnabled)
                    Divider()
                    ResenhaToggleRow("Guardar os últimos 10 textos", detail: "Somente neste Mac; áudio nunca é guardado.", isOn: $preferences.keepsHistory)
                }
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginError = "Não foi possível alterar a inicialização automática."
        }
    }
}

private struct ShortcutSettingsPane: View {
    @ObservedObject var preferences: ProductPreferences
    @StateObject private var recorder = ShortcutCaptureController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
            ResenhaPageHeader(eyebrow: "Push to talk", title: "Atalho", subtitle: "Uma combinação global, disponível em qualquer aplicativo.")
                ResenhaRuleSection("Pressione e segure para falar") {
                    LabeledContent("Atalho atual", value: preferences.shortcut.displayName)
                    Text("Escolha uma tecla ou combinação. A mudança vale imediatamente em qualquer aplicativo.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(recorder.isRecording ? "Pressione o novo atalho…" : "Gravar novo atalho") {
                            recorder.begin { preferences.shortcut = $0 }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(recorder.isRecording)
                        Button("Usar Option direita") { preferences.shortcut = .rightOption }
                            .disabled(recorder.isRecording || preferences.shortcut == .rightOption)
                    }
                    if recorder.isRecording {
                        Text("Pressione a combinação completa e solte. Esc cancela.")
                            .font(.callout.weight(.medium)).foregroundStyle(ResenhaTheme.accent)
                    }
                }
                Spacer(minLength: 24)
                HStack(spacing: 14) {
                    Image(systemName: "keyboard.fill").font(.system(size: 28)).foregroundStyle(ResenhaTheme.accent)
                    Text(preferences.shortcut.displayName)
                        .font(.system(size: 26, weight: .medium, design: .serif))
                }
            }
        }
        .onDisappear { recorder.cancel() }
    }
}

private struct AudioSettingsPane: View {
    private var deviceName: String { AVCaptureDevice.default(for: .audio)?.localizedName ?? "Nenhum microfone disponível" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
            ResenhaPageHeader(eyebrow: "Entrada", title: "Áudio", subtitle: "O microfone é usado somente enquanto você segura o atalho.")
                ResenhaRuleSection("Entrada padrão do macOS") {
                LabeledContent("Microfone", value: deviceName)
                Text("O Resenha grava em mono, 16 kHz, somente enquanto o atalho está pressionado.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Abrir Ajustes de Som") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

}

private struct AboutSettingsPane: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }

    var body: some View {
        VStack(spacing: 18) {
            Image("ResenhaLockup")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 220, height: 56)
            Text("Fale. O Resenha escreve.")
                .font(.system(size: 26, weight: .semibold, design: .serif))
            VStack(spacing: 10) {
                    Label("Áudio e texto processados neste Mac", systemImage: "lock.shield.fill")
                    Label("Software livre e sem conta", systemImage: "chevron.left.forwardslash.chevron.right")
                    Text("Versão \(version)").foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
