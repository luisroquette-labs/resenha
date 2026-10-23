# Proactive Real-Time Contextual Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Resenha proactively correct ambiguous spoken words during the same push-to-talk attempt by combining local Whisper uncertainty/candidates with bounded JEV choices, without requiring prior dislike feedback or permitting free rewriting.

**Architecture:** Extend the existing inference value from text-only to text plus local token evidence. An observational whisper.cpp logits callback records bounded top alternatives keyed by decoder prefix; after decoding, only evidence that aligns with the selected transcript survives. A deterministic candidate generator creates one exact ambiguous occurrence from acoustic evidence or a local-vocabulary fallback. Existing continuous session and final resolver paths send bounded choices to JEV, validate the exact selected option, and feed accepted terms into an ephemeral per-attempt prompt. All existing authorization, deadlines, cancellation, audit, and single-insertion boundaries remain owners of their current responsibilities.

**Tech Stack:** Swift 5, AppKit/SwiftUI, Foundation, Security, whisper.cpp C API, XCTest, XcodeGen, macOS 14+

**Spec:** `.specs/tasks/todo/add-proactive-real-time-contextual-guidance.feature.md`

## Global Constraints

- Work only in `feat/jev-real-time-guidance` at `/Users/luisroquette/Projects/.worktrees/resenha-jev-real-time-guidance`, based on current `origin/main`; preserve every unrelated worktree.
- Reuse `ContinuousContextSession`, `RevisionBoundJevLoop`, `ContextualCorrectionResolver`, `ContextualCorrectionPolicy`, `PersonalRemoteAuthorizationOwner`, `OpenRouterDecisionsClient`, and `ContextualAttemptStore`. Do not add a second scheduler, provider, credential, transport, or audit store.
- Whisper remains the only audio recognizer. JEV sees text choices, never audio/logits/probabilities, and cannot return arbitrary text.
- The logits callback must never mutate its `float *` input. It retains only bounded token IDs/scores until the inference returns, then releases all evidence.
- No second Whisper pass, no package dependency, no embeddings, no history lookup, and no destination-app context.
- PT-BR proactive generation only. Current learned-example evaluation remains available for all already-supported languages.
- Replace the unproven 200 ms rolling deadline with a measured 1,200 ms hard deadline; preserve the 900 ms final deadline, thresholds of 0.90/0.90, one-active/one-pending scheduling, 500 ms minimum interval, 4 KiB request cap, 64 KiB response cap, and fail-open behavior. Rolling work never blocks recognition or release.
- Add a six-provider-dispatch hard cap per dictation attempt and a five-term cap for ephemeral accepted vocabulary. Consume the budget immediately before `provider.decide`; credential/transport/provider failures do not refund it. Revisions without a safe candidate consume no budget.
- Automated tests and planning make zero network calls. A paid physical provider run occurs only after local gates, explicit execution-stage cost confirmation if required by the active session policy, and a visible opt-in in the candidate app.
- Native compilation/tests run only through `~/.local/bin/mac-gate`; never call `xcodebuild` directly. This native app has no Vercel gate.
- One branch, one PR, agent-owned review/integration. Install only the exact integrated build after physical candidate approval.

## Review Focus

- Beam-search callbacks occur for multiple decoder branches. No alternative is eligible until its complete token-prefix key is proven to be an ancestor of the final selected token sequence.
- Token text and normalized transcript indices can diverge. Candidate evidence must cross normalization as value data (`heard`, alternatives, token probability), then rebind by validated whole-term occurrence; never persist raw `String.Index` across strings.
- A real JEV sample previously took about 884 ms while rolling revisions arrive every 500 ms. Task 4 tests exact-prefix rebase onto newer hypotheses; any edit inside the evaluated prefix discards the result.
- The current final path intentionally uses the completed WAV and inserts once. Ephemeral rolling choices may bias the final prompt but never replace the final transcript directly.
- Call expansion is the largest cost/privacy regression risk. Enforce candidate-first dispatch, six attempts per dictation, no retry, sanitized audit, and immediate cancellation on authority changes.
- Premature context can create a confidently wrong choice. Task 4 requires two consecutive identical proactive candidate signatures before rolling dispatch; learned pairs and final resolution keep their existing paths.
- Corpus tuning and evaluation must be separate. Freeze thresholds and hashes before evaluation; zero control regressions is a hard gate.

