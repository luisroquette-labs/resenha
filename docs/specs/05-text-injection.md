# SPEC-005 — Text Injection

Status: accepted for M0

Post-M0 amendment: SPEC-012 supersedes clipboard restoration. A completed transcript now remains on the clipboard and enters the bounded local recovery history before insertion.

## Goal

Insert transcription at the current caret in the application that was focused when recording began.

## M0 method

Use a clipboard transaction plus a synthetic Command-V event:

1. Write the transcription to the general pasteboard.
2. Reactivate the application captured when recording began.
3. Confirm that this exact process is frontmost.
4. Post Command-V through Core Graphics only if the clipboard still contains the staged transcription.

This uses the macOS Accessibility event path and maximizes compatibility. Direct `AXUIElement` value/range mutation is deferred because many web and custom editors expose inconsistent writable ranges.

## Requirements

- Target the frontmost application captured before WhisperKey displays UI.
- Never activate a normal WhisperKey window during dictation.
- Leave every completed transcription immediately available to Command-V.
- Do not paste if the user or target app changes the clipboard before insertion.
- Reject empty text.

## Known ceiling

Secure fields, apps rejecting synthetic events, remote desktops, and some terminal modes may refuse injection. M0 reports failure where detectable and keeps the transcription in the clipboard only when paste cannot be confirmed.

## Current acceptance

Insertion works at the caret in TextEdit and one Chromium-based text field. The completed transcript remains on the clipboard after the attempt, as required by SPEC-012.
