# Context-Aware Transcription Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a conservative, local-first contextual correction beta that learns explicit phrase-bound examples, never turns `rosto -> Hostel` into an unconditional rule, and confines the authorized Jev use to one synthetic diagnostic call.

**Architecture:** A new `ContextualCorrections.swift` owns the versioned local store, whole-term occurrence matching, bounded decision validation, one-shot synthetic diagnostic, ephemeral OpenRouter transport, and Keychain adapter. `DictationCoordinator` asks an injected resolver for one final string before staging it, while the existing feedback editor saves a confirmed phrase and occurrence into the separate store; real personal dictation has no production path to remote transport. App composition and settings expose local examples, explicit deletion, opt-in disclosure, credential removal, and the synthetic-only diagnostic without changing the legacy glossary.

**Tech Stack:** Swift 5, SwiftUI/AppKit, Foundation (`URLSession`, `Codable`, sentence enumeration), Security (`SecItem`), XCTest, XcodeGen, macOS 14+

**Spec:** `.specs/tasks/todo/add-context-aware-corrections.feature.md`

## Global Constraints

- Execute only after the visual-feedback dependency is merged into updated `main`; create a fresh dedicated branch/worktree from that SHA and do not copy, stash, reset, or overwrite the current visual WIP.
- Keep legacy `TranscriptionGlossary`, Whisper prompting, `TranscriptPostprocessor`, `TextInjector`, `TranscriptHistory`, feedback timing/halo/bubbles, menus, focus, and rollback behavior intact unless this plan explicitly names a seam.
- Contextual records live only at `Application Support/Resenha/ContextualCorrections/v1.json`, schema version `1`, maximum `100` records, one confirmed phrase per record, maximum `600` Swift `String.count`, and maximum file size `2 MiB`; record 101 is rejected without FIFO.
- The store exposes one typed snapshot of examples, generation, and health. Corrupt, oversized, unsupported-schema, failed read-back/rollback, or otherwise unhealthy state preserves the last trustworthy snapshot but is never eligible for matching/provider work; only a fully verified explicit reload restores healthy resolution.
- A decision may only keep or apply an already-confirmed pair to an exact whole-term occurrence; `confidence >= 0.90` and selected-option probability `>= 0.90` are both mandatory.
- Zero candidates or more than three candidate occurrences, multiple required sentences, overlapping or invalid spans, conflict, uncertainty, malformed data, deadline, cancellation, or any dependency failure preserves the entire resolver input.
- The total resolver deadline is `900 ms`, measured monotonically from resolver entry; there is no retry, alternate provider/model, or late mutation.
- App composition owns exactly one `ContextualMonotonicTime` instance shared by resolver, synthetic diagnostic, and streaming transport; production constructors have no clock defaults, and offsets/deadlines from distinct origins are rejected before component use.
- The beta is off by default. Personal dictation remains ineligible for real transport even with opt-in and a credential; production network use is limited to one allowlisted synthetic fixture after local gates and review.
- The only remote contract is `POST https://openrouter.ai/api/alpha/decisions` with pinned model `typesafe/jev-1.14`, an ephemeral streaming session, fixed HTTPS host, redirects rejected, and a `64 KiB` response cap enforced first in synchronized delegate state while chunks arrive and again in the client; byte 65,537 cancels the task before enqueue/decoding.
- Never persist or log authorization headers, provider bodies, phrases, pairs, examples, audio, history, clipboard, app identity, local UUIDs, or personal text. The key is accepted only through the app's scoped Keychain control, never source, fixture, defaults, environment, CLI, commit, or shared memory.
- Planning, automated tests, CI, app launch, settings, feedback Save, and personal dictation make zero paid calls. The final synthetic diagnostic issues/registers its policy token before the first suspension, consumes the durable one-shot guard before creating transport work, revalidates after every suspension and immediately before open, and remains consumed on success, error, timeout, unknown result, restart, opt-out, credential deletion, or termination.
- One `ContextualCorrectionPolicy` owns generation tokens and every pending resolver/diagnostic cancellation; opt-out, credential-removal intent, and every successful contextual-store mutation increment generation before cancelling registered work.
- Resolver transport is allowlisted by token scope before provider-task creation: only `.syntheticDiagnostic` and `.testDouble` may call a provider; disabled and personal-dictation scopes preserve original text with zero requests.
- Local beta state and synthetic-diagnostic authorization are separate operations on one owner: `setLocalBetaEnabled` never touches Keychain/guard, while `authorizeSyntheticDiagnostic` orders explicit diagnostic consent -> Keychain save -> exact read-back -> guard validation/provision. Authorization uncertainty removes the candidate key and blocks dispatch without silently changing local beta state.
- The diagnostic guard uses `Application Support/Resenha/ContextualCorrections/diagnostic-authorization-v1.json` plus a one-time provision marker in the same `0700` directory; state files/temporaries are `0600`, and missing-after-provision, corrupt, oversized, read-back-uncertain, or write-uncertain state blocks dispatch with zero network.
- Use existing Apple system frameworks only: the new support file imports Foundation, Combine, and Security; UI keeps its existing AppKit/SwiftUI imports and adds explicit Combine where it declares `ObservableObject`/`@Published`. Add no package/SDK, provider abstraction, embeddings, analytics, backend, monthly budget, automatic migration, or generalized next-word generation.
- The frozen 100-case calibration/evaluation corpus must keep learning examples and the diagnostic fixture outside case rows, seed the real store only from each case's mapped learning IDs, and compare contextual, keep-original, and global-replacement baselines by family/pair. Its normalized semantic keys and rationales must be unique, numbered/template variants and invalid labels block loading, and an independent non-author audits all 100 rows against the exact frozen hash before metrics. Only evaluation gates acceptance: every evaluation row receives exact-output and span-authorization analysis, its 20 positive IDs are frozen before execution, false positives/unauthorized mutations/harmful span changes must all be zero, safety coverage must include every evaluation row, and recall must be at least 0.80; calibration/diagnostic never affect the gate.
- All local native gates run serialized through `~/.local/bin/mac-gate`; never run `xcodebuild` directly. This native target has no npm/Vercel gate.
- Implement in one task branch and one PR. Run the native gate before PR/integration, require applicable checks green on the latest SHA, integrate autonomously, then validate/install the exact integrated app.
- The single synthetic call occurs only after the frozen candidate, native gate, privacy documentation, and executable Phase 1 PASS. The exact candidate is then installed/tested physically pre-merge and reviewed by opus Phase 2; only PASS permits `done`, closure commit/push, latest-SHA checks, and merge. It never uses personal dictation and does not establish PT-BR quality or recurring authorization.

## Review Focus

- A common-word negative such as `Meu rosto ficou vermelho` must remain byte-for-byte unchanged even when a local `rosto -> Hostel` example exists; Task 2 pins this in the held-out corpus.
- Two identical heard terms with different meanings must bind decisions to ordinals/ranges and apply literal replacements in reverse order without interpreting `$` or `\\`; Task 2 tests mixed decisions and metacharacters.
- Store corruption, unknown schema, oversized data, write/read-back failure, and failed rollback must preserve the last trustworthy snapshot and block mutation rather than silently becoming empty; Task 1 tests every recovery state.
- Disabling the beta, deleting an example/credential, cancelling attempt A, or starting attempt B while A is suspended must invalidate A and produce no late stage/history/insertion; Task 4 uses controlled continuations and sink spies.
- Delegate overflow, one-shot concurrency/crash/corruption/write uncertainty, timeout, provider error, redirect, and restart must cancel/block before unsafe dispatch and never expose key/body; Task 3 tests both byte defenses and the durable guard.

## SDD Execution Governance

| Writing-plan tasks | SDD owner | Spec phase review |
| --- | --- | --- |
| Tasks 1–3 | The single implementation agent assigned to Step 01 | One Phase 1 review after Task 6 evidence is complete |
| Tasks 4–5 | The single implementation agent assigned to Step 02 | Covered by that same Phase 1 review; no extra phase review |
| Task 6 | The single implementation agent assigned to Step 03 | Produces the Phase 1 package and resolves its findings with the owning Step 01/02 agent |
| Task 7 | The single implementation agent assigned to Step 04 | One opus Phase 2 review after diagnostic/physical evidence and before `in-progress -> done` |

The four SDD step owners above are the only implementation-agent assignments. Internal RED/GREEN commits, corrective loops, documentation commits, and review-finding fixes stay with the existing owning step; they do not create another agent, phase, or review. A finding always returns to its mapped owner, and the plan advances only after the one review required for that spec phase passes.

---

## File Map

| File | Change | Responsibility |
| --- | --- | --- |
| `Sources/WhisperKey/ContextualCorrections.swift` | Create | Domain records, atomic store, occurrence matcher, resolver, Decisions request/response validation, synthetic allowlist, one-shot guard, ephemeral transport, Keychain adapter. |
| `Tests/Fixtures/contextual-corrections.json` | Create | Frozen synthetic PT-BR learning-example table, 100 separately mapped calibration/evaluation cases, frozen 20-ID evaluation-positive set, and one separate allowlisted diagnostic fixture. |
| `Sources/WhisperKey/DictationCoordinator.swift` | Modify | Resolve the immutable postprocessed transcript before all sinks; declare the non-class-bound output protocol and `TextInjector` conformance; carry final text/language plus the nil-by-default lifetime probe in `DictationCompletion`; reject stale attempts. |
| `Sources/WhisperKey/FloatingPanel.swift` | Modify | Confirm sentence/occurrence, save a contextual example instead of a global glossary rule, preserve draft on failure, release transcript ownership on every exit. |
| `Sources/WhisperKey/ProductPreferences.swift` | Modify | Store beta opt-in only; render example list/deletion, credential controls, disclosures, and synthetic diagnostic state. |
| `Sources/WhisperKey/WhisperKeyApp.swift` | Modify | Compose one store/resolver/credential/diagnostic controller and invalidate policy generations on lifecycle/settings changes. |
| `Sources/WhisperKey/PermissionOnboarding.swift` | Modify | Replace absolute all-text-local wording with exact audio/local-text and synthetic-diagnostic disclosure. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Modify | Unit/integration/corpus/lifecycle/accessibility/resource tests; all network and credentials use doubles. |
| `project.yml` | Modify | Add the synthetic JSON to app Copy Bundle Resources and the test target; link Security only if compilation requires it. |
| `WhisperKey.xcodeproj/project.pbxproj` | Regenerate | XcodeGen output for the new Swift source/resource/framework entries; no hand edits. |
| `README.md` | Modify | Explain local contextual examples, synthetic-only remote diagnostic, limits, and current non-availability for personal dictation. |
| `docs/PRIVACY.md` | Modify | Describe retained fields, deletion boundary, Keychain credential, OpenRouter/TypeSafe synthetic transmission, and non-guarantees. |
| `docs/specs/00-constitution.md` | Modify | Narrow absolute local-processing copy only for the explicit synthetic diagnostic exception. |
| `docs/architecture.md` | Modify | Add the pre-sink resolver/store flow and hard remote boundary. |
| `docs/specs/11-output-quality.md` | Modify | Replace feedback-to-global-rule behavior with contextual example behavior while preserving user-authored legacy rules. |
| `docs/specs/08-testing.md` | Modify | Add zero-network gates, corpus provenance, single-call boundary, and physical evidence rules. |
| `docs/testing/context-aware-corrections.md` | Create in Task 6; complete in Task 7 pre-merge | Tested-product provenance, frozen-contract sources, independent 100-row corpus audit, sanitized payload shape, gates, corpus/fake results, Phase 1/2 reviews, physical proof, controlled observation, and explicit unproven claims. |

## Execution Prerequisite: Start From the Integrated Dependency

**Files:**
- Read: `.specs/tasks/todo/add-context-aware-corrections.feature.md`
- Read: `.specs/analysis/analysis-context-aware-corrections.md`
- Read: `.claude/skills/context-aware-transcription-corrections/SKILL.md`
- Read: `Sources/WhisperKey/DictationCoordinator.swift`
- Read: `Sources/WhisperKey/FloatingPanel.swift`
- Read: `Sources/WhisperKey/ProductPreferences.swift`
- Read: `Sources/WhisperKey/WhisperKeyApp.swift`
- Read: `Sources/WhisperKey/WhisperTranscriber.swift`
- Read: `Sources/WhisperKey/TranscriptHistory.swift`
- Read: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**
- Consumes: integrated visual-feedback implementation on `main`, including the four-second offer and current completion/editor lifecycle.
- Produces: clean branch `feat/context-aware-corrections` whose base SHA and clean status are recorded before code changes.

- [ ] **Step 1: Verify the dependency is integrated and the source tree is clean**

```bash
set -euo pipefail
git fetch origin main
git log -1 --oneline origin/main
git status --short
git log --oneline origin/main -- .specs/tasks/in-progress/add-transcription-feedback.feature.md Sources/WhisperKey/FloatingStatusView.swift Sources/WhisperKey/RecordingWaveformView.swift
```

Expected: the visual-feedback commit is reachable from `origin/main`; `git status --short` prints nothing. If either condition fails, stop without stashing/resetting and return to the dependency task.

- [ ] **Step 2: Create the dedicated implementation worktree and branch**

```bash
set -euo pipefail
git worktree add ../resenha-context-aware-corrections -b feat/context-aware-corrections origin/main
cd ../resenha-context-aware-corrections
git status --short
git rev-parse HEAD
```

Expected: the new worktree is clean and `HEAD` equals the inspected `origin/main` SHA. Continue all later steps in this new worktree.

- [ ] **Step 3: Promote the SDD task to in-progress**

Promote the task before product edits; keep the move in the first implementation commit rather than creating a setup-only commit:

```bash
set -euo pipefail
git mv .specs/tasks/todo/add-context-aware-corrections.feature.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md
test -f .specs/tasks/in-progress/add-context-aware-corrections.feature.md
test ! -e .specs/tasks/todo/add-context-aware-corrections.feature.md
```

Expected: the task has one uncommitted `todo -> in-progress` rename. The four subtask files keep their stable locations and their “usar localização atual” rule; all later task references resolve the filename under `.specs/tasks/` rather than assuming the old folder.

- [ ] **Step 4: Map every caller before changing shared contracts**

```bash
set -euo pipefail
rg -n "DictationCompletion|completeInsertion|onCompleted|configureFeedback|offerFeedback|saveCorrection|saveTranscriptionCorrection|TranscriptPostprocessor\.process|TranscriptionGlossary|TranscriptHistory" Sources Tests
rg -n "URLSession|SecItem|UserDefaults|Logger\(" Sources Tests project.yml
```

Expected: the map includes `DictationCoordinator`, `FloatingPanel`, `ProductPreferences`, `WhisperKeyApp`, `WhisperTranscriber`, `TranscriptHistory`, and their XCTest callers. Add no product file beyond the File Map without first updating this plan/spec.

- [ ] **Step 5: Confirm the implementation worktree is ready without changing product code**

```bash
git status --short
```

Expected: only the intentional task-file rename is present. Proceed directly to Task 1; setup has no standalone deliverable or commit.

### Task 1: Versioned Contextual Example Store

**Files:**
- Create: `Sources/WhisperKey/ContextualCorrections.swift`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`
- Modify: `WhisperKey.xcodeproj/project.pbxproj` (generated only)

**Interfaces:**
- Consumes: `TranscriptionLanguage.rawValue`, Foundation file APIs, injected file URL and file-system operations in tests.
- Produces: `ContextualCorrectionExample`, `ContextualCorrectionStore`, typed `ContextualCorrectionStoreHealth`/`ContextualCorrectionStoreSnapshot`, `ContextualCorrectionStoreError`, and `ContextualCorrectionSaveResult` with exact signatures below.

**Owner test suite:** `ContextualStoreTests` owns exactly nine named tests: `testContextualStoreSavesConfirmedOccurrenceWithoutChangingGlossary`, `testContextualStoreAcceptsHundredAndRejectsHundredFirstWithoutEviction`, `testContextualStoreUsesSwiftCharacterLimitWithoutTruncation`, `testContextualStoreDuplicateIsIdempotentAndConflictingTargetRequiresDeletion`, `testContextualStoreRejectsInvalidIdentityOccurrenceAndLanguage`, `testContextualStoreAtomicWritePermissionsAndReload`, `testContextualStoreCorruptOversizedAndFailedRollbackPreserveTrustworthyBytes`, `testUnknownStoreVersionPreservesBytesAndBlocksMutation`, and `testContextualStoreHealthSnapshotStaysUnhealthyUntilVerifiedReload`. Put the shown snippets and table-driven edge fixtures inside `@MainActor final class ContextualStoreTests: XCTestCase`; annotate every helper that creates, reads, or mutates `ContextualCorrectionStore` with `@MainActor`, and run this whole class in every Task 1 RED/GREEN command. Generated-project membership is a shell gate immediately after XcodeGen, not an XCTest coupled to the checkout working directory.

- [ ] **Step 1: Write failing tests for validation, capacity, identity, and separation**

Append focused XCTest methods using temporary directories:

```swift
private func contextualExample(
    index: Int = 0,
    sentence: String? = nil,
    heard: String = "rosto",
    canonical: String = "Hostel",
    ordinal: Int = 1
) -> ContextualCorrectionExample {
    let resolvedSentence = sentence
        ?? "Contexto \(index): reservei um \(heard) na opção número \(index)."
    return ContextualCorrectionExample(
        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
        language: "pt", heard: heard, canonical: canonical,
        sentence: resolvedSentence, occurrenceOrdinal: ordinal
    )
}

@MainActor
private func makeContextualStore() -> ContextualCorrectionStore {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResenhaTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return ContextualCorrectionStore(fileURL: root.appendingPathComponent("ContextualCorrections/v1.json"))
}

func testContextualStoreSavesConfirmedOccurrenceWithoutChangingGlossary() throws {
    let suiteName = "ContextualStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let glossaryKey = "resenha.transcriptionGlossary"
    let originalGlossary = "rosto = Rosto\ncoisa energia = COESA Energia"
    defaults.set(originalGlossary, forKey: glossaryKey)
    let preferences = ProductPreferences(defaults: defaults)
    let rawGlossaryBefore = try XCTUnwrap(defaults.string(forKey: glossaryKey))
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections/v1.json")
    let store = ContextualCorrectionStore(fileURL: file)
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let result = store.save(.init(
        id: id, language: "pt", heard: "rosto", canonical: "Hostel",
        sentence: "Reservei um rosto perto da estação.", occurrenceOrdinal: 1
    ))

    XCTAssertEqual(result, .saved(id))
    XCTAssertEqual(store.examples.map(\.canonical), ["Hostel"])
    XCTAssertEqual(preferences.transcriptionGlossary, originalGlossary)
    XCTAssertEqual(defaults.string(forKey: glossaryKey), rawGlossaryBefore)
    XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber, 0o600)
}

func testContextualStoreAcceptsHundredAndRejectsHundredFirstWithoutEviction() throws {
    let store = makeContextualStore()
    for index in 0..<100 {
        let example = contextualExample(index: index)
        XCTAssertTrue(example.sentence.contains("rosto"))
        XCTAssertTrue(store.save(example).isSuccess)
    }
    XCTAssertEqual(store.save(contextualExample(index: 100)), .limitReached)
    XCTAssertEqual(store.examples.count, 100)
    XCTAssertEqual(Set(store.examples.map(\.id)).count, 100)
    XCTAssertEqual(Set(store.examples.map(\.sentence)).count, 100)
    XCTAssertEqual(store.examples.first?.id, contextualExample(index: 0).id)
}

func testContextualStoreUsesSwiftCharacterLimitWithoutTruncation() {
    let store = makeContextualStore()
    let sixHundred = String(repeating: "é", count: 594) + " rosto"
    let sixHundredOne = String(repeating: "é", count: 595) + " rosto"
    XCTAssertEqual(sixHundred.count, 600)
    XCTAssertEqual(sixHundredOne.count, 601)
    XCTAssertTrue(store.save(contextualExample(index: 1, sentence: sixHundred)).isSuccess)
    XCTAssertEqual(
        store.save(contextualExample(index: 2, sentence: sixHundredOne)),
        .invalid(.sentenceTooLong)
    )
}

func testContextualStoreDuplicateIsIdempotentAndConflictingTargetRequiresDeletion() {
    let store = makeContextualStore()
    let original = contextualExample(sentence: "Reservei um rosto.", canonical: "Hostel", ordinal: 1)
    XCTAssertTrue(store.save(original).isSuccess)
    XCTAssertEqual(store.save(original), .alreadyExists(original.id))
    XCTAssertEqual(store.save(contextualExample(index: 1, sentence: original.sentence, canonical: "hotel", ordinal: 1)), .conflict(original.id))
    XCTAssertEqual(store.examples, [original])
}

```

Also test: blank/identical/newline/`=` pairs, absent occurrence, invalid ordinal, item deletion, delete-all, reload, history-off independence, and a legacy glossary conflict reported but never mutated. No contextual/glossary-separation test may access `.standard` or a real user domain; every such test uses a UUID-named suite or injected spy, snapshots the raw stored string/bytes before and after, and removes the persistent domain in `defer`.

- [ ] **Step 2: Run the store tests and verify RED**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualStoreTests
```

Expected: FAIL because `ContextualCorrectionStore` and related types do not exist.

- [ ] **Step 3: Add the minimum domain and store interfaces**

Start `ContextualCorrections.swift` with these complete value types and the store protocol contract:

```swift
import Foundation
import Combine
import Security

struct ContextualCorrectionExample: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let language: String
    let heard: String
    let canonical: String
    let sentence: String
    let occurrenceOrdinal: Int
}

enum ContextualCorrectionValidationError: Equatable {
    case empty, identical, invalidCharacters, sentenceTooLong, occurrenceMissing, occurrenceAmbiguous
}

enum ContextualCorrectionSaveResult: Equatable {
    case saved(UUID), alreadyExists(UUID), conflict(UUID), limitReached
    case invalid(ContextualCorrectionValidationError)
    case storageFailure(recoveryRequired: Bool)

    var isSuccess: Bool {
        if case .saved = self { return true }
        if case .alreadyExists = self { return true }
        return false
    }
}

enum ContextualCorrectionStoreError: Error, Equatable, Sendable {
    case unavailable, oversized, corrupt, unsupportedVersion(Int), writeFailed, rollbackFailed
}

enum ContextualCorrectionStoreHealth: Equatable, Sendable {
    case healthy
    case unhealthy(ContextualCorrectionStoreError)
}

struct ContextualCorrectionStoreSnapshot: Equatable, Sendable {
    let examples: [ContextualCorrectionExample]
    let generation: UInt64
    let health: ContextualCorrectionStoreHealth
}

@MainActor
protocol ContextualCorrectionStoreContract: AnyObject {
    var examples: [ContextualCorrectionExample] { get }
    var error: ContextualCorrectionStoreError? { get }
    var generation: UInt64 { get }
    var snapshot: ContextualCorrectionStoreSnapshot { get }
    func save(_ example: ContextualCorrectionExample) -> ContextualCorrectionSaveResult
    func delete(id: UUID) -> Bool
    func deleteAll() -> Bool
    func reload() -> Bool
}
```

