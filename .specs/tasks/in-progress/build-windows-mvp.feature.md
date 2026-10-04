---
title: Build native Windows dictation MVP and publish its download
depends_on: []
---

# Description

**What:** Build a native Resenha MVP for Windows 10/11 x64: hold a configurable
global shortcut, speak, release, transcribe on the device with whisper.cpp, copy
the transcript, then insert it into the field that had focus. Expose a Windows
download on the existing site only after the exact release artifact passes the
documented Windows verification and distribution gates.

**Why:** Give Windows users the same short, private dictation workflow without
an account, subscription dependency, remote transcription, or paid AI API.
Clipboard recovery must preserve useful output when an application rejects
automatic insertion. The site must distinguish planned availability from a
release users can actually install and use.

**Who:** People using Windows 10/11 x64 who dictate in Brazilian Portuguese,
English, or Spanish, including everyday English terms within Portuguese or
Spanish sentences. Release maintainers need reproducible packaging and evidence
that corresponds to the bytes offered for download.

### Scope Included

- Global, configurable push-to-talk shortcut; visible idle, recording,
  transcribing, inserting, and recoverable error states; microphone selection
  and understandable Windows permission/device errors.
- Local microphone capture, bundled local whisper.cpp runtime, a model obtained
  once with integrity validation, explicit PT-BR/EN/ES selection, and
  deterministic text cleanup that preserves anglicisms and meaning.
- Clipboard write before insertion into the captured target; safe recovery for
  blocked paste, clipboard contention, focus loss, missing/corrupt model,
  disconnected microphone, cancellation, and inference failure.
- Windows 10/11 x64 packaging as at least one documented installer or portable
  distribution, Authenticode signing, SHA-256 sidecar, malware scan, clean
  removal, and evidence from real Windows hardware for the exact artifact.
- A Windows release channel on the existing site, preserving the mandatory
  name, email, and WhatsApp form and its trusted completion checks. The Windows
  download remains unavailable until all release evidence exists.

### Scope Excluded

- New backend, user accounts, cloud audio/transcription, paid AI APIs, AI rewrite,
  translation, tone rewriting, or generative post-processing.
- Windows ARM, x86, Linux, Microsoft Store submission, automatic updates,
  telemetry additions, and guaranteed insertion into elevated/protected fields.
- Continuous listening, meetings, speaker diarization, mandatory transcript
  history, and features unrelated to the push-to-talk loop.
- Redesigning the macOS app, replacing the existing form service, adding another
  lead database, or bypassing the required download form.

### User Scenarios

**Primary:** On a verified Windows 10/11 x64 installation, the user opens an
editable field, chooses PT-BR, holds the shortcut, speaks a sentence containing
an English work term, and releases it. Recording stops, local transcription
runs, the transcript reaches the clipboard, and a single paste inserts it into
the original field. The app returns to idle and accepts another dictation.

**Alternative:** The user changes the shortcut and chooses EN or ES. After the
verified model is available, the same loop works with networking disabled. In a
target that prevents simulated input, the app retains the completed transcript
on the clipboard, explains manual Ctrl+V, and accepts the next dictation.

**Error:** Microphone permission is denied, the device disconnects, the model is
missing/corrupt, inference fails, or the clipboard is busy. Recording and any
partial resources stop safely. A specific message identifies the recovery
action; retry does not duplicate output or start another recording while busy.
No paste is attempted until the current transcript was successfully copied.

**Distribution:** A visitor selects Windows and completes the required form.
Only a validated completion for the existing trusted form may release the
verified Windows destination. Missing signing certificate, Windows hardware,
scan evidence, or artifact verification keeps Windows explicitly unavailable;
the implementation report states the blocker without claiming a published MVP.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
| --- | --- | --- | --- |
| CK-1 | Does a configurable global shortcut record only while held, stop on release, ignore key repeat, reject overlapping work, and recover from cancellation or lost release without remaining stuck? | Interaction | MUST |
| CK-2 | Are microphone audio and whisper.cpp inference local, with no recording before press or after release and no retained temporary audio after success, cancellation, failure, or next-start cleanup? | Privacy | MUST |
| CK-3 | Can the user explicitly select PT-BR, EN, and ES, with offline results meeting the declared fixture accuracy and anglicism-preservation thresholds? | Transcription | MUST |
| CK-4 | Is the exact completed transcript committed to the clipboard before one insertion attempt into the captured target, with no paste when clipboard write failed and no silent insertion into an unrelated field after focus changes? | Output safety | MUST |
| CK-5 | Do permission denial, unavailable/disconnected microphone, missing/corrupt model, inference failure, clipboard contention, and blocked insertion each expose an actionable recovery path that returns to an operable state? | Recovery | MUST |
| CK-6 | Does the same distributable run as a normal user on Windows 10 and Windows 11 x64, including real microphone-to-text-to-target demonstrations on each OS? | Compatibility | MUST |
| CK-7 | Is at least one installer or portable artifact self-contained apart from its documented verified model download, and can it be removed without orphaned processes, hooks, startup entries, or application-owned temporary files? | Packaging | MUST |
| CK-8 | Are the final shipped binaries/package signed and timestamped with a valid trusted publisher certificate, and are a SHA-256 sidecar and successful malware-scan evidence bound to those exact final bytes? | Distribution integrity | MUST |
| CK-9 | Does the site enable the Windows destination only with complete matching artifact, signing, hash, scan, and physical-verification evidence, while missing or inconsistent evidence renders it unavailable? | Release truthfulness | MUST |
| CK-10 | Does every Windows download CTA preserve the required name, email, and WhatsApp form, reject incomplete/forged completion, and route successful completion to the selected verified platform without regressing macOS? | Download funnel | MUST |
| HR-1 | Are there no new backend, account, remote transcription, paid AI calls, or AI rewrite dependencies in the Windows product or its release path? | Hard requirement | MUST |
| HR-2 | If a signing certificate, Windows execution environment, or release evidence is unavailable, is public Windows distribution blocked and the missing prerequisite explicitly recorded rather than represented as passed? | Hard requirement | MUST |
| HR-3 | Are checks tied to the current source SHA and artifact hash, with no fabricated test results, disabled gates, unverified public URLs, direct main push, or claimed publication before actual evidence? | Hard requirement | MUST |

**Regular Checks:**

- [ ] Run the existing site regression command on the Mac through the shared
  gate: `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`. Extend that
  suite for Windows evidence and form/platform routing; keep existing checks.
- [ ] Implement the **new proposed** Windows gate
  `pwsh -NoProfile -File Scripts/windows/preflight.ps1` for the selected native
  toolchain's compile/static checks and unit/integration tests. Execute
  Windows-dependent checks on Windows; any portable checks run on the Mac only
  through `mac-gate`. Missing tools or tests fail the gate, never become passes.
- [ ] Implement and run the **new proposed** packaging command
  `pwsh -NoProfile -File Scripts/windows/build-release.ps1 -Version <version>`
  on Windows, recording source SHA, toolchain/runtime/model versions, package
  type, and output artifact path. Signing requires an available approved
  certificate; absence records a publication blocker.
- [ ] Implement and run the **new proposed** verifier
  `pwsh -NoProfile -File Scripts/windows/verify-release.ps1 -Artifact <path> -Evidence <json>`
  after signing. It must validate Authenticode/timestamp, SHA-256, scanner
  result, and exact-artifact physical test evidence; absent evidence fails.
  `Get-FileHash -Algorithm SHA256 <path>` and
  `Get-AuthenticodeSignature <signed-file>` are real PowerShell inspection
  commands, not substitutes for the complete verifier.
- [ ] Record physical Windows 10/11 x64 tests and the real hosted-download
  round-trip hash. Before integration, run the repository's canonical preflight
  through `mac-gate` (use `npm run preflight:ci` only if actually introduced),
  inspect applicable workflows/provider configuration, require applicable green
  remote checks on the latest SHA, and attach evidence to the task's single PR.
  Never run `next build` locally; if applicable it belongs to Vercel Preview.

