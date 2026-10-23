import AppKit
import AVFoundation
import CryptoKit
import XCTest
import SwiftUI
@testable import WhisperKey

private actor DisabledCoordinatorDecisionProvider: ContextualDecisionProvider {
    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        preconditionFailure("Disabled coordinator tests must not reach a provider")
    }
}

private final class EphemeralContextualCredentialStore: ContextualCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    func save(_ value: String) throws { lock.withLock { self.value = value } }
    func load() throws -> String? { lock.withLock { value } }
    func delete() throws { lock.withLock { value = nil } }
}

private actor NoopSyntheticDiagnosticProvider: SyntheticDiagnosticDecisionProvider {
    func decideSynthetic(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt {
        throw OpenRouterDecisionsError.transportUnavailable
    }
}

@MainActor
private final class TestSettingsComposition {
    let store: ContextualCorrectionStore
    let authorization: SyntheticDiagnosticAuthorizationOwner
    let diagnostic: SyntheticDiagnosticController

    init(preferences: ProductPreferences) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)")
        store = ContextualCorrectionStore(fileURL: root.appendingPathComponent("contextual.json"))
        let policy = ContextualCorrectionPolicy()
        let time = ContinuousContextualTime()
        authorization = SyntheticDiagnosticAuthorizationOwner(
            optInStore: preferences,
            credentialStore: EphemeralContextualCredentialStore(),
            guardStore: SyntheticDiagnosticGuard(directoryURL: root.appendingPathComponent("guard")),
            policy: policy
        )
        diagnostic = SyntheticDiagnosticController(
            policy: policy,
            authorization: authorization,
            client: NoopSyntheticDiagnosticProvider(),
            validator: ContextualDecisionValidator(),
            fixture: .init(
                id: SyntheticDiagnosticFixture.id,
                pairID: "rosto-hostel",
                learningExampleIDs: ["learn-rosto-hostel-001"],
                language: "pt",
                input: "Reservei uma cama no rosto perto da estação.",
                heard: "rosto",
                canonical: "Hostel",
                ordinal: 1,
                expected: "Reservei uma cama no Hostel perto da estação."
            ),
            time: time
        )
    }
}

@MainActor
private extension DictationCoordinator {
    convenience init(
        permissions: PermissionService,
        panel: FloatingPanelController,
        showsHUD: @escaping () -> Bool = { true },
        soundsEnabled: @escaping () -> Bool = { true },
        language: @escaping () -> TranscriptionLanguage = { .portuguese },
        glossaryText: @escaping () -> String = { TranscriptionGlossary.defaultText },
        onRecordingLevel: @escaping (Float) -> Void = { _ in },
        onTranscript: @escaping (String) -> Void = { _ in },
        onFailure: @escaping (DictationErrorPresentation) -> Void = { _ in },
        transcriber: WhisperTranscriber = WhisperTranscriber()
    ) {
        let store = ContextualCorrectionStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/contextual.json"))
        let policy = ContextualCorrectionPolicy()
        let time = ContinuousContextualTime()
        let resolver = ContextualCorrectionResolver(
            store: store,
            policy: policy,
            provider: DisabledCoordinatorDecisionProvider(),
            storeGeneration: { store.generation },
            time: time
        )
        self.init(
            permissions: permissions,
            panel: panel,
            showsHUD: showsHUD,
            soundsEnabled: soundsEnabled,
            language: language,
            glossaryText: glossaryText,
            onRecordingLevel: onRecordingLevel,
            onTranscript: onTranscript,
            onFailure: onFailure,
            transcriber: transcriber,
            outputSink: TextInjector(),
            contextualResolver: resolver,
            contextualTokenSource: { _ in policy.issueToken(scope: .disabled) },
            contextualStoreGeneration: { store.generation }
        )
    }
}

final class WhisperKeyTests: XCTestCase {
    private func previewRevision(
        attemptID: UUID,
        revision: UInt64,
        text: String
    ) -> ContinuousContextRevision {
        ContinuousContextRevision(
            attemptID: attemptID,
            revision: revision,
            snapshotID: revision,
            sampleRange: 0..<8_000,
            sourceText: text,
            language: "pt",
            kind: .provisional,
            generationIDs: .init(session: 1, work: revision),
            capturedAt: 1,
            candidateAt: 1.1,
            emittedAt: 1.1,
            stablePrefixCharacterCount: 0,
            mutableSourceCharacterRange: 0..<text.count,
            mutableSuffix: text
        )
    }

    func testApprovedBrandAssetsLoadAndMenuBarImageIsTemplateSized() throws {
        XCTAssertNotNil(NSImage(named: "ResenhaMark"))
        XCTAssertNotNil(NSImage(named: "ResenhaLockup"))
        let menuBarImage = try XCTUnwrap(ResenhaBrand.menuBarImage())
        XCTAssertTrue(menuBarImage.isTemplate)
        XCTAssertEqual(menuBarImage.size, NSSize(width: 18, height: 18))
    }

    func testBrandResonanceTracksSpeechAndRespectsReducedMotion() throws {
        XCTAssertEqual(RecordingResonance.normalized(.nan), 0)
        XCTAssertEqual(RecordingResonance.normalized(-1), 0)
        XCTAssertEqual(RecordingResonance.normalized(2), 1)
        XCTAssertLessThan(RecordingResonance.markScale(level: 0, reduceMotion: false),
            RecordingResonance.markScale(level: 1, reduceMotion: false))
        XCTAssertLessThan(RecordingResonance.haloOpacity(level: 0.5, reduceMotion: false),
            RecordingResonance.haloOpacity(level: 1, reduceMotion: false))
        XCTAssertEqual(RecordingResonance.markScale(level: 0, reduceMotion: false), 0.84)
        XCTAssertEqual(RecordingResonance.markScale(level: 1, reduceMotion: false), 1.16)
        XCTAssertEqual(RecordingResonance.haloScale(level: 1, reduceMotion: false), 1.52)
        XCTAssertEqual(RecordingResonance.haloOpacity(level: 1, reduceMotion: false), 0.30)
        XCTAssertEqual(RecordingResonance.markScale(level: 1, reduceMotion: true), 1)
        XCTAssertEqual(RecordingResonance.haloOpacity(level: 1, reduceMotion: true), 0)
        XCTAssertEqual((0...4).map { RecordingResonance.menuStep(level: Float($0) / 4) }, [0, 1, 2, 3, 4])
        let quiet = try XCTUnwrap(try XCTUnwrap(ResenhaBrand.resonatingMenuBarImage(level: 0)).tiffRepresentation)
        let loud = try XCTUnwrap(try XCTUnwrap(ResenhaBrand.resonatingMenuBarImage(level: 1)).tiffRepresentation)
        XCTAssertNotEqual(quiet, loud)
    }

    @MainActor
    func testProductPreferencesPersistValidatedShortcutAndHUDChoice() {
        let suite = "ResenhaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        XCTAssertEqual(preferences.shortcut, .rightOption)
        XCTAssertTrue(preferences.showsHUD)
        XCTAssertTrue(preferences.soundsEnabled)
        XCTAssertTrue(preferences.keepsHistory)
        XCTAssertFalse(preferences.localPreviewEnabled)
        XCTAssertFalse(preferences.personalRemoteEnabled)
        XCTAssertEqual(preferences.transcriptionLanguage, .portuguese)
        XCTAssertTrue(preferences.transcriptionGlossary.contains("Resenha"))
        XCTAssertEqual(preferences.readySoundID, 60)
        var changed: HotkeyShortcut?
        var localPreviewChanges: [Bool] = []
        preferences.onShortcutChange = { changed = $0 }
        preferences.onLocalPreviewChange = { localPreviewChanges.append($0) }
        let customShortcut = HotkeyShortcut(keyCode: 40, flags: [.maskControl, .maskShift], keyLabel: "K")
        preferences.shortcut = customShortcut
        preferences.showsHUD = false
        preferences.soundsEnabled = false
        preferences.keepsHistory = false
        preferences.localPreviewEnabled = true
        preferences.transcriptionLanguage = .spanish
        preferences.transcriptionGlossary = "coisa = COESA"
        preferences.readySoundID = 3
        XCTAssertEqual(changed, customShortcut)
        XCTAssertEqual(localPreviewChanges, [true])
        let restored = ProductPreferences(defaults: defaults)
        XCTAssertEqual(restored.shortcut, customShortcut)
        XCTAssertFalse(restored.showsHUD)
        XCTAssertFalse(restored.soundsEnabled)
        XCTAssertFalse(restored.keepsHistory)
        XCTAssertTrue(restored.localPreviewEnabled)
        XCTAssertEqual(restored.transcriptionLanguage, .spanish)
        XCTAssertEqual(restored.transcriptionGlossary, "coisa = COESA")
        XCTAssertEqual(restored.readySoundID, 3)
        XCTAssertEqual(restored.readySound.name, "Pum seco")
    }

    @MainActor
    func testPersonalRemoteStartsContinuousContextWhenLocalPreviewIsOff() throws {
        let suite = "ResenhaRemoteContinuous.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)

        XCTAssertFalse(preferences.localPreviewEnabled)
        XCTAssertFalse(preferences.personalRemoteEnabled)
        XCTAssertFalse(preferences.continuousContextEnabled)
        try preferences.persistPersonalRemoteEnabled(true)
        XCTAssertFalse(preferences.localPreviewEnabled)
        XCTAssertTrue(preferences.continuousContextEnabled)
        try preferences.persistPersonalRemoteEnabled(false)
        XCTAssertFalse(preferences.continuousContextEnabled)
    }

    func testGlossaryBuildsPromptAndReplacesOnlyWholeTerms() {
        let glossary = TranscriptionGlossary(text: "Resenha\ncoisa = COESA\ncf galço = CF Gauss\ninválido =\n= vazio")
        XCTAssertEqual(glossary.prompt, "CF Gauss, COESA, Resenha")
        XCTAssertEqual(
            TranscriptPostprocessor.process("O resenha viu a coisa e a CF Galço chegarem à coisar.", glossary: glossary),
            "O Resenha viu a COESA e a CF Gauss chegarem à coisar."
        )
    }

    @MainActor
    func testGlossaryBoundsProtectPreferencesAndWhisperArguments() throws {
        let suite = "ResenhaGlossaryBounds.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        preferences.transcriptionGlossary = String(repeating: "x", count: ProductPreferences.maximumGlossaryCharacters + 100)
        XCTAssertEqual(preferences.transcriptionGlossary.count, ProductPreferences.maximumGlossaryCharacters)

        let lines = (0..<(TranscriptionGlossary.maximumTerms + 20))
            .map { "termo-\($0)-" + String(repeating: "y", count: TranscriptionGlossary.maximumLineCharacters + 20) }
            .joined(separator: "\n")
        let glossary = TranscriptionGlossary(text: lines)
        XCTAssertEqual(glossary.terms.count, TranscriptionGlossary.maximumTerms)
        XCTAssertLessThanOrEqual(glossary.terms.map(\.count).max() ?? 0, TranscriptionGlossary.maximumLineCharacters)
        XCTAssertLessThanOrEqual(glossary.prompt.count, TranscriptionGlossary.maximumPromptCharacters)
    }

    func testCorrectionCandidateValidatesFieldsAndPreservesExactExistingText() {
        for pair in [("", "Nome"), (" \t ", "Nome"), ("Nome", " ")] {
            XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: pair.0, canonical: pair.1, existingText: ""),
                           .invalid(.empty))
        }
        for invalid in ["nome\n", "\rnome", "no\u{2028}me", "no=me"] {
            XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: invalid, canonical: "Nome", existingText: ""),
                           .invalid(.invalidCharacters))
            XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "nome", canonical: invalid, existingText: ""),
                           .invalid(.invalidCharacters))
        }
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: " nome ", canonical: "nome", existingText: ""),
                       .invalid(.identical))
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: " nome ", canonical: " Nome ", existingText: ""),
                       .added(text: "Nome"))
        for existing in ["  anterior = Anterior  ", "anterior = Anterior\n", "anterior = Anterior\r\n"] {
            let separator = existing.last?.isNewline == true ? "" : "\n"
            XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: " coisa ", canonical: " COESA ", existingText: existing),
                           .added(text: existing + separator + "COESA"))
        }
    }

    func testCorrectionCandidateFindsConflictsAndOnlyAcceptsEffectiveDuplicates() {
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "COISA", canonical: "COESA", existingText: "coisa = COESA"),
                       .alreadyExists)
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "coesa", canonical: "COESA", existingText: "COESA"),
                       .alreadyExists)
        for existing in ["Coisa = Outra", "coisa = COESA\nCOISA = Outra", "COESA = Outra"] {
            guard case .invalid(.conflict) = TranscriptionGlossary.feedbackVocabularyCandidate(
                heard: "coisa", canonical: "COESA", existingText: existing
            ) else { return XCTFail("Conflito não identificado: \(existing)") }
        }
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "rosto", canonical: "Hostel", existingText: "rosto"),
                       .added(text: "rosto\nHostel"))
        let full = Array(repeating: "termo", count: 200).joined(separator: "\n")
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "coisa", canonical: "COESA", existingText: full + "\ncoisa = COESA"
        ), .invalid(.entryLimit))
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "coisa", canonical: "COESA", existingText: "coisa = COESA\n" + full + "\nCOISA = Outra"
        ), .invalid(.conflict(existingCanonical: "Outra")))
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "coisa", canonical: "COESA", existingText: "coisa = COESA\n" + full
        ), .alreadyExists)
        // ICU case folding matches the replacement engine, including the Kelvin sign.
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "K", canonical: "Kelvin", existingText: "K = Outra"
        ), .invalid(.conflict(existingCanonical: "Outra")))
    }

    func testCorrectionCandidateExactLineEntryTextAndPromptBoundaries() {
        let canonical157 = String(repeating: "á", count: 160)
        XCTAssertEqual(canonical157.count, 160)
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "x", canonical: canonical157, existingText: ""),
                       .added(text: canonical157))
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "x", canonical: canonical157 + "á", existingText: ""),
                       .invalid(.lineLimit))
        let entries199 = Array(repeating: "termo", count: 199).joined(separator: "\n")
        guard case .added(let at200) = TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "x", canonical: "Y", existingText: entries199
        ) else { return XCTFail("A entrada 200 deve ser aceita antes da deduplicação") }
        XCTAssertEqual(TranscriptionGlossary(text: at200).terms.count, 2)
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "x", canonical: "Y", existingText: entries199 + "\ntermo"),
                       .invalid(.entryLimit))
        let textPrefix = String(repeating: " ", count: 19_996) + "\n"
        guard case .added(let at20000) = TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "x", canonical: "YES", existingText: textPrefix
        ) else { return XCTFail("20.000 caracteres devem ser aceitos") }
        XCTAssertEqual(at20000.count, 20_000)
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "x", canonical: "YES", existingText: " " + textPrefix
        ), .invalid(.textLimit))

        let terms = (0..<50).map { String(format: "%02d", $0) + String(repeating: "a", count: 155) }
        let existing = terms.joined(separator: "\n")
        let finalTerm = String(repeating: "z", count: 50)
        guard case .added(let at8000) = TranscriptionGlossary.feedbackVocabularyCandidate(
            heard: "x", canonical: finalTerm, existingText: existing
        ) else { return XCTFail("8.000 caracteres de prompt devem ser aceitos") }
        XCTAssertEqual(TranscriptionGlossary(text: at8000).terms.joined(separator: ", ").count, 8_000)
        XCTAssertEqual(TranscriptionGlossary.feedbackVocabularyCandidate(heard: "x", canonical: finalTerm + "z", existingText: existing),
                       .invalid(.promptLimit))
    }

    func testFeedbackVocabularyNeverAddsMappingsAndLegacyParserKeepsEscapingAndCascade() {
        for pair in [("cifrão", "$COESA"), ("barra", #"C:\COESA"#), ("eriq", "Éric"), ("whisper.cp", "whisper.cpp")] {
            guard case .added(let text) = TranscriptionGlossary.feedbackVocabularyCandidate(
                heard: pair.0, canonical: pair.1, existingText: ""
            ) else { return XCTFail("Par representável recusado") }
            XCTAssertEqual(TranscriptPostprocessor.process("A \(pair.0) chegou.", glossary: .init(text: text)),
                           "A \(pair.0) chegou.")
            XCTAssertEqual(TranscriptPostprocessor.process("A \(pair.0) chegou.", glossary: .init(text: "\(pair.0) = \(pair.1)")),
                           "A \(pair.1) chegou.", "Manual settings mappings remain supported")
            XCTAssertTrue(TranscriptionGlossary(text: text).prompt.contains(pair.1))
        }
        let text = "erro longo = curto\ncurto = Final"
        XCTAssertEqual(TranscriptPostprocessor.process("erro longo", glossary: .init(text: text)), "Final")
    }

    private final class CorrectionDefaults: UserDefaults {
        var glossaryWrites = 0
        var glossaryRemovals = 0
        var divergeAfterWrite = false
        var divergentReads = 0
        var rejectRestoration = false
        var rejectNextWrite = false
        var unreadable = false

        override func set(_ value: Any?, forKey defaultName: String) {
            // UserDefaults.removeObject calls set(nil); count that operation only as a removal.
            guard defaultName == "resenha.transcriptionGlossary", value != nil else {
                super.set(value, forKey: defaultName)
                return
            }
            glossaryWrites += 1
            if rejectNextWrite { rejectNextWrite = false; return }
            if rejectRestoration && glossaryWrites > 1 { return }
            super.set(value, forKey: defaultName)
            if divergeAfterWrite { divergentReads = 1; divergeAfterWrite = false }
        }

        override func removeObject(forKey defaultName: String) {
            if defaultName == "resenha.transcriptionGlossary" {
                glossaryRemovals += 1
                if rejectRestoration { return }
            }
            super.removeObject(forKey: defaultName)
        }

        override func object(forKey defaultName: String) -> Any? {
            if defaultName == "resenha.transcriptionGlossary" {
                if unreadable { return 42 }
                if divergentReads > 0 { divergentReads -= 1; return "divergent read" }
            }
            return super.object(forKey: defaultName)
        }
    }

    @MainActor
    func testCorrectionSavePersistsCurrentSettingsAndOnlyGlossaryChanges() throws {
        let suite = "ResenhaCorrection.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        preferences.keepsHistory = false
        // This settings edit happens after the caller opened its draft.
        preferences.transcriptionGlossary = " anterior = Anterior "
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        defaults.glossaryWrites = 0
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: " Coisa Energia ", canonical: " COESA Energia "), .saved)
        XCTAssertEqual(defaults.glossaryWrites, 1)
        XCTAssertEqual(preferences.transcriptionGlossary, " anterior = Anterior \nCOESA Energia")
        let restored = ProductPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(restored.transcriptionGlossary, preferences.transcriptionGlossary)
        XCTAssertEqual(TranscriptPostprocessor.process(
            "A Coisa Energia chegou. Coisa Energias ficou.", glossary: .init(text: restored.transcriptionGlossary)
        ), "A Coisa Energia chegou. Coisa Energias ficou.")
        XCTAssertTrue(TranscriptionGlossary(text: restored.transcriptionGlossary).prompt.contains("COESA Energia"))
        XCTAssertFalse(String(describing: defaults.persistentDomain(forName: suite)).contains("Coisa Energia"))
        var after = defaults.persistentDomain(forName: suite) ?? [:]
        after.removeValue(forKey: "resenha.transcriptionGlossary")
        var otherBefore = before
        otherBefore.removeValue(forKey: "resenha.transcriptionGlossary")
        XCTAssertEqual(after as NSDictionary, otherBefore as NSDictionary)
        XCTAssertFalse(restored.keepsHistory)
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa energia", canonical: "COESA Energia"), .alreadyExists)
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "", canonical: "COESA"), .invalid(.empty))
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "anterior", canonical: "Outra"),
                       .invalid(.conflict(existingCanonical: "Anterior")))
        XCTAssertEqual(defaults.glossaryWrites, 1)
    }

    @MainActor
    func testCorrectionSaveRollsBackDivergentReadIncludingAbsentKey() throws {
        for original in [nil, " anterior = Anterior " as String?] {
            let suite = "ResenhaCorrectionRollback.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            if let original { defaults.set(original, forKey: "resenha.transcriptionGlossary") }
            defaults.glossaryWrites = 0
            let preferences = ProductPreferences(defaults: defaults)
            let previous = preferences.transcriptionGlossary
            defaults.divergeAfterWrite = true
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "Coisa Energia", canonical: "COESA Energia"),
                           .storageFailure(recoveryRequired: false))
            XCTAssertEqual(preferences.transcriptionGlossary, previous)
            XCTAssertEqual(defaults.string(forKey: "resenha.transcriptionGlossary"), original)
            XCTAssertEqual(defaults.glossaryWrites, original == nil ? 1 : 2)
            XCTAssertEqual(defaults.glossaryRemovals, original == nil ? 1 : 0)
            XCTAssertTrue(preferences.canSaveTranscriptionCorrection)
            XCTAssertEqual(ProductPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).transcriptionGlossary, previous)
        }
    }

    @MainActor
    func testFeedbackHostelStoresOnlyVocabularyAndNeverReplacesRosto() throws {
        let suite = "ResenhaTermOnly.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        preferences.transcriptionGlossary = "  legado = Legado  "
        defaults.glossaryWrites = 0
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "rosto", canonical: "Hostel"), .saved)
        XCTAssertEqual(preferences.transcriptionGlossary, "  legado = Legado  \nHostel")
        let restored = ProductPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        let glossary = TranscriptionGlossary(text: restored.transcriptionGlossary)
        XCTAssertTrue(glossary.prompt.contains("Hostel"))
        XCTAssertEqual(TranscriptPostprocessor.process("Meu rosto está vermelho", glossary: glossary), "Meu rosto está vermelho")
        XCTAssertFalse(glossary.replacements.contains { $0.heard == "rosto" })
        let after = defaults.persistentDomain(forName: suite) ?? [:]
        XCTAssertFalse(String(describing: after).contains("rosto"))
        XCTAssertEqual(Set(after.keys), Set(before.keys))
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "outro som", canonical: "Hostel"), .alreadyExists)
        XCTAssertEqual(defaults.glossaryWrites, 1)
        XCTAssertEqual(ProductPreferences.CorrectionSaveResult.saved.message, "Termo adicionado ao vocabulário")
    }

    @MainActor
    func testCorrectionDraftRejectsOversizedPasteBeforeSaveWithoutKeepingOrTruncatingInput() throws {
        let suite = "ResenhaDraftBound.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let panel = FloatingPanelController()
        defer { panel.hide() }
        panel.configureFeedback(preferences: preferences)
        let token = UUID()
        panel.offerFeedback(.init(id: token, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        panel.openCorrection(token: token)
        panel.updateCorrectionDraft(token: token, heard: "rosto", canonical: "Hostel")
        let oversized = String(repeating: "x", count: 161)
        let combining = "a" + String(repeating: "\u{0301}", count: TranscriptionGlossary.maximumCorrectionFieldBytes)
        XCTAssertEqual(combining.count, 1)
        for value in [oversized, combining, String(repeating: "z", count: 1_000_000)] {
            for invalidHeard in [true, false] {
                panel.updateCorrectionDraft(token: token, heard: invalidHeard ? value : "rosto",
                                            canonical: invalidHeard ? "Hostel" : value)
                XCTAssertEqual(panel.correctionDraft?.heard, "rosto")
                XCTAssertEqual(panel.correctionDraft?.canonical, "Hostel")
                XCTAssertFalse(panel.canSaveCorrection)
                XCTAssertEqual(panel.correctionSession?.invalidField, invalidHeard ? .heard : .canonical)
                XCTAssertTrue(panel.correctionError?.contains("160") == true)
                panel.saveCorrection(token: token)
                XCTAssertEqual(defaults.glossaryWrites, 0)
                XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: invalidHeard ? value : "rosto",
                    canonical: invalidHeard ? "Hostel" : value), .invalid(.lineLimit))
                panel.updateCorrectionDraft(token: token, heard: "rosto", canonical: "Hostel")
                XCTAssertTrue(panel.canSaveCorrection)
            }
        }
        let boundary = String(repeating: "x", count: 160)
        panel.updateCorrectionDraft(token: token, heard: boundary, canonical: "Hostel")
        XCTAssertEqual(panel.correctionDraft?.heard, boundary)
        XCTAssertTrue(panel.canSaveCorrection)
        XCTAssertEqual(defaults.glossaryWrites, 0)
    }

    @MainActor
    func testCorrectionTerminalClearsRetainedSessionAndReleasesEditorClosures() async throws {
        let suite = "ResenhaDraftRetention.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        for terminal in 0..<6 {
            let panel = FloatingPanelController()
            panel.configureFeedback(preferences: preferences)
            let token = UUID()
            panel.offerFeedback(.init(id: token, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
            panel.openCorrection(token: token)
            panel.updateCorrectionDraft(token: token, heard: "rosto", canonical: "Hostel\(terminal)")
            var retainedSession = try XCTUnwrap(panel.correctionSession) as CorrectionSession?
            weak var releasedSession = retainedSession
            let oldWindow = try XCTUnwrap(panel.correctionWindow)
            let writes = defaults.glossaryWrites
            switch terminal {
            case 0: panel.saveCorrection(token: token)
            case 1: panel.cancelFeedback(token: token, restoreFocus: false)
            case 2: oldWindow.performClose(nil)
            case 3: panel.show(.listening)
            case 4: panel.hide() // Same cleanup for HUD off/termination.
            default:
                defaults.glossaryWrites = 0
                defaults.divergeAfterWrite = true
                defaults.rejectRestoration = true
                panel.saveCorrection(token: token)
                XCTAssertFalse(panel.canSaveCorrection)
                panel.cancelFeedback(token: token, restoreFocus: false)
            }
            XCTAssertNil(panel.correctionDraft)
            XCTAssertEqual(retainedSession?.heard, "")
            XCTAssertEqual(retainedSession?.canonical, "")
            XCTAssertNil(retainedSession?.targetPID)
            XCTAssertNil(retainedSession?.token)
            XCTAssertNil(oldWindow.contentView)
            panel.saveCorrection(token: token)
            if terminal != 0 && terminal != 5 { XCTAssertEqual(defaults.glossaryWrites, writes) }
            XCTAssertFalse(String(describing: defaults.persistentDomain(forName: suite)).contains("rosto"))
            retainedSession = nil
            try await Task.sleep(for: .milliseconds(20))
            XCTAssertNil(releasedSession)
            panel.hide()
        }
    }

    @MainActor
    func testCorrectionSaveRejectsWriteAndRecoversWithoutFalseSuccess() throws {
        let suite = "ResenhaCorrectionRejectedWrite.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        defaults.rejectNextWrite = true
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa", canonical: "COESA"),
                       .storageFailure(recoveryRequired: false))
        XCTAssertNil(defaults.object(forKey: "resenha.transcriptionGlossary"))
        XCTAssertEqual(preferences.transcriptionGlossary, TranscriptionGlossary.defaultText)
        XCTAssertTrue(preferences.canSaveTranscriptionCorrection)
    }

    @MainActor
    func testCorrectionRollbackFailureBlocksDirectSaveUntilVerifiedReloadWithoutWrites() throws {
        for original in [nil, "Anterior" as String?] {
            let suite = "ResenhaCorrectionRecovery.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            if let original { defaults.set(original, forKey: "resenha.transcriptionGlossary") }
            defaults.glossaryWrites = 0
            let preferences = ProductPreferences(defaults: defaults)
            let previous = preferences.transcriptionGlossary
            defaults.divergeAfterWrite = true
            defaults.rejectRestoration = true
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa", canonical: "COESA"),
                           .storageFailure(recoveryRequired: true))
            XCTAssertEqual(preferences.transcriptionGlossary, previous)
            XCTAssertFalse(preferences.canSaveTranscriptionCorrection)
            let writes = defaults.glossaryWrites
            let removals = defaults.glossaryRemovals
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "outra", canonical: "Outra"),
                           .storageFailure(recoveryRequired: true))
            defaults.unreadable = true
            XCTAssertFalse(preferences.reloadTranscriptionGlossaryForCorrection())
            XCTAssertFalse(preferences.canSaveTranscriptionCorrection)
            XCTAssertEqual(preferences.transcriptionGlossary, previous)
            defaults.unreadable = false
            defaults.divergentReads = 1
            XCTAssertFalse(preferences.reloadTranscriptionGlossaryForCorrection())
            defaults.rejectRestoration = false
            XCTAssertTrue(preferences.reloadTranscriptionGlossaryForCorrection())
            XCTAssertTrue(preferences.canSaveTranscriptionCorrection)
            XCTAssertEqual(preferences.transcriptionGlossary, previous + "\nCOESA")
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa", canonical: "COESA"), .alreadyExists)
            XCTAssertFalse(preferences.transcriptionGlossary.contains("coisa"))
            XCTAssertEqual(defaults.glossaryWrites, writes)
            XCTAssertEqual(defaults.glossaryRemovals, removals)
        }
    }

    func testPersonalGlossaryCanonicalizesObservedPhysicalTranscripts() {
        let glossary = TranscriptionGlossary(text: TranscriptionGlossary.defaultText + """

        Éric
        Luís
        COESA
        MOVA
        CF Gauss
        eric = Éric
        luiz = Luís
        coesa = COESA
        mova = MOVA
        eriq = Éric
        a viva luís = avisa ao Luís
        """)
        XCTAssertEqual(
            TranscriptPostprocessor.process("testando o resenha no meu Mac.", glossary: glossary),
            "testando o Resenha no meu Mac."
        )
        XCTAssertEqual(
            TranscriptPostprocessor.process(
                "Eric, avise ao Luiz que a Coesa, a Mova e a CF Gauss participaram.",
                glossary: glossary
            ),
            "Éric, avise ao Luís que a COESA, a MOVA e a CF Gauss participaram."
        )
        XCTAssertEqual(
            TranscriptPostprocessor.process(
                "Eriq, a Viva Luís rodou o benchmark do whisper.cp às 17 horas.",
                glossary: glossary
            ),
            "Éric, avisa ao Luís rodou o benchmark do whisper.cpp às 17h00."
        )
    }

    func testExplicitCorrectionReplacesOnlyLastParaComplement() {
        let text = "Marque a apresentação para terça-feira às 15 horas. Não, corrige. Quarta-feira às 16h30."
        XCTAssertEqual(
            TranscriptPostprocessor.process(text, glossary: .init(text: "")),
            "Marque a apresentação para quarta-feira às 16h30."
        )
        XCTAssertEqual(
            TranscriptPostprocessor.process("Não, corrige isto literalmente.", glossary: .init(text: "")),
            "Não, corrige isto literalmente."
        )
        let physical = "Éric, avisa ao Luís que a Coisa atualizou o README e marcou a entrega pra terça-feira às 15h.Não. Corrige. Quarta-feira, às 16h30."
        XCTAssertEqual(
            TranscriptPostprocessor.process(physical, glossary: .init(text: "que a coisa = que a COESA")),
            "Éric, avisa ao Luís que a COESA atualizou o README e marcou a entrega pra quarta-feira, às 16h30."
        )
        let repeatedMarker = "Éric, avisa ao Luís que a COESA atualizou o README da Resenha, rodou o benchmark do whisper.cpp e marcou entrega pra quarta-feira às 16h30. Não, não, corrija. Às 17h00."
        XCTAssertEqual(
            TranscriptPostprocessor.process(repeatedMarker, glossary: .init(text: "")),
            "Éric, avisa ao Luís que a COESA atualizou o README da Resenha, rodou o benchmark do whisper.cpp e marcou entrega às 17h00."
        )
    }

    func testWhisperPathsPreferTurboButRespectExplicitEnvironmentModel() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let models = home.appendingPathComponent("Library/Application Support/WhisperKey/Models")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        let turbo = models.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin")
        let explicit = models.appendingPathComponent("custom.bin")
        FileManager.default.createFile(atPath: turbo.path, contents: Data())
        FileManager.default.createFile(atPath: explicit.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: home) }
        XCTAssertEqual(try WhisperPaths.resolve(environment: [:], home: home).model, turbo)
        XCTAssertEqual(try WhisperPaths.resolve(environment: ["WHISPER_MODEL_PATH": explicit.path], home: home).model, explicit)
    }

    @MainActor
    func testTranscriptHistoryPersistsLatestTenAndCollapsesConsecutiveDuplicate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaHistoryTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = TranscriptHistory(fileURL: file)
        history.add("primeiro", now: Date(timeIntervalSince1970: 1))
        history.add("primeiro", now: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(history.items.map(\.text), ["primeiro"])
        for index in 2...11 { history.add("texto \(index)", now: Date(timeIntervalSince1970: Double(index))) }
        XCTAssertEqual(history.items.count, 10)
        XCTAssertEqual(history.items.first?.text, "texto 11")
        XCTAssertFalse(history.items.contains { $0.text == "primeiro" })
        XCTAssertEqual(TranscriptHistory(fileURL: file).items.map(\.text), history.items.map(\.text))
        let directoryMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        ).intValue
        let fileMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        ).intValue
        XCTAssertEqual(directoryMode & 0o777, 0o700)
        XCTAssertEqual(fileMode & 0o777, 0o600)
        history.clear()
        XCTAssertTrue(history.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testTranscriptHistoryBoundsStoredTextAndRejectsOversizedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaHistoryBoundsTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = TranscriptHistory(fileURL: file)
        history.add(String(repeating: "x", count: TranscriptHistory.maximumTextCharacters + 1))
        XCTAssertEqual(history.items.first?.text.count, TranscriptHistory.maximumTextCharacters)

        try Data(repeating: 0, count: TranscriptHistory.maximumFileBytes + 1).write(to: file)
        let reloaded = TranscriptHistory(fileURL: file)
        XCTAssertTrue(reloaded.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .contains { $0.hasPrefix("history.corrupt-") })
    }

    func testDictationCuesUseDistinctProductAndNativeSounds() {
        XCTAssertNil(DictationCue.ready.nativeSoundName)
        XCTAssertNotEqual(DictationCue.started.nativeSoundName, DictationCue.stopped.nativeSoundName)
        XCTAssertEqual(String(data: ResenhaReadyTone.wavData.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertGreaterThan(ResenhaReadyTone.wavData.count, 20_000)
        XCTAssertNotNil(DictationCue.ready.makeSound())
        XCTAssertNotNil(DictationCue.started.makeSound())
        XCTAssertNotNil(DictationCue.stopped.makeSound())
        XCTAssertEqual(DictationCue.ready.maximumDuration, .milliseconds(500))
        XCTAssertEqual(DictationCue.started.maximumDuration, .milliseconds(250))
        XCTAssertEqual(DictationCue.stopped.maximumDuration, .milliseconds(250))
        XCTAssertGreaterThan(DictationCue.ready.volume, DictationCue.started.volume)
    }

    func testSoundLibraryContainsSeventyUniqueFastLocalSounds() {
        let sounds = ResenhaSoundCatalog.all
        XCTAssertEqual(sounds.count, 70)
        XCTAssertEqual(sounds.map(\.id), Array(1...70))
        XCTAssertEqual(Set(sounds.map(\.id)).count, 70)
        XCTAssertEqual(ResenhaSoundCatalog.defaultSound.id, 60)
        for category in ResenhaSoundCategory.allCases {
            XCTAssertEqual(ResenhaSoundCatalog.sounds(in: category).count, 10)
        }

        let rendered = sounds.map(ResenhaSoundRenderer.wavData)
        XCTAssertEqual(Set(rendered).count, 70)
        for (sound, data) in zip(sounds, rendered) {
            XCTAssertGreaterThanOrEqual(sound.duration, 0.18)
            XCTAssertLessThanOrEqual(sound.duration, 0.50)
            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertLessThanOrEqual(data.count, 44 + ResenhaSoundRenderer.sampleRate)
        }
    }

    func testSupportedLanguagesExposeWhisperCodesAndCompactMenuNames() {
        XCTAssertEqual(TranscriptionLanguage.allCases.map(\.rawValue), ["pt", "en", "es"])
        XCTAssertEqual(TranscriptionLanguage.allCases.map(\.displayName), ["PT-BR", "EN", "ES"])
    }

    func testProductSettingsNavigationKeepsEverySectionVisible() {
        XCTAssertEqual(ProductSettingsSection.allCases.count, 6)
        XCTAssertEqual(ProductSettingsSection.allCases.map(\.title),
            ["Geral", "Atalho", "Sons", "Áudio", "Transcrição", "Sobre"])
        XCTAssertEqual(Set(ProductSettingsSection.allCases.map(\.symbol)).count, 6)
    }

    @MainActor
    func testProductSettingsFixturesForEverySectionAndAppearance() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/ui-fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "ResenhaSettingsFixtures.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let contextual = TestSettingsComposition(preferences: preferences)

        for section in ProductSettingsSection.allCases {
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let view = NSHostingView(rootView: ProductSettingsView(
                    preferences: preferences,
                    contextualStore: contextual.store,
                    authorization: contextual.authorization,
                    diagnostic: contextual.diagnostic,
                    contextualAttemptStore: ContextualAttemptStore(fileURL: directory.appendingPathComponent("attempts-\(section.rawValue)-\(appearance).json")),
                    initialSection: section
                ).environment(\.colorScheme, scheme))
                view.frame = CGRect(x: 0, y: 0, width: 760, height: 560)
                view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                view.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("settings-\(section.rawValue)-\(appearance).png"))
            }
        }
    }

    func testCompletedTranscriptIsStagedOnClipboardWithoutSnapshotRestoration() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ResenhaTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let injector = TextInjector(pasteboard: pasteboard)
        let changeCount = try injector.stage("texto recuperável")
        XCTAssertEqual(pasteboard.string(forType: .string), "texto recuperável")
        XCTAssertEqual(pasteboard.changeCount, changeCount)
        XCTAssertThrowsError(try injector.stage("  \n ")) { error in
            XCTAssertEqual(error as? TextInjectionError, .emptyText)
        }
    }

    func testDirectInsertionRequiresTheOriginalApplicationToBeFrontmost() {
        XCTAssertTrue(TextInjectionTargetPolicy.isExpectedTarget(targetPID: 42, frontmostPID: 42))
        XCTAssertFalse(TextInjectionTargetPolicy.isExpectedTarget(targetPID: 42, frontmostPID: 7))
        XCTAssertFalse(TextInjectionTargetPolicy.isExpectedTarget(targetPID: 42, frontmostPID: nil))
    }

    func testHotkeyPresetsHaveDistinctNamesAndSafeTriggers() {
        XCTAssertEqual(Set(HotkeyShortcut.allCases.map(\.displayName)).count, HotkeyShortcut.allCases.count)
        XCTAssertTrue(HotkeyShortcut.rightOption.isModifierOnly)
        XCTAssertTrue(HotkeyShortcut.leftOption.isModifierOnly)
        for shortcut in HotkeyShortcut.allCases where !shortcut.isModifierOnly {
            XCTAssertEqual(shortcut.keyCode, 49)
            XCTAssertFalse(shortcut.requiredFlags.isEmpty)
        }
    }

    func testCustomHotkeyRoundTripsAndMatchesOnlyItsExactCombination() throws {
        let shortcut = HotkeyShortcut(keyCode: 40, flags: [.maskControl, .maskShift], keyLabel: "K")
        let restored = try XCTUnwrap(HotkeyShortcut(rawValue: shortcut.rawValue))
        XCTAssertEqual(restored, shortcut)
        XCTAssertEqual(restored.displayName, "Control + Shift + K")
        XCTAssertEqual(restored.isPressed(eventType: .keyDown, keyCode: 40, flags: [.maskControl, .maskShift]), true)
        XCTAssertEqual(restored.isPressed(eventType: .keyDown, keyCode: 40, flags: [.maskControl, .maskShift, .maskAlternate]), false)
        XCTAssertNil(restored.isPressed(eventType: .keyDown, keyCode: 41, flags: [.maskControl, .maskShift]))
        XCTAssertEqual(HotkeyShortcut(rawValue: "rightOption"), .rightOption)
    }

    @MainActor
    func testShortcutRecorderNormalizesOnlySupportedGlobalModifiers() {
        let flags = ShortcutCaptureController.flags(from: [.command, .option, .capsLock, .numericPad])
        XCTAssertEqual(flags, [.maskCommand, .maskAlternate])
    }

    func testHotkeyMatchingRejectsExtraModifiersAndInterruptionReleasesLatch() {
        XCTAssertEqual(HotkeyShortcut.controlSpace.isPressed(
            eventType: .keyDown, keyCode: 49, flags: .maskControl
        ), true)
        XCTAssertEqual(HotkeyShortcut.controlSpace.isPressed(
            eventType: .keyDown, keyCode: 49, flags: [.maskControl, .maskAlternate]
        ), false)
        XCTAssertEqual(HotkeyShortcut.controlSpace.isPressed(
            eventType: .keyUp, keyCode: 49, flags: .maskControl
        ), false)
        XCTAssertNil(HotkeyShortcut.controlSpace.isPressed(
            eventType: .keyDown, keyCode: 12, flags: .maskControl
        ))
        XCTAssertEqual(HotkeyShortcut.rightOption.isPressed(
            eventType: .flagsChanged, keyCode: 61, flags: .maskAlternate, modifierKeyDown: true
        ), true)
        XCTAssertEqual(HotkeyShortcut.rightOption.isPressed(
            eventType: .flagsChanged, keyCode: 61, flags: .maskAlternate, modifierKeyDown: false
        ), false)
        XCTAssertEqual(HotkeyShortcut.rightOption.isPressed(
            eventType: .flagsChanged, keyCode: 61, flags: .maskAlternate
        ), true)
        XCTAssertEqual(HotkeyShortcut.rightOption.isPressed(
            eventType: .flagsChanged, keyCode: 61, flags: []
        ), false)

        var latch = HotkeyLatch()
        XCTAssertEqual(latch.update(true), .pressed)
        XCTAssertNil(latch.update(true))
        XCTAssertEqual(latch.interrupt(), .released)
        XCTAssertFalse(latch.isPressed)
        XCTAssertNil(latch.interrupt())
    }

    @MainActor
    func testAppConfiguresBothGlobalHotkeyEdges() {
        let app = AppDelegate()
        XCTAssertFalse(app.isHotkeyRoutingConfigured)
        app.configureHotkeyRouting()
        XCTAssertTrue(app.isHotkeyRoutingConfigured)
    }

    @MainActor
    func testReopeningMenuBarAppShowsSettings() throws {
        let app = AppDelegate()

        XCTAssertTrue(app.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))

        let window = try XCTUnwrap(NSApplication.shared.windows.first {
            $0.title == "Ajustes do Resenha" && $0.isVisible
        })
        window.orderOut(nil)
    }

    func testStaleAudioCleanupKeepsFreshAndUnrelatedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaAudioCleanupTests-\(UUID().uuidString)", isDirectory: true)
        let directory = AudioRecorder.recordingDirectory(base: root)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stale = directory.appendingPathComponent("stale.wav")
        let fresh = directory.appendingPathComponent("fresh.wav")
        let unrelated = directory.appendingPathComponent("keep.txt")
        for file in [stale, fresh, unrelated] {
            XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data([0])))
        }
        let now = Date(timeIntervalSince1970: 2_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-AudioRecorder.staleRecordingAge - 1)],
            ofItemAtPath: stale.path
        )
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: fresh.path)

        AudioRecorder.cleanupStaleRecordings(
            now: now,
            olderThan: AudioRecorder.staleRecordingAge,
            directory: directory
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @MainActor
    func testHistoryReportsPersistenceFailureWithoutLosingInMemoryRecovery() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaHistoryFailureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appendingPathComponent("not-a-directory")
        XCTAssertTrue(FileManager.default.createFile(atPath: blocker.path, contents: Data()))
        let history = TranscriptHistory(fileURL: blocker.appendingPathComponent("history.json"))
        var callbackStorageAvailable: Bool?
        history.onChange = { _, available in callbackStorageAvailable = available }

        history.add("texto ainda recuperável")

        XCTAssertEqual(history.items.map(\.text), ["texto ainda recuperável"])
        XCTAssertFalse(history.storageAvailable)
        XCTAssertEqual(callbackStorageAvailable, false)
    }

    @MainActor
    func testProductSettingsReusesOneNativeWindow() throws {
        let preferences = ProductPreferences()
        let contextual = TestSettingsComposition(preferences: preferences)
        let controller = ProductSettingsWindowController(
            preferences: preferences,
            contextualStore: contextual.store,
            authorization: contextual.authorization,
            diagnostic: contextual.diagnostic,
            contextualAttemptStore: ContextualAttemptStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/attempts.json")
            )
        )
        controller.show()
        let first = try XCTUnwrap(controller.window)
        controller.show()
        XCTAssertTrue(first === controller.window)
        XCTAssertTrue(first.styleMask.contains(.resizable))
        XCTAssertEqual(first.minSize, NSSize(width: 700, height: 500))
        first.orderOut(nil)
    }

    func testPermissionOnboardingAppearsOnlyOnceWhileSetupIsIncomplete() {
        let blocked = PermissionSnapshot(microphone: true, inputMonitoring: false)
        let ready = PermissionSnapshot(microphone: true, inputMonitoring: true)
        XCTAssertTrue(PermissionOnboardingPolicy.shouldPresent(snapshot: blocked, hasPresented: false))
        XCTAssertFalse(PermissionOnboardingPolicy.shouldPresent(snapshot: blocked, hasPresented: true))
        XCTAssertFalse(PermissionOnboardingPolicy.shouldPresent(snapshot: ready, hasPresented: false))
    }

    @MainActor
    func testPermissionOnboardingReusesOneWindow() throws {
        let controller = PermissionOnboardingController(requestPermissions: {}, openSettings: { _ in })
        let blocked = PermissionSnapshot(microphone: false, inputMonitoring: false)
        controller.show(snapshot: blocked, isRequesting: false)
        let first = try XCTUnwrap(controller.window)
        controller.show(snapshot: blocked, isRequesting: true)
        XCTAssertTrue(first === controller.window)
        controller.close()
        XCTAssertFalse(first.isVisible)
    }

    func testPermissionPresentationCoversEveryAvailabilityCombination() {
        for microphone in [false, true] {
            for inputMonitoring in [false, true] {
                for accessibility in [false, true] {
                    let snapshot = PermissionSnapshot(microphone: microphone, inputMonitoring: inputMonitoring, accessibility: accessibility)
                    XCTAssertEqual(snapshot.isReady, microphone && inputMonitoring && accessibility)
                    XCTAssertEqual(snapshot.presentations.map(\.permission), [.microphone, .inputMonitoring, .accessibility])
                    XCTAssertEqual(snapshot.presentations.map(\.isGranted), [microphone, inputMonitoring, accessibility])
                    XCTAssertEqual(snapshot.missingPermissions.count, [microphone, inputMonitoring, accessibility].filter { !$0 }.count)
                    for presentation in snapshot.presentations {
                        XCTAssertEqual(presentation.status, "\(presentation.permission.name): \(presentation.isGranted ? "ativada" : "permissão necessária")")
                        XCTAssertFalse(presentation.permission.purpose.isEmpty)
                        XCTAssertEqual(presentation.permission.settingsActionTitle, "Abrir Ajustes de \(presentation.permission.name)")
                    }
                    let expectedMessage = !microphone ? "Acesso ao Microfone necessário"
                        : !inputMonitoring ? "Acesso ao Monitoramento de Entrada necessário"
                        : !accessibility ? "Acesso à Acessibilidade necessário" : "Permissões prontas"
                    XCTAssertEqual(snapshot.missingPermissionMessage, expectedMessage)
                }
                }
        }
    }

    func testPermissionSnapshotsDetectPartialRestorationAndRevocation() {
        let blocked = PermissionSnapshot(microphone: false, inputMonitoring: false)
        let partial = PermissionSnapshot(microphone: true, inputMonitoring: false)
        let ready = PermissionSnapshot(microphone: true, inputMonitoring: true)
        XCTAssertNotEqual(blocked, partial)
        XCTAssertNotEqual(blocked.missingPermissionMessage, partial.missingPermissionMessage)
        XCTAssertFalse(partial.isReady)
        XCTAssertEqual(partial.missingPermissions, [.inputMonitoring])
        XCTAssertEqual(partial, PermissionSnapshot(microphone: true, inputMonitoring: false))
        for revoked in [
            PermissionSnapshot(microphone: false, inputMonitoring: true),
            PermissionSnapshot(microphone: true, inputMonitoring: false)
        ] {
            XCTAssertNotEqual(ready, revoked)
            XCTAssertFalse(revoked.isReady)
            XCTAssertEqual(revoked.missingPermissions.count, 1)
        }
        XCTAssertTrue(ready.isReady)
        XCTAssertTrue(ready.missingPermissions.isEmpty)
    }

    func testPermissionDestinationsIdentifyEachSettingsPane() {
        XCTAssertEqual(RequiredPermission.microphone.name, "Microfone")
        XCTAssertEqual(RequiredPermission.inputMonitoring.name, "Monitoramento de Entrada")
        XCTAssertEqual(RequiredPermission.accessibility.name, "Acessibilidade")
        XCTAssertEqual(RequiredPermission.microphone.settingsDestination.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        XCTAssertEqual(RequiredPermission.inputMonitoring.settingsDestination.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        XCTAssertEqual(RequiredPermission.accessibility.settingsDestination.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @MainActor
    func testPartialSnapshotRefreshBuildsEveryPermissionWithoutFalseBlockers() {
        let app = AppDelegate()
        let blocked = PermissionSnapshot(microphone: false, inputMonitoring: false)
        let partial = PermissionSnapshot(microphone: true, inputMonitoring: false)
        let blockedMenu = app.makePermissionsMenu(blocked)
        let partialMenu = app.makePermissionsMenu(partial)
        XCTAssertTrue(blockedMenu.items.contains { $0.title == "Abrir Ajustes de Microfone" })
        XCTAssertFalse(partialMenu.items.contains { $0.title == "Abrir Ajustes de Microfone" })
        XCTAssertTrue(partialMenu.items.contains { $0.title == "Microfone: ativada" })
        XCTAssertTrue(partialMenu.items.contains { $0.title == "Abrir Ajustes de Monitoramento de Entrada" })
        XCTAssertTrue(partialMenu.delegate === app)
    }

    func testMenuActivityPriorityRetainsAllPermissionBlockers() {
        let snapshot = PermissionSnapshot(microphone: false, inputMonitoring: true)
        for (phase, expected) in [(DictationPhase.recording, "Ouvindo"), (.transcribing, "Transcrevendo"), (.inserting, "Inserindo")] {
            let presentation = MenuStatusPresentation(phase: phase, snapshot: snapshot, error: nil)
            XCTAssertEqual(presentation.activity, expected)
            XCTAssertTrue(presentation.accessibleStatus.contains("configurado no Resenha"))
            XCTAssertEqual(presentation.symbol, phase == .recording ? "mic.fill" : "waveform")
        }
        let blocked = MenuStatusPresentation(phase: .idle, snapshot: snapshot, error: nil)
        XCTAssertEqual(blocked.activity, "Permissões necessárias")
        XCTAssertEqual(blocked.symbol, "waveform.badge.exclamationmark")
        let ready = PermissionSnapshot(microphone: true, inputMonitoring: true)
        XCTAssertEqual(MenuStatusPresentation(phase: .idle, snapshot: ready, error: nil).activity, "Pronto")
        XCTAssertEqual(MenuStatusPresentation(phase: .idle, snapshot: ready, error: nil, hotkeyUnavailable: true).activity,
            "Atalho global indisponível")
    }

    func testRejectedMenuRequestAndSelfPressRequiresFreshRelease() {
        for blocker in 0..<3 {
            var interaction = DictationInteraction()
            interaction.openMenuCount = blocker == 0 ? 2 : 0
            interaction.isRequestingPermission = blocker == 1
            XCTAssertFalse(interaction.press(phase: .idle, targetIsSelf: blocker == 2))
            interaction.openMenuCount = 0
            interaction.isRequestingPermission = false
            XCTAssertFalse(interaction.press(phase: .idle, targetIsSelf: false), "Closing a guard must not replay a held press")
            interaction.release()
            XCTAssertTrue(interaction.press(phase: .idle, targetIsSelf: false))
            interaction.release()
        }
    }

    @MainActor
    func testActiveRecordingReleaseSurvivesMenuAndRequestGuards() {
        let app = AppDelegate()
        let root = NSMenu()
        let submenu = NSMenu()
        let panel = FloatingPanelController()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: panel)
        app.observeCoordinator(coordinator)
        app.menuWillOpen(root)
        app.menuWillOpen(submenu)
        XCTAssertEqual(app.interaction.openMenuCount, 2)
        app.handleHotkeyPress(targetIsSelf: false)
        XCTAssertEqual(coordinator.phase, .idle)
        app.menuDidClose(submenu)
        app.menuDidClose(root)
        app.handleHotkeyPress(targetIsSelf: false)
        XCTAssertEqual(coordinator.phase, .idle, "Closing the native menu does not replay its rejected press")
        app.handleHotkeyRelease()
        coordinator.transition(to: .recording)
        app.menuWillOpen(root)
        app.handleHotkeyRelease()
        XCTAssertNotEqual(coordinator.phase, .recording, "Even a controlled recording without an audio file must finish or fail")
        XCTAssertFalse(app.interaction.isPressed)
        app.menuDidClose(root)
        coordinator.cancel()
    }

    @MainActor
    func testSafeNativeStatusDetailsBoundWidthAndPreservePathsAndRecovery() throws {
        let app = AppDelegate()
        let failure = DictationErrorPresentation(error: WhisperError.failed(19, "PRIVATE RAW STDERR AND TRANSCRIPT"))
        let menu = app.makeDetailsMenu(failure)
        let content = menu.items.map(\.title).joined(separator: "\n")
        XCTAssertTrue(content.contains("Causa: Falha na transcrição"))
        XCTAssertTrue(content.contains("Código de saída: 19"))
        XCTAssertTrue(content.contains("Recuperação:"))
        XCTAssertFalse(content.contains("PRIVATE"))
        XCTAssertTrue(menu.delegate === app)
        let path = "/safe/" + String(repeating: "long-path-", count: 90) + "model.bin"
        let pathsMenu = app.makeDetailsMenu(DictationErrorPresentation(error: WhisperError.modelMissing(path)))
        let diagnosticIndex = try XCTUnwrap(pathsMenu.items.firstIndex { $0.title == "Diagnóstico" })
        let diagnosticItems = pathsMenu.items.dropFirst(diagnosticIndex + 1).prefix { !$0.isSeparatorItem }
        XCTAssertEqual(diagnosticItems.map(\.title).joined(), path)
        for item in diagnosticItems {
            let view = try XCTUnwrap(item.view)
            XCTAssertLessThanOrEqual(view.frame.width, 360)
            XCTAssertLessThan(view.frame.height, 180)
            let label = try XCTUnwrap(view.subviews.first as? NSTextField)
            XCTAssertEqual(label.stringValue, item.title)
            XCTAssertEqual(label.accessibilityLabel(), item.title)
            XCTAssertFalse(label.isEditable)
        }
        let narrow = NativeMenuText.item(path.prefix(180).description, availableWidth: 240)
        XCTAssertLessThanOrEqual(try XCTUnwrap(narrow.view).frame.width, 240)
    }

    @MainActor
    func testNamedSettingsFailureRetainsManualRecoveryUntilSuccessfulNavigation() throws {
        let app = AppDelegate()
        let snapshot = PermissionSnapshot(microphone: false, inputMonitoring: true)
        app.settingsNavigationFinished(false, for: .microphone)
        let rejected = app.makePermissionsMenu(snapshot)
        XCTAssertTrue(rejected.items.contains { $0.title.contains("Não foi possível abrir os Ajustes.")
            && $0.title.contains("Privacidade e Segurança → Microfone") })
        let action = try XCTUnwrap(rejected.items.first { $0.title == "Abrir Ajustes de Microfone" })
        XCTAssertEqual(action.representedObject as? RequiredPermission, .microphone)
        XCTAssertEqual(action.action, #selector(AppDelegate.openPermissionSettings))
        app.settingsNavigationFinished(true, for: .microphone)
        let opened = app.makePermissionsMenu(snapshot)
        XCTAssertFalse(opened.items.contains { $0.title.contains("Não foi possível abrir os Ajustes.") })
        XCTAssertTrue(opened.items.contains { $0.title == RequiredPermission.microphone.manualRecovery })
    }

    func testPermissionGateStartsWhenPermissionsArriveAfterLaunch() {
        XCTAssertFalse(PermissionGate.shouldStartHotkey(microphone: false, inputMonitoring: true, hotkeyRunning: false))
        XCTAssertFalse(PermissionGate.shouldStartHotkey(microphone: true, inputMonitoring: false, hotkeyRunning: false))
        XCTAssertFalse(PermissionGate.shouldStartHotkey(microphone: true, inputMonitoring: true, accessibility: false, hotkeyRunning: false))
        XCTAssertTrue(PermissionGate.shouldStartHotkey(microphone: true, inputMonitoring: true, hotkeyRunning: false))
        XCTAssertFalse(PermissionGate.shouldStartHotkey(microphone: true, inputMonitoring: true, hotkeyRunning: true))
    }

    func testPanelDismissalUsesCurrentGenerationAndDeadline() {
        var dismissal = PanelDismissal()
        dismissal.invalidate(deadline: 12)
        let ready = dismissal.generation
        XCTAssertFalse(dismissal.dismissIfCurrent(generation: ready, now: 11))
        dismissal.invalidate()
        XCTAssertFalse(dismissal.dismissIfCurrent(generation: ready, now: 20))
        dismissal.invalidate(deadline: 22)
        let failure = dismissal.generation
        XCTAssertFalse(dismissal.dismissIfCurrent(generation: ready, now: 30))
        XCTAssertTrue(dismissal.dismissIfCurrent(generation: failure, now: 22))
        XCTAssertFalse(dismissal.dismissIfCurrent(generation: failure, now: 23))
    }

    @MainActor
    func testOldReadyAndFailureDismissalsCannotReplaceListening() {
        let panel = FloatingPanelController()
        var callbacks = 0
        for status in [FloatingStatus.ready, .failure("Failure")] {
            panel.showTemporarily(status) { callbacks += 1 }
            let obsolete = panel.dismissal.generation
            panel.show(.listening, target: .session(42))
            panel.dismissIfCurrent(generation: obsolete, now: .greatestFiniteMagnitude)
            XCTAssertEqual(panel.target, .session(42))
            XCTAssertTrue(panel.isVisible)
            XCTAssertEqual(panel.status, .listening)
            XCTAssertEqual(callbacks, 0)
            panel.show(.transcribing, target: .session(42))
            panel.dismissIfCurrent(generation: obsolete, now: .greatestFiniteMagnitude)
            XCTAssertTrue(panel.isVisible)
            XCTAssertEqual(panel.status, .transcribing)
            XCTAssertEqual(callbacks, 0)
        }
        panel.hide()
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor
    func testRepeatedHideShowCancelsCallbackAndCurrentDismissalRunsOnce() {
        let panel = FloatingPanelController()
        var callbacks = 0
        panel.showTemporarily(.ready) { callbacks += 100 }
        let obsolete = panel.dismissal.generation
        panel.hide()
        panel.hide()
        panel.showTemporarily(.ready) { callbacks += 1 }
        let current = panel.dismissal.generation
        panel.dismissIfCurrent(generation: obsolete, now: .greatestFiniteMagnitude)
        XCTAssertEqual(callbacks, 0)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.status, .ready)
        panel.dismissIfCurrent(generation: current, now: .greatestFiniteMagnitude)
        panel.dismissIfCurrent(generation: current, now: .greatestFiniteMagnitude)
        XCTAssertEqual(callbacks, 1)
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor
    func testRepeatedAutomaticHotkeyFailuresKeepOriginalDismissalDeadline() throws {
        var feedback = HotkeyFailureFeedback()
        let panel = FloatingPanelController()
        let failure = FloatingStatus.failure("Atalho global indisponível")
        if feedback.recordFailure(phase: .idle, explicitCheck: false) { panel.showTemporarily(failure) }
        let generation = panel.dismissal.generation
        let deadline = try XCTUnwrap(panel.dismissal.deadline)
        XCTAssertTrue(panel.isVisible)
        for _ in 0..<3 {
            if feedback.recordFailure(phase: .idle, explicitCheck: false) { panel.showTemporarily(failure) }
            XCTAssertEqual(panel.dismissal.generation, generation)
            XCTAssertEqual(panel.dismissal.deadline, deadline)
        }
        panel.dismissIfCurrent(generation: generation, now: deadline)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(feedback.recordFailure(phase: .idle, explicitCheck: false))
        if feedback.recordFailure(phase: .idle, explicitCheck: true) { panel.showTemporarily(failure) }
        XCTAssertTrue(panel.isVisible)
        XCTAssertGreaterThan(panel.dismissal.generation, generation)
        panel.hide()
        feedback.lastAttemptFailed = false
        XCTAssertTrue(feedback.recordFailure(phase: .idle, explicitCheck: false))
        for phase in [DictationPhase.recording, .transcribing, .inserting, .failed] {
            XCTAssertFalse(feedback.recordFailure(phase: phase, explicitCheck: true))
        }
    }

    @MainActor
    func testFailureReturnsToIdleOnlyOnCurrentPanelDismissal() {
        let panel = FloatingPanelController()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: panel)
        var phases: [DictationPhase] = []
        coordinator.onPhaseChange = { phases.append($0) }
        coordinator.fail(DictationErrorPresentation(error: WhisperError.emptyTranscript))
        let generation = panel.dismissal.generation
        panel.dismissIfCurrent(generation: generation, now: 0)
        XCTAssertEqual(coordinator.phase, .failed)
        panel.dismissIfCurrent(generation: generation, now: .greatestFiniteMagnitude)
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertEqual(phases, [.failed, .idle])
        XCTAssertEqual(coordinator.currentError?.title, "Nenhuma fala detectada")
        coordinator.cancel()
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testCanceledFailureCannotResetNewSession() {
        let panel = FloatingPanelController()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: panel)
        coordinator.fail(DictationErrorPresentation(error: WhisperError.emptyTranscript))
        let obsolete = panel.dismissal.generation
        coordinator.cancel()
        coordinator.transition(to: .recording)
        panel.show(.listening)
        panel.dismissIfCurrent(generation: obsolete, now: .greatestFiniteMagnitude)
        XCTAssertEqual(coordinator.phase, .recording)
        coordinator.cancel()
    }

    @MainActor
    func testPermissionLossStopsOnlyRecordingAndPreservesProcessing() {
        let denied = PermissionSnapshot(microphone: false, inputMonitoring: true)
        let panel = FloatingPanelController()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: panel)
        coordinator.transition(to: .recording)
        coordinator.permissionLost(denied)
        XCTAssertEqual(coordinator.phase, .failed)
        XCTAssertTrue(coordinator.currentError?.isPermissionFailure == true)
        coordinator.permissionsRestored()
        XCTAssertNil(coordinator.currentError)
        coordinator.cancel()
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.permissionLost(denied)
        XCTAssertEqual(coordinator.phase, .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.permissionLost(denied)
        XCTAssertEqual(coordinator.phase, .inserting)
        coordinator.cancel()
    }

    @MainActor
    func testFeedbackCompletionRequiresCurrentSuccessfulInsertionAfterCleanup() {
        let panel = FloatingPanelController()
        var showsHUD = true
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: panel,
            showsHUD: { showsHUD }, soundsEnabled: { false })
        var completed: [UUID] = []
        coordinator.onCompleted = { context in
            XCTAssertEqual(coordinator.phase, .idle)
            XCTAssertFalse(panel.isVisible)
            XCTAssertNotEqual(coordinator.attemptID, context.id)
            completed.append(context.id)
        }
        let original = coordinator.attemptID
        coordinator.completeInsertion(attemptID: original, isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertTrue(completed.isEmpty)
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: original, isCancelled: true, text: "Transcrição concluída.", language: .portuguese)
        coordinator.completeInsertion(attemptID: UUID(), isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertTrue(completed.isEmpty)
        coordinator.cancel()
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: original, isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertEqual(coordinator.phase, .inserting, "A post-await stale completion cannot reset the next attempt")
        let current = coordinator.attemptID
        coordinator.completeInsertion(attemptID: current, isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertEqual(completed, [current])
        coordinator.completeInsertion(attemptID: current, isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertEqual(completed, [current])
        showsHUD = false
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: coordinator.attemptID, isCancelled: false, text: "Transcrição concluída.", language: .portuguese)
        XCTAssertEqual(completed, [current])
        for error in [WhisperError.emptyTranscript as Error, TextInjectionError.eventCreationFailed,
                      TextInjectionError.clipboardChanged, WhisperError.invalidAudio] {
            coordinator.fail(DictationErrorPresentation(error: error))
            XCTAssertEqual(completed, [current])
            coordinator.cancel()
        }
    }

    @MainActor
    func testFeedbackLikeCancelAndOldTimersNeverWriteOrReachNewSession() throws {
        let suite = "ResenhaFeedbackLifecycle.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        preferences.keepsHistory = false
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: preferences)
        panel.showTemporarily(.ready)
        let timer = panel.dismissal.generation
        let first = DictationCompletion(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese)
        panel.offerFeedback(first)
        XCTAssertTrue(panel.hasFeedback)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.feedbackTargetWindows.count, 2)
        XCTAssertNotNil(panel.dismissal.deadline)
        panel.dismissIfCurrent(generation: timer, now: .greatestFiniteMagnitude)
        XCTAssertEqual(panel.feedbackToken, first.id)
        panel.approveFeedback(token: first.id)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertTrue(panel.ignoresMouseEvents)
        let next = DictationCompletion(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese)
        panel.offerFeedback(next)
        panel.approveFeedback(token: first.id)
        panel.openCorrection(token: first.id)
        XCTAssertFalse(panel.isEditingCorrection)
        panel.openCorrection(token: next.id)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.correctionDraft?.heard, "")
        XCTAssertEqual(panel.correctionDraft?.canonical, "")
        panel.updateCorrectionDraft(token: next.id, heard: "Coisa", canonical: "COESA")
        let window = try XCTUnwrap(panel.correctionWindow)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(window.isVisible)
        window.performClose(nil)
        panel.saveCorrection(token: next.id)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertNil(panel.correctionDraft)
        XCTAssertEqual(defaults.glossaryWrites, 0)
        XCTAssertEqual(defaults.persistentDomain(forName: suite)! as NSDictionary, before as NSDictionary)
        panel.hide()
    }

    @MainActor
    func testFeedbackDeadlineExpiresOnlyCurrentPassiveOfferWithoutWrites() throws {
        let suite = "ResenhaFeedbackTimeout.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        var now: TimeInterval = 100
        let panel = FloatingPanelController(clock: { now })
        defer { panel.hide() }
        panel.configureFeedback(preferences: preferences)
        var menuToken: UUID?
        panel.onFeedbackChange = { [weak panel] in menuToken = panel?.approvalActionToken }
        let first = DictationCompletion(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese)
        panel.show(.inserting, target: .session(nil))
        let processingFrame = panel.frame
        panel.offerFeedback(first)
        XCTAssertEqual(panel.frame, processingFrame)
        XCTAssertEqual(panel.frame.size, CGSize(width: 280, height: 64))
        XCTAssertEqual(panel.dismissal.deadline, 104)
        XCTAssertEqual(panel.dismissal.feedbackToken, first.id)
        let generation = panel.dismissal.generation
        panel.dismissIfCurrent(generation: generation, now: 103.999)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(menuToken, first.id)
        XCTAssertEqual(panel.feedbackToken, first.id)
        now = 104
        panel.dismissIfCurrent(generation: generation, now: now)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertNil(panel.feedbackToken)
        XCTAssertNil(panel.correctionActionToken)
        XCTAssertNil(menuToken)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(defaults.glossaryWrites, 0)
        XCTAssertEqual((defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary, before as NSDictionary)
    }

    @MainActor
    func testFeedbackTimerCannotReachReplacementEditorRecordingNoticeOrHiddenHUD() throws {
        let suite = "ResenhaFeedbackStaleTimeout.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        var now: TimeInterval = 100
        let panel = FloatingPanelController(clock: { now })
        defer { panel.hide() }
        panel.configureFeedback(preferences: preferences)
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let oldGeneration = panel.dismissal.generation
        now = 102
        let next = UUID()
        panel.offerFeedback(.init(id: next, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let currentGeneration = panel.dismissal.generation
        panel.dismissIfCurrent(generation: oldGeneration, now: 104)
        XCTAssertEqual(panel.feedbackToken, next)
        XCTAssertEqual(panel.dismissal.deadline, 106)
        XCTAssertTrue(panel.isVisible)
        panel.openCorrection(token: next)
        XCTAssertNil(panel.dismissal.deadline)
        XCTAssertNil(panel.dismissal.feedbackToken)
        panel.updateCorrectionDraft(token: next, heard: "Coisa", canonical: "")
        panel.saveCorrection(token: next)
        let error = try XCTUnwrap(panel.correctionError)
        panel.dismissIfCurrent(generation: currentGeneration, now: .greatestFiniteMagnitude)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertTrue(panel.correctionWindow?.isVisible == true)
        XCTAssertEqual(panel.feedbackToken, next)
        XCTAssertEqual(panel.correctionDraft?.heard, "Coisa")
        XCTAssertEqual(panel.correctionError, error)
        for state in [FloatingStatus.listening, .feedbackNotice("Termo adicionado ao vocabulário")] {
            panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
            let generation = panel.dismissal.generation
            panel.show(state)
            panel.dismissIfCurrent(generation: generation, now: .greatestFiniteMagnitude)
            XCTAssertEqual(panel.status, state)
            XCTAssertTrue(panel.isVisible)
            XCTAssertFalse(panel.hasFeedback)
        }
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let hiddenGeneration = panel.dismissal.generation
        panel.hide()
        panel.dismissIfCurrent(generation: hiddenGeneration, now: .greatestFiniteMagnitude)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.dismissal.deadline)
        XCTAssertEqual(defaults.glossaryWrites, 0)
        XCTAssertEqual((defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary, before as NSDictionary)
    }

    @MainActor
    func testFeedbackFinitePhasesShareMonotonicDeadlineAndStopAtTerminal() {
        var now: TimeInterval = 100
        let panel = FloatingPanelController(clock: { now })
        defer { panel.hide() }
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let generation = panel.dismissal.generation
        XCTAssertEqual(panel.dismissal.deadline, 104)
        XCTAssertEqual(panel.feedbackPhase, .entering)
        XCTAssertEqual(panel.activePresentationTaskCount, 1)
        XCTAssertNil(panel.correctionDraft)
        panel.advanceFeedbackPresentation(generation: generation)
        XCTAssertEqual(panel.feedbackPhase, .resting)
        now = 103.249
        panel.advanceFeedbackPresentation(generation: generation)
        XCTAssertEqual(panel.feedbackPhase, .resting)
        now = 103.25
        panel.advanceFeedbackPresentation(generation: generation)
        XCTAssertEqual(panel.feedbackPhase, .exiting)
        XCTAssertEqual(panel.dismissal.deadline, 104)
        XCTAssertEqual(panel.feedbackTargetWindows.count, 2)
        now = 104
        panel.advanceFeedbackPresentation(generation: generation)
        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(panel.feedbackPhase, .hidden)
        XCTAssertEqual(panel.activePresentationTaskCount, 0)
        XCTAssertTrue(panel.feedbackTargetWindows.isEmpty)
        now = 1_000_000
        panel.advanceFeedbackPresentation(generation: generation)
        XCTAssertEqual(panel.feedbackPhase, .hidden)
    }

    @MainActor
    func testFeedbackOnlyTwoFixedNonactivatingTargetsReceiveActionsAndFollowScreenSpaceChanges() throws {
        let suite = "ResenhaFeedbackTargets.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let panel = FloatingPanelController()
        defer { panel.hide() }
        panel.configureFeedback(preferences: ProductPreferences(defaults: defaults))
        let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let first = UUID()
        panel.offerFeedback(.init(id: first, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let targets = panel.feedbackTargetWindows
        XCTAssertEqual(targets.count, 2)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, activePID)
        let labels = [FloatingStatusView.approveLabel, FloatingStatusView.correctLabel]
        let visual = try XCTUnwrap(NSApplication.shared.windows.first {
            $0.frame == panel.frame && $0.ignoresMouseEvents
        })
        for (index, target) in targets.enumerated() {
            XCTAssertEqual(target.frame.size, CGSize(width: 44, height: 44))
            XCTAssertEqual(target.frame.midY, panel.frame.midY)
            XCTAssertEqual(target.frame.midX, panel.frame.midX + (index == 0 ? -30 : 30))
            XCTAssertFalse(target.ignoresMouseEvents)
            XCTAssertFalse(target.canBecomeKey)
            XCTAssertFalse(target.canBecomeMain)
            XCTAssertNil(target.parent)
            XCTAssertTrue(visual.ignoresMouseEvents)
            XCTAssertFalse(visual.hasShadow)
            XCTAssertEqual(visual.backgroundColor?.alphaComponent, 0)
            XCTAssertEqual(target.level, visual.level)
            XCTAssertEqual(target.collectionBehavior, visual.collectionBehavior)
            let button = try XCTUnwrap(target.contentView as? NSButton)
            XCTAssertEqual(button.accessibilityLabel(), labels[index])
            XCTAssertFalse((button.accessibilityHelp() ?? "").isEmpty)
            XCTAssertTrue(button.hitTest(NSPoint(x: 22, y: 22)) === button)
            XCTAssertNil(button.hitTest(NSPoint(x: 45, y: 22)))
        }
        // The only event-receiving windows exclude the HUD background and gap.
        for point in [CGPoint(x: panel.frame.minX + 8, y: panel.frame.midY),
                      CGPoint(x: panel.frame.midX, y: panel.frame.midY),
                      CGPoint(x: panel.frame.midX, y: panel.frame.maxY - 2)] {
            XCTAssertFalse(targets.contains { $0.frame.contains(point) })
        }
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        XCTAssertEqual(panel.feedbackTargetWindows.map(\.frame), targets.map(\.frame))
        XCTAssertEqual(targets[0].frame.midX, panel.frame.midX - 30)
        let retiredButton = try XCTUnwrap(targets[0].contentView as? NSButton)
        retiredButton.performClick(nil)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertEqual(panel.activePresentationTaskCount, 0)
        XCTAssertTrue(targets.allSatisfy { !$0.isVisible && $0.parent == nil && $0.contentView == nil })

        let next = UUID()
        panel.offerFeedback(.init(id: next, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        retiredButton.performClick(nil)
        XCTAssertEqual(panel.feedbackToken, next)
        let correctionButton = try XCTUnwrap(panel.feedbackTargetWindows[1].contentView as? NSButton)
        correctionButton.performClick(nil)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertEqual(panel.activePresentationTaskCount, 0)
        XCTAssertEqual(panel.feedbackPhase, .hidden)
        XCTAssertTrue(panel.feedbackTargetWindows.isEmpty)
    }

    @MainActor
    func testFeedbackWindowServerRoutesMouseClickToCorrectionAndPassesBackgroundThrough() async throws {
        let suite = "ResenhaFeedbackMouseRouting.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let panel = FloatingPanelController(clock: { 100 })
        defer { panel.hide() }
        panel.configureFeedback(preferences: ProductPreferences(defaults: defaults))
        panel.show(.ready)
        let underneath = NSWindow(contentRect: panel.frame, styleMask: .borderless, backing: .buffered, defer: false)
        underneath.isReleasedWhenClosed = false
        underneath.backgroundColor = .white
        underneath.level = .floating
        underneath.orderFrontRegardless()
        defer { underneath.close() }
        let token = UUID()
        panel.offerFeedback(.init(id: token, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let targets = panel.feedbackTargetWindows
        targets.forEach { $0.displayIfNeeded() }
        // Let the WindowServer commit the pixels before asking which window receives a real mouse-down.
        try await Task.sleep(for: .milliseconds(100))
        for target in targets {
            let point = CGPoint(x: target.frame.midX, y: target.frame.midY)
            XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), target.windowNumber)
        }
        for point in [CGPoint(x: panel.frame.minX + 8, y: panel.frame.midY),
                      CGPoint(x: panel.frame.midX, y: panel.frame.midY)] {
            XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), underneath.windowNumber)
        }
        let correction = try XCTUnwrap(targets.last)
        let point = CGPoint(x: correction.frame.midX, y: correction.frame.midY)
        let receiver = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        guard receiver == correction.windowNumber else {
            XCTFail("WindowServer routing bypassed correction overlay")
            return
        }
        XCTAssertEqual(panel.feedbackToken, token)
        XCTAssertEqual(panel.dismissal.deadline, 104)
        let location = correction.convertPoint(fromScreen: point)
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: receiver, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: receiver, context: nil,
            eventNumber: 2, clickCount: 1, pressure: 0))
        NSApplication.shared.postEvent(up, atStart: true)
        NSApplication.shared.sendEvent(down)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertTrue(panel.correctionWindow?.isVisible == true)
        XCTAssertNil(panel.dismissal.deadline)
        XCTAssertTrue(panel.feedbackTargetWindows.isEmpty)
    }

    private final class FeedbackApplicationProbe: NSRunningApplication, @unchecked Sendable {
        var onDeinit: (() -> Void)?
        override var processIdentifier: pid_t { 0 }
        deinit { onDeinit?() }
    }

    @MainActor
    func testFeedbackReleasesApplicationContextAndRetiredTargetHandlersOnEveryTerminal() throws {
        let suite = "ResenhaFeedbackRetention.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for terminal in 0..<6 {
            let panel = FloatingPanelController(clock: { 100 })
            defer { panel.hide() }
            panel.configureFeedback(preferences: ProductPreferences(defaults: defaults))
            let token = UUID()
            var releases = 0
            autoreleasepool {
                let application = FeedbackApplicationProbe()
                application.onDeinit = { releases += 1 }
                panel.offerFeedback(.init(id: token, targetApplication: application, text: "Transcrição concluída.", language: .portuguese))
            }
            XCTAssertEqual(releases, 1, "The passive offer must retain only PID/token")
            let generation = panel.dismissal.generation
            let retiredTargets = panel.feedbackTargetWindows
            let retiredButton = try XCTUnwrap(retiredTargets.first?.contentView as? NSButton)
            switch terminal {
            case 0: panel.approveFeedback(token: token)
            case 1: panel.dismissIfCurrent(generation: generation, now: 104)
            case 2: panel.show(.listening)
            case 3: panel.show(.feedbackNotice("Termo adicionado ao vocabulário"))
            case 4: panel.hide() // HUD off and application termination share this terminal.
            default:
                panel.openCorrection(token: token)
                panel.cancelFeedback(token: token, restoreFocus: false)
            }
            XCTAssertFalse(panel.hasFeedback)
            XCTAssertEqual(panel.activePresentationTaskCount, 0)
            XCTAssertEqual(panel.feedbackPhase, .hidden)
            XCTAssertTrue(retiredTargets.allSatisfy { !$0.isVisible && $0.contentView == nil })
            retiredButton.performClick(nil)
            XCTAssertFalse(panel.hasFeedback)
        }
    }

    @MainActor
    func testFeedbackControllerDeallocatesWithActiveTaskAndExternallyRetainedTarget() throws {
        weak var releasedController: FloatingPanelController?
        var target: NSPanel?
        var button: NSButton?
        autoreleasepool {
            let controller = FloatingPanelController()
            releasedController = controller
            controller.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
            target = controller.feedbackTargetWindows.first
            button = target?.contentView as? NSButton
            XCTAssertEqual(controller.activePresentationTaskCount, 1)
        }
        XCTAssertNil(releasedController)
        XCTAssertFalse(try XCTUnwrap(target).isVisible)
        XCTAssertNil(target?.contentView)
        XCTAssertNil(target?.parent)
        button?.performClick(nil)
    }

    @MainActor
    func testFeedbackVisualPhaseAndRetiredTargetsCannotReachNewOfferOrEditor() throws {
        var now: TimeInterval = 100
        let panel = FloatingPanelController(clock: { now })
        defer { panel.hide() }
        let suite = "ResenhaFeedbackVisualGeneration.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        panel.configureFeedback(preferences: ProductPreferences(defaults: defaults))
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        let oldGeneration = panel.dismissal.generation
        let oldButton = try XCTUnwrap(panel.feedbackTargetWindows[1].contentView as? NSButton)
        now = 102
        let current = UUID()
        panel.offerFeedback(.init(id: current, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        panel.advanceFeedbackPresentation(generation: oldGeneration)
        oldButton.performClick(nil)
        XCTAssertEqual(panel.feedbackPhase, .entering)
        XCTAssertEqual(panel.feedbackToken, current)
        XCTAssertEqual(panel.dismissal.deadline, 106)
        let currentGeneration = panel.dismissal.generation
        panel.openCorrection(token: current)
        now = 106
        panel.advanceFeedbackPresentation(generation: currentGeneration)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertEqual(panel.feedbackPhase, .hidden)
        XCTAssertEqual(panel.activePresentationTaskCount, 0)
        XCTAssertTrue(panel.feedbackTargetWindows.isEmpty)
    }

    @MainActor
    func testCorrectionExplicitSavePreservesDraftOnValidationAndRollbackThenConsumesOnce() throws {
        let suite = "ResenhaFeedbackSave.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: preferences)
        let context = DictationCompletion(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese)
        panel.offerFeedback(context)
        panel.openCorrection(token: context.id)
        panel.saveCorrection(token: context.id)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertNotNil(panel.correctionError)
        XCTAssertEqual(defaults.glossaryWrites, 0)
        panel.updateCorrectionDraft(token: context.id, heard: "Coisa Energia", canonical: "COESA Energia")
        defaults.divergeAfterWrite = true
        panel.saveCorrection(token: context.id)
        XCTAssertEqual(panel.feedbackToken, context.id)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertTrue(panel.canSaveCorrection)
        XCTAssertEqual(panel.correctionDraft?.heard, "Coisa Energia")
        XCTAssertEqual(panel.correctionDraft?.canonical, "COESA Energia")
        XCTAssertTrue(panel.correctionError?.contains("restaurado") == true)
        defaults.divergeAfterWrite = false
        panel.saveCorrection(token: context.id)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertNil(panel.correctionDraft)
        XCTAssertTrue(panel.status.title.contains("Termo adicionado ao vocabulário"))
        let writes = defaults.glossaryWrites
        panel.saveCorrection(token: context.id)
        XCTAssertEqual(defaults.glossaryWrites, writes)
        let repeated = DictationCompletion(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese)
        panel.offerFeedback(repeated)
        panel.openCorrection(token: repeated.id)
        panel.updateCorrectionDraft(token: repeated.id, heard: "Coisa Energia", canonical: "COESA Energia")
        panel.saveCorrection(token: repeated.id)
        XCTAssertTrue(panel.status.title.contains("Termo já existente"))
        XCTAssertEqual(defaults.glossaryWrites, writes)
        panel.hide()
    }

    @MainActor
    func testRollbackRecoveryCancelReloadAndRetiredTokens() throws {
        let suite = "ResenhaFeedbackRecovery.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: preferences)
        let original = UUID()
        panel.offerFeedback(.init(id: original, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        panel.openCorrection(token: original)
        panel.updateCorrectionDraft(token: original, heard: "Coisa", canonical: "COESA")
        defaults.divergeAfterWrite = true
        defaults.rejectRestoration = true
        panel.saveCorrection(token: original)
        XCTAssertFalse(panel.canSaveCorrection)
        XCTAssertEqual(panel.feedbackToken, original)
        let writes = defaults.glossaryWrites
        let removals = defaults.glossaryRemovals
        panel.saveCorrection(token: original)
        panel.cancelFeedback(token: original, restoreFocus: false)
        XCTAssertFalse(panel.isEditingCorrection)
        XCTAssertNil(panel.feedbackToken)
        XCTAssertTrue(panel.hasFeedback)
        XCTAssertNil(panel.correctionDraft)
        XCTAssertNil(panel.approvalActionToken)
        let recovery = try XCTUnwrap(panel.correctionActionToken)
        defaults.unreadable = true
        panel.openCorrection(token: recovery)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertFalse(panel.canSaveCorrection)
        XCTAssertNil(panel.feedbackToken)
        panel.saveCorrection(token: original)
        panel.saveCorrection(token: recovery)
        panel.cancelFeedback(token: try XCTUnwrap(panel.correctionActionToken), restoreFocus: false)
        let retry = try XCTUnwrap(panel.correctionActionToken)
        XCTAssertNotEqual(retry, recovery)
        defaults.unreadable = false
        defaults.rejectRestoration = false
        panel.openCorrection(token: retry)
        let renewed = try XCTUnwrap(panel.feedbackToken)
        XCTAssertNotEqual(renewed, original)
        XCTAssertTrue(panel.canSaveCorrection)
        XCTAssertEqual(panel.correctionDraft?.canonical, "")
        XCTAssertEqual(panel.correctionDraft?.heard, "")
        panel.cancelFeedback(token: recovery)
        panel.saveCorrection(token: original)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertEqual(defaults.glossaryWrites, writes)
        XCTAssertEqual(defaults.glossaryRemovals, removals)
        panel.updateCorrectionDraft(token: renewed, heard: "Coisa", canonical: "COESA")
        panel.saveCorrection(token: renewed)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertTrue(panel.status.title.contains("Termo já existente"))
        XCTAssertEqual(defaults.glossaryWrites, writes)
        panel.hide()
    }

    @MainActor
    func testFeedbackHotkeySelfReleaseExternalAndAltTabUseRealRoutingSeam() throws {
        let app = AppDelegate()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: app.panel)
        app.observeCoordinator(coordinator)
        let original = UUID()
        app.panel.offerFeedback(.init(id: original, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        XCTAssertTrue(app.acceptHotkeyPress(targetIsSelf: false), "An ignored offer retires on the same accepted press")
        XCTAssertFalse(app.panel.hasFeedback)
        app.handleHotkeyRelease()
        let editing = UUID()
        app.panel.offerFeedback(.init(id: editing, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        app.panel.openCorrection(token: editing)
        app.panel.updateCorrectionDraft(token: editing, heard: "Coisa", canonical: "COESA")
        XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: true))
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertFalse(app.panel.hasFeedback)
        XCTAssertTrue(app.interaction.isPressed)
        XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: false))
        app.handleHotkeyRelease()
        XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: true), "Waiting for activation cannot dictate into Resenha")
        app.handleHotkeyRelease()
        XCTAssertTrue(app.acceptHotkeyPress(targetIsSelf: false))
        app.handleHotkeyRelease()
        let altTab = UUID()
        app.panel.offerFeedback(.init(id: altTab, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        app.panel.openCorrection(token: altTab)
        XCTAssertTrue(app.acceptHotkeyPress(targetIsSelf: false), "Alt-Tab permits immediate external dictation")
        XCTAssertFalse(app.panel.hasFeedback)
        XCTAssertFalse(app.panel.isEditingCorrection)
        app.handleHotkeyRelease()
        app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    }

    @MainActor
    func testFeedbackMenuOldActionsAndRoutineStatusCannotChangeCurrentEditor() throws {
        let app = AppDelegate()
        app.observeCoordinator(DictationCoordinator(permissions: PermissionService(), panel: app.panel))
        let menu = NativeMenuController(delegate: app)
        menu.configure()
        let original = UUID()
        app.panel.offerFeedback(.init(id: original, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        menu.updateFeedback(approvalToken: app.panel.approvalActionToken, correctionToken: app.panel.correctionActionToken)
        let oldApprove = try XCTUnwrap(menu.approvalMenuItem)
        let oldCorrect = try XCTUnwrap(menu.correctionMenuItem)
        XCTAssertTrue(oldApprove.isEnabled)
        let current = UUID()
        app.panel.offerFeedback(.init(id: current, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        menu.updateFeedback(approvalToken: app.panel.approvalActionToken, correctionToken: app.panel.correctionActionToken)
        XCTAssertFalse(oldApprove === menu.approvalMenuItem)
        app.approveTranscription(oldApprove)
        app.correctTranscription(oldCorrect)
        XCTAssertEqual(app.panel.feedbackToken, current)
        XCTAssertFalse(app.panel.isEditingCorrection)
        app.correctTranscription(try XCTUnwrap(menu.correctionMenuItem))
        XCTAssertTrue(app.panel.isEditingCorrection)
        app.showRoutineStatus(.ready)
        app.showRoutineStatus(.failure("Atalho global indisponível"))
        XCTAssertTrue(app.applyPermissionSnapshot(.init(microphone: true, inputMonitoring: true)))
        XCTAssertTrue(app.panel.isEditingCorrection)
        XCTAssertEqual(app.panel.feedbackToken, current)
        XCTAssertFalse(app.applyPermissionSnapshot(.init(microphone: false, inputMonitoring: true)))
        XCTAssertFalse(app.panel.hasFeedback)
        XCTAssertNil(app.panel.correctionDraft)
        app.panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
        app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        XCTAssertFalse(app.panel.hasFeedback)
        XCTAssertNil(app.panel.correctionDraft)
        app.correctTranscription(oldCorrect)
        XCTAssertFalse(app.panel.isEditingCorrection)
    }

    @MainActor
    func testRecoveryDraftIsErasedOnNewDictationHUDOffAndTermination() throws {
        for event in 0..<3 {
            let suite = "ResenhaRecoveryDiscard.\(UUID())"
            let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = ProductPreferences(defaults: defaults)
            let app = AppDelegate()
            app.observeCoordinator(DictationCoordinator(permissions: PermissionService(), panel: app.panel))
            app.panel.configureFeedback(preferences: preferences)
            let token = UUID()
            app.panel.offerFeedback(.init(id: token, targetApplication: nil, text: "Transcrição concluída.", language: .portuguese))
            app.panel.openCorrection(token: token)
            app.panel.updateCorrectionDraft(token: token, heard: "Coisa", canonical: "COESA")
            defaults.divergeAfterWrite = true
            defaults.rejectRestoration = true
            app.panel.saveCorrection(token: token)
            if event == 0 {
                XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: true))
                XCTAssertFalse(app.panel.isEditingCorrection)
                XCTAssertNil(app.panel.correctionDraft)
                XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: false))
                app.handleHotkeyRelease()
            } else {
                app.panel.cancelFeedback(token: token, restoreFocus: false)
            }
            let recovery = try XCTUnwrap(app.panel.correctionActionToken)
            let writes = defaults.glossaryWrites
            switch event {
            case 0: XCTAssertTrue(app.acceptHotkeyPress(targetIsSelf: false))
            case 1: app.preferences.onHUDChange?(false)
            default: app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            XCTAssertFalse(app.panel.hasFeedback)
            XCTAssertNil(app.panel.correctionDraft)
            app.panel.openCorrection(token: recovery)
            app.panel.saveCorrection(token: token)
            XCTAssertFalse(app.panel.isEditingCorrection)
            XCTAssertEqual(defaults.glossaryWrites, writes)
            app.panel.hide()
        }
    }

    func testSafeErrorPresentationDoesNotExposeSubprocessOrUnknownErrorText() {
        let failure = DictationErrorPresentation(error: WhisperError.failed(7, "PRIVATE TRANSCRIPT"))
        XCTAssertEqual(failure.diagnostic, "Código de saída: 7")
        XCTAssertFalse(String(describing: failure).contains("PRIVATE TRANSCRIPT"))
        let unknown = DictationErrorPresentation(error: NSError(domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "PRIVATE TRANSCRIPT"]))
        XCTAssertEqual(unknown.title, "Falha no ditado")
        XCTAssertNil(unknown.diagnostic)
        let missing = DictationErrorPresentation(error: WhisperError.modelMissing("/safe/model.bin"))
        XCTAssertEqual(missing.diagnostic, "/safe/model.bin")
    }

    func testInteractionGuardAndStatusFeedbackRespectActivity() {
        var interaction = DictationInteraction()
        XCTAssertTrue(interaction.canStart(phase: .idle, targetIsSelf: false))
        XCTAssertFalse(interaction.canStart(phase: .idle, targetIsSelf: true))
        interaction.openMenuCount = 1
        XCTAssertFalse(interaction.canStart(phase: .idle, targetIsSelf: false))
        interaction.openMenuCount = 0
        interaction.isRequestingPermission = true
        XCTAssertFalse(interaction.canStart(phase: .idle, targetIsSelf: false))
        interaction.isRequestingPermission = false
        for phase in [DictationPhase.recording, .transcribing, .inserting, .failed] {
            XCTAssertFalse(phase.acceptsStatusFeedback)
            XCTAssertFalse(interaction.canStart(phase: phase, targetIsSelf: false))
        }
        XCTAssertTrue(DictationPhase.idle.acceptsStatusFeedback)
    }

    func testHUDStateMappingIncludesInstructionsAndOperationMeaning() {
        XCTAssertEqual(FloatingStatus.ready.title, "Pronto")
        XCTAssertEqual(FloatingStatus.ready.secondary, "Segure seu atalho para ditar")
        XCTAssertEqual(FloatingStatus.ready.symbol, "waveform")
        XCTAssertEqual(FloatingStatus.listening.secondary, "Solte o atalho para concluir")
        XCTAssertEqual(FloatingStatus.listening.symbol, "mic.fill")
        for state in [FloatingStatus.transcribing, .inserting] {
            XCTAssertTrue(state.isBusy)
            XCTAssertNil(state.symbol)
            XCTAssertNil(state.secondary)
            XCTAssertEqual(state.accessibilityLabel, state.title)
        }
        let failure = FloatingStatus.failure("Microfone indisponível")
        XCTAssertEqual(failure.symbol, "exclamationmark.triangle.fill")
        XCTAssertEqual(failure.secondary, "Abra o menu do Resenha para obter ajuda")
        XCTAssertTrue(failure.accessibilityLabel.contains("Microfone indisponível"))
        XCTAssertFalse(failure.isBusy)
        XCTAssertEqual(FloatingStatus.feedback.title, "Avaliar transcrição")
        XCTAssertNil(FloatingStatus.feedback.secondary)
        XCTAssertFalse(FloatingStatus.feedback.isBusy)
        for message in ["Termo adicionado ao vocabulário", "Termo já existente", "Solte e pressione novamente para ditar"] {
            let notice = FloatingStatus.feedbackNotice(message)
            XCTAssertEqual(notice.title, message)
            XCTAssertEqual(notice.accessibilityLabel, message)
            XCTAssertEqual(notice.symbol, "info.circle")
            XCTAssertFalse(notice.isFailure)
        }
    }

    @MainActor
    func testLocalPreviewModelBoundsUnicodeRejectsStaleSessionsAndClearsExplicitly() {
        let model = FloatingPanelModel()
        let attempt = UUID()
        let otherAttempt = UUID()
        model.show(.listening, now: 0)
        let longUnicode = String(repeating: "🧑🏽‍💻", count: 300)

        XCTAssertTrue(model.showPreview(previewRevision(attemptID: attempt, revision: 1, text: longUnicode)))
        XCTAssertEqual(model.preview?.text.count, FloatingPreview.maximumCharacters)
        XCTAssertTrue(model.preview?.text.hasSuffix("…") == true)
        XCTAssertEqual(model.preview?.phase, .provisional)
        XCTAssertFalse(model.showPreview(previewRevision(attemptID: attempt, revision: 1, text: "stale")))
        XCTAssertFalse(model.showPreview(previewRevision(attemptID: otherAttempt, revision: 2, text: "other")))
        XCTAssertTrue(model.showPreview(previewRevision(attemptID: attempt, revision: 2, text: "Olá, COESA 👋🏽")))
        XCTAssertFalse(model.applyContextualPreview(attemptID: otherAttempt, revision: 2, text: "ignorado"))
        XCTAssertFalse(model.applyContextualPreview(attemptID: attempt, revision: 1, text: "atrasado"))
        XCTAssertTrue(model.applyContextualPreview(attemptID: attempt, revision: 2, text: "Olá, COESA Energia 👋🏽"))
        XCTAssertEqual(model.preview?.text, "Olá, COESA Energia 👋🏽")

        model.show(.transcribing, now: 1)
        XCTAssertEqual(model.preview?.phase, .finalizing)
        XCTAssertTrue(model.preview?.accessibilityLabel.contains("FINALIZANDO") == true)
        model.clearPreview(attemptID: otherAttempt)
        XCTAssertNotNil(model.preview)
        model.clearPreview(attemptID: attempt)
        XCTAssertNil(model.preview)

        model.show(.listening, now: 2)
        model.showLocalFallback(attemptID: attempt)
        XCTAssertEqual(model.preview?.phase, .localFallback)
        XCTAssertEqual(model.preview?.text, FloatingPreview.fallbackText)
        XCTAssertNotEqual(FloatingPreviewPhase.provisional.symbol, FloatingPreviewPhase.localFallback.symbol)
    }

    @MainActor
    func testLocalPreviewPanelCoalescesRapidRevisionsPreservesFocusContractAndCleansUp() async throws {
        var now: TimeInterval = 10
        let panel = FloatingPanelController(clock: { now }, previewCoalescingInterval: 0.08)
        let attempt = UUID()
        panel.show(.listening, target: .standalone(nil))
        XCTAssertTrue(panel.ignoresMouseEvents)

        panel.updateContinuousPreview(previewRevision(attemptID: attempt, revision: 1, text: "um"))
        panel.updateContinuousPreview(previewRevision(attemptID: attempt, revision: 2, text: "um teste"))
        panel.updateContinuousPreview(previewRevision(attemptID: attempt, revision: 3, text: "um teste local"))
        XCTAssertEqual(panel.preview?.revision, 1)
        now += 0.08
        for _ in 0..<50 where panel.preview?.revision != 3 {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(panel.preview?.revision, 3)
        XCTAssertEqual(panel.preview?.text, "um teste local")

        panel.show(.transcribing, target: .standalone(nil))
        XCTAssertEqual(panel.preview?.phase, .finalizing)
        panel.hide()
        XCTAssertNil(panel.preview)
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor
    func testLocalPreviewViewFitsSmallScreenContrastAndReducedMotion() {
        let model = FloatingPanelModel()
        let attempt = UUID()
        model.show(.listening, now: 0)
        XCTAssertTrue(model.showPreview(previewRevision(
            attemptID: attempt,
            revision: 1,
            text: "Uma frase longa com acentos, emoji 👩🏾‍💻 e nome COESA Energia"
        )))
        let smallScreen = CGSize(width: 320, height: 180)
        let size = FloatingStatusView.panelSize(for: .listening, available: smallScreen, hasPreview: true)
        XCTAssertLessThanOrEqual(size.width, smallScreen.width - 24)
        XCTAssertLessThanOrEqual(size.height, smallScreen.height - 24)
        let view = FloatingStatusView(
            model: model,
            fixtureContrast: .increased,
            fixtureReduceTransparency: true,
            fixtureReduceMotion: true
        )
        XCTAssertEqual(view.fixtureContrast, .increased)
        XCTAssertEqual(view.fixtureReduceTransparency, true)
        XCTAssertEqual(view.fixtureReduceMotion, true)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.frame.size, size)
        XCTAssertTrue(model.preview?.accessibilityLabel.contains("PRÉVIA LOCAL") == true)
    }

    @MainActor
    func testContinuousContextShippingLabelsAndRemoteAuthorityAvailableSmoke() {
        XCTAssertEqual(FloatingPreviewPhase.provisional.title, "PRÉVIA LOCAL")
        XCTAssertEqual(FloatingPreviewPhase.finalizing.title, "FINALIZANDO")
        XCTAssertEqual(FloatingPreviewPhase.localFallback.title, "MODO LOCAL")
        XCTAssertEqual(FloatingPreview.fallbackText, "O ditado continua sem prévia ao vivo.")
        XCTAssertEqual(PersonalRemoteReleaseDecision.current, .personalRemoteAvailable)
    }

    @MainActor
    func testFeedbackUsesProcessingDimensionsAndEditorClampsSmallScreens() {
        XCTAssertEqual(FloatingStatusView.panelSize(for: .feedback, available: CGSize(width: 1440, height: 900)),
            CGSize(width: 280, height: 64))
        for state in [FloatingStatus.transcribing, .inserting] {
            XCTAssertEqual(FloatingStatusView.panelSize(for: state, available: CGSize(width: 1440, height: 900)),
                FloatingStatusView.panelSize(for: .feedback, available: CGSize(width: 1440, height: 900)))
        }
        XCTAssertEqual(TranscriptionCorrectionView.panelSize(available: CGSize(width: 1440, height: 900)),
            CGSize(width: 440, height: 360))
        let smallScreen = CGSize(width: 320, height: 320)
        XCTAssertEqual(FloatingStatusView.panelSize(for: .feedback, available: smallScreen), CGSize(width: 280, height: 64))
        XCTAssertEqual(TranscriptionCorrectionView.panelSize(available: smallScreen), CGSize(width: 296, height: 296))
        XCTAssertEqual(FloatingStatusView.panelSize(for: .feedbackNotice("Termo adicionado ao vocabulário"), available: smallScreen),
            CGSize(width: 280, height: 64))
    }

    @MainActor
    func testFeedbackViewActionLabelsAndEditorBindingsContract() {
        var approved = 0
        var corrected = 0
        let model = FloatingPanelModel()
        model.show(.feedback, now: 0)
        let view = FloatingStatusView(model: model,
            onApprove: { approved += 1 }, onCorrect: { corrected += 1 })
        XCTAssertEqual(FloatingStatusView.approveLabel, "Transcrição correta")
        XCTAssertEqual(FloatingStatusView.correctLabel, "Corrigir transcrição")
        XCTAssertEqual(view.feedbackActions.map(\.label), ["Transcrição correta", "Corrigir transcrição"])
        XCTAssertEqual(view.feedbackActions.map(\.symbol), ["hand.thumbsup", "hand.thumbsdown"])
        view.feedbackActions[0].perform()
        XCTAssertEqual(approved, 1)
        XCTAssertEqual(corrected, 0)
        view.feedbackActions[1].perform()
        XCTAssertEqual(approved, 1)
        XCTAssertEqual(corrected, 1)

        var heard = ""
        var canonical = ""
        var saved = 0
        var cancelled = 0
        var editor = TranscriptionCorrectionView(heard: Binding(get: { heard }, set: { heard = $0 }),
            canonical: Binding(get: { canonical }, set: { canonical = $0 }),
            errorMessage: "Confira o termo informado.", invalidField: .heard, isSaveEnabled: true,
            onSave: { saved += 1 }, onCancel: { cancelled += 1 })
        XCTAssertEqual(editor.heard, "")
        XCTAssertEqual(editor.canonical, "")
        editor.heard = "Coisa Energia"
        editor.canonical = "COESA Energia"
        XCTAssertEqual(TranscriptionCorrectionView.Field.heard.label, "Saiu como")
        XCTAssertEqual(TranscriptionCorrectionView.Field.canonical.label, "Correto é")
        XCTAssertEqual(TranscriptionCorrectionView.saveLabel, "Salvar")
        XCTAssertEqual(TranscriptionCorrectionView.cancelLabel, "Cancelar")
        XCTAssertEqual(editor.errorMessage, "Confira o termo informado.")
        XCTAssertEqual(editor.invalidField, .heard)
        XCTAssertTrue(editor.isSaveEnabled)
        XCTAssertEqual(editor.actions.map(\.label), ["Salvar", "Cancelar"])
        editor.actions[0].perform()
        XCTAssertEqual(saved, 1)
        XCTAssertEqual(cancelled, 0)
        editor.isSaveEnabled = false
        XCTAssertFalse(editor.actions[0].isEnabled)
        editor.actions[0].perform()
        XCTAssertTrue(editor.actions[1].isEnabled)
        editor.actions[1].perform()
        XCTAssertEqual(saved, 1)
        XCTAssertEqual(cancelled, 1)
        XCTAssertEqual(heard, "Coisa Energia")
        XCTAssertEqual(canonical, "COESA Energia")
    }

    func testFeedbackBubbleMotionStaysBoundedAndReduceMotionRemovesTravel() {
        XCTAssertEqual(FeedbackBubbleMotion.targetSize, 44)
        XCTAssertEqual(FeedbackBubbleMotion.visualSize, 32)
        XCTAssertEqual(FeedbackBubbleMotion.duration, 4)

        let firstEntry = FeedbackBubbleMotion.state(elapsed: 0.1, index: 0, reduceMotion: false)
        let secondEntry = FeedbackBubbleMotion.state(elapsed: 0.1, index: 1, reduceMotion: false)
        XCTAssertEqual(firstEntry, secondEntry) // No stagger or independent animation clock.

        let settled = FeedbackBubbleMotion.state(elapsed: 1, index: 1, reduceMotion: false)
        XCTAssertEqual(settled.opacity, 1)
        XCTAssertEqual(settled.offset, 8 - 12 / 3.25, accuracy: 0.001)
        XCTAssertEqual(settled.bubbleScale, 1)
        let fadeStart = FeedbackBubbleMotion.state(elapsed: 3.25, index: 0, reduceMotion: false)
        XCTAssertEqual(fadeStart.opacity, 1)
        XCTAssertEqual(fadeStart.offset, -4)
        let exiting = FeedbackBubbleMotion.state(elapsed: 4, index: 0, reduceMotion: false)
        XCTAssertEqual(exiting.opacity, 0)
        XCTAssertEqual(exiting.offset, -12)
        XCTAssertEqual(exiting.bubbleScale, 1)
        XCTAssertEqual(FeedbackBubbleMotion.state(elapsed: 0, index: 0, reduceMotion: false).offset - exiting.offset, 20)
        XCTAssertEqual(FeedbackBubblePhase.hidden.elapsed, 4)
        XCTAssertEqual(FeedbackBubblePhase.entering.elapsed, 0)
        XCTAssertEqual(FeedbackBubblePhase.resting.elapsed, 3.25)
        XCTAssertEqual(FeedbackBubblePhase.exiting.elapsed, 4)
        XCTAssertLessThanOrEqual(FeedbackBubbleMotion.visualSize, FeedbackBubbleMotion.targetSize)

        for time in [TimeInterval.nan, -1, 0, 0.5, 3.5, 4, 8] {
            let animated = FeedbackBubbleMotion.state(elapsed: time, index: 0, reduceMotion: false)
            XCTAssertTrue(animated.opacity.isFinite)
            XCTAssertTrue(animated.offset.isFinite)
            XCTAssertTrue(animated.bubbleScale.isFinite)
            XCTAssertTrue((0...1).contains(animated.opacity))
            XCTAssertTrue((-12...8).contains(animated.offset))
            XCTAssertEqual(animated.bubbleScale, 1)

            let reduced = FeedbackBubbleMotion.state(elapsed: time, index: 1, reduceMotion: true)
            XCTAssertEqual(reduced.offset, 0)
            XCTAssertEqual(reduced.bubbleScale, 1)
            XCTAssertEqual(reduced.opacity, animated.opacity)
        }
    }

    @MainActor
    func testFeedbackGlyphOnlyFixturesHaveNoCardBorderOrBubbleBackground() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ResenhaTests/feedback-glyphs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appearances: [(String, ColorScheme, Bool, Bool)] = [
            ("light", .light, false, false), ("dark", .dark, false, false),
            ("contrast", .light, true, false), ("opaque", .dark, true, false),
            ("reduced-motion", .light, false, true)
        ]
        for (name, scheme, contrast, reduceMotion) in appearances {
            for elapsed in [0.0, 2.0, 4.0] {
                let model = FloatingPanelModel()
                model.show(.feedback, now: 100)
                let view = FloatingStatusView(model: model, fixtureContrast: contrast ? .increased : .standard,
                    fixtureReduceTransparency: name == "opaque", fixtureReduceMotion: reduceMotion,
                    fixtureFeedbackElapsed: elapsed).environment(\.colorScheme, scheme).frame(width: 280, height: 64)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
                var paintedPixels = 0
                var outsideGlyphPixels = 0
                let offset = FeedbackBubbleMotion.state(elapsed: elapsed, index: 0, reduceMotion: reduceMotion).offset
                // Glyph + minimal shadow only; the 44pt bounds exclude a title, card and border.
                let glyphBounds = [110.0, 170.0].map {
                    CGRect(x: $0 - 22, y: 32 + offset - 22, width: 44, height: 44)
                }
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 else { continue }
                        paintedPixels += 1
                        let point = CGPoint(x: Double(x) / 2, y: Double(y) / 2)
                        if !glyphBounds.contains(where: { $0.contains(point) }) { outsideGlyphPixels += 1 }
                    }
                }
                XCTAssertEqual(outsideGlyphPixels, 0, "\(name) elapsed=\(elapsed): no paint outside glyphs")
                if elapsed == 4 { XCTAssertEqual(paintedPixels, 0) }
                else { XCTAssertGreaterThan(paintedPixels, 100) }
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("feedback-\(name)-\(Int(elapsed)).png"))
            }
        }
        print("Feedback glyph fixtures: \(directory.path)")
    }

    func testScreenChoiceUsesIntersectionThenCenterAndDeterministicTie() {
        let left = PanelScreen(id: 1, frame: CGRect(x: -1000, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 24, width: 1000, height: 776))
        let right = PanelScreen(id: 2, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1000, height: 776))
        XCTAssertEqual(PanelPlacement.screen(for: CGRect(x: -800, y: 50, width: 900, height: 600), screens: [right, left], fallbackID: 2)?.id, 1)
        XCTAssertEqual(PanelPlacement.screen(for: CGRect(x: -300, y: 50, width: 600, height: 600), screens: [left, right], fallbackID: 1)?.id, 2)
        let overlap = PanelScreen(id: 3, frame: right.frame, visibleFrame: right.visibleFrame)
        XCTAssertEqual(PanelPlacement.screen(for: CGRect(x: 50, y: 50, width: 600, height: 600), screens: [right, overlap], fallbackID: 3)?.id, 2)
        XCTAssertEqual(PanelPlacement.screen(for: nil, screens: [left, right], fallbackID: 2)?.id, 2)
        XCTAssertNil(PanelPlacement.screen(for: nil, screens: [], fallbackID: nil))
    }

    func testPanelClampsAllEdgesWithNegativeAndSmallVisibleFrames() {
        for visible in [CGRect(x: -1440, y: -900, width: 1440, height: 850), CGRect(x: -80, y: 20, width: 150, height: 90)] {
            for size in [CGSize(width: 280, height: 64), CGSize(width: 360, height: 104)] {
                let frame = PanelPlacement.panelFrame(size: size, visibleFrame: visible)
                let inset = visible.insetBy(dx: 12, dy: 12)
                XCTAssertTrue(inset.contains(frame))
                XCTAssertEqual(frame.midX, visible.midX)
                XCTAssertLessThanOrEqual(frame.width, size.width)
                XCTAssertLessThanOrEqual(frame.height, size.height)
            }
        }
        let visible = CGRect(x: 0, y: 40, width: 1000, height: 700)
        XCTAssertEqual(PanelPlacement.panelFrame(size: CGSize(width: 280, height: 64), visibleFrame: visible).minY, 128)
    }

    func testSessionRetainsDisplayAndUsesFreshFramesAfterDisconnect() {
        let left = PanelScreen(id: 1, frame: CGRect(x: -1000, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 24, width: 1000, height: 776))
        let right = PanelScreen(id: 2, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1000, height: 776))
        var selection = PanelScreenSelection()
        selection.beginSession(pid: 42, window: CGRect(x: -900, y: 100, width: 600, height: 500), screens: [left, right], mainID: 2)
        XCTAssertEqual(selection.sessionScreen(screens: [left, right], mainID: 2)?.id, 1)
        selection.rememberExternalTarget(99)
        XCTAssertEqual(selection.sessionScreen(screens: [left, right], mainID: 2)?.id, 1)
        let fresh = PanelScreen(id: 1, frame: left.frame, visibleFrame: CGRect(x: -900, y: 80, width: 900, height: 700))
        XCTAssertEqual(selection.sessionScreen(screens: [fresh, right], mainID: 2)?.visibleFrame, fresh.visibleFrame)
        XCTAssertEqual(selection.sessionScreen(screens: [right], mainID: 2)?.id, 2)
        XCTAssertEqual(selection.sessionDisplay, 2)
        selection.endSession()
        XCTAssertFalse(selection.hasSession)
    }

    func testStandaloneMissingWindowUsesExternalTargetFallbacks() {
        let primary = PanelScreen(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1000, height: 776))
        let secondary = PanelScreen(id: 2, frame: CGRect(x: -1000, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 24, width: 1000, height: 776))
        var selection = PanelScreenSelection()
        selection.rememberExternalTarget(42)
        XCTAssertEqual(selection.standaloneTarget(explicit: nil, frontmost: 7, ownPID: 7), 42)
        XCTAssertEqual(selection.standaloneTarget(explicit: nil, frontmost: 99, ownPID: 7), 99)
        XCTAssertEqual(selection.standaloneTarget(explicit: 42, frontmost: 99, ownPID: 7), 42)
        XCTAssertEqual(selection.resolve(pid: 42, window: secondary.frame, screens: [primary, secondary], mainID: 1)?.id, 2)
        // The sandboxed Service build does not inspect another app's focused window.
        XCTAssertEqual(selection.resolve(pid: 42, window: nil, screens: [primary, secondary], mainID: 1)?.id, 2)
        XCTAssertEqual(selection.resolve(pid: 99, window: nil, screens: [primary, secondary], mainID: 1)?.id, 1)
        XCTAssertEqual(selection.resolve(pid: 42, window: nil, screens: [primary], mainID: 1)?.id, 1)
        XCTAssertEqual(selection.resolve(pid: nil, window: nil, screens: [secondary], mainID: nil)?.id, 2)
    }

    @MainActor
    func testFailureLayoutReplacementRestoresOrdinaryFootprintAndDoesNotStealFocus() {
        let panel = FloatingPanelController()
        let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        panel.showTemporarily(.failure("Permissão de Monitoramento de Entrada necessária para receber o atalho de ditado"))
        let obsolete = panel.dismissal.generation
        XCTAssertLessThanOrEqual(panel.frame.width, 360)
        XCTAssertLessThanOrEqual(panel.frame.height, 104)
        panel.show(.listening, target: .session(42))
        XCTAssertEqual(panel.frame.size, CGSize(width: 340, height: 72))
        panel.dismissIfCurrent(generation: obsolete, now: .greatestFiniteMagnitude)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, activePID)
        panel.hide()
    }

    func testKnownErrorsMapToSafeCauseAndAllowedDiagnostics() {
        let cases: [(Error, String)] = [
            (AudioRecorderError.failedToStart, "Microfone indisponível"),
            (WhisperError.modelMissing("/safe/model.bin"), "Modelo Whisper não encontrado"),
            (WhisperError.modelLoadFailed("/safe/model.bin"), "Falha ao abrir o modelo Whisper"),
            (WhisperError.timedOut, "Transcrição demorou demais"),
            (WhisperError.emptyTranscript, "Nenhuma fala detectada"),
            (TextInjectionError.clipboardUnavailable, "Falha ao guardar o texto")
        ]
        for (error, title) in cases {
            let presentation = DictationErrorPresentation(error: error)
            XCTAssertEqual(presentation.title, title)
            XCTAssertFalse(presentation.recovery.isEmpty)
        }
        let subprocess = DictationErrorPresentation(error: WhisperError.failed(9, "PRIVATE RAW STDERR"))
        XCTAssertEqual(subprocess.diagnostic, "Código de saída: 9")
        XCTAssertFalse(String(describing: subprocess).contains("PRIVATE RAW STDERR"))
    }

    private final class WhisperExecutionProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String] = []
        private var uptime: TimeInterval = 100
        private var activeInferenceCount = 0
        private var peakInferenceCount = 0
        func record(_ event: String) -> Int {
            lock.withLock { entries.append(event); return entries.filter { $0 == event }.count }
        }
        var events: [String] { lock.withLock { entries } }
        var now: TimeInterval { lock.withLock { uptime } }
        func advance(to value: TimeInterval) { lock.withLock { uptime = value } }
        func beginInference() -> Int {
            lock.withLock {
                activeInferenceCount += 1
                peakInferenceCount = max(peakInferenceCount, activeInferenceCount)
                entries.append("infer")
                return entries.filter { $0 == "infer" }.count
            }
        }
        func endInference() { lock.withLock { activeInferenceCount -= 1 } }
        var peakInferences: Int { lock.withLock { peakInferenceCount } }
    }

    private final class WhisperPromptProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var currentTerms: [String] = []
        private var capturedPrompts: [String] = []
        private var hypothesisCount = 0
        var terms: [String] { lock.withLock { currentTerms } }
        var prompts: [String] { lock.withLock { capturedPrompts } }
        func setTerms(_ terms: [String]) { lock.withLock { currentTerms = terms } }
        func record(prompt: String) -> Int {
            lock.withLock {
                capturedPrompts.append(prompt)
                return capturedPrompts.count
            }
        }
        func nextHypothesis() -> Int {
            lock.withLock { hypothesisCount += 1; return hypothesisCount }
        }
    }

    private final class FakeAudioRecordingBackend: AudioRecordingBackend {
        var isMeteringEnabled = false
        private(set) var isRecording = false
        private(set) var stopCount = 0
        func prepareToRecord() -> Bool { true }
        func record() -> Bool { isRecording = true; return true }
        func stop() { stopCount += 1; isRecording = false }
        func updateMeters() {}
        func averagePower(forChannel channelNumber: Int) -> Float { -30 }
    }

    private final class FakeRollingAudioCapture: RollingAudioCapture, @unchecked Sendable {
        private let onSnapshot: @Sendable (AudioSampleSnapshot) -> Void
        private let onInterruption: @Sendable () -> Void
        private(set) var startCount = 0
        private(set) var stopCount = 0

        init(
            onSnapshot: @escaping @Sendable (AudioSampleSnapshot) -> Void,
            onInterruption: @escaping @Sendable () -> Void = {}
        ) {
            self.onSnapshot = onSnapshot
            self.onInterruption = onInterruption
        }

        func start() throws { startCount += 1 }
        func stop() { stopCount += 1 }
        func emit(_ snapshot: AudioSampleSnapshot) { onSnapshot(snapshot) }
        func interrupt() { onInterruption() }
    }

    private func temporaryWhisperRecording() throws -> (directory: URL, audio: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixture = try XCTUnwrap(Bundle(for: WhisperKeyTests.self).url(forResource: "jfk", withExtension: "wav"))
        let audio = directory.appendingPathComponent("recording.wav")
        try FileManager.default.copyItem(at: fixture, to: audio)
        return (directory, audio)
    }

    func testRollingAudioAccumulatorKeepsOwnedBoundedSamplesAndMonotonicRanges() throws {
        let accumulator = BoundedAudioSampleAccumulator(configuration: .init(
            maximumRetainedSamples: 5,
            snapshotStrideSamples: 2
        ))
        let source = [Float](repeating: 1, count: 4)
        XCTAssertNil(accumulator.append([source[0]], capturedAt: 10))
        let first = try XCTUnwrap(accumulator.append(Array(source[1...2]), capturedAt: 11))
        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(first.samples, [1, 1, 1])
        XCTAssertEqual(first.sampleRange, 0..<3)
        XCTAssertEqual(first.capturedAt, 11)
        XCTAssertEqual(first.enqueuedAt, 11)

        for value in 2...10_000 {
            _ = accumulator.append([Float(value)], capturedAt: TimeInterval(value))
            XCTAssertLessThanOrEqual(accumulator.retainedSampleCount, 5)
        }
        let final = try XCTUnwrap(accumulator.append([10_001, 10_002], capturedAt: 10_002))
        XCTAssertEqual(final.samples, [9_998, 9_999, 10_000, 10_001, 10_002])
        XCTAssertEqual(final.sampleRange.count, final.samples.count)
        XCTAssertEqual(final.sampleRange.upperBound, 10_004)

        accumulator.reset()
        XCTAssertEqual(accumulator.retainedSampleCount, 0)
        let reset = try XCTUnwrap(accumulator.append([7, 8], capturedAt: 30))
        XCTAssertEqual(reset.id, 1)
        XCTAssertEqual(reset.sampleRange, 0..<2)
    }

    func testAudioCaptureTimestampUsesTapHostTimeForFinalFrameAndKeepsPublicationSeparate() throws {
        let startSeconds = 1_000.0
        let start = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: startSeconds))
        let capturedAt = AudioCaptureTimestamp.finalFrame(
            startingAt: start,
            frameCount: 800,
            sampleRate: 16_000,
            fallback: 9_999
        )
        XCTAssertEqual(capturedAt, startSeconds + 799.0 / 16_000.0, accuracy: 0.000_001)

        let accumulator = BoundedAudioSampleAccumulator(configuration: .init(
            maximumRetainedSamples: 800,
            snapshotStrideSamples: 800
        ))
        let snapshot = try XCTUnwrap(accumulator.append(
            [Float](repeating: 0, count: 800),
            capturedAt: capturedAt,
            enqueuedAt: capturedAt + 0.2
        ))
        XCTAssertEqual(snapshot.capturedAt, capturedAt)
        XCTAssertEqual(snapshot.enqueuedAt, capturedAt + 0.2)
    }

    @MainActor
    func testAudioRecorderRollingLifecycleStopsOnceAndRejectsLateCallbacks() async throws {
        let firstBackend = FakeAudioRecordingBackend()
        var firstCapture: FakeRollingAudioCapture?
        let recorder = AudioRecorder(
            recorderFactory: { url, _ in
                FileManager.default.createFile(atPath: url.path, contents: Data())
                return firstBackend
            },
            rollingCaptureFactory: { _, callback, interruption in
                let capture = FakeRollingAudioCapture(
                    onSnapshot: callback,
                    onInterruption: interruption
                )
                firstCapture = capture
                return capture
            }
        )
        let unexpected = expectation(description: "No snapshots after terminal stop")
        unexpected.isInverted = true
        try recorder.start(
            rolling: .init(maximumRetainedSamples: 100, snapshotStrideSamples: 10),
            onSnapshot: { _ in unexpected.fulfill() }
        )
        XCTAssertThrowsError(try recorder.start()) { error in
            guard case AudioRecorderError.alreadyRecording = error else {
                return XCTFail("Expected alreadyRecording, got \(error)")
            }
        }
        XCTAssertEqual(firstCapture?.startCount, 1)
        let output = try recorder.stop()
        defer { try? FileManager.default.removeItem(at: output) }
        XCTAssertEqual(firstBackend.stopCount, 1)
        XCTAssertEqual(firstCapture?.stopCount, 1)
        firstCapture?.emit(.init(id: 1, samples: [1], sampleRange: 0..<1, capturedAt: 1))
        await fulfillment(of: [unexpected], timeout: 0.15)

        let secondBackend = FakeAudioRecordingBackend()
        var secondCapture: FakeRollingAudioCapture?
        var cancelledURL: URL?
        let unexpectedAfterCancel = expectation(description: "No snapshots after cancellation")
        unexpectedAfterCancel.isInverted = true
        let cancelledRecorder = AudioRecorder(
            recorderFactory: { url, _ in
                cancelledURL = url
                FileManager.default.createFile(atPath: url.path, contents: Data())
                return secondBackend
            },
            rollingCaptureFactory: { _, callback, interruption in
                let capture = FakeRollingAudioCapture(
                    onSnapshot: callback,
                    onInterruption: interruption
                )
                secondCapture = capture
                return capture
            }
        )
        try cancelledRecorder.start(
            rolling: .init(maximumRetainedSamples: 100, snapshotStrideSamples: 10),
            onSnapshot: { _ in unexpectedAfterCancel.fulfill() }
        )
        cancelledRecorder.cancel()
        cancelledRecorder.cancel()
        secondCapture?.emit(.init(id: 2, samples: [2], sampleRange: 1..<2, capturedAt: 2))
        await fulfillment(of: [unexpectedAfterCancel], timeout: 0.15)
        XCTAssertEqual(secondBackend.stopCount, 1)
        XCTAssertEqual(secondCapture?.stopCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(cancelledURL).path))

        let interruptedBackend = FakeAudioRecordingBackend()
        var interruptedCapture: FakeRollingAudioCapture?
        let unexpectedAfterInterruption = expectation(description: "No snapshots after interruption")
        unexpectedAfterInterruption.isInverted = true
        let interruptedRecorder = AudioRecorder(
            recorderFactory: { url, _ in
                FileManager.default.createFile(atPath: url.path, contents: Data())
                return interruptedBackend
            },
            rollingCaptureFactory: { _, callback, interruption in
                let capture = FakeRollingAudioCapture(
                    onSnapshot: callback,
                    onInterruption: interruption
                )
                interruptedCapture = capture
                return capture
            }
        )
        try interruptedRecorder.start(
            rolling: .init(maximumRetainedSamples: 100, snapshotStrideSamples: 10),
            onSnapshot: { _ in unexpectedAfterInterruption.fulfill() }
        )
        interruptedCapture?.interrupt()
        await Task.yield()
        interruptedCapture?.emit(.init(id: 3, samples: [3], sampleRange: 2..<3, capturedAt: 3))
        await fulfillment(of: [unexpectedAfterInterruption], timeout: 0.15)
        let interruptedOutput = try interruptedRecorder.stop()
        defer { try? FileManager.default.removeItem(at: interruptedOutput) }
        XCTAssertEqual(interruptedCapture?.stopCount, 1)
        XCTAssertEqual(interruptedBackend.stopCount, 1)
    }

    func testRollingWhisperKeepsOneActiveAndLatestPendingThenCoalescesEqualText() async throws {
        let firstStarted = expectation(description: "First rolling inference started")
        let secondStarted = expectation(description: "Latest pending inference started")
        let results = expectation(description: "Only distinct current hypothesis delivered")
        results.expectedFulfillmentCount = 2
        let releaseFirst = DispatchSemaphore(value: 0)
        let probe = WhisperExecutionProbe()
        let transcriber = WhisperTranscriber(infer: { samples, _, _, _ in
            let call = probe.record("infer")
            if call == 1 {
                firstStarted.fulfill()
                _ = releaseFirst.wait(timeout: .now() + 2)
                return "primeira"
            }
            secondStarted.fulfill()
            return samples.last == 3 ? "mais recente" : "obsoleta"
        })
        let recognizer = try XCTUnwrap(transcriber.makeRollingRecognizer(glossaryText: "") { hypothesis in
            _ = probe.record("result-\(hypothesis.snapshotID)-\(hypothesis.text)")
            results.fulfill()
        })
        func snapshot(_ id: UInt64, _ value: Float) -> AudioSampleSnapshot {
            .init(id: id, samples: [value], sampleRange: Int64(id - 1)..<Int64(id), capturedAt: Double(id))
        }

        recognizer.submit(snapshot(1, 1))
        await fulfillment(of: [firstStarted], timeout: 1)
        recognizer.submit(snapshot(2, 2))
        recognizer.submit(snapshot(3, 3))
        recognizer.submit(snapshot(3, 3))
        XCTAssertEqual(recognizer.queuedInferenceCount, 2)
        releaseFirst.signal()

        await fulfillment(of: [secondStarted, results], timeout: 2)
        XCTAssertEqual(probe.events.filter { $0 == "infer" }.count, 2)
        XCTAssertTrue(probe.events.contains("result-1-primeira"))
        XCTAssertTrue(probe.events.contains("result-3-mais recente"))
        XCTAssertFalse(probe.events.contains { $0.contains("result-2-") })
        XCTAssertEqual(recognizer.queuedInferenceCount, 0)
    }

    func testAcceptedPromptTermIsLateBoundForRollingAndCompletedWAV() async throws {
        let first = expectation(description: "Base rolling prompt")
        let second = expectation(description: "Enriched rolling prompt")
        let probe = WhisperPromptProbe()
        let transcriber = WhisperTranscriber(resultInference: { samples, _, prompt, _ in
            let call = probe.record(prompt: prompt)
            return .init(text: "fala \(call)-\(samples.count)", tokenEvidence: [])
        })
        let recognizer = try XCTUnwrap(transcriber.makeRollingRecognizer(
            glossaryText: "Resenha",
            promptTerms: { probe.terms }
        ) { _ in
            if probe.nextHypothesis() == 1 { first.fulfill() } else { second.fulfill() }
        })
        recognizer.submit(.init(id: 1, samples: [1], sampleRange: 0..<1, capturedAt: 1))
        await fulfillment(of: [first], timeout: 1)
        probe.setTerms(["Hostel"])
        recognizer.submit(.init(id: 2, samples: [1, 2], sampleRange: 0..<2, capturedAt: 2))
        await fulfillment(of: [second], timeout: 1)

        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        _ = try await transcriber.transcribeWithEvidence(
            audioURL: recording.audio,
            glossaryText: "Resenha",
            promptTerms: ["Hostel"]
        )

        XCTAssertEqual(probe.prompts, ["Resenha", "Resenha, Hostel", "Resenha, Hostel"])
        XCTAssertEqual(
            WhisperTranscriber.prompt(
                glossaryText: "",
                adding: [String(repeating: "x", count: 8_001), "COESA"]
            ),
            "COESA"
        )
    }

    func testRollingWhisperCancellationTagsNoncooperativeLateResultAsStale() async throws {
        let started = expectation(description: "Rolling inference started")
        let staleResult = expectation(description: "Late result tagged stale")
        let release = DispatchSemaphore(value: 0)
        let transcriber = WhisperTranscriber(infer: { _, _, _, _ in
            started.fulfill()
            _ = release.wait(timeout: .now() + 2)
            return "resultado tardio"
        })
        let recognizer = try XCTUnwrap(transcriber.makeRollingRecognizer(glossaryText: "") { hypothesis in
            XCTAssertTrue(hypothesis.isStale)
            XCTAssertTrue(hypothesis.isProvisional)
            staleResult.fulfill()
        })
        recognizer.submit(.init(id: 9, samples: [1], sampleRange: 0..<1, capturedAt: 1))
        await fulfillment(of: [started], timeout: 1)
        recognizer.cancel()
        release.signal()
        await fulfillment(of: [staleResult], timeout: 1)
        XCTAssertEqual(recognizer.queuedInferenceCount, 0)
    }

    func testRollingWhisperSharesBackpressureAcrossAttemptsWhileOldWorkIgnoresCancellation() async throws {
        let oldStarted = expectation(description: "Old attempt started")
        let newStarted = expectation(description: "New attempt started")
        let hypotheses = expectation(description: "Old stale and new current hypotheses")
        hypotheses.expectedFulfillmentCount = 2
        let releaseOld = DispatchSemaphore(value: 0)
        let probe = WhisperExecutionProbe()
        let transcriber = WhisperTranscriber(infer: { samples, _, _, _ in
            let call = probe.beginInference()
            defer { probe.endInference() }
            if call == 1 {
                oldStarted.fulfill()
                _ = releaseOld.wait(timeout: .now() + 2)
                return "antiga"
            }
            newStarted.fulfill()
            return samples.last == 2 ? "nova" : "inesperada"
        })
        let old = try XCTUnwrap(transcriber.makeRollingRecognizer(glossaryText: "") { hypothesis in
            XCTAssertTrue(hypothesis.isStale)
            _ = probe.record("old-\(hypothesis.text)")
            hypotheses.fulfill()
        })
        let new = try XCTUnwrap(transcriber.makeRollingRecognizer(glossaryText: "") { hypothesis in
            XCTAssertFalse(hypothesis.isStale)
            _ = probe.record("new-\(hypothesis.text)")
            hypotheses.fulfill()
        })

        old.submit(.init(id: 1, samples: [1], sampleRange: 0..<1, capturedAt: 1))
        await fulfillment(of: [oldStarted], timeout: 1)
        old.cancel()
        new.submit(.init(id: 2, samples: [2], sampleRange: 0..<1, capturedAt: 2))
        XCTAssertEqual(new.queuedInferenceCount, 2)
        XCTAssertEqual(probe.peakInferences, 1)
        releaseOld.signal()

        await fulfillment(of: [newStarted, hypotheses], timeout: 2)
        XCTAssertEqual(probe.peakInferences, 1)
        XCTAssertEqual(probe.events.filter { $0 == "infer" }.count, 2)
        XCTAssertTrue(probe.events.contains("old-antiga"))
        XCTAssertTrue(probe.events.contains("new-nova"))
        XCTAssertEqual(new.queuedInferenceCount, 0)
    }

    func testUnsupportedRollingRecognitionLeavesCompletedWAVFallbackAuthoritative() async throws {
        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        let transcriber = WhisperTranscriber(
            infer: { _, _, _, _ in "Transcrição final." },
            supportsRollingInference: false
        )
        XCTAssertNil(transcriber.makeRollingRecognizer { _ in XCTFail("Unsupported rolling path must stay closed") })

        let final = try await transcriber.transcribe(audioURL: recording.audio, glossaryText: "")
        XCTAssertEqual(final, "Transcrição final.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
    }

    private struct SessionEvent: ContinuousContextRollingEvent {
        let snapshotID: UInt64
        let sampleRange: Range<Int64>
        let capturedAt: TimeInterval
        let candidateAt: TimeInterval
        let text: String
        let tokenEvidence: [WhisperTokenEvidence]
        var isStale = false

        init(
            snapshotID: UInt64,
            sampleRange: Range<Int64>,
            capturedAt: TimeInterval,
            candidateAt: TimeInterval,
            text: String,
            tokenEvidence: [WhisperTokenEvidence] = [],
            isStale: Bool = false
        ) {
            self.snapshotID = snapshotID
            self.sampleRange = sampleRange
            self.capturedAt = capturedAt
            self.candidateAt = candidateAt
            self.text = text
            self.tokenEvidence = tokenEvidence
            self.isStale = isStale
        }
    }

    private actor RevisionLoopProvider: ContextualDecisionProvider {
        enum Mode: Sendable {
            case immediate(ContextualDecisionReceipt)
            case failure(OpenRouterDecisionsError)
            case suspended
        }

        private let mode: Mode
        private var continuation: CheckedContinuation<ContextualDecisionReceipt, Error>?
        private var startWaiters: [CheckedContinuation<Void, Never>] = []
        private(set) var requestCount = 0

        init(_ mode: Mode) { self.mode = mode }

        func decide(
            sentence: String,
            language: String,
            occurrences: [ContextualCorrectionOccurrence],
            deadline: ContextualInstant
        ) async throws -> ContextualDecisionReceipt {
            requestCount += 1
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
            switch mode {
            case .immediate(let receipt): return receipt
            case .failure(let error): throw error
            case .suspended:
                return try await withCheckedThrowingContinuation { continuation = $0 }
            }
        }

        func waitUntilStarted() async {
            if requestCount > 0 { return }
            await withCheckedContinuation { startWaiters.append($0) }
        }

        func resume(_ receipt: ContextualDecisionReceipt) {
            continuation?.resume(returning: receipt)
            continuation = nil
        }
    }

    private final class RevisionLifetimeProbe: @unchecked Sendable {}

    private final class RevisionWeakLifetimeReference {
        weak var value: RevisionLifetimeProbe?
        init(_ value: RevisionLifetimeProbe) { self.value = value }
    }

    private final class RevisionCancellationProvider: ContextualDecisionProvider, @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<ContextualDecisionReceipt, Error>?
        private var startWaiters: [CheckedContinuation<Void, Never>] = []
        private var cancelled = false
        private var retainedRequestText: String?
        private var retainedRequestProbe: RevisionLifetimeProbe?
        private var cancellationCountStorage = 0
        private var decisionCountStorage = 0

        init(requestProbe: RevisionLifetimeProbe) {
            retainedRequestProbe = requestProbe
        }

        func decide(
            sentence: String,
            language: String,
            occurrences: [ContextualCorrectionOccurrence],
            deadline: ContextualInstant
        ) async throws -> ContextualDecisionReceipt {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    var startWaiters: [CheckedContinuation<Void, Never>] = []
                    let cancelImmediately = lock.withLock {
                        decisionCountStorage += 1
                        retainedRequestText = sentence
                        startWaiters = self.startWaiters
                        self.startWaiters.removeAll()
                        guard !cancelled else { return true }
                        self.continuation = continuation
                        return false
                    }
                    startWaiters.forEach { $0.resume() }
                    if cancelImmediately {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            } onCancel: {
                self.cancelRequest()
            }
        }

        func waitUntilStarted() async {
            let shouldWait = lock.withLock { retainedRequestText == nil }
            guard shouldWait else { return }
            await withCheckedContinuation { waiter in
                let alreadyStarted = lock.withLock {
                    guard retainedRequestText == nil else { return true }
                    startWaiters.append(waiter)
                    return false
                }
                if alreadyStarted { waiter.resume() }
            }
        }

        @discardableResult
        func completeLate(with receipt: ContextualDecisionReceipt) -> Bool {
            let continuation = lock.withLock {
                let continuation = self.continuation
                self.continuation = nil
                return continuation
            }
            continuation?.resume(returning: receipt)
            return continuation != nil
        }

        var cancellationCount: Int { lock.withLock { cancellationCountStorage } }
        var decisionCount: Int { lock.withLock { decisionCountStorage } }
        var capturedRequestText: String? { lock.withLock { retainedRequestText } }

        private func cancelRequest() {
            let continuation = lock.withLock {
                cancelled = true
                cancellationCountStorage += 1
                retainedRequestText = nil
                retainedRequestProbe = nil
                let continuation = self.continuation
                self.continuation = nil
                return continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    private final class RevisionWeakProviderReference {
        weak var value: RevisionCancellationProvider?
        init(_ value: RevisionCancellationProvider) { self.value = value }
    }

    private final class RevisionUptime: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0.0
        func now() -> TimeInterval { lock.withLock { value } }
        func set(milliseconds: Int) { lock.withLock { value = Double(milliseconds) / 1_000 } }
    }

    private final class RevisionGeneration: @unchecked Sendable {
        private let lock = NSLock()
        private var value: UInt64
        init(_ value: UInt64) { self.value = value }
        func read() -> UInt64 { lock.withLock { value } }
        func set(_ value: UInt64) { lock.withLock { self.value = value } }
    }

    @MainActor
    private final class RevisionSnapshotBox {
        var value: ContextualCorrectionStoreSnapshot
        init(_ value: ContextualCorrectionStoreSnapshot) { self.value = value }
    }

    private func revisionReceipt(
        choice: ContextualDecisionChoice = .replace,
        confidence: Double = 0.99,
        probability: Double = 0.99,
        localAttemptID: UUID? = nil
    ) -> ContextualDecisionReceipt {
        .init(
            decisions: [.init(
                questionID: "o1",
                choice: choice,
                confidence: confidence,
                chosenProbability: probability,
                runnerUpProbability: 1 - probability
            )],
            resolvedModel: "fixture/deterministic",
            inputTokens: nil,
            outputTokens: nil,
            costUSD: nil,
            localAttemptID: localAttemptID
        )
    }

    private var revisionExample: ContextualCorrectionExample {
        .init(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
            language: "pt",
            heard: "rosto",
            canonical: "Hostel",
            sentence: "Reservei um rosto.",
            occurrenceOrdinal: 1
        )
    }

    func testContinuousContextAdmissionHonors499500501MillisecondsAndLatestWins() throws {
        for boundary in [499, 500, 501] {
            let uptime = RevisionUptime()
            let session = ContinuousContextSession(now: { uptime.now() })
            XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
            _ = session.ingest(SessionEvent(
                snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
                candidateAt: 0, text: "Reservei um rosto."
            ))
            let active = try XCTUnwrap(session.takeNextWork())
            uptime.set(milliseconds: 100)
            _ = session.ingest(SessionEvent(
                snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.05,
                candidateAt: 0.1, text: "Reservei outro rosto."
            ))
            _ = session.ingest(SessionEvent(
                snapshotID: 3, sampleRange: 0..<300, capturedAt: 0.08,
                candidateAt: 0.1, text: "Reservei o último rosto."
            ))
            XCTAssertEqual(session.scheduledWorkCount, 2)
            XCTAssertFalse(session.completeWork(active))
            uptime.set(milliseconds: boundary)
            let next = session.takeNextWork()
            XCTAssertEqual(next != nil, boundary >= 500, "boundary-\(boundary)")
            if let next { XCTAssertEqual(next.revision, 3, "boundary-\(boundary)") }
        }
    }

    func testContinuousContextWorkExpiresFromCandidateTime() throws {
        let uptime = RevisionUptime()
        let session = ContinuousContextSession(now: { uptime.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        uptime.set(milliseconds: 300)
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))

        let work = try XCTUnwrap(session.takeNextWork())
        XCTAssertEqual(work.eligibleAt, 0.3, accuracy: 0.001)
        XCTAssertEqual(work.expiresAt, 1.2, accuracy: 0.001)
        XCTAssertNotNil(session.remainingDuration(of: work))
    }

    @MainActor
    func testRevisionBoundLoopAccepts1199AndRejects1200And1201Milliseconds() async throws {
        for boundary in [1_199, 1_200, 1_201] {
            let uptime = RevisionUptime()
            let time = ManualContextualTime()
            let provider = RevisionLoopProvider(.suspended)
            let session = ContinuousContextSession(now: { uptime.now() })
            XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
            _ = session.ingest(SessionEvent(
                snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
                candidateAt: 0, text: "Reservei um rosto."
            ))
            let snapshot = ContextualCorrectionStoreSnapshot(
                examples: [revisionExample], generation: 7, health: .healthy
            )
            let loop = RevisionBoundJevLoop(
                session: session,
                provider: provider,
                time: time,
                storeSnapshot: { snapshot },
                policyGeneration: { 11 }
            )
            let task = Task { await loop.evaluateNext(scope: .testDouble) }
            await provider.waitUntilStarted()
            time.advance(milliseconds: Int64(boundary))
            await provider.resume(revisionReceipt())
            let result = await task.value
            XCTAssertEqual(
                result?.text,
                boundary == 1_199 ? "Reservei um Hostel." : "Reservei um rosto.",
                "boundary-\(boundary)"
            )
            XCTAssertEqual(
                session.contextualPreviewText,
                boundary == 1_199 ? "Reservei um Hostel." : "Reservei um rosto.",
                "boundary-\(boundary)"
            )
        }
    }

    @MainActor
    func testRevisionBoundLoopDeadlineIncludesCandidateQueueAge() async throws {
        for providerMilliseconds in [899, 900] {
            let uptime = RevisionUptime()
            let time = ManualContextualTime()
            let provider = RevisionLoopProvider(.suspended)
            let session = ContinuousContextSession(now: { uptime.now() })
            XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
            uptime.set(milliseconds: 300)
            _ = session.ingest(SessionEvent(
                snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
                candidateAt: 0, text: "Reservei um rosto."
            ))
            let snapshot = ContextualCorrectionStoreSnapshot(
                examples: [revisionExample], generation: 7, health: .healthy
            )
            let loop = RevisionBoundJevLoop(
                session: session,
                provider: provider,
                time: time,
                storeSnapshot: { snapshot },
                policyGeneration: { 11 }
            )
            let task = Task { await loop.evaluateNext(scope: .testDouble) }
            await provider.waitUntilStarted()
            uptime.set(milliseconds: 300 + providerMilliseconds)
            time.advance(milliseconds: Int64(providerMilliseconds))
            await provider.resume(revisionReceipt())

            let result = await task.value
            XCTAssertEqual(
                result?.text,
                providerMilliseconds == 899 ? "Reservei um Hostel." : "Reservei um rosto.",
                "provider-\(providerMilliseconds)"
            )
        }
    }

    @MainActor
    func testProactiveLoopDispatchesOnlyAfterSecondIdenticalCandidate() async throws {
        let uptime = RevisionUptime()
        let session = ContinuousContextSession(now: { uptime.now() })
        let provider = RevisionLoopProvider(.immediate(revisionReceipt()))
        let snapshot = ContextualCorrectionStoreSnapshot(examples: [], generation: 1, health: .healthy)
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 1 },
            glossaryTerms: { ["Hostel"] }
        )
        let evidence = [WhisperTokenEvidence(
            tokenID: 1, text: " rosto", probability: 0.20, alternatives: []
        )]
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei uma cama no rosto.", tokenEvidence: evidence
        ))
        _ = await loop.evaluateNext(scope: .testDouble)
        let firstRequestCount = await provider.requestCount
        XCTAssertEqual(firstRequestCount, 0)

        uptime.set(milliseconds: 500)
        _ = session.ingest(SessionEvent(
            snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.4,
            candidateAt: 0.5, text: "Reservei uma cama no rosto hoje.", tokenEvidence: evidence
        ))
        let result = await loop.evaluateNext(scope: .testDouble)
        let secondRequestCount = await provider.requestCount
        XCTAssertEqual(secondRequestCount, 1)
        XCTAssertEqual(result?.text, "Reservei uma cama no Hostel hoje.")
        XCTAssertEqual(session.ephemeralTerms, ["Hostel"])
    }

    func testAcceptedTermsAreAtomicDeduplicatedCappedAndClearedOnCancel() throws {
        let uptime = RevisionUptime()
        let session = ContinuousContextSession(now: { uptime.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))

        for index in 1...7 {
            uptime.set(milliseconds: (index - 1) * 500)
            let heard = "termo\(index)"
            let replacement = ["Destino1", "Destino1", "Destino2", "Destino3", "Destino4", "Destino5", "Destino6"][index - 1]
            let text = "Usei \(heard)."
            _ = session.ingest(SessionEvent(
                snapshotID: UInt64(index), sampleRange: 0..<Int64(index * 100),
                capturedAt: uptime.now(), candidateAt: uptime.now(), text: text
            ))
            let work = try XCTUnwrap(session.takeNextWork())
            let range = try XCTUnwrap(text.range(of: heard))
            let occurrence = ContextualCorrectionOccurrence(
                questionID: "o1", heard: heard, canonical: replacement,
                alternatives: [.init(id: "replace_1", value: replacement, source: .vocabulary)],
                ordinal: 1, range: range
            )
            let result = RevisionBoundContextualResult(
                identity: work.identity(policyGeneration: 1, storeGeneration: 1),
                originalText: text,
                text: text.replacingCharacters(in: range, with: replacement),
                outcome: .init(category: .replaced, decisions: [.init(
                    questionID: "o1", choice: .replace,
                    selectedProbability: 0.99, runnerUpProbability: 0.01
                )])
            )
            XCTAssertNotNil(session.applyContextualResult(result, occurrence: occurrence, for: work))
        }

        XCTAssertEqual(session.ephemeralTerms, ["Destino1", "Destino2", "Destino3", "Destino4", "Destino5"])
        session.cancel()
        XCTAssertTrue(session.ephemeralTerms.isEmpty)
    }

    @MainActor
    func testRevisionBoundLoopReturnsCorrectionRebasedOntoAppendedSpeech() async throws {
        let uptime = RevisionUptime()
        let provider = RevisionLoopProvider(.suspended)
        let session = ContinuousContextSession(now: { uptime.now() })
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 7, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 11 }
        )
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))

        let task = Task { await loop.evaluateNext(scope: .testDouble) }
        await provider.waitUntilStarted()
        uptime.set(milliseconds: 100)
        _ = session.ingest(SessionEvent(
            snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.05,
            candidateAt: 0.1, text: "Reservei um rosto. O quarto estava limpo."
        ))
        await provider.resume(revisionReceipt())

        let completed = await task.value
        let result = try XCTUnwrap(completed)
        XCTAssertEqual(result.text, "Reservei um Hostel. O quarto estava limpo.")
        XCTAssertEqual(session.contextualPreviewText, result.text)
    }

    @MainActor
    func testRevisionBoundLoopKeepsResponseThatArrivedBeforeDeadline() async throws {
        let time = ManualContextualTime()
        var policyReads = 0
        let session = ContinuousContextSession(now: { 0 })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 7, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: RevisionLoopProvider(.immediate(revisionReceipt())),
            time: time,
            storeSnapshot: { snapshot },
            policyGeneration: {
                policyReads += 1
                if policyReads == 2 { time.advance(milliseconds: 201) }
                return 11
            }
        )

        let result = await loop.evaluateNext(scope: .testDouble)

        XCTAssertEqual(result?.text, "Reservei um Hostel.")
        XCTAssertEqual(session.contextualPreviewText, "Reservei um Hostel.")
        XCTAssertEqual(time.now().offset, .milliseconds(201))
    }

    @MainActor
    func testRevisionBoundLoopReportsAppliedProviderAttempt() async throws {
        let attemptID = UUID()
        let audit = ContextualAttemptStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/attempts.json"))
        audit.consume(.requested(id: attemptID, at: Date()))
        audit.consume(.succeeded(
            id: attemptID, startedAt: Date(), completedAt: Date(), latencyMilliseconds: 1,
            receipt: revisionReceipt(localAttemptID: attemptID)
        ))
        let session = ContinuousContextSession(now: { 0 })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 7, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: RevisionLoopProvider(.immediate(revisionReceipt(localAttemptID: attemptID))),
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 11 },
            onAttemptDisposition: { id, disposition, context in
                audit.consume(.resolved(id: id, disposition: disposition, context: context))
            }
        )

        let result = await loop.evaluateNext(scope: .testDouble)

        XCTAssertEqual(result?.text, "Reservei um Hostel.")
        XCTAssertEqual(audit.latest?.disposition, .appliedReplacement)
        XCTAssertEqual(audit.latest?.stage, .rolling)
        XCTAssertEqual(audit.latest?.revision, 1)
        XCTAssertEqual(audit.latest?.dispatchOrdinal, 1)
        XCTAssertEqual(audit.latest?.candidateToDecisionMilliseconds, 0)
    }

    @MainActor
    private func runRevisionBoundCancellationScenario() async throws -> (
        RevisionWeakLifetimeReference,
        RevisionWeakProviderReference
    ) {
        let uptime = RevisionUptime()
        let session = ContinuousContextSession(now: { uptime.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 7, health: .healthy
        )
        var requestProbe: RevisionLifetimeProbe? = RevisionLifetimeProbe()
        weak var weakRequestProbe = requestProbe
        var taskProbe: RevisionLifetimeProbe? = RevisionLifetimeProbe()
        let weakTaskProbe = RevisionWeakLifetimeReference(try XCTUnwrap(taskProbe))
        var provider: RevisionCancellationProvider? = RevisionCancellationProvider(
            requestProbe: try XCTUnwrap(requestProbe)
        )
        let weakProvider = RevisionWeakProviderReference(try XCTUnwrap(provider))
        var loop: RevisionBoundJevLoop? = RevisionBoundJevLoop(
            session: session,
            provider: try XCTUnwrap(provider),
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 11 }
        )
        var task: Task<RevisionBoundContextualResult?, Never>? = Task { [
            loop = try XCTUnwrap(loop),
            taskProbe = try XCTUnwrap(taskProbe)
        ] in
            defer { withExtendedLifetime(taskProbe) {} }
            return await loop.evaluateNext(scope: .testDouble)
        }
        requestProbe = nil
        taskProbe = nil
        await provider?.waitUntilStarted()
        XCTAssertEqual(provider?.capturedRequestText, "Reservei um rosto.")

        uptime.set(milliseconds: 100)
        _ = session.ingest(SessionEvent(
            snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.05,
            candidateAt: 0.1, text: "Reservei outro rosto."
        ))
        XCTAssertEqual(session.scheduledWorkCount, 2)

        session.cancel()
        let result = await task?.value
        XCTAssertEqual(result?.text, "Reservei um rosto.")
        XCTAssertEqual(provider?.cancellationCount, 1)
        XCTAssertNil(provider?.capturedRequestText)
        XCTAssertNil(weakRequestProbe)
        XCTAssertEqual(session.state, .cancelled)
        XCTAssertEqual(session.scheduledWorkCount, 0)
        XCTAssertNil(session.latestRevision)
        XCTAssertNil(session.contextualPreviewText)
        XCTAssertFalse(provider?.completeLate(with: revisionReceipt()) ?? true)
        XCTAssertNil(session.commitFinalCandidate())
        XCTAssertEqual(session.state, .cancelled)
        XCTAssertNil(session.contextualPreviewText)

        task = nil
        loop = nil
        provider = nil
        await Task.yield()
        return (weakTaskProbe, weakProvider)
    }

    @MainActor
    func testRevisionBoundLoopSessionCancelCancelsProviderAndReleasesRequestOwnership() async throws {
        let (taskProbe, provider) = try await runRevisionBoundCancellationScenario()
        await Task.yield()
        XCTAssertNil(taskProbe.value)
        XCTAssertNil(provider.value)
    }

    @MainActor
    func testRevisionBoundLoopAuthorityInvalidationCancelsOpenedProviderAndDiscardsResponse() async throws {
        let uptime = RevisionUptime()
        let session = ContinuousContextSession(now: { uptime.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 7, health: .healthy
        )
        let policy = ContextualCorrectionPolicy()
        let provider = RevisionCancellationProvider(requestProbe: RevisionLifetimeProbe())
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { policy.generation },
            policy: policy
        )
        let token = policy.issueToken(scope: .personalDictation)
        let task = Task {
            await loop.evaluateNext(scope: token.scope, policyToken: token)
        }
        await provider.waitUntilStarted()

        policy.invalidate(.authorityChanged)
        let completed = await task.value
        let result = try XCTUnwrap(completed)
        XCTAssertEqual(result.outcome.category, .abstained)
        XCTAssertEqual(result.text, "Reservei um rosto.")
        XCTAssertEqual(provider.cancellationCount, 1)
        XCTAssertFalse(provider.completeLate(with: revisionReceipt()))

        uptime.set(milliseconds: 1_000)
        _ = session.ingest(SessionEvent(
            snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.5,
            candidateAt: 0.5, text: "Reservei outro rosto."
        ))
        let staleResult = await loop.evaluateNext(scope: token.scope, policyToken: token)
        XCTAssertEqual(staleResult?.outcome.category, .abstained)
        XCTAssertEqual(provider.cancellationCount, 1)
        XCTAssertEqual(provider.decisionCount, 1)

        uptime.set(milliseconds: 2_000)
        _ = session.ingest(SessionEvent(
            snapshotID: 3, sampleRange: 0..<300, capturedAt: 1.5,
            candidateAt: 1.5, text: "Reservei mais um rosto."
        ))
        let unbound = await loop.evaluateNext(scope: .personalDictation)
        XCTAssertEqual(unbound?.outcome.category, .abstained)
        XCTAssertEqual(provider.decisionCount, 1)
    }

    @MainActor
    func testRevisionBoundLoopFailsOpenForProviderErrorsInvalidOutputAndChangedAuthority() async throws {
        for error in [
            OpenRouterDecisionsError.invalidStatus(401),
            .invalidStatus(429),
            .invalidStatus(500),
            .transportUnavailable
        ] {
            let session = ContinuousContextSession(now: { 0 })
            XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
            _ = session.ingest(SessionEvent(
                snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
                candidateAt: 0, text: "Reservei um rosto."
            ))
            let snapshot = ContextualCorrectionStoreSnapshot(
                examples: [revisionExample], generation: 1, health: .healthy
            )
            let loop = RevisionBoundJevLoop(
                session: session,
                provider: RevisionLoopProvider(.failure(error)),
                time: ManualContextualTime(),
                storeSnapshot: { snapshot },
                policyGeneration: { 1 }
            )
            let output = await loop.evaluateNext(scope: .testDouble)
            XCTAssertEqual(output?.text, "Reservei um rosto.")
            XCTAssertEqual(session.contextualPreviewText, "Reservei um rosto.")
        }

        let invalid = revisionReceipt(confidence: 0.89, probability: 0.89)
        let invalidSession = ContinuousContextSession(now: { 0 })
        XCTAssertTrue(invalidSession.start(attemptID: UUID(), language: "pt"))
        _ = invalidSession.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let healthy = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 1, health: .healthy
        )
        let invalidLoop = RevisionBoundJevLoop(
            session: invalidSession,
            provider: RevisionLoopProvider(.immediate(invalid)),
            time: ManualContextualTime(),
            storeSnapshot: { healthy },
            policyGeneration: { 3 }
        )
        let invalidResult = await invalidLoop.evaluateNext(scope: .testDouble)
        XCTAssertEqual(invalidResult?.text, "Reservei um rosto.")

        let session = ContinuousContextSession(now: { 0 })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let policyGeneration = RevisionGeneration(3)
        let provider = RevisionLoopProvider(.suspended)
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 1, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { policyGeneration.read() }
        )
        let task = Task { await loop.evaluateNext(scope: .testDouble) }
        await provider.waitUntilStarted()
        policyGeneration.set(4)
        await provider.resume(invalid)
        let changedAuthority = await task.value
        XCTAssertEqual(changedAuthority?.text, "Reservei um rosto.")
        XCTAssertEqual(session.contextualPreviewText, "Reservei um rosto.")
    }

    @MainActor
    func testRevisionBoundLoopBindsStoreGenerationAndRepeatedOccurrenceIdentity() async throws {
        let repeatedReceipt = ContextualDecisionReceipt(
            decisions: [
                .init(
                    questionID: "o1", choice: .keepOriginal, confidence: 0.99,
                    chosenProbability: 0.99, runnerUpProbability: 0.01
                ),
                .init(
                    questionID: "o2", choice: .replace, confidence: 0.99,
                    chosenProbability: 0.99, runnerUpProbability: 0.01
                )
            ],
            resolvedModel: "fixture/deterministic",
            inputTokens: nil,
            outputTokens: nil,
            costUSD: nil
        )
        let session = ContinuousContextSession(now: { 0 })
        let attemptID = UUID()
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 9, sampleRange: 100..<900, capturedAt: 0,
            candidateAt: 0, text: "Lavei o rosto e reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 17, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: RevisionLoopProvider(.immediate(repeatedReceipt)),
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 23 }
        )
        let evaluated = await loop.evaluateNext(scope: .testDouble)
        let result = try XCTUnwrap(evaluated)
        XCTAssertEqual(result.text, "Lavei o rosto e reservei um Hostel.")
        XCTAssertEqual(result.identity.attemptID, attemptID)
        XCTAssertEqual(result.identity.revision, 1)
        XCTAssertEqual(result.identity.snapshotID, 9)
        XCTAssertEqual(result.identity.sampleRange, 100..<900)
        XCTAssertEqual(result.identity.storeGeneration, 17)
        XCTAssertEqual(result.identity.policyGeneration, 23)

        let staleSession = ContinuousContextSession(now: { 0 })
        XCTAssertTrue(staleSession.start(attemptID: UUID(), language: "pt"))
        _ = staleSession.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let provider = RevisionLoopProvider(.suspended)
        let box = RevisionSnapshotBox(snapshot)
        let staleLoop = RevisionBoundJevLoop(
            session: staleSession,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { box.value },
            policyGeneration: { 23 }
        )
        let task = Task { await staleLoop.evaluateNext(scope: .testDouble) }
        await provider.waitUntilStarted()
        box.value = .init(examples: [], generation: 18, health: .healthy)
        await provider.resume(revisionReceipt())
        let stale = await task.value
        XCTAssertEqual(stale?.text, "Reservei um rosto.")
        XCTAssertEqual(staleSession.contextualPreviewText, "Reservei um rosto.")
    }

    @MainActor
    func testRevisionBoundLoopRejectsStaleCallbackAndDisabledScopeWithoutTransport() async throws {
        let uptime = RevisionUptime()
        let provider = RevisionLoopProvider(.suspended)
        let session = ContinuousContextSession(now: { uptime.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1, sampleRange: 0..<100, capturedAt: 0,
            candidateAt: 0, text: "Reservei um rosto."
        ))
        let snapshot = ContextualCorrectionStoreSnapshot(
            examples: [revisionExample], generation: 1, health: .healthy
        )
        let loop = RevisionBoundJevLoop(
            session: session,
            provider: provider,
            time: ManualContextualTime(),
            storeSnapshot: { snapshot },
            policyGeneration: { 1 }
        )
        let task = Task { await loop.evaluateNext(scope: .testDouble) }
        await provider.waitUntilStarted()
        uptime.set(milliseconds: 100)
        _ = session.ingest(SessionEvent(
            snapshotID: 2, sampleRange: 0..<200, capturedAt: 0.05,
            candidateAt: 0.1, text: "Reservei outro rosto."
        ))
        await provider.resume(revisionReceipt())
        let stale = await task.value
        XCTAssertEqual(stale?.text, "Reservei um rosto.")
        XCTAssertNil(session.contextualPreviewText)
        XCTAssertTrue(session.ephemeralTerms.isEmpty)

        uptime.set(milliseconds: 500)
        let blocked = await loop.evaluateNext(scope: .disabled)
        XCTAssertEqual(blocked?.text, "Reservei outro rosto.")
        let requestCount = await provider.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testContinuousContextSessionReconcilesImmutableUnicodeSnapshotsAndRejectsOldWork() throws {
        var uptime: TimeInterval = 20
        let attemptID = UUID()
        let session = ContinuousContextSession(now: { uptime })
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))

        func event(_ id: UInt64, _ text: String) -> SessionEvent {
            SessionEvent(
                snapshotID: id,
                sampleRange: 0..<Int64(id * 100),
                capturedAt: uptime - 0.1,
                candidateAt: uptime,
                text: text
            )
        }

        let first = try XCTUnwrap(session.ingest(event(1, "A COE")))
        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(first.stablePrefixCharacterCount, 0)
        XCTAssertEqual(first.mutableSuffix, "A COE")
        let firstWork = try XCTUnwrap(session.takeNextWork())

        uptime = 21
        let splitWord = try XCTUnwrap(session.ingest(event(2, "A COESA chegou 👩🏽‍💻")))
        XCTAssertEqual(splitWord.stablePrefixCharacterCount, 5)
        XCTAssertEqual(splitWord.mutableSourceCharacterRange, 5..<splitWord.sourceText.count)
        XCTAssertEqual(splitWord.mutableSuffix, "SA chegou 👩🏽‍💻")
        uptime = 22
        let retracted = try XCTUnwrap(session.ingest(event(3, "A coisa mudou")))
        XCTAssertEqual(retracted.stablePrefixCharacterCount, 2)
        XCTAssertEqual(retracted.mutableSuffix, "coisa mudou")
        XCTAssertEqual(session.scheduledWorkCount, 2)

        XCTAssertFalse(session.completeWork(firstWork))
        let latestWork = try XCTUnwrap(session.takeNextWork())
        XCTAssertEqual(latestWork.revision, retracted.revision)
        XCTAssertTrue(session.completeWork(latestWork))
        XCTAssertNil(session.ingest(event(3, "callback reordenado")))
        XCTAssertNil(session.ingest(event(4, "A coisa mudou")))
        XCTAssertEqual(session.latestRevision?.revision, 3)
    }

    func testContinuousContextSessionBoundsAudioTextAndLatestWinsUnderLongStream() throws {
        let configuration = ContinuousContextSession.Configuration(
            maximumContextAge: 0.01,
            maximumContextCharacters: 12,
            maximumWorkAge: 0.2,
            sampleRate: 1_000
        )
        let session = ContinuousContextSession(configuration: configuration, now: { 50 })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))

        for id in 1...10_000 {
            let upper = Int64(id * 20)
            session.retainAudio(.init(
                id: UInt64(id),
                samples: (0..<20).map(Float.init),
                sampleRange: (upper - 20)..<upper,
                capturedAt: Double(id)
            ))
            _ = session.ingest(SessionEvent(
                snapshotID: UInt64(id),
                sampleRange: 0..<upper,
                capturedAt: 49,
                candidateAt: 50,
                text: "prefixo-\(id)-abcdefghijklmnop"
            ))
            if id == 1 { XCTAssertNotNil(session.takeNextWork()) }
            XCTAssertLessThanOrEqual(session.retainedAudioSampleCount, 10)
            XCTAssertLessThanOrEqual(session.retainedContextCharacterCount, 12)
            XCTAssertLessThanOrEqual(session.scheduledWorkCount, 2)
        }

        XCTAssertEqual(session.retainedContext, "efghijklmnop")
        XCTAssertEqual(session.retainedAudioSampleCount, 10)
    }

    func testContinuousContextSessionFinalizationIsFrozenExactlyOnceAndReleasesState() throws {
        let attemptID = UUID()
        let session = ContinuousContextSession(now: { 9 })
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))
        _ = session.ingest(SessionEvent(
            snapshotID: 1,
            sampleRange: 0..<100,
            capturedAt: 8,
            candidateAt: 9,
            text: "texto parcial"
        ))
        let lateWork = try XCTUnwrap(session.takeNextWork())
        session.retainAudio(.init(id: 1, samples: [1, 2], sampleRange: 0..<2, capturedAt: 8))

        let final = try XCTUnwrap(session.finalize(SessionEvent(
            snapshotID: 2,
            sampleRange: 0..<200,
            capturedAt: 8.5,
            candidateAt: 9,
            text: "texto final"
        ), attemptID: attemptID))
        XCTAssertEqual(final.kind, .final)
        XCTAssertEqual(session.state, .finalizing)
        XCTAssertEqual(session.finalCandidate?.sourceText, "texto final")
        XCTAssertFalse(session.completeWork(lateWork))
        XCTAssertNil(session.ingest(SessionEvent(
            snapshotID: 3,
            sampleRange: 0..<300,
            capturedAt: 8.8,
            candidateAt: 9,
            text: "texto tardio"
        )))

        let committed = try XCTUnwrap(session.commitFinalCandidate())
        XCTAssertEqual(committed.sourceText, "texto final")
        XCTAssertEqual(committed.attemptID, attemptID)
        XCTAssertEqual(session.state, .committed)
        XCTAssertNil(session.commitFinalCandidate())
        XCTAssertNil(session.latestRevision)
        XCTAssertNil(session.finalCandidate)
        XCTAssertEqual(session.retainedAudioSampleCount, 0)
        XCTAssertEqual(session.retainedContextCharacterCount, 0)
        XCTAssertEqual(session.scheduledWorkCount, 0)
    }

    func testContinuousContextSessionFinalizesAnUnchangedLastHypothesisAndExpiresWork() throws {
        var uptime: TimeInterval = 4
        let attemptID = UUID()
        let session = ContinuousContextSession(now: { uptime })
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))
        let partial = SessionEvent(
            snapshotID: 1,
            sampleRange: 0..<100,
            capturedAt: 3,
            candidateAt: 4,
            text: "mesmo texto"
        )
        _ = session.ingest(partial)
        let expiring = try XCTUnwrap(session.takeNextWork())
        uptime = 5.201
        XCTAssertFalse(session.completeWork(expiring))

        let final = try XCTUnwrap(session.finalize(SessionEvent(
            snapshotID: 2,
            sampleRange: 0..<200,
            capturedAt: 3.5,
            candidateAt: 5.2,
            text: "mesmo texto"
        ), attemptID: attemptID))
        XCTAssertEqual(final.mutableSourceCharacterRange, final.sourceText.count..<final.sourceText.count)
        XCTAssertEqual(session.finalCandidate?.sourceText, "mesmo texto")
    }

    func testContinuousContextSessionAcceptsAuthoritativeFinalForLatestFramesOnlyOnce() throws {
        let attemptID = UUID()
        let session = ContinuousContextSession(now: { 10 })
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))
        let provisional = SessionEvent(
            snapshotID: 7,
            sampleRange: 100..<500,
            capturedAt: 9,
            candidateAt: 9.5,
            text: "A coisa chegou"
        )
        _ = try XCTUnwrap(session.ingest(provisional))

        let olderFinal = SessionEvent(
            snapshotID: 6,
            sampleRange: 0..<400,
            capturedAt: 8,
            candidateAt: 10,
            text: "texto antigo"
        )
        XCTAssertNil(session.finalize(olderFinal, attemptID: attemptID))
        XCTAssertNil(session.finalize(provisional, attemptID: UUID()))

        let authoritativeFinal = SessionEvent(
            snapshotID: 7,
            sampleRange: 100..<500,
            capturedAt: 9,
            candidateAt: 10,
            text: "A COESA chegou"
        )
        let revision = try XCTUnwrap(session.finalize(authoritativeFinal, attemptID: attemptID))
        XCTAssertEqual(revision.kind, .final)
        XCTAssertEqual(revision.sourceText, "A COESA chegou")
        XCTAssertEqual(session.state, .finalizing)

        XCTAssertNil(session.finalize(authoritativeFinal, attemptID: attemptID))
        XCTAssertNil(session.ingest(SessionEvent(
            snapshotID: 8,
            sampleRange: 100..<600,
            capturedAt: 9.5,
            candidateAt: 10,
            text: "callback tardio"
        )))
        XCTAssertEqual(session.commitFinalCandidate()?.sourceText, "A COESA chegou")
        XCTAssertNil(session.commitFinalCandidate())
    }

    func testContinuousContextSessionCancelAndFailureReleaseAllSensitiveState() {
        for terminal in [ContinuousContextSessionState.cancelled, .failed] {
            weak var weakSession: ContinuousContextSession?
            autoreleasepool {
                let session = ContinuousContextSession(now: { 3 })
                weakSession = session
                XCTAssertTrue(session.start(attemptID: UUID(), language: "pt"))
                _ = session.ingest(SessionEvent(
                    snapshotID: 1,
                    sampleRange: 0..<2,
                    capturedAt: 2,
                    candidateAt: 3,
                    text: "conteúdo privado"
                ))
                session.retainAudio(.init(id: 1, samples: [1, 2], sampleRange: 0..<2, capturedAt: 2))
                terminal == .cancelled ? session.cancel() : session.fail()
                XCTAssertEqual(session.state, terminal)
                XCTAssertNil(session.latestRevision)
                XCTAssertEqual(session.retainedAudioSampleCount, 0)
                XCTAssertEqual(session.retainedContextCharacterCount, 0)
                XCTAssertEqual(session.scheduledWorkCount, 0)
            }
            XCTAssertNil(weakSession)
        }
    }

    func testTextOnlyInferenceProducesEmptyEvidenceAndCompatibilityText() async throws {
        let first = try temporaryWhisperRecording()
        let second = try temporaryWhisperRecording()
        defer {
            try? FileManager.default.removeItem(at: first.directory)
            try? FileManager.default.removeItem(at: second.directory)
        }
        let transcriber = WhisperTranscriber(infer: { _, _, _, _ in "Texto compatível." })

        let enriched = try await transcriber.transcribeWithEvidence(audioURL: first.audio, glossaryText: "")
        let textOnly = try await transcriber.transcribe(audioURL: second.audio, glossaryText: "")

        XCTAssertEqual(enriched, WhisperTranscription(text: "Texto compatível.", tokenEvidence: []))
        XCTAssertEqual(textOnly, enriched.text)
    }

    func testRollingHypothesisCarriesBoundedEvidenceIntoRevisionAndWork() {
        let evidence = [WhisperTokenEvidence(
            tokenID: 20,
            text: " rosto",
            probability: 0.42,
            alternatives: [.init(tokenID: 90, text: " Hostel", logit: 7.2)]
        )]
        let session = ContinuousContextSession(now: { 1 })
        let attemptID = UUID()
        XCTAssertTrue(session.start(attemptID: attemptID, language: "pt"))

        let revision = session.ingest(RollingWhisperHypothesis(
            snapshotID: 1,
            sampleRange: 0..<16_000,
            capturedAt: 0,
            candidateAt: 0.5,
            text: "Reservei uma cama no rosto.",
            tokenEvidence: evidence
        ))

        XCTAssertEqual(revision?.tokenEvidence, evidence)
        XCTAssertEqual(session.takeNextWork()?.tokenEvidence, evidence)
    }

    func testWhisperLogitCollectorAlignsAlternativesWithoutChangingChosenTokens() {
        let hostel = WhisperAlternativeToken(tokenID: 90, text: " Hostel", logit: 7.2)
        let rosto = WhisperAlternativeToken(tokenID: 20, text: " rosto", logit: 6.8)
        let collector = WhisperLogitCollector(snapshots: [
            .init(prefixSuffix: [2, 10], alternatives: [
                .init(tokenID: 91, text: " decoy", logit: 9.9)
            ]),
            .init(prefixSuffix: [1, 10], alternatives: [hostel, rosto]),
            .init(prefixSuffix: [1, 10, 20], alternatives: [
                .init(tokenID: 30, text: " perto", logit: 8.1)
            ])
        ])

        let evidence = collector.align(
            tokenIDs: [1, 10, 20, 30],
            tokenTexts: ["<|start|>", " Eu", " rosto", " perto"],
            probabilities: [1, 0.99, 0.42, 0.96],
            endOfText: 100
        )

        XCTAssertEqual(evidence.map(\.tokenID), [10, 20, 30])
        XCTAssertEqual(evidence.map(\.text), [" Eu", " rosto", " perto"])
        XCTAssertEqual(evidence[1].alternatives, [hostel, rosto])
        XCTAssertEqual(evidence[2].alternatives.map(\.text), [" perto"])
    }

    func testWhisperLogitCollectorRejectsUnmatchedPrefixesAndBoundsSelectedEvidence() {
        let decoy = WhisperAlternativeToken(tokenID: 90, text: " Hostel", logit: 7.2)
        let collector = WhisperLogitCollector(snapshots: [
            .init(prefixSuffix: [999, 10], alternatives: [decoy])
        ])
        let unmatched = collector.align(
            tokenIDs: [1, 10, 20],
            tokenTexts: ["<|start|>", " Eu", " rosto"],
            probabilities: [1, 0.99, 0.42],
            endOfText: 1_000
        )
        XCTAssertEqual(unmatched.last?.alternatives, [])

        let ids = Array(1...140).map(Int32.init)
        let bounded = WhisperLogitCollector().align(
            tokenIDs: ids,
            tokenTexts: Array(repeating: " a", count: ids.count),
            probabilities: Array(repeating: 0.5, count: ids.count),
            endOfText: 1_000
        )
        XCTAssertEqual(bounded.count, 128)
        XCTAssertEqual(bounded.first?.tokenID, 13)
        XCTAssertTrue(bounded.allSatisfy { $0.probability.isFinite && (0...1).contains($0.probability) })
    }

    func testCTopLogitsReturnsDescendingFiniteCandidatesWithoutMutatingInput() {
        let original: [Float] = [1, .nan, 9, 3, .infinity, 7, 5]
        var logits = original
        var output = Array(repeating: ResenhaLogitCandidate(token_id: -1, logit: 0), count: 4)
        let count = logits.withUnsafeMutableBufferPointer { values in
            output.withUnsafeMutableBufferPointer { candidates in
                resenha_top_logits(values.baseAddress, Int32(values.count), 4, candidates.baseAddress)
            }
        }

        XCTAssertEqual(count, 4)
        XCTAssertEqual(output.map(\.token_id), [2, 5, 6, 3])
        XCTAssertEqual(logits[0], original[0])
        XCTAssertTrue(logits[1].isNaN)
        XCTAssertTrue(logits[4].isInfinite)
        XCTAssertEqual(Array(logits[5...]), Array(original[5...]))
    }

    func testEmbeddedWhisperTranscribesOfficialFixtureWhenLocalModelIsAvailable() async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = home.appendingPathComponent(
            "Library/Application Support/WhisperKey/Models/ggml-small-q5_1.bin"
        )
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper model is not installed")
        }

        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }

        let result = try await WhisperTranscriber().transcribeWithEvidence(
            audioURL: recording.audio,
            language: .english,
            glossaryText: ""
        )
        let transcript = result.text.lowercased()

        XCTAssertTrue(transcript.contains("fellow americans"), transcript)
        XCTAssertTrue(transcript.contains("country"), transcript)
        XCTAssertFalse(result.tokenEvidence.isEmpty)
        XCTAssertTrue(result.tokenEvidence.contains { !$0.alternatives.isEmpty })
        XCTAssertLessThanOrEqual(result.tokenEvidence.count, 128)
        XCTAssertTrue(result.tokenEvidence.allSatisfy {
            $0.probability.isFinite && (0...1).contains($0.probability) && $0.alternatives.count <= 4
        })
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
    }

    func testRealWhisperEvidenceCollectionP95OverheadStaysBelowFifteenPercent() async throws {
        let model = WhisperPaths.modelDirectory.appendingPathComponent("ggml-small-q5_1.bin")
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper benchmark model is not installed")
        }
        let baselineEngine = EmbeddedWhisperEngine(collectsTokenEvidence: false)
        let evidenceEngine = EmbeddedWhisperEngine()

        func measure(_ engine: EmbeddedWhisperEngine) async throws -> (TimeInterval, WhisperTranscription) {
            let recording = try temporaryWhisperRecording()
            defer { try? FileManager.default.removeItem(at: recording.directory) }
            let transcriber = WhisperTranscriber(resultInference: { samples, language, prompt, control in
                try engine.transcribeWithEvidence(
                    samples: samples,
                    model: model,
                    language: language,
                    prompt: prompt,
                    control: control
                )
            })
            let started = ProcessInfo.processInfo.systemUptime
            let result = try await transcriber.transcribeWithEvidence(
                audioURL: recording.audio,
                language: .english,
                glossaryText: ""
            )
            return (ProcessInfo.processInfo.systemUptime - started, result)
        }

        _ = try await measure(baselineEngine)
        _ = try await measure(evidenceEngine)
        var baseline: [TimeInterval] = []
        var evidence: [TimeInterval] = []
        for iteration in 0..<20 {
            if iteration.isMultiple(of: 2) {
                baseline.append(try await measure(baselineEngine).0)
                let measured = try await measure(evidenceEngine)
                evidence.append(measured.0)
                XCTAssertFalse(measured.1.tokenEvidence.isEmpty)
            } else {
                let measured = try await measure(evidenceEngine)
                evidence.append(measured.0)
                XCTAssertFalse(measured.1.tokenEvidence.isEmpty)
                baseline.append(try await measure(baselineEngine).0)
            }
        }
        func p95(_ values: [TimeInterval]) -> TimeInterval {
            let sorted = values.sorted()
            return sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
        }
        let baselineP95 = p95(baseline)
        let evidenceP95 = p95(evidence)
        print("WHISPER_EVIDENCE_BENCHMARK baseline_ms=\(baseline.map { Int($0 * 1_000) }) evidence_ms=\(evidence.map { Int($0 * 1_000) }) p95_baseline_ms=\(Int(baselineP95 * 1_000)) p95_evidence_ms=\(Int(evidenceP95 * 1_000))")
        XCTAssertLessThanOrEqual(evidenceP95, baselineP95 * 1.15)
    }

    func testWhisperRuntimePolicyHasAnExactBound() {
        let clock = WhisperExecutionProbe()
        let control = WhisperExecutionControl(maximumRuntime: 600, clock: { clock.now })
        clock.advance(to: 699.999)
        XCTAssertFalse(control.shouldAbort)
        clock.advance(to: 700)
        XCTAssertTrue(control.shouldAbort)
        control.cancel()
        XCTAssertThrowsError(try control.check()) { error in
            guard case WhisperError.timedOut = error else { return XCTFail("Timeout cause must remain latched") }
        }
        let cancelled = WhisperExecutionControl(clock: { clock.now })
        cancelled.cancel()
        clock.advance(to: 2_000)
        XCTAssertThrowsError(try cancelled.check()) { XCTAssertTrue($0 is CancellationError) }
    }

    func testRealWhisperCancellationAndDeadlineAbortThenRecoverOnSameEngine() async throws {
        let model = WhisperPaths.modelDirectory.appendingPathComponent("ggml-small-q5_1.bin")
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper model is not installed")
        }
        let engine = EmbeddedWhisperEngine()
        let removals = WhisperExecutionProbe()
        let transcriber = WhisperTranscriber(infer: { samples, language, prompt, control in
            try engine.transcribe(samples: samples, model: model, language: language, prompt: prompt, control: control)
        }, removeAudio: { url in
            _ = removals.record("removed")
            try FileManager.default.removeItem(at: url)
        })
        for (index, interruption) in ["cancel", "timeout"].enumerated() {
            let recording = try temporaryWhisperRecording()
            defer { try? FileManager.default.removeItem(at: recording.directory) }
            let clock = WhisperExecutionProbe()
            let control = WhisperExecutionControl(maximumRuntime: 0.03, clock: { clock.now })
            let task = Task.detached {
                try await transcriber.transcribe(audioURL: recording.audio, language: .english,
                    glossaryText: "", control: control)
            }
            // Only whisper_full can poll this control: this engine has no injected inference.
            let startBound = ProcessInfo.processInfo.systemUptime + 20
            while control.abortCallbackPolls == 0, ProcessInfo.processInfo.systemUptime < startBound {
                try await Task.sleep(for: .milliseconds(5))
            }
            guard control.abortCallbackPolls > 0 else {
                task.cancel()
                _ = try? await task.value
                return XCTFail("Real whisper_full did not reach its abort callback within 20 seconds")
            }
            XCTAssertFalse(control.didAbortInference)
            XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
            let interruptedAt = ProcessInfo.processInfo.systemUptime
            if interruption == "cancel" { task.cancel() }
            else { clock.advance(to: 101) }
            do {
                _ = try await task.value
                XCTFail("Real interrupted inference must not deliver partial or late text")
            } catch {
                if interruption == "cancel" { XCTAssertTrue(error is CancellationError) }
                else if case WhisperError.timedOut = error { }
                else { XCTFail("Real deadline must map to WhisperError.timedOut") }
            }
            XCTAssertTrue(control.didAbortInference, "The real C callback must return abort, not just discard the final result")
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - interruptedAt, 5)

            let next = try temporaryWhisperRecording()
            defer { try? FileManager.default.removeItem(at: next.directory) }
            let transcript = try await transcriber.transcribe(audioURL: next.audio, language: .english,
                glossaryText: "", control: WhisperExecutionControl(maximumRuntime: 30)).lowercased()
            XCTAssertTrue(transcript.contains("fellow americans"), transcript)
            XCTAssertTrue(transcript.contains("country"), transcript)
            XCTAssertFalse(FileManager.default.fileExists(atPath: next.audio.path))
            XCTAssertEqual(removals.events.count, (index + 1) * 2)
        }
    }

    func testWhisperCancellationAbortsCallbackReleasesEngineAndConsumesWAVOnce() async throws {
        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        let entered = expectation(description: "Whisper entered")
        let aborted = expectation(description: "C callback aborted")
        let probe = WhisperExecutionProbe()
        let engine = EmbeddedWhisperEngine(inference: { params, samples in
            let call = probe.record("entered")
            XCTAssertFalse(samples.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
            if call == 1 {
                entered.fulfill()
                let bound = ProcessInfo.processInfo.systemUptime + 2
                while params.abort_callback?(params.abort_callback_user_data) != true {
                    guard ProcessInfo.processInfo.systemUptime < bound else { throw WhisperError.failed(-999, "abort not observed") }
                    Thread.sleep(forTimeInterval: 0.001)
                }
                _ = probe.record("aborted")
                aborted.fulfill()
                return "Partial result must be discarded."
            }
            return "Segunda tentativa."
        })
        let transcriber = WhisperTranscriber(infer: { samples, language, prompt, control in
            try engine.transcribe(samples: samples, model: recording.directory, language: language, prompt: prompt, control: control)
        }, removeAudio: { url in
            XCTAssertEqual(url, recording.audio)
            _ = probe.record("removed")
            try FileManager.default.removeItem(at: url)
        })
        let task = Task.detached { try await transcriber.transcribe(audioURL: recording.audio, glossaryText: "") }
        await fulfillment(of: [entered], timeout: 1)
        task.cancel()
        await fulfillment(of: [aborted], timeout: 1)
        do { _ = try await task.value; XCTFail("Cancelled inference must not return partial text") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(probe.events, ["removed", "entered", "aborted"])
        let next = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: next.directory) }
        let second = WhisperTranscriber(infer: { samples, language, prompt, control in
            try engine.transcribe(samples: samples, model: next.directory, language: language, prompt: prompt, control: control)
        })
        let result = try await second.transcribe(audioURL: next.audio, glossaryText: "")
        XCTAssertEqual(result, "Segunda tentativa.")
        XCTAssertEqual(probe.events, ["removed", "entered", "aborted", "entered"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: next.audio.path))
    }

    func testWhisperQueuedCancellationAndTimeoutDoNotWaitForEngineOwner() async throws {
        let entered = expectation(description: "Owner holds engine")
        let waiting = expectation(description: "Second attempt waits for engine")
        let release = DispatchSemaphore(value: 0)
        let probe = WhisperExecutionProbe()
        let engine = EmbeddedWhisperEngine(inference: { _, _ in
            if probe.record("entered") == 1 {
                entered.fulfill()
                guard release.wait(timeout: .now() + 2) == .success else { throw WhisperError.failed(-999, "owner not released") }
            }
            return "Resultado."
        }, onWait: {
            if probe.record("waiting") == 1 { waiting.fulfill() }
        })
        let model = FileManager.default.temporaryDirectory
        let owner = Task.detached {
            try engine.transcribe(samples: [0], model: model, language: "pt", prompt: "", control: WhisperExecutionControl())
        }
        defer { release.signal() }
        await fulfillment(of: [entered], timeout: 1)
        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        let transcriber = WhisperTranscriber(infer: { samples, language, prompt, control in
            try engine.transcribe(samples: samples, model: model, language: language, prompt: prompt, control: control)
        })
        let queued = Task.detached { try await transcriber.transcribe(audioURL: recording.audio) }
        await fulfillment(of: [waiting], timeout: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
        queued.cancel()
        do { _ = try await queued.value; XCTFail("Queued cancellation must leave without acquiring engine") }
        catch { XCTAssertTrue(error is CancellationError) }
        let deadline = WhisperExecutionControl(maximumRuntime: 0.03)
        let expired = Task.detached {
            try engine.transcribe(samples: [0], model: model, language: "pt", prompt: "", control: deadline)
        }
        do { _ = try await expired.value; XCTFail("Queued deadline must expire while owner still holds engine") }
        catch { guard case WhisperError.timedOut = error else { return XCTFail("Expected timeout") } }
        XCTAssertEqual(probe.events.filter { $0 == "entered" }.count, 1)
        release.signal()
        _ = try await owner.value
        let next = try engine.transcribe(samples: [0], model: model, language: "pt", prompt: "", control: WhisperExecutionControl())
        XCTAssertEqual(next, "Resultado.")
    }

    func testWhisperDeadlineAbortsInferenceAndReleasesCallbackControl() async throws {
        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        let entered = expectation(description: "Deadline inference entered")
        let aborted = expectation(description: "Deadline observed inside C callback")
        let engine = EmbeddedWhisperEngine(inference: { params, _ in
            entered.fulfill()
            let bound = ProcessInfo.processInfo.systemUptime + 2
            while params.abort_callback?(params.abort_callback_user_data) != true {
                guard ProcessInfo.processInfo.systemUptime < bound else { throw WhisperError.failed(-999, "deadline not observed") }
                Thread.sleep(forTimeInterval: 0.001)
            }
            aborted.fulfill()
            throw WhisperError.failed(-8, "aborted decode")
        })
        let transcriber = WhisperTranscriber(infer: { samples, language, prompt, control in
            try engine.transcribe(samples: samples, model: recording.directory, language: language, prompt: prompt, control: control)
        })
        let clock = WhisperExecutionProbe()
        weak var retainedControl: WhisperExecutionControl?
        do {
            let control = WhisperExecutionControl(maximumRuntime: 0.03, clock: { clock.now })
            retainedControl = control
            let task = Task.detached { try await transcriber.transcribe(audioURL: recording.audio, control: control) }
            await fulfillment(of: [entered], timeout: 1)
            clock.advance(to: 101)
            await fulfillment(of: [aborted], timeout: 1)
            do { _ = try await task.value; XCTFail("Deadline cannot return text") }
            catch { guard case WhisperError.timedOut = error else { return XCTFail("Expected timeout") } }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
        XCTAssertNil(retainedControl, "The C callback must not retain its control after inference returns")
    }

    func testWhisperConsumesOnlyOwnedWAVOnReadFailureEarlyCancellationAndInferenceFailure() async throws {
        for scenario in ["read", "cancel", "inference"] {
            let recording = try temporaryWhisperRecording()
            let untouched = recording.directory.appendingPathComponent("untouched.wav")
            try FileManager.default.copyItem(at: recording.audio, to: untouched)
            if scenario == "read" { try Data("invalid WAV".utf8).write(to: recording.audio) }
            let probe = WhisperExecutionProbe()
            let transcriber = WhisperTranscriber(infer: { _, _, _, _ in
                _ = probe.record("inference")
                throw WhisperError.failed(-6, "fixture failure")
            }, removeAudio: { url in
                XCTAssertEqual(url, recording.audio)
                _ = probe.record("removed")
                try FileManager.default.removeItem(at: url)
            })
            let control = WhisperExecutionControl()
            if scenario == "cancel" { control.cancel() }
            do { _ = try await transcriber.transcribe(audioURL: recording.audio, control: control); XCTFail("Expected fixture failure") }
            catch { if scenario == "cancel" { XCTAssertTrue(error is CancellationError) } }
            XCTAssertEqual(probe.events.filter { $0 == "removed" }.count, 1)
            XCTAssertEqual(probe.events.filter { $0 == "inference" }.count, scenario == "inference" ? 1 : 0)
            XCTAssertFalse(FileManager.default.fileExists(atPath: recording.audio.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: untouched.path))
            try FileManager.default.removeItem(at: recording.directory)
        }
    }

    @MainActor
    func testCoordinatorImmediateCancellationConsumesWAVWithoutResettingNextAttempt() async throws {
        let recording = try temporaryWhisperRecording()
        defer { try? FileManager.default.removeItem(at: recording.directory) }
        let removed = expectation(description: "Cancelled recording consumed")
        let transcriber = WhisperTranscriber(infer: { _, _, _, _ in
            XCTFail("Pre-cancelled attempt must not enter inference")
            return "Obsolete."
        }, removeAudio: { url in
            try FileManager.default.removeItem(at: url)
            removed.fulfill()
        })
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: FloatingPanelController(),
            showsHUD: { false }, soundsEnabled: { false }, onTranscript: { _ in XCTFail("No stale history") },
            transcriber: transcriber)
        coordinator.transition(to: .recording)
        coordinator.transcribeRecording(at: recording.audio)
        coordinator.cancel()
        let next = coordinator.attemptID
        coordinator.transition(to: .recording)
        await fulfillment(of: [removed], timeout: 1)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(coordinator.attemptID, next)
        XCTAssertEqual(coordinator.phase, .recording)
        coordinator.cancel()
    }

    @MainActor
    func testHUDNativeFixturesForEveryStateAndAppearance() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/ui-fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func capture<Content: View>(_ view: NSHostingView<Content>, size: CGSize, name: String) async throws {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false)
            defer { window.orderOut(nil) }
            window.contentView = view
            window.setContentSize(size)
            window.orderFront(nil)
            view.layoutSubtreeIfNeeded()
            // Let SwiftUI commit its display layers, then restore the fixture's bounded frame.
            try await Task.sleep(for: .milliseconds(20))
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutSubtreeIfNeeded()
            window.display()
            view.displayIfNeeded()
            XCTAssertEqual(view.bounds.size, size)
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent(name))
        }
        let states: [(String, FloatingStatus)] = [("ready", .ready), ("listening", .listening), ("listening-silence", .listening), ("listening-decay", .listening), ("transcribing", .transcribing), ("inserting", .inserting),
            ("feedback", .feedback), ("feedback-saved", .feedbackNotice("Termo adicionado ao vocabulário")),
            ("feedback-existing", .feedbackNotice("Termo já existente")),
            ("feedback-guidance", .feedbackNotice("Solte e pressione novamente para ditar")),
            ("failure", .failure("Permissão de Monitoramento de Entrada necessária")),
            ("long-failure", .failure("Permissão de Monitoramento de Entrada necessária para receber o atalho de ditado"))]
        let appearances: [(String, ColorScheme, ColorSchemeContrast, Bool, Bool)] = [
            ("light", .light, .standard, false, false), ("dark", .dark, .standard, false, false),
            ("increased-contrast", .light, .increased, false, false), ("reduced-transparency", .dark, .increased, true, false),
            ("reduced-motion", .light, .standard, false, true)]
        for (name, state) in states {
            for (appearance, scheme, contrast, opaque, reduceMotion) in appearances {
                let model = FloatingPanelModel()
                model.show(state, now: 100)
                if state == .listening {
                    let speech: [Float] = [-60, -50, -39, -22, -12, -7, -14, -24, -33, -48, -60, -60]
                    for index in 0..<RecordingMeter.barCount {
                        let power: Float = name == "listening-silence" ? -60
                            : name == "listening-decay" ? (index < 14 ? -14 : -60) : speech[index % speech.count]
                        model.recording.append(level: RecordingMeter.normalizedDecibels(power), at: 104.65 + Double(index) * 0.05)
                    }
                }
                let size = FloatingStatusView.panelSize(for: state, available: CGSize(width: 1440, height: 900))
                if state == .feedback { XCTAssertEqual(size, CGSize(width: 280, height: 64)) }
                else {
                    if state == .listening { XCTAssertEqual(size, CGSize(width: 340, height: 72)) }
                    else if !state.isFailure { XCTAssertEqual(size, CGSize(width: 280, height: 64)) }
                    XCTAssertLessThanOrEqual(size.width, 360)
                    XCTAssertLessThanOrEqual(size.height, 104)
                }
                let view = NSHostingView(rootView: FloatingStatusView(model: model, fixtureContrast: contrast, fixtureReduceTransparency: opaque, fixtureReduceMotion: reduceMotion, fixtureFeedbackElapsed: 1)
                    .environment(\.colorScheme, scheme))
                view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                try await capture(view, size: size, name: "hud-\(name)-\(appearance).png")
            }
        }
        for (appearance, scheme, contrast, opaque, reduceMotion) in appearances {
            let smallSize = FloatingStatusView.panelSize(for: .feedback, available: CGSize(width: 320, height: 320))
            let model = FloatingPanelModel()
            model.show(.feedback, now: 0)
            let offer = NSHostingView(rootView: FloatingStatusView(model: model, fixtureContrast: contrast,
                fixtureReduceTransparency: opaque, fixtureReduceMotion: reduceMotion,
                fixtureFeedbackElapsed: 1).environment(\.colorScheme, scheme))
            offer.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            try await capture(offer, size: smallSize, name: "hud-feedback-small-\(appearance).png")

            for fixture in ["empty", "long-error", "small-error", "save-disabled"] {
                let hasError = fixture.contains("error")
                let editor = TranscriptionCorrectionView(
                    heard: .constant(hasError ? "Coisa Energia e Participações de São José dos Campos" : ""),
                    canonical: .constant(hasError ? "COESA Energia e Participações de São José dos Campos" : ""),
                    errorMessage: hasError ? "Este termo já aponta para outro destino no glossário. Abra Ajustes → Transcrição → glossário para conferir a regra existente e corrigir o destino antes de salvar novamente." : nil,
                    invalidField: hasError ? .heard : nil, isSaveEnabled: fixture != "save-disabled",
                    onSave: {}, onCancel: {}, fixtureContrast: contrast,
                    fixtureReduceTransparency: opaque, fixtureReduceMotion: reduceMotion)
                XCTAssertEqual(editor.fixtureContrast, contrast)
                XCTAssertEqual(editor.fixtureReduceTransparency, opaque)
                XCTAssertEqual(editor.fixtureReduceMotion, reduceMotion)
                let size = TranscriptionCorrectionView.panelSize(available: fixture == "small-error"
                    ? CGSize(width: 320, height: 320) : CGSize(width: 1440, height: 900))
                let view = NSHostingView(rootView: editor.environment(\.colorScheme, scheme))
                view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                try await capture(view, size: size, name: "correction-\(fixture)-\(appearance).png")
            }
        }
    }

    func testRecordingMeterNormalizesActualPowerAndBoundsAttackDecay() {
        XCTAssertEqual(RecordingMeter.normalizedDecibels(-60), 0)
        XCTAssertEqual(RecordingMeter.normalizedDecibels(-30), 0.5)
        XCTAssertEqual(RecordingMeter.normalizedDecibels(0), 1)
        for power in [Float.nan, -.infinity, .infinity, -120] {
            XCTAssertEqual(RecordingMeter.normalizedDecibels(power), 0)
        }
        XCTAssertEqual(RecordingMeter.normalizedDecibels(12), 1)
        var meter = RecordingMeter()
        meter.start(at: 10)
        meter.append(level: 2, at: 10)
        XCTAssertEqual(meter.currentLevel, 0.65, accuracy: 0.0001)
        meter.append(level: .nan, at: 10.05)
        XCTAssertGreaterThan(meter.currentLevel, 0)
        XCTAssertLessThan(meter.currentLevel, 0.65)
        for index in 0..<100 { meter.append(level: -1, at: 10.1 + Double(index) * 0.05) }
        XCTAssertLessThan(meter.currentLevel, 0.0001)
        XCTAssertTrue(meter.levels.allSatisfy { $0.isFinite && (0...1).contains($0) })
    }

    func testRecordingMeterHistoryIsFixedOrderedAndSessionOnly() {
        var meter = RecordingMeter()
        meter.append(level: 1, at: 100)
        XCTAssertFalse(meter.isRecording)
        XCTAssertEqual(meter.levels, Array(repeating: 0, count: 48))
        meter.start(at: 10)
        for index in 1...60 { meter.append(level: Float(index) / 60, at: 10 + Double(index) * 0.05) }
        XCTAssertEqual(meter.levels.count, 48)
        XCTAssertGreaterThan(meter.levels[0], 0)
        XCTAssertEqual(meter.levels.last, meter.currentLevel)
        XCTAssertTrue(zip(meter.levels, meter.levels.dropFirst()).allSatisfy { $0 <= $1 })
        meter.start(at: 200)
        XCTAssertEqual(meter.elapsedText, "00:00")
        XCTAssertTrue(meter.levels.allSatisfy { $0 == 0 })
    }

    @MainActor
    func testInjectedRecordingClockRollsOverAndStopsResetsWithHUDLifecycle() {
        var now: TimeInterval = 10
        let panel = FloatingPanelController(clock: { now })
        panel.show(.listening, target: .session(42))
        panel.updateRecordingLevel(1)
        XCTAssertEqual(panel.recordingMeter.elapsedText, "00:00")
        now = 72.9
        panel.updateRecordingLevel(0)
        XCTAssertEqual(panel.recordingMeter.elapsedText, "01:02")
        panel.show(.listening, target: .session(42))
        XCTAssertEqual(panel.recordingMeter.elapsedText, "01:02")
        panel.show(.transcribing, target: .session(42))
        XCTAssertFalse(panel.recordingMeter.isRecording)
        panel.updateRecordingLevel(1)
        XCTAssertTrue(panel.recordingMeter.levels.allSatisfy { $0 == 0 })
        now = 90
        panel.show(.listening, target: .session(42))
        now = 97
        panel.updateRecordingLevel(0.5)
        XCTAssertEqual(panel.recordingMeter.elapsedText, "00:07")
        panel.hide()
        now = 110
        panel.updateRecordingLevel(1)
        XCTAssertFalse(panel.recordingMeter.isRecording)
        XCTAssertTrue(panel.recordingMeter.levels.allSatisfy { $0 == 0 })
        panel.show(.listening, target: .session(42))
        XCTAssertEqual(panel.recordingMeter.elapsedText, "00:00")
        panel.hide()
    }

    func testReducedMotionKeepsStationaryRealLevelAndStableAccessibleStatus() {
        var meter = RecordingMeter()
        meter.start(at: 0)
        for index in 0..<48 { meter.append(level: index.isMultiple(of: 2) ? 0.9 : 0.1, at: Double(index) / 20) }
        let history = meter.levels
        XCTAssertGreaterThan(Set(history).count, 1)
        XCTAssertEqual(meter.displayLevels(reduceMotion: true), Array(repeating: meter.currentLevel, count: 48))
        XCTAssertEqual(meter.displayLevels(reduceMotion: false), history)
        XCTAssertEqual(meter.levels, history)
        XCTAssertEqual(FloatingStatus.listening.accessibilityLabel, "Ouvindo…. Solte o atalho para concluir")
    }

    func testDictationStateMachineRejectsOverlap() {
        XCTAssertTrue(DictationPhase.idle.canTransition(to: .recording))
        XCTAssertFalse(DictationPhase.recording.canTransition(to: .recording))
        XCTAssertTrue(DictationPhase.recording.canTransition(to: .transcribing))
        XCTAssertTrue(DictationPhase.transcribing.canTransition(to: .inserting))
        XCTAssertTrue(DictationPhase.inserting.canTransition(to: .idle))
    }

    func testTranscriptNormalizationRemovesNonSpeechLines() {
        XCTAssertEqual(
            TranscriptNormalizer.normalize("  [Música]  \n Testando o sistema. \n"),
            "Testando o sistema."
        )
        XCTAssertEqual(TranscriptNormalizer.normalize(" [silêncio] "), "")
    }

    func testWhisperPathResolutionUsesOverrides() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = directory.appendingPathComponent("model.bin")
        XCTAssertTrue(FileManager.default.createFile(atPath: model.path, contents: Data()))

        let paths = try WhisperPaths.resolve(
            environment: ["WHISPER_MODEL_PATH": model.path],
            home: directory
        )
        XCTAssertEqual(paths.model, model)
    }
}

@MainActor
final class ContextualStoreTests: XCTestCase {
    private func makeStore() -> (ContextualCorrectionStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = root.appendingPathComponent("ContextualCorrections/v1.json")
        return (ContextualCorrectionStore(fileURL: file), file)
    }

    private func example(
        index: Int = 0,
        sentence: String? = nil,
        heard: String = "rosto",
        canonical: String = "Hostel",
        ordinal: Int = 1,
        language: String = "pt"
    ) -> ContextualCorrectionExample {
        .init(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
            language: language,
            heard: heard,
            canonical: canonical,
            sentence: sentence ?? "Contexto \(index): reservei um \(heard) na opcao \(index).",
            occurrenceOrdinal: ordinal
        )
    }

    func testContextualStoreSavesConfirmedOccurrenceWithoutChangingGlossary() throws {
        let suite = "ContextualStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = "rosto = Rosto\ncoisa energia = COESA Energia"
        defaults.set(original, forKey: "resenha.transcriptionGlossary")
        let preferences = ProductPreferences(defaults: defaults)
        let (store, file) = makeStore()

        XCTAssertEqual(store.save(example(sentence: "Reservei um rosto perto da estacao.")), .saved(example().id))
        XCTAssertEqual(store.examples.map(\.canonical), ["Hostel"])
        XCTAssertEqual(preferences.transcriptionGlossary, original)
        XCTAssertEqual(defaults.string(forKey: "resenha.transcriptionGlossary"), original)
        XCTAssertEqual(
            try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber,
            0o600
        )
    }

    func testContextualStoreAcceptsHundredAndRejectsHundredFirstWithoutEviction() {
        let (store, _) = makeStore()
        for index in 0..<100 { XCTAssertTrue(store.save(example(index: index)).isSuccess) }
        XCTAssertEqual(store.save(example(index: 100)), .limitReached)
        XCTAssertEqual(store.examples.count, 100)
        XCTAssertEqual(store.examples.first?.id, example().id)
    }

    func testContextualStoreUsesSwiftCharacterLimitWithoutTruncation() {
        let (store, _) = makeStore()
        let accepted = String(repeating: "e", count: 594) + " rosto"
        let rejected = String(repeating: "e", count: 595) + " rosto"
        XCTAssertEqual(accepted.count, 600)
        XCTAssertEqual(rejected.count, 601)
        XCTAssertTrue(store.save(example(index: 1, sentence: accepted)).isSuccess)
        XCTAssertEqual(store.save(example(index: 2, sentence: rejected)), .invalid(.sentenceTooLong))
    }

    func testContextualStoreDuplicateIsIdempotentAndConflictingTargetRequiresDeletion() {
        let (store, _) = makeStore()
        let original = example(sentence: "Reservei um rosto.")
        XCTAssertTrue(store.save(original).isSuccess)
        XCTAssertEqual(store.save(original), .alreadyExists(original.id))
        XCTAssertEqual(
            store.save(example(index: 1, sentence: original.sentence, canonical: "hotel")),
            .conflict(original.id)
        )
        XCTAssertEqual(store.examples, [original])
    }

    func testContextualStoreRejectsInvalidIdentityOccurrenceAndLanguage() {
        let (store, _) = makeStore()
        XCTAssertEqual(store.save(example(heard: " ")), .invalid(.empty))
        XCTAssertEqual(store.save(example(canonical: "ROSTO")), .invalid(.identical))
        XCTAssertEqual(store.save(example(heard: "rosto\n")), .invalid(.invalidCharacters))
        XCTAssertEqual(store.save(example(sentence: "Reservei um rosto.\nOutro trecho.")), .invalid(.invalidCharacters))
        XCTAssertEqual(
            store.save(example(sentence: "Reservei um rosto. Outro trecho.")),
            .invalid(.multipleSentences)
        )
        XCTAssertEqual(store.save(example(sentence: "Reservei um hotel.")), .invalid(.occurrenceMissing))
        XCTAssertEqual(store.save(example(sentence: "rosto e rosto", ordinal: 3)), .invalid(.occurrenceAmbiguous))
        XCTAssertEqual(store.save(example(language: "xx")), .invalid(.invalidCharacters))
    }

    func testContextualStoreAtomicWritePermissionsAndReload() throws {
        let (store, file) = makeStore()
        let first = example(sentence: "Reservei um rosto.")
        XCTAssertTrue(store.save(first).isSuccess)
        XCTAssertEqual(ContextualCorrectionStore(fileURL: file).examples, [first])
        XCTAssertTrue(store.delete(id: first.id))
        XCTAssertTrue(store.examples.isEmpty)
        XCTAssertTrue(store.reload())
        XCTAssertTrue(store.snapshot.health == .healthy)
    }

    func testContextualStoreCorruptOversizedAndFailedRollbackPreserveTrustworthyBytes() throws {
        let (store, file) = makeStore()
        let original = example(sentence: "Reservei um rosto.")
        XCTAssertTrue(store.save(original).isSuccess)
        let trusted = try Data(contentsOf: file)

        try Data("not-json".utf8).write(to: file, options: .atomic)
        XCTAssertFalse(store.reload())
        XCTAssertEqual(store.examples, [original])
        XCTAssertEqual(store.error, .corrupt)
        XCTAssertEqual(store.save(example(index: 2)), .storageFailure(recoveryRequired: true))

        try trusted.write(to: file, options: .atomic)
        XCTAssertTrue(store.reload())
        try Data(repeating: 0, count: ContextualCorrectionStore.maximumFileBytes + 1).write(to: file)
        XCTAssertFalse(store.reload())
        XCTAssertEqual(store.examples, [original])
        XCTAssertEqual(store.error, .oversized)
    }

    func testUnknownStoreVersionPreservesBytesAndBlocksMutation() throws {
        let (_, file) = makeStore()
        let bytes = Data(#"{"schemaVersion":2,"examples":[]}"#.utf8)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: file, options: .atomic)
        let store = ContextualCorrectionStore(fileURL: file)
        XCTAssertEqual(store.error, .unsupportedVersion(2))
        XCTAssertEqual(store.save(example()), .storageFailure(recoveryRequired: true))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    func testContextualStoreHealthSnapshotStaysUnhealthyUntilVerifiedReload() throws {
        let (store, file) = makeStore()
        let original = example(sentence: "Reservei um rosto.")
        XCTAssertTrue(store.save(original).isSuccess)
        let healthyGeneration = store.generation
        try Data("broken".utf8).write(to: file, options: .atomic)
        XCTAssertFalse(store.reload())
        XCTAssertEqual(store.snapshot.health, .unhealthy(.corrupt))
        XCTAssertEqual(store.generation, healthyGeneration)
        XCTAssertFalse(store.reload())
        XCTAssertEqual(store.snapshot.health, .unhealthy(.corrupt))

        let repair = #"{"schemaVersion":1,"examples":[]}"#
        try Data(repair.utf8).write(to: file, options: .atomic)
        XCTAssertTrue(store.reload())
        XCTAssertEqual(store.snapshot.health, .healthy)
        XCTAssertGreaterThan(store.generation, healthyGeneration)
    }
}

final class ManualContextualTime: ContextualMonotonicTime, @unchecked Sendable {
    private struct Waiter {
        let id: UUID
        let deadline: ContextualInstant
        let continuation: CheckedContinuation<Void, Error>
    }
    private let lock = NSLock()
    private var instant = ContextualInstant(offset: .zero)
    private var waiters: [Waiter] = []
    private var cancelledIDs: Set<UUID> = []

    func now() -> ContextualInstant { lock.withLock { instant } }

    func sleep(until deadline: ContextualInstant) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    if cancelledIDs.remove(id) != nil {
                        continuation.resume(throwing: CancellationError())
                    } else if instant >= deadline { continuation.resume() }
                    else { waiters.append(.init(id: id, deadline: deadline, continuation: continuation)) }
                }
            }
        } onCancel: { [weak self] in self?.cancel(id) }
    }

    func advance(milliseconds: Int64) {
        let ready: [Waiter] = lock.withLock {
            instant = .init(offset: .milliseconds(milliseconds))
            let ready = waiters.filter { $0.deadline <= instant }
            waiters.removeAll { $0.deadline <= instant }
            return ready
        }
        ready.forEach { $0.continuation.resume() }
    }

    private func cancel(_ id: UUID) {
        let waiter: Waiter? = lock.withLock {
            guard let index = waiters.firstIndex(where: { $0.id == id }) else {
                cancelledIDs.insert(id)
                return nil
            }
            return waiters.remove(at: index)
        }
        waiter?.continuation.resume(throwing: CancellationError())
    }
}

@MainActor
private final class ContextualMatcherCounter {
    var value = 0
}

private final class ContextualFailingFileManager: FileManager, @unchecked Sendable {
    var failSetAttributes = false

    override func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws {
        if failSetAttributes { throw CocoaError(.fileWriteUnknown) }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}

actor ResolverDecisionProviderStub: ContextualDecisionProvider {
    private(set) var requestCount = 0
    private(set) var captured: [ContextualCorrectionOccurrence] = []
    private(set) var capturedSentence: String?
    let decisions: [ContextualDecision]
    let localAttemptID: UUID?

    init(_ decisions: [ContextualDecision], localAttemptID: UUID? = nil) {
        self.decisions = decisions
        self.localAttemptID = localAttemptID
    }

    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        requestCount += 1
        captured = occurrences
        capturedSentence = sentence
        return .init(
            decisions: decisions,
            resolvedModel: "fixture/deterministic",
            inputTokens: nil,
            outputTokens: nil,
            costUSD: nil,
            localAttemptID: localAttemptID
        )
    }
}

actor SuspendedResolverProvider: ContextualDecisionProvider {
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var receiptContinuation: CheckedContinuation<ContextualDecisionReceipt, Error>?
    private(set) var requestCount = 0

    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        requestCount += 1
        let waiters = requestWaiters
        requestWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return try await withCheckedThrowingContinuation { receiptContinuation = $0 }
    }

    func waitForRequest() async {
        if requestCount > 0 { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func resume(_ receipt: ContextualDecisionReceipt) {
        receiptContinuation?.resume(returning: receipt)
        receiptContinuation = nil
    }
}

@MainActor
final class ContextualResolverTests: XCTestCase {
    private func example(
        index: Int = 0,
        heard: String = "rosto",
        canonical: String = "Hostel",
        sentence: String = "Reservei um rosto perto da estacao."
    ) -> ContextualCorrectionExample {
        .init(
            id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1))!,
            language: "pt",
            heard: heard,
            canonical: canonical,
            sentence: sentence,
            occurrenceOrdinal: 1
        )
    }

    private func fixture(
        examples: [ContextualCorrectionExample]? = nil,
        provider: any ContextualDecisionProvider,
        time: ManualContextualTime = .init(),
        matcher: ContextualCorrectionResolver.CandidateMatcher? = nil,
        fileManager: FileManager = .default,
        onAttemptDisposition: @escaping @MainActor @Sendable (
            UUID, ContextualAttemptDisposition, ContextualAttemptContext
        ) -> Void = { _, _, _ in }
    ) -> (ContextualCorrectionResolver, ContextualCorrectionStore, ContextualCorrectionPolicy, ManualContextualTime, URL) {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections/v1.json")
        let store = ContextualCorrectionStore(fileURL: file, fileManager: fileManager)
        for item in examples ?? [example()] { XCTAssertTrue(store.save(item).isSuccess) }
        let policy = ContextualCorrectionPolicy()
        let resolver: ContextualCorrectionResolver
        if let matcher {
            resolver = .init(
                store: store,
                policy: policy,
                provider: provider,
                storeGeneration: { store.generation },
                candidateMatcher: matcher,
                time: time,
                onAttemptDisposition: onAttemptDisposition
            )
        } else {
            resolver = .init(
                store: store,
                policy: policy,
                provider: provider,
                storeGeneration: { store.generation },
                time: time,
                onAttemptDisposition: onAttemptDisposition
            )
        }
        return (resolver, store, policy, time, file)
    }

    private func request(
        _ text: String,
        store: ContextualCorrectionStore,
        policy: ContextualCorrectionPolicy,
        scope: ContextualTransportScope = .testDouble
    ) -> ContextualResolutionRequest {
        .init(
            attemptID: UUID(),
            text: text,
            language: "pt",
            policyToken: policy.issueToken(scope: scope),
            storeGenerationAtStart: store.generation
        )
    }

    private func decision(
        _ id: String,
        _ choice: ContextualDecisionChoice,
        confidence: Double = 0.99,
        probability: Double = 0.99
    ) -> ContextualDecision {
        .init(
            questionID: id,
            choice: choice,
            confidence: confidence,
            chosenProbability: probability,
            runnerUpProbability: 1 - probability
        )
    }

    private func assertResolution(
        _ name: String,
        examples: [ContextualCorrectionExample]? = nil,
        input: String,
        decisions: [ContextualDecision],
        expected: String,
        expectedRequests: Int,
        expectedSentence: String? = nil,
        matcher: ContextualCorrectionResolver.CandidateMatcher? = nil
    ) async {
        let provider = ResolverDecisionProviderStub(decisions)
        let item = fixture(examples: examples, provider: provider, matcher: matcher)
        let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
        let requestCount = await provider.requestCount
        let sentence = await provider.capturedSentence
        XCTAssertEqual(output, expected, name)
        XCTAssertEqual(requestCount, expectedRequests, name)
        if let expectedSentence { XCTAssertEqual(sentence, expectedSentence, name) }
    }

    func testResolverKeepsCommonRostoAndChangesOnlySupportedSecondOccurrence() async {
        let provider = ResolverDecisionProviderStub([
            decision("o1", .keepOriginal), decision("o2", .replace)
        ])
        let item = fixture(provider: provider)
        let input = "Lavei o rosto antes de voltar ao rosto perto da estacao."
        let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
        XCTAssertEqual(output, "Lavei o rosto antes de voltar ao Hostel perto da estacao.")
    }

    func testResolverReportsAppliedProviderAttempt() async {
        let attemptID = UUID()
        let audit = ContextualAttemptStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/attempts.json"))
        audit.consume(.requested(id: attemptID, at: Date()))
        let receipt = ContextualDecisionReceipt(
            decisions: [decision("o1", .replace)], resolvedModel: "fixture/deterministic",
            inputTokens: nil, outputTokens: nil, costUSD: nil, localAttemptID: attemptID
        )
        audit.consume(.succeeded(
            id: attemptID, startedAt: Date(), completedAt: Date(), latencyMilliseconds: 1,
            receipt: receipt
        ))
        let provider = ResolverDecisionProviderStub(
            [decision("o1", .replace)], localAttemptID: attemptID
        )
        let item = fixture(provider: provider, onAttemptDisposition: { id, disposition, context in
            audit.consume(.resolved(id: id, disposition: disposition, context: context))
        })

        let output = await item.0.resolve(request("Reservei um rosto.", store: item.1, policy: item.2))

        XCTAssertEqual(output, "Reservei um Hostel.")
        XCTAssertEqual(audit.latest?.disposition, .appliedReplacement)
        XCTAssertEqual(audit.latest?.stage, .final)
        XCTAssertNil(audit.latest?.revision)
        XCTAssertEqual(audit.latest?.dispatchOrdinal, 1)
    }

    func testResolverOrdersMultiPairOccurrencesByRangeAndAssignsUniqueQuestionIDs() async {
        let provider = ResolverDecisionProviderStub([
            decision("o1", .keepOriginal), decision("o2", .keepOriginal), decision("o3", .keepOriginal)
        ])
        let examples = [
            example(index: 1, heard: "rosto", canonical: "Hostel"),
            example(index: 2, heard: "sexta", canonical: "cesta", sentence: "Cheguei na sexta porta."),
            example(index: 3, heard: "cesta", canonical: "sexta", sentence: "A cesta ficou na mesa.")
        ]
        let item = fixture(examples: examples, provider: provider)
        let input = "A cesta do rosto fica ao lado da sexta porta."
        let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
        XCTAssertEqual(output, input)
        let captured = await provider.captured
        XCTAssertEqual(captured.map(\.questionID), ["o1", "o2", "o3"])
        XCTAssertEqual(captured.map(\.heard), ["cesta", "rosto", "sexta"])
    }

    func testResolverRejectsInvalidUnicodeSpanConflictAndSentenceSets() async {
        await assertResolution(
            "nfc", input: "Reservei um rosto perto da estação.",
            decisions: [decision("o1", .replace)],
            expected: "Reservei um Hostel perto da estação.", expectedRequests: 1
        )
        await assertResolution(
            "nfd", input: "Reservei um rosto perto da estac\u{327}a\u{303}o.",
            decisions: [decision("o1", .replace)],
            expected: "Reservei um Hostel perto da estac\u{327}a\u{303}o.", expectedRequests: 1
        )
        await assertResolution(
            "punctuation", input: "(rosto)!", decisions: [decision("o1", .replace)],
            expected: "(Hostel)!", expectedRequests: 1
        )
        await assertResolution(
            "substring", input: "Os rostos ficaram vermelhos.", decisions: [],
            expected: "Os rostos ficaram vermelhos.", expectedRequests: 0
        )
        await assertResolution(
            "zero-candidate", input: "Reservei um hotel.", decisions: [],
            expected: "Reservei um hotel.", expectedRequests: 0
        )
        await assertResolution(
            "invalid-ordinal", input: "Reservei um rosto.", decisions: [],
            expected: "Reservei um rosto.", expectedRequests: 0,
            matcher: { _, text, _ in
                [.init(questionID: "o1", heard: "rosto", canonical: "Hostel", ordinal: 0,
                       range: text.range(of: "rosto")!)]
            }
        )
        await assertResolution(
            "out-of-range-ordinal", input: "Reservei um rosto.", decisions: [],
            expected: "Reservei um rosto.", expectedRequests: 0,
            matcher: { _, text, _ in
                [.init(questionID: "o1", heard: "rosto", canonical: "Hostel", ordinal: 2,
                       range: text.range(of: "rosto")!)]
            }
        )
        await assertResolution(
            "overlap", input: "Reservei um rosto.", decisions: [],
            expected: "Reservei um rosto.", expectedRequests: 0,
            matcher: { _, text, _ in
                let range = text.range(of: "rosto")!
                return [
                    .init(questionID: "o1", heard: "rosto", canonical: "Hostel", ordinal: 1, range: range),
                    .init(questionID: "o2", heard: "rosto", canonical: "Hostel", ordinal: 1, range: range)
                ]
            }
        )
        await assertResolution(
            "multiple-sentences", input: "Vi meu rosto. Reservei um rosto.", decisions: [],
            expected: "Vi meu rosto. Reservei um rosto.", expectedRequests: 0
        )
        let tooLong = String(repeating: "é", count: 594) + " rosto."
        XCTAssertEqual(tooLong.count, 601)
        await assertResolution(
            "sentence-601", input: tooLong, decisions: [], expected: tooLong, expectedRequests: 0
        )
        await assertResolution(
            "conflicting-destination",
            examples: [
                example(index: 1),
                example(index: 2, canonical: "Hotel", sentence: "Outro rosto apareceu.")
            ],
            input: "Meu rosto ficou vermelho.", decisions: [],
            expected: "Meu rosto ficou vermelho.", expectedRequests: 0
        )
        await assertResolution(
            "immutable-outside-range", input: "🧭 Antes. Reservei um rosto. Depois, ação.",
            decisions: [decision("o1", .replace)],
            expected: "🧭 Antes. Reservei um Hostel. Depois, ação.", expectedRequests: 1,
            expectedSentence: "Reservei um rosto. "
        )
    }

    func testResolverAbstainsEntireInputAboveThreeCandidateOccurrencesWithoutRequest() async {
        let provider = ResolverDecisionProviderStub([])
        let item = fixture(provider: provider)
        let input = "rosto, rosto, rosto e rosto"
        let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
        let requestCount = await provider.requestCount
        XCTAssertEqual(output, input)
        XCTAssertEqual(requestCount, 0)
    }

    func testResolverAppliesDollarAndBackslashCanonicalsLiterally() async {
        let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let item = fixture(
            examples: [example(canonical: #"Hostel $1 \\ Centro"#)],
            provider: provider
        )
        let output = await item.0.resolve(
            request("Reservei um rosto.", store: item.1, policy: item.2)
        )
        XCTAssertEqual(output, #"Reservei um Hostel $1 \\ Centro."#)
    }

    func testResolverRejectsDisabledScopeAndAllowsAuthorizedPersonalScope() async {
        let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let item = fixture(provider: provider)
        let input = "Reservei um rosto."
        let disabled = await item.0.resolve(request(input, store: item.1, policy: item.2, scope: .disabled))
        XCTAssertEqual(disabled, input)
        let personal = await item.0.resolve(request(input, store: item.1, policy: item.2, scope: .personalDictation))
        XCTAssertEqual(personal, "Reservei um Hostel.")
        let requestCount = await provider.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testResolverRejectsUnhealthyStoreBeforeMatchingOrProvider() async throws {
        for row in ["corrupt", "oversized", "unsupported-schema", "rollback-failed"] {
            let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
            let matchCount = ContextualMatcherCounter()
            let failingFileManager = ContextualFailingFileManager()
            let item = fixture(provider: provider, matcher: { _, _, _ in
                matchCount.value += 1
                return []
            }, fileManager: failingFileManager)
            let current = item.1.examples[0]
            switch row {
            case "corrupt":
                try Data("broken".utf8).write(to: item.4, options: .atomic)
                XCTAssertFalse(item.1.reload(), row)
            case "oversized":
                try Data(repeating: 0, count: ContextualCorrectionStore.maximumFileBytes + 1)
                    .write(to: item.4)
                XCTAssertFalse(item.1.reload(), row)
            case "unsupported-schema":
                try Data(#"{"schemaVersion":2,"examples":[]}"#.utf8)
                    .write(to: item.4, options: .atomic)
                XCTAssertFalse(item.1.reload(), row)
            default:
                failingFileManager.failSetAttributes = true
                _ = item.1.save(example(index: 90, sentence: "Outro rosto apareceu."))
                failingFileManager.failSetAttributes = false
                XCTAssertEqual(item.1.snapshot.health, .unhealthy(.rollbackFailed), row)
            }
            let input = "Reservei um rosto."
            let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
            let requestCount = await provider.requestCount
            XCTAssertEqual(output, input, row)
            XCTAssertEqual(matchCount.value, 0, row)
            XCTAssertEqual(requestCount, 0, row)
            XCTAssertEqual(item.1.examples, [current], row)
        }
    }

    func testResolverRecoversOnlyAfterExplicitVerifiedStoreReload() async throws {
        let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let item = fixture(provider: provider)
        let valid = try Data(contentsOf: item.4)
        try Data("broken".utf8).write(to: item.4, options: .atomic)
        XCTAssertFalse(item.1.reload())
        try valid.write(to: item.4, options: .atomic)
        let input = "Reservei um rosto."
        let beforeReload = await item.0.resolve(request(input, store: item.1, policy: item.2))
        XCTAssertEqual(beforeReload, input)
        XCTAssertTrue(item.1.reload())
        let afterReload = await item.0.resolve(request(input, store: item.1, policy: item.2))
        XCTAssertEqual(afterReload, "Reservei um Hostel.")
    }

    func testResolverRequiresConfidenceAndSelectedProbabilityAtThreshold() async {
        for row in [(0.899, 1.0, false), (1.0, 0.899, false), (0.9, 0.9, true), (1.0, 1.0, true)] {
            let provider = ResolverDecisionProviderStub([
                decision("o1", .replace, confidence: row.0, probability: row.1)
            ])
            let item = fixture(provider: provider)
            let output = await item.0.resolve(request("Reservei um rosto.", store: item.1, policy: item.2))
            XCTAssertEqual(output, row.2 ? "Reservei um Hostel." : "Reservei um rosto.")
        }
    }

    func testResolverRejectsMalformedProbabilityAndAnswerSets() async {
        let rows: [(String, String, [ContextualDecision])] = [
            ("finite", "Reservei um rosto.", [decision("o1", .replace, confidence: .nan)]),
            ("range", "Reservei um rosto.", [
                .init(questionID: "o1", choice: .replace, confidence: 1,
                      chosenProbability: 1.1, runnerUpProbability: -0.1)
            ]),
            ("total", "Reservei um rosto.", [
                .init(questionID: "o1", choice: .replace, confidence: 1,
                      chosenProbability: 0.9, runnerUpProbability: 0.2)
            ]),
            ("tie", "Reservei um rosto.", [
                .init(questionID: "o1", choice: .replace, confidence: 1,
                      chosenProbability: 0.5, runnerUpProbability: 0.5)
            ]),
            ("missing", "Reservei um rosto.", []),
            ("extra", "Reservei um rosto.", [decision("o1", .replace), decision("o2", .replace)]),
            ("unknown", "Reservei um rosto.", [decision("unknown", .replace)]),
            ("inconsistent", "rosto e rosto", [decision("o2", .replace), decision("o1", .replace)]),
            ("mixed", "rosto e rosto", [
                decision("o1", .replace), decision("o2", .replace, confidence: 0.89)
            ])
        ]
        for row in rows {
            let provider = ResolverDecisionProviderStub(row.2)
            let item = fixture(provider: provider)
            let input = row.1
            let output = await item.0.resolve(request(input, store: item.1, policy: item.2))
            XCTAssertEqual(output, input, row.0)
        }
    }

    func testResolverDeadlineReturnsWithoutAwaitingLateProvider() async {
        for milliseconds in [899, 900, 901] {
            let provider = SuspendedResolverProvider()
            let time = ManualContextualTime()
            let item = fixture(provider: provider, time: time)
            let input = "Reservei um rosto."
            let task = Task { await item.0.resolve(request(input, store: item.1, policy: item.2)) }
            await provider.waitForRequest()
            time.advance(milliseconds: Int64(milliseconds))
            if milliseconds == 899 {
                await provider.resume(.init(
                    decisions: [decision("o1", .replace)], resolvedModel: "on-time",
                    inputTokens: nil, outputTokens: nil, costUSD: nil
                ))
            }
            let output = await task.value
            XCTAssertEqual(
                output,
                milliseconds == 899 ? "Reservei um Hostel." : input,
                "deadline-\(milliseconds)"
            )
            XCTAssertEqual(time.now().offset, .milliseconds(milliseconds), "deadline-\(milliseconds)")
            if milliseconds >= 900 {
                await provider.resume(.init(
                    decisions: [decision("o1", .replace)], resolvedModel: "late",
                    inputTokens: nil, outputTokens: nil, costUSD: nil
                ))
            }
        }

        let provider = SuspendedResolverProvider()
        let time = ManualContextualTime()
        let item = fixture(provider: provider, time: time)
        let input = "Reservei um rosto."
        let task = Task { await item.0.resolve(request(input, store: item.1, policy: item.2)) }
        await provider.waitForRequest()
        time.advance(milliseconds: 900)
        let original = await task.value
        await provider.resume(.init(
            decisions: [decision("o1", .replace)], resolvedModel: "noncooperative-late",
            inputTokens: nil, outputTokens: nil, costUSD: nil
        ))
        XCTAssertEqual(original, input, "noncooperative-late")
    }

    func testResolverKeepsResponseThatArrivedBeforeDeadline() async {
        let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let time = ManualContextualTime()
        var generationReads = 0
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections/v1.json")
        let store = ContextualCorrectionStore(fileURL: file)
        XCTAssertTrue(store.save(example()).isSuccess)
        let policy = ContextualCorrectionPolicy()
        let resolver = ContextualCorrectionResolver(
            store: store,
            policy: policy,
            provider: provider,
            storeGeneration: {
                generationReads += 1
                if generationReads == 2 { time.advance(milliseconds: 901) }
                return store.generation
            },
            time: time
        )

        let output = await resolver.resolve(request("Reservei um rosto.", store: store, policy: policy))

        XCTAssertEqual(output, "Reservei um Hostel.")
        XCTAssertEqual(time.now().offset, .milliseconds(901))
    }

    func testResolverRejectsStoreGenerationChangedDuringSuspension() async {
        let provider = SuspendedResolverProvider()
        let item = fixture(provider: provider)
        let input = "Reservei um rosto."
        let task = Task { await item.0.resolve(request(input, store: item.1, policy: item.2)) }
        await provider.waitForRequest()
        XCTAssertTrue(item.1.save(example(index: 9, sentence: "Vi um rosto no espelho.")).isSuccess)
        await provider.resume(.init(
            decisions: [decision("o1", .replace)], resolvedModel: "fixture",
            inputTokens: nil, outputTokens: nil, costUSD: nil
        ))
        let output = await task.value
        XCTAssertEqual(output, input)
    }
}

struct DecisionsStreamingSnapshot: Equatable, Sendable {
    let deliveredChunkCount: Int
    let cancelCount: Int
    let capturedRequest: URLRequest?
}

private final class LockedInteger: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    func read() -> Int { lock.withLock { value } }
}

final class DecisionsStreamingTransportStub: DecisionsStreamingTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let statusCode: Int
    private let chunks: [Data]
    private let terminalError: Error?
    private let ignoresTransportLimit: Bool
    private var index = 0
    private var deliveredChunkCount = 0
    private var cancelCount = 0
    private var cancelled = false
    private var acceptedBytes = 0
    private var capturedRequest: URLRequest?

    init(
        statusCode: Int = 200,
        chunks: [Data],
        terminalError: Error? = nil,
        ignoresTransportLimit: Bool = false
    ) {
        self.statusCode = statusCode
        self.chunks = chunks
        self.terminalError = terminalError
        self.ignoresTransportLimit = ignoresTransportLimit
    }

    func open(
        _ request: URLRequest,
        maximumResponseBytes: Int,
        deadline: ContextualInstant
    ) async throws -> DecisionsResponseStream {
        lock.withLock { capturedRequest = request }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: statusCode,
            httpVersion: "HTTP/1.1", headerFields: nil
        )!
        return .init(
            response: response,
            nextChunk: { [weak self] in
                guard let self else { return nil }
                return try self.lock.withLock {
                    guard !self.cancelled else { return nil }
                    if self.index == self.chunks.count {
                        if let terminalError = self.terminalError { throw terminalError }
                        return nil
                    }
                    let chunk = self.chunks[self.index]
                    if !self.ignoresTransportLimit,
                       self.acceptedBytes > maximumResponseBytes - chunk.count {
                        self.cancelled = true
                        self.cancelCount += 1
                        throw OpenRouterDecisionsError.responseTooLarge
                    }
                    self.index += 1
                    self.acceptedBytes += chunk.count
                    self.deliveredChunkCount += 1
                    return chunk
                }
            },
            cancel: { [weak self] in
                guard let self else { return }
                self.lock.withLock {
                    guard !self.cancelled else { return }
                    self.cancelled = true
                    self.cancelCount += 1
                }
            }
        )
    }

    func snapshot() -> DecisionsStreamingSnapshot {
        lock.withLock {
            .init(
                deliveredChunkCount: deliveredChunkCount,
                cancelCount: cancelCount,
                capturedRequest: capturedRequest
            )
        }
    }
}

@MainActor
final class ContextualTransportCorpusTests: XCTestCase {
    private func occurrence(in sentence: String = "Reservei um rosto.") -> ContextualCorrectionOccurrence {
        .init(
            questionID: "o1",
            heard: "rosto",
            canonical: "Hostel",
            ordinal: 1,
            range: sentence.range(of: "rosto")!
        )
    }

    private var officialResponse: Data {
        Data(#"{"model":"typesafe/jev-1.14-20261014","answers":{"o1":{"type":"choice","choice":"replace_1","probabilities":{"keep_original":0.01,"replace_1":0.99},"confidence":0.98}},"usage":{"input_tokens":357,"output_tokens":38,"cost":0.000014994},"id":"synthetic-id","provider":"TypeSafe"}"#.utf8)
    }

    func testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture() throws {
        let sentence = "Reservei um rosto."
        let dto = OpenRouterDecisionsClient.requestDTO(
            sentence: sentence,
            language: "pt",
            occurrences: [occurrence(in: sentence)]
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(dto)) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), Set(["model", "state", "questions"]))
        XCTAssertEqual(object["model"] as? String, "typesafe/jev-1.14")
        let state = try XCTUnwrap(object["state"] as? [String: Any])
        XCTAssertEqual(Set(state.keys), Set(["language", "text", "occurrences"]))
        let encodedOccurrence = try XCTUnwrap((state["occurrences"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(encodedOccurrence.keys), Set(["heard", "canonical", "ordinal"]))
        let questions = try XCTUnwrap(object["questions"] as? [String: [String: Any]])
        XCTAssertEqual(Set(questions.keys), ["o1"])
        XCTAssertEqual(Set(try XCTUnwrap(questions["o1"]?["criteria"] as? [String: String]).keys),
                       Set(["keep_original", "replace_1"]))

        let receipt = try OpenRouterDecisionsClient.receipt(
            from: officialResponse,
            occurrences: [occurrence(in: sentence)]
        )
        XCTAssertEqual(receipt.resolvedModel, "typesafe/jev-1.14-20261014")
        XCTAssertEqual(receipt.decisions.first?.choice, .replace)
        XCTAssertEqual(receipt.decisions.first?.chosenProbability, 0.99)
        XCTAssertEqual(receipt.decisions.first?.runnerUpProbability, 0.01)
        XCTAssertEqual(receipt.decisions.first?.confidence, 0.98)
        XCTAssertEqual(receipt.inputTokens, 357)
        XCTAssertEqual(receipt.outputTokens, 38)
        XCTAssertEqual(receipt.costUSD, Decimal(string: "0.000014994"))
        XCTAssertEqual(receipt.providerRequestID, "synthetic-id")
    }

    func testDecisionsRequestPayloadAccepts4095And4096BytesAndRejects4097() throws {
        let baseSentence = "rosto"
        let base = try OpenRouterDecisionsClient.requestBody(
            sentence: baseSentence,
            language: "pt",
            occurrences: [occurrence(in: baseSentence)]
        ).count
        for target in [4_095, 4_096] {
            let sentence = baseSentence + String(repeating: "a", count: target - base)
            let body = try OpenRouterDecisionsClient.requestBody(
                sentence: sentence,
                language: "pt",
                occurrences: [occurrence(in: sentence)]
            )
            XCTAssertEqual(body.count, target)
        }
        let rejected = baseSentence + String(repeating: "a", count: 4_097 - base)
        XCTAssertThrowsError(try OpenRouterDecisionsClient.requestBody(
            sentence: rejected,
            language: "pt",
            occurrences: [occurrence(in: rejected)]
        )) { error in
            XCTAssertEqual(error as? OpenRouterDecisionsError, .requestTooLarge)
        }
    }

    func testOpenRouterCredentialRejectsMaskedAndMalformedValues() {
        let valid = "sk-or-v1-" + String(repeating: "a", count: 64)
        XCTAssertTrue(OpenRouterCredential.isValid(valid))
        for invalid in [
            "",
            "candidate",
            "sk-or-v1-" + String(repeating: "a", count: 39),
            "sk-or-v1-" + String(repeating: "a", count: 65),
            "sk-or-v1-" + String(repeating: "g", count: 64),
            valid + " ",
            String(repeating: "•", count: 148)
        ] {
            XCTAssertFalse(OpenRouterCredential.isValid(invalid), invalid)
        }
    }

    func testTransportRegistryIsolatesCancelledOldAndNewRequestsWithSameTaskIdentifier() {
        let oldSession = NSObject()
        let newSession = NSObject()
        let oldCancellations = LockedInteger()
        let newCancellations = LockedInteger()
        let old = DecisionsDelegateState(maximumResponseBytes: 8) { oldCancellations.increment() }
        let new = DecisionsDelegateState(maximumResponseBytes: 8) { newCancellations.increment() }
        let registry = DecisionsTransportContextRegistry<DecisionsDelegateState>()

        registry.insert(old, session: oldSession, taskIdentifier: 1)
        registry.insert(new, session: newSession, taskIdentifier: 1)
        XCTAssertTrue(registry.remove(session: oldSession, taskIdentifier: 1) === old)
        old.cancel()
        registry.lookup(session: newSession, taskIdentifier: 1)?.receive(Data([1, 2, 3]))
        XCTAssertNil(registry.lookup(session: oldSession, taskIdentifier: 1))
        XCTAssertTrue(registry.lookup(session: newSession, taskIdentifier: 1) === new)
        XCTAssertEqual(old.snapshot(), .init(acceptedBytes: 0, queuedChunkCount: 0, cancelCount: 1))
        XCTAssertEqual(new.snapshot(), .init(acceptedBytes: 3, queuedChunkCount: 1, cancelCount: 0))
        XCTAssertEqual(oldCancellations.read(), 1)
        XCTAssertEqual(newCancellations.read(), 0)
    }

    func testRevisionCandidateValidationProtectsNumbersNegationsAndIdentifiers() {
        func example(_ heard: String, _ canonical: String) -> ContextualCorrectionExample {
            .init(
                id: UUID(), language: "pt", heard: heard, canonical: canonical,
                sentence: "Confirme \(heard).", occurrenceOrdinal: 1
            )
        }
        XCTAssertNil(ContextualCorrectionResolver.validatedDecisionInput(
            examples: [example("10", "100")], text: "Confirme 10.", language: "pt"
        ))
        XCTAssertNil(ContextualCorrectionResolver.validatedDecisionInput(
            examples: [example("não", "agora")], text: "Confirme não.", language: "pt"
        ))
        XCTAssertNil(ContextualCorrectionResolver.validatedDecisionInput(
            examples: [example("a/b", "ab")], text: "Confirme a/b.", language: "pt"
        ))
    }

    func testURLSessionDelegateStateCancelsBeforeQueueingByte65537() async throws {
        let cancellations = LockedInteger()
        let state = DecisionsDelegateState(maximumResponseBytes: 65_536) { cancellations.increment() }
        state.receive(Data(repeating: 0, count: 32_768))
        state.receive(Data(repeating: 0, count: 32_768))
        state.receive(Data([0]))
        state.receive(Data([1]))
        let snapshot = state.snapshot()
        XCTAssertEqual(snapshot.acceptedBytes, 65_536)
        XCTAssertEqual(snapshot.queuedChunkCount, 2)
        XCTAssertEqual(snapshot.cancelCount, 1)
        XCTAssertEqual(cancellations.read(), 1)
        let first = try await state.nextChunk()
        let second = try await state.nextChunk()
        XCTAssertEqual(first?.count, 32_768)
        XCTAssertEqual(second?.count, 32_768)
        do {
            _ = try await state.nextChunk()
            XCTFail("Expected responseTooLarge")
        } catch {
            XCTAssertEqual(error as? OpenRouterDecisionsError, .responseTooLarge)
        }
    }

    func testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB() async {
        for acceptedSize in [65_535, 65_536] {
            let padding = Data(repeating: 0x20, count: acceptedSize - officialResponse.count)
            let acceptedTransport = DecisionsStreamingTransportStub(
                chunks: [officialResponse, padding]
            )
            let acceptedClient = OpenRouterDecisionsClient(
                transport: acceptedTransport,
                credential: { "test-key" }
            )
            do {
                let receipt = try await acceptedClient.decide(
                    sentence: "Reservei um rosto.", language: "pt",
                    occurrences: [occurrence()], deadline: .init(offset: .milliseconds(900))
                )
                XCTAssertEqual(receipt.decisions.first?.choice, .replace, "bytes-\(acceptedSize)")
            } catch {
                XCTFail("bytes-\(acceptedSize): \(error)")
            }
        }

        let transport = DecisionsStreamingTransportStub(
            chunks: [
                Data(repeating: 0x20, count: 32_768),
                Data(repeating: 0x20, count: 32_768),
                Data([0x20]),
                Data(#"{"must":"not be consumed"}"#.utf8)
            ],
            ignoresTransportLimit: true
        )
        let client = OpenRouterDecisionsClient(transport: transport, credential: { "test-key" })
        do {
            _ = try await client.decide(
                sentence: "Reservei um rosto.",
                language: "pt",
                occurrences: [occurrence()],
                deadline: .init(offset: .milliseconds(900))
            )
            XCTFail("Expected responseTooLarge")
        } catch {
            XCTAssertEqual(error as? OpenRouterDecisionsError, .responseTooLarge)
        }
        let snapshot = transport.snapshot()
        XCTAssertEqual(snapshot.deliveredChunkCount, 3)
        XCTAssertEqual(snapshot.cancelCount, 1)
    }

    func testDecisionsClientReturnsTypedReceiptFromSingleEnvelope() async throws {
        let transport = DecisionsStreamingTransportStub(chunks: [officialResponse])
        let client = OpenRouterDecisionsClient(transport: transport, credential: { "test-key" })
        let receipt = try await client.decide(
            sentence: "Reservei um rosto.",
            language: "pt",
            occurrences: [occurrence()],
            deadline: .init(offset: .milliseconds(900))
        )
        XCTAssertEqual(receipt.decisions.count, 1)
        XCTAssertEqual(receipt.resolvedModel, "typesafe/jev-1.14-20261014")
        XCTAssertEqual(receipt.inputTokens, 357)
        XCTAssertEqual(receipt.outputTokens, 38)
        XCTAssertEqual(receipt.costUSD, Decimal(string: "0.000014994"))
    }

    func testDecisionsClientRejectsStatusRedirectMalformedAndPrivatePayloadFields() async throws {
        for status in [401, 402, 403, 429, 500, 503] {
            let transport = DecisionsStreamingTransportStub(statusCode: status, chunks: [])
            let client = OpenRouterDecisionsClient(transport: transport, credential: { "test-key" })
            do {
                _ = try await client.decide(
                    sentence: "Reservei um rosto.", language: "pt",
                    occurrences: [occurrence()], deadline: .init(offset: .milliseconds(900))
                )
                XCTFail("Expected status \(status)")
            } catch {
                XCTAssertEqual(error as? OpenRouterDecisionsError, .invalidStatus(status))
            }
        }
        for row in [
            ("redirect", DecisionsStreamingTransportStub(statusCode: 302, chunks: []), OpenRouterDecisionsError.redirected),
            ("offline", DecisionsStreamingTransportStub(chunks: [], terminalError: URLError(.notConnectedToInternet)), .transportUnavailable),
            ("timeout", DecisionsStreamingTransportStub(chunks: [], terminalError: OpenRouterDecisionsError.timedOut), .timedOut),
            ("truncated", DecisionsStreamingTransportStub(chunks: [Data(#"{"model":"typesafe/jev-1.14""#.utf8)]), .malformedResponse)
        ] {
            let client = OpenRouterDecisionsClient(transport: row.1, credential: { "test-key" })
            do {
                _ = try await client.decide(
                    sentence: "Reservei um rosto.", language: "pt",
                    occurrences: [occurrence()], deadline: .init(offset: .milliseconds(900))
                )
                XCTFail("Expected \(row.0)")
            } catch {
                XCTAssertEqual(error as? OpenRouterDecisionsError, row.2, row.0)
            }
        }
        let malformed = DecisionsStreamingTransportStub(chunks: [Data("{}".utf8)])
        let client = OpenRouterDecisionsClient(transport: malformed, credential: { "test-key" })
        do {
            _ = try await client.decide(
                sentence: "Reservei um rosto.", language: "pt",
                occurrences: [occurrence()], deadline: .init(offset: .milliseconds(900))
            )
            XCTFail("Expected malformedResponse")
        } catch {
            XCTAssertEqual(error as? OpenRouterDecisionsError, .malformedResponse)
        }
        let request = try XCTUnwrap(malformed.snapshot().capturedRequest)
        XCTAssertEqual(request.url, OpenRouterDecisionsClient.endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)!
        for forbidden in ["history", "audio", "clipboard", "application", "attempt", "test-key"] {
            XCTAssertFalse(body.localizedCaseInsensitiveContains(forbidden), forbidden)
        }
    }
}

private enum ContextualCorpusFamily: String, Codable { case calibration, evaluation }
private enum ContextualCorpusGroup: String, Codable {
    case correctOriginal = "correct_original"
    case supportedCorrection = "supported_correction"
    case ambiguous
    case mixedUnicode = "mixed_unicode"
    case securityLifecycle = "security_lifecycle"
}
private enum ContextualCorpusOutcomeKind: String, Codable {
    case decisions, offline, timeout, malformed, stale, ineligible
}
private enum ContextualCorpusChoice: String, Codable { case keepOriginal = "keep_original", replace = "replace_1" }

private struct ProactiveContextFixture: Decodable {
    struct Token: Decodable {
        let text: String
        let probability: Float
    }

    struct Alternative: Decodable {
        let text: String
        let logit: Float
    }

    struct Row: Decodable {
        let id: String
        let semanticKey: String
        let partition: String
        let family: String
        let language: String
        let recognizedText: String
        let token: Token
        let alternatives: [Alternative]
        let vocabulary: [String]
        let expectedChoice: String
        let expectedText: String
        let protectedSemantics: String
    }

    let schemaVersion: Int
    let corpusVersion: String
    let provenance: String
    let language: String
    let frozenSHA256: String
    let thresholds: ProactiveCandidateThresholds
    var calibration: [Row]
    var evaluation: [Row]
    var controls: [Row]

    static let fileSHA256 = "563e70806d2d980767943e49a0243d27b90755ccb7256be0494ce811785975b4"

    static func load(bundle: Bundle) throws -> (fixture: Self, data: Data) {
        let url = try XCTUnwrap(bundle.url(forResource: "proactive-context-guidance", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return (try JSONDecoder().decode(Self.self, from: data), data)
    }

    func calibrationThresholds() -> ProactiveCandidateThresholds? {
        calibration.isEmpty ? nil : thresholds
    }

    func validate() -> Bool {
        let rows = calibration + evaluation + controls
        guard schemaVersion == 1,
              corpusVersion == "2026-10-22.1",
              provenance == "synthetic_invented_no_personal_dictation",
              language == "pt-BR",
              frozenSHA256.count == 64,
              calibration.count >= 15,
              evaluation.count >= 60,
              controls.count >= 30,
              Set(evaluation.map(\.family)).count >= 15,
              Set(rows.map(\.id)).count == rows.count,
              Set(rows.map(\.semanticKey)).count == rows.count,
              thresholds.tokenProbability.isFinite,
              (0...1).contains(thresholds.tokenProbability),
              thresholds.maximumLogitGap.isFinite,
              thresholds.maximumLogitGap >= 0,
              thresholds.minimumVocabularySimilarity.isFinite,
              (0...1).contains(thresholds.minimumVocabularySimilarity) else { return false }

        for (partition, partitionRows) in [
            ("calibration", calibration),
            ("evaluation", evaluation),
            ("controls", controls)
        ] {
            for row in partitionRows {
                guard row.partition == partition,
                      row.language == "pt",
                      !row.id.isEmpty,
                      !row.semanticKey.isEmpty,
                      !row.family.isEmpty,
                      !row.recognizedText.isEmpty,
                      !row.token.text.isEmpty,
                      row.token.probability.isFinite,
                      (0...1).contains(row.token.probability),
                      row.recognizedText.localizedCaseInsensitiveContains(row.token.text),
                      (1...3).contains(row.alternatives.count),
                      row.alternatives.allSatisfy({ !$0.text.isEmpty && $0.logit.isFinite }),
                      !row.vocabulary.isEmpty,
                      ["keep_original", "replace_1", "replace_2", "replace_3"].contains(row.expectedChoice),
                      !row.expectedText.isEmpty,
                      !row.protectedSemantics.isEmpty else { return false }
            }
        }
        return true
    }
}

private struct ProactiveEvaluationReport: Equatable {
    let baselineErrors: Int
    let currentErrors: Int
    let unauthorizedChanges: Int
    let controlRegressions: Int
    let coveredFamilies: Int
    let acousticCandidates: Int
    let vocabularyCandidates: Int
    let fallbackCount: Int
    let partitionSHA256: String
}

private enum ProactiveEvaluationRunner {
    static func run(_ fixture: ProactiveContextFixture) -> ProactiveEvaluationReport {
        var baselineErrors = 0
        var currentErrors = 0
        var unauthorizedChanges = 0
        var controlRegressions = 0
        var acousticCandidates = 0
        var vocabularyCandidates = 0
        var fallbackCount = 0

        for row in fixture.evaluation + fixture.controls {
            if row.recognizedText != row.expectedText { baselineErrors += 1 }
            let evidence = WhisperTokenEvidence(
                tokenID: 1,
                text: row.token.text,
                probability: row.token.probability,
                alternatives: row.alternatives.enumerated().map { index, alternative in
                    .init(tokenID: Int32(index + 2), text: alternative.text, logit: alternative.logit)
                }
            )
            let candidate = ProactiveContextualCandidateGenerator.candidate(
                text: row.recognizedText,
                language: row.language,
                tokenEvidence: [evidence],
                glossaryTerms: row.vocabulary,
                examples: [],
                thresholds: .frozen
            )
            switch candidate?.alternatives.first?.source {
            case .acoustic: acousticCandidates += 1
            case .vocabulary: vocabularyCandidates += 1
            default: if candidate == nil { fallbackCount += 1 }
            }

            var output = row.recognizedText
            if row.expectedChoice != ContextualDecisionChoice.keepOriginal.rawValue,
               let candidate,
               let index = replacementIndex(
                for: .init(rawValue: row.expectedChoice),
                optionCount: candidate.alternatives.count
               ) {
                output.replaceSubrange(candidate.range, with: candidate.alternatives[index].value)
            }
            if output != row.expectedText { currentErrors += 1 }
            if row.expectedChoice == ContextualDecisionChoice.keepOriginal.rawValue,
               output != row.recognizedText { unauthorizedChanges += 1 }
            if row.partition == "controls", output != row.expectedText { controlRegressions += 1 }
        }

        return .init(
            baselineErrors: baselineErrors,
            currentErrors: currentErrors,
            unauthorizedChanges: unauthorizedChanges,
            controlRegressions: controlRegressions,
            coveredFamilies: Set(fixture.evaluation.map(\.family)).count,
            acousticCandidates: acousticCandidates,
            vocabularyCandidates: vocabularyCandidates,
            fallbackCount: fallbackCount,
            partitionSHA256: ProactiveContextFixture.fileSHA256
        )
    }
}

private struct ContinuousContextEventsFixture: Decodable {
    struct Event: Decodable {
        let revision: Int
        let logicalOffsetMilliseconds: Int
        let text: String
        let isFinal: Bool
    }

    struct Case: Decodable {
        let id: String
        let category: String
        let noChangeRequired: Bool
        let sourceEvents: [Event]
        let expectedCompletedRecordingText: String
        let expectedFinalReferenceText: String
        let allowedContextualAlternatives: [String]
    }

    let schemaVersion: Int
    let corpusVersion: String
    let language: String
    let provenance: String
    let evidenceScope: String
    let eventTimeBasis: String
    let containsAudioOrPCM: Bool
    let cases: [Case]

    static let frozenSHA256 = "46c5794007c61b5135374cc275f01d5a012838807c28df6624d77fd556dd9415"
    static let requiredCategories: Set<String> = [
        "homophone", "technical_term", "names_identifiers", "negation", "numbers",
        "code_switching", "unicode", "pauses", "retractions", "repeated_occurrences",
        "topic_changes"
    ]

    static func load(bundle: Bundle) throws -> (fixture: Self, data: Data, url: URL) {
        let url = try XCTUnwrap(bundle.url(forResource: "continuous-context-events", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return (try JSONDecoder().decode(Self.self, from: data), data, url)
    }

    func validate() -> Bool {
        let contextualCases = cases.filter { !$0.noChangeRequired }
        let controls = cases.filter(\.noChangeRequired)
        guard schemaVersion == 1,
              corpusVersion == "2026-10-21.1",
              language == "pt-BR",
              provenance == "synthetic_invented",
              evidenceScope == "semantic_orchestration_only",
              eventTimeBasis == "simulated_logical_milliseconds",
              !containsAudioOrPCM,
              contextualCases.count >= 40,
              controls.count >= 10,
              Set(cases.map(\.id)).count == cases.count,
              Set(cases.map(\.category)).isSuperset(of: Self.requiredCategories) else { return false }

        for item in cases {
            guard !item.sourceEvents.isEmpty,
                  !item.expectedCompletedRecordingText.isEmpty,
                  !item.expectedFinalReferenceText.isEmpty,
                  !item.allowedContextualAlternatives.isEmpty,
                  item.allowedContextualAlternatives.contains(item.expectedFinalReferenceText),
                  item.sourceEvents.last?.isFinal == true,
                  item.sourceEvents.last?.text == item.expectedCompletedRecordingText else { return false }

            for (index, event) in item.sourceEvents.enumerated() {
                guard event.revision == index + 1,
                      event.logicalOffsetMilliseconds >= 0,
                      !event.text.isEmpty else { return false }
                if index > 0 {
                    guard event.logicalOffsetMilliseconds > item.sourceEvents[index - 1].logicalOffsetMilliseconds else {
                        return false
                    }
                }
            }

            if item.noChangeRequired {
                guard item.expectedFinalReferenceText == item.expectedCompletedRecordingText,
                      item.allowedContextualAlternatives == [item.expectedCompletedRecordingText] else { return false }
            }
        }
        return true
    }
}

private struct ContinuousContextCorpusTrace: Codable, Equatable {
    let caseID: String
    let category: String
    let revisionCount: Int
    let noChangeRequired: Bool
    let baselineMatchesReference: Bool
    let mockedContextualMatchesReference: Bool
    let contextualOutcome: String
    let maximumScheduledWorkCount: Int
    let simulatedDecisionOffsetMilliseconds: Int
}

private struct ContinuousContextCorpusReport: Codable, Equatable {
    let schemaVersion: Int
    let corpusVersion: String
    let corpusSHA256: String
    let generatedBy: String
    let evidenceScope: String
    let timeBasis: String
    let remoteAuthority: String
    let personalRemoteRequestCount: Int
    let totalCases: Int
    let contextualCases: Int
    let controls: Int
    let baselineErrors: Int
    let mockedContextualErrors: Int
    let improvements: Int
    let regressions: Int
    let controlMeaningChanges: Int
    let timeoutFallbackErrors: Int
    let featureOffErrors: Int
    let maximumScheduledWorkCount: Int
    let unsupportedProofClaims: [String]
    let traces: [ContinuousContextCorpusTrace]
}

private enum ContinuousContextCorpusRunnerError: Error {
    case invalidFixture
    case invalidEvent
    case missingWork
    case rejectedMockResult
}

private final class ContinuousContextCorpusClock: @unchecked Sendable {
    private let lock = NSLock()
    private var seconds = 0.0

    func now() -> TimeInterval { lock.withLock { seconds } }
    func set(milliseconds: Int) { lock.withLock { seconds = Double(milliseconds) / 1_000 } }
    func set(seconds: TimeInterval) { lock.withLock { self.seconds = seconds } }
}

private struct ContinuousContextCorpusEvent: ContinuousContextRollingEvent {
    let snapshotID: UInt64
    let sampleRange: Range<Int64>
    let capturedAt: TimeInterval
    let candidateAt: TimeInterval
    let text: String
    let isStale = false
}

private enum ContinuousContextCorpusRunner {
    private enum Mode {
        case localCandidate
        case mockedContextual
        case timeoutFallback
        case featureOff
    }

    private struct Result {
        let output: String
        let outcome: String
        let maximumScheduledWorkCount: Int
        let simulatedDecisionOffsetMilliseconds: Int
    }

    static func run(bundle: Bundle) throws -> ContinuousContextCorpusReport {
        let loaded = try ContinuousContextEventsFixture.load(bundle: bundle)
        guard loaded.fixture.validate(),
              SHA256.hash(data: loaded.data).map({ String(format: "%02x", $0) }).joined()
                == ContinuousContextEventsFixture.frozenSHA256 else {
            throw ContinuousContextCorpusRunnerError.invalidFixture
        }

        var traces: [ContinuousContextCorpusTrace] = []
        var baselineErrors = 0
        var mockedErrors = 0
        var improvements = 0
        var regressions = 0
        var controlMeaningChanges = 0
        var timeoutErrors = 0
        var featureOffErrors = 0
        var maximumScheduledWorkCount = 0

        for item in loaded.fixture.cases.sorted(by: { $0.id < $1.id }) {
            let baseline = try execute(item, mode: .localCandidate)
            let mocked = try execute(item, mode: .mockedContextual)
            let timeout = try execute(item, mode: .timeoutFallback)
            let featureOff = try execute(item, mode: .featureOff)
            let baselineMatches = baseline.output == item.expectedFinalReferenceText
            let mockedMatches = mocked.output == item.expectedFinalReferenceText

            baselineErrors += baselineMatches ? 0 : 1
            mockedErrors += mockedMatches ? 0 : 1
            improvements += !baselineMatches && mockedMatches ? 1 : 0
            regressions += baselineMatches && !mockedMatches ? 1 : 0
            controlMeaningChanges += item.noChangeRequired && mocked.output != baseline.output ? 1 : 0
            timeoutErrors += timeout.output == item.expectedFinalReferenceText ? 0 : 1
            featureOffErrors += featureOff.output == item.expectedFinalReferenceText ? 0 : 1
            maximumScheduledWorkCount = max(
                maximumScheduledWorkCount,
                baseline.maximumScheduledWorkCount,
                mocked.maximumScheduledWorkCount,
                timeout.maximumScheduledWorkCount,
                featureOff.maximumScheduledWorkCount
            )
            traces.append(.init(
                caseID: item.id,
                category: item.category,
                revisionCount: item.sourceEvents.count,
                noChangeRequired: item.noChangeRequired,
                baselineMatchesReference: baselineMatches,
                mockedContextualMatchesReference: mockedMatches,
                contextualOutcome: mocked.outcome,
                maximumScheduledWorkCount: mocked.maximumScheduledWorkCount,
                simulatedDecisionOffsetMilliseconds: mocked.simulatedDecisionOffsetMilliseconds
            ))
        }

        let report = ContinuousContextCorpusReport(
            schemaVersion: 1,
            corpusVersion: loaded.fixture.corpusVersion,
            corpusSHA256: ContinuousContextEventsFixture.frozenSHA256,
            generatedBy: "WhisperKeyTests.ContinuousContextCorpusRunner/v1",
            evidenceScope: loaded.fixture.evidenceScope,
            timeBasis: loaded.fixture.eventTimeBasis,
            remoteAuthority: "closed",
            personalRemoteRequestCount: 0,
            totalCases: loaded.fixture.cases.count,
            contextualCases: loaded.fixture.cases.filter { !$0.noChangeRequired }.count,
            controls: loaded.fixture.cases.filter(\.noChangeRequired).count,
            baselineErrors: baselineErrors,
            mockedContextualErrors: mockedErrors,
            improvements: improvements,
            regressions: regressions,
            controlMeaningChanges: controlMeaningChanges,
            timeoutFallbackErrors: timeoutErrors,
            featureOffErrors: featureOffErrors,
            maximumScheduledWorkCount: maximumScheduledWorkCount,
            unsupportedProofClaims: [
                "acoustic_asr_accuracy",
                "capture_to_candidate_latency",
                "completed_wav_vs_rolling_asr",
                "cold_warm_hardware_latency",
                "cpu_memory_thermal"
            ],
            traces: traces
        )
        if let path = ProcessInfo.processInfo.environment["CONTINUOUS_CONTEXT_CORPUS_REPORT_PATH"] {
            try JSONEncoder.sorted.encode(report).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        return report
    }

    private static func execute(
        _ item: ContinuousContextEventsFixture.Case,
        mode: Mode
    ) throws -> Result {
        let clock = ContinuousContextCorpusClock()
        let session = ContinuousContextSession(now: { clock.now() })
        let attemptID = UUID(uuidString: "71000000-0000-0000-0000-000000000001")!
        guard session.start(attemptID: attemptID, language: "pt-BR") else {
            throw ContinuousContextCorpusRunnerError.invalidEvent
        }
        var maximumScheduledWorkCount = 0
        var finalEvent: ContinuousContextCorpusEvent?
        for source in item.sourceEvents {
            clock.set(milliseconds: source.logicalOffsetMilliseconds)
            let event = ContinuousContextCorpusEvent(
                snapshotID: UInt64(source.revision),
                sampleRange: 0..<Int64(source.revision * 100),
                capturedAt: clock.now(),
                candidateAt: clock.now(),
                text: source.text
            )
            guard session.ingest(event) != nil else {
                throw ContinuousContextCorpusRunnerError.invalidEvent
            }
            finalEvent = event
            maximumScheduledWorkCount = max(maximumScheduledWorkCount, session.scheduledWorkCount)
        }
        guard let finalEvent else { throw ContinuousContextCorpusRunnerError.invalidEvent }

        let output: String
        let outcome: String
        switch mode {
        case .mockedContextual:
            guard item.allowedContextualAlternatives.contains(item.expectedFinalReferenceText),
                  let work = session.takeNextWork() else {
                throw ContinuousContextCorpusRunnerError.missingWork
            }
            let changed = work.sourceText != item.expectedFinalReferenceText
            let result = RevisionBoundContextualResult(
                identity: work.identity(policyGeneration: 1, storeGeneration: 1),
                originalText: work.sourceText,
                text: item.expectedFinalReferenceText,
                outcome: .init(
                    category: changed ? .replaced : .kept,
                    decisions: [.init(
                        questionID: "fixture-\(item.id)",
                        choice: changed ? .replace : .keepOriginal,
                        selectedProbability: 0.99,
                        runnerUpProbability: 0.01
                    )]
                )
            )
            guard session.applyContextualResult(result, for: work) else {
                throw ContinuousContextCorpusRunnerError.rejectedMockResult
            }
            output = session.contextualPreviewText ?? work.sourceText
            outcome = changed ? "replaced" : "kept"
        case .timeoutFallback:
            guard let work = session.takeNextWork() else {
                throw ContinuousContextCorpusRunnerError.missingWork
            }
            clock.set(seconds: work.expiresAt)
            let fallback = RevisionBoundContextualResult(
                identity: work.identity(policyGeneration: 1, storeGeneration: 1),
                originalText: work.sourceText,
                text: work.sourceText,
                outcome: .init(category: .abstained, decisions: [])
            )
            guard !session.applyContextualResult(fallback, for: work) else {
                throw ContinuousContextCorpusRunnerError.rejectedMockResult
            }
            output = work.sourceText
            outcome = "timed_out_keep_original"
        case .localCandidate:
            output = finalEvent.text
            outcome = "local_candidate"
        case .featureOff:
            session.cancel()
            output = finalEvent.text
            outcome = "feature_off_keep_original"
        }

        maximumScheduledWorkCount = max(maximumScheduledWorkCount, session.scheduledWorkCount)
        return .init(
            output: output,
            outcome: outcome,
            maximumScheduledWorkCount: maximumScheduledWorkCount,
            simulatedDecisionOffsetMilliseconds: item.sourceEvents.last?.logicalOffsetMilliseconds ?? 0
        )
    }
}

private struct ContextualCorpusFixture: Decodable {
    struct Learning: Codable {
        let id: String
        let pairID: String
        let language: String
        let sentence: String
        let heard: String
        let canonical: String
        let ordinal: Int
    }
    struct Answer: Codable {
        let ordinal: Int
        let choice: ContextualCorpusChoice
        let confidence: Double
        let chosenProbability: Double
        let runnerUpProbability: Double
    }
    struct Outcome: Codable {
        let kind: ContextualCorpusOutcomeKind
        let answers: [Answer]
    }
    struct Case: Codable {
        let id: String
        let pairID: String
        let learningExampleIDs: [String]
        let family: ContextualCorpusFamily
        let group: ContextualCorpusGroup
        let language: String
        let input: String
        let heard: String
        let canonical: String
        let ordinal: Int
        let expected: String
        let providerOutcome: Outcome
        let rationale: String
    }

    let schemaVersion: Int
    let corpusVersion: String
    let evaluationPositiveIDs: [String]
    let learningExamples: [Learning]
    var cases: [Case]
    let diagnosticFixture: SyntheticDiagnosticFixture

    static func load(bundle: Bundle = .main) throws -> Self {
        let url = try XCTUnwrap(bundle.url(forResource: "contextual-corrections", withExtension: "json"))
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func validate() -> Bool {
        guard schemaVersion == 1, cases.count == 100,
              Set(cases.map(\.id)).count == 100,
              Set(learningExamples.map(\.id)).count == learningExamples.count,
              diagnosticFixture.id == SyntheticDiagnosticFixture.id else { return false }
        let learningByID = Dictionary(uniqueKeysWithValues: learningExamples.map { ($0.id, $0) })
        let normalizedLearning = Set(learningExamples.map { Self.normalize($0.sentence) })
        var semanticKeys = Set<String>()
        var rationales = Set<String>()
        for item in cases {
            guard item.rationale.count >= 20,
                  !normalizedLearning.contains(Self.normalize(item.input)),
                  !item.learningExampleIDs.isEmpty,
                  item.learningExampleIDs.allSatisfy({ learningByID[$0]?.pairID == item.pairID }),
                  Self.wholeTermCount(item.heard, in: item.input) >= item.ordinal,
                  item.ordinal > 0 else { return false }
            let key = [item.pairID, item.family.rawValue, Self.normalize(item.input), Self.normalize(item.expected)]
                .joined(separator: "|")
            guard semanticKeys.insert(key).inserted,
                  rationales.insert(Self.normalize(item.rationale)).inserted else { return false }
        }
        let positives = cases.filter { evaluationPositiveIDs.contains($0.id) }
        guard positives.count == 20,
              Set(evaluationPositiveIDs).count == 20,
              positives.allSatisfy({
                  $0.family == .evaluation && $0.group == .supportedCorrection && $0.input != $0.expected
              }),
              cases.filter({ $0.group == .supportedCorrection }).count == 20 else { return false }
        return true
    }

    static func normalize(_ value: String) -> String {
        var normalized = value.precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "pt_BR"))
        normalized = normalized.replacingOccurrences(
            of: #"\b(caso|exemplo|variação|variacao|cenário|cenario)\s*\d*\b"#,
            with: " ", options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: #"\b\d+(º|ª|o|a)?\b"#, with: "<n>", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"[^\p{L}\p{N}<>]+"#, with: " ", options: .regularExpression)
        return normalized.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func wholeTermCount(_ term: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        )
        return regex?.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) ?? 0
    }
}

extension ContextualTransportCorpusTests {
    func testProactiveEvaluationImprovesWithoutControlRegressions() throws {
        let fixture = try ProactiveContextFixture.load(
            bundle: Bundle(for: ContextualTransportCorpusTests.self)
        ).fixture
        let first = ProactiveEvaluationRunner.run(fixture)
        let second = ProactiveEvaluationRunner.run(fixture)

        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first.baselineErrors, 0)
        XCTAssertLessThanOrEqual(
            first.currentErrors * 5,
            first.baselineErrors * 4,
            "Requires at least 20% relative error reduction"
        )
        XCTAssertEqual(first.unauthorizedChanges, 0)
        XCTAssertEqual(first.controlRegressions, 0)
        XCTAssertEqual(first.coveredFamilies, 15)
        XCTAssertEqual(first.partitionSHA256, ProactiveContextFixture.fileSHA256)
    }

    func testProactiveContextFixtureIsFrozenPartitionedAndValid() throws {
        let bundle = Bundle(for: ContextualTransportCorpusTests.self)
        let loaded = try ProactiveContextFixture.load(bundle: bundle)
        let rows = loaded.fixture.calibration + loaded.fixture.evaluation + loaded.fixture.controls

        XCTAssertTrue(loaded.fixture.validate())
        XCTAssertEqual(loaded.fixture.calibration.count, 15)
        XCTAssertEqual(loaded.fixture.evaluation.count, 60)
        XCTAssertEqual(loaded.fixture.controls.count, 30)
        XCTAssertEqual(Set(loaded.fixture.evaluation.map(\.family)).count, 15)
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
        XCTAssertEqual(Set(rows.map(\.semanticKey)).count, rows.count)
        XCTAssertEqual(
            SHA256.hash(data: loaded.data).map { String(format: "%02x", $0) }.joined(),
            ProactiveContextFixture.fileSHA256,
            "The proactive corpus changed. Re-plan and freeze a new baseline before implementation."
        )
    }

    func testProactiveThresholdsAcceptBoundaryAndRejectOutside() throws {
        let thresholds = try XCTUnwrap(
            ProactiveContextFixture.load(bundle: Bundle(for: ContextualTransportCorpusTests.self))
                .fixture.calibrationThresholds()
        )
        XCTAssertEqual(thresholds, .frozen)

        XCTAssertTrue(thresholds.accepts(
            tokenProbability: thresholds.tokenProbability,
            logitGap: thresholds.maximumLogitGap,
            vocabularySimilarity: thresholds.minimumVocabularySimilarity
        ))
        XCTAssertFalse(thresholds.accepts(
            tokenProbability: thresholds.tokenProbability.nextUp,
            logitGap: thresholds.maximumLogitGap,
            vocabularySimilarity: thresholds.minimumVocabularySimilarity
        ))
        XCTAssertFalse(thresholds.accepts(
            tokenProbability: thresholds.tokenProbability,
            logitGap: thresholds.maximumLogitGap.nextUp,
            vocabularySimilarity: thresholds.minimumVocabularySimilarity
        ))
        XCTAssertFalse(thresholds.accepts(
            tokenProbability: thresholds.tokenProbability,
            logitGap: thresholds.maximumLogitGap,
            vocabularySimilarity: thresholds.minimumVocabularySimilarity.nextDown
        ))
    }

    func testProactiveThresholdSelectionCannotReadEvaluationRows() throws {
        var fixture = try ProactiveContextFixture.load(
            bundle: Bundle(for: ContextualTransportCorpusTests.self)
        ).fixture
        let selected = fixture.calibrationThresholds()
        fixture.evaluation.removeAll()
        fixture.controls.removeAll()
        XCTAssertEqual(fixture.calibrationThresholds(), selected)
    }

    func testProactiveCandidateUsesLearnedThenAcousticThenVocabularyEvidence() throws {
        let thresholds = try XCTUnwrap(
            ProactiveContextFixture.load(bundle: Bundle(for: ContextualTransportCorpusTests.self))
                .fixture.calibrationThresholds()
        )
        let text = "Reservei uma cama no rosto."
        let acousticEvidence = [WhisperTokenEvidence(
            tokenID: 1,
            text: " rosto",
            probability: 0.40,
            alternatives: [
                .init(tokenID: 2, text: " Hostel", logit: 8),
                .init(tokenID: 3, text: " posto", logit: 7)
            ]
        )]
        let learned = ContextualCorrectionExample(
            id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
            sentence: text, occurrenceOrdinal: 1
        )

        let learnedCandidate = try XCTUnwrap(ProactiveContextualCandidateGenerator.candidate(
            text: text, language: "pt", tokenEvidence: [], glossaryTerms: [],
            examples: [learned], thresholds: thresholds
        ))
        XCTAssertEqual(learnedCandidate.alternatives.map(\.source), [.learned])

        let acousticCandidate = try XCTUnwrap(ProactiveContextualCandidateGenerator.candidate(
            text: text, language: "pt", tokenEvidence: acousticEvidence, glossaryTerms: ["Hostel"],
            examples: [], thresholds: thresholds
        ))
        XCTAssertEqual(acousticCandidate.alternatives.map(\.value), ["Hostel", "posto"])
        XCTAssertTrue(acousticCandidate.alternatives.allSatisfy { $0.source == .acoustic })

        let vocabularyEvidence = [WhisperTokenEvidence(
            tokenID: 1, text: " rosto", probability: 0.40, alternatives: []
        )]
        let vocabularyCandidate = try XCTUnwrap(ProactiveContextualCandidateGenerator.candidate(
            text: text, language: "pt-BR", tokenEvidence: vocabularyEvidence,
            glossaryTerms: ["Hostel"], examples: [], thresholds: thresholds
        ))
        XCTAssertEqual(vocabularyCandidate.canonical, "Hostel")
        XCTAssertEqual(vocabularyCandidate.alternatives.map(\.source), [.vocabulary])
    }

    func testProactiveCandidateRequiresLowConfidencePortugueseAndExactBinding() throws {
        let thresholds = try XCTUnwrap(
            ProactiveContextFixture.load(bundle: Bundle(for: ContextualTransportCorpusTests.self))
                .fixture.calibrationThresholds()
        )
        func candidate(text: String, language: String, probability: Float) -> ContextualCorrectionOccurrence? {
            ProactiveContextualCandidateGenerator.candidate(
                text: text,
                language: language,
                tokenEvidence: [.init(tokenID: 1, text: " rosto", probability: probability, alternatives: [])],
                glossaryTerms: ["Hostel"], examples: [], thresholds: thresholds
            )
        }

        XCTAssertNil(candidate(text: "Reservei no rosto.", language: "en", probability: 0.40))
        XCTAssertNotNil(candidate(text: "Reservei no rosto.", language: "pt", probability: 0.84))
        XCTAssertNil(candidate(text: "Reservei no rosto.", language: "pt", probability: 0.86))
        XCTAssertNil(candidate(text: "Reservei no rosto e lavei o rosto.", language: "pt", probability: 0.40))
        XCTAssertNil(candidate(text: "Reservei no posto.", language: "pt", probability: 0.40))
    }

    func testProactiveCandidateRejectsProtectedAndNonLexicalTerms() throws {
        let thresholds = try XCTUnwrap(
            ProactiveContextFixture.load(bundle: Bundle(for: ContextualTransportCorpusTests.self))
                .fixture.calibrationThresholds()
        )
        for term in ["123", "R$", "a@b.com", "https://a.com", "user_name", "não", "rosto!", "rosto�"] {
            let candidate = ProactiveContextualCandidateGenerator.candidate(
                text: "Teste \(term)", language: "pt",
                tokenEvidence: [.init(tokenID: 1, text: term, probability: 0.20, alternatives: [])],
                glossaryTerms: ["Hostel"], examples: [], thresholds: thresholds
            )
            XCTAssertNil(candidate, term)
        }
        let caseOnly = ProactiveContextualCandidateGenerator.candidate(
            text: "Teste rosto", language: "pt",
            tokenEvidence: [.init(tokenID: 1, text: "rosto", probability: 0.20, alternatives: [])],
            glossaryTerms: ["ROSTO"], examples: [], thresholds: thresholds
        )
        XCTAssertNil(caseOnly)
        XCTAssertNil(ProactiveContextualCandidateGenerator.candidate(
            text: "Teste rosto", language: "pt", tokenEvidence: [],
            glossaryTerms: ["Hostel"], examples: [], thresholds: thresholds
        ))
        XCTAssertNil(ProactiveContextualCandidateGenerator.candidate(
            text: "Teste rosto", language: "pt",
            tokenEvidence: [.init(tokenID: 1, text: "rosto", probability: 0.20, alternatives: [])],
            glossaryTerms: [], examples: [], thresholds: thresholds
        ))

        let deterministicTie = try XCTUnwrap(ProactiveContextualCandidateGenerator.candidate(
            text: "Teste mato", language: "pt",
            tokenEvidence: [.init(tokenID: 1, text: "mato", probability: 0.20, alternatives: [])],
            glossaryTerms: ["rato", "pato"], examples: [], thresholds: thresholds
        ))
        XCTAssertEqual(deterministicTie.canonical, "pato")
    }

    func testContinuousContextCorpusIsBundledFrozenAndSchemaValid() throws {
        let testBundle = Bundle(for: ContextualTransportCorpusTests.self)
        let loaded = try ContinuousContextEventsFixture.load(bundle: testBundle)

        XCTAssertTrue(loaded.url.path.contains("WhisperKeyTests.xctest/Contents/Resources"))
        XCTAssertTrue(loaded.fixture.validate())
        XCTAssertEqual(loaded.fixture.cases.filter { !$0.noChangeRequired }.count, 43)
        XCTAssertEqual(loaded.fixture.cases.filter(\.noChangeRequired).count, 10)
        XCTAssertEqual(
            SHA256.hash(data: loaded.data).map { String(format: "%02x", $0) }.joined(),
            ContinuousContextEventsFixture.frozenSHA256,
            "The pre-implementation corpus changed. Re-plan and freeze a new baseline before resuming implementation."
        )

        let appURL = try XCTUnwrap(Bundle.main.url(forResource: "continuous-context-events", withExtension: "json"))
        XCTAssertTrue(appURL.path.contains("Resenha.app/Contents/Resources"))
        XCTAssertEqual(try Data(contentsOf: appURL), loaded.data)
    }

    func testContinuousContextFrozenCorpusImprovesDeterministicOrchestrationWithoutControlRegressions() throws {
        let bundle = Bundle(for: ContextualTransportCorpusTests.self)
        let first = try ContinuousContextCorpusRunner.run(bundle: bundle)
        let second = try ContinuousContextCorpusRunner.run(bundle: bundle)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.corpusSHA256, ContinuousContextEventsFixture.frozenSHA256)
        XCTAssertEqual(first.totalCases, 53)
        XCTAssertEqual(first.contextualCases, 43)
        XCTAssertEqual(first.controls, 10)
        XCTAssertEqual(first.baselineErrors, 35)
        XCTAssertEqual(first.mockedContextualErrors, 0)
        XCTAssertEqual(first.improvements, 35)
        XCTAssertEqual(first.regressions, 0)
        XCTAssertEqual(first.controlMeaningChanges, 0)
        XCTAssertEqual(first.timeoutFallbackErrors, first.baselineErrors)
        XCTAssertEqual(first.featureOffErrors, first.baselineErrors)
        XCTAssertLessThanOrEqual(first.maximumScheduledWorkCount, 2)
        XCTAssertEqual(first.remoteAuthority, "closed")
        XCTAssertEqual(first.personalRemoteRequestCount, 0)
    }

    func testContinuousContextFrozenCorpusTraceIsSanitizedAndOrchestrationOnly() throws {
        let bundle = Bundle(for: ContextualTransportCorpusTests.self)
        let loaded = try ContinuousContextEventsFixture.load(bundle: bundle)
        let report = try ContinuousContextCorpusRunner.run(bundle: bundle)
        let encoded = try JSONEncoder.sorted.encode(report)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertEqual(report.evidenceScope, "semantic_orchestration_only")
        XCTAssertEqual(report.timeBasis, "simulated_logical_milliseconds")
        XCTAssertEqual(Set(report.traces.map(\.caseID)).count, loaded.fixture.cases.count)
        XCTAssertEqual(Set(report.traces.map(\.category)), ContinuousContextEventsFixture.requiredCategories)
        XCTAssertEqual(Set(report.unsupportedProofClaims), [
            "acoustic_asr_accuracy",
            "capture_to_candidate_latency",
            "completed_wav_vs_rolling_asr",
            "cold_warm_hardware_latency",
            "cpu_memory_thermal"
        ])
        for item in loaded.fixture.cases {
            XCTAssertFalse(json.contains(item.expectedCompletedRecordingText), item.id)
            XCTAssertFalse(json.contains(item.expectedFinalReferenceText), item.id)
            XCTAssertFalse(json.contains(item.sourceEvents[0].text), item.id)
        }
        for forbiddenKey in ["audio", "pcm", "transcript", "sourceText", "outputText", "sentence"] {
            XCTAssertFalse(json.localizedCaseInsensitiveContains("\"\(forbiddenKey)\""), forbiddenKey)
        }
    }

    func testContinuousContextCorpusQueueIsBoundedAndExpiredWorkFailsOpen() throws {
        let clock = ContinuousContextCorpusClock()
        let session = ContinuousContextSession(now: { clock.now() })
        XCTAssertTrue(session.start(attemptID: UUID(), language: "pt-BR"))

        for revision in 1...200 {
            clock.set(milliseconds: revision * 10)
            let event = ContinuousContextCorpusEvent(
                snapshotID: UInt64(revision),
                sampleRange: 0..<Int64(revision * 100),
                capturedAt: clock.now(),
                candidateAt: clock.now(),
                text: "fixture-revision-\(revision)"
            )
            XCTAssertNotNil(session.ingest(event))
            if revision == 1 { XCTAssertNotNil(session.takeNextWork()) }
            XCTAssertLessThanOrEqual(session.scheduledWorkCount, 2)
        }

        XCTAssertEqual(session.scheduledWorkCount, 2)
        clock.set(milliseconds: 2_500)
        XCTAssertNil(session.takeNextWork(), "An active item and latest-only pending item must not create extra work")
        session.cancel()
        XCTAssertEqual(session.scheduledWorkCount, 0)
        XCTAssertEqual(session.state, .cancelled)

        let expiryClock = ContinuousContextCorpusClock()
        let expirySession = ContinuousContextSession(now: { expiryClock.now() })
        XCTAssertTrue(expirySession.start(attemptID: UUID(), language: "pt-BR"))
        XCTAssertNotNil(expirySession.ingest(ContinuousContextCorpusEvent(
            snapshotID: 1,
            sampleRange: 0..<100,
            capturedAt: 0,
            candidateAt: 0,
            text: "fixture-timeout"
        )))
        let work = try XCTUnwrap(expirySession.takeNextWork())
        expiryClock.set(seconds: work.expiresAt)
        XCTAssertFalse(expirySession.completeWork(work))
        XCTAssertNil(expirySession.contextualPreviewText)
        XCTAssertEqual(expirySession.scheduledWorkCount, 0)
    }

    func testCorpusSchemaFreezesLearningEvaluationAndDiagnosticIDs() throws {
        let fixture = try ContextualCorpusFixture.load()
        XCTAssertTrue(fixture.validate())
        XCTAssertEqual(fixture.corpusVersion, "2026-10-20.1")
        XCTAssertEqual(fixture.learningExamples.count, 5)
        XCTAssertEqual(Set(fixture.cases.map(\.pairID)).count, 5)
        XCTAssertEqual(fixture.cases.filter { $0.group == .correctOriginal }.count, 30)
        XCTAssertEqual(fixture.cases.filter { $0.group == .supportedCorrection }.count, 20)
        XCTAssertEqual(fixture.cases.filter { $0.group == .ambiguous }.count, 20)
        XCTAssertEqual(fixture.cases.filter { $0.group == .mixedUnicode }.count, 15)
        XCTAssertEqual(fixture.cases.filter { $0.group == .securityLifecycle }.count, 15)
        XCTAssertEqual(fixture.diagnosticFixture.id, SyntheticDiagnosticFixture.id)
        XCTAssertFalse(fixture.cases.map(\.input).contains(fixture.diagnosticFixture.input))

        let bytes = try Data(contentsOf: XCTUnwrap(
            Bundle.main.url(forResource: "contextual-corrections", withExtension: "json")
        ))
        for mutation in [
            ("\"family\": \"evaluation\"", "\"family\": \"EVALUATION\""),
            ("\"group\": \"correct_original\"", "\"group\": \"correct\""),
            ("\"kind\": \"decisions\"", "\"kind\": \"DECISIONS\""),
            ("\"choice\": \"keep_original\"", "\"choice\": \"keep\"")
        ] {
            var text = try XCTUnwrap(String(data: bytes, encoding: .utf8))
            text = text.replacingOccurrences(of: mutation.0, with: mutation.1, options: [], range: text.range(of: mutation.0))
            XCTAssertThrowsError(try JSONDecoder().decode(ContextualCorpusFixture.self, from: Data(text.utf8)))
        }

        var numberedDuplicate = try XCTUnwrap(String(data: bytes, encoding: .utf8))
        numberedDuplicate = numberedDuplicate.replacingOccurrences(
            of: "Meu rosto ficou vermelho depois da corrida.",
            with: "Caso 42: O retrato mostra o rosto de perfil."
        )
        let duplicateFixture = try JSONDecoder().decode(
            ContextualCorpusFixture.self,
            from: Data(numberedDuplicate.utf8)
        )
        XCTAssertFalse(duplicateFixture.validate())
    }

    func testDiagnosticFixtureLoadsFromCandidateAppBundle() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "br.com.luisroquette.Resenha")
        let url = try XCTUnwrap(Bundle.main.url(forResource: "contextual-corrections", withExtension: "json"))
        XCTAssertTrue(url.path.contains("Resenha.app/Contents/Resources"))
        let fixture = try SyntheticDiagnosticFixture.load(from: .main)
        XCTAssertEqual(fixture.id, SyntheticDiagnosticFixture.id)
        XCTAssertEqual(fixture.language, "pt")
    }
}

private actor ContextualAttemptEventCollector {
    private var events: [ContextualProviderAttemptEvent] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func append(_ event: ContextualProviderAttemptEvent) {
        events.append(event)
        if events.count >= 2 {
            let waiters = waiters
            self.waiters = []
            waiters.forEach { $0.resume() }
        }
    }
    func waitForPair() async {
        guard events.count < 2 else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func snapshot() -> [ContextualProviderAttemptEvent] { events }
}

@MainActor
final class ContextualAttemptAuditTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/jev-attempts-v1.json")
    }

    private func receipt(index: Int = 0) -> ContextualDecisionReceipt {
        .init(
            decisions: [.init(
                questionID: "o1", choice: index.isMultiple(of: 2) ? .replace : .keepOriginal,
                confidence: 0.96, chosenProbability: 0.97, runnerUpProbability: 0.03
            )],
            resolvedModel: "typesafe/jev-1.14-20261014",
            inputTokens: 357,
            outputTokens: 38,
            costUSD: Decimal(string: "0.000014994"),
            providerRequestID: "jev-proof-\(index)"
        )
    }

    func testAttemptStorePersistsBoundedSanitizedProviderProofAndDeletesIt() throws {
        struct SensitiveFailure: Error, CustomStringConvertible {
            let description = "SECRET-SENTINEL dictated sentence and api key"
        }
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ContextualAttemptStore(fileURL: file)

        for index in 0..<25 {
            let id = UUID()
            let start = Date(timeIntervalSince1970: Double(index))
            store.consume(.requested(id: id, at: start))
            if index == 0 {
                store.consume(.failed(
                    id: id, startedAt: start, completedAt: start.addingTimeInterval(0.01), latencyMilliseconds: 10,
                    failure: .init(SensitiveFailure())
                ))
            } else {
                if index == 24 {
                    store.consume(.resolved(
                        id: id,
                        disposition: .appliedReplacement,
                        context: .init(
                            dictationAttemptID: UUID(), stage: .rolling,
                            revision: 7, dispatchOrdinal: 3,
                            candidateToDecisionMilliseconds: 777
                        )
                    ))
                }
                store.consume(.succeeded(
                    id: id, startedAt: start, completedAt: start.addingTimeInterval(0.125),
                    latencyMilliseconds: 125, receipt: receipt(index: index)
                ))
            }
        }

        XCTAssertEqual(store.records.count, ContextualAttemptStore.maximumRecords)
        let latest = try XCTUnwrap(store.latest)
        XCTAssertTrue(latest.providerResponseConfirmed)
        XCTAssertEqual(latest.resolvedModel, "typesafe/jev-1.14-20261014")
        XCTAssertEqual(latest.minimumConfidence, 0.96)
        XCTAssertEqual(latest.minimumProbability, 0.97)
        XCTAssertEqual(latest.latencyMilliseconds, 125)
        XCTAssertEqual(latest.costUSD, Decimal(string: "0.000014994"))
        XCTAssertEqual(latest.providerRequestID, "jev-proof-24")
        XCTAssertEqual(latest.disposition, .appliedReplacement)
        XCTAssertEqual(latest.stage, .rolling)
        XCTAssertEqual(latest.revision, 7)
        XCTAssertEqual(latest.dispatchOrdinal, 3)
        XCTAssertEqual(latest.candidateToDecisionMilliseconds, 777)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber, 0o600)

        let failureID = UUID()
        let failureStart = Date(timeIntervalSince1970: 30)
        store.consume(.requested(id: failureID, at: failureStart))
        store.consume(.failed(
            id: failureID, startedAt: failureStart,
            completedAt: failureStart.addingTimeInterval(0.01), latencyMilliseconds: 10,
            failure: .init(SensitiveFailure())
        ))
        XCTAssertEqual(store.latest?.status, .failed)
        XCTAssertEqual(store.latest?.failure, .unknown)
        let persistedAudit = String(decoding: try Data(contentsOf: file), as: UTF8.self)
        for forbidden in ["SECRET-SENTINEL", "dictated sentence", "api key", "rosto", "Hostel"] {
            XCTAssertFalse(persistedAudit.localizedCaseInsensitiveContains(forbidden), forbidden)
        }

        let reloaded = ContextualAttemptStore(fileURL: file)
        XCTAssertEqual(reloaded.records, store.records)
        reloaded.deleteAll()
        XCTAssertTrue(reloaded.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: ContextualAttemptStore.maximumFileBytes + 1).write(to: file)
        let oversized = ContextualAttemptStore(fileURL: file)
        XCTAssertTrue(oversized.records.isEmpty)
        XCTAssertFalse(oversized.storageAvailable)

        let corrupt = String(decoding: try JSONEncoder().encode(
            ContextualAttemptRecord(
                id: UUID(), startedAt: Date(), completedAt: Date(), status: .succeeded,
                resolvedModel: "test", decisions: [], minimumConfidence: nil,
                minimumProbability: nil, latencyMilliseconds: 1, inputTokens: nil,
                outputTokens: nil, costUSD: nil, dictationAttemptID: UUID(),
                stage: .rolling, revision: 1, dispatchOrdinal: 7,
                candidateToDecisionMilliseconds: 1, failure: nil
            )
        ), as: UTF8.self)
        try Data(#"{"schemaVersion":1,"records":["#.utf8)
            .write(to: file, options: .atomic)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(Data(corrupt.utf8))
        try handle.write(Data("]}".utf8))
        try handle.close()
        let invalidContext = ContextualAttemptStore(fileURL: file)
        XCTAssertTrue(invalidContext.records.isEmpty)
        XCTAssertFalse(invalidContext.storageAvailable)
    }

    func testPersonalClientEmitsCorrelatedProviderConfirmedAttemptWithUsage() async throws {
        let response = Data(#"{"model":"typesafe/jev-1.14-20261014","answers":{"o1":{"type":"choice","choice":"replace_1","probabilities":{"keep_original":0.01,"replace_1":0.99},"confidence":0.98}},"usage":{"input_tokens":357,"output_tokens":38,"cost":0.000014994},"id":"jev-proof-123"}"#.utf8)
        let collector = ContextualAttemptEventCollector()
        let client = OpenRouterDecisionsClient(
            transport: DecisionsStreamingTransportStub(chunks: [response]),
            credential: { "test-only-key" },
            beforeTransportOpen: { true },
            onAttempt: { await collector.append($0) }
        )
        let sentence = "Reservei um rosto."
        let range = try XCTUnwrap(sentence.range(of: "rosto"))
        let receipt = try await client.decide(
            sentence: sentence,
            language: "pt",
            occurrences: [.init(
                questionID: "o1", heard: "rosto", canonical: "Hostel",
                ordinal: 1, range: range
            )],
            deadline: .init(offset: .seconds(1))
        )

        XCTAssertEqual(receipt.costUSD, Decimal(string: "0.000014994"))
        await collector.waitForPair()
        let events = await collector.snapshot()
        XCTAssertEqual(events.count, 2)
        let requestedID = events.compactMap { event -> UUID? in
            guard case .requested(let id, _) = event else { return nil }
            return id
        }.first
        let success = events.compactMap { event -> (UUID, ContextualDecisionReceipt)? in
            guard case .succeeded(let id, _, _, _, let receipt) = event else { return nil }
            return (id, receipt)
        }.first
        guard let requestedID, let (succeededID, observedReceipt) = success else {
            return XCTFail("Expected correlated requested and succeeded events")
        }
        XCTAssertEqual(requestedID, succeededID)
        XCTAssertEqual(observedReceipt.resolvedModel, "typesafe/jev-1.14-20261014")
        XCTAssertEqual(observedReceipt.costUSD, Decimal(string: "0.000014994"))
        XCTAssertEqual(observedReceipt.providerRequestID, "jev-proof-123")
    }
}

@MainActor
private final class CoordinatorPipelineProbe: DictationOutputSink {
    enum Event: Equatable {
        case providerInput(String)
        case preview(String?)
        case staged(String)
        case history(String)
        case inserted
        case completed(String)
    }

    var events: [Event] = []
    var shouldSuspendInsertion = false
    private var insertionContinuation: CheckedContinuation<Void, Never>?

    func stage(_ text: String) throws -> Int {
        events.append(.staged(text))
        return 7
    }

    func insertStaged(into target: NSRunningApplication?, changeCount: Int) async throws {
        XCTAssertEqual(changeCount, 7)
        events.append(.inserted)
        if shouldSuspendInsertion {
            await withCheckedContinuation { insertionContinuation = $0 }
        }
    }

    func resumeInsertion() {
        insertionContinuation?.resume()
        insertionContinuation = nil
    }
}

private actor ControlledCoordinatorProvider: ContextualDecisionProvider {
    enum Mode { case replace, failure, suspended }

    private let mode: Mode
    private let probe: CoordinatorPipelineProbe
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var decisionContinuation: CheckedContinuation<Void, Never>?
    private(set) var calls = 0

    init(mode: Mode, probe: CoordinatorPipelineProbe) {
        self.mode = mode
        self.probe = probe
    }

    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        calls += 1
        await MainActor.run { probe.events.append(.providerInput(sentence)) }
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        switch mode {
        case .failure:
            throw OpenRouterDecisionsError.transportUnavailable
        case .suspended:
            await withCheckedContinuation { decisionContinuation = $0 }
        case .replace:
            break
        }
        return .init(
            decisions: occurrences.map {
                .init(
                    questionID: $0.questionID,
                    choice: .replace,
                    confidence: 0.99,
                    chosenProbability: 0.99,
                    runnerUpProbability: 0.01
                )
            },
            resolvedModel: "fixture/deterministic",
            inputTokens: nil,
            outputTokens: nil,
            costUSD: nil
        )
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resume() {
        decisionContinuation?.resume()
        decisionContinuation = nil
    }
}

@MainActor
final class ContextualCoordinatorTests: XCTestCase {
    private struct Harness {
        let store: ContextualCorrectionStore
        let policy: ContextualCorrectionPolicy
        let probe: CoordinatorPipelineProbe
        let provider: ControlledCoordinatorProvider
        let coordinator: DictationCoordinator
        let continuousSession: ContinuousContextSession?
    }

    private func makeHarness(
        providerMode: ControlledCoordinatorProvider.Mode,
        store: ContextualCorrectionStore? = nil,
        policy: ContextualCorrectionPolicy? = nil,
        scope: ContextualTransportScope = .testDouble,
        continuousEnabled: Bool = false,
        personalRemoteEnabled: Bool = false,
        localPreviewVisible: Bool? = nil,
        wiresContinuousRemote: Bool = false
    ) -> Harness {
        let actualPolicy = policy ?? ContextualCorrectionPolicy()
        let actualStore = store ?? ContextualCorrectionStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/contextual.json")
        )
        if actualStore.snapshot.health == .healthy, actualStore.examples.isEmpty {
            XCTAssertTrue(actualStore.save(.init(
                id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
                sentence: "Reservei um rosto.", occurrenceOrdinal: 1
            )).isSuccess)
        }
        actualStore.onMutation = { actualPolicy.invalidate(.storeMutated) }
        let probe = CoordinatorPipelineProbe()
        let provider = ControlledCoordinatorProvider(mode: providerMode, probe: probe)
        let continuousMode = continuousEnabled || personalRemoteEnabled
        let previewVisible = localPreviewVisible ?? continuousEnabled
        let continuousSession = continuousMode ? ContinuousContextSession() : nil
        let time = ContinuousContextualTime()
        let resolver = ContextualCorrectionResolver(
            store: actualStore,
            policy: actualPolicy,
            provider: provider,
            storeGeneration: { actualStore.generation },
            time: time
        )
        let coordinator = DictationCoordinator(
            permissions: PermissionService(),
            panel: FloatingPanelController(),
            showsHUD: { true },
            soundsEnabled: { false },
            language: { .portuguese },
            onTranscript: { probe.events.append(.history($0)) },
            continuousContextEnabled: { continuousMode },
            continuousPreviewVisible: { previewVisible },
            continuousContextSessionFactory: { continuousSession ?? ContinuousContextSession() },
            onContinuousPreview: {
                if continuousMode { probe.events.append(.preview($0?.sourceText)) }
            },
            continuousContextLoopFactory: { session, budget in
                guard wiresContinuousRemote else { return nil }
                return RevisionBoundJevLoop(
                    session: session,
                    provider: provider,
                    time: time,
                    storeSnapshot: { actualStore.snapshot },
                    policyGeneration: { actualPolicy.generation },
                    policy: actualPolicy,
                    dispatchBudget: budget
                )
            },
            onContinuousContextualPreview: { _, _, text in
                probe.events.append(.preview(text))
            },
            outputSink: probe,
            contextualResolver: resolver,
            contextualTokenSource: { _ in actualPolicy.issueToken(scope: scope) },
            contextualStoreGeneration: { actualStore.generation }
        )
        coordinator.onCompleted = { probe.events.append(.completed($0.text)) }
        return .init(
            store: actualStore,
            policy: actualPolicy,
            probe: probe,
            provider: provider,
            coordinator: coordinator,
            continuousSession: continuousSession
        )
    }

    private func begin(_ coordinator: DictationCoordinator) -> UUID {
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        return coordinator.attemptID
    }

    private func beginContinuous(_ harness: Harness) -> UUID {
        harness.coordinator.transition(to: .recording)
        XCTAssertTrue(harness.coordinator.beginContinuousContextForActiveAttempt())
        return harness.coordinator.attemptID
    }

    private func emitPartial(
        _ text: String,
        to harness: Harness,
        attemptID: UUID,
        snapshotID: UInt64 = 1
    ) {
        let candidateAt = ProcessInfo.processInfo.systemUptime
        harness.coordinator.receiveContinuousHypothesis(
            .init(
                snapshotID: snapshotID,
                sampleRange: 0..<8_000,
                capturedAt: candidateAt,
                candidateAt: candidateAt,
                text: text,
                isStale: false
            ),
            attemptID: attemptID,
            session: harness.continuousSession
        )
    }

    func testContinuousCoordinatorPreviewsLocallyThenCommitsAuthoritativeFinalOnce() async throws {
        let harness = makeHarness(providerMode: .replace, scope: .disabled, continuousEnabled: true)
        let attempt = beginContinuous(harness)
        emitPartial("A COIS Energia chegou", to: harness, attemptID: attempt)
        XCTAssertEqual(harness.probe.events, [.preview("A COIS Energia chegou")])
        harness.coordinator.transition(to: .transcribing)

        try await harness.coordinator.finishTranscription(
            "A COESA Energia chegou", attemptID: attempt, language: .portuguese
        )

        XCTAssertEqual(harness.probe.events, [
            .preview("A COIS Energia chegou"),
            .staged("A COESA Energia chegou"),
            .history("A COESA Energia chegou"),
            .inserted,
            .preview(nil),
            .completed("A COESA Energia chegou")
        ])
        XCTAssertEqual(harness.continuousSession?.state, .committed)
    }

    func testContinuousCoordinatorDispatchesAuthorizedPersonalRevisionWithLocalPreviewToggleOff() async {
        let harness = makeHarness(
            providerMode: .replace,
            scope: .personalDictation,
            continuousEnabled: false,
            personalRemoteEnabled: true,
            wiresContinuousRemote: true
        )
        let attempt = beginContinuous(harness)
        emitPartial("Reservei um rosto.", to: harness, attemptID: attempt)
        await harness.provider.waitUntilStarted()
        for _ in 0..<20 where harness.probe.events.last != .providerInput("Reservei um rosto.") {
            await Task.yield()
        }

        XCTAssertEqual(harness.probe.events, [.providerInput("Reservei um rosto.")])
        XCTAssertFalse(harness.probe.events.contains {
            if case .preview(let text) = $0 { text != nil } else { false }
        })
        let callsBeforeRevocation = await harness.provider.calls
        XCTAssertEqual(callsBeforeRevocation, 1)

        harness.coordinator.continuousContextModeChanged()
        emitPartial("Reservei outro rosto.", to: harness, attemptID: attempt, snapshotID: 2)
        await Task.yield()
        let callsAfterRevocation = await harness.provider.calls
        XCTAssertEqual(callsAfterRevocation, 1)
        XCTAssertFalse(harness.probe.events.contains {
            if case .preview(let text) = $0 { text != nil } else { false }
        })
    }

    func testContinuousCoordinatorRejectsDuplicateFinalAndLatePreview() async throws {
        let harness = makeHarness(providerMode: .replace, scope: .disabled, continuousEnabled: true)
        let attempt = beginContinuous(harness)
        emitPartial("texto parcial", to: harness, attemptID: attempt)
        harness.coordinator.transition(to: .transcribing)

        try await harness.coordinator.finishTranscription(
            "texto final", attemptID: attempt, language: .portuguese
        )
        emitPartial("texto atrasado", to: harness, attemptID: attempt, snapshotID: 2)
        try await harness.coordinator.finishTranscription(
            "duplicado", attemptID: attempt, language: .portuguese
        )

        XCTAssertEqual(harness.probe.events.filter {
            if case .staged = $0 { true } else { false }
        }, [.staged("texto final")])
        XCTAssertFalse(harness.probe.events.contains(.preview("texto atrasado")))
    }

    func testContinuousCoordinatorModeChangeClearsPreviewWithoutBlockingFinalFallback() async throws {
        let harness = makeHarness(providerMode: .replace, scope: .disabled, continuousEnabled: true)
        let attempt = beginContinuous(harness)
        emitPartial("texto parcial", to: harness, attemptID: attempt)
        harness.coordinator.continuousContextModeChanged()
        emitPartial("texto atrasado", to: harness, attemptID: attempt, snapshotID: 2)
        harness.coordinator.transition(to: .transcribing)

        try await harness.coordinator.finishTranscription(
            "texto final local", attemptID: attempt, language: .portuguese
        )

        XCTAssertEqual(harness.probe.events, [
            .preview("texto parcial"),
            .preview(nil),
            .staged("texto final local"),
            .history("texto final local"),
            .inserted,
            .preview(nil),
            .completed("texto final local")
        ])
        XCTAssertEqual(harness.continuousSession?.state, .cancelled)
    }

    func testContinuousCoordinatorFeatureOffPreservesExistingFinalPath() async throws {
        let harness = makeHarness(providerMode: .replace, scope: .disabled)
        harness.coordinator.transition(to: .recording)
        XCTAssertFalse(harness.coordinator.beginContinuousContextForActiveAttempt())
        harness.coordinator.transition(to: .transcribing)
        let attempt = harness.coordinator.attemptID

        try await harness.coordinator.finishTranscription(
            "texto local", attemptID: attempt, language: .portuguese
        )

        XCTAssertEqual(harness.probe.events, [
            .staged("texto local"),
            .history("texto local"),
            .inserted,
            .completed("texto local")
        ])
    }

    func testCoordinatorUsesRealResolverAndOneResolvedStringForClipboardHistoryAndCompletion() async throws {
        let harness = makeHarness(providerMode: .replace)
        let attempt = begin(harness.coordinator)
        try await harness.coordinator.finishTranscription(
            "Reservei um rosto.", attemptID: attempt, language: .portuguese
        )
        XCTAssertEqual(harness.probe.events, [
            .providerInput("Reservei um rosto."),
            .staged("Reservei um Hostel."),
            .history("Reservei um Hostel."),
            .inserted,
            .completed("Reservei um Hostel.")
        ])
    }

    func testClockCompositionRejectsDistinctOriginsAndSharesOneManualClock() throws {
        XCTAssertThrowsError(try ContextualTimeComposition(
            resolver: ManualContextualTime(),
            diagnostic: ManualContextualTime(),
            transport: ManualContextualTime()
        )) { XCTAssertEqual($0 as? ContextualTimeCompositionError, .mismatchedOrigins) }
        let time = ManualContextualTime()
        let composition = try ContextualTimeComposition(
            resolver: time, diagnostic: time, transport: time
        )
        XCTAssertTrue(composition.shared === time)
        _ = URLSessionDecisionsStreamingTransport(time: composition.shared)
    }

    func testPersonalRemoteRequiresDistinctConsentCredentialAndLocalEligibility() async throws {
        XCTAssertEqual(PersonalRemoteReleaseDecision.current, .personalRemoteAvailable)
        XCTAssertEqual(PersonalRemoteReleaseDecision.allCases, [.personalRemoteAvailable])
        let policy = ContextualCorrectionPolicy()
        let optIn = PersonalRemoteOptInStoreStub()
        let credential = InMemoryCredentialStore()
        let authorizationState = InMemoryPersonalRemoteAuthorizationStateStore(
            backing: PersonalRemoteAuthorizationStateBacking()
        )
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/contextual.json")
        let store = ContextualCorrectionStore(fileURL: file)
        let owner = PersonalRemoteAuthorizationOwner(
            optInStore: optIn,
            credentialStore: credential,
            authorizationStateStore: authorizationState,
            policy: policy,
            storeSnapshot: { store.snapshot }
        )
        let source = DictationCoordinator.productionContextualTokenSource(
            authorization: owner
        )
        XCTAssertEqual(source(UUID()).scope, .disabled)
        XCTAssertThrowsError(try owner.authorizePersonalRemote(explicitConsent: true, credential: "personal-key")) {
            XCTAssertEqual($0 as? PersonalRemoteAuthorizationError, .locallyIneligible)
        }
        XCTAssertTrue(store.save(.init(
            id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
            sentence: "Reservei um rosto.", occurrenceOrdinal: 1
        )).isSuccess)
        XCTAssertThrowsError(try owner.authorizePersonalRemote(explicitConsent: false, credential: "personal-key")) {
            XCTAssertEqual($0 as? PersonalRemoteAuthorizationError, .consentRequired)
        }
        try owner.authorizePersonalRemote(explicitConsent: true, credential: "personal-key")
        XCTAssertEqual(source(UUID()).scope, .personalDictation)
        try owner.revokePersonalRemote()
        XCTAssertEqual(source(UUID()).scope, .disabled)
        XCTAssertFalse(optIn.personalRemoteEnabled)
        XCTAssertNil(try credential.load())
        try owner.authorizePersonalRemote(explicitConsent: true, credential: "personal-key-2")
        owner.handleProviderError(OpenRouterDecisionsError.invalidStatus(402))
        XCTAssertEqual(source(UUID()).scope, .disabled)
        XCTAssertFalse(optIn.personalRemoteEnabled)
        XCTAssertNil(try credential.load())

        let failingOptIn = PersonalRemoteOptInStoreStub()
        let failingCredential = InMemoryCredentialStore()
        let durableBacking = PersonalRemoteAuthorizationStateBacking()
        let failingAuthorizationState = InMemoryPersonalRemoteAuthorizationStateStore(
            backing: durableBacking
        )
        let failingOwner = PersonalRemoteAuthorizationOwner(
            optInStore: failingOptIn,
            credentialStore: failingCredential,
            authorizationStateStore: failingAuthorizationState,
            policy: ContextualCorrectionPolicy(),
            storeSnapshot: { store.snapshot }
        )
        try failingOwner.authorizePersonalRemote(explicitConsent: true, credential: "retained-key")
        failingOptIn.failOnDisable = true
        failingCredential.setDeleteFailure(true)
        XCTAssertThrowsError(try failingOwner.revokePersonalRemote())
        XCTAssertTrue(failingOptIn.personalRemoteEnabled)
        XCTAssertEqual(try failingCredential.load(), "retained-key")
        XCTAssertTrue(failingOwner.personalRemoteHealth().revokedInProcess)
        XCTAssertFalse(failingOwner.personalRemoteHealth().canDispatch)
        XCTAssertEqual(failingOwner.issueToken().scope, .disabled)
        let reconstructedAuthorizationState = InMemoryPersonalRemoteAuthorizationStateStore(
            backing: durableBacking
        )
        let reconstructedOwner = PersonalRemoteAuthorizationOwner(
            optInStore: failingOptIn,
            credentialStore: failingCredential,
            authorizationStateStore: reconstructedAuthorizationState,
            policy: ContextualCorrectionPolicy(),
            storeSnapshot: { store.snapshot }
        )
        XCTAssertFalse(reconstructedOwner.personalRemoteHealth().canDispatch)
        XCTAssertEqual(reconstructedOwner.issueToken().scope, .disabled)
        let blockedTransport = DecisionsStreamingTransportStub(chunks: [])
        let blockedClient = OpenRouterDecisionsClient(
            transport: blockedTransport,
            credential: { "retained-key" },
            beforeTransportOpen: {
                await reconstructedOwner.personalRemoteHealth().canDispatch
            }
        )
        let blockedSentence = "Reservei um rosto."
        let blockedRange = try XCTUnwrap(blockedSentence.range(of: "rosto"))
        do {
            _ = try await blockedClient.decide(
                sentence: blockedSentence,
                language: "pt",
                occurrences: [.init(
                    questionID: "o1", heard: "rosto", canonical: "Hostel",
                    ordinal: 1, range: blockedRange
                )],
                deadline: .init(offset: .seconds(1))
            )
            XCTFail("Revoked authority must block before transport open")
        } catch {
            XCTAssertEqual(error as? OpenRouterDecisionsError, .authorizationInvalidated)
        }
        XCTAssertNil(blockedTransport.snapshot().capturedRequest)

        failingOptIn.failOnDisable = false
        failingCredential.setDeleteFailure(false)
        XCTAssertEqual(reconstructedOwner.issueToken().scope, .disabled)
        try reconstructedOwner.authorizePersonalRemote(explicitConsent: true, credential: "new-explicit-key")
        XCTAssertFalse(reconstructedOwner.personalRemoteHealth().revokedInProcess)
        XCTAssertEqual(reconstructedOwner.issueToken().scope, .personalDictation)

        for (index, status) in [401, 402, 403, 429].enumerated() {
            failingOptIn.failOnDisable = true
            failingCredential.setDeleteFailure(true)
            reconstructedOwner.handleProviderError(OpenRouterDecisionsError.invalidStatus(status))
            XCTAssertTrue(reconstructedOwner.personalRemoteHealth().revokedInProcess)
            XCTAssertFalse(reconstructedOwner.personalRemoteHealth().canDispatch)
            XCTAssertEqual(reconstructedOwner.issueToken().scope, .disabled)
            guard index < 3 else { continue }
            failingOptIn.failOnDisable = false
            failingCredential.setDeleteFailure(false)
            try reconstructedOwner.authorizePersonalRemote(
                explicitConsent: true,
                credential: "explicit-key-\(status)"
            )
        }

        reconstructedAuthorizationState.readFails = true
        XCTAssertFalse(reconstructedOwner.personalRemoteHealth().canDispatch)
        XCTAssertEqual(reconstructedOwner.issueToken().scope, .disabled)
        reconstructedAuthorizationState.readFails = false
        failingOptIn.failOnDisable = false
        failingCredential.setDeleteFailure(false)
        try reconstructedOwner.authorizePersonalRemote(explicitConsent: true, credential: "write-test-key")
        reconstructedAuthorizationState.writeFails = true
        XCTAssertThrowsError(try reconstructedOwner.revokePersonalRemote())
        XCTAssertFalse(failingOptIn.personalRemoteEnabled)
        XCTAssertNil(try failingCredential.load())
        XCTAssertFalse(reconstructedOwner.personalRemoteHealth().canDispatch)
        XCTAssertEqual(reconstructedOwner.issueToken().scope, .disabled)
        let writeFailureReconstructedOwner = PersonalRemoteAuthorizationOwner(
            optInStore: failingOptIn,
            credentialStore: failingCredential,
            authorizationStateStore: InMemoryPersonalRemoteAuthorizationStateStore(
                backing: durableBacking
            ),
            policy: ContextualCorrectionPolicy(),
            storeSnapshot: { store.snapshot }
        )
        XCTAssertFalse(writeFailureReconstructedOwner.personalRemoteHealth().canDispatch)
        XCTAssertEqual(writeFailureReconstructedOwner.issueToken().scope, .disabled)
    }

    func testPersonalRemoteDurableStatePersistsAcrossStoreReconstructionAndRejectsCorruption() throws {
        let suite = "ResenhaTests.PersonalRemoteState.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let epoch = UUID()

        try UserDefaultsPersonalRemoteAuthorizationStateStore(defaults: defaults)
            .persistAuthorizedEpoch(epoch)
        XCTAssertEqual(
            try UserDefaultsPersonalRemoteAuthorizationStateStore(defaults: defaults)
                .loadAuthorizedEpoch(),
            epoch
        )
        try UserDefaultsPersonalRemoteAuthorizationStateStore(defaults: defaults).persistRevoked()
        XCTAssertNil(
            try UserDefaultsPersonalRemoteAuthorizationStateStore(defaults: defaults)
                .loadAuthorizedEpoch()
        )
        defaults.set(7, forKey: "resenha.personalRemoteAuthorizationState")
        XCTAssertThrowsError(
            try UserDefaultsPersonalRemoteAuthorizationStateStore(defaults: defaults)
                .loadAuthorizedEpoch()
        )
    }

    func testCoordinatorTestTokenSourceUsesTestDoubleScope() async throws {
        let harness = makeHarness(providerMode: .replace, scope: .testDouble)
        let attempt = begin(harness.coordinator)
        try await harness.coordinator.finishTranscription(
            "Reservei um rosto.", attemptID: attempt, language: .portuguese
        )
        let providerCalls = await harness.provider.calls
        XCTAssertEqual(providerCalls, 1)
    }

    func testCoordinatorRejectsStoreMutationWhileResolverSuspended() async throws {
        let harness = makeHarness(providerMode: .suspended)
        let attempt = begin(harness.coordinator)
        let task = Task {
            try await harness.coordinator.finishTranscription(
                "Reservei um rosto.", attemptID: attempt, language: .portuguese
            )
        }
        await harness.provider.waitUntilStarted()
        XCTAssertTrue(harness.store.save(.init(
            id: UUID(), language: "pt", heard: "sessão", canonical: "seção",
            sentence: "Abra a sessão financeira.", occurrenceOrdinal: 1
        )).isSuccess)
        await harness.provider.resume()
        try await task.value
        XCTAssertEqual(harness.probe.events, [.providerInput("Reservei um rosto.")])
        XCTAssertEqual(harness.coordinator.phase, .idle)
    }

    func testCoordinatorUnhealthyStoreKeepsOriginalUntilVerifiedReload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("contextual.json")
        try Data("not-json".utf8).write(to: file)
        let store = ContextualCorrectionStore(fileURL: file)
        let harness = makeHarness(providerMode: .replace, store: store)

        for _ in 0..<2 {
            let attempt = begin(harness.coordinator)
            try await harness.coordinator.finishTranscription(
                "Reservei um rosto.", attemptID: attempt, language: .portuguese
            )
            if store.error != nil {
                try? FileManager.default.removeItem(at: file)
                let writer = ContextualCorrectionStore(fileURL: file)
                XCTAssertTrue(writer.save(.init(
                    id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
                    sentence: "Reservei um rosto.", occurrenceOrdinal: 1
                )).isSuccess)
            }
        }
        let callsBeforeReload = await harness.provider.calls
        XCTAssertEqual(callsBeforeReload, 0)
        XCTAssertTrue(store.reload())
        let attempt = begin(harness.coordinator)
        try await harness.coordinator.finishTranscription(
            "Reservei um rosto.", attemptID: attempt, language: .portuguese
        )
        let callsAfterReload = await harness.provider.calls
        XCTAssertEqual(callsAfterReload, 1)
        XCTAssertEqual(harness.probe.events.filter {
            if case .staged = $0 { true } else { false }
        }, [
            .staged("Reservei um rosto."),
            .staged("Reservei um rosto."),
            .staged("Reservei um Hostel.")
        ])
    }

    func testCoordinatorIgnoresLateCompletionFromCancelledAttempt() async throws {
        let harness = makeHarness(providerMode: .suspended)
        let attempt = begin(harness.coordinator)
        let task = Task {
            try await harness.coordinator.finishTranscription(
                "Reservei um rosto.", attemptID: attempt, language: .portuguese
            )
        }
        await harness.provider.waitUntilStarted()
        harness.coordinator.cancel()
        let nextAttempt = begin(harness.coordinator)
        await harness.provider.resume()
        _ = try? await task.value
        XCTAssertEqual(harness.probe.events, [.providerInput("Reservei um rosto.")])
        XCTAssertEqual(harness.coordinator.phase, .transcribing)
        XCTAssertEqual(harness.coordinator.attemptID, nextAttempt)
        harness.coordinator.cancel()

        let afterStage = makeHarness(providerMode: .replace)
        afterStage.probe.shouldSuspendInsertion = true
        let stagedAttempt = begin(afterStage.coordinator)
        let stagedTask = Task {
            try await afterStage.coordinator.finishTranscription(
                "Reservei um rosto.", attemptID: stagedAttempt, language: .portuguese
            )
        }
        while !afterStage.probe.events.contains(.inserted) { await Task.yield() }
        afterStage.coordinator.cancel()
        afterStage.probe.resumeInsertion()
        try await stagedTask.value
        XCTAssertFalse(afterStage.probe.events.contains(.completed("Reservei um Hostel.")))
        XCTAssertEqual(afterStage.coordinator.phase, .idle)
    }

    func testContextualPolicyInvalidationCancelsResolverAndDiagnosticAndRejectsOldTokens() async throws {
        for reason in [
            ContextualPolicyInvalidationReason.optedOut,
            .credentialDeleted,
            .storeMutated,
            .appTerminated,
            .authorityChanged
        ] {
            let policy = ContextualCorrectionPolicy()
            let resolver = policy.issueToken(scope: .testDouble)
            let diagnostic = policy.issueToken(scope: .syntheticDiagnostic)
            var observed: [(String, UInt64)] = []
            XCTAssertTrue(policy.register(resolver) {
                observed.append(("resolver", policy.generation))
            })
            XCTAssertTrue(policy.register(diagnostic) {
                observed.append(("diagnostic", policy.generation))
            })
            policy.invalidate(reason)
            XCTAssertEqual(policy.generation, 1)
            XCTAssertEqual(observed.map(\.0).sorted(), ["diagnostic", "resolver"])
            XCTAssertTrue(observed.allSatisfy { $0.1 == 1 })
            XCTAssertFalse(policy.isCurrent(resolver))
            XCTAssertFalse(policy.isCurrent(diagnostic))
            policy.finish(resolver)
            policy.finish(diagnostic)
            XCTAssertEqual(observed.count, 2)
        }

        let mutationPolicy = ContextualCorrectionPolicy()
        let store = ContextualCorrectionStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/contextual.json")
        )
        store.onMutation = { mutationPolicy.invalidate(.storeMutated) }
        let first = ContextualCorrectionExample(
            id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
            sentence: "Reservei um rosto.", occurrenceOrdinal: 1
        )
        XCTAssertTrue(store.save(first).isSuccess)
        XCTAssertEqual(mutationPolicy.generation, 1)
        XCTAssertTrue(store.delete(id: first.id))
        XCTAssertEqual(mutationPolicy.generation, 2)
        XCTAssertTrue(store.save(first).isSuccess)
        XCTAssertTrue(store.deleteAll())
        XCTAssertEqual(mutationPolicy.generation, 4)

        let optOutPolicy = ContextualCorrectionPolicy()
        let optIn = ContextualOptInStoreStub(enabled: true)
        let optOutOwner = SyntheticDiagnosticAuthorizationOwner(
            optInStore: optIn,
            credentialStore: InMemoryCredentialStore(),
            guardStore: SyntheticGuardSpy(),
            policy: optOutPolicy
        )
        try await optOutOwner.setLocalBetaEnabled(false)
        XCTAssertEqual(optOutPolicy.generation, 1)

        let deletionPolicy = ContextualCorrectionPolicy()
        let credential = InMemoryCredentialStore()
        try credential.save("disposable-test-key")
        let deletionOwner = SyntheticDiagnosticAuthorizationOwner(
            optInStore: ContextualOptInStoreStub(enabled: true),
            credentialStore: credential,
            guardStore: SyntheticGuardSpy(),
            policy: deletionPolicy
        )
        try await deletionOwner.removeSyntheticDiagnosticCredential()
        XCTAssertEqual(deletionPolicy.generation, 1)
        XCTAssertNil(try credential.load())
    }

    func testCoordinatorProviderFailureFlowsOriginalExactlyOnce() async throws {
        let harness = makeHarness(providerMode: .failure, continuousEnabled: true)
        let attempt = beginContinuous(harness)
        emitPartial("Reservei um rosto", to: harness, attemptID: attempt)
        harness.coordinator.transition(to: .transcribing)
        try await harness.coordinator.finishTranscription(
            "Reservei um rosto.", attemptID: attempt, language: .portuguese
        )
        XCTAssertEqual(harness.probe.events, [
            .preview("Reservei um rosto"),
            .providerInput("Reservei um rosto."),
            .staged("Reservei um rosto."),
            .history("Reservei um rosto."),
            .inserted,
            .preview(nil),
            .completed("Reservei um rosto.")
        ])
    }
}

@MainActor
final class ContextualFeedbackSettingsTests: XCTestCase {
    private struct SettingsFixture {
        let suiteName: String
        let defaults: UserDefaults
        let preferences: ProductPreferences

        @MainActor static func make() throws -> Self {
            let suiteName = "ContextualFeedbackSettingsTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            return .init(
                suiteName: suiteName,
                defaults: defaults,
                preferences: ProductPreferences(defaults: defaults)
            )
        }
    }

    private final class AuthorizationManagerSpy: SyntheticDiagnosticAuthorizationManaging {
        enum Failure: Error { case requested }
        var failure: Failure?
        private(set) var localValues: [Bool] = []
        private(set) var authorizedCredentials: [String] = []
        private(set) var removalCount = 0

        func setLocalBetaEnabled(_ enabled: Bool) async throws {
            localValues.append(enabled)
            if let failure { throw failure }
        }

        func authorizeSyntheticDiagnostic(explicitConsent: Bool, credential: String) async throws {
            authorizedCredentials.append(credential)
            if let failure { throw failure }
        }

        func removeSyntheticDiagnosticCredential() async throws {
            removalCount += 1
            if let failure { throw failure }
        }
    }

    private func makeStore() -> (store: ContextualCorrectionStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContextualFeedbackSettingsTests/\(UUID().uuidString)")
        return (ContextualCorrectionStore(fileURL: root.appendingPathComponent("contextual.json")), root)
    }

    private func configurePanel(
        store: ContextualCorrectionStore,
        defaults: UserDefaults
    ) -> FloatingPanelController {
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: ProductPreferences(defaults: defaults), store: store)
        return panel
    }

    private func offer(
        _ panel: FloatingPanelController,
        text: String,
        heard: String = "rosto",
        canonical: String = "Hostel",
        ordinal: Int? = nil
    ) -> UUID {
        let token = UUID()
        panel.offerFeedback(.init(
            id: token, targetApplication: nil, text: text, language: .portuguese
        ))
        panel.openCorrection(token: token)
        panel.updateCorrectionDraft(token: token, heard: heard, canonical: canonical)
        if let ordinal { panel.selectCorrectionOccurrence(token: token, ordinal: ordinal) }
        return token
    }

    func testFeedbackSaveCreatesContextualExampleWithoutGlobalGlossaryRule() throws {
        let suite = "ContextualFeedbackSettingsTests.Save.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixture = makeStore()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let preferences = ProductPreferences(defaults: defaults)
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: preferences, store: fixture.store)
        let baseline = preferences.transcriptionGlossary
        defaults.set(7, forKey: "resenha.transcriptionGlossary")
        XCTAssertFalse(preferences.reloadTranscriptionGlossaryForCorrection())
        let token = offer(panel, text: "Reservei um rosto perto da estação.", ordinal: 1)
        panel.saveCorrection(token: token)

        XCTAssertEqual(fixture.store.examples.map(\.canonical), ["Hostel"])
        XCTAssertEqual(preferences.transcriptionGlossary, baseline)
    }

    func testFeedbackStoresOnlySentenceContainingSelectedOccurrence() throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let storage = makeStore()
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let panel = configurePanel(store: storage.store, defaults: fixture.defaults)

        let token = offer(
            panel,
            text: "Vi meu rosto no espelho. Reservei um rosto perto da estação.",
            ordinal: 2
        )
        panel.saveCorrection(token: token)

        XCTAssertEqual(storage.store.examples.count, 1)
        XCTAssertEqual(storage.store.examples.first?.sentence, "Reservei um rosto perto da estação.")
        XCTAssertEqual(storage.store.examples.first?.occurrenceOrdinal, 1)
    }

    func testFeedbackRejectsAbsentMultipleUnselectedAndOversizedOccurrence() throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let storage = makeStore()
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let panel = configurePanel(store: storage.store, defaults: fixture.defaults)

        let absent = offer(panel, text: "Reservei uma pousada.")
        XCTAssertFalse(panel.canSaveCorrection, "absent")
        panel.cancelFeedback(token: absent, restoreFocus: false)

        let multiple = offer(panel, text: "rosto perto de outro rosto")
        XCTAssertFalse(panel.canSaveCorrection, "multiple-unselected")
        panel.selectCorrectionOccurrence(token: multiple, ordinal: 2)
        XCTAssertTrue(panel.canSaveCorrection)
        panel.cancelFeedback(token: multiple, restoreFocus: false)

        let oversized = offer(panel, text: "rosto" + String(repeating: " x", count: 298))
        panel.saveCorrection(token: oversized)
        XCTAssertEqual(panel.correctionError, "A frase confirmada ultrapassa 600 caracteres")
        XCTAssertTrue(panel.isEditingCorrection)
    }

    func testFeedbackPreservesDraftAcrossDuplicateConflictLimitAndWriteFailure() throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        let duplicateStorage = makeStore()
        defer { try? FileManager.default.removeItem(at: duplicateStorage.root) }
        let original = ContextualCorrectionExample(
            id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
            sentence: "Reservei um rosto.", occurrenceOrdinal: 1
        )
        XCTAssertTrue(duplicateStorage.store.save(original).isSuccess)
        let duplicatePanel = configurePanel(store: duplicateStorage.store, defaults: fixture.defaults)
        let duplicate = offer(duplicatePanel, text: original.sentence, ordinal: 1)
        duplicatePanel.saveCorrection(token: duplicate)
        XCTAssertFalse(duplicatePanel.hasFeedback, "duplicate is an idempotent success")

        let conflictPanel = configurePanel(store: duplicateStorage.store, defaults: fixture.defaults)
        let conflict = offer(conflictPanel, text: original.sentence, canonical: "Hotel", ordinal: 1)
        conflictPanel.saveCorrection(token: conflict)
        XCTAssertEqual(conflictPanel.correctionDraft?.canonical, "Hotel")
        XCTAssertTrue(conflictPanel.correctionError?.contains("outra correção") == true)

        let limitStorage = makeStore()
        defer { try? FileManager.default.removeItem(at: limitStorage.root) }
        for index in 0..<ContextualCorrectionStore.maximumExamples {
            XCTAssertTrue(limitStorage.store.save(.init(
                id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
                sentence: "Reservei um rosto no quarto \(index).", occurrenceOrdinal: 1
            )).isSuccess)
        }
        let limitPanel = configurePanel(store: limitStorage.store, defaults: fixture.defaults)
        let limit = offer(limitPanel, text: "Reservei um rosto além do limite.", ordinal: 1)
        limitPanel.saveCorrection(token: limit)
        XCTAssertEqual(limitPanel.correctionDraft?.heard, "rosto")
        XCTAssertTrue(limitPanel.correctionError?.contains("limite") == true)

        let failureStorage = makeStore()
        try FileManager.default.removeItem(at: failureStorage.root)
        try Data("blocked".utf8).write(to: failureStorage.root)
        defer { try? FileManager.default.removeItem(at: failureStorage.root) }
        let failurePanel = configurePanel(store: failureStorage.store, defaults: fixture.defaults)
        let failure = offer(failurePanel, text: "Reservei um rosto.", ordinal: 1)
        failurePanel.saveCorrection(token: failure)
        XCTAssertEqual(failurePanel.correctionDraft?.canonical, "Hostel")
        XCTAssertNotNil(failurePanel.correctionError)
    }

    func testContextualFeedbackReleasesCompletionAcrossEveryExit() throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let storage = makeStore()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        for row in ["expiry", "approve", "save", "cancel", "replacement", "new-dictation", "hud-off", "termination"] {
            var now: TimeInterval = 10
            let panel = FloatingPanelController(clock: { now })
            panel.configureFeedback(preferences: fixture.preferences, store: storage.store)
            let released = expectation(description: "context released: \(row)")
            weak var weakProbe: ContextRetentionProbe?
            var token: UUID!
            do {
                let probe = ContextRetentionProbe { released.fulfill() }
                weakProbe = probe
                token = UUID()
                panel.offerFeedback(.init(
                    id: token, targetApplication: nil, text: "Reservei um rosto \(row).",
                    language: .portuguese, retentionProbe: probe
                ))
            }
            switch row {
            case "expiry":
                now = 20
                panel.dismissIfCurrent(generation: panel.dismissal.generation, now: now)
            case "approve": panel.approveFeedback(token: token)
            case "save":
                panel.openCorrection(token: token)
                panel.updateCorrectionDraft(token: token, heard: "rosto", canonical: "Hostel")
                panel.saveCorrection(token: token)
            case "cancel": panel.cancelFeedback(token: token, restoreFocus: false)
            case "replacement":
                panel.offerFeedback(.init(id: UUID(), targetApplication: nil, text: "nova", language: .portuguese))
                panel.hide()
            case "new-dictation": panel.show(.listening)
            case "hud-off", "termination": panel.hide()
            default: XCTFail(row)
            }
            wait(for: [released], timeout: 1)
            XCTAssertNil(weakProbe, row)
        }
    }

    func testContextualSettingsLocalToggleNeverTouchesDiagnosticAuthorization() async throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        XCTAssertFalse(fixture.preferences.contextualCorrectionsEnabled, "default")
        let manager = AuthorizationManagerSpy()
        let model = ContextualSettingsModel(authorization: manager, diagnostic: makeDiagnostic())
        await model.setLocalBetaEnabled(true)
        XCTAssertEqual(manager.localValues, [true])
        XCTAssertTrue(manager.authorizedCredentials.isEmpty)
        XCTAssertEqual(manager.removalCount, 0)
        try fixture.preferences.persistContextualCorrectionsEnabled(true)
        XCTAssertTrue(ProductPreferences(defaults: fixture.defaults).contextualCorrectionsEnabled, "reopen")
    }

    func testContextualSettingsAuthorizationAndRemovalExposeSanitizedErrors() async throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let manager = AuthorizationManagerSpy()
        manager.failure = .requested
        let model = ContextualSettingsModel(authorization: manager, diagnostic: makeDiagnostic())
        model.credential = "secret-provider-body"
        await model.authorizeDiagnostic()
        XCTAssertEqual(model.errorMessage, "Não foi possível autorizar o diagnóstico sintético.")
        XCTAssertFalse(model.errorMessage?.contains("secret-provider-body") == true)
        XCTAssertTrue(model.credential.isEmpty)
        await model.removeCredential()
        XCTAssertEqual(model.errorMessage, "Não foi possível remover a chave do diagnóstico.")
    }

    func testContextualSettingsExposeDeleteFailures() throws {
        let manager = AuthorizationManagerSpy()
        let model = ContextualSettingsModel(authorization: manager, diagnostic: makeDiagnostic())

        let single = makeStore()
        let example = ContextualCorrectionExample(
            id: UUID(), language: "pt", heard: "rosto", canonical: "Hostel",
            sentence: "Reservei um rosto.", occurrenceOrdinal: 1
        )
        XCTAssertTrue(single.store.save(example).isSuccess)
        try FileManager.default.removeItem(at: single.root)
        try Data("blocked".utf8).write(to: single.root)
        defer { try? FileManager.default.removeItem(at: single.root) }
        model.deleteExample(id: example.id, from: single.store)
        XCTAssertEqual(model.errorMessage, "Não foi possível apagar a correção contextual.")

        let all = makeStore()
        XCTAssertTrue(all.store.save(example).isSuccess)
        try FileManager.default.removeItem(at: all.root)
        try Data("blocked".utf8).write(to: all.root)
        defer { try? FileManager.default.removeItem(at: all.root) }
        model.deleteAll(from: all.store)
        XCTAssertEqual(model.errorMessage, "Não foi possível apagar as correções contextuais.")
    }

    func testContextualSettingsDiagnosticCatchesOnlySanitizedErrors() async throws {
        let success = await runSyntheticDiagnostic(makeDiagnostic(provider: .receipt(validDiagnosticReceipt())))
        XCTAssertNotNil(success.result)
        XCTAssertNil(success.errorMessage)
        let rows: [(SyntheticProviderMode, String?)] = [
            (.openRouter(.timedOut), "O diagnóstico sintético expirou."),
            (.openRouter(.invalidStatus(401)), "O provedor recusou o diagnóstico sintético."),
            (.openRouter(.transportUnavailable), "Não foi possível acessar o diagnóstico sintético."),
            (.receipt(validDiagnosticReceipt(decisions: [])), "O diagnóstico recebeu uma resposta inválida."),
            (.cancellation, nil)
        ]
        for (provider, expected) in rows {
            let observation = await runSyntheticDiagnostic(makeDiagnostic(provider: provider))
            XCTAssertNil(observation.result)
            XCTAssertEqual(observation.errorMessage, expected)
        }
        let unavailable = await runSyntheticDiagnostic(makeDiagnostic(authorizationMode: .failure))
        XCTAssertEqual(unavailable.errorMessage, "Autorize novamente o diagnóstico sintético.")
    }

    func testContextualSettingsNeverEnablePersonalRemoteTransport() async throws {
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        XCTAssertEqual(ContextualSettingsModel.disclosureLines, [
            "Correções contextuais (beta)",
            "Beta local, desligado por padrão: usa incerteza do Whisper, glossário e exemplos confirmados.",
            "Avaliação remota pessoal é separada e começa desligada.",
            "Diagnóstico de infraestrutura: envia somente a frase sintética identificada ao OpenRouter/TypeSafe, uma única vez.",
            "O diagnóstico não recebe nem corrige seu ditado pessoal."
        ])
        let provider = SyntheticProviderStub(.receipt(validDiagnosticReceipt()))
        let manager = AuthorizationManagerSpy()
        let model = ContextualSettingsModel(
            authorization: manager,
            diagnostic: makeDiagnostic(providerObject: provider)
        )
        await model.setLocalBetaEnabled(true)
        await model.setLocalBetaEnabled(false)
        let requestCount = await provider.requestCount()
        XCTAssertEqual(requestCount, 0)
        XCTAssertFalse(fixture.preferences.personalRemoteEnabled)
        XCTAssertNotEqual(
            KeychainContextualCredentialConstants.syntheticAccount,
            KeychainContextualCredentialConstants.personalAccount
        )
        XCTAssertTrue(ContextualSettingsModel.personalDisclosure.contains("somente a frase atual"))
        XCTAssertTrue(ContextualSettingsModel.personalDisclosure.localizedCaseInsensitiveContains("nunca áudio"))
        XCTAssertTrue(ContextualSettingsModel.personalDisclosure.contains("no máximo seis envios"))
        XCTAssertTrue(ContextualSettingsModel.personalDisclosure.contains("500 ms"))
        XCTAssertTrue(ContextualSettingsModel.personalDisclosure.contains("4096 bytes"))
        XCTAssertFalse(ContextualSettingsModel.personalDisclosure.localizedCaseInsensitiveContains("ZDR"))
    }

    func testContextualControlsHaveExactAccessibilityLabelsAndRestoreFocus() throws {
        XCTAssertEqual(ContextualSettingsModel.diagnosticAccessibilityLabel, "Executar diagnóstico sintético uma vez")
        XCTAssertEqual(ContextualSettingsModel.deleteExampleAccessibilityLabel, "Apagar exemplo contextual")
        XCTAssertEqual(ContextualSettingsModel.deleteAllAccessibilityLabel, "Apagar todos os exemplos contextuais")
        XCTAssertEqual(ContextualSettingsModel.removeCredentialAccessibilityLabel, "Remover chave do diagnóstico")
        XCTAssertEqual(ContextualSettingsModel.authorizePersonalAccessibilityLabel, "Ativar avaliação remota pessoal")
        XCTAssertEqual(ContextualSettingsModel.revokePersonalAccessibilityLabel, "Desativar avaliação remota e remover chave")
        let fixture = try SettingsFixture.make()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let storage = makeStore()
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let panel = configurePanel(store: storage.store, defaults: fixture.defaults)
        let token = offer(panel, text: "Reservei um rosto.", ordinal: 1)
        XCTAssertTrue(panel.cancelFeedback(token: token, restoreFocus: false))
        XCTAssertFalse(panel.hasFeedback)
    }

    private func validDiagnosticReceipt(
        decisions: [ContextualDecision]? = nil
    ) -> ContextualDecisionReceipt {
        .init(
            decisions: decisions ?? [.init(
                questionID: "o1", choice: .replace, confidence: 0.99,
                chosenProbability: 0.99, runnerUpProbability: 0.01
            )],
            resolvedModel: "synthetic-test", inputTokens: 10, outputTokens: 5, costUSD: 0
        )
    }

    private func makeDiagnostic(
        authorizationMode: DiagnosticAuthorizationStub.Mode = .success,
        provider: SyntheticProviderMode = .receipt(.init(
            decisions: [.init(
                questionID: "o1", choice: .replace, confidence: 0.99,
                chosenProbability: 0.99, runnerUpProbability: 0.01
            )],
            resolvedModel: "synthetic-test", inputTokens: 10, outputTokens: 5, costUSD: 0
        ))
    ) -> SyntheticDiagnosticController {
        makeDiagnostic(
            authorizationMode: authorizationMode,
            providerObject: SyntheticProviderStub(provider)
        )
    }

    private func makeDiagnostic(
        authorizationMode: DiagnosticAuthorizationStub.Mode = .success,
        providerObject: SyntheticProviderStub
    ) -> SyntheticDiagnosticController {
        let policy = ContextualCorrectionPolicy()
        return SyntheticDiagnosticController(
            policy: policy,
            authorization: DiagnosticAuthorizationStub(mode: authorizationMode, policy: policy),
            client: providerObject,
            validator: ContextualDecisionValidator(),
            fixture: .init(
                id: SyntheticDiagnosticFixture.id,
                pairID: "rosto-hostel",
                learningExampleIDs: ["learn-rosto-hostel-001"],
                language: "pt",
                input: "Reservei uma cama no rosto perto da estação.",
                heard: "rosto",
                canonical: "Hostel",
                ordinal: 1,
                expected: "Reservei uma cama no Hostel perto da estação."
            ),
            time: ContinuousContextualTime()
        )
    }
}

private final class InMemoryCredentialStore: ContextualCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    private(set) var calls: [String] = []
    var loadOverride: String?
    private var deleteFails = false

    func save(_ value: String) throws {
        lock.withLock { calls.append("credential-save"); self.value = value }
    }
    func load() throws -> String? {
        lock.withLock { calls.append("credential-load"); return loadOverride ?? value }
    }
    func delete() throws {
        try lock.withLock {
            calls.append("credential-delete")
            if deleteFails { throw ContextualCredentialError.invalidValue }
            value = nil
        }
    }
    func setDeleteFailure(_ enabled: Bool) { lock.withLock { deleteFails = enabled } }
    func snapshotCalls() -> [String] { lock.withLock { calls } }
}

@MainActor
private final class PersonalRemoteAuthorizationStateBacking {
    var epoch: UUID?
}

@MainActor
private final class InMemoryPersonalRemoteAuthorizationStateStore:
    PersonalRemoteAuthorizationStateStore
{
    private let backing: PersonalRemoteAuthorizationStateBacking
    var readFails = false
    var writeFails = false

    init(backing: PersonalRemoteAuthorizationStateBacking) {
        self.backing = backing
    }

    func loadAuthorizedEpoch() throws -> UUID? {
        if readFails { throw PersonalRemoteAuthorizationError.durableStateUnavailable }
        return backing.epoch
    }

    func persistAuthorizedEpoch(_ epoch: UUID) throws {
        if writeFails { throw PersonalRemoteAuthorizationError.durableStateUnavailable }
        backing.epoch = epoch
    }

    func persistRevoked() throws {
        if writeFails { throw PersonalRemoteAuthorizationError.durableStateUnavailable }
        backing.epoch = nil
    }
}

@MainActor
private final class ContextualOptInStoreStub: ContextualOptInStore {
    private(set) var contextualCorrectionsEnabled: Bool
    private(set) var writes: [Bool] = []
    init(enabled: Bool) { contextualCorrectionsEnabled = enabled }
    func persistContextualCorrectionsEnabled(_ enabled: Bool) throws {
        writes.append(enabled)
        contextualCorrectionsEnabled = enabled
    }
}

@MainActor
private final class PersonalRemoteOptInStoreStub: PersonalRemoteOptInStore {
    var contextualCorrectionsEnabled = true
    private(set) var personalRemoteEnabled = false
    private(set) var writes: [Bool] = []
    var failOnDisable = false

    func persistPersonalRemoteEnabled(_ enabled: Bool) throws {
        writes.append(enabled)
        if !enabled, failOnDisable { throw PersonalRemoteAuthorizationError.credentialUnverified }
        personalRemoteEnabled = enabled
    }
}

private actor SyntheticGuardSpy: SyntheticDiagnosticGuardStore {
    var health: SyntheticDiagnosticGuardHealth = .blocked
    var calls: [String] = []
    var failure: SyntheticDiagnosticGuardError?

    func validateForAuthorization() throws {
        calls.append("guard-inspect")
        if let failure { throw failure }
    }
    func provisionAuthorizedCall() throws {
        calls.append("guard-provision")
        if let failure { throw failure }
        health = .ready(.available)
    }
    func consume() throws {
        calls.append("guard-consume")
        if let failure { throw failure }
        guard health == .ready(.available) else { throw SyntheticDiagnosticGuardError.blocked }
        health = .ready(.consumed)
    }
    func currentState() -> SyntheticDiagnosticGuardHealth {
        calls.append("guard-state")
        return health
    }
    func setHealth(_ health: SyntheticDiagnosticGuardHealth) { self.health = health }
    func snapshotCalls() -> [String] { calls }
}

private enum SyntheticProviderMode: Sendable {
    case receipt(ContextualDecisionReceipt)
    case openRouter(OpenRouterDecisionsError)
    case cancellation
}

private actor SyntheticProviderStub: SyntheticDiagnosticDecisionProvider {
    let mode: SyntheticProviderMode
    private(set) var calls = 0
    private(set) var beforeOpenResults: [Bool] = []

    init(_ mode: SyntheticProviderMode) { self.mode = mode }

    func requestCount() -> Int { calls }

    func decideSynthetic(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt {
        let allowed = await beforeTransportOpen()
        beforeOpenResults.append(allowed)
        guard allowed else { throw OpenRouterDecisionsError.authorizationInvalidated }
        calls += 1
        switch mode {
        case .receipt(let receipt): return receipt
        case .openRouter(let error): throw error
        case .cancellation: throw CancellationError()
        }
    }
}

@MainActor
private final class DiagnosticAuthorizationStub: SyntheticDiagnosticAuthorizationChecking {
    enum Mode { case success, failure, invalidate(ContextualPolicyInvalidationReason) }
    let mode: Mode
    let policy: ContextualCorrectionPolicy
    private(set) var tokens: [ContextualPolicyToken] = []

    init(mode: Mode, policy: ContextualCorrectionPolicy) {
        self.mode = mode
        self.policy = policy
    }

    func consumeForDispatch(token: ContextualPolicyToken) async throws {
        tokens.append(token)
        switch mode {
        case .success: return
        case .failure: throw SyntheticDiagnosticAuthorizationError.guardUnavailable
        case .invalidate(let reason):
            policy.invalidate(reason)
            throw SyntheticDiagnosticAuthorizationError.stalePolicy
        }
    }

    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth {
        .init(localBetaEnabled: true, diagnosticArmed: true, guardHealth: .ready(.available))
    }
}

private final class FailingContextualFileOperations: ContextualFileOperating, @unchecked Sendable {
    enum Failure { case read, write }
    let failure: Failure
    init(_ failure: Failure) { self.failure = failure }
    func fileExists(at url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func read(_ url: URL) throws -> Data {
        if failure == .read { throw CocoaError(.fileReadUnknown) }
        return try Data(contentsOf: url)
    }
    func write(_ data: Data, to url: URL) throws {
        if failure == .write { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
    func setPermissions(_ permissions: Int, at url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }
    func replace(_ destination: URL, with source: URL) throws {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
    }
    func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}

@MainActor
private final class ConsumingInvalidatingAuthorizationStub: SyntheticDiagnosticAuthorizationChecking {
    let guardStore: SyntheticDiagnosticGuard
    let policy: ContextualCorrectionPolicy
    let reason: ContextualPolicyInvalidationReason

    init(
        guardStore: SyntheticDiagnosticGuard,
        policy: ContextualCorrectionPolicy,
        reason: ContextualPolicyInvalidationReason
    ) {
        self.guardStore = guardStore
        self.policy = policy
        self.reason = reason
    }

    func consumeForDispatch(token: ContextualPolicyToken) async throws {
        try await guardStore.consume()
        policy.invalidate(reason)
    }

    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth {
        .init(localBetaEnabled: true, diagnosticArmed: false, guardHealth: await guardStore.currentState())
    }
}

private actor InvalidatingBeforeOpenProvider: SyntheticDiagnosticDecisionProvider {
    let policy: ContextualCorrectionPolicy
    private(set) var openCount = 0

    init(policy: ContextualCorrectionPolicy) { self.policy = policy }

    func decideSynthetic(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt {
        await MainActor.run { policy.invalidate(.optedOut) }
        guard await beforeTransportOpen() else {
            throw OpenRouterDecisionsError.authorizationInvalidated
        }
        openCount += 1
        throw OpenRouterDecisionsError.transportUnavailable
    }
}

extension ContextualResolverTests {
    @MainActor
    func testFinalResolverUsesProactiveEvidenceWithoutFeedbackExample() async {
        let provider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let item = fixture(examples: [], provider: provider)
        let output = await item.0.resolve(.init(
            attemptID: UUID(),
            text: "Reservei uma cama no rosto.",
            language: "pt",
            policyToken: item.2.issueToken(scope: .testDouble),
            storeGenerationAtStart: item.1.generation,
            tokenEvidence: [.init(
                tokenID: 1, text: " rosto", probability: 0.20, alternatives: []
            )],
            glossaryTerms: ["Hostel"]
        ))

        XCTAssertEqual(output, "Reservei uma cama no Hostel.")

        let blockedProvider = ResolverDecisionProviderStub([decision("o1", .replace)])
        let blocked = fixture(examples: [], provider: blockedProvider)
        let unchanged = await blocked.0.resolve(.init(
            attemptID: UUID(),
            text: "Texto comum sem candidato.",
            language: "pt",
            policyToken: blocked.2.issueToken(scope: .personalDictation),
            storeGenerationAtStart: blocked.1.generation
        ))
        XCTAssertEqual(unchanged, "Texto comum sem candidato.")
        let blockedRequestCount = await blockedProvider.requestCount
        XCTAssertEqual(blockedRequestCount, 0)
    }

    func testProactiveStabilityRequiresTwoIdenticalSightingsAndResetsOnChange() throws {
        let text = "Reservei uma cama no rosto."
        let range = try XCTUnwrap(text.range(of: "rosto"))
        func occurrence(_ value: String, source: ContextualCandidateSource) -> ContextualCorrectionOccurrence {
            .init(
                questionID: "o1", heard: "rosto", canonical: value,
                alternatives: [.init(id: "replace_1", value: value, source: source)],
                ordinal: 1, range: range
            )
        }
        let session = ContinuousContextSession()
        XCTAssertFalse(session.isStableForDispatch(occurrence("Hostel", source: .vocabulary)))
        XCTAssertTrue(session.isStableForDispatch(occurrence("Hostel", source: .vocabulary)))
        XCTAssertFalse(session.isStableForDispatch(occurrence("posto", source: .vocabulary)))
        session.resetProactiveStability()
        XCTAssertFalse(session.isStableForDispatch(occurrence("posto", source: .vocabulary)))
        XCTAssertTrue(session.isStableForDispatch(occurrence("Hostel", source: .learned)))
    }

    func testContextualDispatchBudgetAllowsExactlySixConcurrentAttemptsWithoutRefund() async {
        let budget = ContextualDispatchBudget()
        let accepted = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<40 { group.addTask { budget.consume() } }
            var count = 0
            for await value in group where value { count += 1 }
            return count
        }
        XCTAssertEqual(accepted, 6)
        XCTAssertEqual(budget.consumed, 6)
        XCTAssertFalse(budget.consume())
    }

    func testContextualDispatchBudgetReturnsUniqueOrdinals() async {
        let budget = ContextualDispatchBudget()
        let ordinals = await withTaskGroup(of: Int?.self, returning: [Int].self) { group in
            for _ in 0..<40 { group.addTask { budget.consumeOrdinal() } }
            var values: [Int] = []
            for await value in group { if let value { values.append(value) } }
            return values.sorted()
        }
        XCTAssertEqual(ordinals, Array(1...6))
    }

    func testContextualRevisionRebaseAcceptsOnlyAppendedSuffix() throws {
        let source = "Reservei uma cama no rosto."
        let range = try XCTUnwrap(source.range(of: "rosto"))
        let occurrence = ContextualCorrectionOccurrence(
            questionID: "o1", heard: "rosto", canonical: "Hostel",
            alternatives: [.init(id: "replace_1", value: "Hostel", source: .vocabulary)],
            ordinal: 1, range: range
        )
        let identity = ContextualRevisionWindowIdentity(
            attemptID: UUID(), revision: 1, snapshotID: 1, sampleRange: 0..<1,
            mutableSourceCharacterRange: 0..<source.count,
            generationIDs: .init(session: 1, work: 1), policyGeneration: 1, storeGeneration: 1
        )
        let result = RevisionBoundContextualResult(
            identity: identity, originalText: source,
            text: "Reservei uma cama no Hostel.",
            outcome: .init(category: .replaced, decisions: [])
        )
        XCTAssertEqual(ContextualRevisionRebase.apply(
            result: result, evaluatedSource: source, occurrence: occurrence,
            to: source + " O quarto estava limpo."
        ), "Reservei uma cama no Hostel. O quarto estava limpo.")
        XCTAssertNil(ContextualRevisionRebase.apply(
            result: result, evaluatedSource: source, occurrence: occurrence,
            to: "Reservei duas camas no rosto."
        ))
    }
}

extension ContextualCoordinatorTests {
    @MainActor
    func testPersonalRemoteCanAuthorizeWithProactiveEvidenceAndNoExample() throws {
        let optIn = PersonalRemoteOptInStoreStub()
        let credential = InMemoryCredentialStore()
        let store = ContextualCorrectionStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/contextual.json"))
        let owner = PersonalRemoteAuthorizationOwner(
            optInStore: optIn,
            credentialStore: credential,
            authorizationStateStore: InMemoryPersonalRemoteAuthorizationStateStore(
                backing: PersonalRemoteAuthorizationStateBacking()
            ),
            policy: ContextualCorrectionPolicy(),
            storeSnapshot: { store.snapshot },
            proactiveEvidenceAvailable: { true }
        )

        try owner.authorizePersonalRemote(explicitConsent: true, credential: "temporary-test-key")
        XCTAssertTrue(owner.personalRemoteHealth().canDispatch)

        let unavailable = PersonalRemoteAuthorizationOwner(
            optInStore: PersonalRemoteOptInStoreStub(),
            credentialStore: InMemoryCredentialStore(),
            authorizationStateStore: InMemoryPersonalRemoteAuthorizationStateStore(
                backing: PersonalRemoteAuthorizationStateBacking()
            ),
            policy: ContextualCorrectionPolicy(),
            storeSnapshot: { store.snapshot },
            proactiveEvidenceAvailable: { false }
        )
        XCTAssertThrowsError(
            try unavailable.authorizePersonalRemote(explicitConsent: true, credential: "temporary-test-key")
        ) { XCTAssertEqual($0 as? PersonalRemoteAuthorizationError, .locallyIneligible) }
    }
}

extension ContextualTransportCorpusTests {
    private func guardDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections")
    }

    private func validReceipt(
        confidence: Double = 0.99,
        probability: Double = 0.99,
        decisions: [ContextualDecision]? = nil
    ) -> ContextualDecisionReceipt {
        .init(
            decisions: decisions ?? [.init(
                questionID: "o1", choice: .replace, confidence: confidence,
                chosenProbability: probability, runnerUpProbability: 1 - probability
            )],
            resolvedModel: "typesafe/jev-1.14-fixture",
            inputTokens: 10,
            outputTokens: 2,
            costUSD: Decimal(string: "0.000001")
        )
    }

    func testDiagnosticAndResolverShareSemanticValidatorWithoutSideChannel() async throws {
        let validator = ContextualDecisionValidator()
        let sentence = "Reservei uma cama no rosto perto da estação."
        let occurrence = ContextualCorrectionOccurrence(
            questionID: "o1", heard: "rosto", canonical: "Hostel", ordinal: 1,
            range: sentence.range(of: "rosto")!
        )
        let rows = [
            validReceipt(),
            validReceipt(confidence: 0.89),
            validReceipt(probability: 0.5),
            validReceipt(decisions: []),
            validReceipt(decisions: [
                validReceipt().decisions[0],
                .init(questionID: "o2", choice: .replace, confidence: 1,
                      chosenProbability: 1, runnerUpProbability: 0)
            ])
        ]
        for receipt in rows {
            let resolverOutcome = validator.validate(receipt: receipt, occurrences: [occurrence])
            let diagnosticOutcome = validator.validate(receipt: receipt, occurrences: [occurrence])
            XCTAssertEqual(resolverOutcome, diagnosticOutcome)
            XCTAssertEqual(
                diagnosticOutcome.category == .replaced,
                receipt == rows[0]
            )
        }
    }

    func testSyntheticDiagnosticRunReturnsResultAndThrowsOnlySanitizedErrors() async throws {
        let fixture = try ContextualCorpusFixture.load().diagnosticFixture
        let successPolicy = ContextualCorrectionPolicy()
        let successProvider = SyntheticProviderStub(.receipt(validReceipt()))
        let success = try await SyntheticDiagnosticController(
            policy: successPolicy,
            authorization: DiagnosticAuthorizationStub(mode: .success, policy: successPolicy),
            client: successProvider,
            validator: .init(),
            fixture: fixture,
            time: ManualContextualTime()
        ).run()
        XCTAssertEqual(success.outcome.category, .replaced)
        XCTAssertEqual(success.callCount, 1)

        let rows: [(SyntheticDiagnosticError, DiagnosticAuthorizationStub.Mode, SyntheticProviderMode)] = [
            (.authorizationUnavailable, .failure, .receipt(validReceipt())),
            (.timedOut, .success, .openRouter(.timedOut)),
            (.providerRejected, .success, .openRouter(.invalidStatus(401))),
            (.transportUnavailable, .success, .openRouter(.transportUnavailable)),
            (.invalidResponse, .success, .openRouter(.malformedResponse)),
            (.cancelled, .success, .cancellation)
        ]
        for row in rows {
            let policy = ContextualCorrectionPolicy()
            let controller = SyntheticDiagnosticController(
                policy: policy,
                authorization: DiagnosticAuthorizationStub(mode: row.1, policy: policy),
                client: SyntheticProviderStub(row.2),
                validator: .init(), fixture: fixture, time: ManualContextualTime()
            )
            do {
                _ = try await controller.run()
                XCTFail("Expected \(row.0)")
            } catch {
                XCTAssertEqual(error as? SyntheticDiagnosticError, row.0)
                let reflected = String(reflecting: error)
                XCTAssertFalse(reflected.contains("test-key"))
                XCTAssertFalse(reflected.contains(fixture.input))
            }
        }
    }

    func testSyntheticDiagnosticGuardConsumesBeforeConcurrentDispatch() async throws {
        let directory = guardDirectory()
        let guardStore = SyntheticDiagnosticGuard(directoryURL: directory)
        try await guardStore.provisionAuthorizedCall()
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<10 {
                group.addTask { (try? await guardStore.consume()) != nil }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }
        XCTAssertEqual(successes, 1)
        let consumedState = await guardStore.currentState()
        XCTAssertEqual(consumedState, .ready(.consumed))
    }

    func testDiagnosticGuardCrashAfterMarkerBlocksWithoutDispatch() async throws {
        let directory = guardDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("diagnostic-authorization-provisioned-v1.json")
        try Data(#"{"schemaVersion":1,"provisioned":true}"#.utf8).write(to: marker)
        let guardStore = SyntheticDiagnosticGuard(directoryURL: directory)
        let health = await guardStore.currentState()
        XCTAssertEqual(health, .blocked)
        do { try await guardStore.provisionAuthorizedCall(); XCTFail("Expected blocked") }
        catch { XCTAssertNotNil(error as? SyntheticDiagnosticGuardError) }
    }

    func testDiagnosticGuardCrashAfterConsumedReplacementRemainsConsumed() async throws {
        let directory = guardDirectory()
        let first = SyntheticDiagnosticGuard(directoryURL: directory)
        try await first.provisionAuthorizedCall()
        try await first.consume()
        let restarted = SyntheticDiagnosticGuard(directoryURL: directory)
        let health = await restarted.currentState()
        XCTAssertEqual(health, .ready(.consumed))
        do { try await restarted.provisionAuthorizedCall(); XCTFail("Expected consumed") }
        catch { XCTAssertEqual(error as? SyntheticDiagnosticGuardError, .consumed) }
    }

    func testDiagnosticGuardCorruptUnknownOrOversizedStateBlocksWithoutDispatch() async throws {
        for row in ["corrupt", "unknown", "oversized"] {
            let directory = guardDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(#"{"schemaVersion":1,"provisioned":true}"#.utf8).write(
                to: directory.appendingPathComponent("diagnostic-authorization-provisioned-v1.json")
            )
            let state = directory.appendingPathComponent("diagnostic-authorization-v1.json")
            switch row {
            case "unknown": try Data(#"{"schemaVersion":2,"state":"available"}"#.utf8).write(to: state)
            case "oversized": try Data(repeating: 0, count: 65_537).write(to: state)
            default: try Data("broken".utf8).write(to: state)
            }
            let guardStore = SyntheticDiagnosticGuard(directoryURL: directory)
            let health = await guardStore.currentState()
            XCTAssertEqual(health, .blocked, row)
            do { try await guardStore.consume(); XCTFail("Expected blocked: \(row)") }
            catch { XCTAssertNotNil(error as? SyntheticDiagnosticGuardError) }
        }
    }

    func testDiagnosticGuardReadWriteAndReadBackFailuresBlockWithoutDispatch() async throws {
        let writeGuard = SyntheticDiagnosticGuard(
            directoryURL: guardDirectory(),
            files: FailingContextualFileOperations(.write)
        )
        do { try await writeGuard.provisionAuthorizedCall(); XCTFail("Expected write failure") }
        catch {
            let health = await writeGuard.currentState()
            XCTAssertEqual(health, .blocked)
        }

        let directory = guardDirectory()
        let healthy = SyntheticDiagnosticGuard(directoryURL: directory)
        try await healthy.provisionAuthorizedCall()
        let readGuard = SyntheticDiagnosticGuard(
            directoryURL: directory,
            files: FailingContextualFileOperations(.read)
        )
        let readHealth = await readGuard.currentState()
        XCTAssertEqual(readHealth, .blocked)
    }

    func testLocalBetaToggleNeverTouchesCredentialOrGuard() async throws {
        let preferences = ContextualOptInStoreStub(enabled: false)
        let credentials = InMemoryCredentialStore()
        let guardStore = SyntheticGuardSpy()
        let owner = SyntheticDiagnosticAuthorizationOwner(
            optInStore: preferences, credentialStore: credentials,
            guardStore: guardStore, policy: ContextualCorrectionPolicy()
        )
        try await owner.setLocalBetaEnabled(true)
        try await owner.setLocalBetaEnabled(false)
        XCTAssertEqual(preferences.writes, [true, false])
        XCTAssertTrue(credentials.snapshotCalls().isEmpty)
        let guardCalls = await guardStore.snapshotCalls()
        XCTAssertTrue(guardCalls.isEmpty)
    }

    func testDiagnosticAuthorizationOrdersConsentCredentialReadBackAndGuardFailClosed() async throws {
        let preferences = ContextualOptInStoreStub(enabled: true)
        let credentials = InMemoryCredentialStore()
        let guardStore = SyntheticGuardSpy()
        let policy = ContextualCorrectionPolicy()
        let owner = SyntheticDiagnosticAuthorizationOwner(
            optInStore: preferences, credentialStore: credentials,
            guardStore: guardStore, policy: policy
        )
        do {
            try await owner.authorizeSyntheticDiagnostic(explicitConsent: false, credential: "candidate")
            XCTFail("Expected consentRequired")
        } catch { XCTAssertEqual(error as? SyntheticDiagnosticAuthorizationError, .consentRequired) }
        XCTAssertTrue(credentials.snapshotCalls().isEmpty)
        let callsBeforeConsent = await guardStore.snapshotCalls()
        XCTAssertTrue(callsBeforeConsent.isEmpty)

        try await owner.authorizeSyntheticDiagnostic(explicitConsent: true, credential: "candidate")
        XCTAssertEqual(credentials.snapshotCalls().prefix(2), ["credential-save", "credential-load"])
        let guardHealth = await guardStore.currentState()
        XCTAssertEqual(guardHealth, .ready(.available))
        let health = await owner.currentHealth()
        XCTAssertTrue(health.diagnosticArmed)
        XCTAssertTrue(health.localBetaEnabled)
    }

    func testSyntheticDiagnosticTokenIssuedBeforeFirstAwaitAndCheckedBeforeTransportOpen() async throws {
        let fixture = try ContextualCorpusFixture.load().diagnosticFixture
        let policy = ContextualCorrectionPolicy()
        let authorization = DiagnosticAuthorizationStub(mode: .success, policy: policy)
        let provider = SyntheticProviderStub(.receipt(validReceipt()))
        _ = try await SyntheticDiagnosticController(
            policy: policy, authorization: authorization, client: provider,
            validator: .init(), fixture: fixture, time: ManualContextualTime()
        ).run()
        let token = try XCTUnwrap(authorization.tokens.first)
        XCTAssertEqual(token.scope, .syntheticDiagnostic)
        XCTAssertTrue(policy.isCurrent(token))
        let beforeOpenResults = await provider.beforeOpenResults
        XCTAssertEqual(beforeOpenResults, [true])
    }

    func testSyntheticDiagnosticInvalidationDuringConsumeLeavesConsumedAndNeverOpensTransport() async throws {
        let fixture = try ContextualCorpusFixture.load().diagnosticFixture
        for reason in [ContextualPolicyInvalidationReason.optedOut, .credentialDeleted, .appTerminated] {
            let policy = ContextualCorrectionPolicy()
            let guardStore = SyntheticDiagnosticGuard(directoryURL: guardDirectory())
            try await guardStore.provisionAuthorizedCall()
            let provider = SyntheticProviderStub(.receipt(validReceipt()))
            let authorization = ConsumingInvalidatingAuthorizationStub(
                guardStore: guardStore, policy: policy, reason: reason
            )
            do {
                _ = try await SyntheticDiagnosticController(
                    policy: policy, authorization: authorization, client: provider,
                    validator: .init(), fixture: fixture, time: ManualContextualTime()
                ).run()
                XCTFail("Expected invalidation")
            } catch { XCTAssertEqual(error as? SyntheticDiagnosticError, .authorizationUnavailable) }
            let guardHealth = await guardStore.currentState()
            let providerCalls = await provider.calls
            XCTAssertEqual(guardHealth, .ready(.consumed))
            XCTAssertEqual(providerCalls, 0)
        }

        let policy = ContextualCorrectionPolicy()
        let provider = InvalidatingBeforeOpenProvider(policy: policy)
        do {
            _ = try await SyntheticDiagnosticController(
                policy: policy,
                authorization: DiagnosticAuthorizationStub(mode: .success, policy: policy),
                client: provider, validator: .init(), fixture: fixture, time: ManualContextualTime()
            ).run()
            XCTFail("Expected before-open invalidation")
        } catch { XCTAssertEqual(error as? SyntheticDiagnosticError, .authorizationUnavailable) }
        let openCount = await provider.openCount
        XCTAssertEqual(openCount, 0)
    }

    func testSyntheticAuthorizationConsumesBeforeDispatchExactlyOnce() async throws {
        let fixture = try ContextualCorpusFixture.load().diagnosticFixture
        let preferences = ContextualOptInStoreStub(enabled: true)
        let credentials = InMemoryCredentialStore()
        let directory = guardDirectory()
        let guardStore = SyntheticDiagnosticGuard(directoryURL: directory)
        let policy = ContextualCorrectionPolicy()
        let owner = SyntheticDiagnosticAuthorizationOwner(
            optInStore: preferences, credentialStore: credentials,
            guardStore: guardStore, policy: policy
        )
        try await owner.authorizeSyntheticDiagnostic(explicitConsent: true, credential: "candidate")
        let provider = SyntheticProviderStub(.receipt(validReceipt()))
        let result = try await SyntheticDiagnosticController(
            policy: policy, authorization: owner, client: provider,
            validator: .init(), fixture: fixture, time: ManualContextualTime()
        ).run()
        XCTAssertEqual(result.callCount, 1)
        let providerCalls = await provider.calls
        let consumedHealth = await guardStore.currentState()
        XCTAssertEqual(providerCalls, 1)
        XCTAssertEqual(consumedHealth, .ready(.consumed))

        let restarted = SyntheticDiagnosticGuard(directoryURL: directory)
        let restartedHealth = await restarted.currentState()
        XCTAssertEqual(restartedHealth, .ready(.consumed))
        do {
            try await owner.authorizeSyntheticDiagnostic(explicitConsent: true, credential: "candidate")
            XCTFail("Consumed guard must not rearm")
        } catch {
            let ownerHealth = await owner.currentHealth()
            XCTAssertFalse(ownerHealth.diagnosticArmed)
        }
    }
}

struct ContextualCorpusMetrics: Codable, Equatable {
    let total: Int
    let correct: Int
    let falsePositives: Int
    let safetyEvaluatedCases: Int
    let unauthorizedMutations: Int
    let harmfulSpanChanges: Int
    let eligiblePositives: Int
    let correctPositives: Int
    let abstentions: Int
    let correctionRecall: Double
}

struct ContextualCorpusPairReport: Codable, Equatable {
    let pair: String
    let contextual: ContextualCorpusMetrics
    let keepOriginal: ContextualCorpusMetrics
    let globalReplacement: ContextualCorpusMetrics
    let minimumDecisionMargin: Double?
    let medianDecisionMargin: Double?
}

struct ContextualCorpusFamilyReport: Codable, Equatable {
    let family: String
    let contextual: ContextualCorpusMetrics
    let keepOriginal: ContextualCorpusMetrics
    let globalReplacement: ContextualCorpusMetrics
}

struct ContextualCorpusReport: Codable, Equatable {
    let schemaVersion: Int
    let corpusVersion: String
    let generatedBy: String
    let contextual: ContextualCorpusMetrics
    let keepOriginal: ContextualCorpusMetrics
    let globalReplacement: ContextualCorpusMetrics
    let families: [ContextualCorpusFamilyReport]
    let pairs: [ContextualCorpusPairReport]
}

private enum ContextualCorpusProviderFailure: Error { case configured }

private actor ContextualCorpusDecisionProvider: ContextualDecisionProvider {
    let outcome: ContextualCorpusFixture.Outcome

    init(outcome: ContextualCorpusFixture.Outcome) { self.outcome = outcome }

    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        switch outcome.kind {
        case .decisions:
            let decisions = occurrences.compactMap { occurrence -> ContextualDecision? in
                guard let answer = outcome.answers.first(where: { $0.ordinal == occurrence.ordinal }) else {
                    return nil
                }
                return .init(
                    questionID: occurrence.questionID,
                    choice: answer.choice == .replace ? .replace : .keepOriginal,
                    confidence: answer.confidence,
                    chosenProbability: answer.chosenProbability,
                    runnerUpProbability: answer.runnerUpProbability
                )
            }
            return .init(
                decisions: decisions,
                resolvedModel: "fixture/deterministic",
                inputTokens: nil,
                outputTokens: nil,
                costUSD: nil
            )
        case .malformed:
            return .init(
                decisions: [], resolvedModel: "fixture/malformed",
                inputTokens: nil, outputTokens: nil, costUSD: nil
            )
        default:
            throw ContextualCorpusProviderFailure.configured
        }
    }
}

@MainActor
private enum ContextualCorpusRunner {
    private struct Observation {
        let item: ContextualCorpusFixture.Case
        let contextual: String
        let keep: String
        let global: String
        let margins: [Double]
    }

    private struct Analysis {
        let unauthorized: Int
        let harmful: Int
    }

    static func runBundledFixture(
        seedObserver: ((String, [String]) -> Void)? = nil
    ) async throws -> ContextualCorpusReport {
        let fixture = try ContextualCorpusFixture.load()
        guard fixture.validate() else { throw ContextualCorpusProviderFailure.configured }
        let learningByID = Dictionary(uniqueKeysWithValues: fixture.learningExamples.map { ($0.id, $0) })
        var observations: [Observation] = []
        for item in fixture.cases.sorted(by: { $0.id < $1.id }) {
            let mapped = try item.learningExampleIDs.map { try XCTUnwrap(learningByID[$0]) }
            seedObserver?(item.id, mapped.map(\.id))
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections/v1.json")
            let store = ContextualCorrectionStore(fileURL: file)
            for learning in mapped {
                XCTAssertTrue(store.save(.init(
                    id: UUID(), language: learning.language, heard: learning.heard,
                    canonical: learning.canonical, sentence: learning.sentence,
                    occurrenceOrdinal: learning.ordinal
                )).isSuccess, item.id)
            }
            let policy = ContextualCorrectionPolicy()
            let provider = ContextualCorpusDecisionProvider(outcome: item.providerOutcome)
            let resolver = ContextualCorrectionResolver(
                store: store,
                policy: policy,
                provider: provider,
                storeGeneration: { store.generation },
                time: ManualContextualTime()
            )
            let result = await resolver.resolveWithTrace(.init(
                attemptID: UUID(), text: item.input, language: item.language,
                policyToken: policy.issueToken(scope: .testDouble),
                storeGenerationAtStart: store.generation
            ))
            observations.append(.init(
                item: item,
                contextual: result.text,
                keep: item.input,
                global: TranscriptPostprocessor.process(
                    item.input,
                    glossary: TranscriptionGlossary(text: "\(item.heard) = \(item.canonical)")
                ),
                margins: result.outcome.decisions.map(\.margin)
            ))
        }
        let report = makeReport(fixture: fixture, observations: observations)
        if let path = ProcessInfo.processInfo.environment["CONTEXTUAL_CORPUS_REPORT_PATH"] {
            let data = try JSONEncoder.sorted.encode(report)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        return report
    }

    static func analyze(input: String, expected: String, output: String, heard: String, canonical: String) -> (Int, Int) {
        let ranges = wholeTermRanges(heard, in: input)
        guard let expectedMask = uniqueMask(rendering: expected, input: input, ranges: ranges, canonical: canonical),
              let outputMask = uniqueMask(rendering: output, input: input, ranges: ranges, canonical: canonical) else {
            return output == expected ? (0, 0) : (1, max(1, ranges.count))
        }
        let harmful = outputMask.enumerated().filter { $0.element && !expectedMask[$0.offset] }.count
        return (harmful > 0 ? 1 : 0, harmful)
    }

    private static func makeReport(
        fixture: ContextualCorpusFixture,
        observations: [Observation]
    ) -> ContextualCorpusReport {
        let positives = Set(fixture.evaluationPositiveIDs)
        let contextual = metrics(observations, output: \.contextual, positives: positives)
        let keep = metrics(observations, output: \.keep, positives: positives)
        let global = metrics(observations, output: \.global, positives: positives)
        let families = Set(observations.map { $0.item.family.rawValue }).sorted().map { family in
            let rows = observations.filter { $0.item.family.rawValue == family }
            return ContextualCorpusFamilyReport(
                family: family,
                contextual: metrics(rows, output: \.contextual, positives: positives),
                keepOriginal: metrics(rows, output: \.keep, positives: positives),
                globalReplacement: metrics(rows, output: \.global, positives: positives)
            )
        }
        let pairs = Set(observations.map { $0.item.pairID }).sorted().map { pair in
            let rows = observations.filter { $0.item.pairID == pair }
            let margins = rows.flatMap(\.margins).sorted()
            return ContextualCorpusPairReport(
                pair: pair,
                contextual: metrics(rows, output: \.contextual, positives: positives),
                keepOriginal: metrics(rows, output: \.keep, positives: positives),
                globalReplacement: metrics(rows, output: \.global, positives: positives),
                minimumDecisionMargin: margins.first,
                medianDecisionMargin: margins.isEmpty ? nil : margins[margins.count / 2]
            )
        }
        return .init(
            schemaVersion: 1,
            corpusVersion: fixture.corpusVersion,
            generatedBy: "WhisperKeyTests.ContextualCorpusRunner/v1",
            contextual: contextual,
            keepOriginal: keep,
            globalReplacement: global,
            families: families,
            pairs: pairs
        )
    }

    private static func metrics(
        _ rows: [Observation],
        output: KeyPath<Observation, String>,
        positives: Set<String>
    ) -> ContextualCorpusMetrics {
        var correct = 0
        var falsePositives = 0
        var safety = 0
        var unauthorized = 0
        var harmful = 0
        var eligible = 0
        var correctPositive = 0
        var abstentions = 0
        for row in rows {
            let value = row[keyPath: output]
            if value == row.item.expected { correct += 1 }
            if row.item.family == .evaluation {
                safety += 1
                let analysis = analyze(
                    input: row.item.input,
                    expected: row.item.expected,
                    output: value,
                    heard: row.item.heard,
                    canonical: row.item.canonical
                )
                unauthorized += analysis.0
                harmful += analysis.1
                if row.item.expected == row.item.input, value != row.item.input { falsePositives += 1 }
                if positives.contains(row.item.id) {
                    eligible += 1
                    if value == row.item.expected { correctPositive += 1 }
                    if value == row.item.input { abstentions += 1 }
                } else if value == row.item.input,
                          row.item.group == .ambiguous || row.item.providerOutcome.kind != .decisions {
                    abstentions += 1
                }
            }
        }
        return .init(
            total: rows.count,
            correct: correct,
            falsePositives: falsePositives,
            safetyEvaluatedCases: safety,
            unauthorizedMutations: unauthorized,
            harmfulSpanChanges: harmful,
            eligiblePositives: eligible,
            correctPositives: correctPositive,
            abstentions: abstentions,
            correctionRecall: eligible == 0 ? 0 : Double(correctPositive) / Double(eligible)
        )
    }

    private static func wholeTermRanges(_ term: String, in input: String) -> [Range<String.Index>] {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        )
        return regex?.matches(
            in: input,
            range: NSRange(input.startIndex..<input.endIndex, in: input)
        ).compactMap { Range($0.range, in: input) } ?? []
    }

    private static func uniqueMask(
        rendering target: String,
        input: String,
        ranges: [Range<String.Index>],
        canonical: String
    ) -> [Bool]? {
        guard ranges.count < Int.bitWidth else { return nil }
        var found: [[Bool]] = []
        for rawMask in 0..<(1 << ranges.count) {
            let mask = ranges.indices.map { rawMask & (1 << $0) != 0 }
            var rendered = input
            for index in ranges.indices.reversed() where mask[index] {
                rendered.replaceSubrange(ranges[index], with: canonical)
            }
            if rendered == target { found.append(mask) }
        }
        return found.count == 1 ? found[0] : nil
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension ContextualResolverTests {
    func testProactiveAlternativesMustUseContiguousOptionIDs() throws {
        let text = "Reservei o quarto 12."
        let range = try XCTUnwrap(text.range(of: "quarto 12"))
        let receipt = ContextualDecisionReceipt(
            decisions: [.init(
                questionID: "o1", choice: .keepOriginal, confidence: 0.99,
                chosenProbability: 0.99, runnerUpProbability: 0.01
            )],
            resolvedModel: "test", inputTokens: nil, outputTokens: nil, costUSD: nil
        )
        let invalidID = ContextualCorrectionOccurrence(
            questionID: "o1", heard: "quarto 12", canonical: "quarto 12",
            alternatives: [
                .init(id: "replace_2", value: "quarto 12", source: .acoustic)
            ],
            ordinal: 1, range: range
        )
        XCTAssertNil(ContextualCorrectionResolver.applying(
            receipt: receipt, occurrences: [invalidID], to: text
        ))
    }
}

extension ContextualTransportCorpusTests {
    func testJevRequestAndReceiptUseOnlySuppliedReplacementOptions() throws {
        let sentence = "Reservei uma cama no rosto."
        let range = try XCTUnwrap(sentence.range(of: "rosto"))
        let occurrence = ContextualCorrectionOccurrence(
            questionID: "o1", heard: "rosto", canonical: "Hostel",
            alternatives: [
                .init(id: "replace_1", value: "Hostel", source: .acoustic),
                .init(id: "replace_2", value: "posto", source: .acoustic),
                .init(id: "replace_3", value: "rosto", source: .acoustic)
            ],
            ordinal: 1, range: range
        )
        let dto = OpenRouterDecisionsClient.requestDTO(
            sentence: sentence, language: "pt", occurrences: [occurrence]
        )
        XCTAssertEqual(Set(try XCTUnwrap(dto.questions["o1"]?.criteria.keys)), Set([
            "keep_original", "replace_1", "replace_2", "replace_3"
        ]))

        let response = Data(#"{"model":"typesafe/jev-1.14","answers":{"o1":{"type":"choice","choice":"replace_2","probabilities":{"keep_original":0.01,"replace_1":0.02,"replace_2":0.96,"replace_3":0.01},"confidence":0.97}}}"#.utf8)
        let receipt = try OpenRouterDecisionsClient.receipt(from: response, occurrences: [occurrence])
        XCTAssertEqual(receipt.decisions.first?.choice.rawValue, "replace_2")
        XCTAssertEqual(receipt.decisions.first?.runnerUpProbability, 0.02)
        XCTAssertEqual(
            ContextualCorrectionResolver.applying(receipt: receipt, occurrences: [occurrence], to: sentence),
            "Reservei uma cama no posto."
        )
    }

    func testJevReceiptRejectsUnknownMissingAndExtraChoices() throws {
        let sentence = "Reservei uma cama no rosto."
        let range = try XCTUnwrap(sentence.range(of: "rosto"))
        let occurrence = ContextualCorrectionOccurrence(
            questionID: "o1", heard: "rosto", canonical: "Hostel",
            alternatives: [
                .init(id: "replace_1", value: "Hostel", source: .acoustic),
                .init(id: "replace_2", value: "posto", source: .acoustic)
            ],
            ordinal: 1, range: range
        )
        let probabilityObjects = [
            #"{"keep_original":0.01,"replace_1":0.01,"replace_2":0.97,"replace_3":0.01}"#,
            #"{"keep_original":0.01,"replace_2":0.99}"#,
            #"{"keep_original":0.01,"replace_1":0.01,"replace_2":0.98,"extra":0.0}"#
        ]
        let choices = ["replace_3", "replace_2", "replace_2"]
        for (choice, probabilities) in zip(choices, probabilityObjects) {
            let response = Data("""
                {"model":"typesafe/jev-1.14","answers":{"o1":{"type":"choice","choice":"\(choice)","probabilities":\(probabilities),"confidence":0.99}}}
                """.utf8)
            XCTAssertThrowsError(try OpenRouterDecisionsClient.receipt(
                from: response, occurrences: [occurrence]
            )) { error in
                XCTAssertEqual(error as? OpenRouterDecisionsError, .malformedResponse)
            }
        }

        let unsupported = ContextualDecisionReceipt(
            decisions: [.init(
                questionID: "o1", choice: .init(rawValue: "replace_3"), confidence: 0.99,
                chosenProbability: 0.99, runnerUpProbability: 0.01
            )],
            resolvedModel: "test", inputTokens: nil, outputTokens: nil, costUSD: nil
        )
        XCTAssertEqual(
            ContextualDecisionValidator().validate(receipt: unsupported, occurrences: [occurrence]).category,
            .abstained
        )
    }
}

extension ContextualTransportCorpusTests {
    func testContextualCorpusRunnerEvaluatesAllCasesAndBaselinesDeterministically() async throws {
        let first = try await ContextualCorpusRunner.runBundledFixture()
        let second = try await ContextualCorpusRunner.runBundledFixture()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.contextual.total, 100)
        let evaluation = try XCTUnwrap(first.families.first { $0.family == "evaluation" })
        XCTAssertEqual(evaluation.contextual.falsePositives, 0)
        XCTAssertEqual(evaluation.contextual.safetyEvaluatedCases, evaluation.contextual.total)
        XCTAssertEqual(evaluation.contextual.unauthorizedMutations, 0)
        XCTAssertEqual(evaluation.contextual.harmfulSpanChanges, 0)
        XCTAssertEqual(evaluation.contextual.eligiblePositives, 20)
        XCTAssertGreaterThanOrEqual(evaluation.contextual.correctionRecall, 0.80)
        XCTAssertEqual(first.families.first { $0.family == "calibration" }?.contextual.eligiblePositives, 0)
        XCTAssertEqual(first.families.map(\.family), first.families.map(\.family).sorted())
        XCTAssertEqual(first.pairs.map(\.pair), first.pairs.map(\.pair).sorted())
        for pair in first.pairs {
            XCTAssertEqual(pair.contextual.unauthorizedMutations, 0, pair.pair)
            XCTAssertEqual(pair.contextual.harmfulSpanChanges, 0, pair.pair)
        }
    }

    func testCorpusRunnerSeedsStoreOnlyFromMappedLearningExamples() async throws {
        let fixture = try ContextualCorpusFixture.load()
        let expected = Dictionary(uniqueKeysWithValues: fixture.cases.map { ($0.id, $0.learningExampleIDs) })
        var observed: [String: [String]] = [:]
        _ = try await ContextualCorpusRunner.runBundledFixture { observed[$0] = $1 }
        XCTAssertEqual(observed, expected)
        XCTAssertFalse(observed.values.flatMap { $0 }.contains(SyntheticDiagnosticFixture.id))
    }

    func testCorpusGateRejectsMixedCaseThatChangesUnauthorizedSpan() {
        let input = "Lavei o rosto no banheiro do rosto"
        let expected = "Lavei o rosto no banheiro do Hostel"
        let harmful = "Lavei o Hostel no banheiro do Hostel"
        let analysis = ContextualCorpusRunner.analyze(
            input: input, expected: expected, output: harmful,
            heard: "rosto", canonical: "Hostel"
        )
        XCTAssertEqual(analysis.0, 1)
        XCTAssertEqual(analysis.1, 1)
    }
}
