# Definition of Done verification — transcription feedback

Date: 2026-10-20 12:01 BRT  
Verified revision: `a8dd373` (`feat/transcription-feedback`)  
Candidate: `build/Build/Products/Debug/Resenha.app`

## Result

Task-level DoD: **3/5 passed; 2/5 blocked by missing controlled physical evidence.** The task must remain in `in-progress`.

| Criterion | Status | Evidence |
|---|---|---|
| CK-1 | PASS | Physical candidate inserted a local synthesized phrase and exposed the real two-action offer; deterministic tests reject stale, cancelled, empty/error and HUD-off completion paths. |
| CK-2 | PASS | `testFeedbackLikeCancelAndOldTimersNeverWriteOrReachNewSession` proves approval closes without glossary/defaults mutation; the user reports exercising the thumbs flow. |
| CK-3 | PASS | Native view exposes exactly `Saiu como` and `Correto é`; tests prove dislike/edit do not write and valid explicit Save is the mutation point. |
| CK-4 | PASS | XCTest covers trim/empty, all specified line separators, `=`, identical terms, exact line/term/text/prompt boundaries, preserved draft and no partial success. |
| CK-5 | PASS (deterministic) | Isolated defaults prove prior-entry preservation, reconstruction after relaunch-equivalent reinstantiation, idempotence, explicit conflict rejection and rollback/recovery. Physical Save/relaunch remains unobserved. |
| CK-6 | PASS (deterministic) | `testCorrectionSavePersistsCurrentSettingsAndOnlyGlossaryChanges` reconstructs preferences and proves `A Coisa Energia chegou. Coisa Energias ficou.` → `A COESA Energia chegou. Coisa Energias ficou.`; save code has no path to already inserted text. |
| CK-7 | PASS | Lifecycle tests cover cancel/close, ignored offer, new dictation, HUD off, termination, repeated Save, retired tokens, old menu actions and stale timers. |
| CK-8 | BLOCKED | Diff adds no network destination, analytics, login, dependency, API or persistence key; isolated storage tests show only the confirmed glossary changes. Bounded live network observation across like/dislike/cancel/Save and offline repeat was not run. |
| CK-9 | BLOCKED | AX labels, keyboard shortcuts, focus state, appearances, Reduce Motion and fixtures are tested. Actual VoiceOver speech and continuous keyboard/focus traversal were not observed physically. |
| CK-10 | BLOCKED | Physical insertion and restoration of the installed app passed; 80-test gate covers clipboard/history and lifecycle regressions. A controlled next dictation, continuous clipboard/caret/focus, editor hotkey/Alt-Tab and history/HUD-off physical run is missing. |

## Definition of Done

| Item | Status | Evidence / gap |
|---|---|---|
| CK-1–CK-10 demonstrated; only confirmed rule persists; no additional send | BLOCKED | CK-8–CK-10 still require the controlled physical observations above. |
| `Coisa Energia` → `COESA Energia`, persisted and applied next, preserving prior entries/already inserted text | PASS | Isolated persistence reconstruction plus real postprocessor test; prior settings unchanged except the glossary key. |
| Applicable local gates green via mac-gate | PASS | Fresh canonical run: 80 passed, 0 failed, 0 skipped. Result bundle: `build/Logs/Test/Test-WhisperKey-2026.10.20_12-00-17--0300.xcresult`. Initial run failed before tests because installed Resenha PID 51337 occupied the singleton; it was gracefully quit, the same gate passed, and `/Applications/Resenha.app` was reopened as PID 65201. |
| Commit-dated physical evidence covers dictation, focus, keyboard and VoiceOver | BLOCKED | Existing evidence identifies an earlier committed base plus diff hash, not final commit `a8dd373`; VoiceOver, full keyboard/focus and next-dictation cases are explicitly `NOT RUN`. |
| Specs, tests and privacy documentation match final flow; limited diff without paid API/analytics/service | PASS | Four specs/evidence docs updated; source/test diff uses existing native components and settings key. No dependency, project configuration, site/script, network destination, analytics, login or service was added. `git diff --check` is clean. |

## Gate and scope notes

- Canonical gate command: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`.
- `Scripts/site.test.mjs` was correctly not run: the diff does not touch site or scripts covered by that conditional check.
- Fixtures and XCTest are counted only as deterministic/visual evidence, never as physical VoiceOver or focus proof.
- The user's report that thumbs and correct/incorrect worked supports the basic flow, but does not prove Save/relaunch, network silence, clipboard/focus continuity or spoken VoiceOver output.

## Smallest action to close the blockers

Run SPEC-008 cases F2–F8 once on the exact committed candidate `a8dd373`, recording: glossary before/after, Save then relaunch and next dictation, keyboard/Return/Escape/focus/clipboard continuity, actual VoiceOver speech, and a bounded network/offline observation. Append the commit and observed results to `docs/testing/UI-REFINEMENT-EVIDENCE.md`; then re-run this DoD verification.

## Follow-up — 12:02–12:07 BRT

The exact `a8dd373` candidate was run and its executable/implementation hashes recorded in `docs/testing/UI-REFINEMENT-EVIDENCE.md`. User supplied literal manual outputs `A COIS Energia chegou para o teste local.` followed by `A COESA Energia chegou para o teste local.`. This adds real user evidence of a canonical following output, but no independently observed Save/persistence/relaunch link. The agent did not create an extra alias for `COIS`.

Read-only glossary metadata found the stored key absent before and after; the 15-line effective default glossary had no exact pair or conflict. A 90-sample PID-only nettop window produced no connection records, but did not cover the four feedback actions or an offline repeat. Clipboard item/types were preserved in memory and restored in finally. A frontmost change to Chrome during the nominal TextEdit window prevented controlled attribution; testing stopped as instructed. Original installed app/hash, enabled permissions and built-in input were restored, final PID 71768.

The follow-up does not close CK-8–CK-10: actual VoiceOver/keyboard traversal, controlled Save/relaunch/next-output causality, continuous caret/clipboard and network/offline action coverage remain pending. Task-level DoD remains **3/5**, with the evidence limitation unchanged. No product code or checks were modified; documentation diff check passed.

## PR follow-up — 12:22–12:27 BRT

Current PR revision `217379848f127b82b7451efde6793aaf894a8e97` and its rebuilt executable were fingerprinted; implementation dylib matches `a8dd373`. Latest gate `Test-WhisperKey-2026.10.20_12-10-25--0300.xcresult` remains 80/80. A focus guard aborted before dictation on seeing Terminal after TextEdit had been confirmed; executor/session activation is an unresolved alternative to user interference.

The permitted single continuous diagnostic run then failed in its final process check and did not deliver its accumulated event report. No intended physical case from that run is credited. Clipboard restoration preceded the failing check; candidate/VoiceOver were absent afterward. The installed app was explicitly reopened as PID21875 with its original hash, enabled permissions/model readiness and built-in default input. Glossary key remained absent; no Save was confirmed. Detailed provenance/limitations are in the dated UI evidence. CK-8–CK-10 and DoD **3/5** remain unchanged; no product code or gate was weakened.

The one diagnostic-only retry aborted before any UI/app/clipboard mutation on a null clipboard-items collection (`NSNull count`). It produced no functional event log and earns no case coverage. Original PID21875, built-in default input and VoiceOver absent were verified afterward; no further variation was attempted. Physical DoD blockers remain unchanged.
