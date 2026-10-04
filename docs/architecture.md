# Resenha architecture

Status: dual-channel architecture implemented; physical cross-app acceptance pending

## Distribution channels

One XcodeGen application target produces two release configurations from the same source:

| Channel | Scheme/configuration | Insertion | Permissions |
|---|---|---|---|
| Mac App Store | `ResenhaAppStore` / `AppStore` | AppKit Service response | Microphone + Input Monitoring; sandbox network only for model download |
| Developer ID DMG | `WhisperKey` / `Release` | reactivate target + guarded Command-V | Microphone + Input Monitoring + Accessibility; no sandbox |

Debug uses `br.com.luisroquette.Resenha.Debug` and product `Resenha Dev`, isolating tests, TCC, preferences and LaunchServices from production. Both release channels are arm64, require macOS 14, embed `whisper.xcframework`, include third-party notices and accept a model only after exact size and SHA-256 verification.

## Shared runtime

`HotkeyMonitor` supports two explicit paths. The App Store path starts only from a real Service request and binds release to the exact held non-modifier key. The direct path matches the user-selected shortcut and emits one press/release pair. Neither suppresses input.

`DictationCoordinator` owns capture, transcription, clipboard recovery and terminal state. Delivery is selected at build time: `.appKitService` returns text through `ResenhaServiceProvider`; `.accessibility` uses `TextInjector`. Audio is a temporary 16 kHz mono WAV deleted after every outcome. History starts disabled and retains at most ten texts only after opt-in.

## Runtime bounds

- Capture auto-stops at 5 minutes.
- `whisper_full` aborts cooperatively at 4m30.
- AppKit Service expires at 10 minutes using monotonic uptime.
- Sleep, session lock or event-tap interruption terminates the active attempt.
- Whisper context unloads after 45 idle seconds or memory pressure.

## Security and release invariants

- App Store archive has exactly sandbox, audio-input and network-client entitlements, valid `NSServices`, no Accessibility insertion at runtime and source-commit provenance.
- Developer ID archive has Hardened Runtime, no App Sandbox, configurable hotkey and disclosed Accessibility insertion.
- Release binaries reject `WHISPER_MODEL_PATH`; Debug may use it for tests.
- Model replacement is staged, verified and rollback-safe; resumable downloads never remove the last valid model.
- Archive contains `PrivacyInfo.xcprivacy`, `THIRD_PARTY_NOTICES.md` and both MIT licenses.

## Validation boundary

Unit tests cover both delivery policies, hotkey latches, permissions, model integrity, runtime bounds and test identity. Release validation is channel-specific. Upload may stage an exact validated candidate in App Store Connect, but submission still requires physical Service insertion in TextEdit, Chromium and Terminal plus VoiceOver/macOS 14 evidence. The notarized DMG requires physical direct insertion in the same app matrix.

## Deferred

- Windows client.
- Streaming inference and larger-model benchmarks.
- AI rewrite, cloud transcription, login, billing, analytics or sync.