## File Map

| File | Change | Responsibility |
|---|---|---|
| `Sources/WhisperKey/WhisperTranscriber.swift` | Modify | Recognition evidence, observational logits collector, selected-beam alignment, rolling/final evidence propagation. |
| `Sources/WhisperKey/ContextualCorrections.swift` | Modify | Proactive candidate domain, local generator, exact multi-choice JEV DTO/validation/application while preserving legacy binary decisions. |
| `Sources/WhisperKey/ContextualAttemptAudit.swift` | Modify | Record selected option IDs without transcript/alternative content and preserve current sanitized proof. |
| `Sources/WhisperKey/ContinuousContextSession.swift` | Modify | Candidate evidence on revisions/work, ephemeral accepted vocabulary, lifecycle erasure. |
| `Sources/WhisperKey/DictationCoordinator.swift` | Modify | Carry evidence through rolling/final paths and pass ephemeral vocabulary into the authoritative final recognition. |
| `Sources/WhisperKey/WhisperKeyApp.swift` | Modify | Compose glossary/store vocabulary snapshot and accepted-term callback without a new service layer. |
| `Sources/WhisperKey/ProductPreferences.swift` | Modify | Explain spoken-context correction, authorization without prior feedback, and bounded cost; reuse the current personal remote toggle. |
| `Tests/Fixtures/proactive-context-guidance.json` | Create | Frozen calibration/evaluation/control corpus and thresholds/provenance. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Modify | Unit, integration, corpus, privacy, lifecycle, and regression coverage. |
| `project.yml` / `WhisperKey.xcodeproj/project.pbxproj` | Modify/regenerate | Bundle the frozen fixture in the test target and regenerate the Xcode project. |
| `README.md`, `docs/PRIVACY.md`, `docs/architecture.md` | Modify | Exact capability, data flow, cost cap, privacy boundary, and non-claims. |
| `docs/testing/proactive-real-time-contextual-guidance.md` | Create | Frozen evidence, gates, physical/provider proof, and installed-build provenance. |

## Task 1: Freeze the candidate contract and corpus

**Files:**
- Move: `.specs/tasks/todo/add-proactive-real-time-contextual-guidance.feature.md` → `.specs/tasks/in-progress/add-proactive-real-time-contextual-guidance.feature.md`
- Create: `Tests/Fixtures/proactive-context-guidance.json`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`
- Modify: `project.yml`
- Regenerate: `WhisperKey.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces fixture envelope `ProactiveContextFixture` with `schemaVersion`, `frozenSHA256`, `thresholds`, `calibration`, `evaluation`, and `controls`.
- Produces `ProactiveCandidateThresholds(tokenProbability: Float, maximumLogitGap: Float, minimumVocabularySimilarity: Double)` used by Tasks 2–4.

