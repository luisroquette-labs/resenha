# Step 05: target broker and mouse observer

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 02, 04, 08
**Parallel with:** 06, 07
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Provide bounded original-target identity that becomes permanently unsafe after an observed change.

Own Resenha.TargetBroker/Program.cs, FocusProbe.cs, Resenha.Platform/TargetBrokerClient.cs, MouseActivityMonitor.cs and target-focused tests. IPC protocol and process containment share ChildProcessJob ownership with step 08 through Contracts.cs; serialize shared implementation edits. New COM/IPC isolation and wrong-field insertion safety require opus.

#### Expected Output

MTA UIA broker using inherited anonymous pipe and passive mouse observer; typed SameTarget/Changed/Unsafe/Unknown responses.

#### Success Criteria

- Snapshot includes HWND/PID/process creation/session/desktop/integrity/UIA runtime ID and available caret identity without collecting field content.
- 300 ms broker timeout kills its job and disables auto-paste for that attempt; password/protected/elevated/unknown fields remain clipboard-only.
- Foreground/field/caret/nonshortcut key/mouse button changes permanently invalidate an attempt even after focus returns; mouse observer loss also fails closed.

#### Subtasks

- [ ] Implement bounded versioned attempt-scoped IPC, MTA FocusProbe and broker job lifetime without network listeners or transcript access.
- [ ] Implement snapshot interval consistency and full identity recheck including HWND/PID reuse, browser field IDs and provider uncertainty.
- [ ] Install passive WH_MOUSE_LL on the shared input thread through its owner API, ignore injected events, observe buttons only and unhook/rearm on suspend/resume/shutdown.
- [ ] Write TargetIdentityTests.cs and broker IPC tests for hanging providers, malformed/oversized responses, stale attempts, same-HWND different fields and observer loss; run Windows tests.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | UIA provider hangs WPF or hook threads | High | High | Isolated MTA broker, 300 ms deadline and killable child job. |
| Risk | Shared Chrome child HWND or return-to-field permits wrong-target paste | High | High | Use UIA runtime/focus generation plus permanent attempt invalidation; unknown identity means manual paste. |
