# Resenha Constitution

Status: accepted for macOS M0 and Windows MVP implementation contract; Windows release evidence pending

## macOS product invariant

Resenha is a macOS input method: hold the global shortcut chosen inside the app, speak, release it, and receive the local transcription at the active cursor.

## macOS non-negotiable principles

1. **Local-only:** microphone audio and transcripts never leave the Mac.
2. **Native:** Swift, SwiftUI, AVFoundation, Accessibility event posting, and embedded whisper.cpp. No Electron, Python runtime, or backend.
3. **Invisible workflow:** dictation requires no app switching, file selection, copying, or manual pasting.
4. **Least privilege:** request Microphone, Input Monitoring and Accessibility; never retain or act on keystrokes beyond the configured shortcut and one insertion command.
5. **Ephemeral audio:** M0 deletes audio and generated transcript files after each attempt. A later owner-approved amendment may retain final text locally with an explicit limit and clear action.

## Engineering rules

- Implement only M0 until `CORE-001` passes end to end.
- State transitions must be explicit: `idle → recording → transcribing → inserting → idle`, with `failed → idle` recovery.
- One active dictation at a time. Repeated or overlapping hotkey events are ignored safely.
- Fail closed: no text injection after failed or empty transcription.
- Every non-trivial component has one focused automated check; the end-to-end path has a manual acceptance check.
- Distribution embeds whisper.cpp. The fixed model is installed locally only after exact size and SHA-256 verification.

## Explicit non-goals

No AI rewrite, cloud transcription, login, billing, sync, analytics, ads or hands-free mode in version 1.0.

## Amendment 001 — local recovery (2026-10-02)

After M0 passed physically, the owner authorized a local recovery buffer of the 10 latest successful transcripts. This supersedes only the M0 history non-goal. Audio remains ephemeral; there is no sync, account, backend or analytics. The app must expose history, copy and clear actions, and must place a completed transcript on the clipboard before attempting cross-app insertion.

## Amendment 002 — Store distribution (2026-10-02)

The owner authorized one free, public Mac App Store product with full product-quality presentation. Distribution must not weaken the core privacy promise or silently ship a reduced workflow. The app uses App Sandbox, embeds every runtime dependency, works without Homebrew/Python/API keys and avoids Accessibility APIs. A sandbox-compatible macOS Service is the insertion boundary: the calling editor receives the transcript through its service pasteboard. Obsolete direct targets and duplicate app identities must be removed. App Store submission remains an explicit owner authorization gate after the exact binary, metadata, privacy answers, territories and release mode are shown.

## Amendment 003 — direct distribution and in-app shortcut (2026-10-03)

The owner explicitly replaced the Store shortcut boundary with direct distribution. The user chooses any shortcut inside Resenha, including a single right Option key. Accessibility is required for automatic insertion through a bounded synthetic `Command-V`; App Sandbox and the registered macOS Service are removed. The transcript remains on the clipboard if the target refuses insertion. This amendment supersedes Amendment 002 wherever the two conflict.

## Amendment 004 — independent Windows MVP (2026-10-04)

The accepted [Windows specification](23-windows-mvp.md) extends the local
hold-to-talk workflow with independent C# 14/WPF/Win32/WASAPI adapters and
bundled whisper.cpp CLI. SDK 10.0.401 and Desktop Runtime 10.0.12 are pinned;
native tool versions must be measured on an authorized Windows host. Swift,
macOS artifacts and historical macOS evidence do not prove Windows behavior.

Windows targets Home/Pro 10 22H2 build 10.0.19045 and 11 25H2 minimum build
10.0.26200, x64. AVX2/FMA/F16C/SSE4.2 and OS-enabled AVX state, 8 GiB RAM and
1 GiB free beyond measured payload are required. Windows 10 compatibility QA
does not imply Microsoft/.NET vendor support. No broad x64/ARM guarantee.

Audio and inference remain local; model acquisition is explicit and integrity
verified. Windows has no disk transcript history: last completed text is RAM
recovery until replaced/cleared/exit, with OS clipboard recovery. No account,
backend, paid AI API, telemetry or rewrite. Amendment 001's macOS history does
not authorize Windows history. App-owned audio/result files are ephemeral;
cleanup must validate ownership and preserve imported source/user data.

Exact clipboard commit precedes at most one guarded paste. Failed clipboard
write exposes Copy again; changed/unsafe targets expose manual recovery. The
Windows contract never restores target focus, elevates or promises acceptance
by arbitrary editors. This scoped safety requirement permits manual recovery
when automatic insertion cannot be validated. The website still requires name,
email and WhatsApp through a dedicated verified Windows form/redirect.

[Physical protocol](../testing/WINDOWS-MVP-EVIDENCE.md) requires real speech,
Notepad/Chrome, ABNT2/AltGr, all failure paths and ten cycles on each OS.
[Release protocol](../testing/WINDOWS-RELEASE-EVIDENCE.md) requires exact-source
signed/timestamped bytes, final SHA-256, complete updated Defender scans,
installation/removal and actual hosted-byte proof before enabling Windows.
Missing host/certificate/form/evidence blocks release; documentation or mocked
tests do not establish possession or publication. Every CK/HR remains an
independent gate on the task's single branch/PR and current applicable checks.

## macOS definition of done

M0 is done only when a locally launched `.app` completes `hotkey → recording → whisper.cpp → text → insertion` in another application, without network access or manual clipboard action.