Implement `@MainActor final class ContextualCorrectionStore: ObservableObject, ContextualCorrectionStoreContract` with constants `schemaVersion = 1`, `maximumExamples = 100`, `maximumSentenceCharacters = 600`, and `maximumFileBytes = 2 * 1_024 * 1_024`, plus the exact initializer `init(fileURL: URL = Self.defaultURL(), fileManager: FileManager = .default)`. Every concrete property and method receives a real body in this step; do not paste a signature-only class shell. Use an envelope `private struct Envelope: Codable { let schemaVersion: Int; let examples: [ContextualCorrectionExample] }`. Validate the complete candidate before writing; write a same-directory temporary file with `.atomic`, set directory/file permissions to `0700`/`0600`, read and decode it, replace the final file, then read/decode the final file before publishing `examples` or incrementing `generation`.

Immediately after creating `ContextualCorrections.swift`, regenerate the project before any GREEN attempt and prove both the file reference and Sources membership exist:

```bash
set -euo pipefail
xcodegen generate
ruby -e 'require "yaml"; p=YAML.load_file("project.yml"); abort unless p.dig("targets", "WhisperKey", "sources").any? { |entry| entry == {"path"=>"Sources/WhisperKey"} }'
rg -n "ContextualCorrections\.swift.*PBXFileReference|ContextualCorrections\.swift in Sources" WhisperKey.xcodeproj/project.pbxproj
ruby -e 'p=File.read(ARGV[0]); n=p[/\/\* Begin PBXNativeTarget section \*\/(.*?)\/\* End PBXNativeTarget section \*\//m,1] or abort; t=n[/\/\* #{Regexp.escape(ARGV[1])} \*\/ = \{(.*?)\n\s*\};/m,1] or abort; id=t[/([A-F0-9]+) \/\* #{ARGV[3]} \*\//,1] or abort; phase=p[/#{id} \/\* #{ARGV[3]} \*\/ = \{(.*?)\n\s*\};/m,1] or abort; abort unless phase.include?("#{ARGV[2]} in #{ARGV[3]}")' WhisperKey.xcodeproj/project.pbxproj WhisperKey ContextualCorrections.swift Sources
git diff -- WhisperKey.xcodeproj/project.pbxproj
```

Expected: the source root is assigned to the `WhisperKey` application target in `project.yml`, the generated PBX file-reference/Sources association exists, and the next owner-suite GREEN compile proves target membership. No count heuristic, XCTest, `#filePath`, or assumed test working directory inspects `project.pbxproj`.

- [ ] **Step 4: Write failing recovery tests**

Add injected file-operation seams local to this file and tests for: file over 2 MiB, malformed JSON, schema `2`, temporary write failure, final read-back mismatch, rollback success, rollback failure, and delete-all leaving a known transaction file behind. Assert all preserve the last trustworthy in-memory examples, publish `.unhealthy(exactError)` in the typed snapshot, set `error`, reject subsequent mutations, and leave the original bytes untouched when possible. No failure silently publishes `.healthy` or an empty trustworthy store. Only an explicit `reload()` that completely reads, bounds-checks, decodes, validates, and read-backs a valid envelope may return the snapshot to `.healthy`; it increments generation so suspended work remains stale.

```swift
func testUnknownStoreVersionPreservesBytesAndBlocksMutation() throws {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections/v1.json")
    let bytes = Data(#"{"schemaVersion":2,"examples":[]}"#.utf8)
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    try bytes.write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    let store = ContextualCorrectionStore(fileURL: file)

    XCTAssertEqual(store.error, .unsupportedVersion(2))
    XCTAssertEqual(store.save(contextualExample()), .storageFailure(recoveryRequired: true))
    XCTAssertEqual(try Data(contentsOf: file), bytes)
}
```

- [ ] **Step 5: Implement recovery and make the focused suite GREEN**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualStoreTests
```

Expected: PASS, with no network access and no changes to `ProductPreferences.saveTranscriptionCorrection`.

- [ ] **Step 6: Run every new test and commit the generated store membership**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git add Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift WhisperKey.xcodeproj/project.pbxproj .specs/tasks/in-progress/add-context-aware-corrections.feature.md .specs/tasks/todo/add-context-aware-corrections.feature.md
git commit -m "feat: add contextual correction store"
```

Expected: generated diff adds only `ContextualCorrections.swift`; the full native suite, including every new store test, PASSes immediately before the commit.

### Task 2: Whole-Term Candidate Selection and Conservative Resolver

**Files:**
- Modify: `Sources/WhisperKey/ContextualCorrections.swift`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**
- Consumes: a typed `ContextualCorrectionStoreSnapshot`, immutable postprocessed text, language string, attempt UUID, `ContextualPolicyToken`, injected monotonic clock and injected decision provider.
- Produces: `ContextualCorrectionOccurrence`, `ContextualDecision`, `ContextualDecisionProvider`, `ContextualCorrectionPolicy`, shared `ContextualDecisionValidator`, `ValidatedContextualOutcome`, `ContextualResolutionResult`, `ContextualCorrectionResolver.resolve(_:)`, and an internal trace used only by the synthetic corpus runner.

**Owner test suite:** `ContextualResolverTests` owns `testResolverKeepsCommonRostoAndChangesOnlySupportedSecondOccurrence`, `testResolverOrdersMultiPairOccurrencesByRangeAndAssignsUniqueQuestionIDs`, `testResolverRejectsInvalidUnicodeSpanConflictAndSentenceSets`, `testResolverAbstainsEntireInputAboveThreeCandidateOccurrencesWithoutRequest`, `testResolverAppliesDollarAndBackslashCanonicalsLiterally`, `testResolverRejectsDisabledAndPersonalScopesBeforeProvider`, `testResolverRejectsUnhealthyStoreBeforeMatchingOrProvider`, `testResolverRecoversOnlyAfterExplicitVerifiedStoreReload`, `testResolverRequiresConfidenceAndSelectedProbabilityAtThreshold`, `testResolverRejectsMalformedProbabilityAndAnswerSets`, `testResolverDeadlineReturnsWithoutAwaitingLateProvider`, and `testResolverRejectsStoreGenerationChangedDuringSuspension`. Put all listed edge rows in these table-driven methods; every Task 2 RED/GREEN command runs this whole class.

- [ ] **Step 1: Write failing matcher tests for Unicode, ordinals, count, conflict, and literal application**

```swift
actor DecisionProviderStub: ContextualDecisionProvider {
    private(set) var requestCount = 0
    let decisions: [ContextualDecision]
    init(decisions: [ContextualDecision]) { self.decisions = decisions }
    func decide(sentence: String, language: String,
                occurrences: [ContextualCorrectionOccurrence],
                deadline: ContextualInstant) async throws -> ContextualDecisionReceipt {
        requestCount += 1
        return .init(decisions: decisions, resolvedModel: "fixture/deterministic",
                     inputTokens: nil, outputTokens: nil, costUSD: nil)
    }
}

actor CapturingDecisionProviderStub: ContextualDecisionProvider {
    private(set) var capturedOccurrences: [ContextualCorrectionOccurrence] = []
    private(set) var requestCount = 0
    func decide(sentence: String, language: String,
                occurrences: [ContextualCorrectionOccurrence],
                deadline: ContextualInstant) async throws -> ContextualDecisionReceipt {
        requestCount += 1
        capturedOccurrences = occurrences
        let decisions = occurrences.map {
            ContextualDecision(questionID: $0.questionID, choice: .keepOriginal,
                               confidence: 0.99, chosenProbability: 0.99,
                               runnerUpProbability: 0.01)
        }
        return .init(decisions: decisions, resolvedModel: "fixture/deterministic",
                     inputTokens: nil, outputTokens: nil, costUSD: nil)
    }
}

@MainActor
private func makeResolver(
    examples: [ContextualCorrectionExample] = [contextualExample()],
    provider: any ContextualDecisionProvider,
    policy: ContextualCorrectionPolicy,
    time: any ContextualMonotonicTime
) -> (resolver: ContextualCorrectionResolver, store: ContextualCorrectionStore,
      time: any ContextualMonotonicTime) {
    let store = makeContextualStore()
    for example in examples { XCTAssertTrue(store.save(example).isSuccess) }
    let resolver = ContextualCorrectionResolver(
        store: store, policy: policy, provider: provider,
        storeGeneration: { store.generation }, time: time
    )
    return (resolver, store, time)
}

@MainActor
private func request(text: String, policy: ContextualCorrectionPolicy,
                     store: ContextualCorrectionStore) -> ContextualResolutionRequest {
    .init(attemptID: UUID(), text: text, language: "pt",
          policyToken: policy.issueToken(scope: .testDouble),
          storeGenerationAtStart: store.generation)
}

@MainActor
func testResolverKeepsCommonRostoAndChangesOnlySupportedSecondOccurrence() async {
    let input = "Lavei o rosto antes de voltar ao rosto perto da estação."
    let provider = DecisionProviderStub(decisions: [
        .init(questionID: "o1", choice: .keepOriginal, confidence: 0.98,
              chosenProbability: 0.98, runnerUpProbability: 0.02),
        .init(questionID: "o2", choice: .replace, confidence: 0.97,
              chosenProbability: 0.97, runnerUpProbability: 0.03)
    ])
    let policy = ContextualCorrectionPolicy()
    let fixture = makeResolver(examples: [contextualExample()], provider: provider,
                               policy: policy, time: ManualContextualTime())

    let output = await fixture.resolver.resolve(request(text: input, policy: policy, store: fixture.store))

    XCTAssertEqual(output, "Lavei o rosto antes de voltar ao Hostel perto da estação.")
}

@MainActor
func testResolverOrdersMultiPairOccurrencesByRangeAndAssignsUniqueQuestionIDs() async {
    let input = "A cesta do rosto fica ao lado da sexta porta."
    let provider = CapturingDecisionProviderStub()
    let policy = ContextualCorrectionPolicy()
    let examples = [
        contextualExample(index: 10, sentence: "Reservei um rosto perto da estação.",
                          heard: "rosto", canonical: "Hostel"),
        contextualExample(index: 11, sentence: "Cheguei na sexta porta do corredor.",
                          heard: "sexta", canonical: "cesta"),
        contextualExample(index: 12, sentence: "A cesta de frutas ficou na mesa.",
                          heard: "cesta", canonical: "sexta")
    ]
    let fixture = makeResolver(examples: examples, provider: provider,
                               policy: policy, time: ManualContextualTime())
    let output = await fixture.resolver.resolve(
        request(text: input, policy: policy, store: fixture.store)
    )
    XCTAssertEqual(output, input)
    let occurrences = await provider.capturedOccurrences
    XCTAssertEqual(occurrences.map(\.questionID), ["o1", "o2", "o3"])
    XCTAssertEqual(occurrences.map(\.heard), ["cesta", "rosto", "sexta"])
    XCTAssertEqual(occurrences.map(\.ordinal), [1, 1, 1])
    let requestCount = await provider.requestCount
    XCTAssertEqual(requestCount, 1)
}

@MainActor
func testResolverAbstainsEntireInputAboveThreeCandidateOccurrencesWithoutRequest() async {
    let provider = DecisionProviderStub(decisions: [])
    let policy = ContextualCorrectionPolicy()
    let input = "rosto, rosto, rosto e rosto"
    let fixture = makeResolver(provider: provider, policy: policy,
                               time: ManualContextualTime())
    let output = await fixture.resolver.resolve(
        request(text: input, policy: policy, store: fixture.store)
    )
    XCTAssertEqual(output, input)
    let requestCount = await provider.requestCount
    XCTAssertEqual(requestCount, 0)
}

@MainActor
func testResolverAppliesDollarAndBackslashCanonicalsLiterally() async {
    let provider = DecisionProviderStub(decisions: [
        .init(questionID: "o1", choice: .replace, confidence: 0.99,
              chosenProbability: 0.99, runnerUpProbability: 0.01)
    ])
    let policy = ContextualCorrectionPolicy()
    let fixture = makeResolver(
        examples: [contextualExample(canonical: #"Hostel $1 \\ Centro"#)],
        provider: provider, policy: policy, time: ManualContextualTime()
    )
    let output = await fixture.resolver.resolve(
        request(text: "Reservei um rosto.", policy: policy, store: fixture.store)
    )
    XCTAssertEqual(output, #"Reservei um Hostel $1 \\ Centro."#)
}
```

In `testResolverRejectsInvalidUnicodeSpanConflictAndSentenceSets`, use named table rows `nfc`, `nfd`, `punctuation`, `substring`, `zero-candidate`, `invalid-ordinal`, `out-of-range-ordinal`, `overlap`, `multiple-sentences`, `sentence-601`, `conflicting-destination`, and `immutable-outside-range`; assert expected text and provider count for every row.

Add `testResolverRejectsDisabledAndPersonalScopesBeforeProvider`: issue `.disabled` and `.personalDictation` tokens against a provider spy, assert byte-for-byte original text and `requestCount == 0` for both. The only provider-eligible scopes are `.syntheticDiagnostic` and `.testDouble`; no future enum case is eligible by default.

Add `testResolverRejectsUnhealthyStoreBeforeMatchingOrProvider` with corrupt, oversized, unsupported-schema, and rollback-failed rows. Each row constructs or transitions the real store into the named `.unhealthy(error)` snapshot while preserving its last trustworthy examples, resolves text that would otherwise match, and asserts byte-for-byte original text, `requestCount == 0`, and no occurrence/matcher trace. Add `testResolverRecoversOnlyAfterExplicitVerifiedStoreReload`: begin unhealthy, externally replace the fixture file with a bounded valid schema-1 envelope, prove resolution still fails closed before reload, call `reload()`, assert a `.healthy` snapshot with incremented generation, then issue a fresh request/token and prove the provider is reached exactly once. A failed reload never clears unhealthy state or reuses the old request.

- [ ] **Step 2: Run matcher tests and verify RED**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualResolverTests
```

Expected: FAIL because the resolver contracts do not exist.

- [ ] **Step 3: Implement the exact resolver contracts**

```swift
struct ContextualCorrectionOccurrence: Equatable, Sendable {
    let questionID: String
    let heard: String
    let canonical: String
    let ordinal: Int
    let range: Range<String.Index>
}

enum ContextualDecisionChoice: String, Codable, Sendable {
    case keepOriginal = "keep_original"
    case replace = "replace_1"
}

struct ContextualDecision: Equatable, Sendable {
    let questionID: String
    let choice: ContextualDecisionChoice
    let confidence: Double
    let chosenProbability: Double
    let runnerUpProbability: Double
}

struct ContextualDecisionReceipt: Equatable, Sendable {
    let decisions: [ContextualDecision]
    let resolvedModel: String
    let inputTokens: Int?
    let outputTokens: Int?
    let costUSD: Decimal?
}

protocol ContextualDecisionProvider: Sendable {
    func decide(sentence: String, language: String,
                occurrences: [ContextualCorrectionOccurrence],
                deadline: ContextualInstant) async throws -> ContextualDecisionReceipt
}

struct ContextualInstant: Comparable, Sendable {
    let offset: Duration
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
}

protocol ContextualMonotonicTime: AnyObject, Sendable {
    func now() -> ContextualInstant
    func sleep(until deadline: ContextualInstant) async throws
}

final class ContinuousContextualTime: ContextualMonotonicTime, @unchecked Sendable {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    init() { origin = clock.now }
    func now() -> ContextualInstant { .init(offset: origin.duration(to: clock.now)) }
    func sleep(until deadline: ContextualInstant) async throws {
        try await clock.sleep(until: origin.advanced(by: deadline.offset))
    }
}

enum ContextualTimeCompositionError: Error, Equatable {
    case mismatchedOrigins
}

struct ContextualTimeComposition {
    let shared: any ContextualMonotonicTime

    init(resolver: any ContextualMonotonicTime,
         diagnostic: any ContextualMonotonicTime,
         transport: any ContextualMonotonicTime) throws {
        guard resolver === diagnostic, diagnostic === transport else {
            throw ContextualTimeCompositionError.mismatchedOrigins
        }
        shared = resolver
    }
}

enum ContextualTransportScope: Equatable, Sendable {
    case disabled, personalDictation, testDouble, syntheticDiagnostic
}

enum ContextualPolicyInvalidationReason: Sendable {
    case optedOut, credentialDeleted, storeMutated, appTerminated
}

struct ContextualPolicyToken: Equatable, Sendable {
    let requestID: UUID
    let generation: UInt64
    let scope: ContextualTransportScope
}

@MainActor
protocol ContextualCorrectionPolicyContract: AnyObject {
    var generation: UInt64 { get }
    func issueToken(scope: ContextualTransportScope) -> ContextualPolicyToken
    func register(_ token: ContextualPolicyToken,
                  cancel: @escaping @MainActor @Sendable () -> Void) -> Bool
    func finish(_ token: ContextualPolicyToken)
    func isCurrent(_ token: ContextualPolicyToken) -> Bool
    func invalidate(_ reason: ContextualPolicyInvalidationReason)
}

struct ContextualResolutionRequest: Sendable {
    let attemptID: UUID
    let text: String
    let language: String
    let policyToken: ContextualPolicyToken
    let storeGenerationAtStart: UInt64
}

struct ContextualDecisionTrace: Equatable, Sendable {
    let questionID: String
    let choice: ContextualDecisionChoice
    let selectedProbability: Double
    let runnerUpProbability: Double
    var margin: Double { selectedProbability - runnerUpProbability }
}

struct ValidatedContextualOutcome: Equatable, Sendable {
    enum Category: String, Codable, Sendable { case kept, replaced, abstained }
    let category: Category
    let decisions: [ContextualDecisionTrace]
}

struct ContextualResolutionResult: Equatable, Sendable {
    let text: String
    let outcome: ValidatedContextualOutcome
}

protocol ContextualDecisionValidating: Sendable {
    func validate(receipt: ContextualDecisionReceipt,
                  occurrences: [ContextualCorrectionOccurrence]) -> ValidatedContextualOutcome
}

@MainActor
protocol ContextualResolving: AnyObject {
    func resolve(_ request: ContextualResolutionRequest) async -> String
}