- [ ] **Step 1: Promote the spec and add the failing fixture-schema test.** Test `testProactiveContextFixtureIsFrozenPartitionedAndValid` loads `proactive-context-guidance.json`, asserts 60+ evaluation rows, 15+ families, 30+ controls, disjoint IDs/semantic keys, and exact SHA-256.
- [ ] **Step 2: Run the single RED test.**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build -only-testing:WhisperKeyTests/WhisperKeyTests/testProactiveContextFixtureIsFrozenPartitionedAndValid test
```

Expected: FAIL because the fixture/loader is absent.

- [ ] **Step 3: Add the exact fixture contract and resource.** Each row contains `id`, `semanticKey`, `partition`, `family`, `language`, `recognizedText`, selected token `text/probability`, `alternatives` as `text/logit`, `vocabulary`, `expectedChoice`, and `protectedSemantics`. Calibration alone stores the selected thresholds. Evaluation and controls cannot be read by the selector.
- [ ] **Step 4: Add boundary tests.** `testProactiveThresholdsAcceptBoundaryAndRejectOutside` asserts probability/logit/similarity at B−epsilon, B, and B+epsilon; `testProactiveThresholdSelectionCannotReadEvaluationRows` injects a trap evaluation row and asserts unchanged thresholds.
- [ ] **Step 5: Bundle the fixture.** Add it to the test target resources in `project.yml`, run `xcodegen generate`, then rerun the two named tests through `mac-gate`.

Expected: PASS; `git diff --check` prints nothing.

- [ ] **Step 6: Commit Task 1.**

```bash
git add .specs/tasks/in-progress/add-proactive-real-time-contextual-guidance.feature.md Tests/Fixtures/proactive-context-guidance.json Tests/WhisperKeyTests/WhisperKeyTests.swift project.yml WhisperKey.xcodeproj/project.pbxproj
git commit -m "test: freeze proactive context guidance corpus"
```

## Task 2: Return safe Whisper candidate evidence

**Files:**
- Modify: `Sources/WhisperKey/WhisperTranscriber.swift:103-515`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**

```swift
struct WhisperAlternativeToken: Equatable, Sendable {
    let tokenID: Int32
    let text: String
    let logit: Float
}
struct WhisperTokenEvidence: Equatable, Sendable {
    let tokenID: Int32
    let text: String
    let probability: Float
    let alternatives: [WhisperAlternativeToken]
}
struct WhisperInferenceResult: Equatable, Sendable {
    let text: String
    let tokens: [WhisperTokenEvidence]
}
struct WhisperTranscription: Equatable, Sendable {
    let text: String
    let tokenEvidence: [WhisperTokenEvidence]
}
```

- `WhisperTranscriber.Inference` returns `WhisperInferenceResult`.
- `transcribe(...) -> String` remains and delegates to `transcribeWithEvidence(...) -> WhisperTranscription`.
- `RollingWhisperHypothesis` gains `tokenEvidence: [WhisperTokenEvidence]`.
- `ContinuousContextRollingEvent`, `ContinuousContextRevision`, and `ContinuousContextWork` gain the same immutable `tokenEvidence` value; final/test events use `[]` when no evidence exists.

- [ ] **Step 1: Write RED value/compatibility tests.** Add `testTextOnlyInferenceProducesEmptyEvidence`, `testTranscribeCompatibilityWrapperReturnsSameText`, and `testRollingHypothesisCarriesBoundedEvidence`.
- [ ] **Step 2: Run those three tests through `mac-gate`.** Expected: compile FAIL because the evidence types/method are absent.
- [ ] **Step 3: Add the value types and compatibility wrapper.** Update the ten `WhisperTranscriber(infer:)` test closures to return `.init(text: existingText, tokens: [])`; do not change their assertions.
- [ ] **Step 4: Write RED collector tests.** `testLogitCollectorNeverMutatesInput`, `testLogitCollectorKeepsFourRegularFiniteAlternatives`, `testSelectedBeamAlignmentRejectsDecoyPrefixes`, `testUnmatchedPrefixReturnsNoAlternatives`, and `testCollectorReleasesOnCancellation` use synthetic token IDs/prefixes and a deinit probe.
- [ ] **Step 5: Implement `WhisperLogitCollector`.** The noncapturing C callback obtains an `Unmanaged<WhisperLogitCollector>` from `logits_filter_callback_user_data`, copies at most the latest 128 prefix IDs, scans `0..<whisper_n_vocab(ctx)` without writing to `logits`, and retains four finite regular-token alternatives. Keep at most the latest 256 callback records. Special IDs (`>= whisper_token_eot(ctx)`), empty strings, `<|...|>`, invalid UTF-8, and non-lexical-only strings are excluded.
- [ ] **Step 6: Align and bound after `whisper_full`.** Read selected IDs/text/probability through `whisper_full_get_token_id/text/p`; match callback prefixes by exact suffix ancestry of the selected sequence; ambiguous/unmatched records get `alternatives: []`. Retain at most 128 selected tokens and the suffix corresponding to the latest 600 transcript characters.
- [ ] **Step 7: Run collector/unit regressions.** Use `-only-testing` for the eight named tests; expected PASS.
- [ ] **Step 8: Run one real local Whisper regression and benchmark.** Extend the existing real-engine test to assert returned text equals its pre-change baseline, token probabilities are finite in `0...1`, alternatives/records/prefix IDs are bounded, and the audio fixture causes zero network calls. Run 20 warm fixture inferences with collection off/on in alternating order; assert collection p95 overhead is <=15% and record both distributions.
- [ ] **Step 9: Commit Task 2.**

```bash
git add Sources/WhisperKey/WhisperTranscriber.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: expose bounded Whisper candidate evidence"
```

## Task 3: Generate one conservative proactive occurrence

**Files:**
- Modify: `Sources/WhisperKey/ContextualCorrections.swift:340-1028`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**

```swift
enum ContextualCandidateSource: String, Codable, Sendable { case learned, acoustic, vocabulary }
struct ContextualReplacementOption: Equatable, Sendable {
    let id: String       // replace_1...replace_3
    let value: String
    let source: ContextualCandidateSource
}
// Existing fields remain; `canonical` is the first option for binary compatibility.
struct ContextualCorrectionOccurrence: Equatable, Sendable {
    let questionID: String
    let heard: String
    let canonical: String
    let alternatives: [ContextualReplacementOption]
    let ordinal: Int
    let range: Range<String.Index>
}
struct ProactiveContextualCandidateGenerator {
    static func candidate(
        text: String,
        language: String,
        tokenEvidence: [WhisperTokenEvidence],
        glossaryTerms: [String],
        examples: [ContextualCorrectionExample],
        thresholds: ProactiveCandidateThresholds
    ) -> ContextualCorrectionOccurrence?
}
```

- [ ] **Step 1: Write RED source-priority tests.** `testLearnedCandidateOutranksAcousticAndVocabulary`, `testAcousticCandidateOutranksVocabulary`, and `testVocabularyCandidateWorksWithoutFeedbackExample` use the same heard span with competing sources.
- [ ] **Step 2: Write RED safety tests.** Cover high-confidence token, unsupported language, unbound evidence, repeated-term ordinal ambiguity, numbers, currency, URL, email, code identifier, isolated `não`, punctuation-only, case-only, invalid Unicode scalar protection, empty vocabulary/evidence, and deterministic ties. Every case asserts `nil` and zero provider calls.
- [ ] **Step 3: Run the named candidate tests.** Expected: compile FAIL because generator/types are absent.
- [ ] **Step 4: Implement exact acoustic generation.** Rebind token `text` into `text` as a whole-term ordinal; require probability at/below the frozen threshold; retain at most three lexical alternatives within maximum logit gap; fold case/diacritics only for comparison, never for output.
- [ ] **Step 5: Implement vocabulary fallback.** Candidate pool is `TranscriptionGlossary.terms + examples.map(\.canonical)`, folded/deduplicated and capped by existing 200+100 source limits. Rank normalized Damerau-Levenshtein similarity descending, then folded value ascending. Below the frozen similarity threshold returns `nil`; keep only the first result.
- [ ] **Step 6: Reuse existing safety validators.** Extend `areValid`/`preservesProtectedSemantics` to validate every alternative, exact ordinal/range in the current text, and nonoverlap. Keep `matchCandidates` output byte-compatible for learned single-option cases.
- [ ] **Step 7: Run all Task 3 tests and the existing contextual matching group.** Expected: PASS, including `rosto -> Hostel` from vocabulary with no example and all no-change controls.
- [ ] **Step 8: Commit Task 3.**

```bash
git add Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: generate proactive contextual candidates"
```

## Task 4: Generalize the bounded JEV decision and cost cap

**Files:**
- Modify: `Sources/WhisperKey/ContextualCorrections.swift:348-380,598-645,1031-1699`
- Modify: `Sources/WhisperKey/ContinuousContextSession.swift:123-145,519-650`
- Modify: `Sources/WhisperKey/ContextualAttemptAudit.swift:1-238`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**

```swift
struct ContextualDecisionChoice: RawRepresentable, Codable, Equatable, Sendable {
    let rawValue: String
    static let keepOriginal = Self(rawValue: "keep_original")
    static let replace = Self(rawValue: "replace_1") // legacy spelling retained
}
// Returns nil for keep/unknown; 0 for replace_1, 1 for replace_2, 2 for replace_3.
func replacementIndex(for choice: ContextualDecisionChoice, optionCount: Int) -> Int?
final class ContextualDispatchBudget: @unchecked Sendable {
    init(limit: Int = 6)
    func consume() -> Bool
    var consumed: Int { get }
}
struct ContextualRevisionRebase {
    static func apply(
        result: RevisionBoundContextualResult,
        evaluatedSource: String,
        occurrence: ContextualCorrectionOccurrence,
        to latestSource: String
    ) -> String?
}
struct ProactiveCandidateSignature: Equatable, Sendable {
    let foldedHeard: String
    let ordinal: Int
    let orderedOptionValues: [String]
}
```

- `OpenRouterDecisionsClient.requestDTO` emits criteria for exactly `keep_original` plus occurrence alternatives.
- One `ContextualDispatchBudget` is created per `DictationCoordinator` attempt and shared by the rolling loop and final resolver request; it returns true only six times total.

- [ ] **Step 1: Pin legacy compatibility RED/GREEN.** Before changing production code, add `testSingleAlternativeRequestDTOIsLegacyCompatible` asserting the existing learned request still contains only `keep_original`/`replace_1`, with the same canonical state field and response parsing.
- [ ] **Step 2: Add RED multi-choice tests.** `testRequestDTOCarriesThreeExactAlternatives`, `testReceiptRejectsUnknownChoice`, `testReceiptRejectsMissingOrExtraProbabilities`, `testValidatorRejectsReplacementOutsideSuppliedOptions`, and `testApplyingUsesExactSelectedAlternative`.
- [ ] **Step 3: Implement dynamic exact choices.** Custom-decode raw option IDs; accept only `keep_original` and contiguous `replace_1...replace_N` where `N == alternatives.count`. Resolve the replacement strictly by index into the occurrence options. Preserve 0.90 confidence and selected-probability gates and whole-request abstention.
- [ ] **Step 4: Add RED stability, budget, and rebase tests.** Stability tests assert the first proactive sighting makes zero calls, the identical second sighting dispatches once, changed heard/ordinal/options reset the counter, learned candidates dispatch as before, and final resolution needs no rolling sightings. Budget tests are `testProviderDispatchBudgetAllowsExactlySixAttempts`, `testConcurrentBudgetCannotExceedSix`, `testNoCandidateConsumesNoBudget`, and `testFailureDoesNotRefundBudget`. Rebase tests assert: exact appended suffix accepts; any edit in evaluated prefix rejects; changed occurrence/options reject; cancellation/policy/store generation reject; rebasing never mutates text outside the exact occurrence.
- [ ] **Step 5: Implement stability, one shared budget, and bounded rebase.** Store only the latest proactive signature/count in locked session state; dispatch on count 2, reset on any signature change, and clear it with sensitive state. Create the budget when an attempt starts; pass it into `RevisionBoundJevLoop` and `ContextualResolutionRequest`. Validate candidate/body, consume immediately before `provider.decide`, and use a 1,200 ms rolling deadline. On return, apply directly to the same revision or rebase only when `latestSource.hasPrefix(evaluatedSource)` and occurrence/options/policy/store/session identities still validate. The seventh combined attempt or failed rebase stays local.
- [ ] **Step 6: Keep audit content-free.** Store option IDs, confidence/probability, model, request ID, usage/cost, latency, and disposition. Add `testAttemptAuditContainsNoHeardReplacementSentenceOrBody` encoding the audit and scanning against fixture content and authorization prefixes.
- [ ] **Step 7: Run Task 4 plus existing transport/deadline/audit tests through `mac-gate`.** Add 1,199/1,200/1,201 ms rolling boundary cases. Expected: PASS; request remains <=4096 bytes and response <=65536 bytes.
- [ ] **Step 8: Commit Task 4.**

```bash
git add Sources/WhisperKey/ContextualCorrections.swift Sources/WhisperKey/ContinuousContextSession.swift Sources/WhisperKey/ContextualAttemptAudit.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: rank exact JEV alternatives with bounded cost"
```

## Task 5: Feed accepted context into later rolling and final recognition

**Files:**
- Modify: `Sources/WhisperKey/ContinuousContextSession.swift:123-430`
- Modify: `Sources/WhisperKey/WhisperTranscriber.swift:103-417`
- Modify: `Sources/WhisperKey/DictationCoordinator.swift:122-588`
- Modify: `Sources/WhisperKey/WhisperKeyApp.swift:28-213`
- Modify: `Sources/WhisperKey/ContextualCorrections.swift:2116-2230`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**

```swift
// ContinuousContextSession
enum ContinuousContextApplication: Equatable, Sendable { case direct(String), rebased(String) }
func applyContextualResult(
    _ result: RevisionBoundContextualResult,
    occurrence: ContextualCorrectionOccurrence,
    for work: ContinuousContextWork
) -> ContinuousContextApplication?
var ephemeralTerms: [String] { get } // insertion order, max 5

