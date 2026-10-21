# Definition of Done verification — transcription feedback

Date: 2026-10-21 10:04 BRT
Source identity: `0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377` plus Sources/Config/project diff `b88ef1723ae82bdc684efabbe2e83d52ff3367a539b1affff9d0f58fe1f7a16c`
Installed Release: `1.0.0 (2026102102)`

## Result

Definition of Done: **4/7 PASS (57%); 3/7 BLOCKED.** Keep the task in `in-progress`.

| Criterion | Status | Evidence / issue |
|---|---|---|
| CK-1 | BLOCKED physically | XCTest/fixtures cover geometry and actions, and the earlier installed Debug visually showed halo/bubbles. The current Release cannot dictate because TCC permissions are pending; no Release observation is inferred. |
| CK-2 | PASS | Like and expiry use non-writing terminal paths; preference snapshots remain unchanged. |
| CK-3 | PASS | Exactly two fields remain; only explicit valid Save persists vocabulary. |
| CK-4 | PASS | Early draft and save validation cover empty/invalid/equal/over-limit input without truncation or partial write. |
| CK-5 | PASS | Feedback stores only the canonical term, preserves existing bytes, deduplicates and reconstructs isolated preferences without storing the heard form. |
| CK-6 | PASS | `testFeedbackHostelStoresOnlyVocabularyAndNeverReplacesRosto` proves prompt contains `Hostel`, storage omits `rosto`, and `Meu rosto está vermelho` remains unchanged. |
| CK-7 | PASS | Tests cover cancel, expiry, replacement, new attempt, HUD off, termination and stale token/timer isolation. |
| CK-8 | BLOCKED physically | Static diff/tests show no new endpoint, analytics, login, provider or persisted heard phrase. The full Release feedback sequence was not observable, so no live network claim is made. |
| CK-9 | BLOCKED | Labels/hints/keyboard contracts and appearance fixtures pass. VoiceOver, native focus traversal and OS Reduce Motion were not observed in the Release. |
| CK-10 | BLOCKED | Regression suite is green, but Release dictation, insertion, clipboard/history and following attempt were not physically exercised due missing permissions. |
| CK-11 | BLOCKED physically | Monotonic four-second expiry and stale-timer guards pass deterministically; live Release timeout/editor survival was not observed. |
| CK-12 | BLOCKED | Finite animation, monotonic lifecycle and a short idle CPU sample are evidenced. Physical click pass-through outside the two `44×44` targets was not run. |
| CK-13 | PASS | Bounded drafts and deinit probes prove token/PID-only context and release of heard/canonical/app/closures across terminal paths. |
| CK-14 | PASS | Fresh real-whisper integration proves preemptive cancel/deadline abort, same-engine recovery and four WAVs removed once; full 97-test gate includes it. |
| CK-15 | PASS (criterion) | Installed product is Release, Developer ID/Hardened Runtime, empty entitlements, no XCTest/debug/test artifacts, verified hashes/PID, recoverable backup and fixture rollback proof. Source is attributable to base commit plus sealed diff hash. |

## Definition of Done items

| Item | Status | Evidence / blocker |
|---|---|---|
| CK-1–CK-15 fully demonstrated; no unsafe replacement/persistence/network/hidden work | BLOCKED | Release physical CK-1/8/9/10/11/12 cases remain unexecuted; pass-through is specifically unproved. |
| `rosto` → `Hostel` persists only `Hostel` and preserves common `rosto`, prior entries and inserted text | PASS | Isolated storage/postprocessor test verifies exact persisted text, prompt, negative replacement and unchanged unrelated preferences. |
| Preemptive cancellation/timeout and single WAV ownership without blocking the next attempt | PASS | `testRealWhisperCancellationAndDeadlineAbortThenRecoverOnSameEngine` passes against local whisper.cpp; cancel and deadline callbacks abort C inference, next attempts run on the same engine, and four temporary WAVs are removed exactly once. |
| Applicable Phase 5 gates green through `mac-gate` | PASS | Exact current source/test fingerprint passed **97/97**, 0 failed, 0 skipped: `build/Logs/Test/Test-WhisperKey-2026.10.21_09-56-43--0300.xcresult`. |
| Commit-dated physical evidence covers dictation, focus, keyboard and VoiceOver | BLOCKED | Release shows `Resenha — Permissões necessárias`; microphone/input-monitoring/accessibility were not granted or reset. VoiceOver and dictation were not run. |
| Installed Release corresponds to final SHA, rejects test artifacts/entitlements and has verified backup | BLOCKED | Structural Release/install/backup validation passes, but the installed bundle represents HEAD `0cf73d5` plus sealed uncommitted diff `b88ef172`, not one final committed SHA. Rebuild/install after commit is required for the literal final-SHA clause. |
| Specs/tests/privacy docs reflect term-only learning, finite lifecycle, real cancellation and Release installation; no paid API/analytics/service | PASS | Current diff and docs cover the new contracts; searches found no new provider/network/analytics surface or dependency/config change. `git diff --check` is clean. |

## Verified artifacts

- Native result: 97 passed, 0 failed, 0 skipped on macOS 26.1 arm64.
- Installed executable: `/Applications/Resenha.app/Contents/MacOS/Resenha`, PID `51151`, SHA-256 `9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15`.
- Installed bundle passes `codesign --verify --deep --strict`; entitlements dictionary is empty and no forbidden test/debug files were found.
- Build provenance plist records `Configuration=Release`, base Git revision and `SourceDiffSHA256=b88ef172…`.
- Recoverable previous Release: `/Applications/Resenha-backups/Resenha-20261021T125818Z-0cf73d5834c8.wK40De9o/previous-Resenha.app`.
- Current default input is AirPods, not `Microfone (MacBook Pro)`; no input setting was changed during verification.

## Smallest actions to close the blockers

1. Commit the frozen Phase 5 diff, rebuild/install Release from that exact commit and record matching provenance.
2. Manually grant the three macOS permissions to that Release.
3. Run the bounded physical script once: dictation/insertion, click inside/outside targets, four-second expiry/editor survival, keyboard/VoiceOver/Reduce Motion, clipboard/history and process network observation.
