# SPEC-002 — Global Hotkey

Status: implemented for Store 1.0

## Decision

Store 1.0 uses the macOS Service **Ditar com Resenha**, with default shortcut **Control + Option + Space**. The user can change the binding in System Settings → Keyboard → Keyboard Shortcuts → Services. The Service invocation starts capture; a listen-only event tap observes the matching release.

## Requirements

- Start only from a real Services request in a compatible editable field.
- Arm release monitoring for the configured Service shortcut only after that request.
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
- One Service request starts one recording; its matching release stops it once.
- The configured Service works in the supported TextEdit, browser and terminal matrix.
