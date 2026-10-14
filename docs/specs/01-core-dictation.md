# SPEC-001 — Core Dictation

Status: accepted for M0

## Problem

File-based Whisper is not a macOS input experience. The user needs voice to behave like a temporary keyboard in the application already being used.

## Goal

While another app owns the focused editable control, holding the configured hotkey records speech. Releasing it transcribes locally and inserts non-empty text at the cursor.

## User story

Given an editable field in a supported macOS app, when the user holds the **Ditar com Resenha** Service shortcut, speaks Portuguese, and releases its main key, the transcription is inserted without changing the active app.

## State machine

| Current | Event | Next | Effect |
|---|---|---|---|
| idle | Service request | recording | requester retains its selection, start capture, show listening UI |
| recording | armed Service key up | transcribing | stop capture, show progress |
| transcribing | non-empty text | inserting | inject text |
| inserting | success | idle | hide UI, delete temporary files |
| any active | failure | failed | show concise error, clean up |
| failed | timeout/dismiss | idle | hide UI |

Hotkey repeats and a new press outside `idle` are ignored.

## Requirements

- `CORE-001`: Execute the full Service flow in Chrome/TextEdit/another editable app.
- `CORE-002`: Preserve the target application through capture and transcription.
- `CORE-003`: Insert nothing for silence or whitespace-only output.
- `CORE-004`: Always remove per-dictation temporary artifacts.
- `CORE-005`: No network request is part of the flow.

## Failure behavior

Missing permission, recorder failure, missing model/CLI, non-zero Whisper exit, and injection failure produce visible status and return to `idle`; they never leave recording active.

## Acceptance

`CORE-001`: In TextEdit, place the caret in a blank document, hold Command + Shift + E, say “Testando o nosso sistema de voz”, release E, and observe that sentence at the caret with no app switch or manual paste.
