# SPEC-023 — Windows local dictation MVP

Status: accepted implementation contract; Windows availability and physical acceptance pending.

Authority: [accepted task architecture](../../.specs/tasks/in-progress/build-windows-mvp.feature.md).
The Windows target is independent of the existing Swift application. This document
records requirements, not successful execution, hardware ownership or publication.

## Platform predicates and pinned toolchain

| Boundary | Required predicate |
| --- | --- |
| Windows 10 | Home/Pro 22H2, version `10.0.19045`, x64, with available security updates; earlier releases and LTSC excluded. This is a compatibility target requiring physical QA, not a claim of Microsoft Windows 10 or .NET 10 vendor support. |
| Windows 11 | Home/Pro 25H2, minimum version `10.0.26200`, x64; later releases require a recorded smoke before being named verified. |
| Excluded systems | ARM/ARM emulation, x86, Server, S-mode and Linux. Windows N requires the Media Feature Pack. |
| CPU/memory/storage | AVX2, FMA, F16C, SSE4.2 and OS-enabled AVX state; check both CPU support and OS AVX save/restore state before native inference. 8 GiB RAM and at least 1 GiB free beyond the measured installed payload. No GPU requirement. |
| App | C# 14, WPF, SDK `10.0.401`, self-contained Desktop Runtime `10.0.12`, `win-x64`, `net10.0-windows10.0.19041.0`; the product OS predicates above are stricter than the TFM. No trimming, single-file publishing, Native AOT or Windows App SDK. |
| Tests | Portable `Resenha.Core` on `net10.0`; MSTest.Sdk `4.4.0`, exact dependencies and locked restore. `Windows/global.json` has `rollForward: disable`; execute every dotnet command from `Windows/`. |
| Host inventory | Exact approved Windows SDK, MSVC v143, CMake, PowerShell 7 and Inno Setup `6.7.3` versions/hashes must be measured and locked before build. Host and certificate availability remain pending. |

SDK/runtime patches must be reviewed against current security support before each
release; an unreviewed obsolete patch blocks release. Version pins are accepted
inputs, not evidence that the tools are installed. See [.NET support](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)
and [supported OS matrix](https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md).

## Interaction and finite lifecycle

`Idle → Recording → Transcribing → Inserting → Idle`; cancellation/error visibly
enters `Failed` and returns to `Idle` only after cleanup acknowledgment. One
serialized coordinator owns one AttemptId, recording and inference child job.
Invalidating generation precedes cancellation; stale completions never copy,
paste, change current UI or delete another attempt's files.

Default shortcut: **Left Ctrl + Left Alt + Space**. A dedicated `WH_KEYBOARD_LL`
thread owns press/release, ignores injected events and repeated downs, and probes
registered conflicts with temporary `RegisterHotKey`. The probe cannot detect
all application-private shortcuts. Reject Right Alt/AltGr, modifier-only/Win
chords, F12 and reserved/invalid/occupied combinations. Suppress only the latched
trigger key; unrelated keys/modifiers pass through. Stop on the first required
key release; require every chord key up before rearming. Extra modifiers cancel.
Opening settings, Escape, tray Cancel, lock, suspend and shutdown cancel.

| Deadline | Contract |
| --- | --- |
| Hold/audio | Maximum 120 seconds; under 300 ms produces no inference. Start within 2 seconds; stop acknowledgment within 1 second. Late asynchronous start after release is canceled. |
| Lost release | Independent physical-key watchdog every 100 ms; lost release/max duration cancels and discards instead of transcribing. |
| Inference | 120 seconds from process start; kill child job and wait at most 2 seconds before owned-file cleanup. |
| Target/modifiers | Target broker request 300 ms; all shortcut modifiers up within 2 seconds before any insertion. |
| Clipboard | Five attempts within a total 500 ms budget; write/readback must succeed before paste. |

Unacknowledged audio shutdown fails closed: show Reopen instruction and terminate
rather than labeling a possibly active microphone idle. Busy presses are rejected
visibly, never queued. No automatic retry starts capture/inference. A per-user
mutex prevents duplicate hooks. WPF tray/settings and nonactivating overlay do
not steal editor focus; resume rearms only after hooks and keys are ready.

## Local audio, model and output

WASAPI shared capture uses the selected microphone, never loopback. Negotiate the
actual PCM16/24/32 or float32 mix rate/channel mask; Media Foundation resampler
quality 60 produces mono 16,000 Hz PCM16 WAV. Drain/verify sample and byte counts.
QPC timestamps bound retained samples to the press/release interval; uncertainty,
discontinuity and device loss fail the attempt. Every acquired packet is released.
Empty audio or fewer than 200 ms of 20 ms frames above -50 dBFS RMS is rejected.
This energy threshold is not perfect speech detection; silence must cause no
text, clipboard change or paste.