@MainActor
protocol ContextualCorrectionResolverContract: ContextualResolving {
    init(store: ContextualCorrectionStore, policy: ContextualCorrectionPolicy,
         provider: any ContextualDecisionProvider,
         storeGeneration: @escaping @MainActor @Sendable () -> UInt64,
         candidateMatcher: @escaping @MainActor @Sendable (
             _ examples: [ContextualCorrectionExample], _ text: String, _ language: String
         ) -> [ContextualCorrectionOccurrence],
         time: any ContextualMonotonicTime)
    static func matchCandidates(examples: [ContextualCorrectionExample],
                                text: String,
                                language: String) -> [ContextualCorrectionOccurrence]
    func resolve(_ request: ContextualResolutionRequest) async -> String
    func resolveWithTrace(_ request: ContextualResolutionRequest) async -> ContextualResolutionResult
}
```

Implement `@MainActor final class ContextualCorrectionPolicy: ContextualCorrectionPolicyContract`, `struct ContextualDecisionValidator: ContextualDecisionValidating`, and `@MainActor final class ContextualCorrectionResolver: ContextualCorrectionResolverContract` in this step. The resolver's concrete initializer uses the protocol signature above and supplies `ContextualCorrectionResolver.matchCandidates` as its default `candidateMatcher`; every concrete initializer/method has a real body implementing the rules below, never a signature-only shell.

At the first line of each resolve entrypoint, capture exactly one `let storeSnapshot = store.snapshot`. Guard `storeSnapshot.health == .healthy`, `request.storeGenerationAtStart == storeSnapshot.generation`, and current eligible policy scope before invoking `candidateMatcher` or creating any provider task; otherwise return the entire original with an abstained trace and request count zero. The unhealthy-store owner test injects a matcher closure that increments a counter and asserts it remains zero, so “before matching” is executable proof rather than inference from provider count. Production uses the exact static whole-term matcher by default, and matching reads only `storeSnapshot.examples`. After every suspension, require a new store snapshot that is still healthy and whose generation equals the captured snapshot/request; any unhealthy transition or generation change preserves the original and discards the receipt. Corrupt, oversized, unsupported-schema, rollback-failed, or failed-reload state therefore cannot reuse cached examples for a decision.

Enumerate whole-term matches with `"(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: heard))(?![\\p{L}\\p{N}])"`, matching the project's current boundary. Convert each validated `NSRange` once against the immutable input, derive one-based ordinals left-to-right per heard form, merge candidates from every pair, then sort the merged list by `range.lowerBound` in the immutable input. Only after that global sort, assign unique deterministic question IDs `o1...oN`; never restart IDs for a pair or dictionary iteration. Reject overlap and apply only `.replace` decisions from highest range to lowest with `String.replaceSubrange`. The multi-pair test inserts examples in non-text order and proves the provider receives global text order, unique IDs, and per-heard ordinals.

- [ ] **Step 4: Write failing validator/deadline tests**

`testResolverRequiresConfidenceAndSelectedProbabilityAtThreshold` owns rows `confidence-0899`, `probability-0899`, `both-0900`, and `both-1000`. `testResolverRejectsMalformedProbabilityAndAnswerSets` owns finite/range/total/tie/missing/extra/unknown/inconsistent/mixed rows. `testResolverDeadlineReturnsWithoutAwaitingLateProvider` owns 899/900/901-ms plus noncooperative-late rows. Every invalid row returns the entire original and no later callback changes it.

The test target implements this deterministic time source; it never calls `Task.sleep`, `usleep`, or a wall clock. `sleep(until:)` stores checked throwing continuations under `NSLock`, `advance(to:)` detaches/resumes every waiter whose deadline is reached, and its cancellation handler removes/resumes the matching waiter with `CancellationError` exactly once:

```swift
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

    func now() -> ContextualInstant {
        lock.lock(); defer { lock.unlock() }
        return instant
    }

    func sleep(until deadline: ContextualInstant) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelledIDs.remove(id) != nil {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else if instant >= deadline {
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append(.init(id: id, deadline: deadline, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: { [weak self] in self?.cancelWaiter(id) }
    }

    func advance(to next: ContextualInstant) {
        lock.lock()
        precondition(next >= instant)
        instant = next
        let ready = waiters.filter { $0.deadline <= next }
        waiters.removeAll { $0.deadline <= next }
        lock.unlock()
        ready.forEach { $0.continuation.resume() }
    }

    private func cancelWaiter(_ id: UUID) {
        lock.lock()
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            cancelledIDs.insert(id)
            lock.unlock(); return
        }
        let waiter = waiters.remove(at: index)
        lock.unlock()
        waiter.continuation.resume(throwing: CancellationError())
    }
}
```

For each `899`, `900`, and `901` row, create a fresh manual time, real resolver/store fixture, and controlled provider. Wait until the provider captures its request; advance directly to that exact millisecond. At `899`, resume the provider with a valid receipt and assert replacement. At `900` and `901`, advance without completing the provider and assert immediate original/abstained because completion requires `time.now() < deadline`. The `noncooperative-late` row ignores task cancellation and retains its continuation: advance to `900`, await the resolver's original result, then resume the provider and assert no trace/text/sink changes. All four rows assert elapsed wall-clock waiting is absent by inspecting only manual-time state and continuation events.

```swift
@MainActor
func testResolverRequiresConfidenceAndSelectedProbabilityAtThreshold() async {
    let original = "Reservei um rosto."
    func resolve(confidence: Double, probability: Double) async -> String {
        let provider = DecisionProviderStub(decisions: [
            .init(questionID: "o1", choice: .replace,
                  confidence: confidence, chosenProbability: probability,
                  runnerUpProbability: 1 - probability)
        ])
        let policy = ContextualCorrectionPolicy()
        let fixture = makeResolver(provider: provider, policy: policy,
                                   time: ManualContextualTime())
        return await fixture.resolver.resolve(
            request(text: original, policy: policy, store: fixture.store)
        )
    }
    let lowConfidence = await resolve(confidence: 0.899, probability: 1)
    let lowProbability = await resolve(confidence: 1, probability: 0.899)
    let accepted = await resolve(confidence: 0.900, probability: 0.900)
    XCTAssertEqual(lowConfidence, original)
    XCTAssertEqual(lowProbability, original)
    XCTAssertEqual(accepted, "Reservei um Hostel.")
}
```

- [ ] **Step 5: Implement validation and the single 900 ms completion race**

`ContextualCorrectionPolicy.invalidate` increments `generation` first, detaches all registered cancellation closures, then invokes them after clearing the registry. `register` accepts only a token whose generation is current; otherwise it invokes the supplied cancellation immediately and returns false. `finish` removes only the matching request ID. This closes the invalidate-before-register race without global task state.

At entry compute `let deadline = ContextualInstant(offset: time.now().offset + .milliseconds(900))` before matching. Require `request.storeGenerationAtStart == storeGeneration()` before provider creation. Before creating or registering a provider task, guard `request.policyToken.scope == .syntheticDiagnostic || request.policyToken.scope == .testDouble`; `.disabled`, `.personalDictation`, and every unrecognized/future scope return original plus `.abstained`/empty trace and zero provider requests. Pass the absolute deadline to the provider. Register the provider task's cancellation under `request.policyToken`; race provider completion against `time.sleep(until: deadline)` through one checked continuation/actor-owned completion state; cancel the provider task at the deadline but return original immediately without awaiting a noncooperative child. Recheck eligible scope, `policy.isCurrent(request.policyToken)`, `request.storeGenerationAtStart == storeGeneration()`, and `time.now() < deadline` before applying ranges, and call `policy.finish` on every exit. `testResolverRejectsStoreGenerationChangedDuringSuspension` suspends the fake provider, mutates the real store, resumes the provider, and asserts original text, stale outcome, and zero downstream mutation. Feed the immutable receipt through exactly one `ContextualDecisionValidator`; only a validated `.replaced` outcome permits reverse-range application, while invalid/missing/extra/low-confidence/tied decisions produce `.abstained` and original text. Implement `resolve(_:)` as `await resolveWithTrace(request).text`; the trace contains only bounded labels/probabilities and is never logged or persisted by product code.

- [ ] **Step 6: Run resolver tests GREEN and commit**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualResolverTests
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git add Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: resolve contextual corrections conservatively"
```

Expected: focused tests PASS; no production transport exists yet.

### Task 3: Frozen Synthetic Corpus, Decisions Client, Keychain, and One-Shot Guard

**Files:**
- Create: `Tests/Fixtures/contextual-corrections.json`
- Modify: `Sources/WhisperKey/ContextualCorrections.swift`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`
- Modify: `project.yml`
- Modify: `WhisperKey.xcodeproj/project.pbxproj` (generated only)

**Interfaces:**
- Consumes: Task 2's `ContextualDecisionProvider`; the same composed `ContextualMonotonicTime` used by resolver/diagnostic/transport; injected `DecisionsStreamingTransport`, credential store, guard URL, and bundled fixture loader.
- Produces: frozen alpha request/response DTOs, typed `ContextualDecisionReceipt`, `OpenRouterDecisionsClient`, `ContextualCredentialStore`, `SyntheticDiagnosticGuard`, authorization manager/checking interfaces plus their single owner, `SyntheticDiagnosticFixture`, `ContextualCorpusRunner`, and `SyntheticDiagnosticController.run() async throws -> SyntheticDiagnosticResult` with sanitized `SyntheticDiagnosticError` failures.

**Owner test suite:** `ContextualTransportCorpusTests` owns exactly `testCorpusSchemaFreezesLearningEvaluationAndDiagnosticIDs`, `testContextualCorpusRunnerEvaluatesAllCasesAndBaselinesDeterministically`, `testCorpusGateRejectsMixedCaseThatChangesUnauthorizedSpan`, `testCorpusRunnerSeedsStoreOnlyFromMappedLearningExamples`, `testDiagnosticFixtureLoadsFromCandidateAppBundle`, `testDecisionsClientRejectsStatusRedirectMalformedAndPrivatePayloadFields`, `testURLSessionDelegateStateCancelsBeforeQueueingByte65537`, `testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB`, `testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture`, `testDecisionsClientReturnsTypedReceiptFromSingleEnvelope`, `testDiagnosticAndResolverShareSemanticValidatorWithoutSideChannel`, `testSyntheticDiagnosticRunReturnsResultAndThrowsOnlySanitizedErrors`, `testSyntheticDiagnosticGuardConsumesBeforeConcurrentDispatch`, `testDiagnosticGuardCrashAfterMarkerBlocksWithoutDispatch`, `testDiagnosticGuardCrashAfterConsumedReplacementRemainsConsumed`, `testDiagnosticGuardCorruptUnknownOrOversizedStateBlocksWithoutDispatch`, `testDiagnosticGuardReadWriteAndReadBackFailuresBlockWithoutDispatch`, `testLocalBetaToggleNeverTouchesCredentialOrGuard`, `testDiagnosticAuthorizationOrdersConsentCredentialReadBackAndGuardFailClosed`, `testSyntheticDiagnosticTokenIssuedBeforeFirstAwaitAndCheckedBeforeTransportOpen`, `testSyntheticDiagnosticInvalidationDuringConsumeLeavesConsumedAndNeverOpensTransport`, and `testSyntheticAuthorizationConsumesBeforeDispatchExactlyOnce`. Every Task 3 RED/GREEN command runs the whole class; table fixtures enumerate each status/failure/guard state explicitly. Disabled/personal scope enforcement remains wholly in Task 2's resolver owner suite.

- [ ] **Step 1: Revalidate and freeze the alpha Decisions DTO without sending a request**

Read the official OpenRouter Decisions API reference, Jev tutorial, and `typesafe/jev-1.14` model page on the execution date. Use the literal current endpoint/model/field names to write the golden encoder/decoder test in Step 5 before adding any production DTO; retain only the official synthetic request/response fixtures and source URLs inside the test fixture/comments needed to explain those assertions. Task 3 creates or modifies no `docs/**` file. Task 6/SDD Step 03 will record retrieval timestamp, contract sources, payload shape, and limitations in the allowlisted evidence report. If endpoint, required fields, answer path, choice/probability shape, or model ID differs, the golden expectations follow the current official contract. This is schema inspection only: zero HTTP requests to the Decisions endpoint and zero credential access.

The Step 5 RED test targets the following app-owned types; implement them only in Step 6 after the golden test fails. Add `CodingKeys` only where the official schema uses a different spelling:

```swift
private struct DecisionsRequestDTO: Encodable {
    struct State: Encodable {
        struct Occurrence: Encodable {
            let heard: String
            let canonical: String
            let ordinal: Int
        }
        let language: String
        let text: String
        let occurrences: [Occurrence]
    }
    struct Question: Encodable {
        let type: String
        let instructions: String
        let criteria: [String: String]
    }
    let model: String
    let state: State
    let questions: [String: Question]
}

private struct DecisionsResponseDTO: Decodable {
    struct Answer: Decodable {
        let type: String
        let choice: String
        let probabilities: [String: Double]
        let confidence: Double
    }
    struct Usage: Decodable {
        let cost: Decimal?
        let inputTokens: Int?
        let outputTokens: Int?
    }
    let model: String
    let answers: [String: Answer]
    let usage: Usage?
}
```

The golden request asserts that `state` has exactly `language`, `text`, and `occurrences`, and that each occurrence has exactly `heard`, `canonical`, and `ordinal`; local range, attempt UUID, stored example sentence, target app, and credential never enter a DTO. The response decoder validates the exact expected answer-ID set after decoding. If official token keys differ, map those literal documented names through `Usage.CodingKeys` and update the golden fixture; do not maintain speculative aliases.

- [ ] **Step 2: Write the 100-case corpus with a frozen diagnostic fixture**

Use this schema and exact top-level shape:

```json
{
  "schemaVersion": 1,
  "corpusVersion": "2026-10-20.1",
  "evaluationPositiveIDs": [
    "pt-rosto-hostel-eval-positive-001",
    "pt-rosto-hostel-eval-positive-002",
    "pt-sessao-secao-eval-positive-001",
    "pt-sessao-secao-eval-positive-002",
    "pt-cesta-sexta-eval-positive-001",
    "pt-cesta-sexta-eval-positive-002",
    "pt-conserto-concerto-eval-positive-001",
    "pt-conserto-concerto-eval-positive-002",
    "pt-censo-senso-eval-positive-001",
    "pt-censo-senso-eval-positive-002",
    "pt-rosto-hostel-eval-positive-003",
    "pt-rosto-hostel-eval-positive-004",
    "pt-sessao-secao-eval-positive-003",
    "pt-sessao-secao-eval-positive-004",
    "pt-cesta-sexta-eval-positive-003",
    "pt-cesta-sexta-eval-positive-004",
    "pt-conserto-concerto-eval-positive-003",
    "pt-conserto-concerto-eval-positive-004",
    "pt-censo-senso-eval-positive-003",
    "pt-censo-senso-eval-positive-004"
  ],
  "learningExamples": [
    {
      "id": "learn-rosto-hostel-001",
      "pairID": "rosto-hostel",
      "language": "pt",
      "sentence": "O rosto oferece quartos compartilhados.",
      "heard": "rosto",
      "canonical": "Hostel",
      "ordinal": 1
    }
  ],
  "cases": [
    {
      "id": "pt-rosto-common-eval-001",
      "pairID": "rosto-hostel",
      "learningExampleIDs": ["learn-rosto-hostel-001"],
      "family": "evaluation",
      "group": "correct_original",
      "language": "pt",
      "input": "Meu rosto ficou vermelho.",
      "heard": "rosto",
      "canonical": "Hostel",
      "ordinal": 1,
      "expected": "Meu rosto ficou vermelho.",
      "providerOutcome": {
        "kind": "decisions",
        "answers": [{"ordinal": 1, "choice": "keep_original", "confidence": 0.98, "chosenProbability": 0.98, "runnerUpProbability": 0.02}]
      },
      "rationale": "Rosto descreve parte do corpo."
    }
  ],
  "diagnosticFixture": {
    "id": "pt-rosto-hostel-diagnostic-001",
    "pairID": "rosto-hostel",
    "learningExampleIDs": ["learn-rosto-hostel-001"],
    "language": "pt",
    "input": "Reservei uma cama no rosto perto da estação.",
    "heard": "rosto",
    "canonical": "Hostel",
    "ordinal": 1,
    "expected": "Reservei uma cama no Hostel perto da estação."
  }
}
```

The 20 literal IDs above are frozen before runner execution and may not be generated from observed outcomes. Complete exactly 100 synthetic `cases`: 30 `correct_original`, 20 `supported_correction`, 20 `ambiguous`, 15 `mixed_unicode`, and 15 `security_lifecycle`; include at least five ambiguous `pairID` values and only `calibration` or `evaluation` families. Every `evaluationPositiveIDs` entry resolves to a case with `family == evaluation`, `group == supported_correction`, and a changed expected output; no other case is eligible for recall. `learningExamples` and the single top-level `diagnosticFixture` are outside the 100-case count and outside metric gates. Every case has a pair ID plus explicit `learningExampleIDs` that resolve only to learning entries of the same pair. No case/diagnostic sentence may appear in `learningExamples`; calibration/evaluation/diagnostic records are never decoded as `ContextualCorrectionExample` or saved into the store. `providerOutcome` is either deterministic bounded decisions or one named failure (`offline`, `timeout`, `malformed`, `stale`, `ineligible`); it never contains generated replacement text. No sentence may come from personal history.

Each case must be semantically authored, not expanded from a numbered template. Define `semanticKey = pairID + "|" + family + "|" + normalize(input) + "|" + normalize(expected)`, where `normalize` applies compatibility composition, Portuguese case/diacritic/width folding, collapses whitespace/punctuation, replaces every digit run and ordinal token with `<n>`, and removes case-ID prefixes such as `caso`, `exemplo`, `variação`, and `cenário`. All 100 semantic keys must be unique. Reject cases whose input/expected become equal to another row after normalization, or whose only distinction is numbering, names swapped into the same sentence frame, punctuation, accents, or boilerplate. Every case requires a nonempty, case-specific `rationale` of at least 20 characters explaining the linguistic/contextual reason for its exact expected output; repeated normalized rationales fail.

Decode `family`, `group`, `providerOutcome.kind`, and every answer `choice` through closed `Codable` enums. Allowed labels are exactly `calibration|evaluation`, `correct_original|supported_correction|ambiguous|mixed_unicode|security_lifecycle`, `decisions|offline|timeout|malformed|stale|ineligible`, and `keep_original|replace_1`. Unknown/misspelled/case-varied labels fail fixture loading before store seeding, metric calculation, or report generation.

- [ ] **Step 3: Write failing corpus, runner, and resource tests**

`testCorpusSchemaFreezesLearningEvaluationAndDiagnosticIDs` asserts counts/groups/families, unique case/learning IDs, the exact frozen 20-ID positive list, phrase <=600, occurrence validity, five pairs, mappings, outcomes, sentence disjointness, 100 unique normalized semantic keys, 100 case-specific normalized rationales, and exactly one separate diagnostic fixture. Mutate one fixture copy per invalid label and assert decoding fails before runner invocation. Add a numbered-template duplicate whose raw strings differ but normalized key collides and assert rejection. `testCorpusRunnerSeedsStoreOnlyFromMappedLearningExamples` wraps the store with a save spy and forbids case/diagnostic/calibration/evaluation saves. `testDiagnosticFixtureLoadsFromCandidateAppBundle` asserts `Bundle.main`, bundle ID `br.com.luisroquette.Resenha`, `Contents/Resources`, schema, and the sole ID; no checkout/test-bundle fallback.

Add a `ContextualCorpusRunner` in the test target that executes all 100 cases through the real matcher/resolver with only the fixture provider double. For each case it creates a fresh store populated exclusively from that case's mapped `learningExampleIDs`, then compares three outputs: contextual resolver; keep-original baseline (`case.input`); and the exact legacy baseline `TranscriptPostprocessor.process(case.input, glossary: TranscriptionGlossary(text: "\(case.heard) = \(case.canonical)"))`. Its sorted `Codable` report must contain total/correct/false-positive/eligible-positive/correct-positive/abstention counts, correction recall, and per-pair counts plus min/median selected-vs-runner-up margin.

```swift
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

@MainActor
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
}
```

Report the three baselines overall, per family, and per pair, but compute acceptance gates only from `family == evaluation`. For every evaluation case and every baseline, first require grapheme-for-grapheme `output == expected` for `correct`. Build the sorted declared occurrence list from the immutable input, enumerate its bounded keep/replace masks, and render each mask by applying only the declared canonical replacements in reverse range order. The unique mask rendering `expected` defines authorized changed spans; absence or ambiguity invalidates the fixture before metrics. The mask rendering `output` defines actual changed spans. If no mask renders output exactly, increment `unauthorizedMutations` for that case because text outside the declared operations changed. Otherwise increment it when the actual mask replaces any span the expected mask keeps. Increment `harmfulSpanChanges` for each actual replaced span that expected keeps; an unrenderable output also increments it for every declared span whose grapheme slice differs from both its input and exact expected slice. A kept authorized span is an abstention/recall miss, not harmful, unless another unauthorized/harmful edit occurred. `safetyEvaluatedCases` counts every evaluation row and must equal evaluation `total`; calibration contributes zero to these three safety fields and cannot dilute them.

Count an evaluation false positive only when expected equals input and output differs; count recall only over the exact 20 frozen positive IDs; count an abstention when contextual output equals input and the fixture outcome is ambiguous/failure or a frozen positive was not applied. `testCorpusGateRejectsMixedCaseThatChangesUnauthorizedSpan` uses an evaluation sentence with two declared occurrences where expected changes only the authorized lodging span, then configures the provider to replace both; assert exact-output mismatch, `unauthorizedMutations == 1`, `harmfulSpanChanges == 1`, and acceptance failure even if false positives remain zero and recall remains at least 0.80. Calibration metrics are descriptive and cannot pass/fail the candidate; `diagnosticFixture` is never included in metrics. Gate: evaluation false positives, unauthorized mutations, and harmful span changes must all equal zero, safety-evaluated cases must cover every evaluation row, and evaluation recall must be at least `0.80`. Calculate each decision margin as `chosenProbability - runnerUpProbability` after validation, never from confidence. Set `generatedBy` to the stable literal `WhisperKeyTests.ContextualCorpusRunner/v1`; include no clock, machine path, UUID, or unordered dictionary in the report. When `CONTEXTUAL_CORPUS_REPORT_PATH` is set, encode the sorted report with `.sortedKeys` and write it atomically to that exact path; otherwise the test remains side-effect free.

- [ ] **Step 4: Register the resource and regenerate the project**

Add to both targets in `project.yml`:

```yaml
      - path: Tests/Fixtures/contextual-corrections.json
        buildPhase: resources
```

Then run:

```bash
set -euo pipefail
xcodegen generate
ruby -e 'require "yaml"; p=YAML.load_file("project.yml"); %w[WhisperKey WhisperKeyTests].each { |target| entries=p.dig("targets", target, "sources"); abort target unless entries.any? { |entry| entry == {"path"=>"Tests/Fixtures/contextual-corrections.json", "buildPhase"=>"resources"} } }'
rg -n "contextual-corrections\.json.*PBXFileReference|contextual-corrections\.json in Resources" WhisperKey.xcodeproj/project.pbxproj
for target_name in WhisperKey WhisperKeyTests; do
  ruby -e 'p=File.read(ARGV[0]); n=p[/\/\* Begin PBXNativeTarget section \*\/(.*?)\/\* End PBXNativeTarget section \*\//m,1] or abort; t=n[/\/\* #{Regexp.escape(ARGV[1])} \*\/ = \{(.*?)\n\s*\};/m,1] or abort; id=t[/([A-F0-9]+) \/\* #{ARGV[3]} \*\//,1] or abort; phase=p[/#{id} \/\* #{ARGV[3]} \*\/ = \{(.*?)\n\s*\};/m,1] or abort; abort unless phase.include?("#{ARGV[2]} in #{ARGV[3]}")' WhisperKey.xcodeproj/project.pbxproj "$target_name" contextual-corrections.json Resources
done
git diff -- project.yml WhisperKey.xcodeproj/project.pbxproj
```

Expected: `project.yml` assigns the resource to both named targets, the generated PBX file-reference/Resources associations exist, the Task 3 GREEN compile builds both targets, and `testDiagnosticFixtureLoadsFromCandidateAppBundle` proves the app-copy bundle path. No count heuristic or XCTest reads `project.pbxproj` from an assumed working directory.

- [ ] **Step 5: Write failing streaming transport, parser, privacy, and one-shot tests**

`testDecisionsClientRejectsStatusRedirectMalformedAndPrivatePayloadFields` captures requests and uses named rows `200`, `401`, `402`, `403`, `429`, `500`, `503`, `offline`, `timeout`, `redirect`, `malformed`, and `truncated`; it asserts exact URL/method/model/question IDs, bearer-only header, the allowlisted body keys, and absence of examples/history/audio/clipboard/app/UUID/key.

Pin the byte boundary with chunks, not one preassembled `Data`: 65,535 and 65,536 total bytes finish normally; a stream whose next chunk would produce 65,537 bytes calls `cancel()` immediately, throws `.responseTooLarge`, does not request/consume a later chunk, and never invokes the decoder. Also cancel on task cancellation/deadline and assert a late yielded chunk has no effect.

Every Task 3 clock-sensitive test creates one `let time = ManualContextualTime()` and injects that identical object into diagnostic controller and transport/client path; it never constructs separate manual origins for a single request. Distinct-origin rejection belongs only to `testClockCompositionRejectsDistinctOriginsAndSharesOneManualClock` and occurs before request construction.

Write two independent RED tests: `testURLSessionDelegateStateCancelsBeforeQueueingByte65537` drives the exact synchronized state used by `URLSessionDataDelegate` and proves the overflowing chunk is not queued; `testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB` uses the pull stub in limit-ignoring mode and proves the client's second defense. The delegate-state test injects a cancellation counter into `DecisionsDelegateState`, feeds chunks of 32,768, 32,768, 1, and then another chunk, and asserts accepted bytes remain 65,536, queued chunks remain two, cancellation is exactly one, and the fourth callback is ignored.

Name the schema golden test `testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture` and make it assert the exact coding-key set, answer path, choice labels, probabilities, confidence, usage, and model snapshot handling. Unknown fields may be ignored only where the current official envelope documents extensibility; missing required decision fields fail closed.

Add `testDecisionsClientReturnsTypedReceiptFromSingleEnvelope`: decode one response whose model differs by an allowed snapshot suffix and whose usage has known input/output tokens and cost; assert the returned `ContextualDecisionReceipt` contains those exact values and decisions. Mutate/release the transport afterward and prove the receipt remains complete without querying client state. Add `testDiagnosticAndResolverShareSemanticValidatorWithoutSideChannel`: pass the same valid, low-confidence, tied, missing-answer, and extra-answer receipts through resolver and diagnostic, assert identical `ValidatedContextualOutcome`, and prove the diagnostic reports `replaced` only for the validator's `.replaced` result.

The test double implements the same streaming boundary, without `URLProtocol`:

```swift
struct DecisionsStreamingSnapshot: Equatable, Sendable {
    let deliveredChunkCount: Int
    let cancelCount: Int
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

    init(statusCode: Int = 200, chunks: [Data], terminalError: Error? = nil,
         ignoresTransportLimit: Bool = false) {
        self.statusCode = statusCode
        self.chunks = chunks
        self.terminalError = terminalError
        self.ignoresTransportLimit = ignoresTransportLimit
    }

    func open(_ request: URLRequest,
              maximumResponseBytes: Int,
              deadline: ContextualInstant) async throws -> DecisionsResponseStream {
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url), statusCode: statusCode,
            httpVersion: "HTTP/1.1", headerFields: nil
        )!
        return DecisionsResponseStream(
            response: response,
            nextChunk: { [weak self] in
                guard let self else { return nil }
                self.lock.lock()
                defer { self.lock.unlock() }
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
            },
            cancel: { [weak self] in
                guard let self else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                guard !self.cancelled else { return }
                self.cancelled = true
                self.cancelCount += 1
            }
        )
    }

    func snapshot() -> DecisionsStreamingSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return .init(deliveredChunkCount: deliveredChunkCount, cancelCount: cancelCount)
    }
}
```

The stub is pull-driven: it advances its chunk index only inside `nextChunk()`, returns exactly one configured chunk per call, and returns no further chunk after cancellation. It does not pre-yield into an unbounded continuation. Protect the chunk index, cancellation flag, counts, and captured request with one private `NSLock`; do not hold it while returning data. The stub stores only counts and the captured request needed by payload assertions; it never accepts a real session or URL. Give it a mode that deliberately ignores `maximumResponseBytes` so the client's independent 64 KiB defense is tested separately from the delegate-state defense.

```swift
func testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB() async {
    let transport = DecisionsStreamingTransportStub(chunks: [
        Data(repeating: 0x20, count: 32_768),
        Data(repeating: 0x20, count: 32_768),
        Data([0x20]),
        Data(#"{"must":"not be consumed"}"#.utf8)
    ], ignoresTransportLimit: true)
    let client = OpenRouterDecisionsClient(transport: transport, credential: { "test-key" })
    let sentence = "Reservei um rosto."
    let range = sentence.range(of: "rosto")!
    let occurrence = ContextualCorrectionOccurrence(
        questionID: "o1", heard: "rosto", canonical: "Hostel", ordinal: 1, range: range
    )
    do {
        _ = try await client.decide(
            sentence: sentence, language: "pt", occurrences: [occurrence],
            deadline: ContextualInstant(offset: .milliseconds(900))
        )
        XCTFail("Expected responseTooLarge")
    } catch {
        XCTAssertEqual(error as? OpenRouterDecisionsError, .responseTooLarge)
    }

    let snapshot = transport.snapshot()
    XCTAssertEqual(snapshot.deliveredChunkCount, 3)
    XCTAssertEqual(snapshot.cancelCount, 1)
}
```

```swift
actor DispatchCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

func testSyntheticDiagnosticGuardConsumesBeforeConcurrentDispatch() async throws {
    let guardDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResenhaTests/\(UUID().uuidString)/ContextualCorrections")
    let guardStore = SyntheticDiagnosticGuard(directoryURL: guardDirectory)
    try await guardStore.provisionAuthorizedCall()
    let counter = DispatchCounter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<10 {
            group.addTask {
                guard (try? await guardStore.consume()) != nil else { return }
                await counter.increment()
            }
        }
    }
    let requestCount = await counter.value
    let persistedState = await SyntheticDiagnosticGuard(directoryURL: guardDirectory).currentState()
    XCTAssertEqual(requestCount, 1)
    XCTAssertEqual(persistedState, .ready(.consumed))
}
```

`testSyntheticAuthorizationConsumesBeforeDispatchExactlyOnce` covers restart after timeout/error/unknown outcome and requires consumed state. `testLocalBetaToggleNeverTouchesCredentialOrGuard` covers app launch, settings, Save, opt-out, and absent key with zero requests; disabled/personal provider rejection stays in Task 2 only.

Before adding production DTO/transport/guard code, also write `testDiagnosticGuardCrashAfterMarkerBlocksWithoutDispatch`, `testDiagnosticGuardCrashAfterConsumedReplacementRemainsConsumed`, `testDiagnosticGuardCorruptUnknownOrOversizedStateBlocksWithoutDispatch`, `testDiagnosticGuardReadWriteAndReadBackFailuresBlockWithoutDispatch`, `testLocalBetaToggleNeverTouchesCredentialOrGuard`, and `testDiagnosticAuthorizationOrdersConsentCredentialReadBackAndGuardFailClosed`. Inject file operations and ordered preference/credential/guard spies; cover false diagnostic consent, credential save/read-back/mismatch, every existing guard state, marker/available write/read-back, consumed transaction write/read-back, atomic replace, final chmod, and final read-back failures. Every failure asserts request count zero, unchanged local-beta setting, no automatic guard repair/reset, original guard bytes preserved where present, and no usable candidate credential.

Run the golden DTO, delegate-state, client-second-defense, and guard tests now:

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualTransportCorpusTests
```

Expected: FAIL because the frozen DTOs, delegate state, streaming client, and guard do not exist. Do not implement them before observing this RED result.

- [ ] **Step 6: Implement the streaming transport and narrow client contract**

```swift
struct DecisionsResponseStream: Sendable {
    let response: HTTPURLResponse
    let nextChunk: @Sendable () async throws -> Data?
    let cancel: @Sendable () -> Void
}

protocol DecisionsDelegateStateContract: Sendable {
    init(maximumResponseBytes: Int, cancelTask: @escaping @Sendable () -> Void)
    func receive(_ data: Data)
    func nextChunk() async throws -> Data?
    func finish(_ error: Error?)
    func cancel()
}

protocol DecisionsStreamingTransport: Sendable {
    func open(_ request: URLRequest,
              maximumResponseBytes: Int,
              deadline: ContextualInstant) async throws -> DecisionsResponseStream
}

protocol URLSessionDecisionsStreamingTransportContract: DecisionsStreamingTransport {
    init(time: any ContextualMonotonicTime)
}

protocol SyntheticDiagnosticDecisionProvider: Sendable {
    func decideSynthetic(sentence: String, language: String,
                         occurrences: [ContextualCorrectionOccurrence],
                         deadline: ContextualInstant,
                         beforeTransportOpen: @escaping @Sendable () async -> Bool) async throws
        -> ContextualDecisionReceipt
}

protocol OpenRouterDecisionsClientContract:
    ContextualDecisionProvider, SyntheticDiagnosticDecisionProvider {
    init(transport: any DecisionsStreamingTransport,
         credential: @escaping @Sendable () throws -> String)
}

protocol ContextualCredentialStore: Sendable {
    func save(_ value: String) throws
    func load() throws -> String?
    func delete() throws
}

enum KeychainContextualCredentialConstants {
    static let service = "br.com.luisroquette.Resenha.contextual-corrections"
    static let account = "openrouter-synthetic-diagnostic"
}

@MainActor
protocol ContextualOptInStore: AnyObject {
    var contextualCorrectionsEnabled: Bool { get }
    func persistContextualCorrectionsEnabled(_ enabled: Bool) throws
}

enum SyntheticDiagnosticGuardState: String, Codable, Sendable { case available, consumed }
enum SyntheticDiagnosticGuardHealth: Equatable, Sendable {
    case ready(SyntheticDiagnosticGuardState), blocked
}

protocol SyntheticDiagnosticGuardStore: Sendable {
    func provisionAuthorizedCall() async throws
    func consume() async throws
    func currentState() async -> SyntheticDiagnosticGuardHealth
}

@MainActor
protocol SyntheticDiagnosticAuthorizationManaging: AnyObject {
    func setLocalBetaEnabled(_ enabled: Bool) async throws
    func authorizeSyntheticDiagnostic(explicitConsent: Bool, credential: String) async throws
    func removeSyntheticDiagnosticCredential() async throws
}

@MainActor
protocol SyntheticDiagnosticAuthorizationChecking: AnyObject {
    func consumeForDispatch(token: ContextualPolicyToken) async throws
    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth
}

struct SyntheticDiagnosticAuthorizationHealth: Equatable, Sendable {
    let localBetaEnabled: Bool
    let diagnosticArmed: Bool
    let guardHealth: SyntheticDiagnosticGuardHealth
}

@MainActor
protocol SyntheticDiagnosticAuthorizationOwnerContract:
    SyntheticDiagnosticAuthorizationManaging, SyntheticDiagnosticAuthorizationChecking {
    init(optInStore: any ContextualOptInStore,
         credentialStore: any ContextualCredentialStore,
         guardStore: any SyntheticDiagnosticGuardStore,
         policy: ContextualCorrectionPolicy)
}

@MainActor
protocol SyntheticDiagnosticControllerContract: ObservableObject {
    init(policy: ContextualCorrectionPolicy,
         authorization: any SyntheticDiagnosticAuthorizationChecking,
         client: any SyntheticDiagnosticDecisionProvider,
         validator: ContextualDecisionValidator,
         fixture: SyntheticDiagnosticFixture,
         time: any ContextualMonotonicTime)
    func run() async throws -> SyntheticDiagnosticResult
}

enum SyntheticDiagnosticError: Error, Equatable, Sendable {
    case authorizationUnavailable
    case timedOut
    case providerRejected
    case transportUnavailable
    case invalidResponse
    case cancelled
}

struct SyntheticDiagnosticResult: Equatable, Sendable {
    let outcome: ValidatedContextualOutcome
    let receipt: ContextualDecisionReceipt
    let durationMilliseconds: Int
    let callCount: Int
}

struct SyntheticDiagnosticFixture: Decodable, Equatable, Sendable {
    static let id = "pt-rosto-hostel-diagnostic-001"
    let id: String
    let pairID: String
    let learningExampleIDs: [String]
    let language: String
    let input: String
    let heard: String
    let canonical: String
    let ordinal: Int
    let expected: String
}
```

Implement the concrete types `final class DecisionsDelegateState: DecisionsDelegateStateContract, @unchecked Sendable`, `final class URLSessionDecisionsStreamingTransport: NSObject, URLSessionDecisionsStreamingTransportContract, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable`, `actor OpenRouterDecisionsClient: OpenRouterDecisionsClientContract`, `KeychainContextualCredentialStore: ContextualCredentialStore`, `actor SyntheticDiagnosticGuard: SyntheticDiagnosticGuardStore`, `@MainActor final class SyntheticDiagnosticAuthorizationOwner: SyntheticDiagnosticAuthorizationOwnerContract`, and `@MainActor final class SyntheticDiagnosticController: SyntheticDiagnosticControllerContract`. The client constants are exactly endpoint `https://openrouter.ai/api/alpha/decisions`, model `typesafe/jev-1.14`, and `maximumResponseBytes = 64 * 1_024`; the Keychain implementation uses `KeychainContextualCredentialConstants`. `SyntheticDiagnosticGuard` exposes the exact initializer `init(directoryURL: URL = Self.defaultDirectoryURL())` and real static URL helpers. Every concrete method/initializer has a real body satisfying the behavior below; do not create signature-only shells.

The bundle loader rejects any diagnostic object whose `id != SyntheticDiagnosticFixture.id`; Settings/UI displays this same constant, request evidence records it, and no alias/legacy diagnostic ID is accepted.

The production directory is exactly `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]/Resenha/ContextualCorrections`; state is `diagnostic-authorization-v1.json` and the one-time marker is `diagnostic-authorization-provisioned-v1.json`. Both envelopes use `schemaVersion: 1`. `setLocalBetaEnabled(_:)` only persists/read-backs the local preference; disabling invalidates pending work, but enabling never reads/writes a credential or guard and never permits personal transport. `authorizeSyntheticDiagnostic(explicitConsent:credential:)` rejects false consent before mutation and never changes the local-beta preference. With explicit consent it performs: inspect guard health, save credential, load it back and require exact byte equality, then validate/provision/read back guard. On any thrown, mismatched, or uncertain step it invalidates pending diagnostic work, best-effort deletes/read-backs only the candidate credential, leaves local beta unchanged, leaves any guard artifact fail-closed, and exposes a non-secret error. Settings never writes preference, Keychain, or guard independently.

Guard-state behavior is exhaustive and testable: both files absent means first authorization may provision marker then `.available`; healthy existing `.available` means explicit reauthorization after opt-out/re-enable, app restart, or credential deletion validates permissions/schema and reuses it without rewriting/resetting the guard; `.consumed` rejects before credential save and can never become available again; `.blocked`, corrupt, oversized, missing-one-file, unknown-schema, or uncertain-read/write rejects before dispatch and never self-repairs. The owner keeps a non-persisted `diagnosticArmed` bit, false on launch, local disable, credential deletion, authorization failure, and dispatch; only successful `authorizeSyntheticDiagnostic` sets it true. Local beta may be toggled freely in all guard states because it is local-only, but re-enable alone never arms diagnostics; a consumed/blocked diagnostic remains unavailable.

When both guard files are absent, atomically write/read-back the marker first and then atomically write/read-back state `.available`. Marker present with missing state, state present with missing marker, any unknown schema/corruption/oversize, or any read/write/read-back uncertainty sets `.blocked` and never recreates availability. A crash after marker but before available therefore fails closed. Add ordered-call-spy tests proving `setLocalBetaEnabled(true/false)` makes zero credential/guard calls, while false diagnostic consent and failures at credential save, credential read-back/mismatch, marker write/read-back, or available write/read-back make zero requests and leave no usable candidate credential. Cover first authorization, healthy `.available` reauthorization after opt-out/re-enable and after key deletion, `.consumed`, and every blocked state. The diagnostic success order is `guard inspect -> credential save -> credential read-back -> guard provision-or-validate/read-back`; local beta is unchanged.

`consume()` accepts only healthy `.available`. In the same directory, encode `.consumed` to a uniquely named transaction file, set `0600`, read/decode it, atomically replace the state file, reapply `0600`, and read/decode the final file before returning success. The directory is created/read back as `0700`; marker/state/transaction are `0600`. Only after `consume()` returns success may controller code create a transport task. A crash after replacement leaves `.consumed`; timeout/error/unknown response never rewrites `.available`. Credential/example deletion and app restart never call provisioning or delete marker/state.

`SyntheticDiagnosticAuthorizationOwner.consumeForDispatch(token:)` requires `token.scope == .syntheticDiagnostic`, `policy.isCurrent(token)`, and `diagnosticArmed`, then clears the armed bit before its first suspension. It revalidates `policy.isCurrent(token)` immediately after every awaited preference, credential, and guard operation. It atomically consumes healthy `.available`; if opt-out, credential deletion, or termination invalidates while that actor call is suspended, the resumed owner observes the stale token, leaves the guard `.consumed`, throws, and permits zero network. Every mismatch is fail-closed.

`SyntheticDiagnosticController.run() async throws -> SyntheticDiagnosticResult` synchronously reads its injected shared clock for the start/deadline, issues the sole `.syntheticDiagnostic` token before its first `await`, registers one cancellation closure under that token, and calls only `consumeForDispatch(token:)`. After that suspension it rechecks `policy.isCurrent(token)` immediately before creating the client task. The task calls `decideSynthetic(...beforeTransportOpen:)`; after request encoding and immediately before `transport.open`, `OpenRouterDecisionsClient` awaits that injected closure, which returns `await MainActor.run { policy.isCurrent(token) }`, and refuses to open when false. The controller revalidates again after awaiting the client and before publishing a result, computes duration from that same clock origin, and calls `policy.finish` on every terminal path. Guard consumption always precedes task creation/dispatch. It passes the returned immutable receipt and exact fixture occurrences through the same injected `ContextualDecisionValidator` used by `ContextualCorrectionResolver`, then returns `SyntheticDiagnosticResult(outcome:receipt:durationMilliseconds:callCount:)`. Result category always comes from `ValidatedContextualOutcome`; controller/UI must never infer `replaced` from a raw choice, probability, answer count, or receipt metadata.

The controller catches lower-layer errors and throws only `SyntheticDiagnosticError`: failed consent/credential/guard/stale-token checks map to `.authorizationUnavailable`; the monotonic 900 ms deadline maps to `.timedOut`; HTTP 401/402/403/429/5xx map to `.providerRejected`; offline/session/delegate failures map to `.transportUnavailable`; malformed/truncated/oversized/semantically invalid envelopes map to `.invalidResponse`; explicit task cancellation maps to `.cancelled`. No case stores an underlying `Error`, status body, response body, URL request, phrase, pair, key, header, or provider message. `testSyntheticDiagnosticRunReturnsResultAndThrowsOnlySanitizedErrors` has named success, authorization, timeout, HTTP-401, transport, invalid-response, and cancellation rows; success asserts the exact typed result, while every failure uses `XCTAssertEqual(error as? SyntheticDiagnosticError, expected)` and reflection/string checks proving no payload or key survives.

`testSyntheticDiagnosticTokenIssuedBeforeFirstAwaitAndCheckedBeforeTransportOpen` uses ordered suspension gates at authorization entry, after consumption, and at `beforeTransportOpen`, asserting the token already exists at the first gate and is current at every resume. `testSyntheticDiagnosticInvalidationDuringConsumeLeavesConsumedAndNeverOpensTransport` has explicit `optedOut`, `credentialDeleted`, and `appTerminated` rows: suspend inside guard consumption after the atomic replacement, trigger invalidation, resume, and assert guard `.consumed`, transport-open count `0`, request count `0`, stale token, and no result. A fourth row invalidates at the before-open gate and asserts the same zero-network/no-result behavior. These interleavings and `testSyntheticAuthorizationConsumesBeforeDispatchExactlyOnce` form the authoritative AUTOMATED proof.

`testSyntheticAuthorizationConsumesBeforeDispatchExactlyOnce` proves the success/error order `token issued+registered -> credential load/read-back -> guard consume/write/read-back consumed -> current-token check -> transport open -> one request`, with `transport open` absent on every earlier failure; a simulated timeout/error after open leaves request count `1`, retry count `0`, and restart guard `.consumed`. Preserve its `.xcresult` path/hash in versioned pre-merge evidence. The manual remote observation never claims to prove internal ordering.

`URLSessionDecisionsStreamingTransport` stores the exact shared `ContextualMonotonicTime` injected by composition, rejects when `deadline <= time.now()`, and computes the positive remaining `Duration` as `deadline.offset - time.now().offset` for request/resource timeout bounds. It creates its private session from `.ephemeral` with `urlCache = nil`, `httpCookieStorage = nil`, `urlCredentialStorage = nil`, `httpShouldSetCookies = false`. Before `resume()`, install a lock-protected request state keyed by `taskIdentifier` containing `receivedByteCount`, the `maximumResponseBytes`, a bounded FIFO of pending chunks/waiters, terminal result, and idempotent cancellation flag; store neither credential nor decoded body there.

Inside `urlSession(_:dataTask:didReceive:)`, while holding the state lock, check `receivedByteCount <= maximumResponseBytes - data.count` before increment/enqueue. If false, mark terminal `.responseTooLarge`, detach waiters/state, release the lock, call that exact task's `cancel()`, and resume waiters with the size error; the overflowing chunk is never enqueued. If true, increment and satisfy one pending `nextChunk` waiter or enqueue that chunk. `didCompleteWithError` finishes/removes state exactly once. Redirect delegate returns `.cancel`. The stream's idempotent `cancel` closure performs the same detach/finish path and calls the exact `URLSessionDataTask.cancel()`; late callbacks find no state and do nothing.

`OpenRouterDecisionsClient` passes `maximumResponseBytes` to `open` and pulls with `while let chunk = try await stream.nextChunk()`. `decideSynthetic` builds the same request as `decide`, then awaits `beforeTransportOpen()` as its final action before calling `transport.open`; false throws `.authorizationInvalidated` with open/request counts still zero. As a second defense, before every append it checks `body.count <= maximumResponseBytes - chunk.count`; failure calls `stream.cancel()` immediately and throws `.responseTooLarge` without decoding or pulling again. Wrap the loop in `withTaskCancellationHandler` so deadline/caller cancellation also calls `stream.cancel()`. Validate HTTP status before decoding and return one immutable `ContextualDecisionReceipt` built from that same validated response envelope: bounded decisions, resolved response model, input/output token counts, and reported cost. There is no mutable metadata cache, callback, notification, singleton, or second parse; missing required diagnostic metadata fails diagnostic reporting closed. Map provider output only to local labels/ranges and never accept replacement text or offsets from the response.

- [ ] **Step 7: Implement scoped SecItem operations and sanitized result categories**

Use `kSecClassGenericPassword`, the fixed service/account, `kSecAttrSynchronizable: false`, and `kSecValueData`. Treat `errSecItemNotFound` as absent only on load/delete, update an existing item after `errSecDuplicateItem`, and map every other `OSStatus` to a non-content-bearing error. `SyntheticDiagnosticResult` contains only validated outcome traces, immutable typed receipt, duration, and call count; it must not retain body/header/pair/sentence or any independently derived category.

- [ ] **Step 8: Run every new test, generate only local temporary corpus evidence, and commit the Step 01 allowlist**

Before invoking the evaluation acceptance gate, freeze the finished fixture and hand it to a human or fresh agent who did not author/edit the corpus. That reviewer reads all 100 rows, not a sample, and creates the local ignored artifact `build/evidence/context-aware-corrections/offline/corpus-review.md` beginning with exactly `- Corpus author: ...`, `- Independent reviewer: ...`, `- Reviewed at (UTC): ...`, and `- Corpus SHA-256: \`<64 lowercase hex>\``. The Markdown header is exactly `| case ID | natural input | expected output | rationale | labels | learning mapping | overall |`, followed by its seven-cell separator. In every data row, `case ID`, `natural input`, `expected output`, and `rationale` must be nonempty text without `|`; the final three cells must each equal literal `PASS`. The identities must be nonempty and different. The reviewer must fail any numbered/template paraphrase, shallow lexical swap, duplicate normalized semantic key/rationale, incoherent expected output, invalid label, or unexplained ambiguity. Every row must be `PASS`; any failure returns to corpus authoring, changes the fixture hash, and requires a wholly new independent audit. The author cannot self-approve, and metric output observed before this audit cannot be used as acceptance evidence. Task 6 copies the sanitized audit metadata/table into its single allowlisted versioned report; Task 3 never stages the local review or metric JSON.

```bash
set -euo pipefail
mkdir -p build/evidence/context-aware-corrections/offline
corpus_sha=$(shasum -a 256 Tests/Fixtures/contextual-corrections.json | awk '{print $1}')
corpus_review=build/evidence/context-aware-corrections/offline/corpus-review.md
corpus_author=$(sed -n 's/^- Corpus author: //p' "$corpus_review")
corpus_reviewer=$(sed -n 's/^- Independent reviewer: //p' "$corpus_review")
reviewed_at=$(sed -n 's/^- Reviewed at (UTC): //p' "$corpus_review")
reviewed_sha=$(sed -n 's/^- Corpus SHA-256: `\([0-9a-f]\{64\}\)`$/\1/p' "$corpus_review")
test -n "$corpus_author"
test -n "$corpus_reviewer"
test "$corpus_author" != "$corpus_reviewer"
date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$reviewed_at" >/dev/null
test -n "$reviewed_sha"
test "$reviewed_sha" = "$corpus_sha"
review_ids=$(mktemp)
trap 'rm -f "$review_ids" "$review_ids.expected" "$review_ids.actual"' EXIT
awk -F '|' '
  BEGIN { header_seen=0 }
  function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
  /^\|/ {
    if (NF != 9) exit 41
    id=trim($2); input=trim($3); expected=trim($4); rationale=trim($5)
    labels=trim($6); mapping=trim($7); overall=trim($8)
    if (id == "case ID") {
      if (input != "natural input" || expected != "expected output" || rationale != "rationale" ||
          labels != "labels" || mapping != "learning mapping" || overall != "overall") exit 42
      header_seen++
      next
    }
    if (id ~ /^-+$/) next
    if (id == "" || input == "" || expected == "" || rationale == "") exit 43
    if (labels != "PASS" || mapping != "PASS" || overall != "PASS") exit 44
    print id
  }
  END { if (header_seen != 1) exit 45 }
' "$corpus_review" > "$review_ids"
test "$(wc -l < "$review_ids" | tr -d ' ')" -eq 100
test "$(sort -u "$review_ids" | wc -l | tr -d ' ')" -eq 100
jq -r '.cases[].id' Tests/Fixtures/contextual-corrections.json | sort > "$review_ids.expected"
sort "$review_ids" > "$review_ids.actual"
cmp "$review_ids.expected" "$review_ids.actual"
rm -f "$review_ids.expected" "$review_ids.actual"
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualTransportCorpusTests
CONTEXTUAL_CORPUS_REPORT_PATH="$PWD/build/evidence/context-aware-corrections/offline/corpus-report.json" ~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
shasum -a 256 build/evidence/context-aware-corrections/offline/corpus-report.json
git diff --check
test -z "$(git status --short -- docs)"
git add Sources/WhisperKey/ContextualCorrections.swift Tests/Fixtures/contextual-corrections.json Tests/WhisperKeyTests/WhisperKeyTests.swift project.yml WhisperKey.xcodeproj/project.pbxproj
git commit -m "feat: add isolated Jev diagnostic transport"
```

Expected: independent 100/100 semantic audit PASSes on the exact frozen corpus hash before acceptance metrics run; the full native suite PASSes using doubles; invalid labels and normalized duplicates block loading; the report contains exactly 100 contextual/keep/global observations with sorted per-pair metrics, every evaluation row is safety-evaluated, contextual false positives/unauthorized mutations/harmful span changes are all zero, the deliberate two-span mutation fails the gate, and a repeated run has a stable SHA-256; the 65,537-byte stream is cancelled on its third chunk; zero real network calls occur; and no secret appears in repository output.

### Task 4: Resolve Before Every Output and Reject Stale Attempts

**Files:**
- Modify: `Sources/WhisperKey/DictationCoordinator.swift`
- Modify: `Sources/WhisperKey/WhisperKeyApp.swift`
- Modify: `Sources/WhisperKey/ContextualCorrections.swift`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**
- Consumes: real `ContextualCorrectionResolver`, one validated shared `ContextualMonotonicTime`, injected internal `ContextualPolicyTokenSource`, and exact `@MainActor @Sendable () -> UInt64` store-generation reader.
- Produces: `DictationCompletion(id:targetApplication:text:language:)`; one final value passed to `stage`, `onTranscript`, `insertStaged`, and feedback, with one shared policy and clock owner wired through app lifecycle.

**Owner test suite:** `ContextualCoordinatorTests` owns `testCoordinatorUsesRealResolverAndOneResolvedStringForClipboardHistoryAndCompletion`, `testClockCompositionRejectsDistinctOriginsAndSharesOneManualClock`, `testCoordinatorProductionTokenSourceUsesOnlyDisabledOrPersonalScope`, `testCoordinatorTestTokenSourceUsesTestDoubleScope`, `testCoordinatorRejectsStoreMutationWhileResolverSuspended`, `testCoordinatorUnhealthyStoreKeepsOriginalUntilVerifiedReload`, `testCoordinatorIgnoresLateCompletionFromCancelledAttempt`, `testContextualPolicyInvalidationCancelsResolverAndDiagnosticAndRejectsOldTokens`, and `testCoordinatorProviderFailureFlowsOriginalExactlyOnce`. Every Task 4 RED/GREEN command runs this entire class. The acceptance harness below constructs a real `ContextualCorrectionStore`, saves the example, creates the shared policy, uses only a fake provider, builds a real `ContextualCorrectionResolver`, injects concrete token/generation sources into a real coordinator, and observes output sink callbacks; it never replaces the resolver or coordinator pipeline with a closure.

- [ ] **Step 1: Write failing sink-order and stale-attempt tests**

`testCoordinatorUsesRealResolverAndOneResolvedStringForClipboardHistoryAndCompletion` owns resolver/stage/history/insertion/completion spies and exact order `resolve -> stage(final) -> onTranscript(final) -> insertStaged -> onCompleted`. `testCoordinatorIgnoresLateCompletionFromCancelledAttempt` owns A-cancel/B-start/A-late and cancellation-after-stage rows. The invalidation test owns beta-off/delete-example/delete-key/termination; provider-failure test owns insertion/provider failure.

This XCTest integration is the acceptance harness for contextual replacement through `resolver -> coordinator -> staged clipboard/history -> insertion callback`: it uses only synthetic text, `.testDouble`, injected clipboard/insertion spies, and zero network. Mark this behavior `AUTOMATED`, not physical. Do not add a fake-provider menu, debug switch, launch argument, or diagnostic route to the release app merely to manufacture a manual replacement; the normal shipped app has no personal-dictation remote provider in this beta.

Add `testContextualPolicyInvalidationCancelsResolverAndDiagnosticAndRejectsOldTokens`: register one suspended resolver cancellation and one suspended diagnostic cancellation under the same generation, invoke each invalidation reason in an isolated policy instance, and assert generation increases from `n` to `n+1` before both cancellations observe it, each closure runs once, both tokens become stale, and late completions have no sink. Add integration tests proving store Save/delete/delete-all, opt-out, successful credential deletion, and termination each route through this owner exactly once.

`testCoordinatorUnhealthyStoreKeepsOriginalUntilVerifiedReload` uses the real store/resolver/coordinator and a provider counter. It drives corrupt, oversized, unsupported-schema, and rollback-failed snapshots through `finishTranscription`, asserting the original reaches stage/history/insertion/completion exactly once and provider count stays zero. It then externally installs a valid bounded envelope, proves another attempt remains fail-closed until explicit `store.reload()`, and only after successful reload starts a fresh attempt/generation whose fake provider is called once. This is the lifecycle recovery proof; cached examples or an old attempt can never revive an unhealthy store.

`testClockCompositionRejectsDistinctOriginsAndSharesOneManualClock` first passes three separately initialized `ManualContextualTime` instances to `ContextualTimeComposition` and asserts `.mismatchedOrigins`. It then passes one `let time = ManualContextualTime()` as resolver, diagnostic, and transport clocks, asserts object identity with `===`, constructs all three real components from `composition.shared`, advances that one clock to 899/900/901 ms, and proves resolver deadline, diagnostic duration/deadline, and transport remaining-time observations share the same origin. No owner test creates independent clocks for components in one composition.

```swift
@MainActor
final class DictationPipelineProbe: DictationOutputSink {
    enum Event: Equatable {
        case providerInput(String), staged(String), history(String), inserted, completed(String)
    }
    var events: [Event] = []
    func stage(_ text: String) throws -> Int { events.append(.staged(text)); return 7 }
    func insertStaged(into target: NSRunningApplication?, changeCount: Int) async throws {
        XCTAssertEqual(changeCount, 7)
        events.append(.inserted)
    }
}

actor AcceptanceDecisionProviderStub: ContextualDecisionProvider {
    let probe: DictationPipelineProbe
    init(probe: DictationPipelineProbe) { self.probe = probe }
    func decide(sentence: String, language: String,
                occurrences: [ContextualCorrectionOccurrence],
                deadline: ContextualInstant) async throws -> ContextualDecisionReceipt {
        await MainActor.run { probe.events.append(.providerInput(sentence)) }
        return .init(decisions: [
            .init(questionID: "o1", choice: .replace, confidence: 0.99,
                  chosenProbability: 0.99, runnerUpProbability: 0.01)
        ], resolvedModel: "fixture/deterministic", inputTokens: nil,
           outputTokens: nil, costUSD: nil)
    }
}

@MainActor
final class AcceptanceDiagnosticAuthorizationStub: SyntheticDiagnosticAuthorizationChecking {
    func consumeForDispatch(token: ContextualPolicyToken) async throws {
        preconditionFailure("Coordinator acceptance must not consume diagnostic authorization")
    }
    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth {
        preconditionFailure("Coordinator acceptance must not read diagnostic authorization")
    }
}

actor AcceptanceSyntheticDiagnosticProviderStub: SyntheticDiagnosticDecisionProvider {
    func decideSynthetic(sentence: String, language: String,
                         occurrences: [ContextualCorrectionOccurrence],
                         deadline: ContextualInstant,
                         beforeTransportOpen: @escaping @Sendable () async -> Bool) async throws
        -> ContextualDecisionReceipt {
        preconditionFailure("Coordinator acceptance must not invoke the synthetic diagnostic")
    }
}

@MainActor
func testCoordinatorUsesRealResolverAndOneResolvedStringForClipboardHistoryAndCompletion() async throws {
    let store = makeContextualStore()
    XCTAssertTrue(store.save(contextualExample(sentence: "Reservei um rosto.")).isSuccess)
    let policy = ContextualCorrectionPolicy()
    let time = ManualContextualTime()
    let composition = try ContextualTimeComposition(
        resolver: time, diagnostic: time, transport: time
    )
    let transport = URLSessionDecisionsStreamingTransport(time: composition.shared)
    let diagnostic = SyntheticDiagnosticController(
        policy: policy,
        authorization: AcceptanceDiagnosticAuthorizationStub(),
        client: AcceptanceSyntheticDiagnosticProviderStub(),
        validator: ContextualDecisionValidator(),
        fixture: .init(
            id: SyntheticDiagnosticFixture.id,
            pairID: "rosto-hostel",
            learningExampleIDs: ["learn-rosto-hostel-001"],
            language: "pt",
            input: "Reservei uma cama no rosto perto da estacao.",
            heard: "rosto",
            canonical: "Hostel",
            ordinal: 1,
            expected: "Reservei uma cama no Hostel perto da estacao."
        ),
        time: composition.shared
    )
    let probe = DictationPipelineProbe()
    let provider = AcceptanceDecisionProviderStub(probe: probe)
    let resolver = ContextualCorrectionResolver(
        store: store, policy: policy, provider: provider,
        storeGeneration: { store.generation }, time: composition.shared
    )
    XCTAssertTrue(composition.shared === time)
    _ = transport
    _ = diagnostic
    let coordinator = DictationCoordinator(
        permissions: PermissionService(), panel: FloatingPanelController(),
        language: { .portuguese },
        onTranscript: { probe.events.append(.history($0)) },
        outputSink: probe, contextualResolver: resolver,
        contextualTokenSource: { _ in policy.issueToken(scope: .testDouble) },
        contextualStoreGeneration: { store.generation }
    )
    coordinator.onCompleted = { probe.events.append(.completed($0.text)) }
    coordinator.transition(to: .recording)
    coordinator.transition(to: .transcribing)
    let attemptID = coordinator.attemptID

    try await coordinator.finishTranscription(
        "Reservei um rosto.", attemptID: attemptID, language: .portuguese
    )

    XCTAssertEqual(probe.events, [
        .providerInput("Reservei um rosto."), .staged("Reservei um Hostel."),
        .history("Reservei um Hostel."), .inserted, .completed("Reservei um Hostel.")
    ])
}
```

- [ ] **Step 2: Run lifecycle tests and verify RED**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualCoordinatorTests
```

Expected: FAIL because `DictationCompletion` has no text/language, policy ownership is not composed, and resolution is not in the pipeline.

- [ ] **Step 3: Extend completion and inject the Task 2 resolver interface**

```swift
struct DictationCompletion {
    let id: UUID
    let targetApplication: NSRunningApplication?
    let text: String
    let language: TranscriptionLanguage
    let retentionProbe: ContextRetentionProbe?

    init(id: UUID, targetApplication: NSRunningApplication?, text: String,
         language: TranscriptionLanguage, retentionProbe: ContextRetentionProbe? = nil) {
        self.id = id
        self.targetApplication = targetApplication
        self.text = text
        self.language = language
        self.retentionProbe = retentionProbe
    }
}

final class ContextRetentionProbe {
    private let onDeinit: () -> Void
    init(onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

typealias ContextualPolicyTokenSource = @MainActor @Sendable (_ attemptID: UUID) -> ContextualPolicyToken
typealias ContextualStoreGenerationSource = @MainActor @Sendable () -> UInt64

@MainActor
protocol DictationOutputSink {
    func stage(_ text: String) throws -> Int
    func insertStaged(into target: NSRunningApplication?, changeCount: Int) async throws
}

extension TextInjector: DictationOutputSink {}
```

`ContextRetentionProbe` is an internal lifetime-observation seam only: production coordinator-created completions use the default `nil`, no UI branches on it, and it carries no text or user data. Tests may supply it to prove that the completion/context/session ownership chain releases; its presence must not change release behavior, persistence, accessibility, or serialization.

Add the protocol and `extension TextInjector: DictationOutputSink {}` in `DictationCoordinator.swift`; the protocol is not class-bound because the existing `TextInjector` is a struct. Make zero edits to `TextInjector.swift`. Add exact required parameters to `DictationCoordinator.init`: `outputSink: any DictationOutputSink = TextInjector()`, `contextualResolver: any ContextualResolving`, `contextualTokenSource: @escaping ContextualPolicyTokenSource`, and `contextualStoreGeneration: @escaping ContextualStoreGenerationSource`. There is no default identity resolver. Extract the existing post-transcriber body into the real internal method `func finishTranscription(_ transcript: String, attemptID: UUID, language: TranscriptionLanguage) async throws`; both `hotkeyReleased()` and the acceptance test call this same method. Production composition injects the real resolver and a source that issues only `.disabled` when local beta is off or `.personalDictation` when on; neither scope reaches provider. Test composition explicitly injects a source issuing `.testDouble`; `.testDouble` is unavailable from production UI/settings. At method entry capture `let generation = contextualStoreGeneration()` and build the request with that value/token before suspension. After real-resolver completion run cancellation/attempt/policy-current/`generation == contextualStoreGeneration()` guards, assign `let final`, then call `outputSink.stage(final)`, `onTranscript(final)`, transition/`outputSink.insertStaged`, and create completion from captured `final`/language before `reset()`. The suspended-store-mutation test changes the real store before provider resume and proves zero stage/history/insertion/completion.

- [ ] **Step 4: Compose local-only production policy in AppDelegate**

Create exactly one `let contextualTime = ContinuousContextualTime()`, one `ContextualCorrectionPolicy`, one `ContextualCorrectionStore`, one `SyntheticDiagnosticAuthorizationOwner`, and one resolver in `AppDelegate`. Validate `ContextualTimeComposition(resolver: contextualTime, diagnostic: contextualTime, transport: contextualTime)`, construct `URLSessionDecisionsStreamingTransport(time: composition.shared)`, `ContextualCorrectionResolver(..., time: composition.shared)`, and `SyntheticDiagnosticController(..., time: composition.shared)`, and retain the shared clock for all three lifetimes. There is no production initializer default that creates another clock, so every `ContextualInstant.offset`, deadline, remaining timeout, and diagnostic duration is comparable within one origin. Inject the same policy into coordinator/resolver/authorization owner, the manager interface into settings, and the checking interface into the diagnostic controller. The coordinator issues `.disabled` while the beta is off and `.personalDictation` while it is on; both preserve the original before provider creation. Only `SyntheticDiagnosticController` may issue `.syntheticDiagnostic`, tests may issue `.testDouble`, and settings cannot create or mutate tokens.

Wire concrete invalidation paths: a successful store `save`, `delete`, or `deleteAll` calls one `store.onMutation` closure that invokes `.invalidate(.storeMutated)`; `authorization.setLocalBetaEnabled(false)` persists/read-backs false then invokes `.invalidate(.optedOut)` exactly once without touching key/guard; `authorization.removeSyntheticDiagnosticCredential()` invokes `.invalidate(.credentialDeleted)` exactly once before `SecItemDelete`, verifies absence, and leaves local beta unchanged (an already-absent item is success; deletion/read-back failure remains visible and cannot resume the cancelled generation); app termination invokes `.invalidate(.appTerminated)`. Failed store mutations do not claim state change. Tests hold a suspended resolver and suspended diagnostic transport for every trigger, assert generation increments exactly once, both registered cancellations fire, the old tokens fail `isCurrent`, and late completions produce zero sinks/results.

- [ ] **Step 5: Run lifecycle and existing coordinator suites GREEN**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualCoordinatorTests
```

Expected: PASS; cancellation/obsolete attempt emits no fallback and no sink, while provider failure on a still-current attempt flows original exactly once.

- [ ] **Step 6: Commit the output lifecycle integration**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git add Sources/WhisperKey/DictationCoordinator.swift Sources/WhisperKey/WhisperKeyApp.swift Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: resolve contextual text before insertion"
```

### Task 5: Contextual Save, Settings, Accessibility, and Ownership

**Files:**
- Modify: `Sources/WhisperKey/FloatingPanel.swift`
- Modify: `Sources/WhisperKey/ProductPreferences.swift`
- Modify: `Sources/WhisperKey/WhisperKeyApp.swift`
- Modify: `Sources/WhisperKey/PermissionOnboarding.swift`
- Modify: `Sources/WhisperKey/ContextualCorrections.swift`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**
- Consumes: completion text/language, store Save/delete/reload, `SyntheticDiagnosticAuthorizationManaging`, and diagnostic controller.
- Produces: explicit sentence/occurrence confirmation, contextual example controls, opt-in disclosure, credential deletion, accessible status, and no call to `saveTranscriptionCorrection` from feedback.

**Owner test suite:** `ContextualFeedbackSettingsTests` owns `testFeedbackSaveCreatesContextualExampleWithoutGlobalGlossaryRule`, `testFeedbackRejectsAbsentMultipleUnselectedAndOversizedOccurrence`, `testFeedbackPreservesDraftAcrossDuplicateConflictLimitAndWriteFailure`, `testContextualFeedbackReleasesCompletionAcrossEveryExit`, `testContextualSettingsLocalToggleNeverTouchesDiagnosticAuthorization`, `testContextualSettingsAuthorizationAndRemovalExposeSanitizedErrors`, `testContextualSettingsDiagnosticCatchesOnlySanitizedErrors`, `testContextualSettingsNeverEnablePersonalRemoteTransport`, and `testContextualControlsHaveExactAccessibilityLabelsAndRestoreFocus`. Every Task 5 RED/GREEN command runs this whole class; table rows name each exit and OSStatus/error case.

- [ ] **Step 1: Write failing Save and ownership tests**

The four feedback owner tests use named rows for Save/reload, absent match, multiple-unselected, 601 characters, duplicate, conflict, limit, write failure, history-off, and legacy conflict. `testContextualFeedbackReleasesCompletionAcrossEveryExit` owns `expiry`, `approve`, `save`, `cancel`, `replacement`, `new-dictation`, `hud-off`, and `termination` rows using the reference-type `ContextRetentionProbe`; recovery asserts only heard/canonical/sentence<=600/ordinal/language/minimum-focus survive.

For each exit row, create an XCTest deinit expectation and install the completion inside a nested scope so the test retains no strong probe after `offerFeedback`. `FeedbackContext` holds `let retentionProbe: ContextRetentionProbe?`; when correction opens, `CorrectionSession` holds that same optional reference. Every terminal/replacement path nils/removes both owners. The persisted recovery draft has no probe field and cannot retain it. Fulfillment plus `XCTAssertNil(weakProbe)` proves the text/context owner was released; do not attempt a weak reference to the value-type `DictationCompletion`.

```swift
@MainActor
private extension XCTestCase {
    func assertContextReleased(
        panel: FloatingPanelController,
        rowName: String,
        text: String,
        performExit: (FloatingPanelController) -> Void
    ) {
        let released = expectation(description: "context released: \(rowName)")
        weak var weakProbe: ContextRetentionProbe?
        do {
            let probe = ContextRetentionProbe { released.fulfill() }
            weakProbe = probe
            panel.offerFeedback(.init(
                id: UUID(), targetApplication: nil, text: text,
                language: .portuguese, retentionProbe: probe
            ))
        }
        performExit(panel)
        wait(for: [released], timeout: 1)
        XCTAssertNil(weakProbe)
    }
}
```

```swift
@MainActor
private func assertFeedbackSaveCreatesContextualExampleWithoutGlobalGlossaryRule(
    panel: FloatingPanelController,
    preferences: ProductPreferences,
    store: ContextualCorrectionStore
) {
    let completion = DictationCompletion(
        id: UUID(), targetApplication: nil,
        text: "Reservei um rosto perto da estação.", language: .portuguese
    )
    let baseline = preferences.transcriptionGlossary
    panel.offerFeedback(completion)
    panel.openCorrection(token: completion.id)
    panel.updateCorrectionDraft(token: completion.id, heard: "rosto", canonical: "Hostel")
    panel.selectCorrectionOccurrence(token: completion.id, ordinal: 1)
    panel.saveCorrection(token: completion.id)

    XCTAssertEqual(store.examples.map(\.canonical), ["Hostel"])
    XCTAssertEqual(preferences.transcriptionGlossary, baseline)
}
```

The named owner test `testFeedbackSaveCreatesContextualExampleWithoutGlobalGlossaryRule` creates its isolated harness and calls this helper; each ownership row calls `assertContextReleased(panel:rowName:text:performExit:)` with its concrete exit closure.

- [ ] **Step 2: Run Save tests and verify RED**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualFeedbackSettingsTests
```

Expected: FAIL because Save still writes the glossary and the editor has no phrase/ordinal.

- [ ] **Step 3: Change feedback configuration without touching visual feedback views**

Replace the dependency with the concrete `FloatingPanelController` methods `func configureFeedback(preferences: ProductPreferences, store: ContextualCorrectionStore)` and `func selectCorrectionOccurrence(token: UUID, ordinal: Int)`. Implement both bodies in this step: configuration retains the injected dependencies for the controller lifetime, and selection mutates only the matching active correction session after validating that `ordinal` exists in its candidate list.

Extend `CorrectionSession` with language, validated sentence, candidate ordinals, and selected ordinal. Extract `let token = context.id` before building SwiftUI actions; closures capture only `token` and weak controller. The editor displays the confirmed sentence, labels each matching occurrence, requires explicit choice when count >1, and calls `store.save` on Save. Keep `ProductPreferences.saveTranscriptionCorrection` and its tests unchanged for direct legacy glossary editing, but remove it from this feedback path.

Add explicit `import Combine` to `FloatingPanel.swift` because it declares `ObservableObject`/`@Published`. `ContextualCorrections.swift` already adds it in Task 1 for both the store and diagnostic controller; add it explicitly to `ProductPreferences.swift` in Step 5 before adding the new published beta property. Combine is a macOS system framework import, not a package or new dependency.

- [ ] **Step 4: Write failing settings/privacy-control tests**

`testContextualSettingsLocalToggleNeverTouchesDiagnosticAuthorization` owns default/reopen/toggle rows; `testContextualSettingsAuthorizationAndRemovalExposeSanitizedErrors` owns save/read-back/provision/remove OSStatus rows; `testContextualSettingsDiagnosticCatchesOnlySanitizedErrors` injects success plus `.authorizationUnavailable`, `.timedOut`, `.providerRejected` (the HTTP-401 mapping), `.transportUnavailable`, `.invalidResponse`, and `.cancelled`, then asserts that the UI uses `do { let result = try await diagnostic.run(); ... } catch let error as SyntheticDiagnosticError { ... }`, renders only fixed localized copy, renders no provider/body/key text, and shows no failure banner for cancellation; `testContextualSettingsNeverEnablePersonalRemoteTransport` owns missing beta/key/fixture/available-guard and every settings action with request count zero; `testContextualControlsHaveExactAccessibilityLabelsAndRestoreFocus` owns labels/hints/errors/focus. The view calls only the manager interface.

Every settings test above creates its own UUID-named `UserDefaults` suite, passes it to `ProductPreferences(defaults:)`, and removes its persistent domain with `defer`; no settings test reads or writes `.standard` or a real preference domain. Use this fixture at the first line of each settings owner test (not one shared mutable suite):

```swift
private struct SettingsPreferencesFixture {
    let suiteName: String
    let defaults: UserDefaults
    let preferences: ProductPreferences

    static func make() throws -> Self {
        let suiteName = "ContextualFeedbackSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return .init(suiteName: suiteName, defaults: defaults,
                     preferences: ProductPreferences(defaults: defaults))
    }
}
```

At the first line of each named settings owner test, create `let fixture = try SettingsPreferencesFixture.make()`, immediately register `defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }`, and bind `let preferences = fixture.preferences` before exercising UI state.

Use the visible copy:

```text
Correções contextuais (beta)
Beta local, desligado por padrão: salva e organiza exemplos confirmados neste Mac.
Neste beta, esses exemplos ainda não aplicam correções automáticas ao ditado pessoal.
Diagnóstico de infraestrutura: envia somente a frase sintética identificada ao OpenRouter/TypeSafe, uma única vez.
O diagnóstico não recebe nem corrige seu ditado pessoal.
```

`testContextualSettingsNeverEnablePersonalRemoteTransport` asserts these four lines verbatim in this order and request count zero after every local-beta action. The diagnostic button accessibility label is `Executar diagnóstico sintético uma vez`; destructive actions are `Apagar exemplo contextual`, `Apagar todos os exemplos contextuais`, and `Remover chave do diagnóstico`.

- [ ] **Step 5: Implement preferences and settings with one composition root**

Add only `@Published private(set) var contextualCorrectionsEnabled: Bool`, backed by `resenha.contextualCorrectionsEnabled`, default false, and conform `ProductPreferences` to `ContextualOptInStore` through an internal throwing write/read-back method. Only `SyntheticDiagnosticAuthorizationOwner` calls that method; tests inject a failing opt-in store. Pass store, authorization-manager interface, and diagnostic objects into `ProductSettingsView` and `ProductSettingsWindowController`; do not put examples or secrets in `UserDefaults`. Add a contextual section inside the existing Transcription pane rather than a new navigation architecture. The view calls the owner methods wired in Task 4 rather than maintaining its own generation counter. Deletion failure remains visible and is not announced as success.

The diagnostic button awaits `try await diagnostic.run()` in a `do/catch`. On success it renders only the validated outcome and typed receipt metadata. Its exhaustive `SyntheticDiagnosticError` catch maps authorization, timeout, provider rejection, transport, and invalid response to fixed app-owned Portuguese strings and treats cancellation as silent dismissal; a final unknown catch renders one generic app-owned failure string. No caught error interpolation, `localizedDescription`, provider status/body, request data, fixture sentence, or key reaches UI state, accessibility text, logs, or clipboard. Put this complete helper in the settings model and bind its two returned values to published state:

```swift
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
```

Use the concrete initializer `ProductSettingsView.init(preferences:contextualStore:authorization:diagnostic:initialSection:)`, with `initialSection: ProductSettingsSection = .general`, and `ProductSettingsWindowController.init(preferences:contextualStore:authorization:diagnostic:)` so the app and Settings scene share the same instances. Implement both initializer bodies in this step by assigning every stored dependency; do not add signature-only declarations.

- [ ] **Step 6: Update onboarding's absolute copy**

Use `O áudio permanece neste Mac. Correções contextuais ficam locais; somente o diagnóstico sintético opcional usa rede.` and change the status pill from `100% local` to `Áudio local`. Do not suggest that personal dictation is remotely enabled.

- [ ] **Step 7: Run feedback/settings/accessibility regressions GREEN and commit**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/ContextualFeedbackSettingsTests
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git add Sources/WhisperKey/FloatingPanel.swift Sources/WhisperKey/ProductPreferences.swift Sources/WhisperKey/WhisperKeyApp.swift Sources/WhisperKey/PermissionOnboarding.swift Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: teach contextual corrections from feedback"
```

Expected: PASS; halo/bubbles, frame, timer, menu, and focus regressions remain unchanged.

### Task 6: Full Offline Gate, Documentation, and Phase Review

**Files:**
- Modify: `README.md`
- Modify: `docs/PRIVACY.md`
- Modify: `docs/specs/00-constitution.md`
- Modify: `docs/architecture.md`
- Modify: `docs/specs/11-output-quality.md`
- Modify: `docs/specs/08-testing.md`
- Create: `docs/testing/context-aware-corrections.md`

**Interfaces:**
- Consumes: frozen implementation diff, corpus version, local ignored corpus audit/report from Task 3, native gate output, and task/spec IDs CK-1..CK-12/HR-1..HR-3.
- Produces: only the Step 03 documentation allowlist, a reviewable candidate, versioned pre-call evidence that distinguishes local fakes from the later remote observation, and an executable Phase 1 PASS gate that blocks Task 7 otherwise.

- [ ] **Step 1: Run the full native gate on the exact candidate**

```bash
set -euo pipefail
tested_product_sha=$(git rev-parse HEAD)
test "$(printf '%s' "$tested_product_sha" | wc -c | tr -d ' ')" -eq 40
git cat-file -e "$tested_product_sha^{commit}"
base_sha=$(git merge-base HEAD origin/main)
mkdir -p build/evidence/context-aware-corrections/offline
CONTEXTUAL_CORPUS_REPORT_PATH="$PWD/build/evidence/context-aware-corrections/offline/corpus-report.json" ~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git ls-tree -r "$tested_product_sha" -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj | shasum -a 256
shasum -a 256 build/Build/Products/Debug/Resenha.app/Contents/MacOS/Resenha
shasum -a 256 build/Build/Products/Debug/Resenha.app/Contents/Resources/contextual-corrections.json
shasum -a 256 build/evidence/context-aware-corrections/offline/corpus-report.json
echo "$base_sha"
echo "$tested_product_sha"
```

Expected: `** TEST SUCCEEDED **`, all existing and new tests pass, the product SHA predates only documentation changes, and its source-manifest/executable/resource/corpus hashes identify the binary actually tested. The run performs zero real network calls. Fix any failure in its owning Task 1-5 code, add/retain its regression test, and recapture every hash before rerunning this full command.

- [ ] **Step 2: Inspect the app resource and scan tracked content for secret-shaped material**

```bash
set -euo pipefail
test -f build/Build/Products/Debug/Resenha.app/Contents/Resources/contextual-corrections.json
shasum -a 256 build/Build/Products/Debug/Resenha.app/Contents/Resources/contextual-corrections.json
if rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' --hidden --glob '!build/**' --glob '!.git/**' .; then
  echo "Sanitization failed: tracked repository content" >&2
  exit 1
fi
history_findings=$(mktemp)
history_scan_input=$(mktemp)
trap 'rm -f "$history_findings" "$history_scan_input"' EXIT
while read -r reachable_oid reachable_path; do
  test "$(git cat-file -t "$reachable_oid")" = "blob" || continue
  git cat-file blob "$reachable_oid" > "$history_scan_input"
  if rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' "$history_scan_input"; then
    printf '%s:%s\n' "$reachable_oid" "${reachable_path:-<no-path>}" >> "$history_findings"
  fi
done < <(git rev-list --objects --all)
while IFS= read -r reachable_commit; do
  git log -1 --format=%B "$reachable_commit" > "$history_scan_input"
  if rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' "$history_scan_input"; then
    printf '%s:commit-message\n' "$reachable_commit" >> "$history_findings"
  fi
done < <(git rev-list --all)
while IFS=' ' read -r tag_oid tag_ref; do
  test "$(git cat-file -t "$tag_oid")" = "tag" || continue
  git for-each-ref --format='%(contents)' "$tag_ref" > "$history_scan_input"
  if rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' "$history_scan_input"; then
    printf '%s:tag-message\n' "$tag_oid" >> "$history_findings"
  fi
done < <(git for-each-ref --format='%(objectname) %(refname)' refs/tags)
if test -s "$history_findings"; then
  echo "Secret-shaped content found at reachable commit paths:" >&2
  sed -n '1,40p' "$history_findings" >&2
  exit 1
fi
rm -f "$history_findings" "$history_scan_input"
trap - EXIT
```

Expected: resource exists; the working tree, every blob reachable from current refs, commit messages, and annotated-tag messages contain no credential value. Findings disclose only `object-id:path`, `object-id:commit-message`, or `object-id:tag-message`, never matching content. Test strings may name the header but may not contain a secret-like bearer value.

- [ ] **Step 3: Update product/privacy/architecture docs with exact boundaries**

State all fixed limits, local record fields, deletion behavior, legacy conflict, beta default-off, personal transport disabled, synthetic-only one-shot, OpenRouter/TypeSafe recipients, metadata-retention uncertainty, ephemeral-client limitation, and absence of quality proof. Keep `O áudio nunca sai do Mac`; remove/qualify only claims that all text can never leave under the explicit synthetic diagnostic.

- [ ] **Step 4: Create the evidence report with concrete pre-call sections**

Use these headings, without secrets or raw bodies. Populate every provenance line from the named Step 1 command output before commit; an unresolved field fails the documentation check. The report records the tested product source, not the documentation commit that will contain the report; never predict or insert its future SHA. The final PR-head SHA is recorded later in the PR comment alongside these hashes:

```markdown
# Context-Aware Corrections Evidence

## Candidate
- Branch: `feat/context-aware-corrections`
- Base SHA: recorded 40-character output of `git merge-base HEAD origin/main`
- Tested product source SHA: recorded 40-character `tested_product_sha` captured before documentation edits
- Tested product source-manifest SHA-256: recorded digest of the Step 1 `git ls-tree` output
- Tested executable SHA-256: recorded digest of `Resenha.app/Contents/MacOS/Resenha`
- Corpus: `2026-10-20.1`, 100 synthetic cases
- App resource SHA-256: recorded 64-character digest from `shasum -a 256`

## Offline evidence
- Native gate: PASS/FAIL with date and command
- Requests observed in XCTest: 0 real; injected protocol only
- Frozen alpha contract: official source URLs, retrieval UTC timestamp, endpoint/model, exact request/answer/probability fields, and matching golden-test name
- Independent corpus audit: non-author reviewer identity, UTC timestamp, reviewed fixture SHA-256, local review-document SHA-256, 100/100 PASS, followed by the exact seven-column 100-row audit table copied from the verified local artifact
- Corpus report: `build/evidence/context-aware-corrections/offline/corpus-report.json` plus SHA-256
- Contextual vs keep-original vs global replacement: overall and per-family totals/correct/false positives/safety-evaluated/unauthorized mutations/harmful span changes/eligible positives/recall/abstentions
- Acceptance gate: evaluation-only coverage of every row, zero false positives, zero unauthorized mutations, zero harmful span changes, and recall >=0.80 over the frozen 20 IDs; calibration/diagnostic excluded
- Per pair: the same counts plus minimum/median selected-vs-runner-up margin
- Interpretation: contract and safety logic only; Jev PT-BR quality not measured

## Controlled diagnostic contract
- Endpoint: `POST https://openrouter.ai/api/alpha/decisions`
- Requested model: `typesafe/jev-1.14`
- Fixture: `pt-rosto-hostel-diagnostic-001`
- Dispatch: one call, zero retry, one-shot guard consumed before send
- Cost estimate: record current official input/output prices and calculated upper bound before dispatch
- Result: NOT RUN until Task 7 replaces this line pre-merge with the sanitized observed result/error, usage/cost when available, and local raw-evidence hash

## Physical evidence
- Status: NOT RUN until the exact pre-merge PR candidate is exercised in Task 7 Step 6

## Phase 1 review
- Status: NOT RUN until Task 6 Step 7
```

Replace each `recorded ...` instruction with the observed non-secret value before committing. Leave no `Final PR SHA` field in this versioned file because its containing commit does not yet exist.

- [ ] **Step 5: Run documentation consistency checks**

```bash
set -euo pipefail
published_docs=(
  README.md docs/PRIVACY.md docs/architecture.md docs/specs/00-constitution.md
  docs/specs/11-output-quality.md docs/specs/08-testing.md
  docs/testing/context-aware-corrections.md Sources/WhisperKey/PermissionOnboarding.swift
)
! rg -ni '100% local|\bTBD\b|\bFIXME\b|\bXXX\b|implement[[:space:]]+later|personal dictation.{0,120}(sent|send|transmit|route).{0,120}OpenRouter' "${published_docs[@]}"
rg -n '600' "${published_docs[@]}"
rg -n '900 ms' "${published_docs[@]}"
rg -n 'typesafe/jev-1\.14' "${published_docs[@]}"
git diff --check
```

Expected: the negative assertion finds no stale absolute text-local promise, unresolved marker, or claim that personal dictation is enabled; the three positive assertions independently find the valid phrase, deadline, and model limits in current documentation.

- [ ] **Step 6: Commit the Step 03 documentation allowlist**

```bash
set -euo pipefail
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
git add README.md docs/PRIVACY.md docs/specs/00-constitution.md docs/architecture.md docs/specs/11-output-quality.md docs/specs/08-testing.md docs/testing/context-aware-corrections.md
git commit -m "docs: document contextual correction boundaries"
git diff origin/main...HEAD --check
git status --short
```

Expected: the full native suite, including every new test, PASSes immediately before the documentation commit; only the Step 03 documentation allowlist is committed; and the tree is clean afterward. Phase 1 has not passed until Step 7 validates and versions its review result.

- [ ] **Step 7: Execute the single Phase 1 review gate and block Task 7 unless it passes**

Give the opus reviewer the current task/spec, analysis, four subtask files, `origin/main...HEAD`, exact tested-product SHA/hashes, versioned evidence report, local corpus audit/report hashes, full native gate result, and no-secret scan. Save the local review artifact at `build/evidence/context-aware-corrections/$tested_product_sha/phase1-review.md` with exactly one `result: PASS|NEEDS_CHANGES`, one numeric `score: N.N`, one integer `essential_ck_hr_failures: N`, then bounded findings/dispositions without secrets or personal text. A finding returns to its owner: Task 1–3/Step 01 for store/resolver/transport/corpus, Task 4–5/Step 02 for lifecycle/settings, or Task 6/Step 03 for documentation/evidence. Rerun affected owner tests, the full gate, refresh hashes/report, and rerun this same Phase 1 review; no additional phase/reviewer is created.

After the artifact says PASS, replace the Phase 1 `NOT RUN` line with exactly `Phase 1: PASS (N.N/5); essential CK/HR failures: 0`, then add the artifact SHA-256 and findings disposition to `docs/testing/context-aware-corrections.md` and execute:

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
phase1_review="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/phase1-review.md"
test -f "$phase1_review"
if LC_ALL=C rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|Reservei uma cama|"(answers|choices|messages|input|prompt|response)"[[:space:]]*:|raw[_ -]?(payload|response|body)|full[_ -]?response' "$phase1_review"; then
  echo "Sanitization failed: phase1-review.md" >&2
  exit 1
fi
test "$(sed -n 's/^result: //p' "$phase1_review")" = "PASS"
phase1_score=$(sed -n 's/^score: //p' "$phase1_review")
awk -v score="$phase1_score" 'BEGIN { exit !(score + 0 >= 4.0 && score + 0 <= 5.0) }'
test "$(sed -n 's/^essential_ck_hr_failures: //p' "$phase1_review")" = "0"
test "$(rg -c '^result:|^score:|^essential_ck_hr_failures:' "$phase1_review")" -eq 3
phase1_hash=$(shasum -a 256 "$phase1_review" | awk '{print $1}')
rg -n '^Phase 1: PASS \([4-5](\.[0-9]+)?/5\); essential CK/HR failures: 0$' docs/testing/context-aware-corrections.md
rg -n "Phase 1 artifact SHA-256: $phase1_hash" docs/testing/context-aware-corrections.md
test -f .specs/tasks/in-progress/add-context-aware-corrections.feature.md
git diff --check
git add docs/testing/context-aware-corrections.md
git commit -m "docs: record phase 1 review"
git status --short
```

Expected: Phase 1 is versioned as PASS with score `>= 4.0/5`, zero essential CK/HR failures, and an attributable local artifact hash. `NEEDS_CHANGES`, lower score, any essential failure, missing/malformed artifact, stale candidate/hash, or dirty tree blocks Task 7 explicitly; no call, installation, push, PR, or Phase 2 begins.

### Task 7: One Synthetic Call, Pre-Merge Physical Proof, Closure, and Operational Integration

**Files:**
- Modify before Phase 2: `docs/testing/context-aware-corrections.md` only, adding the sanitized controlled result, local artifact hashes, and physical proof required by the updated SPEC.
- Create before merge, local/untracked only: `build/evidence/context-aware-corrections/$tested_product_sha/remote.md`, using the variable resolved in Step 1.
- Create before merge and summarize into versioned evidence: `build/evidence/context-aware-corrections/$tested_product_sha/physical-premerge.md`.
- Create before merge, local/untracked only: `build/evidence/context-aware-corrections/$tested_product_sha/phase2-review.md` and `closure-comment.md`.
- Create after merge, local only: `build/evidence/context-aware-corrections/$merge_sha/integration.md` and sanitized `integration-comment.md`.
- Keep the task in `in-progress` through diagnostic, physical evidence, and opus Phase 2. Move it `in-progress -> done` only after Phase 2 scores `>= 4.0/5` with no essential CK/HR failure; include the review summary and rename in the final commit of the same PR.

Raw `.xcresult`, extracted test JSON, `remote.md`, `physical-premerge.md`, install logs, and integration artifacts remain under ignored `build/evidence/`. The versioned report contains only their SHA-256 hashes, exact commands, four-test/owner-suite counts, PASS/FAIL summaries, candidate provenance, and sanitized observations; never `git add` a raw artifact.

**Interfaces:**
- Consumes: Phase 1-approved exact candidate, green full native gate, bundled allowlisted fixture, disposable authorized key entered through app UI, and durable available guard.
- Produces: at most one sanitized remote observation, pre-merge physical proof and opus Phase 2 review tied to the tested candidate, then only after PASS the `done` transition, closure commit/push/latest-SHA checks/one PR/merge; integrated rebuild/install is a separate post-merge operational result.

Before Step 1, materialize one ignored Bash 3.2-compatible installer under `build/evidence/`; it is not a product/spec/subtask file and is never committed. Both pre-merge and post-merge installation must invoke this exact file with three positional arguments—absolute source `.app`, 40-character candidate SHA, absolute evidence directory—without copying or adapting its body:

```bash
set -euo pipefail
installer_path="$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sh"
mkdir -p "$(dirname "$installer_path")"
install -m 700 /dev/stdin "$installer_path" <<'INSTALLER'
#!/bin/bash
set -Eeuo pipefail
source_app=${1:?absolute source app required}
candidate_sha=${2:?candidate sha required}
evidence_dir=${3:?absolute evidence directory required}
case "$source_app" in /*/build/Build/Products/Debug/Resenha.app) ;; *) echo "Invalid source app path" >&2; exit 64 ;; esac
case "$candidate_sha" in *[!0-9a-f]*|'') echo "Invalid candidate SHA" >&2; exit 64 ;; esac
test "$(printf '%s' "$candidate_sha" | wc -c | tr -d ' ')" -eq 40
case "$evidence_dir" in /*/build/evidence/context-aware-corrections/"$candidate_sha") ;; *) echo "Invalid evidence path" >&2; exit 64 ;; esac
test -d "$source_app"
mkdir -p "$evidence_dir"
codesign --verify --deep --strict "$source_app"
source_executable_sha=$(shasum -a 256 "$source_app/Contents/MacOS/Resenha" | awk '{print $1}')
backup_root="$evidence_dir/install-backups/$(date +%Y%m%d-%H%M%S)-$candidate_sha"
stage_root=$(mktemp -d "$evidence_dir/install-stage.XXXXXX")
mkdir -p "$backup_root"
ditto "$source_app" "$stage_root/Resenha.app"
codesign --verify --deep --strict "$stage_root/Resenha.app"
test "$(shasum -a 256 "$stage_root/Resenha.app/Contents/MacOS/Resenha" | awk '{print $1}')" = "$source_executable_sha"
installed_app=/Applications/Resenha.app
installed_executable=/Applications/Resenha.app/Contents/MacOS/Resenha
test ! -L "$installed_app"
test -d "$installed_app"
case "$backup_root" in "$evidence_dir"/install-backups/*) ;; *) echo "Invalid backup path" >&2; exit 64 ;; esac
case "$stage_root" in "$evidence_dir"/install-stage.*) ;; *) echo "Invalid stage path" >&2; exit 64 ;; esac

exact_resenha_pids() {
  ps -axo pid=,command= | awk -v expected="$installed_executable" '{ line=$0; sub(/^[[:space:]]*/, "", line); pid=line; sub(/[[:space:]].*$/, "", pid); sub(/^[0-9]+[[:space:]]+/, "", line); if (line == expected) print pid }'
}
wait_for_exact_resenha_absence() {
  attempt=1
  while test "$attempt" -le 20; do
    test -z "$(exact_resenha_pids)" && return 0
    sleep 0.25
    attempt=$((attempt + 1))
  done
  test -z "$(exact_resenha_pids)"
}

