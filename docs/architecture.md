# Resenha architecture

Status: direct-distribution architecture implemented; physical cross-app acceptance pending

## Runtime flow

```text
configured global shortcut → listen-only CGEvent tap
        │ press                         │ release
        ▼                               ▼
capture target app → AVAudioRecorder → embedded whisper.cpp
                                            │
                                            ▼
                                  general pasteboard
                                            │
                           reactivate target + Command-V
```

## Distribution shape

One XcodeGen application target (`WhisperKey`, product name `Resenha`) and one unit-test target produce bundle `br.com.luisroquette.Resenha`. The arm64 macOS 14 app uses Hardened Runtime and direct distribution without App Sandbox. It embeds `whisper.xcframework`; no Homebrew, Python, shell, cloud transcription or API key is required.

## Components

| Component | Responsibility | Boundary |
|---|---|---|
| `HotkeyMonitor` | observe the exact user-selected press/release | listen-only; never suppresses events |
| `ShortcutCaptureController` | record and persist a shortcut inside Settings | local events only while recording |
| `AudioRecorder` | capture one temporary 16 kHz mono WAV | deletes stale/current audio |
| `WhisperTranscriber` | serialized embedded inference | local model and Metal/Accelerate |
| `TextInjector` | stage text, restore target focus and post `Command-V` | target, permission and clipboard guards |
| `DictationCoordinator` | own state, cancellation and cleanup | one active attempt; fail closed |
| `TranscriptHistory` | retain up to ten successful texts when enabled | local only; no audio or sync |

## Permissions

- Microphone captures speech only while the shortcut is held.
- Input Monitoring powers the global listen-only event tap.
- Accessibility reactivates the captured application and posts one paste command.

The app requests permissions only after explicit user action and exposes separate recovery destinations. It does not inspect another app's accessibility tree.

## Data lifecycle

- Audio: unique temporary file, deleted after success, failure or cancellation.
- Transcript: kept on the general pasteboard and optionally in a bounded local history.
- Model: persistent local file accepted only after exact size and SHA-256 verification.
- Preferences: local `UserDefaults`; no account or sync.
- Diagnostics: no raw audio or transcript content in logs.

## Validation boundary

Unit tests prove shortcut serialization/matching, permission combinations, clipboard staging and target identity. A signed app with real TCC grants must still prove physical TextEdit insertion, then browser and terminal compatibility. The legacy sandboxed Service design remains documented in SPEC-017 but is not registered in the direct bundle.
