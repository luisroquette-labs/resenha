import AppKit
import XCTest
import SwiftUI
@testable import WhisperKey

final class WhisperKeyTests: XCTestCase {
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
        XCTAssertEqual(preferences.transcriptionLanguage, .portuguese)
        XCTAssertTrue(preferences.transcriptionGlossary.contains("Resenha"))
        XCTAssertEqual(preferences.readySoundID, 60)
        var changed: HotkeyShortcut?
        preferences.onShortcutChange = { changed = $0 }
        let customShortcut = HotkeyShortcut(keyCode: 40, flags: [.maskControl, .maskShift], keyLabel: "K")
        preferences.shortcut = customShortcut
        preferences.showsHUD = false
        preferences.soundsEnabled = false
        preferences.keepsHistory = false
        preferences.transcriptionLanguage = .spanish
        preferences.transcriptionGlossary = "coisa = COESA"
        preferences.readySoundID = 3
        XCTAssertEqual(changed, customShortcut)
        let restored = ProductPreferences(defaults: defaults)
        XCTAssertEqual(restored.shortcut, customShortcut)
        XCTAssertFalse(restored.showsHUD)
        XCTAssertFalse(restored.soundsEnabled)
        XCTAssertFalse(restored.keepsHistory)
        XCTAssertEqual(restored.transcriptionLanguage, .spanish)
        XCTAssertEqual(restored.transcriptionGlossary, "coisa = COESA")
        XCTAssertEqual(restored.readySoundID, 3)
        XCTAssertEqual(restored.readySound.name, "Pum seco")
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
            XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: pair.0, canonical: pair.1, existingText: ""),
                           .invalid(.empty))
        }
        for invalid in ["nome\n", "\rnome", "no\u{2028}me", "no=me"] {
            XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: invalid, canonical: "Nome", existingText: ""),
                           .invalid(.invalidCharacters))
            XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "nome", canonical: invalid, existingText: ""),
                           .invalid(.invalidCharacters))
        }
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: " nome ", canonical: "nome", existingText: ""),
                       .invalid(.identical))
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: " nome ", canonical: " Nome ", existingText: ""),
                       .added(text: "nome = Nome"))
        for existing in ["  anterior = Anterior  ", "anterior = Anterior\n", "anterior = Anterior\r\n"] {
            let separator = existing.last?.isNewline == true ? "" : "\n"
            XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: " coisa ", canonical: " COESA ", existingText: existing),
                           .added(text: existing + separator + "coisa = COESA"))
        }
    }

    func testCorrectionCandidateFindsConflictsAndOnlyAcceptsEffectiveDuplicates() {
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "COISA", canonical: "COESA", existingText: "coisa = COESA"),
                       .alreadyExists)
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "coesa", canonical: "COESA", existingText: "COESA"),
                       .alreadyExists)
        for existing in ["Coisa = Outra", "coisa = COESA\nCOISA = Outra", "Coisa", "outro = Coisa"] {
            guard case .invalid(.conflict) = TranscriptionGlossary.correctionCandidate(
                heard: "coisa", canonical: "COESA", existingText: existing
            ) else { return XCTFail("Conflito não identificado: \(existing)") }
        }
        let full = Array(repeating: "termo", count: 200).joined(separator: "\n")
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(
            heard: "coisa", canonical: "COESA", existingText: full + "\ncoisa = COESA"
        ), .invalid(.entryLimit))
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(
            heard: "coisa", canonical: "COESA", existingText: "coisa = COESA\n" + full + "\nCOISA = Outra"
        ), .invalid(.conflict(existingCanonical: "Outra")))
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(
            heard: "coisa", canonical: "COESA", existingText: "coisa = COESA\n" + full
        ), .alreadyExists)
        // ICU case folding matches the replacement engine, including the Kelvin sign.
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(
            heard: "K", canonical: "Kelvin", existingText: "K = Outra"
        ), .invalid(.conflict(existingCanonical: "Outra")))
    }

    func testCorrectionCandidateExactLineEntryTextAndPromptBoundaries() {
        let canonical157 = String(repeating: "á", count: 156)
        XCTAssertEqual(("x = " + canonical157).count, 160)
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "x", canonical: canonical157, existingText: ""),
                       .added(text: "x = " + canonical157))
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "x", canonical: canonical157 + "á", existingText: ""),
                       .invalid(.lineLimit))
        let entries199 = Array(repeating: "termo", count: 199).joined(separator: "\n")
        guard case .added(let at200) = TranscriptionGlossary.correctionCandidate(
            heard: "x", canonical: "Y", existingText: entries199
        ) else { return XCTFail("A entrada 200 deve ser aceita antes da deduplicação") }
        XCTAssertEqual(TranscriptionGlossary(text: at200).terms.count, 2)
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "x", canonical: "Y", existingText: entries199 + "\ntermo"),
                       .invalid(.entryLimit))
        let textPrefix = String(repeating: " ", count: 19_992) + "\n"
        guard case .added(let at20000) = TranscriptionGlossary.correctionCandidate(
            heard: "x", canonical: "YES", existingText: textPrefix
        ) else { return XCTFail("20.000 caracteres devem ser aceitos") }
        XCTAssertEqual(at20000.count, 20_000)
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(
            heard: "x", canonical: "YES", existingText: " " + textPrefix
        ), .invalid(.textLimit))

        let terms = (0..<50).map { String(format: "%02d", $0) + String(repeating: "a", count: 155) }
        let existing = terms.joined(separator: "\n")
        let finalTerm = String(repeating: "z", count: 50)
        guard case .added(let at8000) = TranscriptionGlossary.correctionCandidate(
            heard: "x", canonical: finalTerm, existingText: existing
        ) else { return XCTFail("8.000 caracteres de prompt devem ser aceitos") }
        XCTAssertEqual(TranscriptionGlossary(text: at8000).terms.joined(separator: ", ").count, 8_000)
        XCTAssertEqual(TranscriptionGlossary.correctionCandidate(heard: "x", canonical: finalTerm + "z", existingText: existing),
                       .invalid(.promptLimit))
    }

    func testCorrectionCandidateKeepsEscapingUnicodeWholeTermsAndExistingCascade() {
        for pair in [("cifrão", "$COESA"), ("barra", #"C:\COESA"#), ("eriq", "Éric"), ("whisper.cp", "whisper.cpp")] {
            guard case .added(let text) = TranscriptionGlossary.correctionCandidate(
                heard: pair.0, canonical: pair.1, existingText: ""
            ) else { return XCTFail("Par representável recusado") }
            XCTAssertEqual(TranscriptPostprocessor.process("A \(pair.0) chegou.", glossary: .init(text: text)),
                           "A \(pair.1) chegou.")
        }
        guard case .added(let text) = TranscriptionGlossary.correctionCandidate(
            heard: "erro longo", canonical: "curto", existingText: "curto = Final"
        ) else { return XCTFail("Cascata legada deve permanecer") }
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
        XCTAssertEqual(preferences.transcriptionGlossary, " anterior = Anterior \nCoisa Energia = COESA Energia")
        let restored = ProductPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(restored.transcriptionGlossary, preferences.transcriptionGlossary)
        XCTAssertEqual(TranscriptPostprocessor.process(
            "A Coisa Energia chegou. Coisa Energias ficou.", glossary: .init(text: restored.transcriptionGlossary)
        ), "A COESA Energia chegou. Coisa Energias ficou.")
        var after = defaults.persistentDomain(forName: suite) ?? [:]
        after.removeValue(forKey: "resenha.transcriptionGlossary")
        var otherBefore = before
        otherBefore.removeValue(forKey: "resenha.transcriptionGlossary")
        XCTAssertEqual(after as NSDictionary, otherBefore as NSDictionary)
        XCTAssertFalse(restored.keepsHistory)
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa energia", canonical: "COESA Energia"), .alreadyExists)
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "", canonical: "COESA"), .invalid(.empty))
        XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa energia", canonical: "Outra"),
                       .invalid(.conflict(existingCanonical: "COESA Energia")))
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
            XCTAssertEqual(preferences.transcriptionGlossary, previous + "\ncoisa = COESA")
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa", canonical: "COESA"), .alreadyExists)
            XCTAssertEqual(preferences.saveTranscriptionCorrection(heard: "coisa", canonical: "Outra"),
                           .invalid(.conflict(existingCanonical: "COESA")))
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

        for section in ProductSettingsSection.allCases {
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let view = NSHostingView(rootView: ProductSettingsView(
                    preferences: preferences,
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
        let controller = ProductSettingsWindowController(preferences: ProductPreferences())
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
        coordinator.completeInsertion(attemptID: original, isCancelled: false)
        XCTAssertTrue(completed.isEmpty)
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: original, isCancelled: true)
        coordinator.completeInsertion(attemptID: UUID(), isCancelled: false)
        XCTAssertTrue(completed.isEmpty)
        coordinator.cancel()
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: original, isCancelled: false)
        XCTAssertEqual(coordinator.phase, .inserting, "A post-await stale completion cannot reset the next attempt")
        let current = coordinator.attemptID
        coordinator.completeInsertion(attemptID: current, isCancelled: false)
        XCTAssertEqual(completed, [current])
        coordinator.completeInsertion(attemptID: current, isCancelled: false)
        XCTAssertEqual(completed, [current])
        showsHUD = false
        coordinator.transition(to: .recording)
        coordinator.transition(to: .transcribing)
        coordinator.transition(to: .inserting)
        coordinator.completeInsertion(attemptID: coordinator.attemptID, isCancelled: false)
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
        let first = DictationCompletion(id: UUID(), targetApplication: nil)
        panel.offerFeedback(first)
        XCTAssertTrue(panel.hasFeedback)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertNotNil(panel.dismissal.deadline)
        panel.dismissIfCurrent(generation: timer, now: .greatestFiniteMagnitude)
        XCTAssertEqual(panel.feedbackToken, first.id)
        panel.approveFeedback(token: first.id)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertTrue(panel.ignoresMouseEvents)
        let next = DictationCompletion(id: UUID(), targetApplication: nil)
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
        panel.onFeedbackChange = { menuToken = panel.approvalActionToken }
        let first = DictationCompletion(id: UUID(), targetApplication: nil)
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
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil))
        let oldGeneration = panel.dismissal.generation
        now = 102
        let next = UUID()
        panel.offerFeedback(.init(id: next, targetApplication: nil))
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
        for state in [FloatingStatus.listening, .feedbackNotice("Regra salva")] {
            panel.offerFeedback(.init(id: UUID(), targetApplication: nil))
            let generation = panel.dismissal.generation
            panel.show(state)
            panel.dismissIfCurrent(generation: generation, now: .greatestFiniteMagnitude)
            XCTAssertEqual(panel.status, state)
            XCTAssertTrue(panel.isVisible)
            XCTAssertFalse(panel.hasFeedback)
        }
        panel.offerFeedback(.init(id: UUID(), targetApplication: nil))
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
    func testCorrectionExplicitSavePreservesDraftOnValidationAndRollbackThenConsumesOnce() throws {
        let suite = "ResenhaFeedbackSave.\(UUID())"
        let defaults = try XCTUnwrap(CorrectionDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let panel = FloatingPanelController()
        panel.configureFeedback(preferences: preferences)
        let context = DictationCompletion(id: UUID(), targetApplication: nil)
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
        XCTAssertTrue(panel.status.title.contains("Regra salva"))
        let writes = defaults.glossaryWrites
        panel.saveCorrection(token: context.id)
        XCTAssertEqual(defaults.glossaryWrites, writes)
        let repeated = DictationCompletion(id: UUID(), targetApplication: nil)
        panel.offerFeedback(repeated)
        panel.openCorrection(token: repeated.id)
        panel.updateCorrectionDraft(token: repeated.id, heard: "Coisa Energia", canonical: "COESA Energia")
        panel.saveCorrection(token: repeated.id)
        XCTAssertTrue(panel.status.title.contains("Regra já existente"))
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
        panel.offerFeedback(.init(id: original, targetApplication: nil))
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
        XCTAssertEqual(panel.correctionDraft?.heard, "Coisa")
        XCTAssertNil(panel.approvalActionToken)
        let recovery = try XCTUnwrap(panel.correctionActionToken)
        defaults.unreadable = true
        panel.openCorrection(token: recovery)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertFalse(panel.canSaveCorrection)
        XCTAssertNil(panel.feedbackToken)
        panel.saveCorrection(token: original)
        panel.saveCorrection(token: recovery)
        panel.cancelFeedback(token: recovery, restoreFocus: false)
        let retry = try XCTUnwrap(panel.correctionActionToken)
        XCTAssertNotEqual(retry, recovery)
        defaults.unreadable = false
        defaults.rejectRestoration = false
        panel.openCorrection(token: retry)
        let renewed = try XCTUnwrap(panel.feedbackToken)
        XCTAssertNotEqual(renewed, original)
        XCTAssertTrue(panel.canSaveCorrection)
        XCTAssertEqual(panel.correctionDraft?.canonical, "COESA")
        panel.cancelFeedback(token: recovery)
        panel.saveCorrection(token: original)
        XCTAssertTrue(panel.isEditingCorrection)
        XCTAssertEqual(defaults.glossaryWrites, writes)
        XCTAssertEqual(defaults.glossaryRemovals, removals)
        panel.saveCorrection(token: renewed)
        XCTAssertFalse(panel.hasFeedback)
        XCTAssertTrue(panel.status.title.contains("Regra já existente"))
        XCTAssertEqual(defaults.glossaryWrites, writes)
        panel.hide()
    }

    @MainActor
    func testFeedbackHotkeySelfReleaseExternalAndAltTabUseRealRoutingSeam() throws {
        let app = AppDelegate()
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: app.panel)
        app.observeCoordinator(coordinator)
        let original = UUID()
        app.panel.offerFeedback(.init(id: original, targetApplication: nil))
        XCTAssertTrue(app.acceptHotkeyPress(targetIsSelf: false), "An ignored offer retires on the same accepted press")
        XCTAssertFalse(app.panel.hasFeedback)
        app.handleHotkeyRelease()
        let editing = UUID()
        app.panel.offerFeedback(.init(id: editing, targetApplication: nil))
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
        app.panel.offerFeedback(.init(id: altTab, targetApplication: nil))
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
        app.panel.offerFeedback(.init(id: original, targetApplication: nil))
        menu.updateFeedback(approvalToken: app.panel.approvalActionToken, correctionToken: app.panel.correctionActionToken)
        let oldApprove = try XCTUnwrap(menu.approvalMenuItem)
        let oldCorrect = try XCTUnwrap(menu.correctionMenuItem)
        XCTAssertTrue(oldApprove.isEnabled)
        let current = UUID()
        app.panel.offerFeedback(.init(id: current, targetApplication: nil))
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
        app.panel.offerFeedback(.init(id: UUID(), targetApplication: nil))
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
            app.panel.offerFeedback(.init(id: token, targetApplication: nil))
            app.panel.openCorrection(token: token)
            app.panel.updateCorrectionDraft(token: token, heard: "Coisa", canonical: "COESA")
            defaults.divergeAfterWrite = true
            defaults.rejectRestoration = true
            app.panel.saveCorrection(token: token)
            if event == 0 {
                XCTAssertFalse(app.acceptHotkeyPress(targetIsSelf: true))
                XCTAssertFalse(app.panel.isEditingCorrection)
                XCTAssertNotNil(app.panel.correctionDraft)
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
        for message in ["Regra salva", "Regra já existente", "Solte e pressione novamente para ditar"] {
            let notice = FloatingStatus.feedbackNotice(message)
            XCTAssertEqual(notice.title, message)
            XCTAssertEqual(notice.accessibilityLabel, message)
            XCTAssertEqual(notice.symbol, "info.circle")
            XCTAssertFalse(notice.isFailure)
        }
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
        XCTAssertEqual(FloatingStatusView.panelSize(for: .feedbackNotice("Regra salva"), available: smallScreen),
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
        XCTAssertEqual(FeedbackBubbleMotion.visualSize, 36)
        XCTAssertEqual(FeedbackBubbleMotion.duration, 4)

        let firstEntry = FeedbackBubbleMotion.state(elapsed: 0.1, index: 0, reduceMotion: false)
        let secondEntry = FeedbackBubbleMotion.state(elapsed: 0.1, index: 1, reduceMotion: false)
        XCTAssertGreaterThan(firstEntry.opacity, secondEntry.opacity)
        XCTAssertLessThan(firstEntry.offset, secondEntry.offset)

        let settled = FeedbackBubbleMotion.state(elapsed: 1, index: 1, reduceMotion: false)
        XCTAssertEqual(settled, FeedbackBubbleVisualState(opacity: 1, offset: 0, bubbleScale: 1))
        let exiting = FeedbackBubbleMotion.state(elapsed: 4, index: 0, reduceMotion: false)
        XCTAssertEqual(exiting.opacity, 0)
        XCTAssertEqual(exiting.offset, -14)
        XCTAssertEqual(exiting.bubbleScale, 1.04)
        XCTAssertLessThanOrEqual(
            FeedbackBubbleMotion.visualSize * exiting.bubbleScale,
            FeedbackBubbleMotion.targetSize
        )

        for time in [TimeInterval.nan, -1, 0, 0.5, 3.5, 4, 8] {
            let animated = FeedbackBubbleMotion.state(elapsed: time, index: 0, reduceMotion: false)
            XCTAssertTrue(animated.opacity.isFinite)
            XCTAssertTrue(animated.offset.isFinite)
            XCTAssertTrue(animated.bubbleScale.isFinite)
            XCTAssertTrue((0...1).contains(animated.opacity))
            XCTAssertTrue((-14...10).contains(animated.offset))
            XCTAssertTrue((0.84...1.04).contains(animated.bubbleScale))

            let reduced = FeedbackBubbleMotion.state(elapsed: time, index: 1, reduceMotion: true)
            XCTAssertEqual(reduced.offset, 0)
            XCTAssertEqual(reduced.bubbleScale, 1)
            XCTAssertTrue((0...1).contains(reduced.opacity))
        }
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

    func testEmbeddedWhisperTranscribesOfficialFixtureWhenLocalModelIsAvailable() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let model = home.appendingPathComponent(
            "Library/Application Support/WhisperKey/Models/ggml-small-q5_1.bin"
        )
        guard FileManager.default.fileExists(atPath: model.path) else {
            throw XCTSkip("Local Whisper model is not installed")
        }

        let fixture = try XCTUnwrap(
            Bundle(for: WhisperKeyTests.self).url(forResource: "jfk", withExtension: "wav")
        )

        let transcript = try WhisperTranscriber().transcribe(
            audioURL: fixture,
            language: .english,
            glossaryText: ""
        ).lowercased()

        XCTAssertTrue(transcript.contains("fellow americans"), transcript)
        XCTAssertTrue(transcript.contains("country"), transcript)
    }

    func testWhisperRuntimePolicyHasAnExactBound() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        XCTAssertFalse(WhisperRuntimePolicy.hasTimedOut(
            startedAt: startedAt,
            now: Date(timeIntervalSinceReferenceDate: 699.999),
            maximumRuntime: 600
        ))
        XCTAssertTrue(WhisperRuntimePolicy.hasTimedOut(
            startedAt: startedAt,
            now: Date(timeIntervalSinceReferenceDate: 700),
            maximumRuntime: 600
        ))
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
            ("feedback", .feedback), ("feedback-saved", .feedbackNotice("Regra salva")),
            ("feedback-existing", .feedbackNotice("Regra já existente")),
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