initial_rows=$(exact_resenha_pids)
initial_count=$(printf '%s\n' "$initial_rows" | awk 'NF { count++ } END { print count+0 }')
test "$initial_count" -le 1
previous_pid=
if test "$initial_count" -eq 1; then
  previous_pid=$initial_rows
  test "$(ps -p "$previous_pid" -o command= | sed 's/^[[:space:]]*//')" = "$installed_executable"
  osascript -e 'tell application id "br.com.luisroquette.Resenha" to quit'
  if ! wait_for_exact_resenha_absence; then echo "Installed Resenha did not quit; no move performed" >&2; exit 74; fi
fi
ditto "$installed_app" "$backup_root/Resenha.app"
codesign --verify --deep --strict "$backup_root/Resenha.app"
previous_executable_sha=$(shasum -a 256 "$backup_root/Resenha.app/Contents/MacOS/Resenha" | awk '{print $1}')
install_succeeded=0
rollback_started=0
rollback_install() {
  original_exit=${1:-1}
  test "$install_succeeded" -eq 0 || exit 0
  test "$rollback_started" -eq 0 || exit 71
  rollback_started=1
  trap - ERR INT TERM
  set +e
  if ! test -d "$backup_root/original-moved.app"; then echo "Interrupted before original move; installed app untouched" >&2; exit "$original_exit"; fi
  failed_candidate_pid=
  osascript -e 'tell application id "br.com.luisroquette.Resenha" to quit'
  wait_for_exact_resenha_absence
  candidate_rows=$(exact_resenha_pids)
  candidate_count=$(printf '%s\n' "$candidate_rows" | awk 'NF { count++ } END { print count+0 }')
  if test "$candidate_count" -gt 0; then
    test "$candidate_count" -eq 1 || { echo "Candidate cardinality invalid; rollback not attempted" >&2; exit 73; }
    failed_candidate_pid=$candidate_rows
    test "$(ps -p "$failed_candidate_pid" -o command= | sed 's/^[[:space:]]*//')" = "$installed_executable" || exit 73
    kill -TERM "$failed_candidate_pid"
    if ! wait_for_exact_resenha_absence; then echo "Candidate survived TERM; original preserved" >&2; exit 72; fi
  fi
  test -d "$installed_app" && mv "$installed_app" "$backup_root/failed-candidate.app"
  mv "$backup_root/original-moved.app" "$installed_app"
  codesign --verify --deep --strict "$installed_app"
  restored_sha=$(shasum -a 256 "$installed_executable" | awk '{print $1}')
  test "$restored_sha" = "$previous_executable_sha" || exit 70
  open "$installed_app"
  rollback_pid=
  attempt=1
  while test "$attempt" -le 20; do
    restored_rows=$(exact_resenha_pids)
    restored_count=$(printf '%s\n' "$restored_rows" | awk 'NF { count++ } END { print count+0 }')
    if test "$restored_count" -eq 1; then rollback_pid=$restored_rows; break; fi
    test "$restored_count" -le 1 || break
    sleep 0.25
    attempt=$((attempt + 1))
  done
  test -n "$rollback_pid" || exit 70
  test -z "$previous_pid" || test "$rollback_pid" != "$previous_pid" || exit 70
  test -z "$failed_candidate_pid" || test "$rollback_pid" != "$failed_candidate_pid" || exit 70
  test "$(ps -p "$rollback_pid" -o command= | sed 's/^[[:space:]]*//')" = "$installed_executable" || exit 70
  echo "Install failed; prior app restored; inspect $backup_root" >&2
  exit "$original_exit"
}
trap 'rollback_install $?' ERR
trap 'rollback_install 130' INT
trap 'rollback_install 143' TERM
mv "$installed_app" "$backup_root/original-moved.app"
ditto "$stage_root/Resenha.app" "$installed_app"
codesign --verify --deep --strict "$installed_app"
test "$(shasum -a 256 "$installed_executable" | awk '{print $1}')" = "$source_executable_sha"
open "$installed_app"
running_pid=
attempt=1
while test "$attempt" -le 20; do
  candidate_rows=$(exact_resenha_pids)
  candidate_count=$(printf '%s\n' "$candidate_rows" | awk 'NF { count++ } END { print count+0 }')
  if test "$candidate_count" -eq 1; then running_pid=$candidate_rows; break; fi
  test "$candidate_count" -le 1
  sleep 0.25
  attempt=$((attempt + 1))
