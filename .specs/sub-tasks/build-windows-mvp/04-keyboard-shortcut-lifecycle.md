# Step 04: keyboard shortcut lifecycle

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 02
**Parallel with:** 06, 07, 08
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Implement reliable configurable push-to-talk input without blocking Windows hook callbacks.

Own Resenha.Core/ShortcutPolicy.cs, Resenha.Platform/KeyboardHook.cs and Resenha.Core.Tests/ShortcutTests.cs. New low-level input concurrency and key ownership require opus. NativeMethods additions are routed serially through the phase integration owner. Emit edges only; adapters do not capture audio.

#### Expected Output

Dedicated input message loop, bounded keyboard callback, exact chord validation, rearm/watchdog and interruption events.

#### Success Criteria

- Default Left Ctrl + Left Alt + Space works; Right Alt/AltGr, modifier-only, Win/F12/reserved and observed occupied chords are rejected.
- Auto-repeat/injected events do not start work; release of any required key stops once and all keys must be up to rearm.
- 100 ms watchdog, suspend/lock/resume, extra modifiers and lost release cancel safely; unrelated input passes through.

#### Subtasks

- [x] Implement physical scan-code/exact left-right modifier ShortcutPolicy and brief RegisterHotKey conflict probe.
- [x] Implement WH_KEYBOARD_LL lifecycle on dedicated thread; bound callbacks and suppress only the accepted latched trigger down/up, including busy rejection.
- [x] Implement interruption/watchdog and cancellation-only Escape events during an active attempt, with no permanent Escape hotkey.
- [x] Write fake-clock/key tests for repetition, busy presses, late release, AltGr/ABNT2, callback ordering and shutdown; run portable tests via mac-gate.
- [ ] Run hook integration on an authorized physical Windows host.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Lost hook release leaves capture latched | High | Medium | Independent physical-key watchdog and all-keys-up rearm; installation failure disables dictation. |
| Risk | AltGr or synthetic cleanup alters user-held modifiers | High | Medium | Track left/right physical state and never synthesize releases of physically held keys. |