**Rubric:**

Scores use a 0–4 scale; intermediate scores require recorded supporting evidence.
All MUST checks are independent gates: a weighted score cannot waive one.

| Criterion | Weight | Evidence |
| --- | --- | --- |
| Dictation loop reliability | 0.30 | CK-1, CK-4, CK-5; lifecycle tests and physical sessions |
| Local multilingual quality | 0.25 | CK-2, CK-3, HR-1; offline trace and fixed speech corpus |
| Windows distribution readiness | 0.25 | CK-6, CK-7, CK-8, HR-2; exact-artifact release dossier |
| Truthful site integration | 0.20 | CK-9, CK-10, HR-3; release fixtures and browser verification |

**Rubric Score Definitions:**

### Dictation loop reliability

`score_2`: A happy-path demonstration works, but lifecycle race cases or at
least one error recovery still lacks evidence. `score_4`: All CK-1/4/5 cases
pass, plus ten consecutive real dictations on each supported OS complete with
one recording and at most one insertion each, without a stuck state or lost
completed transcript. `contrast`: A screen recording of one successful paste
does not establish repeatability or recovery after failure.

### Local multilingual quality

`score_2`: Local inference and language selection work, but accuracy, mixed
vocabulary, audio cleanup, or offline behavior is not reproducibly checked.
`score_4`: CK-2/3 and HR-1 pass; a versioned corpus of at least five utterances
per language reaches WER at most 20% per language and preserves at least 90% of
annotated anglicism occurrences in PT-BR/ES, using a documented normalization
that cannot erase substantive word errors. Fixtures include silence and mixed
vocabulary; silence yields no fabricated text or paste. `contrast`: A mocked
transcript or translated/rephrased output cannot demonstrate speech accuracy
or faithful local transcription.

### Windows distribution readiness

`score_2`: A package exists, but signing, scan, clean removal, or either supported
Windows version remains unverified. `score_4`: CK-6/7/8 pass for the final
artifact, with recorded source SHA, package SHA-256, valid publisher signature,
timestamp, scan engine/signature versions and result, both physical OS runs,
and install/run/remove evidence. `contrast`: Cross-compilation, a successful CI
job, or an unsigned local build is development evidence, not public release
readiness. An explicit blocker is honest progress but does not earn score_4.

### Truthful site integration

`score_2`: The Windows slot and form exist, but malformed evidence, platform
routing, or the actual downloadable bytes have not been verified.
`score_4`: CK-9/10 and HR-3 pass, including negative evidence fixtures, required
form validation and trusted completion, actual Windows download/hash matching,
and unchanged working macOS routing. `contrast`: A green link or HTTP 200
without artifact identity and completed-form proof is insufficient.

**Test Strategy:**

**Criticality:** High for user text, microphone privacy, trusted downloads, and
truthful release claims. Use automated lifecycle/contract checks plus physical
OS evidence; simulated APIs cannot prove microphone capture or real insertion.
Performance observations record hardware, model, recording duration, and
end-to-end latency without claiming an unmeasured speed target.

| Type | Size | Framework | Dependencies | Gate |
| --- | --- | --- | --- | --- |
| Lifecycle/output/privacy unit | Small | Native test framework selected and pinned by architecture; new tests | Fake clock, microphone, clipboard, focus, transcriber | Required before Windows release; no network |
| Local inference integration | Medium | New Windows preflight runner plus real whisper.cpp | Pinned model, versioned licensed/owned audio corpus, temp filesystem | All languages and cleanup; no remote inference |
| Site contract regression | Small | Existing Node `node:test` | `site/release.mjs`, `site/download-gate.mjs`, local fixtures | Mac via `mac-gate`; required before PR/integration |
| Browser download/form | Medium | Existing Playwright development dependency; new cases | Local site, intercepted test form; real hosted form for final approved smoke | Required before activating Windows channel |
| Physical release/security | Large | Windows PowerShell verifier, OS tools, recorded manual protocol | Real Windows 10/11 x64, microphone, trusted certificate, scanner, final artifact | Blocks publication; cannot be replaced by mocks or cross-build |

#### CK-1

Cover press/release, auto-repeat, changed shortcut, occupied/invalid shortcut,
release while focus changes, cancellation, lost release, exit during capture,
and a second press while transcribing. Assert one capture session, no stuck
keys/hooks, and a return to idle. Exercise ten successive physical cycles per OS.

#### CK-2

Observe that audio is acquired only during the held session. Verify local-only
capture/inference with networking disabled after model acquisition. Check temp
audio deletion after success/error/cancel and cleanup of app-owned remnants on
next launch after forced termination. Verify model download size/hash and no
transcript/audio in logs; inspect dependency/runtime traces for HR-1.

#### CK-3

Commit the versioned corpus and expected transcripts before measuring quality.
Run PT-BR, EN, and ES with at least five utterances each and report per-language
WER, plus annotated anglicism retention for PT-BR/ES. Include accents, names,
punctuation, mixed terms, silence, and empty capture. Confirm selection survives
restart and silence creates neither transcript nor insertion.

#### CK-4

Assert ordering: complete transcript, successful clipboard commit, one paste.
Use locked clipboard, changed/missing target, blocked synthetic input, and
retry fixtures to prevent stale/duplicate/wrong-target insertion. Physically
verify Notepad and a Chrome editable field on both OS versions. A rejected
automatic paste must leave the completed text available for manual Ctrl+V;
clipboard-write failure must retain text in the app with an explicit copy retry.

#### CK-5

Inject each named failure at its producer boundary. Assert the specific message,
cleanup, bounded retry/cancel action, retained completed text where available,
and a subsequent successful session. Test denied microphone access, removed
device, missing model, hash mismatch, inference crash, clipboard busy, and
normal-user insertion into an elevated or protected target without escalation.

#### CK-6

Record edition/build, x64 architecture, CPU/RAM, audio device, app/model version,
source SHA, and final artifact hash for real Windows 10 and Windows 11 runs.
Install/start as a normal user and demonstrate actual speech, local transcript,
clipboard, and insertion on each. Virtual or mocked checks may supplement this
evidence but do not replace the physical matrix; absent hardware triggers HR-2.

#### CK-7

On a clean user profile, unpack/install, acquire the verified model, run offline,
exit, and uninstall/remove the selected package. Verify no undeclared developer
tools are needed, no running processes/hooks/startup entries remain, and remove
application-owned cache/config/model through the documented removal flow.
Never delete user documents or unrelated clipboard data. Test paths containing
spaces and non-ASCII characters. Document any user-selected retained data.

#### CK-8

Sign before final hashing and scanning. Verify the publisher chain, signature,
timestamp, executables/libraries and installer where applicable, SHA-256
sidecar, and completed malware scan of the shipped package and extracted
payload. Record scanner/version/signature date/time and result. Reject unsigned,
invalid/altered signatures, hash mismatches, incomplete/failed scans, or changed
bytes. An unavailable certificate explicitly blocks public release under HR-2.

#### CK-9

Cover absent evidence and mismatches in source SHA, artifact/platform/version,
hash, signing status, scan result, physical OS coverage, and download URL.
All invalid fixtures must keep Windows unavailable. Only a complete matching
release may activate. Download the real hosted bytes and compare SHA-256 before
advertising availability; attach immutable evidence references. Development
fixtures cannot be copied into production release evidence (HR-3).

#### CK-10

Verify each blank/invalid required form field prevents successful completion;
validate name, email, and WhatsApp remain required. Reject foreign origin,
wrong source window, wrong form ID, malformed message, and completion from an
unrelated form. Verify selected-platform state survives the form flow, Windows
cannot redirect to a macOS DMG, and existing macOS download still works.
Use synthetic data and intercepted submissions for automated tests; do not
create real leads or alter production form configuration as a test side effect.

**Definition of Done:**

