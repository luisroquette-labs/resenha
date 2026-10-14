# Resenha Constitution

Status: accepted for M0

## Product invariant

Resenha is a macOS input method: hold the global shortcut chosen inside the app, speak, release it, and receive the local transcription at the active cursor.

## Non-negotiable principles

1. **Local-only:** microphone audio and transcripts never leave the Mac.
2. **Native:** Swift, SwiftUI, AVFoundation, channel-appropriate native text delivery, and embedded whisper.cpp. No Electron, Python runtime, or backend.
3. **Invisible workflow:** dictation requires no app switching, file selection, copying, or manual pasting.
4. **Least privilege:** request only the permissions required by the distribution channel; never retain or act on keystrokes beyond the active shortcut and one bounded delivery action.
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

## Amendment 004 — dual distribution channels (2026-10-03)

The owner authorized both full product channels from one source tree. The Mac App Store build is sandboxed, uses `Ditar com Resenha` through `NSServices`, and never requests Accessibility. The Developer ID DMG keeps the configurable in-app shortcut and bounded Accessibility insertion. Both channels preserve local transcription, verified model integrity, clipboard recovery, opt-in history, runtime limits and the same product identity. This amendment controls wherever Amendments 002 and 003 conflict; neither channel is a reduced edition.

## Definition of done

M0 is done only when a locally launched `.app` completes `hotkey → recording → whisper.cpp → text → insertion` in another application, without network access or manual clipboard action.
