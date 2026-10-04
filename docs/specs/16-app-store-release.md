# SPEC-016 — Mac App Store release

Status: active for the `ResenhaAppStore`/`AppStore` channel under Amendment 004.

Previous status: accepted for implementation

## Goal

Publish Resenha as a free, polished, local-first macOS app while preserving the product invariant: hold a shortcut, speak, release and receive text at the active insertion point.

## Channel contract

- Store binary: App Sandbox enabled, Apple Distribution signed, uploaded through Xcode/App Store Connect.
- One product target and bundle identity only; obsolete direct editions must be removed rather than shipped beside it.
- No backend, account, tracking, paid API, API key or Python runtime.
- All required libraries and resources live inside the signed app; the verified model lives inside its sandbox container.
- Marketing may say "on-device" only after a clean-machine/network-off acceptance test.

## Release identity

- Product and Finder display name: `Resenha`.
- Store name: a unique, owner-approved App Store Connect name of at most 30 characters; preferred candidate `Resenha — Ditado por Voz`.
- Bundle identifier: `br.com.luisroquette.Resenha` in the owner's developer team.
- Version `1.0.0`; globally increasing build number.
- Price: free, no in-app purchase.
- Primary category: Productivity. Secondary category: Utilities.
- Minimum OS and CPU support must match the embedded inference engine and be stated on the product page.

## Required gates

1. Sandbox launch and microphone capture work from an archived Release build.
2. No runtime lookup under Homebrew, `/usr/local`, arbitrary home paths or executable environment variables.
3. Store insertion passes in TextEdit, Notes, Safari/Chrome web text fields and Terminal, or unsupported hosts are disclosed before submission.
4. Audio is deleted after every attempt; transcript history remains local, optional and clearable.
5. `codesign`, archive validation, privacy manifest inspection, unit tests and physical smoke tests pass on the exact submitted build.

## Failure policy

- A reduced clipboard-only build is not an acceptable silent fallback.
- If the target does not support service return insertion, keep the completed transcript on the clipboard and show a specific recovery message.
- If App Review rejects a public API or entitlement, record the exact reason, fix the architecture and resubmit; never bypass sandbox or obscure behavior.
- Publication is complete only when App Store Connect reports the version Ready for Distribution and the public product page resolves.

## Non-goals

Windows, cloud transcription, subscriptions, login, AI rewrite, analytics, ads and a paid API are not part of version 1.0.

## Acceptance

`STORE-001`: install the TestFlight/App Store build on a clean Apple Silicon Mac, disconnect the network, invoke the configured Resenha service shortcut in another app, dictate Portuguese with English technical terms, release and see the transcript at the original cursor without opening Resenha or pasting manually.