- [ ] All CK and HR gates pass with evidence; rubric evaluation is recorded,
  fixtures and regression tests are committed, and documentation matches the
  implemented behavior and actual package/removal commands.
- [ ] The exact signed artifact has matching SHA-256, completed clean scan,
  real Windows 10/11 x64 verification, and a tested installation/removal path.
- [ ] The site's Windows channel passes evidence/form tests and serves the
  verified bytes only after the existing mandatory form; macOS remains valid.
- [ ] Work stays on the dedicated task branch and single PR; canonical local
  and applicable remote gates pass for the latest SHA, with no bypass or
  fabricated evidence. Publication and deployment are reported only when real.
- [ ] If certificate, Windows execution, hosting, or other required release
  evidence is missing, document the precise blocker and completed development
  scope, leave the Windows download unavailable, and leave release completion
  unchecked. A blocked release is not a completed published MVP.

## Architecture Overview

**Decision record, 2026-10-04.** This section defines the implementation; it
does not report a build, test, signature, scan, installation, or publication.
It supersedes the alternative stacks and example path spellings in the earlier
analysis/research. New native code lives under `Windows/`; release scripts live
under `Scripts/windows/`. The existing Swift target stays intact.

### Platform, stack, and dependency boundary

| Area | Selected contract |
| --- | --- |
| Windows 10 target | Windows 10 Home/Pro **22H2, build 10.0.19045**, x64, with available security updates. This is a Resenha compatibility target requiring physical QA, not a claim of Microsoft support for Windows 10 or .NET 10 on this edition. Earlier Windows 10 releases and LTSC editions are outside the initial matrix. |
| Windows 11 target | Windows 11 Home/Pro **25H2, build 10.0.26200**, x64 minimum. Later releases require a recorded compatibility smoke before being named as verified. No Windows ARM emulation, x86, Server, or S-mode support is claimed. |
| Native application | C# 14, WPF, .NET **10.0.401 SDK** and self-contained Desktop Runtime **10.0.12**, `win-x64`, `net10.0-windows10.0.19041.0`; runtime/installer enforce the stricter product OS floor above. No trimming, single-file publish, Native AOT, Windows App SDK, Electron, Rust migration, or Python dependency. |
| Core and tests | `Resenha.Core` targets `net10.0`, uses framework libraries only, and has no Windows/UI references. **MSTest.Sdk 4.4.0** owns both test projects, with exact SDK/package versions and transitive lockfiles. Windows interop is a narrow, project-owned Win32/COM layer; no audio or UI automation wrapper package is required. |
| Native inference and CPU | Existing whisper.cpp commit `4979e04f5dcaccb36057e059bbaed8a2f5288315`, built as a bundled CLI. CPU-only x64 baseline explicitly requires **AVX2, FMA, F16C, SSE4.2, and OS-enabled AVX state**; startup checks report an unsupported CPU before launching native inference. RAM requirement is 8 GiB; setup checks at least 1 GiB free beyond the measured installed payload. No GPU/driver requirement. |