done
test -n "$running_pid"
test -z "$previous_pid" || test "$running_pid" != "$previous_pid"
test "$(ps -p "$running_pid" -o command= | sed 's/^[[:space:]]*//')" = "$installed_executable"
test "$(shasum -a 256 "$installed_executable" | awk '{print $1}')" = "$source_executable_sha"
mv "$backup_root/original-moved.app" "$backup_root/Resenha-before-install.app"
printf 'candidate_sha=%s\nsource_executable_sha=%s\nrunning_pid=%s\ninstalled_path=%s\nbackup_root=%s\n' "$candidate_sha" "$source_executable_sha" "$running_pid" "$installed_app" "$backup_root" > "$evidence_dir/install-result.txt"
install_succeeded=1
trap - ERR INT TERM
INSTALLER
bash -n "$installer_path"
installer_sha=$(shasum -a 256 "$installer_path" | awk '{print $1}')
printf '%s\n' "$installer_sha" > "$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sha256"
```

Expected: the ignored installer parses under macOS `/bin/bash` 3.2, has mode `0700`, and its saved SHA-256 identifies the exact implementation used twice. No tracked allowlist expands.

- [ ] **Step 1: Resolve tested-product provenance separately from the final PR head**

```bash
set -euo pipefail
git status --short
phase1_head_sha=$(git rev-parse HEAD)
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
git ls-tree -r "$tested_product_sha" -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj | shasum -a 256
codesign -dv --verbose=4 build/Build/Products/Debug/Resenha.app 2>&1 | sed -n '1,40p'
shasum -a 256 build/Build/Products/Debug/Resenha.app/Contents/MacOS/Resenha
shasum -a 256 build/Build/Products/Debug/Resenha.app/Contents/Resources/contextual-corrections.json
echo "$tested_product_sha"
echo "$phase1_head_sha"
```

Expected: clean tree; `tested_product_sha` and all hashes equal the versioned pre-call report; `phase1_head_sha` contains the versioned Phase 1 PASS and intentionally may differ from the tested product source SHA. Never relabel a documentation commit as the source that produced an older binary.

- [ ] **Step 2: Revalidate the executable Phase 1 gate and keep closure local**

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
phase1_review="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/phase1-review.md"
test "$(sed -n 's/^result: //p' "$phase1_review")" = "PASS"
phase1_score=$(sed -n 's/^score: //p' "$phase1_review")
awk -v score="$phase1_score" 'BEGIN { exit !(score + 0 >= 4.0 && score + 0 <= 5.0) }'
test "$(sed -n 's/^essential_ck_hr_failures: //p' "$phase1_review")" = "0"
phase1_hash=$(shasum -a 256 "$phase1_review" | awk '{print $1}')
rg -n "Phase 1 artifact SHA-256: $phase1_hash" docs/testing/context-aware-corrections.md
test -f .specs/tasks/in-progress/add-context-aware-corrections.feature.md
test ! -e .specs/tasks/done/add-context-aware-corrections.feature.md
test -z "$(git status --short)"
```

