# Resenha architecture

Status: Mac App Store architecture implemented; physical cross-app acceptance and Store signing pending

## Runtime flow

```text
Focused editable field
        │ macOS Service: "Ditar com Resenha"
        ▼
ResenhaServiceProvider ──► DictationCoordinator ──► FloatingPanelController
        waits                    │
                                 ├──► AVAudioRecorder ──► temporary 16 kHz mono WAV
shortcut release ◄── CGEvent tap│
                                 ├──► embedded whisper.cpp XCFramework
                                 │       └──► local verified model + Metal/Accelerate
                                 ├──► general pasteboard recovery copy
                                 └──► service response pasteboard
                                             │
                                             ▼
                                  requesting app inserts text
```

## Distribution shape

One XcodeGen app target (`WhisperKey`, product name `Resenha`) and one unit-test target produce one bundle identity: `br.com.luisroquette.Resenha`. There is no second direct target or legacy app edition. The app is arm64, requires macOS 14, runs as a menu-bar utility and enables App Sandbox.

The signed bundle embeds the arm64 `whisper.xcframework`. It does not invoke Homebrew, Python, `Process`, a shell or an external executable. The model is downloaded once from the official Hugging Face repository into the sandbox Application Support container, then accepted only after exact byte-size and SHA-256 verification.

## Components

| Component | Responsibility | Boundary |
|---|---|---|
| `ResenhaServiceProvider` | receive a native Services request and return plain text | one request, ten-minute timeout, no focus manipulation |
| `HotkeyMonitor` | observe only the armed service shortcut release | listen-only; never posts events or stores unrelated keys |
| `AudioRecorder` | capture one temporary WAV and meter levels | deletes stale/current audio; never transcribes |
| `WhisperTranscriber` | run serialized embedded inference and deterministic cleanup | no network, process or Python runtime |
| `WhisperModelManager` | download, verify and atomically install the fixed model | HTTPS download only; rejects wrong size/hash |
| `TextInjector` | place every completed transcript on the general pasteboard | recovery copy only; never simulates paste |
| `DictationCoordinator` | own phase, cancellation, cleanup and callbacks | one active attempt; fail closed |
| `FloatingPanelController` | render passive status near the current screen | never activates or becomes text target |
| `TranscriptHistory` | keep up to ten successful texts locally when enabled | no audio, sync, analytics or account |

## State and concurrency

The main actor owns `idle → recording → transcribing → inserting → idle`; any active phase may enter `failed`, then recover to idle. Inference runs in one detached user-initiated task behind an engine lock. Attempt identifiers reject stale completions. Cancellation stops recording/task ownership and removes the unique temporary WAV.

The service provider keeps its AppKit service connection alive with a bounded run-loop wait. Completion returns UTF-8 plain text to the requesting app. Failure and timeout return no placeholder text, while the last successful transcript is already available through Command-V.

## Permissions and sandbox

The app requests only:

- Microphone, for AVFoundation capture.
- Input Monitoring, for the release of the already-invoked service shortcut.
- Network client entitlement, only for the first verified model download.

The production binary does not request Accessibility and contains no `AXIsProcessTrusted`, `AXUIElement`, `CGEventPost` or synthetic Command-V path. UI accessibility labels and system appearance support remain normal SwiftUI accessibility behavior and require no privacy permission.

## Data lifecycle

- Audio: unique temporary file, deleted after success, failure or cancellation.
- Transcript: returned to the service, copied to the general pasteboard and optionally retained in a bounded ten-item local history.
- Model: persistent inside the sandbox container; verified before installation.
- Preferences: local `UserDefaults`; no account or sync.
- Diagnostics: no raw audio or transcript content in logs.

## Build and release boundary

The archive must contain `PrivacyInfo.xcprivacy`, the embedded Whisper framework, exactly the three declared sandbox entitlements and no forbidden insertion symbols. The exact archived app must pass unit tests, model verification, embedded inference and physical Service insertion before upload. Apple Distribution signing, provisioning, App Store Connect upload and final submission remain external release gates.

## Deferred

- Windows client.
- Streaming inference and larger-model benchmarks.
- AI rewrite, cloud transcription, login, billing, analytics or sync.