The SDK/runtime pins reflect the official [.NET 10 downloads](https://dotnet.microsoft.com/en-us/download/dotnet/10.0)
observed on this date; release preflight must reject an unreviewed obsolete
security patch. Windows 10 22H2 is absent from the current [.NET supported OS
matrix](https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md),
so physical compatibility and vendor support must remain separate claims.
Windows 11 25H2 provides a longer Home/Pro servicing runway than 24H2 at this
date; the exact build comes from [Windows release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information).
No compatibility evidence exists merely because an OS version is listed here.

WPF is chosen for native tray/settings/status windows and mature Win32 access.
A separate CLI costs process/model startup time but gives enforceable inference
cancellation and crash containment. AVX2 reduces the supported CPU set and
must appear in requirements; it avoids promising untested universal x64
performance. These are final MVP choices, not options deferred to implementation.

### Components and exact implementation paths

```text
WPF tray/settings/overlay -> DictationCoordinator (single serialized owner)
                                |-> keyboard edges + monotonic clock
                                |-> WASAPI recorder -> owned WAV lease
                                |-> verified model -> whisper-cli child job
                                |-> output policy -> STA clipboard commit
                                `-> target broker recheck -> one SendInput

signed payload -> signed installer -> hash/scan/physical QA -> release manifest
               -> hosted-byte verification -> platform-specific website gate
```

| Responsibility | Expected new paths |
| --- | --- |
| Build contract | `Windows/Resenha.Windows.sln`, `Windows/global.json`, `Windows/Directory.Build.props`, `Windows/Directory.Packages.props`, `Windows/NuGet.Config`, `Windows/toolchain-lock.json`, `Windows/native/CMakePresets.json` |
| Portable policy | `Windows/Resenha.Core/Resenha.Core.csproj`, `Windows/Resenha.Core/Contracts.cs`, `Windows/Resenha.Core/DictationCoordinator.cs`, `Windows/Resenha.Core/ShortcutPolicy.cs`, `Windows/Resenha.Core/AudioPolicy.cs`, `Windows/Resenha.Core/OutputPolicy.cs`, `Windows/Resenha.Core/ReleasePolicy.cs` |
| Windows boundaries | `Windows/Resenha.Platform/Resenha.Platform.csproj`, `Windows/Resenha.Platform/NativeMethods.cs`, `Windows/Resenha.Platform/KeyboardHook.cs`, `Windows/Resenha.Platform/WasapiRecorder.cs`, `Windows/Resenha.Platform/PcmConverter.cs`, `Windows/Resenha.Platform/ModelStore.cs`, `Windows/Resenha.Platform/WhisperCliTranscriber.cs`, `Windows/Resenha.Platform/ChildProcessJob.cs`, `Windows/Resenha.Platform/TargetBrokerClient.cs`, `Windows/Resenha.Platform/ClipboardService.cs`, `Windows/Resenha.Platform/TextInjector.cs`, `Windows/Resenha.Platform/PreferencesStore.cs`, `Windows/Resenha.Platform/SessionFiles.cs`, `Windows/Resenha.Platform/PlatformReadiness.cs` |
| Native presentation | `Windows/Resenha.Windows/Resenha.Windows.csproj`, `Windows/Resenha.Windows/App.xaml`, `Windows/Resenha.Windows/App.xaml.cs`, `Windows/Resenha.Windows/app.manifest`, `Windows/Resenha.Windows/TrayController.cs`, `Windows/Resenha.Windows/SettingsWindow.xaml`, `Windows/Resenha.Windows/SettingsWindow.xaml.cs`, `Windows/Resenha.Windows/StatusWindow.xaml`, `Windows/Resenha.Windows/StatusWindow.xaml.cs`, `Windows/Resenha.Windows/ProductViewModel.cs`, `Windows/Resenha.Windows/Assets/Resenha.ico` |
| Isolated focus inspection | `Windows/Resenha.TargetBroker/Resenha.TargetBroker.csproj`, `Windows/Resenha.TargetBroker/Program.cs`, `Windows/Resenha.TargetBroker/FocusProbe.cs`; produces `Resenha.TargetBroker.exe`, a local MTA UI Automation worker with no UI and no transcript access |
| Mouse target invalidation | `Windows/Resenha.Platform/MouseActivityMonitor.cs`; owns the passive `WH_MOUSE_LL` observer and emits attempt-scoped physical button activity to invalidate automatic insertion |
| Tests and fixtures | `Windows/Resenha.Core.Tests/Resenha.Core.Tests.csproj`, `Windows/Resenha.Core.Tests/CoordinatorTests.cs`, `Windows/Resenha.Core.Tests/ShortcutTests.cs`, `Windows/Resenha.Core.Tests/OutputTests.cs`, `Windows/Resenha.Platform.Tests/Resenha.Platform.Tests.csproj`, `Windows/Resenha.Platform.Tests/AudioTests.cs`, `Windows/Resenha.Platform.Tests/TargetClipboardTests.cs`, `Windows/Resenha.Platform.Tests/ModelProcessTests.cs`, `Windows/Resenha.Platform.Tests/InferenceCorpusTests.cs`, `Windows/Fixtures/speech-corpus.json`, `Windows/Fixtures/audio/pt-br-01.wav` through `pt-br-05.wav`, `en-01.wav` through `en-05.wav`, `es-01.wav` through `es-05.wav`, `silence.wav`, `Windows/Fixtures/LICENSE.md` |
| Installer and release | `Windows/Installer/Resenha.iss`, `Windows/Installer/LICENSES.txt`, `Windows/model-manifest.json`, `Windows/release-manifest.schema.json`, `Scripts/windows/preflight.ps1`, `Scripts/windows/build-release.ps1`, `Scripts/windows/verify-release.ps1`, `Scripts/windows/collect-physical-evidence.ps1`, `Scripts/windows/promote-release.mjs` |
| Site release contract | `site/windows-release-evidence.json`, `site/download-platforms.mjs`, `Scripts/windows-release.test.mjs`; extend the existing `site/release.mjs`, `site/download-gate.mjs`, `Scripts/site.test.mjs`, and `Tools/site-audit/audit.mjs` |
| Documentation and CI | `docs/specs/23-windows-mvp.md`, `docs/testing/WINDOWS-MVP-EVIDENCE.md`, `docs/testing/WINDOWS-RELEASE-EVIDENCE.md`, `.github/workflows/windows-contracts.yml`; extend `.github/workflows/site-tests.yml` path filters and the existing architecture/privacy/readme/constitution/notices/ignore files listed in the analysis |

`packages.lock.json` is committed beside each project that resolves NuGet
dependencies; restore uses locked mode. `Windows/global.json` fixes SDK
`10.0.401`, `rollForward: disable`, and MSTest SDK `4.4.0`. The toolchain lock
must additionally record the exact approved Windows SDK, MSVC v143 compiler,
CMake, PowerShell 7, and Inno compiler versions/hashes found on the Windows
build host before its first build. This inventory is a prerequisite, not a
license to select floating versions or claim an unidentified host is ready.

Every Windows script that invokes `dotnet` must first resolve the repository
root from `$PSScriptRoot` and change its working directory to that root's
`Windows/` directory (`Push-Location`, restored with `Pop-Location` in
`finally`). Run SDK inspection, restore, build, format, test, and publish from
there so `Windows/global.json` controls SDK selection; passing a project path
from the repository root alone does not select that file. Resolve incoming
artifact/evidence paths before changing directory and retain absolute paths.

### Interfaces, records, and ownership

All boundary calls carry an `AttemptId` and cancellation token. Results use
typed outcomes rather than exception strings as product messages. Only the
coordinator changes state; adapters never call insertion or start another
attempt themselves. `IClock` supplies monotonic deadlines to production and
fake-clock tests.

| Interface | Contract and result |
| --- | --- |
| `IShortcutSource` | `Configure(Shortcut)`, `Start`, `Stop`; emits `Pressed`, `Released`, `Interrupted` with monotonic timestamp. `Shortcut` stores scan code, extended-key flag, and exact left/right modifier requirements; display labels are layout-specific. |
| `IAudioRecorder` | `StartAsync(attempt, deviceId, pressedAt)`, `StopAsync(releasedAt) -> AudioLease`, `CancelAsync`; `AudioLease` owns one 16 kHz mono PCM16 WAV, frame count, duration, energy summary, and disposal. Stop/cancel is idempotent. |
| `IModelStore` / `ITranscriber` | `AcquireVerifiedAsync -> VerifiedModelLease`; `TranscribeAsync(audio, model, language, deadline) -> TranscriptResult`. The model lease retains a read handle denying write/delete while the CLI reads it. Language is exactly `pt`, `en`, or `es`; there is one child inference job. |
| `ITargetProbe` | `CaptureAsync -> TargetSnapshot`, `CheckAsync(snapshot) -> SameTarget/Changed/Unsafe/Unknown`. Snapshot includes foreground/root HWND, focused child HWND, PID, process creation time, session/desktop, integrity, UIA runtime ID/control type/password/editability, focus generation, and selection/caret identity where exposed. No field contents are collected. |
| `IClipboard` / `ITextInjector` | `CommitAsync(text) -> ClipboardToken`; token contains attempt, nonzero clipboard sequence and text digest. `TryInsertAsync(target, token) -> Dispatched/ManualPaste/CopyRequired`; a dispatch is attempted once only after target and clipboard rechecks. The result never asserts that an arbitrary editor accepted input. |

`TranscriptResult` distinguishes text, silence, cancellation, timeout, corrupt
input/model, and engine failure. `RecoveryStatus` carries a stable error code,
localized action, attempt ID, and optional in-memory completed text. Persisted
preferences contain `schemaVersion`, exact shortcut, microphone endpoint ID,
and language only. No account, transcript history, telemetry, or audio log is
created by the Windows target.

### Shortcut, lifecycle, and finite work

`KeyboardHook` owns `WH_KEYBOARD_LL` on a dedicated message-loop thread. It
alone emits start and release edges. `RegisterHotKey` is used briefly to probe
a configured chord for registered conflicts, then unregistered; `WM_HOTKEY`
never starts recording. The default is **Left Ctrl + Left Alt + Space**.
Right Alt/AltGr, modifier-only chords, Win chords, F12, secure/OS-reserved
combinations, and invalid or observed occupied registrations are rejected.
A successful probe cannot detect all application-private shortcuts; settings
states that limitation and provides immediate reassignment.

Callbacks only update bounded key state and enqueue an event; they do no COM,
audio, process, disk, or UI work. Ignore injected events and repeated downs.
Suppress only the configured trigger key's down/up while an accepted chord is
latched, including busy rejection; pass unrelated keys and modifiers through.
Never synthesize releases of physically held keys. Stop on the first release
of any required key, then require all chord keys up before rearming. Extra
modifiers during capture cancel. A 100 ms independent physical-key watchdog
detects missing release/lock/desktop changes and cancels/discards the attempt.
Hook installation failure disables dictation; suspend/session lock cancels,
and resume reinitializes the hook only after all keys are up. The bounded
callback rule follows [Microsoft's hook contract](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelkeyboardproc).

| State/condition | Required transition |
| --- | --- |
| `Idle` + valid press + ready dependencies | Allocate an attempt and capture target before showing status. Enter `Recording` with an internal starting phase; start microphone only while this attempt's hold remains active. Release during asynchronous startup cancels its late start. |
| `Recording` + release | Close the audio interval immediately, stop/release the stream, then enter `Transcribing` only for eligible nonempty audio. Repeated release is a no-op. |
| `Transcribing` + current successful result | Apply deterministic output policy, enter `Inserting`, and commit clipboard before any input dispatch. All new presses while busy are ignored and visibly reported; no queued dictation. |
| `Inserting` + dispatch/fallback/copy failure | Finish resources, retain completed text as necessary, then `Idle` with `Ready`, `ManualPaste`, or `CopyRequired` status. Copy retry copies only; it never repeats inference or automatic paste. |
| Any active state + cancel/error/lock/suspend/shutdown | Invalidate generation first, stop audio/kill child job, dispose owned files, enter `Failed` visibly, then `Idle` when cleanup acknowledges. A stale completion cannot copy, paste, reset UI, or delete a new attempt's resources. |

Limits are product policy: 120 seconds maximum hold; recordings shorter than
300 ms produce no inference; microphone start deadline 2 seconds and stop
acknowledgment deadline 1 second; inference deadline 120 seconds from process
start; target request 300 ms; all shortcut modifiers up within 2 seconds before
insertion; clipboard acquisition budget 500 ms; child termination wait 2
seconds. A maximum-duration/lost-release event cancels instead of transcribing
while the user may still be holding the shortcut. Escape during an active
attempt and the tray Cancel action cancel without adding a permanent Esc hook
shortcut. Child jobs use kill-on-close and are confirmed exited before cleanup.
If audio shutdown cannot be acknowledged, fail closed and terminate the app
after showing a reopen instruction; never label a possibly active microphone
idle or allow a second recorder. No automatic retry starts recording or inference.

WPF owns its STA dispatcher and settings window. A tray icon has Open settings,
Cancel, Copy last result, and Exit. The status overlay uses `WS_EX_NOACTIVATE`,
`ShowActivated=false`, no taskbar entry, and bounded dismissals keyed to the
attempt. It displays real recording level/state without taking editor focus.
Opening settings during a session cancels it. A per-user single-instance mutex
prevents two hooks/recorders; secondary launches only request opening settings
when the first instance is idle.

### WASAPI, local files, model, and inference

`WasapiRecorder` uses `IMMDeviceEnumerator`, a selected capture endpoint,
event-driven shared-mode `IAudioClient`/`IAudioCaptureClient`, and an audio
worker; it never uses loopback. Default input is selected once on first run,
then its stable endpoint ID is saved. Reconnection requires explicit retry;
there is no mid-recording switch to another microphone. Every acquired packet
is released on its owning thread. Silent-buffer flags produce zeros; invalid
timestamps, discontinuity or device loss fail the attempt instead of presenting
partial audio as complete. [WASAPI packet and timing contract](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudiocaptureclient-getbuffer).

Accept PCM16/24/32 or float32 mix format, read its actual rate/channel mask,
and convert with the Windows Media Foundation Audio Resampler to PCM16 mono
16,000 Hz (filter quality 60). Drain the converter and verify WAV byte/frame
counts. Unsupported input format or unavailable Media Foundation produces an
actionable setup error; Windows N without the Media Feature Pack is not ready.
QPC packet positions and captured press/release edges trim committed samples
to the held interval. Timestamp uncertainty cancels the attempt. The device
may need scheduling time to stop; no post-release packet is retained as user
audio. [Resampler interface](https://learn.microsoft.com/en-us/windows/win32/medfound/audioresampler).

Silence policy is deterministic: reject empty audio and captures with fewer
than 200 ms of 20 ms frames above -50 dBFS RMS. This is an energy threshold,
not a claim of perfect speech detection; quiet speech may require adjusting
the microphone. Apply whisper's no-speech threshold `0.6` and suppress
non-speech tokens; silence fixtures must return no text, clipboard change,
or paste. Permission denial maps to `MicrophoneDenied` and the explicit action
`ms-settings:privacy-microphone`; missing/disabled endpoint maps to
`MicrophoneUnavailable` and Choose microphone; unplug/invalidated endpoint
maps to `MicrophoneDisconnected` and Reconnect, then retry. All close the
stream and delete partial audio. No permission/device failure is requeued.

Application files install in `%LOCALAPPDATA%\Programs\Resenha\`; preferences
in `%LOCALAPPDATA%\Resenha\settings.json`; model in
`%LOCALAPPDATA%\Resenha\models\ggml-small-q5_1.bin`; temporary session files in
`%LOCALAPPDATA%\Resenha\sessions\<attempt-guid>\input.wav` and `result.txt`.
The app restricts these directories to the user, validates canonical ownership,
and rejects reparse-point traversal. Single-instance startup removes only its
abandoned session directories before enabling dictation. Success, error,
cancel, exit, and next-start cleanup cover WAV and CLI outputs. Failed deletions
remain a visible cleanup blocker, not silent retention. Disk history is absent;
the last completed text remains in RAM until replaced, explicitly cleared, or
exit, and can remain on the OS clipboard. Secure erasure is not promised.

`Windows/model-manifest.json` pins multilingual `ggml-small-q5_1.bin`,
**190085487 bytes**, SHA-256
`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`,
and the existing model's HTTPS source. Setup downloads only after an explicit
Download model action, or imports a user-selected file into owned storage.
Both paths enforce size/hash, stage `.partial`, and atomically promote only a
complete valid file. A failed replacement preserves a valid prior model.
Verify again on each lease acquisition and hold the verified file read-only
against writes/deletion through inference. Missing/hash-invalid models disable
recording and expose Download/import again; existence alone is never ready.
The download has a 30-second no-progress timeout and 15-minute total deadline,
with manual retry. No executable is downloaded at runtime.

Build whisper with MSVC v143 using the checked-in CMake preset, native tuning
off, CPU backend on, AVX/SSE4.2/AVX2 on, BMI2/AVX-VNNI/AVX512 variants off,
all GPU/BLAS/network/server backends off, static ggml libraries and static
MSVC runtime, OpenMP off. Under MSVC the pinned source implies FMA/F16C with
AVX2; the CPU readiness check includes both. CMake cache and binary dependency
inspection must prove the intended flags and absence of undeclared DLLs.
`min(4, logicalProcessorCount)` limits inference threads. This preset follows
the actual [pinned ggml options](https://raw.githubusercontent.com/ggml-org/whisper.cpp/4979e04f5dcaccb36057e059bbaed8a2f5288315/ggml/CMakeLists.txt).

Launch only bundled `native\whisper-cli.exe` by absolute path, no shell, an
argument list, hidden window, owned working directory, and one Windows Job
Object. Arguments select the pinned model/WAV, explicit `pt/en/es`, CPU-only,
text-file output, no timestamps, no diagnostic printing, zero temperature and
zero temperature increment, beam size 5, no fallback, no cross-session context,
and no translation. Expected output is only the attempt's UTF-8 `result.txt`,
at most 256 KiB and 100,000 characters; stdout/stderr are drained with bounded
buffers and never written to logs. Nonzero exit, absent/oversized/malformed
output or deadline expiration is a typed failure. Cancellation terminates the
job, waits for exit, then deletes files. No obsolete attempt can stage text.
The exact argument list is checked against the pinned CLI in integration tests.

`OutputPolicy` only trims boundary whitespace, normalizes Unicode/line endings,
and applies the established deterministic punctuation/spacing rules covered by
`Tests/Fixtures/output-corpus.json`. It preserves vocabulary, anglicisms,
meaning, and explicit language; it never translates or rewrites. Existing
fixtures are referenced read-only. New speech fixtures are owned/licensed and
their reference transcripts, WER normalization, and anglicism annotations are
committed before inference quality is measured.

### Exact target identity and clipboard recovery

Capture foreground HWND/PID/process creation time and focused child before
any Resenha UI. `TargetBroker` maintains a focus-change generation using UIA
and WinEvent observations and samples the focused element's runtime ID,
password/read-only/editability state and available selection/caret identity.
Request/response IPC uses an anonymous inherited local pipe, a protocol version,
attempt ID, bounded metadata-only messages, and no network listener. The broker
runs COM work on an MTA thread outside WPF/hook/audio threads. A 300 ms timeout
kills its job and marks automatic insertion unavailable for that attempt;
restart only before a later attempt. [UI Automation threading requirements](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-threading).

The initial probe is accepted only if foreground/child identity and focus
generation stay unchanged across the press/snapshot interval. If unavailable,
dictation may still produce clipboard text, but its target is explicitly
`Unknown` and cannot be automatically pasted. The same policy applies to
password, protected, elevated, inaccessible or noneditable targets. A browser's
shared child HWND is insufficient: distinct UIA runtime IDs and focus
generation distinguish input, textarea, and contenteditable fields. If the
provider cannot distinguish them, use clipboard recovery.

`MouseActivityMonitor` installs `SetWindowsHookEx(WH_MOUSE_LL)` on the dedicated
input message-loop thread at app startup, before dictation becomes ready.
Its bounded callback observes physical button down/up events, ignores injected
events, and queues attempt-scoped target invalidation; it records no coordinates
or click history and always calls `CallNextHookEx` without suppressing input.
Call `UnhookWindowsHookEx` on suspend and shutdown before stopping that thread;
reinstall on resume before rearming dictation. Installation failure or observer
loss marks target identity unknown and permits clipboard-only recovery until
the observer is restored; it never silently leaves automatic paste enabled.

Any observed foreground/field change after capture permanently invalidates
automatic insertion for that attempt, even if the user later returns. A caret
or selection change where exposed also invalidates it. Non-shortcut keyboard
input or mouse button activity during the attempt invalidates the target
conservatively, covering providers without selection events. Immediately
before dispatch, recheck the complete identity, current focused element,
generation, normal integrity/desktop, and clipboard token. An HWND/PID reused
by a new process fails identity. Do not activate windows, call
`SetForegroundWindow`, restore a stale selection, or use `ValuePattern.SetValue`.

Commit the completed Unicode text on an STA clipboard context using
`CF_UNICODETEXT`, five bounded attempts within 500 ms. Read back exact text and
the [clipboard sequence](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclipboardsequencenumber)
after immediate rendering. A failed write leaves text in the app with Copy
again and no paste. Clipboard replacement after commit also prevents paste;
do not overwrite the user's newer clipboard automatically. Manual Copy again
is an explicit user action and never triggers a delayed paste.

Only when physical shortcut modifiers are up and all checks still pass,
issue one Ctrl-down/V-down/V-up/Ctrl-up batch through `SendInput`. Fewer than
four accepted events is `ManualPaste`; an exact count is `Dispatched`, not
proof of editor acceptance. Cleanup releases only synthetic keys left down by
this batch and never keys currently held physically. UIPI/protected/elevated
destinations remain manual; the manifest uses `asInvoker`, never administrator
or `uiAccess`. No automatic insertion retry is allowed, including ambiguous
success. UIA validation and SendInput are not an atomic transaction, so a
residual last-instant focus race cannot be advertised as impossible; event
generation checks, immediate recheck and physical race tests are mandatory.
[SendInput limitations](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput).

### Packaging, Windows workflow, and exact-artifact evidence

Public distribution is a **per-user EXE installer built with Inno Setup
6.7.3**, fixed AppId, `PrivilegesRequired=lowest`, x64-only product guard,
no service, scheduled task, startup entry, driver, or updater. The
[6.7.3 license](https://raw.githubusercontent.com/jrsoftware/issrc/is-6_7_3/license.txt)
allows commercial use under its stated conditions; retain notices. The
self-contained folder/internal ZIP is a development intermediate, not the
website download. Installer/uninstaller removes owned installed files and
offers an explicit Remove model and settings option, selected by default;
it never removes imported source files, user documents, or clipboard content.
All running Resenha children must exit before removal. Paths containing spaces
and non-ASCII names are part of installation/removal QA.

The build location is an **owner-controlled physical Windows 11 x64 host**,
with a separate physical Windows 10 22H2 installation for compatibility QA;
one dual-boot physical machine may fulfill both OS runs. No such host is
asserted to exist yet. Its identity, permission to use it, exact toolchain and
certificate availability are external prerequisites. There is no recurring
GitHub-hosted Windows runner or automatic release job in this MVP. Windows
scripts serialize with a host-local named mutex and at most two native build
workers. Routine PR CI remains lightweight Ubuntu with five-minute timeout,
concurrency cancellation and no application/native build; the new
`windows-contracts.yml` runs only site/release-schema/fixture-contract checks.

| Gate | Command/location and evidence |
| --- | --- |
| Mac/site policy | `~/.local/bin/mac-gate node --test Scripts/site.test.mjs Scripts/windows-release.test.mjs`; portable Core tests, when toolchain is available, also run through `mac-gate`. No invented root `npm run preflight:ci`, no `next build`, and no Codespace dependency. |
| Windows source gate | `pwsh -NoProfile -File Scripts/windows/preflight.ps1`; exact SDK/tool checks, locked restore, compile/analyzers with warnings as errors, format verification, MSTest core/platform suites and real pinned CLI/corpus run. Missing tools/model/fixtures or skipped required tests fail; exit codes propagate. |
| Candidate build | `pwsh -NoProfile -File Scripts/windows/build-release.ps1 -Version <version>`; requires a clean checkout at recorded task source SHA, exact submodule/pins and passing Windows preflight, then self-contained publish, native build, dependency inventory, signatures and installer. |
| Final release verification | `pwsh -NoProfile -File Scripts/windows/verify-release.ps1 -Artifact <path> -Evidence <json>`; recomputes hashes, validates signature chains/timestamps, scan reports and physical matrix. Any missing/mismatched proof fails. Physical evidence is collected with `collect-physical-evidence.ps1` plus the recorded human protocol, never invented by a successful script exit. |
| Site promotion | `node Scripts/windows/promote-release.mjs --manifest <path> --download-report <path>` generates the allowlisted public evidence projection only from a fully verified candidate plus hosted-byte proof. It never uploads, submits a form, edits CF Gauss, or publishes automatically. Source/release/site verification stays on the task's single branch/PR. |

Build manifest inputs include exact SDK/runtime, compiler/linker, Windows SDK,
CMake/PowerShell/Inno versions, dependency locks, all native options, source
commit and submodule commit. Capture those before build; no guessed toolchain
entry is permitted. Default output paths are
`artifacts/windows/<version>/<source-sha>/app/`,
`Resenha-<version>-windows-x64-setup.exe`,
`Resenha-<version>-windows-x64-setup.exe.sha256`,
`release-manifest.json`, and `reports/`. These are generated and ignored.

Signing uses an available **publicly trusted Authenticode publisher certificate
through the Windows certificate store/hardware provider**, SHA-256 and RFC
3161 timestamping. The configured expected publisher identity and certificate
thumbprint must match; no PFX/private key enters source or logs. Sign Resenha
PEs/native dependencies that lack an accepted vendor signature, preserve and
verify legitimate vendor signatures, sign the installer/uninstaller, then
verify every shipped PE and the final package. Self-signed development roots
never satisfy release. Certificate absence blocks distribution; this design
does not authorize a certificate purchase or a paid signing service. It does
not depend on Azure Artifact Signing eligibility for a Brazilian publisher.

The immutable artifact sequence is: publish payload → sign payload → package
with signed uninstaller → sign installer → compute final SHA-256 → scan the
final installer and its extracted payload → install/run/remove those exact
bytes on both physical OS targets → complete release dossier → upload those
bytes at the authorized publication step → download through the browser and
verify hosted hash/Mark of the Web → enable the site. No repackaging/signing
after scan/QA. Any byte change invalidates downstream evidence.

`release-manifest.json` has schema version 1 and the following required groups:

| Group | Required data and invariant |
| --- | --- |
| Identity | `platform=windows`, `architecture=x64`, version, exact filename/byte length/SHA-256, source commit, whisper commit, model name/size/hash, OS version/build predicates and CPU flags. Expected immutable URL: `https://github.com/luisroquette/resenha/releases/download/windows-v<version>/Resenha-<version>-windows-x64-setup.exe`. |
| Build and payload | `buildReport` path/hash, UTC time, host/toolchain versions, preflight source SHA and results, complete shipped file inventory with path/size/hash. The report contains no secret, transcript, or personal machine/user identifier. |
| Signatures and scan | Per-PE and installer `Valid` Authenticode status, publisher/certificate identity, chain result, SHA-256 digest and timestamp verification; Defender engine/platform/signature versions, signature time, scan times, artifact hash, extracted-payload inventory hash, complete reports and zero detections/remediations. Nonzero exit, missing/old definitions over 24 hours, partial scan or detection fails. |
| Physical QA | Both required OS releases/builds, x64/CPU/RAM/microphone, final installer hash, source/app/model identity, standard-user install/offline loop/Notepad/Chrome/ABNT2/AltGr/focus race/device recovery/ten cycles/uninstall outcomes, report references/hashes and verifier identity. `passed` without the underlying observations is invalid. |
| Hosting and integrity | Versioned URL plus actual downloaded size/SHA-256 and timestamp, browser/Mark-of-the-Web/SmartScreen outcome, immutable report references and report hashes. The manifest itself is a separate release asset with an external checksum; it never contains its own hash or the hash of a report that embeds the final manifest hash. |

Defender scans use updated definitions and remediation disabled; inspect both
exit status and detailed detection results. A clean scan does not prove
universal safety. SmartScreen may still warn for a valid new publisher/artifact;
record the actual outcome and correct publisher display, and never promise
warning-free installation or tell users to disable protection. Detection or
policy-enforced denial blocks release; a reputation-only warning is disclosed
in the release record and installation documentation. [SmartScreen guidance](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).

The source SHA identifies the immutable native candidate. Later website-only
evidence additions may have a newer commit, whose diff must leave the Windows
source, pins, fixtures, and build inputs identical to the candidate; otherwise
rebuild and rerun the artifact gates. Record this tree comparison and the
latest PR SHA separately. Before integration, require applicable current-SHA
checks and the owner's Vercel Preview gate where configured; the present
repository contains no Vercel configuration, so a nonexistent check cannot be
reported green or replaced with a GitHub Pages assertion. Resolve the real
deployment/check configuration during implementation without creating another
provider or spending on a runner automatically.

### Platform-aware site and unchanged macOS target

Add `windows` as `planned`, URL/evidence `null`, to `site/release.mjs`.
`site/windows-release-evidence.json` starts with no successful release and is
filled only by the promotion verifier. `resolveDestination` validates Windows
against the schema/allowlist and exact installer extension/platform/version/
source/hash/signature/scan/physical/hosting identities. Missing, malformed,
cross-platform, stale-source or contradictory proof leaves the Windows slot
disabled with a concrete unavailable label. Metadata is a checked projection
of retained reports, not proof created by assigning `passed: true`.

`site/download-platforms.mjs` stores immutable validated platform configs
`{platform, version, formId, formUrl, redirectUrl, artifactUrl, artifactSha256}`.
The selected Windows solution is a **dedicated CF Gauss Windows form and
dedicated trusted redirect**, requiring name, email, and WhatsApp. Their real
IDs/URLs must be provisioned and verified in the authorized form workflow;
until then Windows config remains null. Reuse the existing macOS form/redirect
unchanged for macOS. Never invent a query parameter, reuse the Mac redirect
for an EXE, or expose an arbitrary caller-provided artifact URL.

`openDownloadGate(platform)` resolves only a verified allowlisted config and
freezes it for that dialog session. Create a fresh iframe/window identity for
each opening; a local gate generation owns its message handler and redirect
timer. Closing/reopening/switching destroys the old iframe, removes its
handler and cancels its timer. Accept exactly the trusted CF Gauss origin,
current iframe `event.source`, expected message source, selected form ID, and
documented success event while the dialog is open. Process success once and
redirect only to that session's verified form redirect. Height messages are
bounded and never count as completion. Analytics carries platform/version/form
ID only, no name/email/phone, audio, or transcript.

Verify that CF Gauss validates all three required fields server-side and emits
success only after accepted submission. Automated tests use intercepted form
responses and synthetic inputs, covering blank fields, wrong origin/window/
form, forged/malformed event, duplicate success, stale close/reopen, switch
platform and wrong artifact. Existing macOS fixtures remain required. A final
authorized hosted-flow smoke verifies the redirect lands on bytes with the
manifest hash; HTTP 200 alone cannot pass. This is a website lead gate, not
access control over a public GitHub release URL.

Update `site/index.html`, `site/styles.css`,
`site/alternativa-wispr-flow/index.html`, `site/privacy/index.html`, and
`docs/PRIVACY.md` for the actual Windows status, exact OS/CPU requirements,
mandatory WhatsApp disclosure, local storage/microphone behavior and manual
paste limitation. Existing screenshots remain labeled as macOS; no Windows
availability or parity copy precedes matching evidence. Refresh the stale
browser audit to current behavior and include platform config/release evidence
in its fingerprints.

Do not modify `Sources/WhisperKey/**`, `Tests/WhisperKeyTests/**`,
`WhisperKey.xcodeproj/**`, `project.yml`, `Config/**`, `Frameworks/**`,
`AppStore/**`, Mac release scripts, the whisper.cpp submodule pin, or existing
output fixtures. Sharing means behavioral contracts, upstream source pin and
read-only fixtures; the Mac Swift implementation and Windows C# implementation
remain independent. macOS artifact validation/notarization and Windows
Authenticode evidence are separate branches of the same website release
policy. The known external prerequisites remain Windows host/physical runs,
trusted certificate and exact CF Gauss Windows form/redirect; none has been
completed by this architecture document.

## Implementation Process

Launch one foreground agent per step, passing the **current task-file path**
and that step's sub-task-file path. Use its own **Model** capability tier and
**Agent**, implement exactly that step, and launch independent ready steps in
parallel. The orchestrator resolves the task's current draft/todo/in-progress
location when passing it; sub-task paths remain stable. No tier selection
authorizes a paid API/provider change. Run the **reviewer agent once per phase**
at that phase's **Reviewer model**, after all its outputs/tests are available;
resolve findings within the same phase before accepting its milestone.

**Depends on is normative:** every listed predecessor must finish before the
step starts. **Parallel with lists non-exhaustive examples**, not additional
prerequisites or permission to ignore dependencies. Listed partnerships are
symmetric; other independent ready steps may overlap within the concurrency
cap and file-ownership rules. The table lists actual artifact dependencies,
not blanket phase barriers.
A phase groups an independently reviewable milestone; an independent later
step may start once its listed dependencies and required interface review are
complete. Cap concurrent implementation agents at **5** (the currently
available runtime may impose a lower cap). Serialize edits to shared
`Contracts.cs`, `NativeMethods.cs`, project files and evidence schemas through
their owning agent; parallel agents own distinct adapter/test files. Step 02
owns the common project/interop scaffolding; step 08 owns ChildProcessJob;
step 12 owns final composition. Do not run overlapping gates: Mac checks use
`mac-gate`, Windows scripts use the host-local mutex and two native workers.

All paths, commands and tests newly named below are **implementation work to
create**, not claims that they already exist or passed. No step in this
planning pass executes app code, signing, release publication, external form
changes or deployment. During implementation use the dedicated task branch
and single PR, inspect real checks/provider configuration, and preserve every
protected macOS path from the architecture. Native candidate inputs freeze
before step 17; later site-only changes need an explicit unchanged-input tree
comparison. A failure that changes candidate bytes restarts signing/hash/scan/
both physical OS checks/hosting proof. Missing hardware, signing certificate,
form, authority or check configuration is a recorded blocker, never a pass.

### Parallelization Overview

```text
Phase 1   [01 docs] || [02 solution/contracts]-->[03 evidence schema]
Phase 2   [02]-->[04 key] || [06 audio] || [07 model] || [08 whisper]
          [02,04,08]-->[05 target]
Phase 3   [04,06,07,08]-->[09 coordinator]
          [04,05]------->[10 clipboard]
          [02]---------->[11 UI/settings]
          [05,06,07,08,09,10,11]-->[12 composition]
Phase 4   [12]-->[13 package] || [03,12]-->[14 verifier/CI]
          [03]-->[15 site gate]; [01,15]-->[16 copy/browser]
Phase 5   [13,14]-->[17 signed/hash/scan]-->[18 physical OS QA]
          [15,16]----------------------->[19 real form] (parallel)
Phase 6   [18]-->[20 publish + hosted proof]
          [16,19,20]-->[21 promote + hosted form smoke]-->[22 final gates]
```

The diagram groups branches for readability; the table defines every exact
prerequisite and examples of parallel partners. Phase 2's initial adapter
wave has width four (04, 06, 07, 08); step 05 waits for both 04 and 08.
The execution peak remains capped at five: for example, independent ready
step 03 or 11 may overlap that four-step wave across phase boundaries.
Nominal dependency-critical chain: **02 → 08 → 05 → 10 → 12 → 13 → 17 → 18
→ 20 → 21 → 22**. The 04/06/07/08 → 09 branch and verifier 14 can become
critical by duration; real form 19 is an independent external blocker for 21.
No duration-based critical-path guarantee is claimed.

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | 1 | sonnet | developer | None | 02, 03 | `.specs/sub-tasks/build-windows-mvp/01-specs-and-evidence-protocol.md` |
| 02 | 1 | opus | software-architect | None | 01 | `.specs/sub-tasks/build-windows-mvp/02-solution-and-boundary-contracts.md` |
| 03 | 1 | opus | developer | 02 | 01 | `.specs/sub-tasks/build-windows-mvp/03-release-evidence-schema.md` |
| 04 | 2 | opus | developer | 02 | 06, 07, 08 | `.specs/sub-tasks/build-windows-mvp/04-keyboard-shortcut-lifecycle.md` |
| 05 | 2 | opus | developer | 02, 04, 08 | 06, 07 | `.specs/sub-tasks/build-windows-mvp/05-target-broker-and-mouse-observer.md` |
| 06 | 2 | opus | developer | 02 | 04, 05, 07, 08 | `.specs/sub-tasks/build-windows-mvp/06-wasapi-audio-and-resampling.md` |
| 07 | 2 | opus | developer | 02 | 04, 05, 06, 08 | `.specs/sub-tasks/build-windows-mvp/07-owned-storage-and-verified-model.md` |
| 08 | 2 | opus | developer | 02 | 04, 06, 07 | `.specs/sub-tasks/build-windows-mvp/08-pinned-whisper-process-and-corpus.md` |
| 09 | 3 | opus | developer | 04, 06, 07, 08 | 10, 11 | `.specs/sub-tasks/build-windows-mvp/09-coordinator-and-output-policy.md` |
| 10 | 3 | opus | developer | 04, 05 | 09, 11 | `.specs/sub-tasks/build-windows-mvp/10-clipboard-and-single-insertion.md` |
| 11 | 3 | sonnet | developer | 02 | 09, 10 | `.specs/sub-tasks/build-windows-mvp/11-native-presentation-preferences-and-memory-result.md` |
| 12 | 3 | opus | developer | 05, 06, 07, 08, 09, 10, 11 | None | `.specs/sub-tasks/build-windows-mvp/12-runtime-composition-and-native-preflight.md` |
| 13 | 4 | opus | developer | 12 | 14, 15, 16 | `.specs/sub-tasks/build-windows-mvp/13-installer-and-signing-pipeline.md` |
| 14 | 4 | opus | developer | 03, 12 | 13, 15, 16 | `.specs/sub-tasks/build-windows-mvp/14-release-verifier-and-lightweight-ci.md` |
| 15 | 4 | opus | developer | 03 | 13, 14 | `.specs/sub-tasks/build-windows-mvp/15-platform-release-and-required-form-gate.md` |
| 16 | 4 | sonnet | developer | 01, 15 | 13, 14 | `.specs/sub-tasks/build-windows-mvp/16-site-copy-privacy-and-browser-audit.md` |
| 17 | 5 | sonnet | developer | 13, 14 | 19 | `.specs/sub-tasks/build-windows-mvp/17-signed-candidate-hash-and-scan.md` |
| 18 | 5 | sonnet | reviewer | 17 | 19 | `.specs/sub-tasks/build-windows-mvp/18-physical-windows-acceptance.md` |
| 19 | 5 | opus | developer | 15, 16 | 17, 18 | `.specs/sub-tasks/build-windows-mvp/19-verified-windows-form-configuration.md` |
| 20 | 6 | sonnet | developer | 18 | None | `.specs/sub-tasks/build-windows-mvp/20-authorized-artifact-publication-and-hosted-proof.md` |
| 21 | 6 | opus | developer | 16, 19, 20 | None | `.specs/sub-tasks/build-windows-mvp/21-site-promotion-and-hosted-form-smoke.md` |
| 22 | 6 | sonnet | tech-lead | 21 | None | `.specs/sub-tasks/build-windows-mvp/22-current-sha-integration-and-release-proof.md` |

### Phase Overview

Checklist references describe the scope demonstrated at each checkpoint;
adapter/contract evidence does not mark the corresponding final physical or
hosted acceptance complete. Rubric names below reference the single task-level
Acceptance Criteria rubric; no independent scoring configuration is added.

#### Phase 1 — Verifiable contracts and pinned solution

**Steps:** 01, 02, 03
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

The settled specification, buildable inert solution, boundary tests and fail-closed release fixtures can be reviewed and committed. Run documentation/schema/portable tests through mac-gate and native scaffold compile on the authorized Windows host. Missing host is recorded, not counted as a compile pass.

**Checklist items:**

- HR-1, HR-2, HR-3 (design/contracts and blocked-release behavior; runtime claims remain pending)

**Rubrics:**

- Local multilingual quality
- Windows distribution readiness
- Truthful site integration

#### Phase 2 — Isolated native input, capture and inference

**Steps:** 04, 05, 06, 07, 08
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

Each adapter runs through its test harness: bounded key edges, isolated target inspection, owned interval audio, verified model leases and real pinned CLI/corpus. Shared contract files are frozen; hook/job interop edits are coordinated. This is a tested adapter milestone, not physical full-app acceptance.

**Checklist items:**

- CK-1, CK-2, CK-3, CK-4, CK-5 (adapter contracts); HR-1

**Rubrics:**

- Dictation loop reliability
- Local multilingual quality

#### Phase 3 — Operable native dictation application

**Steps:** 09, 10, 11, 12
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

The composed WPF app performs the local loop and every named recovery with Windows preflight green; portable lifecycle tests and Windows integration suites prove ordering, finite work, single instance, RAM-only last result and cleanup. Physical final-package acceptance remains Phase 5.

**Checklist items:**

- CK-1, CK-2, CK-3, CK-4, CK-5; HR-1, HR-3

**Rubrics:**

- Dictation loop reliability
- Local multilingual quality

#### Phase 4 — Packaging and unavailable-by-default website

**Steps:** 13, 14, 15, 16
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

Installer/verifier/promotion scripts and lightweight CI run their contract tests; site/browser tests preserve all three mandatory fields and unchanged macOS routing. Windows remains planned with null real evidence/config until external prerequisites are satisfied. No unsigned development build or synthetic fixture can activate it.

**Checklist items:**

- CK-7, CK-8 (tooling/negative gates), CK-9, CK-10 (automated contracts); HR-1, HR-2, HR-3

**Rubrics:**

- Windows distribution readiness
- Truthful site integration

#### Phase 5 — Exact signed candidate and physical acceptance

**Steps:** 17, 18, 19
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

One frozen signed installer has matching hash/complete scan and real normal-user install/offline speech/recovery/removal evidence on both physical OS targets. Corpus/ten-cycle thresholds pass. Dedicated form/redirect is real and server-validated. Without hardware/certificate/form evidence this phase remains blocked while independent work completes.

**Checklist items:**

- CK-1, CK-2, CK-3, CK-4, CK-5, CK-6, CK-7, CK-8, CK-10 (real form configuration); HR-1, HR-2, HR-3

**Rubrics:**

- Dictation loop reliability
- Local multilingual quality
- Windows distribution readiness
- Truthful site integration

#### Phase 6 — Authorized publication and persisted site evidence

**Steps:** 20, 21, 22
**Reviewer model:** opus

**Acceptance Criteria that should be fulfiled:**

Only with valid external-action authority publish the exact candidate, verify browser-downloaded hash/Mark of the Web/SmartScreen, complete manifest, promote site evidence and prove hosted required-form routing. Current-SHA canonical/remote gates precede integration; actual main CI/deployment and final download evidence close the task. A blocked release remains incomplete.

**Checklist items:**

- CK-6, CK-7, CK-8, CK-9, CK-10; HR-1, HR-2, HR-3

**Rubrics:**

- Windows distribution readiness
- Truthful site integration
