# Codebase impact — context-aware corrections

Task: `.specs/tasks/draft/add-context-aware-corrections.feature.md`
Date: 2026-10-20. Source: `feat/transcription-feedback`, HEAD `6fb3f12274bc51127e31404f2549060c5621ff68`, plus preserved visual/test WIP.

This report distinguishes current code from proposed implementation. No network decision, native test, installed-app behavior or provider billing was verified here. API facts must come from current primary research; the dedicated task's Acceptance Criteria supersede conflicting limits in older step 07. Its fixed contract is local example-based candidate selection, no examples in the request, a synthetic sentence of at most 600 characters, a 900 ms total resolver deadline, whole-input abstention above three candidate occurrences, and one later authorized synthetic call without retry or recurring/monthly budget.

## Current root cause and exact pipeline

`FloatingPanelController.saveCorrection(token:)` (`FloatingPanel.swift:222`) calls `ProductPreferences.saveTranscriptionCorrection(heard:canonical:)` (`ProductPreferences.swift:175`). That method adds a validated `heard = canonical` line to `resenha.transcriptionGlossary`, reads it back and verifies rollback on failure. Next dictation snapshots that glossary at release.

`WhisperTranscriber.transcribe(audioURL:language:glossaryText:) throws -> String` (`WhisperTranscriber.swift:58`) uses canonical terms as the Whisper prompt and calls `TranscriptPostprocessor.process(_:glossary:)` (`:302`). The processor normalizes segments/spacing, applies every glossary replacement with Unicode word boundaries and case-insensitive matching, normalizes Portuguese times, then handles explicit spoken corrections. It has no context-dependent choice. Therefore `rosto = Hostel` rewrites every matching “rosto” and also biases the next Whisper prompt.

Current production chain:

```text
AppDelegate.handleHotkeyPress → coordinator.hotkeyPressed
  capture target + language + attempt ID → recorder.start
handleHotkeyRelease → coordinator.hotkeyReleased
  recorder.stop → transcribing → snapshot glossary
  detached transcriber → global postprocessor
  cancellation check + attemptID check
  TextInjector.stage(transcript) → onTranscript(transcript)
  AppDelegate.recordTranscript → optional TranscriptHistory.add
  inserting → await TextInjector.insertStaged
  completeInsertion(attemptID:isCancelled:) → snapshot completion → reset
  AppDelegate.onCompleted → panel.offerFeedback → optional editor Save
```

There is one source production call to transcribe and one automatic insertion route. `AppDelegate.copyRecentTranscript(_:)` deliberately copies already-final history text; it must not re-evaluate Jev. No runtime Services insertion route exists in this checkout; historical Services docs are not its current execution path.

“Original” in fail-safe requirements must mean the candidate returned by the current local transcription/postprocessing pipeline, byte-for-byte, before contextual changes. It cannot mean raw Whisper text without changing established normalization behavior.

## Interface and caller map

