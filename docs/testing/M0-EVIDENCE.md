# M0 Evidence

Date: 2026-10-02

## Environment

- Hardware: Apple M5 (`arm64`)
- Xcode: 26.3 (17C529)
- Swift: 6.2.4, project language mode Swift 5
- whisper.cpp: 1.9.2 via Homebrew
- Model: `ggml-small-q5_1.bin`, 181 MiB, stored outside the repository

## Automated gate

- Command: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`
- Result: PASS — 4 tests, 0 failures
- Coverage boundaries: state transitions, permission gate, transcript normalization, executable/model path override

## Local runtime checks

- Model load: PASS — Metal backend selected on Apple M5
- Synthetic Portuguese fixture: PASS — “Testando o nosso sistema de voz.” transcribed locally
- Signed debug bundle: PASS — `codesign --verify --deep --strict`
- LaunchServices launch: PASS — WhisperKey process remained active
- Single-instance identity: PASS — one registered active bundle, one running process, `LSMultipleInstancesProhibited=true`
- Stable signing: PASS — Apple Development designated requirement, replacing the previous ad-hoc signature
- Permission gate: PASS — Microphone, Accessibility, and Input Monitoring granted to the stable bundle
- Global hotkey: PASS — logs recorded Right Option press and release through the event tap
- End-to-end plumbing: PASS — live microphone recording was transcribed locally and inserted into TextEdit at the caret
- Default input repair: PASS — replaced virtual `BlackHole 2ch` with `Microfone (MacBook Pro)`

## Duplicate-app incident

Root cause: tests used Xcode's default Derived Data while manual runs used the repository `build` directory. LaunchServices registered both bundles under the same identifier. The old Derived Data copy was unregistered and moved to `~/.Trash/WhisperKey-DerivedData-20261002`; tests now use the same stable `build` path as manual runs.

## CORE-001

Status: PASS for the physical core flow; quality and restoration measurements remain open

On 2026-10-02, with TextEdit focused, the user physically held the configured hotkey, spoke a short Portuguese phrase, released it, and the app inserted the local Whisper result at the caret without a manual paste.

| Observation | Result |
|---|---|
| Target app | TextEdit |
| Intended phrase | “Testando o Resenha no meu Mac.” |
| Actual inserted text | “Testando o resenho no meu Mac.” |
| Hotkey → recording → Whisper → caret insertion | PASS |
| Brand term fidelity (`Resenha`) | FAIL — decoded as `resenho`; promoted to SPEC-011 regression case OQ-001 |
| Release-to-insertion time | NOT MEASURED |
| Clipboard restoration / temporary cleanup | NOT MEASURED |
| Chromium compatibility | NOT RUN |

## Interface refinement checkpoint — 2026-10-02

The earlier 4-test, synthetic, permission, microphone plumbing and input-device observations above remain historical baseline evidence. They are **not** a human-spoken acceptance or a new integration pass for the refined UI.

Current code gate: PASS — 31 tests, 0 failures/skips at 13:01:55 BRT. Same canonical mac-gate command and stable `build` bundle. Log: `build/phase2-refactor-integrated-mac-gate.log`; result: `build/Logs/Test/Test-WhisperKey-2026.10.02_13-01-47--0300.xcresult`. Step 05 is documentation-only; this unchanged passing revision is reused.

Environment: macOS 26.1 (25B78), Apple M5; Xcode/Swift/runtime/model as above. Repository has no HEAD; executable SHA-256: `584f28b2cc68741c1cb1b367121b87bf3132c2148d25bb952c49fdb9c362657b`; implementation `WhisperKey.debug.dylib` SHA-256: `a935ed04602e4e71fc6c5ba2a5c3ec84fe5f230efaaf002858facf5c1e02292f`. Source/project/fixture manifest and accurate native limitations: [UI refinement evidence](UI-REFINEMENT-EVIDENCE.md).

Stable Apple Development signature verification and LaunchServices launch PASS; one registered stable bundle and one process PID 11547 persisted across repeated `open`. This is runtime identity evidence only. Three connected displays do not prove multi-display behavior. Native CUA app selection failed; actual menu/focus/Settings/VoiceOver/Spaces checks remain NOT RUN.

| Required current-revision CORE-001 observation | Result |
|---|---|
| Target / physically spoken phrase | TextEdit / “Testando o nosso sistema de voz” — NOT RUN |
| Actual inserted text / release-to-insertion seconds | NOT RUN / NOT RUN |
| Target focus/caret and no manual paste | NOT RUN |
| Clipboard restoration / session temporary cleanup | NOT RUN / NOT RUN; idle absence of owned files alone is not proof |
| Chromium compatibility | NOT RUN |

This checkpoint is historical. The later physical observation above supersedes its pending phrase status; its unmeasured latency and clipboard fields remain open.

## Recording capsule checkpoint — 2026-10-02

Current revision: recording-only real-level metering HUD and elapsed timer. Canonical mac-gate PASS **35 tests, 0 failures**, 13:53:46 BRT; log `build/recording-hud-mac-gate-rerun.log`, result `build/Logs/Test/Test-WhisperKey-2026.10.02_13-53-40--0300.xcresult`. The prior 31-test revision/fingerprints above are historical. Current executable SHA-256: `6682d9f405982e5172bed5edae260637938311e0c3c5ecccc4647dfb42c75c1d`; implementation SHA-256: `dae94aa7598ed89a8a8b8a06ba09f88e89dafa1cb07557f17c2826bd31d93587`. Same signed stable bundle, one PID 44816 after repeated open.

Forty deterministic native-view fixtures include speech/silence/decay and Reduce Motion; six recording representatives inspected. They are injected samples, not actual microphone evidence. The real metering callback reads the existing AVAudioRecorder without changing capture format or decoding. A current native app binding attempt returned CUA -10005 timeoutReached. This checkpoint predates the physical TextEdit pass recorded above. Clipboard/cleanup, VoiceOver and display/Space checks remain NOT RUN. Full fingerprints/manifest and the 60-second manual check are in [UI evidence](UI-REFINEMENT-EVIDENCE.md).
