# Definition of Done verification — transcription feedback

Date: 2026-10-20 15:17 BRT
PR head: `c0b60364ad4196430a19631ed16bb4ff781ebbb9`
Installed product revision: `68ddb7c1c89c71d8f4eded078d94c5967749cb21`

## Result

Task-level DoD: **3/5 passed; 2/5 blocked by missing controlled physical evidence.** The task must remain in `in-progress`.

| Criterion | Status | Evidence |
|---|---|---|
| CK-1 | PASS (deterministic/visual) | Production controller offers feedback only after current successful insertion. Tests and five appearance fixtures prove the processing-to-feedback surface remains `280 × 64`, contains only the two compact controls and excludes failure/empty/stale paths. Live continuity on the installed revision was not observed. |
| CK-2 | PASS | Approval and timeout use the non-writing dismissal path; isolated defaults remain unchanged in lifecycle and deadline tests. |
| CK-3 | PASS | The correction window exposes exactly `Saiu como` and `Correto é`; tests prove dislike/edit do not write and only valid explicit Save mutates the glossary. |
| CK-4 | PASS | XCTest covers trim/empty, line separators, delimiter, identical terms, exact line/term/text/prompt boundaries, preserved draft and no partial success. |
| CK-5 | PASS (deterministic) | Isolated defaults prove preservation, relaunch-equivalent reconstruction, idempotence, explicit conflict rejection and rollback/recovery. Physical Save/relaunch remains unobserved. |
| CK-6 | PASS (deterministic) | Reconstructed preferences and the real postprocessor prove `Coisa Energia` → `COESA Energia`, whole-term boundaries and no path that rewrites already inserted text. |
| CK-7 | PASS | Lifecycle tests cover cancel, expiry, replacement offer, new dictation, HUD off, termination, repeated actions, retired tokens, stale menu actions and stale timers. |
| CK-8 | BLOCKED | Diff review finds no feedback network destination, analytics, login, dependency, API or persistence key; storage tests show only the confirmed glossary changes. The live network window did not cover like/dislike/cancel/Save or an offline repeat. |
| CK-9 | BLOCKED | Labels, hints, keyboard shortcuts, focus state, Reduce Motion and appearance fixtures are covered. Actual VoiceOver speech, OS Reduce Motion behavior and continuous keyboard/focus traversal were not observed on the installed revision. |
| CK-10 | BLOCKED | The exact reviewed bundle is installed, signed and running; regression tests cover clipboard/history/lifecycle. A controlled installed-revision dictation, next output, continuous caret/clipboard/focus and history/HUD-off run was not completed. |
| CK-11 | BLOCKED (physical only) | Injected-clock tests prove deadline `now + 4`, exact-boundary expiry, editor cancellation and stale-timer isolation. The approximately-four-second live disappearance and editor survival were not observed because TextEdit did not retain focus and the diagnostic stopped before dictation. |

## Definition of Done

| Item | Status | Evidence / gap |
|---|---|---|
| CK-1–CK-11 demonstrated; only confirmed rule persists; no additional send | BLOCKED | CK-8–CK-11 retain the physical gaps above. Deterministic and fixture evidence is not promoted to physical proof. |
| `Coisa Energia` → `COESA Energia`, persisted and applied next, preserving prior entries/already inserted text | PASS | Isolated persistence reconstruction plus real postprocessor test; prior settings remain unchanged except the glossary key. |
| Applicable local gates green after compact/timed refinement | PASS | Exact committed revision `68ddb7c` passed 82 tests, 0 failed, 0 skipped via `mac-gate`; result `build/Logs/Test/Test-WhisperKey-2026.10.20_14-45-14--0300.xcresult`. PR head only adds documentation. |
| Commit-dated physical evidence covers dictation, focus, keyboard and VoiceOver | BLOCKED | Installed revision is commit-dated, but the final attempt stopped before synthetic key/TTS because TextEdit did not stay frontmost. VoiceOver remained off; HUD continuity/timeout, editor, insertion, focus and clipboard were not observed. |
| Specs, tests and privacy documentation match compact/timed final flow; limited diff without paid API/analytics/service | PASS | Phase 3 review scored 4.53. Diff is limited to existing controller/view/test/spec surfaces with no dependency or project configuration change. PR #14 head is clean and all four CodeQL checks succeeded. |

## Installed and remote evidence

- `/Applications/Resenha.app` executable SHA-256: `c5a4af326d644d2afc7b5d13faa5000004185a9e881ce34b3c80cc164676339a`.
- Installed implementation dylib SHA-256: `ac41b4528cc71d15cb0305eb6602f4e914430909c4cad5e3196ece1986acf99e`.
- Strict deep signature verification passes; designated requirement preserves `br.com.luisroquette.Resenha` and the existing Apple Development identity.
- Installed process remains `/Applications/Resenha.app/Contents/MacOS/Resenha`, PID `96641`; default input remains `Microfone (MacBook Pro)`.
- Recoverable prior bundle: `build/install-backups/20261020-68ddb7c/Resenha.app`, executable SHA-256 `2aae6550bbe8a309c8dc0ff5feb4c20212a2aaf9890563f65958b2ded70a695e`.
- PR #14 head `c0b6036` is `CLEAN`; CodeQL `actions`, `javascript-typescript`, `swift` and aggregate `CodeQL` checks are `SUCCESS`.

## Smallest action to close the blockers

Run the bounded SPEC-008 physical cases on the installed `68ddb7c` bundle during an exclusive two-minute desktop window: observe the live `280 × 64` transition and four-second expiry, open the editor before expiry, complete keyboard/VoiceOver/Reduce Motion checks, then perform one Save/relaunch/next-dictation cycle while recording clipboard/focus and process network activity. Re-run this DoD verification afterward.
