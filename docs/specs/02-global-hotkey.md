# SPEC-002 — Global hotkey

Status: implemented by distribution channel

## App Store contract

The App Store build uses the macOS Service **Ditar com Resenha**. Uppercase `E` is a valid `NSKeyEquivalent` and maps to **Command + Shift + E**. A listen-only event tap correlates the real Service request with the most recent still-held non-modifier key and stops only on that matching key-up. Text returns through AppKit; Accessibility is not requested.

Users may change the Service shortcut in macOS Keyboard Shortcuts. The app retains one numeric keycode for at most one second, never stores text events and rejects ambiguous admission.

## Developer ID contract

The direct build defaults to **right Option** and lets the user record a key, modified chord or side-specific modifier inside Resenha. It persists keycode, normalized flags, label and modifier-only behavior, then applies changes immediately. Accessibility is required only for guarded insertion into the captured target application.

## Shared requirements

- One physical press starts at most one recording and one matching release stops it once.
- Reject starts from Resenha itself, during an active attempt or without a verified model.
- Ignore auto-repeat, duplicate edges, unrelated releases and extra modifiers.
- Suppress no keyboard input and log no typed content.
- Stop on permission loss or termination; recover a tap disabled by macOS.
- A recording deadline, sleep or session lock clears every latch.

## Acceptance

- App Store: a real Service request inserts through TextEdit, Chromium and Terminal without Accessibility.
- Direct: a custom shortcut survives restart and inserts into the captured target with Accessibility.
- Both: another key release cannot end an armed recording; test execution remains isolated from `/Applications/Resenha.app`.
