# SPEC-023 — Distribuição por canal

Status: accepted and implemented

## Goal

Ship the complete local Resenha experience through Mac App Store and Developer
ID without mixing their permission or insertion boundaries.

## Contract

| Boundary | Mac App Store | Developer ID DMG |
|---|---|---|
| Build | `ResenhaAppStore` / `AppStore` | `WhisperKey` / `Release` |
| Sandbox | required | absent |
| Shortcut | `NSServices`, `Command + Shift + E` | configurable in app, Right Option default |
| Delivery | Service pasteboard completion | clipboard + bounded `Command-V` |
| Accessibility | never requested | required and disclosed |

Both channels embed whisper.cpp and notices, validate the model by exact size and
SHA-256, bound recording and inference time, keep history opt-in, isolate Debug,
and delete transient audio.

## Acceptance

- Generated schemes and Info.plists encode the table above.
- Unit tests cover both shortcut state machines and channel permission policy.
- Release analysis passes for both configurations.
- An App Store archive is accepted only when its embedded source commit matches
  the audited candidate and the release validator passes.
