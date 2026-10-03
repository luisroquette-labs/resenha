# SPEC-002 — Global hotkey

Status: implemented for direct distribution

## Decision

The user records the push-to-talk shortcut in Resenha. New installations default to **right Option**; existing legacy presets migrate automatically. A listen-only event tap observes the exact chosen press and release anywhere on macOS.

## Requirements

- Accept an ordinary key, a modified key chord, or one left/right modifier key.
- Persist key code, normalized modifiers, side-specific label and modifier-only behavior.
- Apply a changed shortcut immediately without restarting the app.
- Match the exact modifier set and ignore auto-repeat or duplicate edges.
- Suppress no global keyboard event and store no unrelated keystrokes.
- Stop monitoring when permission is lost or the app terminates.
- Re-enable a tap disabled by macOS timeout.

## Permissions

Input Monitoring is required for the global listen-only tap. Accessibility is separately required for insertion; the hotkey remains stopped until all required permissions are ready.

## Acceptance

- Right Option produces exactly one press and one release.
- An arbitrary chord survives app restart and rejects extra modifiers.
- Changing the shortcut in Settings restarts monitoring with the new value.
- No System Settings keyboard-shortcut configuration is part of the product flow.
