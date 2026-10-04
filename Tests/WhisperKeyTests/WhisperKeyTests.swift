import AppKit
import XCTest
import SwiftUI
@testable import WhisperKey

private final class WhisperLifecycleProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var loads = 0
    private var releases = 0
    private var activeUses = 0
    private var maximumConcurrentUses = 0

    func load(path: String) -> OpaquePointer? {
        lock.withLock { loads += 1 }
        return OpaquePointer(bitPattern: 1)
    }

    func release(_ context: OpaquePointer) {
        lock.withLock { releases += 1 }
    }

    func beginUse() {
        lock.withLock {
            activeUses += 1
            maximumConcurrentUses = max(maximumConcurrentUses, activeUses)
        }
    }

    func endUse() {
        lock.withLock { activeUses -= 1 }
    }

    var snapshot: (loads: Int, releases: Int, maximumConcurrentUses: Int) {
        lock.withLock { (loads, releases, maximumConcurrentUses) }
    }
}

final class WhisperKeyTests: XCTestCase {
    private func localWhisperTestModel() throws -> URL {
        let isolatedModel = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperKey/Models/ggml-small-q5_1.bin")
        guard FileManager.default.fileExists(atPath: isolatedModel.path) else {
            throw XCTSkip("O teste cooperativo exige uma cópia do modelo no container Debug isolado.")
        }
        return isolatedModel
    }