// WhisperTranscriber
func makeRollingRecognizer(
    language: TranscriptionLanguage,
    glossaryText: String,
    promptTerms: @escaping @Sendable () -> [String],
    maximumRuntime: TimeInterval,
    clock: @escaping @Sendable () -> TimeInterval,
    onHypothesis: @escaping @Sendable (RollingWhisperHypothesis) -> Void
) -> RollingWhisperRecognizer?
```

- `DictationCoordinator` snapshots `finalPromptTerms` on release and passes them to `transcribeWithEvidence`; it passes final token evidence and vocabulary into the final resolver request.
- `ContinuousContextLoopFactory` becomes `(ContinuousContextSession, ContextualDispatchBudget) -> RevisionBoundJevLoop?`; app composition injects `glossaryTerms: () -> [String]` into the loop.
- `ContextualResolutionRequest` gains `tokenEvidence: [WhisperTokenEvidence]`, `glossaryTerms: [String]`, and `dispatchBudget: ContextualDispatchBudget`; the final resolver uses those plus its existing store snapshot.
- `PersonalRemoteAuthorizationOwner` receives `proactiveEvidenceAvailable: @MainActor @Sendable () -> Bool`; local eligibility is enabled beta + healthy store + (`examples` nonempty OR proactive evidence available).

- [ ] **Step 1: Write RED lifecycle tests.** `testAcceptedCurrentResultAddsEphemeralTerm`, `testStaleResultCannotAddTerm`, `testTermsAreDeduplicatedAndCappedAtFive`, and one parameterized test asserts empty terms after commit/cancel/fail/permission loss/opt-out/app termination.
- [ ] **Step 2: Implement atomic application and session terms inside existing locked storage.** Add no new store/service. `applyContextualResult` validates direct/rebased identity, writes the latest preview, and adds the selected canonical term in the same lock transaction; failure writes neither. `clearSensitiveState()` clears terms.
- [ ] **Step 3: Write RED prompt-flow tests.** A prompt spy asserts revision 1 uses base glossary, accepted `Hostel` appears in revision 2, and the completed-WAV inference receives `Hostel`; a cancelled next attempt receives none.
- [ ] **Step 4: Make rolling prompts late-bound.** Replace stored `Session.prompt: String` with base prompt plus `promptTerms()` evaluated when work starts. Fold/deduplicate and cap combined text with `TranscriptionGlossary.maximumPromptCharacters`.
- [ ] **Step 5: Carry rolling and final evidence.** Add immutable evidence to the rolling event/revision/work structs and copy it during `ingest`. Snapshot terms in `hotkeyReleased` before cancelling rolling recognition. `transcribeRecording` calls `transcribeWithEvidence`; `finishTranscription` passes its evidence, parsed glossary terms, and shared budget in `ContextualResolutionRequest`, then stages exactly one resolved string.
- [ ] **Step 6: Write RED authorization tests.** `testPersonalRemoteCanAuthorizeWithProactiveEvidenceAndNoExample`, `testNoExampleAndNoProactiveEvidenceRemainsIneligible`, and `testAuthorizationStillCannotDispatchWithoutConcreteCandidate`.
- [ ] **Step 7: Inject proactive capability in app composition.** Pass a constant capability closure owned by `WhisperTranscriber` rather than store contents. Preserve consent, Keychain read-back, durable epoch, policy generation, revocation, and provider error handling.
- [ ] **Step 8: Run Task 5 integration tests plus all coordinator single-insertion/cancellation tests.** Expected: PASS; output sink count is one; history/clipboard spies receive no provisional text.
- [ ] **Step 9: Commit Task 5.**

```bash
git add Sources/WhisperKey/ContinuousContextSession.swift Sources/WhisperKey/WhisperTranscriber.swift Sources/WhisperKey/DictationCoordinator.swift Sources/WhisperKey/WhisperKeyApp.swift Sources/WhisperKey/ContextualCorrections.swift Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "feat: guide active transcription with accepted context"
```

## Task 6: Evaluate, document, and pass two clean reviews

**Files:**
- Modify: `Sources/WhisperKey/ProductPreferences.swift:700-770`
- Modify: `README.md`
- Modify: `docs/PRIVACY.md`
- Modify: `docs/architecture.md`
- Create: `docs/testing/proactive-real-time-contextual-guidance.md`
- Modify: `Tests/WhisperKeyTests/WhisperKeyTests.swift`

**Interfaces:**
- Corpus runner emits content-free aggregate counts: baseline/current errors, unauthorized changes, control regressions, candidate-source counts, fallback count, and partition hash.
- Settings copy says “correção contextual durante a fala”; it never says JEV predicts unspoken words.

- [ ] **Step 1: Add the evaluation runner/test.** `testProactiveEvaluationImprovesWithoutControlRegressions` reads evaluation/control partitions only and asserts 20%+ relative error reduction, zero unauthorized changes, zero control regressions, all 15 families covered, and deterministic identical replay.
- [ ] **Step 2: Run the evaluation test twice through `mac-gate`.** Expected: identical PASS reports; calibration rows never appear in evaluation traces.
- [ ] **Step 3: Update product/privacy/architecture copy.** State six dispatch attempts maximum per dictation; only bounded current sentence/options leave the Mac after opt-in; audio/logits/probabilities/full vocabulary/history/app context remain local; offline and feature-off remain local; next-word generation is absent.
- [ ] **Step 4: Run static checks.**

```bash
git diff --check
rg -n "Bearer |sk-or-|Authorization:|request\.httpBody|recognizedText|replacement" Sources docs README.md
```

Expected: no secret; logs/audit docs contain no transcript/body persistence path. Review every semantic hit rather than suppressing the command.

- [ ] **Step 5: Run the full native gate.**

```bash
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

