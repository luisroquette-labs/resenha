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

        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixture = repository.appendingPathComponent("Vendor/whisper.cpp/samples/jfk.wav")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.path))

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
