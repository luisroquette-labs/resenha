# Step 12: runtime composition and native preflight

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 3
**Model:** opus
**Agent:** developer
**Depends on:** 05, 06, 07, 08, 09, 10, 11
**Parallel with:** None
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Wire one operable native app and an honest Windows source gate.

Own Resenha.Platform/PlatformReadiness.cs, final App.xaml.cs composition and Scripts/windows/preflight.ps1. Integrate hooks, broker, recorder, model, inference, clipboard and UI without changing contracts silently. Cross-module lifecycle and privacy review require opus.

#### Expected Output

End-to-end development app plus serialized Windows compile/static/unit/integration gate.

#### Success Criteria

- OS/build/x64/CPU/RAM/disk/Media Foundation/model/hook readiness prevents unsupported inference or capture.
- Per-user single-instance mutex avoids duplicate hooks; secondary launch requests settings only when idle; suspend/exit closes every resource and child.
- preflight.ps1 uses Windows/global.json by Push-Location to Windows, exact tool checks, locked restore, warnings-as-errors, format/MSTest and real CLI corpus; missing/skipped requirements fail.

#### Subtasks

- [x] Compose real adapters and ProductViewModel; implement readiness, single-instance local IPC, startup cleanup and suspend/resume/shutdown ownership.
- [x] Implement fail-closed audio-stop fatal behavior and safe settings/cancel/copy dispatch without permanent extra keyboard shortcuts.
- [x] Implement preflight.ps1 with root/path resolution before Push-Location, finally Pop-Location, host mutex, bounded native workers and propagated failures.
- [ ] Write end-to-end lifecycle/privacy regression tests and preflight failure tests for wrong SDK/cwd/missing CLI/model/skipped tests; execute full Windows source gate and record actual output.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Windows host/toolchain remains unavailable | High | High | Do not claim integrated runtime validation; leave development evidence pending and publication disabled. |
| Risk | Independent adapters each advance lifecycle or start work | High | Medium | Only coordinator owns transitions; integration tests assert one recorder/job and no stale side effects. |
