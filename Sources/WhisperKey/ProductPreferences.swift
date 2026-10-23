import AppKit
import AVFoundation
import Combine
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
    nonisolated static let maximumGlossaryCharacters = 20_000
    private enum Key {
        static let shortcut = "resenha.shortcut"
        static let showsHUD = "resenha.showsHUD"
        static let soundsEnabled = "resenha.soundsEnabled"
        static let keepsHistory = "resenha.keepsHistory"
        static let transcriptionLanguage = "resenha.transcriptionLanguage"
        static let transcriptionGlossary = "resenha.transcriptionGlossary"
        static let readySoundID = "resenha.readySoundID"
        static let contextualCorrectionsEnabled = "resenha.contextualCorrectionsEnabled"
        static let localPreviewEnabled = "resenha.localPreviewEnabled"
        static let personalRemoteEnabled = "resenha.personalRemoteEnabled"
    }
    private let defaults: UserDefaults
    private var updatesGlossaryMemoryOnly = false
    @Published private(set) var canSaveTranscriptionCorrection = true
    @Published private(set) var contextualCorrectionsEnabled: Bool
    @Published private(set) var personalRemoteEnabled: Bool
    var continuousContextEnabled: Bool { localPreviewEnabled || personalRemoteEnabled }
    @Published var localPreviewEnabled: Bool {
        didSet {
            defaults.set(localPreviewEnabled, forKey: Key.localPreviewEnabled)
            if oldValue != localPreviewEnabled { onLocalPreviewChange?(localPreviewEnabled) }
        }
    }
    var onShortcutChange: ((HotkeyShortcut) -> Void)?
    var onHUDChange: ((Bool) -> Void)?
    var onHistoryChange: ((Bool) -> Void)?
    var onLanguageChange: ((TranscriptionLanguage) -> Void)?
    var onLocalPreviewChange: ((Bool) -> Void)?
    var onPersonalRemoteChange: ((Bool) -> Void)?

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
            guard !updatesGlossaryMemoryOnly else { return }
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

    enum CorrectionSaveResult: Equatable {
        case saved
        case alreadyExists
        case invalid(TranscriptionGlossary.CorrectionValidationError)
        case storageFailure(recoveryRequired: Bool)

        var message: String {
            switch self {
            case .saved: "Termo adicionado ao vocabulário"
            case .alreadyExists: "Termo já existente"
            case .invalid(let error): error.message
            case .storageFailure(false): "Não foi possível salvar. O glossário anterior foi restaurado. Tente novamente."
            case .storageFailure(true): "Não foi possível verificar o glossário. Feche e reabra a correção para recarregá-lo."
            }
        }
    }

    func saveTranscriptionCorrection(heard: String, canonical: String) -> CorrectionSaveResult {
        guard canSaveTranscriptionCorrection else { return .storageFailure(recoveryRequired: true) }
        let previousText = transcriptionGlossary
        let previousValue = defaults.object(forKey: Key.transcriptionGlossary)
        guard verifiedGlossaryText(value: previousValue)?.utf8.elementsEqual(previousText.utf8) == true else {
            canSaveTranscriptionCorrection = false
            return .storageFailure(recoveryRequired: true)
        }
        let candidate: String
        switch TranscriptionGlossary.feedbackVocabularyCandidate(heard: heard, canonical: canonical, existingText: previousText) {
        case .alreadyExists: return .alreadyExists
        case .invalid(let error): return .invalid(error)
        case .added(let text): candidate = text
        }
        transcriptionGlossary = candidate
        if let stored = verifiedGlossaryText(value: defaults.object(forKey: Key.transcriptionGlossary)),
           stored.utf8.elementsEqual(candidate.utf8),
           TranscriptionGlossary(text: stored) == TranscriptionGlossary(text: candidate) {
            return .saved
        }

        setGlossaryMemory(previousText)
        if let previousValue { defaults.set(previousValue, forKey: Key.transcriptionGlossary) }
        else { defaults.removeObject(forKey: Key.transcriptionGlossary) }
        let restoredValue = defaults.object(forKey: Key.transcriptionGlossary)
        let restored = verifiedGlossaryText(value: restoredValue)
        let restoredAbsence = (previousValue == nil) == (restoredValue == nil)
        canSaveTranscriptionCorrection = restoredAbsence
            && restored?.utf8.elementsEqual(previousText.utf8) == true
            && restored.map { TranscriptionGlossary(text: $0) } == TranscriptionGlossary(text: previousText)
        return .storageFailure(recoveryRequired: !canSaveTranscriptionCorrection)
    }

    @discardableResult
    func reloadTranscriptionGlossaryForCorrection() -> Bool {
        guard let text = verifiedGlossaryText(value: defaults.object(forKey: Key.transcriptionGlossary)) else {
            canSaveTranscriptionCorrection = false
            return false
        }
        setGlossaryMemory(text)
        canSaveTranscriptionCorrection = true
        return true
    }

    func persistContextualCorrectionsEnabled(_ enabled: Bool) throws {
        defaults.set(enabled, forKey: Key.contextualCorrectionsEnabled)
        guard defaults.object(forKey: Key.contextualCorrectionsEnabled) is Bool,
              defaults.bool(forKey: Key.contextualCorrectionsEnabled) == enabled else {
            throw SyntheticDiagnosticAuthorizationError.localBetaDisabled
        }
        contextualCorrectionsEnabled = enabled
    }

    func persistPersonalRemoteEnabled(_ enabled: Bool) throws {
        let previous = personalRemoteEnabled
        defaults.set(enabled, forKey: Key.personalRemoteEnabled)
        guard defaults.object(forKey: Key.personalRemoteEnabled) is Bool,
              defaults.bool(forKey: Key.personalRemoteEnabled) == enabled else {
            throw PersonalRemoteAuthorizationError.credentialUnverified
        }
        personalRemoteEnabled = enabled
        if previous != enabled { onPersonalRemoteChange?(enabled) }
    }

    private func verifiedGlossaryText(value: Any?) -> String? {
        guard value == nil || value is String else { return nil }
        let text = value as? String ?? TranscriptionGlossary.defaultText
        let reread = defaults.object(forKey: Key.transcriptionGlossary)
        guard (value == nil) == (reread == nil), reread == nil || reread is String,
              text.count <= Self.maximumGlossaryCharacters,
              text.utf8.elementsEqual((reread as? String ?? TranscriptionGlossary.defaultText).utf8),
              (defaults.string(forKey: Key.transcriptionGlossary) ?? TranscriptionGlossary.defaultText).utf8.elementsEqual(text.utf8),
              TranscriptionGlossary(text: text) == TranscriptionGlossary(text: reread as? String ?? TranscriptionGlossary.defaultText)
        else { return nil }
        return text
    }

    private func setGlossaryMemory(_ text: String) {
        updatesGlossaryMemoryOnly = true
        transcriptionGlossary = text
        updatesGlossaryMemoryOnly = false
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultShortcut = HotkeyShortcut.rightOption
        shortcut = HotkeyShortcut(rawValue: defaults.string(forKey: Key.shortcut) ?? "") ?? defaultShortcut
        showsHUD = defaults.object(forKey: Key.showsHUD) as? Bool ?? true
        soundsEnabled = defaults.object(forKey: Key.soundsEnabled) as? Bool ?? true
        keepsHistory = defaults.object(forKey: Key.keepsHistory) as? Bool ?? true
        contextualCorrectionsEnabled = defaults.object(forKey: Key.contextualCorrectionsEnabled) as? Bool ?? false
        personalRemoteEnabled = defaults.object(forKey: Key.personalRemoteEnabled) as? Bool ?? false
        localPreviewEnabled = defaults.object(forKey: Key.localPreviewEnabled) as? Bool ?? false
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

extension ProductPreferences: ContextualOptInStore {}
extension ProductPreferences: PersonalRemoteOptInStore {}

@MainActor
func runSyntheticDiagnostic(
    _ diagnostic: SyntheticDiagnosticController
) async -> (result: SyntheticDiagnosticResult?, errorMessage: String?) {
    do {
        return (try await diagnostic.run(), nil)
    } catch let error as SyntheticDiagnosticError {
        let message: String? = switch error {
        case .authorizationUnavailable: "Autorize novamente o diagnóstico sintético."
        case .timedOut: "O diagnóstico sintético expirou."
        case .providerRejected: "O provedor recusou o diagnóstico sintético."
        case .transportUnavailable: "Não foi possível acessar o diagnóstico sintético."
        case .invalidResponse: "O diagnóstico recebeu uma resposta inválida."
        case .cancelled: nil
        }
        return (nil, message)
    } catch {
        return (nil, "Não foi possível concluir o diagnóstico sintético.")
    }
}

@MainActor
final class ContextualSettingsModel: ObservableObject {
    static let disclosureLines = [
        "Correções contextuais (beta)",
        "Beta local, desligado por padrão: usa incerteza do Whisper, glossário e exemplos confirmados.",
        "Avaliação remota pessoal é separada e começa desligada.",
        "Diagnóstico de infraestrutura: envia somente a frase sintética identificada ao OpenRouter/TypeSafe, uma única vez.",
        "O diagnóstico não recebe nem corrige seu ditado pessoal."
    ]
    static let personalDisclosure = "Ao ativar, o Resenha usa o JEV para escolher entre manter uma palavra já transcrita ou aplicar até três alternativas locais durante a fala. Envia somente a frase atual e essas opções ao OpenRouter/TypeSafe — nunca áudio, probabilidades, vocabulário completo, histórico, clipboard ou conteúdo do aplicativo de destino. São no máximo seis envios por ditado, com intervalo mínimo de 500 ms, prazo de 1,2 s durante a fala, 900 ms na finalização e payload de até 4096 bytes. O provedor pode cobrar conforme uso; o Resenha não estima o custo total. Revogar remove a chave deste Mac e volta imediatamente ao modo local."
    static let diagnosticAccessibilityLabel = "Executar diagnóstico sintético uma vez"
    static let authorizePersonalAccessibilityLabel = "Ativar avaliação remota pessoal"
    static let revokePersonalAccessibilityLabel = "Desativar avaliação remota e remover chave"
    static let deleteExampleAccessibilityLabel = "Apagar exemplo contextual"
    static let deleteAllAccessibilityLabel = "Apagar todos os exemplos contextuais"
    static let removeCredentialAccessibilityLabel = "Remover chave do diagnóstico"

    let authorization: any SyntheticDiagnosticAuthorizationManaging
    let diagnostic: SyntheticDiagnosticController
    let personalAuthorization: (any PersonalRemoteAuthorizationManaging)?
    @Published var credential = ""
    @Published var personalCredential = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRunningDiagnostic = false
    var personalRemoteCanDispatch: Bool {
        personalAuthorization?.personalRemoteHealth().canDispatch == true
    }

    init(
        authorization: any SyntheticDiagnosticAuthorizationManaging,
        diagnostic: SyntheticDiagnosticController,
        personalAuthorization: (any PersonalRemoteAuthorizationManaging)? = nil
    ) {
        self.authorization = authorization
        self.diagnostic = diagnostic
        self.personalAuthorization = personalAuthorization
    }

    func setLocalBetaEnabled(_ enabled: Bool) async {
        do {
            try await authorization.setLocalBetaEnabled(enabled)
            if !enabled { try? personalAuthorization?.revokePersonalRemote() }
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível alterar o beta local."
        }
    }

    func authorizeDiagnostic() async {
        do {
            try await authorization.authorizeSyntheticDiagnostic(
                explicitConsent: true,
                credential: credential
            )
            credential = ""
            statusMessage = "Diagnóstico sintético autorizado."
            errorMessage = nil
        } catch {
            credential = ""
            statusMessage = nil
            errorMessage = "Não foi possível autorizar o diagnóstico sintético."
        }
    }

    func removeCredential() async {
        do {
            try await authorization.removeSyntheticDiagnosticCredential()
            credential = ""
            statusMessage = "Chave do diagnóstico removida."
            errorMessage = nil
        } catch {
            credential = ""
            statusMessage = nil
            errorMessage = "Não foi possível remover a chave do diagnóstico."
        }
    }

    func authorizePersonalRemote() {
        do {
            guard let personalAuthorization else { throw PersonalRemoteAuthorizationError.releaseUnavailable }
            try personalAuthorization.authorizePersonalRemote(
                explicitConsent: true,
                credential: personalCredential
            )
            personalCredential = ""
            statusMessage = "Avaliação remota pessoal ativada."
            errorMessage = nil
        } catch {
            personalCredential = ""
            statusMessage = nil
            errorMessage = "Não foi possível ativar. Confirme uma chave válida e ao menos um exemplo local."
        }
    }

    func revokePersonalRemote() {
        do {
            guard let personalAuthorization else { throw PersonalRemoteAuthorizationError.releaseUnavailable }
            try personalAuthorization.revokePersonalRemote()
            personalCredential = ""
            statusMessage = "Avaliação remota desativada e chave removida."
            errorMessage = nil
        } catch {
            personalCredential = ""
            statusMessage = nil
            errorMessage = "A avaliação foi desativada, mas não foi possível confirmar a remoção da chave."
        }
    }

    func runDiagnostic() async {
        isRunningDiagnostic = true
        defer { isRunningDiagnostic = false }
        let observation = await runSyntheticDiagnostic(diagnostic)
        errorMessage = observation.errorMessage
        guard let result = observation.result else {
            if observation.errorMessage == nil { statusMessage = nil }
            return
        }
        statusMessage = "Diagnóstico concluído: \(result.outcome.category.rawValue). Modelo \(result.receipt.resolvedModel)."
    }

    func deleteExample(id: UUID, from store: ContextualCorrectionStore) {
        errorMessage = store.delete(id: id) ? nil : "Não foi possível apagar a correção contextual."
    }

    func deleteAll(from store: ContextualCorrectionStore) {
        errorMessage = store.deleteAll() ? nil : "Não foi possível apagar as correções contextuais."
    }
}

struct ProductSettingsView: View {
    @ObservedObject var preferences: ProductPreferences
    @ObservedObject var contextualStore: ContextualCorrectionStore
    @StateObject private var contextualModel: ContextualSettingsModel
    @ObservedObject private var contextualAttemptStore: ContextualAttemptStore
    @State private var selection = ProductSettingsSection.general

    init(
        preferences: ProductPreferences,
        contextualStore: ContextualCorrectionStore,
        authorization: any SyntheticDiagnosticAuthorizationManaging,
        diagnostic: SyntheticDiagnosticController,
        personalAuthorization: (any PersonalRemoteAuthorizationManaging)? = nil,
        contextualAttemptStore: ContextualAttemptStore,
        initialSection: ProductSettingsSection = .general
    ) {
        self.preferences = preferences
        self.contextualStore = contextualStore
        self.contextualAttemptStore = contextualAttemptStore
        _contextualModel = StateObject(wrappedValue: ContextualSettingsModel(
            authorization: authorization,
            diagnostic: diagnostic,
            personalAuthorization: personalAuthorization
        ))
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
                case .transcription: TranscriptionSettingsPane(
                    preferences: preferences,
                    contextualStore: contextualStore,
                    contextualModel: contextualModel,
                    contextualAttemptStore: contextualAttemptStore
                )
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
    @ObservedObject var contextualStore: ContextualCorrectionStore
    @ObservedObject var contextualModel: ContextualSettingsModel
    @ObservedObject var contextualAttemptStore: ContextualAttemptStore
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
                ResenhaRuleSection("Prévia local") {
                    Text("Mostra no HUD uma hipótese provisória enquanto você fala. O texto fica neste Mac e só é inserido depois que você solta o atalho.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Toggle("Mostrar prévia local durante o ditado", isOn: $preferences.localPreviewEnabled)
                        .accessibilityLabel("Mostrar prévia local durante o ditado")
                        .accessibilityHint("Ativa somente a prévia processada neste Mac. Não autoriza avaliação remota.")
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
                ResenhaRuleSection(ContextualSettingsModel.disclosureLines[0]) {
                    Text(ContextualSettingsModel.disclosureLines[1]).font(.callout)
                    Text(ContextualSettingsModel.disclosureLines[2]).font(.callout)
                    Toggle("Ativar beta local", isOn: Binding(
                        get: { preferences.contextualCorrectionsEnabled },
                        set: { enabled in Task { await contextualModel.setLocalBetaEnabled(enabled) } }
                    ))
                    .accessibilityLabel("Ativar correções contextuais locais")
                    Divider()
                    Text(ContextualSettingsModel.personalDisclosure).font(.callout)
                    SecureField("Chave pessoal do OpenRouter", text: $contextualModel.personalCredential)
                        .accessibilityLabel("Chave da avaliação remota pessoal")
                    HStack {
                        Button("Ativar avaliação remota") { contextualModel.authorizePersonalRemote() }
                            .accessibilityLabel(ContextualSettingsModel.authorizePersonalAccessibilityLabel)
                        Button("Desativar e remover chave") { contextualModel.revokePersonalRemote() }
                            .accessibilityLabel(ContextualSettingsModel.revokePersonalAccessibilityLabel)
                    }
                    Label(
                        contextualModel.personalRemoteCanDispatch
                            ? "Avaliação remota ativada"
                            : (preferences.personalRemoteEnabled ? "Avaliação remota pausada; somente local" : "Somente local"),
                        systemImage: contextualModel.personalRemoteCanDispatch ? "network" : "lock.fill"
                    )
                    .accessibilityLabel(
                        contextualModel.personalRemoteCanDispatch
                            ? "Avaliação remota pessoal ativada"
                            : "Avaliação remota pessoal indisponível; modo local"
                    )
                    if let attempt = contextualAttemptStore.latest {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Última avaliação JEV").font(.callout.weight(.semibold))
                            Text(attemptSummary(attempt)).font(.callout)
                            Text(attemptDetails(attempt))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        Button("Apagar registros técnicos") { contextualAttemptStore.deleteAll() }
                            .accessibilityLabel("Apagar registros técnicos do JEV")
                    } else {
                        Text("Nenhuma avaliação JEV registrada neste Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if !contextualAttemptStore.storageAvailable {
                        Text("O registro técnico local está indisponível.")
                            .font(.callout)
                            .foregroundStyle(ResenhaTheme.warning)
                    }
                    Divider()
                    Text(ContextualSettingsModel.disclosureLines[3]).font(.callout)
                    Text(ContextualSettingsModel.disclosureLines[4]).font(.callout)
                    SecureField("Chave descartável do OpenRouter", text: $contextualModel.credential)
                        .accessibilityLabel("Chave do diagnóstico sintético")
                    HStack {
                        Button("Autorizar diagnóstico") {
                            Task { await contextualModel.authorizeDiagnostic() }
                        }
                        Button("Executar uma vez") {
                            Task { await contextualModel.runDiagnostic() }
                        }
                        .disabled(contextualModel.isRunningDiagnostic)
                        .accessibilityLabel(ContextualSettingsModel.diagnosticAccessibilityLabel)
                        Button("Remover chave") {
                            Task { await contextualModel.removeCredential() }
                        }
                        .accessibilityLabel(ContextualSettingsModel.removeCredentialAccessibilityLabel)
                    }
                    ForEach(contextualStore.examples) { example in
                        HStack {
                            Text("\(example.heard) → \(example.canonical)")
                            Spacer()
                            Button("Apagar") { contextualModel.deleteExample(id: example.id, from: contextualStore) }
                                .accessibilityLabel(ContextualSettingsModel.deleteExampleAccessibilityLabel)
                        }
                    }
                    if !contextualStore.examples.isEmpty {
                        Button("Apagar todos") { contextualModel.deleteAll(from: contextualStore) }
                            .accessibilityLabel(ContextualSettingsModel.deleteAllAccessibilityLabel)
                    }
                    if let status = contextualModel.statusMessage {
                        Text(status).accessibilityLabel(status)
                    }
                    if let error = contextualModel.errorMessage {
                        Text(error).foregroundStyle(ResenhaTheme.warning).accessibilityLabel(error)
                    }
                }
            }
        }
    }

    private func attemptSummary(_ attempt: ContextualAttemptRecord) -> String {
        switch attempt.status {
        case .requested: return "Solicitada; aguardando resposta."
        case .failed: return "Falhou sem alterar o texto (\(attempt.failure?.rawValue ?? "unknown"))."
        case .succeeded:
            let action = switch attempt.disposition {
            case .appliedReplacement: "Aplicou a correção"
            case .keptOriginal: "Manteve o texto original"
            case .discarded: "Resposta descartada; não guiou a saída"
            case nil: "Resposta recebida; uso ainda não confirmado"
            }
            return "\(action). Modelo \(attempt.resolvedModel ?? "desconhecido")."
        }
    }

    private func attemptDetails(_ attempt: ContextualAttemptRecord) -> String {
        var parts = [attempt.startedAt.formatted(date: .abbreviated, time: .standard)]
        if let latency = attempt.latencyMilliseconds { parts.append("\(latency) ms") }
        if let stage = attempt.stage {
            let revision = attempt.revision.map { " r\($0)" } ?? ""
            let dispatch = attempt.dispatchOrdinal.map { " #\($0)" } ?? ""
            parts.append("\(stage.rawValue)\(revision)\(dispatch)")
        }
        if !attempt.decisions.isEmpty { parts.append(attempt.decisions.map(\.rawValue).joined(separator: ", ")) }
        if let confidence = attempt.minimumConfidence { parts.append(String(format: "conf. %.0f%%", confidence * 100)) }
        if let cost = attempt.costUSD { parts.append("US$ \(NSDecimalNumber(decimal: cost).stringValue)") }
        if let requestID = attempt.providerRequestID { parts.append("ID \(requestID)") }
        return parts.joined(separator: " · ")
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
    private let contextualStore: ContextualCorrectionStore
    private let authorization: any SyntheticDiagnosticAuthorizationManaging
    private let diagnostic: SyntheticDiagnosticController
    private let personalAuthorization: (any PersonalRemoteAuthorizationManaging)?
    private let contextualAttemptStore: ContextualAttemptStore

    init(
        preferences: ProductPreferences,
        contextualStore: ContextualCorrectionStore,
        authorization: any SyntheticDiagnosticAuthorizationManaging,
        diagnostic: SyntheticDiagnosticController,
        personalAuthorization: (any PersonalRemoteAuthorizationManaging)? = nil,
        contextualAttemptStore: ContextualAttemptStore
    ) {
        self.preferences = preferences
        self.contextualStore = contextualStore
        self.authorization = authorization
        self.diagnostic = diagnostic
        self.personalAuthorization = personalAuthorization
        self.contextualAttemptStore = contextualAttemptStore
    }

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
        window.contentView = NSHostingView(rootView: ProductSettingsView(
            preferences: preferences,
            contextualStore: contextualStore,
            authorization: authorization,
            diagnostic: diagnostic,
            personalAuthorization: personalAuthorization,
            contextualAttemptStore: contextualAttemptStore
        ))
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