| Existing symbol/signature | Callers and downstream dependencies | Required treatment |
|---|---|---|
| `WhisperTranscriber.transcribe(audioURL:language:glossaryText:) throws -> String` | Coordinator; embedded model smoke test near test line 1678 | Keep local inference unchanged. Never mix contextual destinations into glossary prompt. |
| `TranscriptPostprocessor.process(_:glossary:) -> String` | Transcriber and glossary/quality tests | Preserve deterministic legacy path. Whole-term regex pattern is reusable; a new helper is optional, not required solely to avoid a few repeated lines. |
| `ProductPreferences.saveTranscriptionCorrection(heard:canonical:) -> CorrectionSaveResult` | Panel Save and glossary storage tests | Stop calling it from contextual feedback; retain legacy behavior/tests for explicitly global settings. Do not migrate existing glossary entries automatically. |
| `DictationCoordinator.hotkeyReleased()` | `AppDelegate.handleHotkeyRelease()` | Await bounded resolver after local candidate, before stage/history. Introduce a small injected async decision seam and a post-transcription side-effect seam sufficient to test actual coordinator ordering without microphone/Whisper. |
| `DictationCompletion` | `completeInsertion`; panel `CorrectionSession`; many tests constructing `.init(id:targetApplication:)` | Add immutable successful final transcript and session language, available only for ephemeral feedback. Thread values through completion before reset clears attempt state. Update all test constructors; an empty default would hide missing context. |
| `completeInsertion(attemptID:isCancelled:)` | Coordinator after `insertStaged`; state tests | Extend with final transcript/language or use a tightly scoped pending snapshot; preserve its current canceled/identity/phase guards and callback-after-reset behavior. |
| `FloatingPanelController.configureFeedback(preferences:)`, `offerFeedback(_:)`, `saveCorrection(token:)` | `AppDelegate.observeCoordinator`; panel/lifecycle tests; menu routes | Inject contextual store, validate heard against session transcript, save one bounded labeled example, then retire current token. Source text must come from that completion, never history/clipboard. |
| `CorrectionEditor`, `canSaveCorrection`, `openCorrection`, `cancelFeedback` | Panel and SwiftUI view | Replace glossary-specific availability/reload/rollback coupling with contextual-store health. Preserve error draft, accessible error, idempotence, focus restoration and stale token protection. |
| `ProductPreferences` / `TranscriptionSettingsPane` | App ownership/settings controller; many preference/UI tests | Add default-off opt-in and operational settings/status; no credential or transcript payload in defaults. Explain global glossary vs contextual examples; provide delete item/all/key. |
| `AppDelegate.observeCoordinator`, launch, terminate | Application lifecycle and integration tests | Compose one store/resolver/credential adapter; wire disable/key-delete to cancellation or generation invalidation. Launch and opening settings never send decisions. |
| `TextInjector.stage(_:) throws -> Int`; `insertStaged(into:changeCount:) async throws` | Coordinator; clipboard tests | Keep clipboard/target safeguards. One final string enters stage/history/insertion; feedback Save never re-stages or re-inserts. |
| `TranscriptHistory.add(_:,now:)` | `recordTranscript`, gated by `keepsHistory` | No new storage responsibility. History-off still permits explicit contextual examples, with separate disclosure/deletion controls. |

`CorrectionSession.context` currently retains only a target reference/id. After adding transcript, `hide`/`discardFeedback`, passive four-second expiry, successful Save, normal cancel, replacement offer, HUD-off and termination must release it. Existing recovery cancellation intentionally retains a draft; contextual recovery must not accidentally retain the entire transcript indefinitely. Retain only the minimal validated example needed for retry, or explicitly end recovery and require a fresh example.

There is a second retention path in `offerFeedback(_:)` at `FloatingPanel.swift:157–159`: `panel.contentView` owns an `NSHostingView`, whose `FloatingStatusView` owns `onApprove`/`onCorrect` closures referring to `context.id`. Those closures can capture the entire `DictationCompletion`, including its new transcript. `hide()` only orders the panel out and clears `feedback`; `discardFeedback()` does not replace `panel.contentView`. Therefore clearing `feedback` alone does not release every reference. Extract `let token = context.id` before constructing the view and capture only that UUID (plus weak self), or replace/remove the hosting content view when retiring feedback. Preserve the existing empty/recording view lifecycle and do not use a hidden panel as proof of release.

Add a focused release regression using a weak lifetime probe attached to test completion context: keep the controller/panel alive, offer feedback, release test-owned context, then dismiss by hide, passive expiry, Save, cancel, replacement and HUD-off/termination. After draining the relevant main-actor/autorelease work, the retired context/probe must be released even if the hosting view remains installed. Exercise retained stale action closures too: they may retain UUIDs but not transcript context, and must not act on a later session. This verifies object ownership, not impossible guaranteed erasure of all Swift string bytes.

## Smallest complete implementation surface

Recommended baseline: **16 affected files = 14 existing modifications + 2 creations, 0 deletions**. Planning artifacts are not counted. This includes native privacy presentation and product-spec consistency, not public site/store publication.

