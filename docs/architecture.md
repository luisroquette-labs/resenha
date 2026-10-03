# WhisperKey Architecture

Status: M0 interface refinement implemented; native/human acceptance pending

## Runtime flow

```text
CGEvent tap (Right Option)
        │ down/up
        ▼
DictationCoordinator ───────► FloatingPanelController
        │
        ├──► AVAudioRecorder ──► temporary 16 kHz mono WAV
        │
        ├──► WhisperCLITranscriber ──► local whisper.cpp + model
        │
        └──► ClipboardTextInjector ──► CGEvent Command-V
                                      │
                                      ▼
                              previously focused app
```

## Components

| Component | Responsibility | Must not do |
|---|---|---|
| `HotkeyMonitor` | produce one press/release pair | record unrelated keys |
| `AudioRecorder` | own one temporary WAV | transcribe or retain audio |
| `WhisperCLITranscriber` | run local inference and return text | download or call network |
| `TextInjector` | stage the final transcript on the clipboard and paste it transactionally | rewrite/format content |
| `DictationCoordinator` | own real phase, original target, cleanup and safe error presentation | own a competing HUD timeout |
| `FloatingPanelController` | own one passive panel, dismissal generation/deadline and target-screen session | activate itself or become the text target |
| `PermissionService` | inspect/request existing rights; named purpose and Settings destination | prompt or navigate from polling |

AppDelegate retains routing, permission polling/request guards and phase callbacks. `NativeMenuController` renders the native menu/status item with a weak AppDelegate action/delegate reference. `MenuStatusPresentation`/`NativeMenuText` provide activity/accessibility copy and bounded wrapping rows; `DictationInteraction` supplies the start/release latch. `FloatingStatusView` owns local SwiftUI layout/appearance; `PanelPlacement`/`PanelScreenSelection` calculate geometry and target-screen fallback. These extracted files preserve presentation responsibilities without a new framework or product surface.

Recording alone adds `RecordingMeter`/`RecordingWaveformView`: AudioRecorder enables existing AVAudioRecorder metering and samples channel-0 average power at 20 Hz on the main run loop. Its callback carries normalized scalar levels through the coordinator into the panel model. A 48-level memory-only history applies bounded attack/decay; an injected monotonic clock produces mm:ss. Leaving Listening or hiding clears the meter; stopping/cancelling the recorder invalidates its timer. Reduced Motion uses stationary current-level bars; no random values, per-frame accessibility labels or waveform animation task exists. Capture settings and transcription/insertion behavior are unchanged.

Permissions remain orthogonal to real activity. Menu/submenu/request/self-target guards reject new starts while forwarding active recording release. Permission loss cancels only recording and preserves processing completion. The panel alone owns the two-second transient hide and current-generation completion, preventing old feedback from hiding new activity.

Read-only AX geometry selects the original target display and retains it through a session. Last valid target screen then main/first are explicit fallbacks. Fresh visibleFrame clamps/repositions after display changes. Actual caret/click-through/full-screen behavior still requires integration observation.

## Concurrency

UI and state transitions are isolated to the main actor. Whisper inference runs off the main thread. One coordinator-owned task exists per dictation; termination cancels it and removes temporary files.

## Data lifecycle

M0 adds no persistent configuration. Audio and Whisper output use unique temporary paths removed by recorder cleanup / `defer`. Transcript text exists in memory and briefly on the general pasteboard. No logs contain raw audio/transcript content. Presentation and safe diagnostic detail are memory-only; details survive transient HUD dismissal until resolved or a new attempt starts. Only attempted paths, exit code and recovery guidance are exposed; raw stderr/transcripts are excluded.

## Security and privacy boundary

Trust boundary inputs are microphone samples, environment-provided executable/model paths, Whisper output and pasteboard representations. Existing path discovery checks executable availability and model existence; subprocess arguments are passed without a shell. Network frameworks/telemetry dependencies are absent. This interface refinement does not change capture, Portuguese decoding, model invocation, normalization, paste or clipboard algorithms.

## Build shape

An XcodeGen manifest produces a macOS application target and a unit-test target. Both use the stable `build` Derived Data path and the owner's Apple Development identity, preserving one LaunchServices/TCC identity across rebuilds. Multiple instances are prohibited. The application links only Apple frameworks in M0; no Python or server is part of runtime.

## Deferred decisions

- Embedded whisper.cpp C bridge and signed model delivery.
- Fn support and user-configurable hotkeys.
- Direct Accessibility range insertion as an alternative to paste.
- Streaming transcription and model warm-up.
- Sandboxing/notarization/distribution channel.
