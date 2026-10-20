# SPEC-008 — Testing

Status: accepted for M0

## Strategy

Use the smallest checks that prove boundaries. Pure state and path discovery are unit tested. macOS permission, hardware, global input, Whisper runtime, and cross-app insertion are validated locally as integration/manual gates.

## Automated checks

Recording refinement: injected monotonic clock and level samples verify dB normalization, fixed 48-bar history order, bounded attack/decay, silence, timer rollover/reset, stopped-state rejection and stationary Reduce Motion. Forty native-view fixtures cover the state/appearance matrix, including injected speech/silence/decay. They do not prove physical microphone responsiveness or cross-app caret preservation.

Brand resonance uses the existing microphone samples. Unit checks verify bounded HUD scale/halo values and five menu-bar frames; fixtures compare silence, speech, decay and Reduce Motion. A physical spoken check remains required to prove that the logo follows real speech rhythm.

- Pipeline state rejects overlapping presses and invalid releases.
- Model path resolution, download size/hash validation and embedded context reuse are deterministic.
- Transcript normalization trims whitespace and rejects non-speech-only output.
- Every completed transcript is staged on the clipboard; target identity and exact shortcut matching are deterministic.

All local test/build commands run through `~/.local/bin/mac-gate` and use `-derivedDataPath build`, so tests and manual launch share one signed app bundle.

Interface checks cover current-generation/deadline dismissal, obsolete callbacks, repeated hotkey-start failure feedback, menu/request/self-target guards with unconditional recording release, partial permission changes, Settings failure guidance, safe errors, negative display coordinates/fallback/disconnection, panel layout and accessible copy. These deterministic checks do not prove hardware/TCC/caret behavior.

The NSHostingView fixture test renders six states across four configurations (24 PNGs in `build/ui-fixtures`). Overrides reproduce appearance values without changing system settings. Images are fixtures, not actual dictation screenshots; progress stills do not prove movement. Idle is verified as absence, not a seventh HUD image.

## Local integration gates

1. Build the `.app` bundle and launch it via LaunchServices.
2. Confirm the process remains alive and the menu bar item appears.
3. Grant Microphone, Input Monitoring and Accessibility through explicit setup when needed.
4. Record the desired shortcut inside Resenha and run a real Portuguese dictation into TextEdit.
5. Repeat in a Chromium text field and verify the transcript remains on the clipboard.

## CORE-001 evidence

Record date, commit (or source/binary fingerprints when HEAD does not exist), macOS version, chip, Whisper version/model, target app, spoken phrase, actual inserted text, release-to-insertion time, clipboard restoration, cleanup and pass/fail in `docs/testing/M0-EVIDENCE.md`.

