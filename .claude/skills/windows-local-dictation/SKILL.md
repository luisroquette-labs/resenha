---
name: windows-local-dictation
description: Design, implement, validate, and package native local-only Windows push-to-talk dictation with WPF, Win32, WASAPI, and whisper.cpp. Use for Resenha Windows hotkeys, microphone capture, safe text insertion, Windows release artifacts, and platform-aware gated website downloads.
---

# Windows local dictation

Research and primary-source verification date: **2026-10-04**. Recheck support, signing eligibility, and distribution requirements before each release.

## Task checkpoints

Use this guide with [build-windows-mvp.feature.md](../../../.specs/tasks/draft/build-windows-mvp.feature.md). Resolve the task's current path if its status directory changes.

1. Before planning: reconcile architecture, non-goals, and acceptance criteria with the task.
2. Before implementation: confirm Windows adapters, state transitions, failure handling, and regression tests against this guide.
3. Before packaging: verify the Windows host, pinned dependencies, signing eligibility, and exact artifact validation commands.
4. Before publication: attach physical-Windows QA and artifact evidence to the task, then validate the mandatory form and platform-specific download route.

## Scope and architecture

Keep the application local-only: no Electron, Python runtime, account, backend, hosted inference, telemetry, or paid AI API. Treat the website lead form as a separate system; never send audio or transcripts to it.

Prefer C# WPF on the current supported .NET LTS, a native Win32 interop layer, and a pinned `whisper-cli.exe` child process. WPF runs only on Windows and supports the tray/settings/overlay scope without an additional Windows App SDK runtime. This is a project tradeoff: Microsoft generally recommends WinUI 3 for new native apps. Reconsider WinUI when its controls or Windows App SDK features are actual requirements. [WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/) · [WinUI](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/)