Expected: the exact Phase 1 review is PASS `>= 4.0/5`, has zero essential failures, matches the versioned report, and the task remains `in-progress`. No push, PR, remote comment, Phase 2 review, or installation has happened yet; any failed assertion returns to its owner and blocks the authorized call.

- [ ] **Step 3: Revalidate the live alpha contract against the frozen DTO and create local pre-dispatch evidence**

Use the same official OpenRouter sources to confirm endpoint schema, `typesafe/jev-1.14` availability, current prices, and relevant privacy/routing policy. Compare every current request/response field and answer path to Task 3's frozen `Codable` DTO and golden fixtures, then rerun the DTO encoder/decoder, delegate-cap, and client-second-defense tests through `mac-gate` before opening the diagnostic UI. Create `build/evidence/context-aware-corrections/$tested_product_sha/remote.md` and record source URLs, timestamp, exact sanitized payload shape, one-call upper-bound cost, DTO match result, `tested_product_sha`, `phase1_head_sha`, executable/resource/corpus-report hashes, and the observed pre-provision guard health with request count zero; never include credential/header/body. If contract/model differs, stop; return to Task 3, update DTOs and golden fixtures first, rerun the full native gate and Phase 1 review, and do not spend the authorization guessing.

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
mkdir -p "build/evidence/context-aware-corrections/$tested_product_sha"
schema_xcresult="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/schema-revalidation.xcresult"
schema_tests_json="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/schema-revalidation-tests.json"
test ! -e "$schema_xcresult"
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build -resultBundlePath "$schema_xcresult" test -only-testing:WhisperKeyTests/ContextualTransportCorpusTests/testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture -only-testing:WhisperKeyTests/ContextualTransportCorpusTests/testDiagnosticAndResolverShareSemanticValidatorWithoutSideChannel -only-testing:WhisperKeyTests/ContextualTransportCorpusTests/testURLSessionDelegateStateCancelsBeforeQueueingByte65537 -only-testing:WhisperKeyTests/ContextualTransportCorpusTests/testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB
xcrun xcresulttool get test-results tests --path "$schema_xcresult" --compact > "$schema_tests_json"
for test_name in \
  testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture \
  testDiagnosticAndResolverShareSemanticValidatorWithoutSideChannel \
  testURLSessionDelegateStateCancelsBeforeQueueingByte65537 \
  testDecisionsClientCancelsStreamingTaskBeforeBufferExceeds64KiB; do
  executed_count=$(jq --arg name "$test_name" '[.. | objects | .name? // empty | select(. == $name or . == ($name + "()"))] | length' "$schema_tests_json")
  test "$executed_count" -eq 1
