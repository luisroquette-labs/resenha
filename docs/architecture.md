# Resenha architecture

Status: Mac App Store architecture implemented; physical cross-app acceptance and Store signing pending

## Runtime flow

```text
Focused editable field
        │ macOS Service: "Ditar com Resenha" (default ⌘⇧E)
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

One XcodeGen app target (`WhisperKey`) produces two configuration identities from the
same source: Release is `Resenha` / `br.com.luisroquette.Resenha`; Debug is
`Resenha Dev` / `br.com.luisroquette.Resenha.Debug`. The separate Debug identity prevents
tests, preferences, TCC state and LaunchServices registrations from touching production.
There is no second product target or legacy app edition. Release is arm64, requires
macOS 14, runs as a menu-bar utility and enables App Sandbox.

The signed bundle embeds the arm64 `whisper.xcframework`. It does not invoke Homebrew, Python, `Process`, a shell or an external executable. The model is downloaded once from the official Hugging Face repository into the sandbox Application Support container, then accepted only after exact byte-size and SHA-256 verification.

## Components

| Component | Responsibility | Boundary |
|---|---|---|
| `ResenhaServiceProvider` | receive a native Services request and return plain text | one lock-protected request, bounded synchronous AppKit boundary, no focus manipulation |
| `HotkeyMonitor` | observe only the armed service shortcut release | listen-only; never posts events or stores unrelated keys |
| `AudioRecorder` | capture one temporary WAV and meter levels | deletes stale/current audio; never transcribes |
| `WhisperTranscriber` | run serialized embedded inference and deterministic cleanup | no network, process or Python runtime |
| `WhisperModelManager` | launch verification, resumable download, backup recovery and rollback-safe installation | `.ready` is the sole admission source; rejects wrong size/hash and never discards the last recoverable valid model |
| `TextInjector` | place every completed transcript on the general pasteboard | recovery copy only; never simulates paste |
| `DictationCoordinator` | own phase, cancellation, cleanup and callbacks | one active attempt; fail closed |
| `FloatingPanelController` | render passive status near the current screen | never activates or becomes text target |
| `TranscriptHistory` | keep up to ten successful texts locally when enabled | no audio, sync, analytics or account |

## State and concurrency

The main actor owns `idle → recording → transcribing → inserting → idle`; any active phase may enter `failed`, then recover to idle. Inference runs in one detached user-initiated task behind an engine lock. Attempt identifiers reject stale completions. Cancellation stops recording/task ownership and removes the unique temporary WAV.

The runtime has one shared bounded budget: capture stops at 5 minutes,
`whisper_full` aborts cooperatively at 4m30, and the synchronous Service boundary
expires at 10 minutes measured by monotonic uptime. Capture completion has one
AppDelegate-owned terminal edge that clears the release latch and pressed state
before transcription, whether triggered by key release or deadline. An event-tap
failure, sleep or session lock cancels it. Whisper context reuse is limited to a
45-second idle window and invalidated by memory pressure under the same engine
lock used for inference.

The Service is the only start/insertion boundary. Admission rejects requests originating from Resenha itself and every model state except `.ready`; the admitted verified URL is retained for that dictation and passed directly into transcription. Admission is transactional: any rejected or failed start rolls back the pressed state and armed release latch. While enabled, the listen-only monitor retains only the numeric keycode and monotonic time of the latest non-modifier key-down, for at most one second; it binds a request to that still-held key and clears the transient state on release, rejection, interruption or shutdown. The provider keeps AppKit's synchronous connection alive with a bounded nested run loop only when invoked on the main thread; its state remains lock-protected and reusable after every terminal outcome. Completion returns UTF-8 plain text to the requesting app. Failure and timeout return no placeholder text, while the last successful transcript is already available through Command-V.

## Permissions and sandbox

The app requests only:

- Microphone, for AVFoundation capture.
- Input Monitoring, for the release of the already-invoked service shortcut.
- Network client entitlement, only for the first verified model download.

The production binary does not request Accessibility and contains no `AXIsProcessTrusted`, `AXUIElement`, `CGEventPost` or synthetic Command-V path. UI accessibility labels and system appearance support remain normal SwiftUI accessibility behavior and require no privacy permission.

## Data lifecycle

- Audio: unique temporary file, deleted after success, failure or cancellation.
- Transcript: returned to the service, copied to the general pasteboard and retained in a bounded ten-item local history only after explicit opt-in; clean installs start with history disabled.
- Model: persistent inside the sandbox container; verified before installation.
- Preferences: local `UserDefaults`; no account or sync.
- Sound favorites: validated sound IDs in local `UserDefaults`; search is in-memory and never leaves the Mac.
- Diagnostics: no raw audio or transcript content in logs.

## Build and release boundary

The archive must contain `PrivacyInfo.xcprivacy`, `THIRD_PARTY_NOTICES.md`, the full
whisper.cpp and OpenAI Whisper MIT licenses, the embedded Whisper framework, exactly
the three declared sandbox entitlements and no forbidden insertion symbols or Release
model-path override. The exact archived app must pass unit tests, model verification,
embedded inference and physical Service insertion before upload. Apple Distribution
signing, provisioning, App Store Connect upload and final submission remain external
release gates.

The website is a static first-party artifact. Canonical/Open Graph/Twitter metadata and
`SoftwareApplication` JSON-LD point to the declared GitHub Pages origin without ratings,
pricing or download claims. Its generated demos use native UI fixtures plus a disclosed
editorial surface; they show cursor movement, key state, responsive HUD and progressive
insertion, but do not claim physical microphone or cross-app compatibility evidence.

## Deferred

- Windows client.
- Streaming inference and larger-model benchmarks.
- AI rewrite, cloud transcription, login, billing, analytics or sync.
