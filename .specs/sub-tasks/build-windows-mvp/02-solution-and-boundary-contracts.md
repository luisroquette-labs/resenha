# Step 02: solution and boundary contracts

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 1
**Model:** opus
**Agent:** software-architect
**Depends on:** None
**Parallel with:** 01
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Create a buildable pinned native solution with portable contracts and test doubles.

Own Windows/Resenha.Windows.sln, global.json, Directory.Build.props, Directory.Packages.props, NuGet.Config, project csproj files, project lockfiles, toolchain-lock.json, Resenha.Core/Contracts.cs and Resenha.Platform/NativeMethods.cs. Create Core, Platform, WPF, TargetBroker and two MSTest projects. Reserve adapter files for their later owners; keep the first WPF shell inert. The shared AttemptId, cancellation, monotonic clock, typed outcomes and target/clipboard records define cross-module integrity and earn opus.

#### Expected Output

Compilable inert WPF shell, portable net10.0 Core, Windows project graph, exact SDK/test pins and shared contracts.

#### Success Criteria

- Windows/global.json selects SDK 10.0.401 with rollForward disabled and MSTest.Sdk 4.4.0; runtime 10.0.12, x64 and self-contained publication are explicit.
- Core has no Windows/UI dependencies; all asynchronous interfaces carry attempt/cancellation and typed failure results.
- Locked restore and initial compile/test pass on an authorized Windows host; no unknown host/compiler version is fabricated in toolchain-lock.json.

#### Subtasks

- [ ] Create exact solution/project/dependency pins and per-project packages.lock.json, with warnings-as-errors and no trimming/single-file/AOT.
- [ ] Define IShortcutSource, IClock, IAudioRecorder, IModelStore, ITranscriber, ITargetProbe, IClipboard and ITextInjector plus immutable records in Contracts.cs.
- [ ] Create narrow NativeMethods.cs interop declarations and inert App.xaml/App.xaml.cs/TargetBroker entry points; transfer ownership to later steps before their edits.
- [ ] Add contract serialization/ownership and project-boundary tests in Resenha.Core.Tests/ContractTests.cs; run portable checks through mac-gate and Windows compile/tests on Windows.
- [ ] Inventory approved host SDK/compiler/Windows SDK/CMake/PowerShell/Inno versions before any build; if host unavailable leave native validation blocked, never substitute cross-build success.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Pinned Windows toolchain or authorized execution host unavailable | High | High | Stop Windows compile claims; preserve reviewed scaffold and request concrete host/tool installation authority. |
| Risk | Parallel adapters edit shared contracts or NativeMethods.cs inconsistently | High | Medium | Freeze Contracts.cs at phase review; later agents propose changes to the coordinator and serialize shared-file edits. |