| Kind | Exact path | Change |
|---|---|---|
| Modify | `Sources/WhisperKey/DictationCoordinator.swift` | Resolver seam, guarded pre-stage await, immutable completion context. |
| Modify | `Sources/WhisperKey/FloatingPanel.swift` | Contextual save/store health and context lifetime; preserve visual WIP elsewhere. |
| Modify | `Sources/WhisperKey/ProductPreferences.swift` | Opt-in, disclosure, credential/status UI, store deletion UI; distinguish global vocabulary. Fix About's absolute “Áudio e texto processados neste Mac” for enabled beta. |
| Modify | `Sources/WhisperKey/WhisperKeyApp.swift` | Composition and cancellation on lifecycle/config change. |
| Modify | `Sources/WhisperKey/PermissionOnboarding.swift` | Scope current “100% local” badge to local transcription/default mode; do not imply enabled remote corrections are local. |
| Create | `Sources/WhisperKey/ContextualCorrections.swift` | Internal Codable records/store, occurrence matching, conservative decision validation, Decisions client, Keychain adapter and one-call authorization guard. No recurring/monthly accounting, SDK, generic provider system or new dependency. Split only if implementation clarity demands it. |
| Modify | `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Preserve existing WIP; adapt completion/panel Save tests and add store/network/resolver/coordinator regressions. |
| Create | `Tests/Fixtures/contextual-corrections.json` | Synthetic contrastive corpus, never user text. |
| Modify | `project.yml` | Explicit resource declaration for new fixture under test target; Security.framework only if required by linking conventions. Existing source directory already discovers new Swift file. |
| Modify | `WhisperKey.xcodeproj/project.pbxproj` | Regenerate via XcodeGen: current project has explicit PBX file/build references, not synchronized folders. |
| Modify | `docs/PRIVACY.md` | Exact opt-in payload, provider, local retention/deletion, no audio upload; distinguish transmitted text from default offline operation. |
| Modify | `README.md` | Local default plus optional remote beta, setup and limitations. |
| Modify | `docs/specs/00-constitution.md` | Narrow, explicit amendment to “transcripts never leave the Mac”; retain audio-local/no analytics/no arbitrary rewriting. User's beta request governs scope; no unrelated constitution rewrite. |
| Modify | `docs/architecture.md` | Pre-insertion decision branch and separate contextual data lifecycle. |
| Modify | `docs/specs/11-output-quality.md` | New feedback semantics; legacy glossary unchanged; original on uncertainty and precise confidence limits. |
| Modify | `docs/specs/08-testing.md` | Offline matrix, labeled corpus, separate authorized live calibration and physical insertion evidence. |

Read-only unless architecture requires a concrete change: `WhisperTranscriber.swift` (optional shared matcher extraction), `TextInjector.swift`, `TranscriptHistory.swift`, `NativeMenuController.swift`, `DictationInteraction.swift`, `WhisperModelManager.swift`, `FloatingStatusView.swift`, `RecordingWaveformView.swift`, `Config/Resenha.entitlements`, `Config/PrivacyInfo.xcprivacy`, `Scripts/benchmark-output.swift`, `.github/workflows/site-tests.yml`.

Public release review additionally touches `site/index.html` (currently “Fica no Mac. Ponto.” and “internet somente no primeiro download”), `AppStore/metadata/pt-BR.md`, `AppStore/metadata/submission-pt-BR.md`, `AppStore/review-notes-pt-BR.md`, and `docs/specs/20-privacy-review.md`. Those are release-dependent, not authorization to publish/update store answers in this planning task. Privacy manifest must be reassessed against actual provider processing/retention; an empty collected-data array cannot itself prove that no data leaves the app. Do not invent entitlement changes: direct target currently has an empty entitlement dictionary and model download already uses networking.

## Storage, transport and decision boundaries

Use a separate versioned store at `Application Support/Resenha/ContextualCorrections/v1.json`. Reuse the *pattern* from `TranscriptHistory` (atomic JSON, bounded load, restrictive directory/file permissions), not its private helpers or its history capacity/lifecycle. Store needs validated read-back before success, in-memory publication only after durable successful write, corrupted/oversize/unknown-version handling without silent loss, and scoped deletion that does not touch glossary/history/model files. Quarantine contains personal text too; deletion policy must account for owned contextual backups without sweeping unrelated files.

Record only UUID/version, validated pair, language and minimal explicitly labeled example required by the agreed design. Existing limits from step 07 (200 records/20,000 characters, one bounded example) are proposals to formalize, not provider facts. Duplicate/conflicting entries and byte/character accounting must be unambiguous. Validate actual matching occurrence in the completion before saving. Multiple identical words in different clauses must not silently label all occurrences from one correction.

Use `Security.framework` generic password storage with one fixed service/account; no synchronizable item, no defaults fallback, no key in launch environment, diagnostics, test snapshots or documents. Read/write/delete failures disable remote availability and expose only an operational category. Inject a tiny credential seam for tests so they do not access the user's Keychain.

`WhisperModelManager` has a `.ephemeral` URLSession, but it is a model download delegate, not a reusable authenticated decision client. Use a separate ephemeral decision session, no cookies/cache/credential storage, bounded timeout, injectable transport/URLProtocol, HTTPS fixed host and redirect rejection so authorization/payload cannot escape the intended endpoint. Do not use URLSession.shared or add a provider SDK.

Return a local choice enum plus validated confidence, never arbitrary provider text. Bind decision to the exact snapshot/occurrence locally even if the official API does not echo application IDs. Reject unknown/missing/null/mistyped choice, non-finite/out-of-range confidence, schema mismatch and mismatched response association. Apply only the exact approved canonical string to approved ranges, from last range to first; overlapping matches need deterministic handling. Dollar signs/backslashes in canonical text must be literal, not regex replacement instructions.

CK-8 fixes the request data to language, candidate pair, alternatives and the authorized synthetic current sentence of at most **600 characters**. Use Swift `String.count` consistently for that sentence limit; do not replace it with a 600-byte limit. Test 599/600/601 characters with multibyte/composed/decomposed text. Reject an overlong sentence and keep the original; do not silently truncate away necessary context. Encoded UTF-8 bytes and JSON/options overhead can inform the pre-call cost estimate without changing this character contract. The authorization header holds the credential; the body contains no identifiers, examples, history, clipboard, audio or additional personal text.

## Concurrency, one-call authorization and cancellation

The natural integration point is between local `transcript` completion and `injector.stage` at coordinator lines 182–184. Keep `.transcribing` while awaiting classification; no new UI phase is necessary. Snapshot candidate, language, eligible rules and policy generation once. Guard attempt identity/cancellation both before remote work and immediately after every await before any side effect.

Decision error/timeout/low confidence means continue once with the local original. Dictation cancellation or stale attempt means abandon the attempt with **zero** clipboard/history/insertion side effects. These are different paths; “fallback original on cancellation” must not resurrect canceled dictation.

Opt-out/key removal during an in-flight decision must invalidate its generation and prevent late apply. Cancel tasks where possible; inability to revoke an already sent request is not evidence that no data was transmitted. Explicitly distinguish opt-out (continue current dictation locally) from full dictation cancel (no output).

CK-5 fixes a **900 ms total deadline**, including preparation and resolution, and whole-input abstention when there are **more than three candidate occurrences**. Count all eligible occurrences before any request or replacement: four means no remote dispatch and the entire resolver input unchanged, not correction of the first three. Zero candidates also returns unchanged immediately. One to three candidates are the future resolver's bounded eligibility rule; they do not authorize three live calls.

HR-1/HR-2 authorize only one later controlled synthetic call with the disposable credential, zero retry, with current model/schema, exact synthetic payload and estimated cost recorded without secrets before dispatch. Keep recurring runtime dispatch disabled; the opt-in toggle alone does not expand that authorization to real user dictation. Use a one-shot execution guard for the controlled harness so repeated clicks/concurrent callbacks cannot send twice. A timeout/unknown outcome consumes the call allowance; it does not license a retry. There is no monthly ceiling, reset period, recurring spend ledger or billing configuration to implement in this task. Planning and automated tests use fakes only; expanded remote use requires its own explicit authorization.

Task-group cancellation alone does not prove a 900 ms wall deadline if a child fails to cooperate. Test the exact URLSession cancellation seam and a transport that completes late; late work must never stage or mutate another attempt. No retries for 429/5xx/timeouts. Never send the full transcript, history, screen/app content or audio as a fallback.

## Test impact and verification

Existing anchors include `testGlossaryBuildsPromptAndReplacesOnlyWholeTerms`, `testCorrectionExplicitSavePreservesDraftOnValidationAndRollbackThenConsumesOnce`, `testRollbackRecoveryCancelReloadAndRetiredTokens`, `testFeedbackCompletionRequiresCurrentSuccessfulInsertionAfterCleanup`, `testFeedbackDeadlineExpiresOnlyCurrentPassiveOfferWithoutWrites`, `testFeedbackHotkeySelfReleaseExternalAndAltTabUseRealRoutingSeam`, and `testRecoveryDraftIsErasedOnNewDictationHUDOffAndTermination`. Direct `saveTranscriptionCorrection` tests remain valid legacy regression tests; panel Save tests must stop asserting glossary writes and instead exercise the new contextual store failures. Do not remove rollback/retired-token coverage while changing storage.

| Test boundary | Required evidence |
|---|---|
| Local matching/corpus | “Meu rosto ficou vermelho” and “O rosto ficou estranho” unchanged; lodging sentence correctable; whole-word/Unicode/case/punctuation, repeated contexts, overlaps, literal replacement syntax, bounded sentences. At least five ambiguous pairs with positive/negative/ambiguous cases and separate learning/evaluation examples, per CK-10. |
| Store | Separate glossary unchanged byte-for-byte, round-trip/version/size, duplicate/conflict handling, write/read-back failure, inaccessible/oversize/corrupt file, item/all deletion, history-off independence and permissions. |
| Network/privacy | Captured URLRequest contains only language/pair/alternatives/synthetic sentence; 599/600/601-character boundaries, exact HTTPS endpoint, no redirected authorization, cache/cookie isolation, no call when disabled/missing key/one-call allowance consumed; no launch/settings/Save calls or personal examples. |
| Decision/authorization | Threshold boundary, invalid enums/NaN/Infinity/types, 401/429/5xx/offline/timeout, no retry, 900 ms including preparation, zero/three/four occurrences with entire original and zero dispatch for four, one-shot guard under concurrent invocation, key removal/opt-out mid-flight. |
| Coordinator/feedback | Decision before stage/history, same final text exactly once to every sink, failure original once, canceled/stale no sink, post-insertion Save never rewrites earlier output, context release through session AND hosting-view closure paths, editor expiry/hide/rollback cleanup and obsolete callbacks. |

Fake decisions prove control flow, not Jev's ability to infer intent. A fake that simply returns fixture labels is not quality evaluation. The SPEC resolves “learned context” as local confirmed examples selecting eligible candidates; the provider receives the selected pair and current synthetic sentence, not the stored examples. Test the local selection separately from the remote choice. Do not reopen example upload or report the fake corpus/one-call smoke test as measured Jev quality.

Canonical future gate:

```sh
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

