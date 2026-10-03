# SPEC-002 — Global Hotkey

Status: implemented for Store 1.0

## Decision

Store 1.0 uses the macOS Service **Ditar com Resenha** for automatic insertion, with default shortcut **Control + Option + Space**. A listen-only event tap must also start capture directly from the shortcut so dictation never appears dead when macOS has not activated the Service binding. The same monitor observes the matching release. A direct invocation keeps the completed transcript on the clipboard; a compatible Service request additionally returns it to the active field.

## Requirements

- Start from the configured global shortcut whenever permissions are ready.
- Attach both press and release handlers before starting the event tap.
- If a compatible editable field also invokes the Service, coalesce both paths into one recording.
- Arm Service release monitoring after a Services request without duplicating the active press.
- Stop only on the matching key-up transition.
- Suppress no shortcut or unrelated keyboard input.
- Disable monitoring cleanly when the app terminates.
- Re-enable an event tap if macOS disables it because of timeout.

## Permissions

The listen-only event tap requires Input Monitoring. Text return through `NSServices` requires no Accessibility permission. Without Input Monitoring, show the exact missing permission and open System Settings only after explicit user action.

## Edge cases

- Auto-repeat or duplicate flag events: ignore.
- Service invoked while another attempt is active: return a bounded error.
- Permission revoked while running: stop monitoring and expose the error.
- Hotkey pressed during transcription: ignore.

## Acceptance

- Invoking another shortcut alone does nothing.
- One physical press starts one recording; its matching release stops it once.
- A simultaneous Service request and global press still produce exactly one recording.
- The configured Service works in the supported TextEdit, browser and terminal matrix.
