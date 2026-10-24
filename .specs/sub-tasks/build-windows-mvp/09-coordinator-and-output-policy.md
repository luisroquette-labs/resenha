# Step 09: coordinator and output policy

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 3
**Model:** opus
**Agent:** developer
**Depends on:** 04, 06, 07, 08
**Parallel with:** 10, 11
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Own the complete serialized dictation lifecycle and reject stale asynchronous work.

Own Resenha.Core/DictationCoordinator.cs, OutputPolicy.cs and Core.Tests/CoordinatorTests.cs/OutputTests.cs. Integrate frozen boundary interfaces with fake adapters first; real composition belongs to step 12. Multi-boundary cancellation/generation ordering and output integrity earn opus.

#### Expected Output

Finite Idle/Recording/Transcribing/Inserting/Failed coordinator and deterministic cleanup/text policy.

#### Success Criteria

- One current attempt owns capture/model/job/target; no queued recording, obsolete completion, duplicate inference or duplicate insertion survives state changes.
- Release during asynchronous start cancels late capture; cancel/lock/suspend/error invalidates generation before cleanup and requires acknowledgment before idle.
- Clipboard commits before one insertion; copy retry only copies retained RAM text; silence changes neither clipboard nor target; deterministic output preserves existing corpus.

#### Subtasks

- [x] Implement serialized transitions, monotonic deadlines and attempt generations for all architecture limits; visible busy/cancel/recovery states.
- [x] Implement acknowledged resource disposal, no auto-retry and explicit fatal audio-stop outcome consumed by the shell.
- [x] Implement OutputPolicy using read-only Tests/Fixtures/output-corpus.json; no generative rewrite/translation/history.
- [x] Write race/fake-clock/state-table tests including stale callback deleting a newer attempt, release during start, double release, cancel during clipboard and all named errors; run Core checks through mac-gate.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Stale async completion copies text or disposes a newer attempt | High | High | Check generation before every externally visible side effect; scope all leases by AttemptId. |
| Risk | Cleanup failure is relabeled ready | High | Medium | Await explicit cleanup acknowledgments and expose blocked/fatal recovery rather than allowing another recorder. |