The repository has no Package.swift/root npm preflight. Current `.github/workflows/site-tests.yml` only runs site tests on Ubuntu. Native Swift changes require the native gate; do not fabricate Vercel deployment evidence. Regenerate Xcode project if adding source/fixture, review the generated diff, then run the native gate. Bundle the new JSON explicitly or follow an existing intentional filesystem-fixture pattern; do not assume `Bundle` can see undeclared resources.

Future physical checks use the exact signed candidate and disposable TextEdit/browser fields, preserving installed app/session/personal glossary/history. Current test/CI output cannot establish real microphone, clipboard target or VoiceOver behavior. The already-authorized later single synthetic call verifies the remote contract, not corpus calibration or recurring usage; this analysis makes none.

## Risks and implementation constraints

| Risk | Level | Mitigation / needed decision |
|---|---|---|
| Sending personal text changes the core privacy contract | High | Default off, precise payload disclosure, narrow constitution amendment, Keychain, no logs, separate release review. |
| Wrong automatic replacement changes meaning | High | Keep-original default, bounded choices, occurrence binding, confidence validation plus labeled provider calibration; never claim fake corpus proves intelligence. |
| Slow/stale task changes clipboard or a later dictation | High | Deadline, transport cancellation, attempt ID and policy generation guards, one sink path, test late completions. |
| Repeated callbacks expand one controlled call into recurring usage | High | One-shot dispatch guard, no retry even on unknown outcome, synthetic-only payload, runtime remote dispatch remains disabled; no monthly budget implementation. |
| Save silently overwrites legacy glossary or loses examples | High | Separate versioned atomic store, read-back, conflict handling, deletion boundary, preserve editor recovery tests. |

Overall risk: **high**, because remote text boundaries, credential handling and asynchronous insertion converge. No implementation/API call is required to finish this planning phase. Architecture must implement the fixed SPEC contracts above, complete occurrence/store-recovery details, and account for both session and SwiftUI closure ownership; it must not reopen example upload, the 600-character/900 ms limits, whole-input abstention above three occurrences or the absence of recurring/monthly authorization.
