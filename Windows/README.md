# Resenha para Windows — estado de desenvolvimento

O aplicativo WPF compõe atalho, WASAPI, whisper.cpp local, clipboard, inserção,
tray, HUD e ajustes. A versão 0.2.0 acrescenta revisão contextual final opcional
por JEV: vocabulário pessoal, chave BYOK protegida pelo Gerenciador de
Credenciais e preservação do texto local em qualquer falha. Áudio nunca é enviado.

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

The macOS arm64 checks prove the managed dependency graph and portable code;
they do not prove Win32 execution, WPF, hooks, WASAPI, UI Automation or MSIX
packaging. The manual Windows release workflow performs those native gates and
generates the exact Partner Center candidate. The public Store version is 0.1.0;
0.2.0 remains a candidate until Microsoft accepts its submission.

All seven per-project `packages.lock.json` files were generated with SDK 10.0.401,
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
- The installer, release verifier, physical-evidence collector and site projection
  now exist as fail-closed contracts. They remain unexecuted on Windows and do
  not establish a distributable artifact.

Official pin sources: [.NET 10](https://dotnet.microsoft.com/en-us/download/dotnet/10.0),
[MSTest.Sdk 4.4.0](https://www.nuget.org/packages/MSTest.Sdk/4.4.0).