Use bundled CPU-only `whisper-cli.exe` from whisper.cpp commit
`4979e04f5dcaccb36057e059bbaed8a2f5288315`. The MSVC v143 preset disables native
tuning, BMI2/AVX-VNNI/AVX512, GPU/BLAS/network/server backends and OpenMP, enables
AVX/SSE4.2/AVX2, static ggml and static MSVC runtime; MSVC AVX2 implies FMA/F16C.
Record CMake cache and dependency inspection; `GGML_NATIVE=OFF` alone is not CPU
compatibility evidence. Inference uses at most `min(4, logicalProcessorCount)` threads.

The multilingual model is `ggml-small-q5_1.bin`, exactly **190085487 bytes**,
SHA-256 `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
Only explicit HTTPS Download model/import obtains it; verify size/hash, stage
`.partial` and atomically promote. Preserve an existing valid model on failure.
Verify each lease and hold a read handle denying write/delete during inference.
Download limits: 30-second no-progress and 15-minute total; retries are manual.
Never download executable code at runtime. After model setup, dictation is offline.

Use absolute bundled CLI path, no shell, argument list, hidden window and one
kill-on-close Windows Job Object. Select exactly `pt`, `en` or `es`, no translation,
zero temperature/increment, beam 5, no fallback/context, no-speech threshold 0.6,
suppressed non-speech tokens, UTF-8 text output without timestamps. Read only the
attempt's bounded result file (256 KiB/100,000 characters); drain stdout/stderr
without logging content. Nonzero exit, missing/malformed/oversized output or
timeout is failure. Cleanup covers success, failure, cancel, exit and next start.

Output cleanup is deterministic Unicode/line-ending/spacing/punctuation policy;
preserve vocabulary, anglicisms and meaning. No rewrite or translation. Commit
owned/licensed reference corpus before measuring: at least five utterances each
for PT-BR, EN, ES; WER ≤20% per language and ≥90% annotated anglicism retention
for PT-BR/ES. Include accents, names, mixed terms, silence and empty capture.
No cloud audio, paid AI API, backend, account, telemetry or disk transcript history.

## Clipboard, target identity and recovery

Before any overlay, capture foreground/root/focused HWND, PID/process creation,
session/desktop/integrity, UIA runtime ID, focus generation and available
caret/selection identity. A separate metadata-only local MTA TargetBroker has
no transcript access. Password/protected/elevated/read-only/inaccessible/unknown
targets use recovery. Shared Chrome HWNDs do not establish field identity.
Passive `WH_MOUSE_LL` observes physical button activity without coordinates,
history or suppression; observer failure makes the target unknown.

Any app/field/caret/selection change, non-shortcut typing or physical mouse button
activity permanently invalidates the attempt's automatic insertion even if focus
returns. Recheck full identity, generation, modifier release and clipboard token
immediately before dispatch. Never activate a target, restore focus/selection,
call `SetForegroundWindow` or replace field content with `ValuePattern.SetValue`.

Commit exact `CF_UNICODETEXT` on STA, read it back and bind nonzero clipboard
sequence/text digest to AttemptId. Write failure preserves completed text in RAM
with **Copy again**, and no paste. External clipboard replacement prevents paste
without overwriting newer content. Explicit Copy again copies only, never reruns
inference or delayed insertion. Successful clipboard commit is required before any input dispatch.
No automatic insertion retry is allowed. Successful clipboard commit permits at most one
four-event Ctrl+V `SendInput` batch. Partial dispatch is **ManualPaste**; four
accepted events mean **Dispatched**, not confirmed editor acceptance. UIPI/manual
fallback requires no elevation, `uiAccess` or automatic insertion retry.
UIA recheck and SendInput are not atomic; residual last-instant focus races exist
and require physical race tests. Do not promise automatic insertion certainty.

## Owned data and installation

Install per user to `%LOCALAPPDATA%\Programs\Resenha\`; settings store only schema
version, shortcut, microphone endpoint ID and language in
`%LOCALAPPDATA%\Resenha\settings.json`. Model storage is
`%LOCALAPPDATA%\Resenha\models\ggml-small-q5_1.bin`; session-only WAV/result files
are under `%LOCALAPPDATA%\Resenha\sessions\<attempt-guid>\`. Restrict to the user,
validate canonical ownership and reject reparse-point traversal. Cleanup failure
is visible and blocks readiness. Last completed text stays in RAM until replaced,
cleared or exit; OS clipboard may retain it. See [privacy contract](../PRIVACY.md).

Public artifact: per-user Inno Setup 6.7.3 EXE, fixed AppId,
`PrivilegesRequired=lowest`, x64/OS guards, self-contained runtime; no service,
driver, startup entry, scheduled task or updater. Internal folder/ZIP is not the
public download. Removal exits children, removes installed/owned session files
and offers **Remove model and settings**, selected by default. Preserve imported
source files, documents, unrelated data and clipboard. Test spaces/non-ASCII paths.

A cloud Windows runner may compile, install and uninstall an explicitly named
`UNSIGNED-NOT-FOR-DISTRIBUTION` smoke installer using the exact pinned Inno Setup
compiler. That artifact is ephemeral, is never uploaded or promoted, and proves
packaging mechanics only. It cannot satisfy signature, Defender, microphone,
hotkey, insertion, physical OS or publication acceptance.

An owner-authorized physical-test beta is a separate channel. It may be retained
for one day by a manually dispatched workflow, then published as an explicitly
named `BETA-UNSIGNED` GitHub prerelease for transfer to the owner's Windows host.
The website must say that it is unsigned, may trigger SmartScreen and is not the
final Windows release. Cloud compile/install/uninstall evidence may be shown, but
signature, Defender, microphone, shortcut, insertion and physical acceptance
remain pending until observed on the downloaded bytes. This exception never
promotes the production Windows release state.

## Release truthfulness and evidence producers

All release fields initially pending. A physical owner-controlled Windows 11
host, physical Windows 10 installation (dual boot allowed), approved toolchain,
trusted publisher certificate and dedicated CF Gauss Windows form/redirect are
unestablished prerequisites. Do not acquire paid services or assume eligibility.
Routine CI stays lightweight Ubuntu, no recurring Windows runner/build.

| Gate | Evidence producer and required record |
| --- | --- |
| CK-1 | Coordinator/shortcut tests and physical lifecycle protocol; ten consecutive cycles on each OS, release races and cancellation observations. |
| CK-2 | Audio/model/process tests, offline trace and owned-session filesystem snapshots after every terminal path; no audio/text logs. |
| CK-3 | Locked speech corpus + real CLI integration; references/hashes, per-language WER and annotated anglicism counts; physical language/silence observations. |
| CK-4 | Target/clipboard tests + Notepad/Chrome physical protocol; commit/dispatch ordering, changed field/race, clipboard replacement and RAM recovery. |
| CK-5 | Producer-boundary fault tests and physical recovery matrix; specific action, cleanup and next successful attempt for each named failure. |
| CK-6 | `collect-physical-evidence.ps1` plus human observation dossier for both exact OS predicates, final installer/model hashes, CPU/OS AVX/RAM and real speech. |
| CK-7 | Standard-user clean install/offline/removal dossier; toolchain-free runtime, paths, owned-data options and no orphan process/hook/startup entries. |
| CK-8 | `build-release.ps1` then `verify-release.ps1`; every shipped PE/installer signature and timestamp, final sidecar hash and Defender installer/payload reports. |
| CK-9 | Release/schema negative fixtures + promotion verifier + real browser download report; matching immutable source/artifact/reports, unavailable on missing proof. |
| CK-10 | Site/browser contracts + authorized dedicated-form smoke; required name/email/WhatsApp and trusted origin/window/form/success checks, platform routes and macOS regression. |
| HR-1 | Dependency inventory, local process/network trace, privacy tests and corpus run; no new account/backend/cloud inference/paid API/rewrite. |
| HR-2 | Pending-prerequisite ledger and fail-closed release/site tests; missing host/certificate/evidence keeps Windows unavailable. |
| HR-3 | Source/app/model/report/hash linkage, clean build, latest PR SHA checks, hosted-byte comparison and immutable release dossier; no fabricated pass, bypass or direct main push. |

Commands/scripts named above are implementation contracts until created and run.
Use [physical protocol/template](../testing/WINDOWS-MVP-EVIDENCE.md) and
[release protocol/template](../testing/WINDOWS-RELEASE-EVIDENCE.md); passing this
documentation's Node tests is not Windows execution or release evidence.

Public release order: publish payload → sign payload → package signed uninstaller
→ sign installer → final SHA-256 → updated Defender installer/extracted payload
scan → both physical OS install/run/remove → release dossier → authorized upload
→ browser hash/Mark of the Web/SmartScreen proof → site promotion. Any byte change
invalidates subsequent proof. Valid signatures do not guarantee no SmartScreen
warning; record actual behavior and never instruct disabling protections.

The Windows website slot remains planned/unavailable until matching verified
artifact, source, signature/timestamp, scan, both physical OS reports, hosted
bytes and dedicated form configuration exist. Name, email and WhatsApp stay
mandatory. Freeze selected platform per dialog; reject foreign origin/window,
wrong form, malformed/duplicate/stale success and cross-platform destinations.
Use intercepted synthetic submissions for tests; real submission/publication
needs applicable authority. Public GitHub assets make this a lead gate, not
access control. Do not invent a `?platform=windows` server contract.

Keep the task on one branch/PR. Mac tests use `mac-gate`; Windows commands use
the host mutex. Check real provider/workflow configuration and latest-SHA gates;
do not invent `npm run preflight:ci` or a green Vercel check where absent. Never
run `next build` on Mac. Candidate SHA stays distinct from later site-only SHA;
prove unchanged native inputs or rebuild and repeat artifact gates.
