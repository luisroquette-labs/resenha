# Windows scaffold — Step 02

Development scaffold only. The WPF executable exits without opening UI or
starting a hook, microphone, inference process or clipboard operation. The
broker exits without starting IPC or UI Automation. No Windows build or test
has been run and no usable application/release is asserted.

## Boundaries

`Resenha.Core` is portable `net10.0` with framework libraries only. Each async
boundary receives an `AttemptId` and `CancellationToken`, returning typed
outcomes. The coordinator alone allocates dictation attempts and changes state;
raw shortcut edges precede that allocation. Monotonic timestamps use TimeSpan
ticks normalized from one process-local origin. Leases have one observable
disposal task, reject cross-attempt reuse, and never cancel cleanup because a
dictation was cancelled. Concrete adapters remain responsible for holding model
read handles, owned-path enforcement and shutdown acknowledgment.

`Resenha.Core.Tests/TestDoubles.cs` supplies deterministic, side-effect-free
clock, shortcut, audio, model, transcription, target, clipboard and insertion
doubles. Their success does not verify a Windows API or physical device.

## Validation and current blocker

Run structural checks on the Mac from the repository root:

```sh
~/.local/bin/mac-gate node --test Windows/scaffold.test.mjs
```

The current host is macOS arm64 with no `dotnet` or `pwsh` in PATH. SDK
installation and Windows execution are not authorized by this scaffold.
`toolchain-lock.json` deliberately leaves the approved native host inventory
null. Required SDK 10.0.401/runtime 10.0.12 and MSTest.Sdk 4.4.0 are pins, not
observed host versions. NuGet's official MSTest.Sdk 4.4.0 package declares
MSTest 4.4.0 and Microsoft.Testing.Platform 2.4.0. The `None` extension profile
avoids optional coverage/reporting packages; it does not disable test execution.

Only the dependency-free Core lock is represented. Remaining per-project
`packages.lock.json` files must be generated and reviewed using the exact SDK
on the approved Windows host, including implicit Windows SDK reference-pack
and MSTest transitive dependencies. They are intentionally not invented.
`RestoreLockedMode=true` keeps ordinary restore closed until that bootstrap is
complete. The one-time lock generation is not a passing locked-restore gate.

Before the first Windows build, inventory the exact approved Windows SDK,
MSVC compiler/linker, CMake, PowerShell and Inno versions/hashes in
`toolchain-lock.json`. Then generate/review dependency locks, run locked restore,
compile/analyzers, format verification and both test projects from `Windows/`
so `global.json` controls SDK selection. Preserve actual failures. The runtime
and installer OS-floor checks belong to later steps; this TFM alone cannot
establish the stricter product compatibility matrix.

## Ownership handoff

- Shared contracts, native declarations and project files stay coordinator-owned;
  later steps propose changes before touching these files.
- Step 05 owns the broker entry point after handoff; step 11 owns presentation;
  step 12 owns final `App.xaml.cs` composition.
- Audio/input/model/inference/clipboard adapters, native CMake, release schema,
  installer and release scripts are reserved for their respective later steps.

Official pin sources: [.NET 10](https://dotnet.microsoft.com/en-us/download/dotnet/10.0),
[MSTest.Sdk 4.4.0](https://www.nuget.org/packages/MSTest.Sdk/4.4.0).
