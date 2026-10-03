# SPEC-017 — Sandboxed text insertion service

Status: superseded by SPEC-021 on 2026-10-03. Retained as the historical Store design; it is not registered by the direct-distribution bundle.

## Problem

Mac App Store apps must enable App Sandbox. Apple documents Accessibility API use as incompatible with sandbox, and simulated `Command-V` is not an acceptable Store architecture for this product.

## Contract

Resenha advertises a sandbox-safe macOS Service with no input type and a plain-text return type. A compatible text editor invokes the service from its responder chain, waits while Resenha records/transcribes, then inserts the returned string at its current selection or cursor.

## Interaction

1. The service shortcut is pressed and held in a compatible editable field.
2. Resenha starts capture and shows the passive listening HUD.
3. Input Monitoring observes only the configured shortcut release.
4. Resenha stops capture, transcribes locally and writes plain text to the service pasteboard.
5. The requesting app reads the returned pasteboard and replaces its active selection.

The service timeout must cover the maximum supported recording plus inference and must fail with a bounded, user-visible error. The provider must never block the main actor or deadlock AppKit's service connection.

## Compatibility

- Use public `NSServices`, `NSApplication.servicesProvider`, `NSPasteboard` and listen-only input APIs.
- Do not call `AXIsProcessTrusted`, `AXUIElement`, `CGEvent.post` or activate another app in the Store target.
- Default shortcut must be a valid Services key equivalent; user customization uses macOS Keyboard Shortcuts/Services or a tested public mapping.
- Keep clipboard recovery independent from service return data.

## Acceptance

- `SERVICE-001`: a fixture provider returns text to an `NSTextView` through the Services responder contract.
- `SERVICE-002`: holding the shortcut produces exactly one start and release pair.
- `SERVICE-003`: timeout, cancellation and empty transcript return no placeholder text and leave the next invocation usable.
- `SERVICE-004`: Store target contains no Accessibility symbols or post-event path.
- `SERVICE-005`: physical cross-app matrix passes from a Release sandbox build.
