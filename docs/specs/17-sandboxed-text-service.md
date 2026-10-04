# SPEC-017 — Sandboxed text insertion service

Status: active only in the `ResenhaAppStore`/`AppStore` channel; it is not registered by the direct-distribution bundle.

## Problem

Mac App Store apps must enable App Sandbox. Apple documents Accessibility API use as incompatible with sandbox, and simulated `Command-V` is not an acceptable Store architecture for this product.

## Contract

Resenha advertises a sandbox-safe macOS Service with no input type and a plain-text return type. A compatible text editor invokes the service from its responder chain, waits while Resenha records/transcribes, then inserts the returned string at its current selection or cursor.

## Interaction

1. Command + Shift + E (or a user-assigned Service shortcut with a main key) is pressed and held in a compatible editable field.
2. Resenha starts capture and shows the passive listening HUD.
3. Input Monitoring matches the most recent held non-modifier key-down and observes only that key's release.
4. Resenha stops capture, transcribes locally and writes plain text to the service pasteboard.
5. The requesting app reads the returned pasteboard and replaces its active selection.

The service timeout is ten minutes: five minutes maximum capture plus 4m30 maximum
inference, leaving 30 seconds for setup and return. It must fail with a bounded,
user-visible error. Admission is transactional: a rejected or failed start clears
both the pressed interaction and armed release state before returning. AppKit's
provider method is synchronous: when AppKit invokes it on the main thread, the
provider may use one explicitly documented nested run-loop boundary, capped by
`NSTimeout`, so release and coordinator callbacks continue without deadlock.
Provider state is lock-protected and reset after success, failure, empty output,
system interruption or timeout. The ten-minute outer boundary uses monotonic
system uptime; wall-clock corrections cannot shorten or extend a request.

## Compatibility

- Use public `NSServices`, `NSApplication.servicesProvider`, `NSPasteboard` and listen-only input APIs.
- Do not call `AXIsProcessTrusted`, `AXUIElement`, `CGEvent.post` or activate another app in the Store target.
- Default shortcut is the single uppercase key equivalent `E` (Command + Shift + E); customization is owned by macOS Keyboard Shortcuts/Services and must include a non-modifier key.
- Keep clipboard recovery independent from service return data.

## Acceptance

- `SERVICE-001`: the production provider returns text to an `NSTextView` through the Services responder contract.
- `SERVICE-002`: holding the shortcut produces exactly one start and release pair.
- `SERVICE-003`: timeout, cancellation and empty transcript return no placeholder text and leave the next invocation usable.
- `SERVICE-004`: Store target contains no Accessibility symbols or post-event path.
- `SERVICE-005`: physical cross-app matrix passes from a Release sandbox build.