done
```

Expected: the result bundle reports exactly four executed tests, each named above once and PASSing against the just-revalidated schema before any real dispatch. Both result artifacts remain local; only their hashes and sanitized four-test summary enter the tracked pre-merge evidence report.

- [ ] **Step 4: Execute the authorized diagnostic exactly once through the candidate UI**

Open the identified candidate only for the synthetic diagnostic, without microphone/personal dictation. In Settings, enable the local beta through its independent toggle, then separately confirm diagnostic consent and submit the disposable key; verify the UI reaches available without an additional beta mutation. Select `Executar diagnóstico sintético uma vez`; confirm the sole ID `pt-rosto-hostel-diagnostic-001`; execute once. The manual observation records only: sanitized result/error, reported call count `1`, retry count `0`, and guard `.consumed` after completion/restart. Append validated outcome category plus duration/effective model/token counts/reported USD cost to local `remote.md`. Do not infer credential/read-back/consume-before-dispatch ordering from UI timing; cite the automated XCTest/xresult for that claim. On authorization failure, timeout, error, unknown result, crash, or closed window, do not retry.

- [ ] **Step 5: Remove local credential, opt out, require provider revocation, and prepare sanitized closure evidence**

Use the app control `Remover chave do diagnóstico`, verify the reported Keychain deletion result, shared policy generation increment, pending cancellation, and consumed guard persistence; leave beta off and verify ordinary local dictation remains available without network. Local deletion does not revoke the provider credential. Pause here and ask the user to revoke this disposable key in the OpenRouter Keys dashboard, as promised. Accept only explicit user confirmation after that action; never infer provider revocation from Keychain deletion, guard consumption, request failure, or UI disappearance.

After confirmation, record in local `remote.md` exactly `provider_key_fingerprint_partial` using only the non-secret partial fingerprint/identifier displayed by OpenRouter, `revoked_at` as the confirmed ISO-8601 UTC time, `revocation_confirmed_by_user: true`, and `external_credential_status: revoked`. Never record the raw key, authorization value, or a reconstructable prefix. If confirmation is absent or ambiguous, record `external_credential_status: active_or_unverified`, keep the SDD task in `in-progress`, and stop before Step 6, Phase 2, merge, or installation; local cleanup alone cannot close the task.

Finish local `remote.md`, then prepare local `closure-comment.md` containing the revocation fields above, `phase1_head_sha`, `tested_product_sha`, source-manifest/executable/resource/corpus-report/remote-evidence hashes, result category, duration/model/usage/cost when available, and explicit limits. State that one observation proves only contract reachability, not PT-BR quality, threshold calibration, recurring cost, privacy beyond published policy, or production readiness. Do not post externally, push, open a PR, or commit the raw remote artifact before Phase 2 PASS.

Silently scan both local `remote.md` and `closure-comment.md` for credential/header shapes, the full synthetic sentence, and raw request/response fields before hashing either file. The scan must use quiet matching and report only the failing filename, never the matching content:

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
remote_evidence="build/evidence/context-aware-corrections/$tested_product_sha/remote.md"
closure_comment="build/evidence/context-aware-corrections/$tested_product_sha/closure-comment.md"
for sanitized_artifact in "$remote_evidence" "$closure_comment"; do
  test -f "$sanitized_artifact"
  if LC_ALL=C rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|Reservei uma cama|"(answers|choices|messages|input|prompt|response)"[[:space:]]*:|raw[_ -]?(payload|response|body)|full[_ -]?response' "$sanitized_artifact"; then
    echo "Sanitization failed: $sanitized_artifact" >&2
    exit 1
  fi
done
shasum -a 256 "$remote_evidence"
shasum -a 256 "$closure_comment"
rg -n '^provider_key_fingerprint_partial: [A-Za-z0-9._:-]{4,24}$|^revoked_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$|^revocation_confirmed_by_user: true$|^external_credential_status: revoked$' "build/evidence/context-aware-corrections/$tested_product_sha/remote.md"
test "$(rg -c '^provider_key_fingerprint_partial:|^revoked_at:|^revocation_confirmed_by_user:|^external_credential_status:' "build/evidence/context-aware-corrections/$tested_product_sha/remote.md")" -eq 4
test -z "$(git status --short --untracked-files=no -- ':!docs/testing/context-aware-corrections.md')"
```

Expected: local sanitized closure evidence records explicit provider revocation confirmation with only a non-secret partial fingerprint and contains no secret/raw body. Missing confirmation leaves the external credential active/unverified and blocks physical closure/Phase 2; no PR/comment exists yet.

- [ ] **Step 6: Run the bounded physical script on the exact pre-merge candidate and freeze the Phase 2 package**

After the diagnostic and final green gates, invoke the exact ignored installer materialized before Step 1; do not copy, edit, or adapt its body. The pre-merge source is the current clean candidate at `tested_product_sha`, not a merge worktree:

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
installer_path="$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sh"
installer_hash_file="$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sha256"
test -x "$installer_path"
test -f "$installer_hash_file"
actual_installer_sha=$(shasum -a 256 "$installer_path" | awk '{print $1}')
test "$(sed -n '1p' "$installer_hash_file")" = "$actual_installer_sha"
source_app="$PWD/build/Build/Products/Debug/Resenha.app"
evidence_dir="$PWD/build/evidence/context-aware-corrections/$tested_product_sha"
bash "$installer_path" "$source_app" "$tested_product_sha" "$evidence_dir"
test "$(sed -n 's/^candidate_sha=//p' "$evidence_dir/install-result.txt")" = "$tested_product_sha"
test "$(sed -n 's/^installed_path=//p' "$evidence_dir/install-result.txt")" = "/Applications/Resenha.app"
printf 'installer_sha256=%s\n' "$actual_installer_sha" >> "$evidence_dir/install-result.txt"
```

Preserve the displaced installation/failed candidate and capture the full local install result under `build/evidence/context-aware-corrections/$tested_product_sha/`. Using disposable TextEdit/browser fields and no real personal remote path, observe common `rosto` unchanged; feedback Save/list/delete; local-beta opt-out/re-enable; diagnostic consumed status; next dictation; keyboard/VoiceOver labels/errors; focus/clipboard/history; halo/bubbles; and offline continuity. Record PASS/FAIL/NOT RUN with candidate SHA, installer SHA, installed path, signature, executable/resource hashes, PID, shortcut and backup location. Contextual lodging replacement, stale remote-result rejection, exact fan-out, and credential/read-back/consume ordering are `AUTOMATED` and cite the owner-suite `.xcresult` path/hash; never expose a fake provider in release.

Write `physical-premerge.md`; update the tracked report's Controlled diagnostic and Physical sections with sanitized result/error, usage/cost when available, local artifact hashes, candidate/source/config/resource hashes, signature, process/path, and every physical PASS/FAIL/NOT RUN. Add exactly one installer-hash line using the actual ignored script hash; the executable regex below fixes its format as the literal prefix `- Installer SHA-256: ` followed by one 64-lowercase-hex value inside Markdown code ticks. This tracked line becomes the sole cross-merge authority. Verify Step 5 recorded `external_credential_status: revoked`. Keep these Task 7 report edits uncommitted and keep the task at `.specs/tasks/in-progress/add-context-aware-corrections.feature.md`; Phase 2 has not passed yet. After every versionable DoD row and user-only provider-revocation checkpoint is satisfied, run the full gate and freeze the local Phase 2 package without push/PR/checks:

```bash
set -euo pipefail
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
remote_evidence="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/remote.md"
installer_path="$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sh"
actual_installer_sha=$(shasum -a 256 "$installer_path" | awk '{print $1}')
test "$(rg -c '^- Installer SHA-256: `[0-9a-f]{64}`$' docs/testing/context-aware-corrections.md)" -eq 1
report_installer_sha=$(sed -n 's/^- Installer SHA-256: `\([0-9a-f]\{64\}\)`$/\1/p' docs/testing/context-aware-corrections.md)
test "$report_installer_sha" = "$actual_installer_sha"
test "$(sed -n 's/^external_credential_status: //p' "$remote_evidence")" = "revoked"
test "$(sed -n 's/^revocation_confirmed_by_user: //p' "$remote_evidence")" = "true"
owner_xcresult="$PWD/build/evidence/context-aware-corrections/$tested_product_sha/ContextualTransportCorpusTests.xcresult"
test ! -e "$owner_xcresult"
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build -resultBundlePath "$owner_xcresult" test -only-testing:WhisperKeyTests/ContextualTransportCorpusTests
ditto -c -k --sequesterRsrc --keepParent "$owner_xcresult" "$owner_xcresult.zip"
shasum -a 256 "$owner_xcresult.zip"
test -f .specs/tasks/in-progress/add-context-aware-corrections.feature.md
test ! -e .specs/tasks/done/add-context-aware-corrections.feature.md
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
test "$(git diff --name-only)" = "docs/testing/context-aware-corrections.md"
git diff --check
git diff -- docs/testing/context-aware-corrections.md > "build/evidence/context-aware-corrections/$tested_product_sha/phase2-versioned-evidence.patch"
phase2_patch="build/evidence/context-aware-corrections/$tested_product_sha/phase2-versioned-evidence.patch"
sanitized_artifacts=(
  "$remote_evidence"
  "build/evidence/context-aware-corrections/$tested_product_sha/closure-comment.md"
  "build/evidence/context-aware-corrections/$tested_product_sha/physical-premerge.md"
  "$phase2_patch"
  "docs/testing/context-aware-corrections.md"
)
for sanitized_artifact in "${sanitized_artifacts[@]}"; do
  test -f "$sanitized_artifact"
  if LC_ALL=C rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|Reservei uma cama|"(answers|choices|messages|input|prompt|response)"[[:space:]]*:|raw[_ -]?(payload|response|body)|full[_ -]?response' "$sanitized_artifact"; then
    echo "Sanitization failed: $sanitized_artifact" >&2
    exit 1
  fi
done
for sanitized_artifact in "${sanitized_artifacts[@]}"; do
  shasum -a 256 "$sanitized_artifact"
done
```

Expected: the exact pre-merge candidate has physical proof and a green full gate; `remote.md`, `closure-comment.md`, `physical-premerge.md`, the versioned-evidence patch, and the tracked report are scanned silently before their hashes and before Phase 2 review, with no `build/` exclusion; the tracked evidence diff is limited to the one Step 04-allowlisted report and contains no secret/raw body; provider revocation is explicitly confirmed; task remains `in-progress`; and nothing is committed, pushed, commented, or merged. Any missing DoD row, physical proof, revocation, or sanitization failure keeps the task in `in-progress` and blocks Phase 2.

- [ ] **Step 7: Run the opus Phase 2 review after final evidence and before merge**

Give the opus reviewer exactly: task/spec, analysis, all four subtask docs, committed `origin/main...HEAD` diff plus the uncommitted allowlisted evidence diff, Phase 1 review, tracked pre-call report, local `remote.md`, local sanitized `closure-comment.md`, full native gate result, guard file/permission/read-back evidence, provider-revocation confirmation, pre-merge physical proof, tested-product provenance hashes, the actual installer hash, and the unique matching installer-hash line in the tracked report. Review at minimum: one-call atomicity, delegate/client byte caps, DTO match, policy invalidation, no personal payload, result interpretation, local credential removal, external provider-key revocation, physical proof, installer-anchor equality, and provenance. Phase 2 passes only with score `>= 4.0/5`, `external_credential_status: revoked`, and no essential CK/HR failure. Save the review locally at `build/evidence/context-aware-corrections/$tested_product_sha/phase2-review.md` with exactly one `result: PASS|NEEDS_CHANGES`, one numeric `score: N.N`, one integer `essential_ck_hr_failures: N`, and—after the whole-branch review below—one `whole_branch_review: PASS|NEEDS_CHANGES`, then bounded findings/dispositions without payload or secret; only these four exact fields drive the closure gate.

Any finding loops to its owning SDD agent and step: transport/DTO/guard to Step 01/Task 3, lifecycle/policy to Step 02/Task 4, settings/credential UX to Step 02/Task 5, documentation/provenance to Step 03/Task 6, and remote observation wording to Step 04/Task 7 Step 5. Product/fixture/DTO/guard changes require a regression test, full native gate, the single Phase 1 review refreshed for the changed candidate, refreshed physical/evidence attribution, and another Phase 2 review. The guard remains consumed and the call is never repeated; if a product change makes the single observation no longer attributable to the merge candidate, mark remote proof pending and stop before merge unless the user separately authorizes another call. Documentation-only fixes remain local, refresh the review package, and do not relabel the unchanged tested-product SHA. Internal commits and repeated review loops remain with those four existing SDD agents; they do not create another phase or owner.

While the task is still `in-progress`, perform the one whole-branch review over the committed `origin/main...HEAD` diff plus the uncommitted allowlisted evidence diff. Inspect privacy boundaries, generated project/resource membership, test and corpus evidence, provenance, closure-comment sanitization, and every changed path. A finding returns to the owning SDD step, reruns its tests/full gate and Phase 1 when the tested product changed, refreshes physical/evidence attribution, and reruns Phase 2 plus this whole-branch review. Record the whole-branch PASS and disposition in the Phase 2 artifact; no review may be deferred until after `done`.

Only after Phase 2 and the whole-branch review both pass while the task is `in-progress`, the Phase 2 score is `>= 4.0/5`, external credential status is `revoked`, and no essential CK/HR failure remains, append the sanitized Phase 2 score/findings disposition to the versioned report, move the task to `done`, commit, push, and check the exact latest SHA:

```bash
set -Eeuo pipefail
closure_commit_created=0
reopen_after_closure_failure() {
  failure_code=$?
  trap - ERR
  if test -f .specs/tasks/done/add-context-aware-corrections.feature.md && test ! -e .specs/tasks/in-progress/add-context-aware-corrections.feature.md; then
    git mv .specs/tasks/done/add-context-aware-corrections.feature.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md
    if test "$closure_commit_created" -eq 1; then
      git add -A -- .specs/tasks/done/add-context-aware-corrections.feature.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md
      if ! git diff --cached --quiet; then
        git commit -m "chore: reopen contextual corrections after closure gate failure"
      fi
      if ! git push -u origin feat/context-aware-corrections >/dev/null 2>&1; then
        echo "Closure failed; task reopened locally but reopen push also failed" >&2
      fi
    fi
  fi
  exit "$failure_code"
}
trap reopen_after_closure_failure ERR
tested_product_sha=$(git log -1 --format=%H -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj)
test "$tested_product_sha" = "$(sed -n 's/^- Tested product source SHA: `\([0-9a-f]\{40\}\)`$/\1/p' docs/testing/context-aware-corrections.md)"
phase2_review="build/evidence/context-aware-corrections/$tested_product_sha/phase2-review.md"
installer_path="$PWD/build/evidence/context-aware-corrections/install-candidate-safely.sh"
actual_installer_sha=$(shasum -a 256 "$installer_path" | awk '{print $1}')
test "$(rg -c '^- Installer SHA-256: `[0-9a-f]{64}`$' docs/testing/context-aware-corrections.md)" -eq 1
report_installer_sha=$(sed -n 's/^- Installer SHA-256: `\([0-9a-f]\{64\}\)`$/\1/p' docs/testing/context-aware-corrections.md)
test "$report_installer_sha" = "$actual_installer_sha"
phase2_artifacts=(
  "build/evidence/context-aware-corrections/$tested_product_sha/remote.md"
  "build/evidence/context-aware-corrections/$tested_product_sha/closure-comment.md"
  "build/evidence/context-aware-corrections/$tested_product_sha/physical-premerge.md"
  "build/evidence/context-aware-corrections/$tested_product_sha/phase2-versioned-evidence.patch"
  "docs/testing/context-aware-corrections.md"
  "$phase2_review"
)
for sanitized_artifact in "${phase2_artifacts[@]}"; do
  test -f "$sanitized_artifact"
  if LC_ALL=C rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|Reservei uma cama|"(answers|choices|messages|input|prompt|response)"[[:space:]]*:|raw[_ -]?(payload|response|body)|full[_ -]?response' "$sanitized_artifact"; then
    echo "Sanitization failed: $sanitized_artifact" >&2
    exit 1
  fi