Start with Windows 11 x64. Do not advertise ARM64, Windows 10, or CPU compatibility until tested. Pin the SDK in `global.json`; prefer .NET 10 LTS at this research date, then recheck support before release. Publish self-contained and untrimmed, retaining ordinary files for native dependencies; do not assume Native AOT or single-file packaging improves this MVP. Ship runtime security updates with app updates. [Support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core) · [Publishing](https://learn.microsoft.com/en-us/dotnet/core/deploying/)

Separate the pure state machine from Windows adapters:

```text
idle -> recording -> transcribing -> inserting -> idle
          |                |             |
          +------ cancel/error ----------+ -> idle + actionable status
```

Use one session ID, one recording, and one inference process at a time. Ignore stale completions after cancellation. Keep tray/UI work separate from audio, hook, and inference workers. Show an overlay without activation; never steal typing focus to display recording status.

## Hold shortcut

Use `WH_KEYBOARD_LL` on a dedicated thread with a message loop for key-down and key-up. Keep the callback bounded: update a small key state and enqueue work, then return. Never record, transcribe, await, or access UI Automation inside the callback. Windows can silently remove a timed-out hook. Pass unrelated events to `CallNextHookEx`; ignore injected events and repeated key-downs. Unhook on shutdown. [LowLevelKeyboardProc](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelkeyboardproc)

Use an editable chord, initially Ctrl+Alt+Space, subject to validation on real keyboards. Do not copy macOS Right Option to Right Alt: AltGr must remain usable. Reserve/reject OS shortcuts and make collisions visible. `RegisterHotKey` reports conflicts for registered chords and supports `MOD_NOREPEAT`, but its `WM_HOTKEY` alone does not provide the release event required by hold-to-talk. If combining registration and a hook, define exactly which owns start and stop. A registration probe cannot prove absence of every application's private shortcut. [RegisterHotKey](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey)

Stop on release of any required key. Cancel on session lock, suspend, device failure, or bounded maximum recording duration; never leave the microphone stuck active. Do not suppress arbitrary user modifiers or synthesize releases for keys the user still holds.

## Capture and local inference

Capture the selected microphone with WASAPI shared mode (`IAudioClient` / `IAudioCaptureClient`), never loopback. Read every packet, handle silent buffers, and release buffers promptly. Negotiate the device format, downmix, and resample explicitly to mono 16 kHz PCM16 WAV; verify sample count and duration. Do not write 48 kHz samples with a 16 kHz header. Handle denied microphone access and removed devices as terminal session failures with a settings/retry action. [WASAPI capture](https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream)

Reuse the repository's pinned whisper.cpp submodule and model manifest; verify the model SHA-256 before enabling dictation. Use a multilingual model for PT-BR, not an `.en` model. Allow an explicit initial HTTPS model download/import; afterwards verify dictation with networking disabled. Do not download executable code at runtime. [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

Launch a bundled, fully qualified CLI path with `UseShellExecute=false`, an argument list, no console window, bounded stdout/stderr, cancellation, and timeout. Parse its UTF-8 text output, not diagnostic stderr. Delete per-session WAV/output files on every terminal path; clear abandoned files at next launch. Do not promise forensic secure erasure. Keep transcripts on the clipboard for recovery and avoid logging them. On silence, empty text, corruption, or failed inference, never inject text.

Build for an explicit CPU baseline. `GGML_NATIVE=OFF` alone does not prove broad compatibility: inspect AVX/AVX2/FMA/F16C options and test the declared minimum CPU, or use verified runtime-dispatched variants. Bundle every required DLL and license. CLI isolation simplifies cancellation/crash containment; replacing it with a native library is an optimization requiring separate lifetime and ABI tests. [Pinned CMake](https://raw.githubusercontent.com/ggml-org/whisper.cpp/4979e04f5dcaccb36057e059bbaed8a2f5288315/CMakeLists.txt) · [CPU build options](https://raw.githubusercontent.com/ggml-org/whisper.cpp/4979e04f5dcaccb36057e059bbaed8a2f5288315/ggml/src/ggml-cpu/CMakeLists.txt)

## Clipboard and insertion safety

At recording start, snapshot foreground HWND, PID, focused child HWND, and, where available, UI Automation focused element identity. Browser fields may share one HWND: comparing only a process/window is insufficient. Revalidate immediately before insertion. If the target changed, disappeared, became password/protected, or cannot be identified safely, keep the transcript for manual paste and show that outcome. Never force focus back after the user switched tasks. [GetGUIThreadInfo](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getguithreadinfo) · [Foreground restrictions](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)

Write Unicode clipboard text on an STA context with bounded retries for clipboard contention. Keep the resulting transcript available rather than restoring an old clipboard on an arbitrary timer. Once all shortcut modifiers are released and the target is still valid, send one Ctrl+V sequence via `SendInput`. Check the returned count. Never retry an ambiguous insertion automatically: success reports input dispatch, not proof that an editor accepted the text. [Clipboard](https://learn.microsoft.com/en-us/windows/win32/dataxchg/using-the-clipboard) · [SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)

Keep the app at normal integrity. UIPI blocks injecting into higher-integrity applications; report manual-paste fallback instead of requesting administrator rights or `uiAccess`. Do not use `ValuePattern.SetValue` as a general caret insertion mechanism: it sets a control value and can replace existing content. UI Automation is useful for focus/password checks and verification, but provider support varies. Run bounded UI Automation work on a separate appropriate COM worker to avoid UI deadlocks. [Control patterns](https://learn.microsoft.com/en-us/dotnet/framework/ui-automation/ui-automation-control-patterns-overview) · [UIA threading](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-threading)

## Artifact and distribution

Produce a self-contained folder and an internal ZIP first. For public direct download, prefer a per-user signed EXE installer when no package identity is needed; Inno Setup can provide install/uninstall and `PrivilegesRequired=lowest`. Verify the chosen version's license and sign the application, bundled executable components, installer, and uninstaller with timestamping. Do not buy tools/certificates or enroll in paid services without authority. [Inno Setup](https://jrsoftware.org/isinfo.php) · [Per-user install](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm) · [Signing integration](https://jrsoftware.org/ishelp/topic_setup_signtool.htm)

MSIX is a valid alternative with stronger package identity/integrity and update support. It requires an appropriate manifest and a signature trusted by the target device; a development self-signed certificate is not a public distribution solution. Do not require users to import a development root or disable protections. [Desktop packaging](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-packaging-dot-net) · [MSIX signing](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)

Recheck publisher eligibility before choosing Microsoft's Artifact Signing: its documented Public Trust geography does not currently list Brazil. An Azure hosting region such as Brazil South is distinct from publisher eligibility. Do not assume the user's Brazilian company qualifies through another account. A valid signature identifies the publisher but does not guarantee no SmartScreen warning; EV certificates no longer automatically bypass reputation checks. Test the browser-downloaded artifact with its Mark of the Web on a clean Windows machine. [Artifact Signing Quickstart prerequisites](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart#prerequisites) · [SmartScreen](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)

Hash only the final signed installer. Scan that file and the extracted payload with an updated Defender engine, retain scan output and signature version, and verify no detections; an exit code alone can be misleading when remediation occurred. Do not claim that a clean scan guarantees safety. Upload the exact tested bytes to a versioned GitHub Release with checksums, source SHA, toolchain versions, licenses, and Windows QA evidence. Prefer immutable releases and verify downloaded assets against the release. [Defender commands](https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus) · [Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) · [Release verification](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity)

## Existing website contract

Inspect `site/release.mjs`, `site/download-gate.mjs`, and their tests before editing. Preserve the required name + email + WhatsApp form and strict `postMessage` origin, iframe source, form ID, and success-event checks. Select an explicit platform before opening the gate; carry that immutable selection through success and route to the correct verified asset. Keep PII out of analytics. The app stays account-free even though the website requires the form.

The current CF Gauss form and redirect are macOS-specific. Inspect the real server contract before reusing them for Windows; a made-up `?platform=windows` parameter is not evidence. Depending on the verified form behavior, use a supported platform destination or a dedicated Windows form with the same required fields. A public GitHub URL means this is a website lead gate, not access control over all possible downloads.

Keep Windows download inactive until artifact URL, version, architecture, minimum OS, SHA-256, scan evidence, signature status, and physical-Windows QA all agree. Test missing fields, forged/mismatched messages, duplicate success, closing/reopening, and switching platforms. Preserve macOS behavior. Update platform copy, privacy text, FAQ, and comparison claims only to match delivered facts.

## Validation commands and proof

These are command templates, not evidence that any project/script already exists. Resolve actual paths and pinned versions before running. On the Mac route local typecheck/lint/tests through `mac-gate`; never run `next build` there. Windows GUI, WASAPI, signing, and installation require Windows. Do not quietly add paid Windows runners to the repository's lightweight Ubuntu PR CI policy; first inventory an authorized Windows host or approved release job.

```powershell
# On Windows, after restoring pinned dependencies; replace proposed project paths.
dotnet --info
dotnet restore Windows/Resenha.Windows.sln --locked-mode
dotnet test Windows/Resenha.Core.Tests/Resenha.Core.Tests.csproj -c Release --no-restore
dotnet publish Windows/Resenha.Windows/Resenha.Windows.csproj -c Release -r win-x64 --self-contained true -p:PublishTrimmed=false -o artifacts/windows/app

# Inspect and pin CPU feature options before building the actual distribution.
cmake -S Vendor/whisper.cpp -B artifacts/windows/whisper -A x64 -DGGML_NATIVE=OFF -DWHISPER_BUILD_SERVER=OFF -DWHISPER_CURL=OFF
cmake --build artifacts/windows/whisper --config Release --target whisper-cli --parallel 2
artifacts/windows/whisper/bin/Release/whisper-cli.exe -m models/ggml-small-q5_1.bin -f fixtures/pt-br.wav -l pt -otxt -of artifacts/windows/transcript -np -nt

# Installer script must include signing configuration; no signing bypass.
ISCC.exe Windows/Installer/Resenha.iss
signtool verify /pa /all /v artifacts/windows/Resenha-Windows-x64-Setup.exe
Get-FileHash artifacts/windows/Resenha-Windows-x64-Setup.exe -Algorithm SHA256
# Resolve the installed, updated MpCmdRun.exe path first.
MpCmdRun.exe -Scan -ScanType 3 -File artifacts/windows/Resenha-Windows-x64-Setup.exe -DisableRemediation
MpCmdRun.exe -Scan -ScanType 3 -File artifacts/windows/app -DisableRemediation

# After authorized publication of an immutable release:
gh release verify RELEASE-TAG --repo luisroquette/resenha
gh release verify-asset RELEASE-TAG artifacts/windows/Resenha-Windows-x64-Setup.exe --repo luisroquette/resenha
```

Validate installer command switches against [ISCC](https://jrsoftware.org/ishelp/topic_compilercmdline.htm) and signature verification against [SignTool](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool). Record every native process exit code; PowerShell must throw on failures rather than continue to package.

Require the following bounded evidence groups:

1. Pure tests: state transitions, repeated key-down, release orders, silence, cancellation, timeouts, stale completions, target changes, clipboard contention, and no duplicate paste.
2. Real Windows: Notepad and browser text/input/contenteditable insertion, PT-BR accents, ABNT2/AltGr, existing selection, app/field focus changes, elevated app fallback, microphone denial/removal, sleep/lock, and ten consecutive sessions without a stuck hook/mic.
3. Offline operation: complete initial model setup, disconnect networking, dictate and insert; verify temp-file cleanup and no text/audio logs. Record cold/warm latency, CPU, RAM, model, CPU model, and OS build without inventing performance guarantees.
4. Clean install/update/uninstall: standard user, no preinstalled .NET or compiler toolchain, all native dependencies present, browser download/SmartScreen behavior, final hashes and signature chain. VM tests supplement the required physical-hardware test.
5. Website: correct verified asset after the mandatory form, unchanged macOS route, no PII in analytics, persisted release evidence, and latest-SHA checks. A green build or stubbed Windows adapter is not runtime proof.