Record native focus/click-through, ready-to-recording overlap, menu-open active release, permission request/recovery, keyboard/VoiceOver, long errors, display/Spaces/full-screen and supported appearance observations in `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Use PASS/FAIL/NOT RUN and identify evidence type. Connected screens alone do not establish display behavior; a CUA timeout is a tool limitation, not an app pass or defect.

Reuse an exact unchanged passing gate for prose-only changes. Code changes require the canonical mac-gate command. Quit the exact stable instance before testing if LaunchServices prevents test-runner launch; never create a second Derived Data identity to bypass it.

## Local transcription feedback — reproducible physical script

Use the task candidate by explicit path, recording HEAD plus product diff fingerprint, executable **and implementation dylib** hashes, macOS/chip, process path/PID, local model and native gate result. Quit only Resenha gracefully before switching bundles, preserve the installed app/signature/TCC, then reopen that exact installed bundle after testing. Do not close Chrome, Terminal or personal documents. Confirm `Microfone (MacBook Pro)` is the selected input before and after; distinguish a synthesized `say` signal captured through this microphone from human speech.

Use a new disposable TextEdit document and a dedicated local browser text field. Preserve existing glossary/history and settings; never clear personal data to manufacture a result. Record each case as action → expected → observed → PASS/FAIL/NOT RUN, with the evidence type and CK. Stop if concurrent user dictation changes the target/session: a transcript, clipboard snapshot or focus assertion can no longer be attributed reliably to this script. Unit tests and visible AX labels are not proof of VoiceOver speech.

| Case / CK | Bounded action | Expected observation and proof |
|---|---|---|
| F1 · CK-1/10/11 | Focus disposable TextEdit; hold configured key, speak “A Coisa Energia chegou para o teste local.”, release. Ignore the offer for four seconds; repeat and open correction before the deadline, leaving it open longer than four seconds. Repeat with Reduce Motion. | Processing transitions to two icons in the same 280 × 64 frame/position. The passive offer expires after approximately four seconds; editor/draft/error remain until explicit action. Reduce Motion removes transition, preserves deadline. TextEdit remains target and clipboard matches insertion. Empty/error offer nothing. |
| F2 · CK-2/7/9 | Starting in TextEdit, use Control-F8 (Fn-Control-F8 if required), navigate to Resenha status menu, select “Transcrição correta” with Return. Compare glossary snapshot. | Entire entry path works without mouse; like dismisses and does not change glossary or create a rating. A new dictation still inserts in TextEdit. |
| F3 · CK-3/4/7/9 | Open “Corrigir transcrição” from status menu. Tab through controls. Enter a disposable source, leave target empty, press Return; then Escape. Repeat Cancelar and window close. | Exactly two named fields, initial source focus and usable Tab order. Error is textual and spoken by VoiceOver; draft remains on invalid Return. Cancel/close/Escape retire normal draft without writing and return focus conditionally. |
| F4 · CK-3/5/6/8 | If `Coisa Energia` is absent and no conflict exists, enter `Coisa Energia` / `COESA Energia`, Save by Return. Reopen candidate; inspect the rule; dictate the same phrase. | “Regra salva” is visible/spoken; existing entries remain, only confirmed pair persists; next output uses `COESA Energia`. Prior text and clipboard are unchanged by Save. If real state conflicts, use an isolated environment or mark this exact case NOT RUN; do not overwrite it. |
| F5 · CK-7/10 | Ignore offer and dictate again; open editor and press/hold hotkey, release, press anew. Then switch from editor to another disposable app and dictate. | Ignored offer retires on next press. Editor-focused first press cancels without recording; new external press records. Switching apps preserves the new target; stale timers/menu actions cannot affect it. Token rejection itself is additionally deterministic XCTest evidence. |
| F6 · CK-7/10 | Open editor, terminate only a disposable destination, then cancel. Trigger normal permission refresh without revocation. | No destination relaunch/late insertion, manual-return guidance on unavailable target; routine refresh preserves active draft. Do not terminate a personal app to run this case. |
| F7 · CK-1/7/8/10 | Repeat F1–F5 with history off; separately disable HUD while offer/editor exists, try old menu, then dictate; restore original preferences. | History off still permits feedback without adding history. HUD off closes editor/removes menu actions and permits dictation without hidden feedback. Existing history remains untouched. |
| F8 · CK-8/9 | With model already local, observe process network connections over like/dislike/cancel/Save and repeat offline without modifying global networking. Enable VoiceOver, navigate F2–F4, then restore its original state. | No new network transmission during all four actions; identify observer/window/limits. VoiceOver actually speaks names, errors and success, with predictable focus. Source review or a one-time socket listing alone does not establish either pass. |

Limits, parser boundaries, duplicate/conflict behavior and rollback are covered by `testCorrectionCandidate*`, `testCorrectionSave*`, `testCorrectionRollbackFailureBlocksDirectSaveUntilVerifiedReloadWithoutWrites` and `testRollbackRecoveryCancelReloadAndRetiredTokens`. The rollback test proves the exceptional Save-block/cancel/reload contract; do not manufacture a real storage failure or call it physically observed. Lifecycle/menu/hotkey coverage is in `testFeedback*` and `testRecoveryDraftIsErasedOnNewDictationHUDOffAndTermination`.

`testFeedbackDeadlineExpiresOnlyCurrentPassiveOfferWithoutWrites` verifies the injected-clock deadline, just-before/exact-limit behavior, processing-frame continuity, menu/token clearing and unchanged defaults. `testFeedbackTimerCannotReachReplacementEditorRecordingNoticeOrHiddenHUD` verifies A→B, A→editor including invalid draft/error, A→recording/notice and hide cancellation. Feedback fixtures are 280 × 64 in light/dark, increased contrast, reduced transparency and Reduce Motion; inspect icon size, hit targets and clipping. Fixtures and source labels do not establish actual VoiceOver speech or live focus continuity.

After the final candidate passes the canonical gate and Phase 3 review, archive the previous `/Applications/Resenha.app` recoverably, install the signed candidate preserving bundle identity/designated requirement, and record final SHA, executable/dylib hashes, version and running installed process. Run the physical script against that exact installed binary; do not substitute a prior gate, an older installed app or an unreviewed worktree for this proof.

Canonical gate remains `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Fixtures are generated under the test process's temporary `ResenhaTests/ui-fixtures`; record their actual path/date, not an older sandbox directory. Reuse a passing unchanged candidate for documentation-only edits. Run `Scripts/site.test.mjs` only when covered site/scripts change. Current observed results and concrete pending cases belong in [UI-REFINEMENT-EVIDENCE](../testing/UI-REFINEMENT-EVIDENCE.md), not in an all-pass declaration here.

## Exit criteria

No known deterministic test failure; `.app` launches locally; `CORE-001` passes in TextEdit. Browser compatibility may remain a separately recorded M0 limitation only if TextEdit passes.