done
test "$(sed -n 's/^result: //p' "$phase2_review")" = "PASS"
phase2_score=$(sed -n 's/^score: //p' "$phase2_review")
awk -v score="$phase2_score" 'BEGIN { exit !(score + 0 >= 4.0 && score + 0 <= 5.0) }'
test "$(sed -n 's/^essential_ck_hr_failures: //p' "$phase2_review")" = "0"
test "$(rg -c '^result:|^score:|^essential_ck_hr_failures:' "$phase2_review")" -eq 3
rg -n '^whole_branch_review: PASS$' "$phase2_review"
phase2_hash=$(shasum -a 256 "$phase2_review" | awk '{print $1}')
rg -n '^Phase 2: PASS \([4-5](\.[0-9]+)?/5\)$' docs/testing/context-aware-corrections.md
rg -n "Phase 2 artifact SHA-256: $phase2_hash" docs/testing/context-aware-corrections.md
test "$(git diff --name-only)" = "docs/testing/context-aware-corrections.md"
test -f .specs/tasks/in-progress/add-context-aware-corrections.feature.md
test ! -e .specs/tasks/done/add-context-aware-corrections.feature.md
git diff origin/main...HEAD --check
git diff --check
if rg -q 'sk-or-v1-[A-Za-z0-9_-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' --hidden --glob '!build/**' --glob '!.git/**' .; then
  echo "Sanitization failed: tracked repository content before closure" >&2
  exit 1
fi
source_manifest_before=$(git ls-tree -r "$tested_product_sha" -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj | shasum -a 256 | awk '{print $1}')
git mv .specs/tasks/in-progress/add-context-aware-corrections.feature.md .specs/tasks/done/add-context-aware-corrections.feature.md
git add -A -- docs/testing/context-aware-corrections.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md .specs/tasks/done/add-context-aware-corrections.feature.md
git commit -m "docs: close contextual corrections evidence"
closure_commit_created=1
final_pr_sha=$(git rev-parse HEAD)
source_manifest_final=$(git ls-tree -r "$final_pr_sha" -- Sources/WhisperKey Tests/Fixtures project.yml WhisperKey.xcodeproj/project.pbxproj | shasum -a 256 | awk '{print $1}')
test "$source_manifest_final" = "$source_manifest_before"
git push -u origin feat/context-aware-corrections
pr_number=$(gh pr list --head feat/context-aware-corrections --base main --state open --json number --jq '.[0].number // empty')
if test -z "$pr_number"; then
  gh pr create --base main --head feat/context-aware-corrections --title "feat: add context-aware transcription corrections" --body-file <(printf '%s\n' 'Implements the approved contextual-corrections SDD spec. Personal dictation remains local; remote evidence is limited to one synthetic diagnostic.')
  pr_number=$(gh pr view feat/context-aware-corrections --json number --jq .number)
fi
test -n "$pr_number"
pr_url=$(gh pr view "$pr_number" --json url --jq .url)
printf '%s\n%s\n' "$pr_number" "$pr_url" > build/evidence/context-aware-corrections/pr-identity.txt
test "$(gh pr view "$pr_number" --json headRefOid --jq .headRefOid)" = "$final_pr_sha"
gh pr checks "$pr_number" --watch
gh pr comment "$pr_number" --body-file "build/evidence/context-aware-corrections/$tested_product_sha/closure-comment.md"
test -f .specs/tasks/done/add-context-aware-corrections.feature.md
test ! -e .specs/tasks/in-progress/add-context-aware-corrections.feature.md
trap - ERR
```

Any finding returns to its owner while the task remains `in-progress`; after fixes, rerun the owner suite/full gate, refresh evidence, Phase 2, and the whole-branch review. Never move to `done`, commit closure, or merge on `NEEDS_CHANGES`, score below `4.0`, an essential CK/HR failure, or a whole-branch review failure.

The closure fence's `ERR` trap is armed before validation and is idempotent: a failure before `done` exits without moving state; a failure in closure commit, push, PR create/update, head equality, checks, or comment moves `done -> in-progress` when needed. If the closure commit already exists, it records and attempts to push a reopening commit on the same branch/PR. The trap disables itself before recovery, prints no command output that could contain a secret, and reports when the reopen push also fails; merge remains blocked either way.

- [ ] **Step 8: Merge the exact reviewed latest SHA and begin operational verification**

This step performs no new product or whole-branch review: both occurred while `in-progress` in Step 7. Recalculate the PR identity, require the remote head and every required check to match the closure commit, then merge exactly that SHA:

```bash
set -euo pipefail
pr_number=$(gh pr view feat/context-aware-corrections --json number --jq .number)
test -n "$pr_number"
final_pr_sha=$(git rev-parse HEAD)
test "$(gh pr view "$pr_number" --json headRefOid --jq .headRefOid)" = "$final_pr_sha"
gh pr checks "$pr_number" --watch
gh pr merge "$pr_number" --squash --match-head-commit "$final_pr_sha"
merge_sha=$(gh pr view "$pr_number" --json mergeCommit --jq .mergeCommit.oid)
git fetch origin main
test "$(git rev-parse origin/main)" = "$merge_sha"
git merge-base --is-ancestor "$merge_sha" origin/main
workflow_review="build/evidence/context-aware-corrections/$merge_sha/main-workflow-applicability.tsv"
workflow_runs="build/evidence/context-aware-corrections/$merge_sha/main-workflow-runs.tsv"
mkdir -p "$(dirname "$workflow_review")"
printf 'file\tname\tevent\tclassification\treason\n' > "$workflow_review"
printf 'file\tname\tevent\tmerge_sha\trun_id\tstatus\tconclusion\turl\n' > "$workflow_runs"
git diff-tree --no-commit-id --name-only -r "$merge_sha^" "$merge_sha" > "${workflow_review%.tsv}-changed-paths.txt"
workflow_files_list="$workflow_review.files"
git ls-tree -r --name-only "$merge_sha" .github/workflows > "$workflow_files_list"
while IFS= read -r workflow_file; do
  test -n "$workflow_file" || continue
  echo "===== $workflow_file ====="
  git show "$merge_sha:$workflow_file" | sed -n '1,120p'
  gh workflow view "$workflow_file" --json name,path,state
done < "$workflow_files_list"
# After reading each printed `on`, branch, paths, and paths-ignore rule against the changed-path list,
# append one tab-separated row per file with its exact GitHub workflow name, the merge-triggered event,
# classification exactly `applicable` or `not-applicable`, and a concrete trigger/path reason.
# A workflow that only has `workflow_dispatch` is not applicable unless this task explicitly dispatched it.
test "$(($(wc -l < "$workflow_review") - 1))" -eq "$(sed '/^$/d' "$workflow_files_list" | wc -l | tr -d ' ')"
while IFS=$'\t' read -r workflow_file workflow_name expected_event classification reason; do
  test "$classification" = "applicable" || continue
  run_json="[]"
  for poll in {1..60}; do
    run_json=$(gh run list --workflow "$workflow_file" --branch main --commit "$merge_sha" --event "$expected_event" --json databaseId,workflowName,event,headSha,status,conclusion,url --limit 20)
    run_id=$(jq -r --arg sha "$merge_sha" --arg name "$workflow_name" --arg event "$expected_event" '[.[] | select(.headSha == $sha and .workflowName == $name and .event == $event)] | sort_by(.databaseId) | last | .databaseId // empty' <<<"$run_json")
    test -n "$run_id" && break
    sleep 5
  done
  test -n "$run_id"
  gh run watch "$run_id" --exit-status
  run_final=$(gh run view "$run_id" --json databaseId,workflowName,event,headSha,status,conclusion,url)
  test "$(jq -r .headSha <<<"$run_final")" = "$merge_sha"
  test "$(jq -r .workflowName <<<"$run_final")" = "$workflow_name"
  test "$(jq -r .event <<<"$run_final")" = "$expected_event"
  test "$(jq -r .status <<<"$run_final")" = "completed"
  test "$(jq -r .conclusion <<<"$run_final")" = "success"
  jq -r --arg file "$workflow_file" '[
      $file, .workflowName, .event, .headSha, (.databaseId|tostring), .status, .conclusion, .url
    ] | @tsv' <<<"$run_final" >> "$workflow_runs"
done < <(tail -n +2 "$workflow_review")
expected_applicable=$(awk -F '\t' 'NR > 1 && $4 == "applicable" { count++ } END { print count+0 }' "$workflow_review")
mapped_success=$(($(wc -l < "$workflow_runs") - 1))
test "$mapped_success" -eq "$expected_applicable"
```

Expected: GitHub's merge SHA equals `origin/main`; the local applicability table covers every workflow file/name at that SHA and evaluates its exact event/branch/path filters against the merge diff. Each applicable row maps to a specific run whose workflow name, event, `headSha == merge_sha`, ID, URL, terminal status, and `success` conclusion are recorded. Counts alone, a different workflow, another SHA, or an unrelated `workflow_dispatch` run never satisfies a row. Zero mapped runs is accepted only when the table proves zero applicable workflows. Do not delete the branch while any task/install worktree exists; cleanup is outside this plan.

If push, PR creation/update, remote-head equality, or latest-SHA checks fail after the closure commit moved the task to `done`, do not review or merge in that state. Immediately reopen the same task and PR with a new commit:

```bash
set -euo pipefail
test -f .specs/tasks/done/add-context-aware-corrections.feature.md
git mv .specs/tasks/done/add-context-aware-corrections.feature.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md
git add -A -- .specs/tasks/done/add-context-aware-corrections.feature.md .specs/tasks/in-progress/add-context-aware-corrections.feature.md
git commit -m "chore: reopen contextual corrections after closure gate failure"
git push -u origin feat/context-aware-corrections
```

Fix the exact failure in its owning step, rerun the affected owner tests and full gate, refresh provenance/evidence and Phase 1 when the tested product changed, then rerun physical proof as affected, Phase 2, and the whole-branch review while `in-progress`. Only a fresh PASS permits another `in-progress -> done` closure commit, push, and latest-SHA checks. Reuse the same branch/PR and never repeat the consumed synthetic diagnostic without separate authorization.

- [ ] **Step 9: Rebuild, back up, and install only the exact integrated candidate**

From the task worktree, resolve the merge SHA and create a detached clean worktree. Run the native gate/build only through `mac-gate`, then stage and verify the exact bundle:

```bash
set -euo pipefail
task_worktree="$PWD"
installer_path="$task_worktree/build/evidence/context-aware-corrections/install-candidate-safely.sh"
test -x "$installer_path"
git fetch origin main
pr_identity_file="$task_worktree/build/evidence/context-aware-corrections/pr-identity.txt"
test -f "$pr_identity_file"
pr_number=$(sed -n '1p' "$pr_identity_file")
test -n "$pr_number"
merge_sha=$(gh pr view "$pr_number" --json mergeCommit --jq .mergeCommit.oid)
git merge-base --is-ancestor "$merge_sha" origin/main
merged_report=$(git show "$merge_sha:docs/testing/context-aware-corrections.md")
test "$(printf '%s\n' "$merged_report" | rg -c '^- Installer SHA-256: `[0-9a-f]{64}`$')" -eq 1
expected_installer_sha=$(printf '%s\n' "$merged_report" | sed -n 's/^- Installer SHA-256: `\([0-9a-f]\{64\}\)`$/\1/p')
test "$(printf '%s' "$expected_installer_sha" | wc -c | tr -d ' ')" -eq 64
test "$(shasum -a 256 "$installer_path" | awk '{print $1}')" = "$expected_installer_sha"
install_worktree="../resenha-context-install-$merge_sha"
git worktree add --detach "$install_worktree" "$merge_sha"
cd "$install_worktree"
test "$(git rev-parse HEAD)" = "$merge_sha"
test -z "$(git status --short)"
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
source_app="$PWD/build/Build/Products/Debug/Resenha.app"
evidence_dir="$PWD/build/evidence/context-aware-corrections/$merge_sha"
bash "$installer_path" "$source_app" "$merge_sha" "$evidence_dir"
test "$(sed -n 's/^candidate_sha=//p' "$evidence_dir/install-result.txt")" = "$merge_sha"
test "$(sed -n 's/^installed_path=//p' "$evidence_dir/install-result.txt")" = "/Applications/Resenha.app"
printf 'installer_sha256=%s\n' "$expected_installer_sha" >> "$evidence_dir/install-result.txt"
```

Expected: the post-merge call extracts exactly one well-formed installer hash from `docs/testing/context-aware-corrections.md` at `merge_sha`, compares the local script to that versioned authority, and never treats the local `.sha256` file as sufficient. It then uses the same reviewed installer as pre-merge, with only the three explicit arguments changed. Its validated paths, PID cardinality, traps, hashes, and rollback invariants remain identical. Never delete either backup or failed candidate automatically.

- [ ] **Step 10: Verify integrated rebuild/install attribution without changing DoD**

Post-merge work verifies integration only: record merge SHA, main-run URLs, rebuilt/installed hashes, signature, backup location, running path/PID, and whether they match the versioned pre-merge evidence. Do not rerun or reinterpret product acceptance, do not change the already-closed DoD, and do not create a commit/PR. Create local `integration.md` and sanitized `integration-comment.md`, then use the PR identity captured before merge:

```bash
set -euo pipefail
pr_identity_file="../resenha-context-aware-corrections/build/evidence/context-aware-corrections/pr-identity.txt"
test -f "$pr_identity_file"
pr_number=$(sed -n '1p' "$pr_identity_file")
pr_url=$(sed -n '2p' "$pr_identity_file")
test -n "$pr_number"
test -n "$pr_url"
merge_sha=$(gh pr view "$pr_number" --json mergeCommit --jq .mergeCommit.oid)
gh pr comment "$pr_number" --body-file "build/evidence/context-aware-corrections/$merge_sha/integration-comment.md"
git status --short
```

Expected: versioned history shows `todo -> in-progress -> done` in the single PR; installed hash matches the exact merge rebuild; same PR has sanitized integration evidence; `git status --short` has no tracked change. A post-merge mismatch is an integration incident to report/repair, not permission to rewrite the pre-merge acceptance record.

---

## Plan Self-Review Record

- Spec coverage: Tasks 1/5 cover CK-1/2/9/11; Tasks 2/4 cover CK-3/4/5/6; Tasks 3/5/7 cover CK-7/8 and HR-1/2; Tasks 3/6/7 cover CK-10/12 and HR-3.
- Unresolved-marker scan: execution instructions contain none of the forbidden incomplete-work phrases; future evidence fields name the exact commands whose recorded outputs must be written before commit.
- Type consistency: `ContextualCorrectionExample`, resolver/store fixture generation, `ContextualCorrectionStore`, typed `ContextualCorrectionStoreHealth`/`ContextualCorrectionStoreSnapshot`, `ContextualCorrectionPolicy`, `ContextualPolicyToken`, `ContextualPolicyTokenSource`, `ContextualStoreGenerationSource`, `ContextualInstant`, class-bound `ContextualMonotonicTime`, `ContextualTimeComposition`, `ContextualResolving`, `ContextualResolutionRequest`, real `ContextualCorrectionResolver`, `ContextualDecisionProvider`, `SyntheticDiagnosticDecisionProvider`, immutable `ContextualDecisionReceipt`, shared `ContextualDecisionValidator`, `ValidatedContextualOutcome`, `ContextualResolutionResult`, `DecisionsResponseStream`, `DecisionsDelegateState`, `DecisionsStreamingTransport`, `SyntheticDiagnosticGuardStore`, `SyntheticDiagnosticFixture.id`, `SyntheticDiagnosticController.run() async throws -> SyntheticDiagnosticResult`, sanitized `SyntheticDiagnosticError`, non-class-bound `DictationOutputSink`, `ContextRetentionProbe`, `finishTranscription`, frozen DTOs, authorization interfaces/owner, guard, corpus safety metrics, and `DictationCompletion` are introduced once and consumed under the same names.
- Buildability scan: all 19 Swift fences pass `swiftc -frontend -parse`; every bodyless declaration is a protocol requirement, while concrete methods/initializers shown in fences have bodies; every awaited actor/async value is captured before an XCTest assertion autoclosure; every concrete `ContextualCorrectionResolver` initializer receives `time:`; and the coordinator acceptance test injects one `ManualContextualTime` through `ContextualTimeComposition` into resolver, diagnostic controller, and transport.
- Governance/closure scan against the updated SPEC: Tasks 1–3 map only to SDD Step 01, Tasks 4–5 to Step 02, Task 6 to Step 03, and Task 7 to Step 04; internal commits create no owners/phases; Phase 1 has an executable local artifact/versioned PASS gate; no push/PR precedes Phase 2; all Phase 2/final/whole-branch review occurs while `in-progress`; and the normative order is pre-merge physical proof -> Phase 2 plus whole-branch `PASS >= 4.0/5` with zero essential failures -> `done`/closure commit/push/latest-SHA checks -> merge -> operational-only integrated rebuild/install. A closure push/head/check failure forces `done -> in-progress`, owning-step repair, gates/reviews, and a new closure commit before merge.
- Shell-safety scan: all 36 Bash fences parse with macOS `/bin/bash` 3.2.57; no post-3.2 built-in, expansion, or shell-specific split syntax remains; every multi-command fence starts with `set -euo pipefail`, or `set -Eeuo pipefail` when it owns a trap; every fenced block that references `tested_product_sha` or `pr_number` recalculates and validates that value in the same block; no block relies on shell state from a prior fence; expected nonzero searches are handled explicitly; and the closure trap idempotently restores `in-progress` on closure push/PR/head/check/comment failure.
- Evidence-sanitization scan: the secret-shaped regex requires either `sk-or-v1-` plus at least 20 token characters or an `Authorization: Bearer` value with at least 20 token characters, so documentation literals such as `sk-or-v1-<key>` remain allowed; raw field/full-sentence checks stay separate. `remote.md`, `closure-comment.md`, `physical-premerge.md`, the versioned-evidence patch/report, and Phase 1/Phase 2 review artifacts are scanned with quiet matching and no `build/` exclusion before hashing or downstream review; every blob reachable from current refs plus commit and annotated-tag messages is scanned silently and reports only object ID plus path/message kind; partial fingerprints, cost, model, and status metadata remain allowed.
- Installer single-source scan: one ignored `install-candidate-safely.sh` is generated from the exact plan, parsed under Bash 3.2, mode/hash checked, and invoked unchanged with `(source_app, candidate_sha, evidence_dir)` for both pre-merge `tested_product_sha` and post-merge `merge_sha`. Before Phase 2, the tracked report contains exactly one installer-hash anchor equal to the local script and the reviewer verifies it; the final closure commit versions that anchor. Post-merge obtains the sole authoritative expected hash with `git show "$merge_sha:docs/testing/context-aware-corrections.md"`, validates one exact-format match, and compares the script to it; the local `.sha256` file is never sufficient authority.
- File-ownership scan: Task 3/Step 01 stages only `Sources`, `Tests`, fixture, `project.yml`, and generated Xcode project files while corpus review/metrics remain ignored local artifacts; Task 6/Step 03 exclusively creates/updates the seven documentation files allowed by subtask 03, including the single `docs/testing/context-aware-corrections.md`; Task 7/Step 04 changes only that report plus orchestrator-owned task state before merge.
- Review Focus coverage: unique semantic fixtures/capacity rows, the 600-character occurrence, hermetic glossary separation, target-specific project/PBX membership plus compile proof, `@MainActor` store tests/helpers, typed unhealthy snapshots, and verified reload recovery are in Task 1; unhealthy-store pre-match/provider rejection and lifecycle recovery, common-word negative, global multi-pair range order/IDs/provider reachability, current store generation, one shared clock origin plus deliberate distinct-origin rejection, deterministic 899/900/901-ms deadline/noncooperative provider, mixed spans, the sole disabled/personal owner test, and mutation-during-suspension are in Tasks 2/4; learning/evaluation gates, exact-output/span authorization across every evaluation case, zero unauthorized/harmful mutations, deliberate two-span gate failure, normalized semantic uniqueness, closed labels, local independent 100-row/hash audit, and the sole diagnostic ID are in Task 3, with the verified audit copied into the Task 6 allowlisted report; byte caps, shared validation, typed receipt, atomic guard, token-before-await, post-suspension checks, invalidate-during-consume interleavings, separate authorization, and automated consume-before-dispatch proof are in Task 3; the explicitly assembled real-resolver/fake-provider coordinator harness, non-class-bound struct sink conformance without editing `TextInjector.swift`, reference-probe lifetime release, isolated settings defaults, explicit Combine imports, interface-only settings wiring, and beta-local/diagnostic-only copy are in Tasks 4/5; executable Phase 1 gating is in Task 6; exact four-test schema selectors/count, hashed local artifacts, provider revocation checkpoint, installed pre-merge physical evidence, final `todo -> in-progress -> done`, Phase 2, exact workflow-file/name/event/SHA-to-successful-run mapping, safe operational integrated installation, and local post-merge attribution are in Task 7.
- Scope check: storage/resolution, app lifecycle/UI, and the controlled diagnostic are dependent increments of one feature; each has an independent red/green/review gate, so separate plans would obscure their shared authorization and output invariants.