Expected: all tests PASS. If site files changed, also run `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`; otherwise record “not applicable”.

- [ ] **Step 6: Commit the product candidate before review.**

```bash
git add Sources/WhisperKey/ProductPreferences.swift README.md docs/PRIVACY.md docs/architecture.md docs/testing/proactive-real-time-contextual-guidance.md Tests/WhisperKeyTests/WhisperKeyTests.swift
git commit -m "docs: validate proactive real-time guidance"
```

- [ ] **Step 7: Review pass 1 on that committed product SHA.** Inspect spec coverage, final diff, beam alignment, request schema, privacy/cost, cancellation/lifecycle, corpus partitioning, UI/accessibility, and test evidence. Keep the review note outside tracked files until both passes finish. Any substantive finding returns to its owning task, receives a fix/test commit and full gate, and resets the clean counter.
- [ ] **Step 8: Review pass 2 on the same unchanged product SHA.** Repeat the exact checklist. Proceed only when both consecutive notes say “no substantive finding”. Append both notes and the reviewed product SHA to the evidence doc, commit that evidence-only change, and run `git diff --check`. Task 7 records the evidence commit separately from the reviewed product SHA.

## Task 7: Prove physically, integrate, and install

**Files:**
- Modify: `docs/testing/proactive-real-time-contextual-guidance.md`
- Move after all proof passes: `.specs/tasks/in-progress/add-proactive-real-time-contextual-guidance.feature.md` → `.specs/tasks/done/add-proactive-real-time-contextual-guidance.feature.md`