    func testDebugHostHasPermanentNonProductionIdentity() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "br.com.luisroquette.Resenha.Debug")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "Resenha Dev")
        XCTAssertNotEqual(Bundle.main.bundleIdentifier, "br.com.luisroquette.Resenha")
    }

    func testBrandTextColorsMeetWCAGAAOnTheirCanvas() {
        let lightBackgrounds = [ResenhaTheme.lightPaperRGB, ResenhaTheme.lightCanvasEndRGB]
        let darkBackgrounds = [ResenhaTheme.darkCanvasStartRGB, ResenhaTheme.darkCanvasEndRGB]
        let lightTextColors = [
            ResenhaTheme.lightAccentRGB,
            ResenhaTheme.lightSuccessRGB,
            ResenhaTheme.lightWarningRGB,
            ResenhaTheme.lightHighContrastAccentRGB,
            ResenhaTheme.lightHighContrastSuccessRGB,
            ResenhaTheme.lightHighContrastWarningRGB
        ]
        let darkTextColors = [
            ResenhaTheme.darkAccentRGB,
            ResenhaTheme.darkSuccessRGB,
            ResenhaTheme.darkWarningRGB,
            ResenhaTheme.darkHighContrastAccentRGB,
            ResenhaTheme.darkHighContrastSuccessRGB,
            ResenhaTheme.darkHighContrastWarningRGB
        ]
        for foreground in lightTextColors {
            for background in lightBackgrounds {
                XCTAssertGreaterThanOrEqual(foreground.contrastRatio(against: background), 4.5)
            }
        }
        for foreground in darkTextColors {
            for background in darkBackgrounds {
                XCTAssertGreaterThanOrEqual(foreground.contrastRatio(against: background), 4.5)
            }
        }
        let white = ResenhaRGB(hex: 0xFFFFFF)
        XCTAssertGreaterThanOrEqual(white.contrastRatio(against: ResenhaTheme.controlTintRGB), 4.5)
        XCTAssertGreaterThanOrEqual(
            ResenhaTheme.controlTintRGB.contrastRatio(against: ResenhaTheme.darkInkRGB),
            3
        )
    }

    @MainActor
    func testHUDEnlargedTextUsesCompactAccessibilityLayoutForEveryState() throws {
        let available = CGSize(width: 500, height: 320)
        let states: [FloatingStatus] = [
            .ready,
            .listening,
            .transcribing,
            .inserting,
            .failure("Permissão de Monitoramento de Entrada necessária para receber o atalho de ditado")
        ]
        for state in states {
            let native = FloatingStatusView.panelSize(for: state, available: available)
            let enlarged = FloatingStatusView.panelSize(
                for: state,
                available: available,
                dynamicTypeSize: .accessibility3
            )
            XCTAssertGreaterThan(enlarged.height, native.height)
            XCTAssertGreaterThanOrEqual(enlarged.width, native.width)
            XCTAssertLessThanOrEqual(enlarged.width, available.width - 24)
            XCTAssertLessThanOrEqual(enlarged.height, available.height - 24)

            let model = FloatingPanelModel()
            model.show(state, now: 100)
            let view = NSHostingView(rootView: FloatingStatusView(
                model: model,
                fixtureContrast: .increased,
                fixtureReduceTransparency: true,
                fixtureReduceMotion: true,
                fixtureDynamicTypeSize: .accessibility3
            ))
            view.frame = CGRect(origin: .zero, size: enlarged)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let backingSize = view.convertToBacking(view.bounds).size
            XCTAssertEqual(bitmap.pixelsWide, Int(backingSize.width))
            XCTAssertEqual(bitmap.pixelsHigh, Int(backingSize.height))
        }
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
    func testProductPreferencesPersistHUDAndLocalChoices() {
        let suite = "ResenhaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        XCTAssertTrue(preferences.showsHUD)
        XCTAssertTrue(preferences.soundsEnabled)
        XCTAssertFalse(preferences.keepsHistory, "Transcript history must be opt-in on a clean install")
        XCTAssertEqual(preferences.transcriptionLanguage, .portuguese)
        XCTAssertTrue(preferences.transcriptionGlossary.contains("Resenha"))
        XCTAssertEqual(preferences.readySoundID, 60)
        preferences.showsHUD = false
        preferences.soundsEnabled = false
        preferences.keepsHistory = false
        preferences.transcriptionLanguage = .spanish
        preferences.transcriptionGlossary = "coisa = COESA"
        preferences.readySoundID = 3
        preferences.toggleFavorite(soundID: 3)
        preferences.toggleFavorite(soundID: 60)
        preferences.toggleFavorite(soundID: 999)
        let restored = ProductPreferences(defaults: defaults)
        XCTAssertFalse(restored.showsHUD)
        XCTAssertFalse(restored.soundsEnabled)
        XCTAssertFalse(restored.keepsHistory)
        XCTAssertEqual(restored.transcriptionLanguage, .spanish)
        XCTAssertEqual(restored.transcriptionGlossary, "coisa = COESA")
        XCTAssertEqual(restored.readySoundID, 3)
        XCTAssertEqual(restored.readySound.name, "Pum seco")
        XCTAssertEqual(restored.favoriteSoundIDs, Set([3, 60]))
        restored.toggleFavorite(soundID: 3)
        XCTAssertEqual(restored.favoriteSoundIDs, Set([60]))
    }

    @MainActor
    func testLegacyHistoryPrivacyMigrationIsOptInIdempotentAndRetriesFailure() throws {
        let suite = "ResenhaHistoryMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        var attempts = 0

        XCTAssertTrue(preferences.needsLegacyHistoryPrivacyMigration)
        XCTAssertFalse(preferences.migrateLegacyHistoryIfNeeded {
            attempts += 1
            return false
        })
        XCTAssertTrue(preferences.needsLegacyHistoryPrivacyMigration)
        XCTAssertEqual(attempts, 1)

        XCTAssertTrue(preferences.migrateLegacyHistoryIfNeeded {
            attempts += 1
            return true
        })
        XCTAssertFalse(preferences.needsLegacyHistoryPrivacyMigration)
        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(preferences.migrateLegacyHistoryIfNeeded {
            attempts += 1
            return false
        })
        XCTAssertEqual(attempts, 2, "Completed migration must never delete a later opt-in history")
        XCTAssertFalse(ProductPreferences(defaults: defaults).needsLegacyHistoryPrivacyMigration)
    }

    @MainActor
    func testExplicitLegacyHistoryPreferenceDoesNotTriggerMigration() throws {
        let suite = "ResenhaHistoryExplicitPreference.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "resenha.keepsHistory")
        let preferences = ProductPreferences(defaults: defaults)
        var cleared = false

        XCTAssertFalse(preferences.needsLegacyHistoryPrivacyMigration)
        XCTAssertTrue(preferences.migrateLegacyHistoryIfNeeded { cleared = true; return true })
        XCTAssertFalse(cleared)
        XCTAssertTrue(preferences.keepsHistory)
    }

    func testSoundSearchMatchesNameCategoryNumberAndDiacritics() {
        XCTAssertEqual(ResenhaSoundCatalog.search("ressonancia").map(\.id), [60])
        XCTAssertEqual(ResenhaSoundCatalog.search("angelicais").count, 10)
        XCTAssertEqual(ResenhaSoundCatalog.search("05").map(\.id), [5])
        XCTAssertEqual(ResenhaSoundCatalog.search("sino", in: .angelic).map(\.id), [62, 70])
        XCTAssertEqual(ResenhaSoundCatalog.search("  ", in: .abstract).count, 10)
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

    func testWhisperPathsUseFixedStoreModelButRespectDebugEnvironmentModel() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let models = home.appendingPathComponent("Library/Application Support/WhisperKey/Models")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        let starter = models.appendingPathComponent("ggml-small-q5_1.bin")
        let explicit = models.appendingPathComponent("custom.bin")
        FileManager.default.createFile(atPath: starter.path, contents: Data())
        FileManager.default.createFile(atPath: explicit.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: home) }
        XCTAssertEqual(try WhisperPaths.resolve(environment: [:], home: home).model, starter)
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
        preferences.toggleFavorite(soundID: 60)

        for section in ProductSettingsSection.allCases {
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let view = NSHostingView(rootView: ProductSettingsView(
                    preferences: preferences,
                    initialSection: section,
                    soundPresentation: section == .sounds
                        ? SoundLibraryPresentation(searchText: "ressonância")
                        : .init()
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

        let interactionStates: [(String, ProductSettingsSection, SoundLibraryPresentation)] = [
            ("general", .general, .init()),
            ("shortcut", .shortcut, .init()),
            ("sounds-angelic", .sounds, .init(searchText: "angelicais")),
            ("sounds-query", .sounds, .init(searchText: "ress")),
            ("sounds-favorite", .sounds, .init(searchText: "ressonância")),
            ("sounds-favorites-only", .sounds, .init(showsFavoritesOnly: true)),
        ]
        for (name, section, presentation) in interactionStates {
            let view = NSHostingView(rootView: ProductSettingsView(
                preferences: preferences,
                initialSection: section,
                soundPresentation: presentation
            ).environment(\.colorScheme, .light))
            view.frame = CGRect(x: 0, y: 0, width: 760, height: 560)
            view.appearance = NSAppearance(named: .aqua)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("settings-interaction-\(name).png"))
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

    func testServiceShortcutUsesValidAppKitKeyEquivalentAndFreshBuild() throws {
        let plist = try XCTUnwrap(Bundle.main.infoDictionary)
        let services = try XCTUnwrap(plist["NSServices"] as? [[String: Any]])
        let keyDictionary = try XCTUnwrap(services.first?["NSKeyEquivalent"] as? [String: String])
        let keyEquivalent = try XCTUnwrap(keyDictionary["default"])
        XCTAssertEqual(keyEquivalent, ResenhaServiceShortcut.keyEquivalent)
        XCTAssertEqual(keyEquivalent.count, 1)
        XCTAssertEqual(keyEquivalent, keyEquivalent.uppercased(), "Uppercase adds Shift to AppKit's required Command modifier")
        XCTAssertNotEqual(ResenhaServiceShortcut.displayName, "Control + Option + Espaço")
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "2", "Submitted build 1 must never be rebuilt")
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "1.0.0")
        XCTAssertEqual(plist["ResenhaSourceCommit"] as? String, "DEVELOPMENT",
            "Development builds are explicit and cannot masquerade as release archives")
    }

    func testServiceReleaseLatchCompletesOnlyForItsArmedKey() {
        var latch = ServiceReleaseLatch()
        latch.noteKeyDown(0)
        latch.noteKeyDown(14)
        XCTAssertTrue(latch.arm(pressedKeyCodes: [0, 14]))
        XCTAssertEqual(latch.keyCode, 14, "The most recent held key invoked the Service")
        XCTAssertFalse(latch.arm(pressedKeyCodes: [49]))
        XCTAssertFalse(latch.consume(eventType: .keyUp, keyCode: 49))
        XCTAssertEqual(latch.keyCode, 14)
        XCTAssertFalse(latch.consume(eventType: .keyDown, keyCode: 14))
        XCTAssertTrue(latch.consume(eventType: .keyUp, keyCode: 14))
        XCTAssertNil(latch.keyCode)
        XCTAssertFalse(latch.consume(eventType: .keyUp, keyCode: 14))
        XCTAssertFalse(latch.interrupt())

        var ambiguous = ServiceReleaseLatch()
        XCTAssertFalse(ambiguous.arm(pressedKeyCodes: [0, 14]), "Multiple keys without an observed key-down are unsafe")
        ambiguous.noteKeyDown(2)
        XCTAssertTrue(ambiguous.arm(pressedKeyCodes: [0, 2, 14]))
        XCTAssertEqual(ambiguous.keyCode, 2, "A customized Service key is selected without a hard-coded E keycode")

        var stale = ServiceReleaseLatch()
        stale.noteKeyDown(14, at: 10)
        stale.expireRecentKey(at: 10.5)
        XCTAssertEqual(stale.mostRecentKeyDown?.keyCode, 14)
        stale.expireRecentKey(at: 10 + ServiceReleaseLatch.recentKeyWindow)
        XCTAssertNil(stale.mostRecentKeyDown)
        stale.noteKeyDown(14, at: 10)
        XCTAssertFalse(stale.arm(pressedKeyCodes: [0, 14], at: 10 + ServiceReleaseLatch.recentKeyWindow + 0.001))
        stale.noteKeyDown(14, at: 20)
        XCTAssertTrue(stale.arm(pressedKeyCodes: [0, 14], at: 20.5))
    }

    @MainActor
    func testAppConfiguresServiceReleaseWithoutDirectPressRoute() {
        let app = AppDelegate()
        XCTAssertFalse(app.isHotkeyRoutingConfigured)
        app.configureHotkeyRouting()
        XCTAssertTrue(app.isHotkeyRoutingConfigured)
    }

    @MainActor
    func testSelfTargetServiceAdmissionRejectsAndNextExternalRequestSucceeds() async {
        let hotkey = HotkeyMonitor()
        var startAttempts = 0
        let app = AppDelegate(hotkey: hotkey, verifiedModelURL: {
            URL(fileURLWithPath: "/verified/model.bin")
        }) {
            startAttempts += 1
            return true
        }
        app.configureHotkeyRouting()
        let routedRelease = hotkey.onRelease
        let releaseDelivered = expectation(description: "matching release reaches AppDelegate")
        hotkey.onRelease = {
            routedRelease?()
            releaseDelivered.fulfill()
        }

        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertFalse(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: true))
        XCTAssertFalse(app.interaction.isPressed)
        XCTAssertEqual(startAttempts, 0, "A self-originated request must not reach capture")

        hotkey.process(eventType: .keyUp, keyCode: 14)
        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertTrue(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        XCTAssertTrue(app.interaction.isPressed)
        XCTAssertEqual(startAttempts, 1)
        hotkey.process(eventType: .keyUp, keyCode: 14)
        await fulfillment(of: [releaseDelivered], timeout: 0.5)
        XCTAssertFalse(app.interaction.isPressed)
    }

    @MainActor
    func testServiceRequestRejectsThenRecoversThroughAppAdmissionAndExactRelease() {
        let hotkey = HotkeyMonitor()
        var startAttempts = 0
        let app = AppDelegate(hotkey: hotkey, verifiedModelURL: {
            URL(fileURLWithPath: "/verified/model.bin")
        }) {
            startAttempts += 1
            return startAttempts > 1
        }
        app.configureHotkeyRouting()
        let provider = ResenhaServiceProvider(timing: .init(timeout: 0.5, pollInterval: 0.002))
        var unrelatedReleasePreservedPress = false
        provider.beginDictation = {
            let started = app.beginServiceDictation(pressedKeyCodes: [0, 14], targetIsSelf: false)
            if started {
                DispatchQueue.main.async {
                    hotkey.process(eventType: .keyUp, keyCode: 0)
                    unrelatedReleasePreservedPress = app.interaction.isPressed
                    hotkey.process(eventType: .keyUp, keyCode: 14)
                    DispatchQueue.main.async { provider.complete(with: "recuperado") }
                }
            }
            return started
        }

        hotkey.process(eventType: .keyDown, keyCode: 0)
        hotkey.process(eventType: .keyDown, keyCode: 14)
        let rejected = NSPasteboard(name: .init("ResenhaServiceRejected.\(UUID().uuidString)"))
        defer { rejected.releaseGlobally() }
        var rejectedError: NSString?
        provider.dictate(rejected, userData: nil, error: &rejectedError)
        XCTAssertNotNil(rejectedError)
        XCTAssertFalse(app.interaction.isPressed, "A rejected admission must roll back before the next request")
        XCTAssertFalse(provider.isServing)

        hotkey.process(eventType: .keyUp, keyCode: 14)
        hotkey.process(eventType: .keyDown, keyCode: 14)
        let recovered = NSPasteboard(name: .init("ResenhaServiceAppRecovery.\(UUID().uuidString)"))
        defer { recovered.releaseGlobally() }
        var recoveryError: NSString?
        provider.dictate(recovered, userData: nil, error: &recoveryError)
        XCTAssertNil(recoveryError)
        XCTAssertEqual(recovered.string(forType: .string), "recuperado")
        XCTAssertTrue(unrelatedReleasePreservedPress)
        XCTAssertFalse(app.interaction.isPressed)
        XCTAssertEqual(startAttempts, 2)
    }

    @MainActor
    func testServiceProviderReturnsTranscriptToRealTextView() throws {
        let provider = ResenhaServiceProvider(timing: .init(timeout: 0.5, pollInterval: 0.002))
        let pasteboard = NSPasteboard(name: .init("ResenhaServiceTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        provider.beginDictation = {
            DispatchQueue.main.async { provider.complete(with: "texto inserido") }
            return true
        }
        var serviceError: NSString?
        provider.dictate(pasteboard, userData: nil, error: &serviceError)
        XCTAssertNil(serviceError)

        let textView = NSTextView(frame: .zero)
        textView.string = "antes depois"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        XCTAssertTrue(textView.readSelection(from: pasteboard))
        XCTAssertEqual(textView.string, "antes texto inseridodepois")
        XCTAssertFalse(provider.isServing)
    }

    @MainActor
    func testServiceProviderTimeoutEmptyAndRecoveryLeaveNoPlaceholder() {
        let provider = ResenhaServiceProvider(timing: .init(timeout: 0.02, pollInterval: 0.002))
        var timeoutCancellationCount = 0
        provider.cancelDictation = { timeoutCancellationCount += 1 }
        provider.complete(with: "resultado sem requisição")
        provider.beginDictation = { true }

        let timedOut = NSPasteboard(name: .init("ResenhaServiceTimeout.\(UUID().uuidString)"))
        defer { timedOut.releaseGlobally() }
        var timeoutError: NSString?
        provider.dictate(timedOut, userData: nil, error: &timeoutError)
        XCTAssertNotNil(timeoutError)
        XCTAssertNil(timedOut.string(forType: .string))
        XCTAssertFalse(provider.isServing)
        XCTAssertEqual(timeoutCancellationCount, 1)

        let empty = NSPasteboard(name: .init("ResenhaServiceEmpty.\(UUID().uuidString)"))
        defer { empty.releaseGlobally() }
        provider.beginDictation = {
            DispatchQueue.main.async { provider.complete(with: " \n ") }
            return true
        }
        var emptyError: NSString?
        provider.dictate(empty, userData: nil, error: &emptyError)
        XCTAssertNotNil(emptyError)
        XCTAssertNil(empty.string(forType: .string))

        let cancelled = NSPasteboard(name: .init("ResenhaServiceCancelled.\(UUID().uuidString)"))
        defer { cancelled.releaseGlobally() }
        provider.beginDictation = {
            DispatchQueue.main.async { provider.fail(with: "Ditado cancelado.") }
            return true
        }
        var cancellationError: NSString?
        provider.dictate(cancelled, userData: nil, error: &cancellationError)
        XCTAssertEqual(cancellationError, "Ditado cancelado.")
        XCTAssertNil(cancelled.string(forType: .string))

        let recovered = NSPasteboard(name: .init("ResenhaServiceRecovery.\(UUID().uuidString)"))
        defer { recovered.releaseGlobally() }
        provider.beginDictation = {
            DispatchQueue.main.async { provider.complete(with: "próxima tentativa") }
            return true
        }
        var recoveryError: NSString?
        provider.dictate(recovered, userData: nil, error: &recoveryError)
        XCTAssertNil(recoveryError)
        XCTAssertEqual(recovered.string(forType: .string), "próxima tentativa")
        XCTAssertFalse(provider.isServing)
    }

    @MainActor
    func testServiceTimeoutUsesMonotonicClockAcrossBackwardForwardAndExactBoundary() {
        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            private var values: [TimeInterval] = [100, 105, 90, 109.999, 110, 1_000]
            func read() -> TimeInterval {
                lock.withLock { values.isEmpty ? 1_000 : values.removeFirst() }
            }
        }
        let clock = Clock()
        let provider = ResenhaServiceProvider(timing: .init(
            timeout: 10,
            pollInterval: 0.001,
            uptime: { clock.read() }
        ))
        var cancellations = 0
        provider.beginDictation = { true }
        provider.cancelDictation = { cancellations += 1 }
        let pasteboard = NSPasteboard(name: .init("ResenhaMonotonicTimeout.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        var serviceError: NSString?

        provider.dictate(pasteboard, userData: nil, error: &serviceError)

        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(serviceError, "O ditado excedeu o tempo máximo do Serviço.")
        XCTAssertFalse(provider.isServing)

        var deadline = MonotonicDeadline(duration: 10, startedAt: 100)
        XCTAssertEqual(deadline.remaining(at: 105), 5)
        XCTAssertEqual(deadline.remaining(at: 90), 5, "A backward jump must not extend the budget")
        XCTAssertFalse(deadline.hasExpired(at: 109.999))
        XCTAssertTrue(deadline.hasExpired(at: 110), "The exact boundary is expired")
        XCTAssertTrue(deadline.hasExpired(at: 1_000), "A forward jump remains expired")
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
        XCTAssertEqual(first.minSize, NSSize(width: 720, height: 500))
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
        XCTAssertTrue(first.styleMask.contains(.resizable))
        XCTAssertEqual(first.contentMinSize, NSSize(width: 620, height: 480))
        controller.close()
        XCTAssertFalse(first.isVisible)
    }

    func testPermissionPresentationCoversEveryAvailabilityCombination() {
        for microphone in [false, true] {
            for inputMonitoring in [false, true] {
                    let snapshot = PermissionSnapshot(microphone: microphone, inputMonitoring: inputMonitoring)
                    XCTAssertEqual(snapshot.isReady, microphone && inputMonitoring)
                    XCTAssertEqual(snapshot.presentations.map(\.permission), [.microphone, .inputMonitoring])
                    XCTAssertEqual(snapshot.presentations.map(\.isGranted), [microphone, inputMonitoring])
                    XCTAssertEqual(snapshot.missingPermissions.count, [microphone, inputMonitoring].filter { !$0 }.count)
                    for presentation in snapshot.presentations {
                        XCTAssertEqual(presentation.status, "\(presentation.permission.name): \(presentation.isGranted ? "ativada" : "permissão necessária")")
                        XCTAssertFalse(presentation.permission.purpose.isEmpty)
                        XCTAssertEqual(presentation.permission.settingsActionTitle, "Abrir Ajustes de \(presentation.permission.name)")
                    }
                    let expectedMessage = !microphone ? "Acesso ao Microfone necessário"
                        : !inputMonitoring ? "Acesso ao Monitoramento de Entrada necessário" : "Permissões prontas"
                    XCTAssertEqual(snapshot.missingPermissionMessage, expectedMessage)
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
        XCTAssertEqual(RequiredPermission.microphone.settingsDestination.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        XCTAssertEqual(RequiredPermission.inputMonitoring.settingsDestination.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
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
            XCTAssertTrue(presentation.accessibleStatus.contains("Serviços do macOS"))
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

    func testRejectedMenuRequestAndSelfPressRollBackAdmission() {
        for blocker in 0..<3 {
            var interaction = DictationInteraction()
            interaction.openMenuCount = blocker == 0 ? 2 : 0
            interaction.isRequestingPermission = blocker == 1
            XCTAssertFalse(interaction.press(phase: .idle, targetIsSelf: blocker == 2))
            XCTAssertFalse(interaction.isPressed)
            interaction.openMenuCount = 0
            interaction.isRequestingPermission = false
            XCTAssertTrue(interaction.press(phase: .idle, targetIsSelf: false))
            interaction.release()
        }
    }

    @MainActor
    func testActiveRecordingReleaseSurvivesMenuAndRequestGuards() {
        let app = AppDelegate(
            hotkey: HotkeyMonitor(),
            verifiedModelURL: { URL(fileURLWithPath: "/verified/model.bin") },
            serviceStartOverride: nil
        )
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
        XCTAssertEqual(coordinator.phase, .failed, "A fresh invocation after closing the menu reaches coordinator admission")
        XCTAssertFalse(app.interaction.isPressed, "A coordinator start failure rolls admission back")
        coordinator.cancel()
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

    func testTargetWindowResolverChoosesFrontmostUsableWindowAndConvertsCoordinates() {
        let candidates = [
            TargetWindowCandidate(ownerPID: 42, layer: 1, isOnscreen: true,
                                  quartzFrame: CGRect(x: 10, y: 10, width: 900, height: 700), order: 0),
            TargetWindowCandidate(ownerPID: 99, layer: 0, isOnscreen: true,
                                  quartzFrame: CGRect(x: 20, y: 30, width: 800, height: 600), order: 1),
            TargetWindowCandidate(ownerPID: 42, layer: 0, isOnscreen: true,
                                  quartzFrame: CGRect(x: -1200, y: 100, width: 1000, height: 700), order: 2),
            TargetWindowCandidate(ownerPID: 42, layer: 0, isOnscreen: true,
                                  quartzFrame: CGRect(x: 40, y: 40, width: 1200, height: 800), order: 3)
        ]
        XCTAssertEqual(
            TargetWindowResolver.frame(for: 42, candidates: candidates, primaryScreenTop: 1080),
            CGRect(x: -1200, y: 280, width: 1000, height: 700)
        )
    }

    func testTargetWindowResolverRejectsHiddenTinyAndForeignWindows() {
        let candidates = [
            TargetWindowCandidate(ownerPID: 42, layer: 0, isOnscreen: false,
                                  quartzFrame: CGRect(x: 0, y: 0, width: 900, height: 700), order: 0),
            TargetWindowCandidate(ownerPID: 42, layer: 0, isOnscreen: true,
                                  quartzFrame: CGRect(x: 0, y: 0, width: 20, height: 20), order: 1),
            TargetWindowCandidate(ownerPID: 7, layer: 0, isOnscreen: true,
                                  quartzFrame: CGRect(x: 0, y: 0, width: 900, height: 700), order: 2)
        ]
        XCTAssertNil(TargetWindowResolver.frame(for: 42, candidates: candidates, primaryScreenTop: 1080))
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

        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "jfk", withExtension: "wav"))

        let transcript = try WhisperTranscriber().transcribe(
            audioURL: fixture,
            modelURL: model,
            language: .english,
            glossaryText: ""
        ).lowercased()

        XCTAssertTrue(transcript.contains("fellow americans"), transcript)
        XCTAssertTrue(transcript.contains("country"), transcript)
    }

    func testRuntimeBudgetsAreBoundedInsideServiceTimeout() {
        XCTAssertEqual(ResenhaRuntimeLimits.maximumRecordingDuration, 300)
        XCTAssertEqual(ResenhaRuntimeLimits.maximumInferenceDuration, 270)
        XCTAssertEqual(ResenhaRuntimeLimits.serviceTimeout, 600)
        XCTAssertTrue(ResenhaRuntimeLimits.serviceBudgetIsValid)
    }

    func testWhisperCancellationTokenUsesMonotonicExactDeadlineAndCancellationWins() {
        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            private var value: TimeInterval = 100
            func read() -> TimeInterval { lock.withLock { value } }
            func set(_ value: TimeInterval) { lock.withLock { self.value = value } }
        }
        let clock = Clock()
        let token = WhisperCancellationToken(maximumRuntime: 10, startedAt: 100) { clock.read() }
        XCTAssertNil(token.abortReason())
        clock.set(109.999)
        XCTAssertNil(token.abortReason())
        clock.set(110)
        XCTAssertEqual(token.abortReason(), .timedOut)

        let cancelled = WhisperCancellationToken(maximumRuntime: 10, startedAt: 100) { clock.read() }
        cancelled.cancel()
        XCTAssertEqual(cancelled.abortReason(), .cancelled)
        XCTAssertEqual(cancelled.abortReason(taskIsCancelled: true), .cancelled)
    }

    func testWhisperContextUnloadGateRejectsStaleIdleCallbacks() {
        var gate = WhisperContextUnloadGate()
        gate.beginUse()
        let obsolete = gate.scheduleUnload()
        XCTAssertTrue(gate.permitsUnload(generation: obsolete))

        gate.beginUse()
        XCTAssertFalse(gate.permitsUnload(generation: obsolete), "A new inference invalidates the old idle callback")
        let current = gate.scheduleUnload()
        XCTAssertTrue(gate.permitsUnload(generation: current))
        gate.invalidate()
        XCTAssertFalse(gate.permitsUnload(generation: current), "Memory-pressure release invalidates queued idle work")
    }

    func testWhisperEngineIdleUnloadRejectsStaleCallbackAndReleasesActualContext() throws {
        let probe = WhisperLifecycleProbe()
        let engine = EmbeddedWhisperEngine(
            idleLifetime: 0.10,
            monitorsMemoryPressure: false,
            contextLoader: { probe.load(path: $0) },
            contextReleaser: { probe.release($0) }
        )
        let model = URL(fileURLWithPath: "/tmp/resenha-test-model.bin")
        try engine.withContext(model: model) { _ in }
        Thread.sleep(forTimeInterval: 0.06)
        try engine.withContext(model: model) { _ in }
        Thread.sleep(forTimeInterval: 0.06)

        XCTAssertTrue(engine.lifecycleSnapshot.hasContext)
        XCTAssertEqual(probe.snapshot.loads, 1)
        XCTAssertEqual(probe.snapshot.releases, 0, "The first queued idle callback must be stale")

        let unloaded = expectation(description: "current idle deadline releases the context")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { unloaded.fulfill() }
        wait(for: [unloaded], timeout: 0.5)
        XCTAssertFalse(engine.lifecycleSnapshot.hasContext)
        XCTAssertEqual(probe.snapshot.releases, 1)
    }

    func testWhisperEngineMemoryPressureWaitsForInferenceBeforeRelease() throws {
        let probe = WhisperLifecycleProbe()
        let engine = EmbeddedWhisperEngine(
            idleLifetime: 60,
            monitorsMemoryPressure: false,
            contextLoader: { probe.load(path: $0) },
            contextReleaser: { probe.release($0) }
        )
        let model = URL(fileURLWithPath: "/tmp/resenha-test-model.bin")
        let entered = DispatchSemaphore(value: 0)
        let mayFinish = DispatchSemaphore(value: 0)
        let inferenceDone = expectation(description: "inference completed")
        let pressureDone = expectation(description: "memory pressure completed")

        DispatchQueue.global().async {
            defer { inferenceDone.fulfill() }
            try? engine.withContext(model: model) { _ in
                entered.signal()
                _ = mayFinish.wait(timeout: .now() + 1)
            }
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 0.5), .success)
        DispatchQueue.global().async {
            engine.handleMemoryPressure()
            pressureDone.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.02)
        XCTAssertEqual(probe.snapshot.releases, 0, "Pressure must not free a context in active use")
        mayFinish.signal()

        wait(for: [inferenceDone, pressureDone], timeout: 1)
        XCTAssertEqual(probe.snapshot.releases, 1)
        XCTAssertFalse(engine.lifecycleSnapshot.hasContext)
    }

    func testWhisperEngineSerializesConcurrentContextUses() throws {
        let probe = WhisperLifecycleProbe()
        let engine = EmbeddedWhisperEngine(
            idleLifetime: 60,
            monitorsMemoryPressure: false,
            contextLoader: { probe.load(path: $0) },
            contextReleaser: { probe.release($0) }
        )
        let model = URL(fileURLWithPath: "/tmp/resenha-test-model.bin")
        let completed = expectation(description: "both context uses completed")
        completed.expectedFulfillmentCount = 2

        for _ in 0..<2 {
            DispatchQueue.global().async {
                defer { completed.fulfill() }
                try? engine.withContext(model: model) { _ in
                    probe.beginUse()
                    Thread.sleep(forTimeInterval: 0.03)
                    probe.endUse()
                }
            }
        }

        wait(for: [completed], timeout: 1)
        XCTAssertEqual(probe.snapshot.loads, 1)
        XCTAssertEqual(probe.snapshot.maximumConcurrentUses, 1)
    }

    func testWhisperFullHonorsCooperativeAbortCallback() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "jfk", withExtension: "wav"))
        let token = WhisperCancellationToken(maximumRuntime: 30)
        token.cancel()

        let model = try localWhisperTestModel()
        XCTAssertThrowsError(try WhisperTranscriber().transcribe(
            audioURL: fixture,
            modelURL: model,
            language: .english,
            glossaryText: "",
            cancellationToken: token
        )) { error in
            XCTAssertTrue(error is CancellationError, "Expected cooperative cancellation, got \(error)")
        }
    }

    func testWhisperFullHonorsDeadlineInsideInference() throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "jfk", withExtension: "wav"))
        let token = WhisperCancellationToken(maximumRuntime: 0)

        let model = try localWhisperTestModel()
        XCTAssertThrowsError(try WhisperTranscriber().transcribe(
            audioURL: fixture,
            modelURL: model,
            language: .english,
            glossaryText: "",
            cancellationToken: token
        )) { error in
            guard case WhisperError.timedOut = error else {
                return XCTFail("Expected cooperative timeout, got \(error)")
            }
        }
    }

    @MainActor
    func testTapInterruptionCancelsArmedReleaseInsteadOfCompletingIt() async {
        let hotkey = HotkeyMonitor()
        let interrupted = expectation(description: "tap interruption is routed separately")
        var releases = 0
        hotkey.onRelease = { releases += 1 }
        hotkey.onInterruption = { interrupted.fulfill() }
        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertTrue(hotkey.armServiceRelease(pressedKeyCodes: [14]))

        hotkey.process(eventType: .tapDisabledByTimeout, keyCode: 0)

        await fulfillment(of: [interrupted], timeout: 0.5)
        XCTAssertEqual(releases, 0)
        XCTAssertFalse(hotkey.interruptServiceRelease())
    }

    @MainActor
    func testSystemInterruptionTerminatesRecordingState() {
        let hotkey = HotkeyMonitor()
        let app = AppDelegate(hotkey: hotkey, verifiedModelURL: {
            URL(fileURLWithPath: "/verified/model.bin")
        }) { true }
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: FloatingPanelController())
        app.observeCoordinator(coordinator)
        app.configureHotkeyRouting()
        coordinator.transition(to: .recording)

        app.handleRuntimeInterruption()

        XCTAssertEqual(coordinator.phase, .failed)
        XCTAssertEqual(coordinator.currentError?.title, "Ditado interrompido pelo sistema")
        XCTAssertFalse(app.interaction.isPressed)
        coordinator.cancel()
    }

    @MainActor
    func testRecordingDeadlineCannotLeaveCoordinatorRecording() {
        let coordinator = DictationCoordinator(permissions: PermissionService(), panel: FloatingPanelController())
        coordinator.transition(to: .recording)

        coordinator.recordingDeadlineReached()

        XCTAssertNotEqual(coordinator.phase, .recording)
        XCTAssertEqual(coordinator.phase, .failed, "A synthetic deadline without an audio file still terminates safely")
        coordinator.cancel()
    }

    @MainActor
    func testRecordingDeadlineWithoutKeyUpAllowsNextServiceStart() {
        let hotkey = HotkeyMonitor()
        var startAttempts = 0
        let app = AppDelegate(hotkey: hotkey, verifiedModelURL: {
            URL(fileURLWithPath: "/verified/model.bin")
        }) {
            startAttempts += 1
            return true
        }
        let coordinator = DictationCoordinator(
            permissions: PermissionService(),
            panel: FloatingPanelController()
        )
        app.observeCoordinator(coordinator)
        app.configureHotkeyRouting()

        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertTrue(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        XCTAssertTrue(app.interaction.isPressed)

        coordinator.onRecordingDeadline?()

        XCTAssertFalse(app.interaction.isPressed)
        XCTAssertFalse(hotkey.interruptServiceRelease(), "The deadline terminal edge must disarm the old release")
        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertTrue(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        XCTAssertTrue(app.interaction.isPressed)
        XCTAssertEqual(startAttempts, 2)
        coordinator.onRecordingDeadline?()
    }

    @MainActor
    func testHUDNativeFixturesForEveryStateAndAppearance() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResenhaTests/ui-fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let states: [(String, FloatingStatus)] = [("ready", .ready), ("listening", .listening), ("listening-silence", .listening), ("listening-decay", .listening), ("transcribing", .transcribing), ("inserting", .inserting),
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
                if state == .listening { XCTAssertEqual(size, CGSize(width: 340, height: 72)) }
                else if !state.isFailure { XCTAssertEqual(size, CGSize(width: 280, height: 64)) }
                XCTAssertLessThanOrEqual(size.width, 360)
                XCTAssertLessThanOrEqual(size.height, 104)
                let view = NSHostingView(rootView: FloatingStatusView(model: model, fixtureContrast: contrast, fixtureReduceTransparency: opaque, fixtureReduceMotion: reduceMotion)
                    .environment(\.colorScheme, scheme))
                view.frame = CGRect(origin: .zero, size: size)
                view.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                view.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("hud-\(name)-\(appearance).png"))
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
