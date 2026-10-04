# SPEC-002 — Global Hotkey

Status: implemented for Store 1.0

## Decision

Store 1.0 uses the macOS Service **Ditar com Resenha** as the only start and insertion boundary. Its valid `NSKeyEquivalent` is uppercase `E`, which AppKit maps to **Command + Shift + E**. This avoids the VoiceOver `VO-Space` conflict and the invalid modifier string previously advertised.

The user may replace the Service shortcut in macOS Keyboard Shortcuts with another combination containing a non-modifier key. While enabled, the global listen-only event tap observes non-modifier key-down/key-up transitions and retains only one numeric keycode for at most one second. When AppKit opens a real Service request, the monitor verifies that the recent key is still physically down and observes only its matching release. The transient keycode is cleared on key-up, rejection, disarm, tap interruption or shutdown; event contents and typed text are never retained or logged. An ambiguous snapshot without a recent key-down is rejected. The app does not expose presets that it cannot synchronize with macOS.

## Requirements

- Start only from an active macOS Service request.
- Reject a request originating from the Resenha process and reset its transient release state.
- Attach the release handler before starting the event tap.
- Arm release monitoring from the most recent physical non-modifier key-down that remains held when the Service request arrives.
- Stop only on the matching key-up transition.
- Suppress no shortcut or unrelated keyboard input.
- Disable monitoring cleanly when the app terminates.
- Re-enable an event tap if macOS disables it because of timeout.

## Permissions

The listen-only event tap requires Input Monitoring because it observes global key transitions, even while no Service request is active, to correlate a customizable Service shortcut with its later release. It stores at most one short-lived numeric keycode and no text. Text return through `NSServices` requires no Accessibility permission. Without Input Monitoring, show the exact missing permission and open System Settings only after explicit user action.

## Edge cases

- Auto-repeat or duplicate flag events: ignore.
- Service invoked while another request is active: return a bounded error.
- Service invoked without a held non-modifier key: return an actionable error without recording.
- Rejected admission: roll back both the press state and release latch before another request.
- Permission revoked while running: stop monitoring and expose the error.
- Hotkey pressed during transcription: ignore.

## Acceptance

- Invoking another shortcut alone does nothing.
- One physical press starts one recording; its matching release stops it once.
- One Service request produces exactly one recording and one response.
- The configured Service works in the supported TextEdit, browser and terminal matrix.
