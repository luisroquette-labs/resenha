# Step 10: clipboard and single insertion

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 3
**Model:** opus
**Agent:** developer
**Depends on:** 04, 05
**Parallel with:** 09, 11
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Commit exact text before at most one safe insertion, retaining manual recovery.

Own Resenha.Platform/ClipboardService.cs, TextInjector.cs and Platform.Tests/TargetClipboardTests.cs. Clipboard sequence, physical modifiers, target identity and partial SendInput form a critical text-integrity boundary requiring opus.

#### Expected Output

STA Unicode clipboard commit token and fail-closed original-target insertion adapter.

#### Success Criteria

- Five clipboard attempts fit 500 ms; exact readback, nonzero sequence, attempt and digest bind current text; failure retains RAM text with no paste.
- Target/focus/clipboard/desktop/integrity are rechecked immediately before one Ctrl/V batch, after shortcut modifiers release within two seconds.
- Partial SendInput yields ManualPaste; full count only Dispatched; user-held keys are never released and no automatic retry or window activation occurs.

#### Subtasks

- [x] Implement immediate CF_UNICODETEXT rendering/readback and ClipboardToken generation on STA context with bounded contention retries.
- [x] Implement target and sequence recheck, physical modifier wait and single four-event SendInput batch with synthetic-only cleanup.
- [x] Map blocked/elevated/password/protected/unknown targets and changed clipboard to manual/copy recovery; manual Copy again never pastes.
- [x] Write tests for locked/replaced clipboard, failed readback, target changes/return, PID reuse, partial dispatch and cancellation; run Windows boundary tests.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Paste uses a newer user clipboard or wrong browser field | High | High | Check full target and clipboard token immediately before dispatch; permanently invalidate changed target. |
| Risk | SendInput count is mistaken for editor acceptance | High | Medium | Expose Dispatched separately from verified insertion and prove actual target acceptance only in physical QA. |
