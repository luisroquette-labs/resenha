# WhisperKey Constitution

Status: accepted for M0

## Product invariant

WhisperKey is a macOS input method: hold one global hotkey, speak, release it, and receive the local transcription at the previously focused cursor.

## Non-negotiable principles

1. **Local-only:** microphone audio and transcripts never leave the Mac.
2. **Native:** Swift, SwiftUI, AVFoundation, Accessibility, and whisper.cpp. No Electron, Python runtime, or backend.
3. **Invisible workflow:** dictation requires no app switching, file selection, copying, or manual pasting.
4. **Least privilege:** request Microphone, Accessibility, and Input Monitoring only when required; never retain or act on keystrokes beyond the configured hotkey.
5. **Ephemeral audio:** M0 deletes audio and generated transcript files after each attempt. A later owner-approved amendment may retain final text locally with an explicit limit and clear action.

## Engineering rules

- Implement only M0 until `CORE-001` passes end to end.
- State transitions must be explicit: `idle → recording → transcribing → inserting → idle`, with `failed → idle` recovery.
- One active dictation at a time. Repeated or overlapping hotkey events are ignored safely.
- Fail closed: no text injection after failed or empty transcription.
- Every non-trivial component has one focused automated check; the end-to-end path has a manual acceptance check.
- M0 may discover a Homebrew `whisper-cli` and a local model for development. Distribution must embed whisper.cpp and the selected model before it is called self-contained.

## Explicit non-goals

No AI rewrite, filler removal, history, login, billing, sync, analytics, cloud API, hands-free mode, personal dictionary, settings suite, or automatic launch at login.

## Amendment 001 — local recovery (2026-10-02)

After M0 passed physically, the owner authorized a local recovery buffer of the 10 latest successful transcripts. This supersedes only the M0 history non-goal. Audio remains ephemeral; there is no sync, account, backend or analytics. The app must expose history, copy and clear actions, and must place a completed transcript on the clipboard before attempting cross-app insertion.

## Amendment 002 — Store distribution (2026-10-02)

The owner authorized a free, public Mac App Store edition with full product-quality presentation. Distribution must not weaken the core privacy promise or silently ship a reduced workflow. The Store edition must use App Sandbox, embed every runtime dependency, work without Homebrew/Python/API keys and avoid Accessibility APIs. A sandbox-compatible macOS Service is the preferred insertion boundary: the calling editor receives the transcript through its service pasteboard. The existing direct build remains available until the Store path passes the same physical dictation acceptance test. App Store submission remains an explicit owner authorization gate after the exact binary, metadata, privacy answers, territories and release mode are shown.

## Definition of done

M0 is done only when a locally launched `.app` completes `hotkey → recording → whisper.cpp → text → insertion` in another application, without network access or manual clipboard action.
