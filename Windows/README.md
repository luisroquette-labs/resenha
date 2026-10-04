# Windows scaffold — Step 02

Development scaffold only. The WPF executable exits without opening UI or
starting a hook, microphone, inference process or clipboard operation. The
broker exits without starting IPC or UI Automation. Managed cross-target checks
have run on macOS, but no native Windows execution or usable release is asserted.

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

The current macOS arm64 host now has .NET SDK 10.0.401. It completed locked
restore, cross-target compilation, 127 Core tests and 67 portable Platform tests
on 2026-10-04.
Those checks prove the managed dependency graph and portable code compile; they
do not prove Win32 execution, WPF, hooks, WASAPI, UI Automation, signing or the
installer. `toolchain-lock.json` therefore leaves the approved native Windows
host inventory null. Required runtime 10.0.12 is pinned in the lock metadata and
release evidence, but deliberately not set as a global MSBuild property because
that collides with the Windows SDK reference pack. NuGet's official MSTest.Sdk
4.4.0 package declares MSTest 4.4.0 and Microsoft.Testing.Platform 2.4.0. The
`None` extension profile avoids optional coverage/reporting packages; it does
not disable test execution.

All six per-project `packages.lock.json` files were generated with SDK 10.0.401,
reviewed and accepted by a subsequent locked restore. The approved Windows host
must reproduce that locked graph; it must not update the locks implicitly.

On the first approved Windows host, inventory the exact Windows SDK, MSVC
compiler/linker, CMake, PowerShell and Inno versions/hashes in
`toolchain-lock.json`. Then rerun locked restore, compile/analyzers, format
verification and both test projects from `Windows/` so `global.json` controls
SDK selection. Preserve actual failures. The runtime and installer OS-floor
checks belong to later steps; this TFM alone cannot establish compatibility.

## Ownership handoff

- Shared contracts, native declarations and project files stay coordinator-owned;
  later steps propose changes before touching these files.
- Step 05 owns the broker entry point after handoff; step 11 owns presentation;
  step 12 owns final `App.xaml.cs` composition.
- Audio/input/model/inference/clipboard adapters, native CMake, release schema,
  installer and release scripts are reserved for their respective later steps.

Official pin sources: [.NET 10](https://dotnet.microsoft.com/en-us/download/dotnet/10.0),
[MSTest.Sdk 4.4.0](https://www.nuget.org/packages/MSTest.Sdk/4.4.0).
