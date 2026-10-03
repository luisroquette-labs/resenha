# SPEC-018 — Embedded local Whisper runtime

## Goal

Make transcription self-contained, signed, sandbox-compatible and optimized for Apple Silicon.

## Requirements

- Integrate whisper.cpp as source/library through a reproducible pinned revision and record its license.
- Expose a narrow Swift/C boundary; do not launch `Process` in the Store target.
- Build arm64 with Metal acceleration where supported and no network dependency.
- Package a redistributable quantized multilingual model or perform an explicit first-run download into the app container with checksum, resumability and clear size disclosure.
- Prefer bundled model for 1.0 when App Store package limits and licensing allow it; otherwise the download host, privacy behavior and offline-after-download limitation must be disclosed.
- Warm/model-load state must be bounded and never freeze the menu/HUD.

## Security and privacy

- Verify model SHA-256 before use.
- Audio and inference buffers never leave the process/container.
- Temporary files use user-only permissions and are deleted on success, failure, cancellation and stale-startup cleanup.
- No model path or executable override from environment variables in Release Store builds.

## Acceptance

- `WHISPER-STORE-001`: archive contains the engine and required model strategy; `otool` and bundle inspection show no Homebrew dependency.
- `WHISPER-STORE-002`: a network-disabled Release build transcribes the fixture corpus.
- `WHISPER-STORE-003`: English terms inside pt-BR speech retain or improve the current baseline.
- `WHISPER-STORE-004`: third-party notices include whisper.cpp and model licenses.
