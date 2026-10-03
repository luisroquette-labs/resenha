# 01 — Lifecycle and presentation contracts

**Task File:** `.specs/tasks/in-progress/refine-macos-interface.feature.md`
**Phase:** 1
**Model:** opus
**Agent:** developer
**Depends on:** None
**Parallel with:** 02
**Note:** Shared contract change earns opus. Own `Sources/WhisperKey/FloatingPanel.swift`, `DictationCoordinator.swift` and `WhisperKeyApp.swift` in this phase. In `Tests/WhisperKeyTests/WhisperKeyTests.swift`, insert lifecycle tests immediately before `testDictationStateMachineRejectsOverlap`; Step 02 owns the permission-test region. No whole-file formatting. Use the task's current location if it has moved from draft.
**Goal:** Keep the existing app runnable while making the coordinator the activity owner and the panel the only transient-dismissal owner.

Read the task's Architecture C1/C3/C4/C6 and all callers of `show`, `showTemporarily`, `hide`, `fail`, `reset`, `hotkeyPressed` and `hotkeyReleased`. Implement settled contracts with minimal internal state, preserving appearance for now. Expose a main-actor phase callback/read-only phase and memory-only current safe error presentation for the menu; no second pipeline state machine. Define the internal handoff used by later steps: panel session-versus-standalone target identity, current concise title/safe diagnostic fields, phase observation and recording-only permission-loss entry point. Wire all existing callers so these contracts do not leave placeholders or broken builds. Target geometry is implemented in Step 03; current screen fallback remains runnable meanwhile.

#### Expected Output

Existing app UI runs with stale-dismissal protection and phase observation. Failure returns to idle only through the current panel dismissal callback. AppDelegate does not replace an active HUD with ready/check feedback. Shared field/method names and semantics are reported to Steps 03/04 through their task context.

#### Success Criteria

- `FloatingPanelController` invalidates a generation and cancels pending dismissal on every show/hide; controlled-time checks prove canceled or obsolete completions cannot hide a newer status or invoke its callback.
- `DictationCoordinator` no longer owns a separate failure timer; success/cancel still clean up, and failure completion does not reset a newer session.
- `AppDelegate` gates unsolicited ready/check feedback on idle, exposes phase changes consistently, and preserves active hotkey release delivery.
- Safe error fields are memory-only, exclude raw stderr/transcripts, and clear on new attempt/resolution; existing code compiles with the contract.

#### Subtasks

1. Trace callers and implement panel generation/deadline/completion ownership in `FloatingPanel.swift`; use a pure internal decision seam for time advancement rather than a scheduler framework.
2. Update `DictationCoordinator.swift` phase publication, failure/reset ownership, safe error representation and recording-only permission-loss cleanup; preserve the detached worker and existing capture/transcribe/insertion algorithms.
3. Update `WhisperKeyApp.swift` to obey coordinator activity when showing status and to call the bounded permission-loss path only while recording; prepare the explicit menu/request start guard while always forwarding an active release.
4. Add focused XCTest regressions before `testDictationStateMachineRejectsOverlap`: old ready/failure dismissal after listening starts, repeated hide/show, callback once, failed-to-idle, and recording cleanup versus processing preservation. Test the actual introduced decisions, not copied logic.
5. After Step 02 finishes writing, run the integrated gate `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; launch `open build/Build/Products/Debug/WhisperKey.app` and supply the phase reviewer the exact revision/diff, results and existing-UI smoke observation.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
|---|---|---|---|---|
| Risk | Stale callback resets a live recording or hides processing | High | Medium | Generation/cancellation guard plus deterministic ordering regression; one dismissal owner |
| Risk | Permission appearance update resets a detached processing task that later inserts | High | Medium | Restrict new cleanup to recording; processing retains real phase and existing completion behavior |
| Blocker | Concurrent test-file edits or build during edits | Medium | Medium | Separate method anchors, narrow patches; wait for both writes before one integrated mac-gate run |
| Blocker | Existing automated baseline fails | High | Low | Record baseline failure, fix in-scope root cause or report unrelated blocker; no bypass or unsupported pass |