**Interfaces:**
- Evidence record contains tested SHA/tree, source/app manifests, executable/signing/model hashes, hardware/OS, stage p50/p95/max, dispatch/request counts, fallback/cost, and sanitized provider proof.

- [ ] **Step 1: Commit a clean candidate and build it through `mac-gate`.** Record exact SHA/tree before build; sign/verify an isolated app and record hashes. Do not replace `/Applications/Resenha.app` yet.
- [ ] **Step 2: Run the physical corpus.** Collect at least 100 provisional revisions, 30 finalizations, and 20 real rolling provider decisions across unseen ambiguity, learned ambiguity, ordinary controls, offline, cancellation, and feature-off. Require candidate-to-decision p95 below 1,200 ms; record direct/rebased/stale/fallback counts. Check TextEdit plus a disposable browser field, target focus, clipboard restoration, VoiceOver, reduced motion, CPU/RAM/thermal, and exactly one insertion.
- [ ] **Step 3: Run the minimal real JEV proof under current cost authorization.** Require matching sanitized request ID, resolved model, usage/cost, revision identity, selected exact option ID, disposition, dispatch count, and actual request count. Store no phrase, option value, key, header, or body.
- [ ] **Step 4: Apply the feedback loop.** Any failed criterion returns to its owning Task 1–6, gets a regression test and fix, repeats the full native gate, and restarts the two-clean-review count before physical retest.
- [ ] **Step 5: Close the spec and final gate.** Move the spec to `done`, commit evidence/spec move, and rerun the full native gate on that exact SHA.
- [ ] **Step 6: Push one branch and open/update one PR.** Review the complete diff, wait for applicable GitHub checks on latest SHA, and merge autonomously only when green.
- [ ] **Step 7: Verify main and install.** Follow post-merge checks to terminal green; build/sign the exact integrated SHA through `mac-gate`; replace `/Applications/Resenha.app`; open it; record version/PID/executable hash; smoke-test hotkey, local/offline, learned, proactive, and ordinary-control paths.

