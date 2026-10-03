# Resenha product site evidence

Status: current Store-launch site, 2026-10-02

## Product truth

- One macOS product: Resenha 1.0, arm64, macOS 14+.
- Swift/SwiftUI, AVFoundation, AppKit Services and embedded whisper.cpp.
- App Sandbox; no Accessibility permission, Electron, Python, backend, account, analytics or paid API.
- Local model download is disclosed as the only required network operation.
- MIT license and public-source destination remain truthful release-state slots until verified.

## Visual assets

- Brand mark and app icon come from the approved Resenha V2 source.
- Six product screens are lossless WebP exports of native SwiftUI test renders at the original 1520:1120 ratio.
- The horizontal gallery uses `object-fit: contain`; no screenshot is cropped, stretched or translated.
- `resenha-flow.mp4` is a 1440×900, 7.3-second demonstration composed from the app's real HUD state renders.
- `resenha-settings.mp4` is a 1440×900, 9.37-second tour of full native settings renders.
- Both videos use H.264, no audio, native controls, posters and inline playback.

The flow video is a disclosed interface demonstration, not a claim of live microphone capture. The site includes no competitor assets, generated testimonials, fabricated ratings or unverified download link.

## Automated gate

Command:

```sh
~/.local/bin/mac-gate node Scripts/site.test.mjs
```

Result: 37/37 passing. Coverage includes destination fail-closed behavior, URL/evidence validation, secure preview confinement, root/subpath serving, asset availability, semantic content, two video elements, release-slot uniqueness and absence of obsolete cloud/API claims.

## Manual inspection

- Desktop Safari: hero hierarchy, native HUD, product video sizing and dark-section contrast inspected.
- Narrow Safari window: navigation, hero wrapping, HUD fit and proof-grid stacking inspected.
- Reduced motion disables authored CSS animation and pauses autoplay video through `media.mjs`. Keyboard traversal and screen-reader narration remain release checks.
