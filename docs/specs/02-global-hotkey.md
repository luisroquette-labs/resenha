# SPEC-002 — Global Hotkey

Status: accepted for M0

## Decision

M0 uses **Right Option** as push-to-talk. It has a distinct hardware key code (`61`) and reliable down/up semantics. Fn is deferred because macOS can reserve or transform it according to Keyboard settings.

## Requirements

- Observe global modifier events using a Core Graphics event tap.
- Start only on the first Right Option down transition.
- Stop only on the matching release transition.
- Suppress neither ordinary Option shortcuts nor unrelated keyboard input.
- Disable monitoring cleanly when the app terminates.
- Re-enable an event tap if macOS disables it because of timeout.

## Permissions

The listen-only event tap requires Input Monitoring; text injection requires Accessibility trust. Without either permission, show the exact missing permission and open System Settings only after explicit user action.

## Edge cases

- Auto-repeat or duplicate flag events: ignore.
- App starts while key is already down: wait for a full release before accepting a press.
- Permission revoked while running: stop monitoring and expose the error.
- Hotkey pressed during transcription: ignore.

## Acceptance

- Pressing Left Option does nothing.
- Holding Right Option emits one `pressed` event; releasing emits one `released` event.
- Events are received while TextEdit, Chrome, and Terminal are frontmost.