Expected: installed merged build demonstrates an unseen proactive correction with verified JEV participation and no control regression. Correct output without matching provider evidence does not count as JEV proof.

## Definition of Done

- [ ] A prior dislike is not required for at least the frozen unseen-ambiguity evaluation families.
- [ ] Whisper evidence and JEV exact-choice participation are independently observable without storing content.
- [ ] Evaluation and physical gates meet RT-11/RT-12 with zero unauthorized/control regressions.
- [ ] Two consecutive reviews of the same committed product SHA are clean; the later evidence-only commit identifies that SHA; native/applicable remote checks are green.
- [ ] One PR is merged and the exact integrated build is installed and smoke-tested.

## Spec Traceability

| Acceptance | Owning task |
|---|---|
| RT-1, RT-2, RT-2A | Task 2: real inference evidence, bounded observational callback, selected-beam alignment, overhead benchmark. |
| RT-3, RT-3A, RT-4 | Task 3 candidate generation plus Task 4 rolling stability gate. |
| RT-5, RT-6, RT-6A | Task 4 exact JEV options, shared dispatch budget, deadline, and safe rebase. |
| RT-7, RT-8, RT-9 | Task 5 ephemeral prompt flow, authoritative final, lifecycle and fail-open integration. |
| RT-10 | Tasks 4, 5, and 6: authorization, bounded payload, sanitized audit, privacy copy/tests. |
| RT-11, RT-12, RT-13 | Tasks 1 and 6: frozen corpus, evaluation, UI/accessibility, claim limits. |
| RT-14 | Tasks 6 and 7: serialized native gate, single PR, merge, exact installed build. |
