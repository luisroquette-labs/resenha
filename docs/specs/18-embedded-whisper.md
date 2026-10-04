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
- On every launch, an existing model enters `verifying`; it cannot enter `ready`
  until its exact byte count and SHA-256 have been recomputed. A corrupt file is
  removed and reported as unavailable.
- The Service and hotkey remain disabled outside `ready`. Admission captures the
  verified model URL and passes that exact URL through the dictation session; the
  transcriber never re-resolves a production model by file existence.
- Downloads use one named staging file and one named resume-data file. Cancellation
  removes staging immediately and persists only resumable URLSession metadata. Success,
  unrecoverable failure and invalid payloads remove both artifacts.
- Installation first verifies the staged payload, then replaces the destination with
  an atomic Foundation replacement that retains a rollback backup until success. A
  failed replacement restores the previously verified destination.
- A rollback failure is explicit and retains the verified backup path. On launch,
  a valid canonical model removes matching stale backups; a missing or invalid
  canonical model is restored from the newest valid matching backup before use.
- Audio and inference buffers never leave the process/container.
- Temporary files use user-only permissions and are deleted on success, failure, cancellation and stale-startup cleanup.
- No model path or executable override from environment variables in Release Store builds.
- `WHISPER_MODEL_PATH` is compiled only in `DEBUG`; the literal and branch must be
  absent from the Release executable.

## Acceptance

- `WHISPER-STORE-001`: archive contains the engine and required model strategy; `otool` and bundle inspection show no Homebrew dependency.
- `WHISPER-STORE-002`: a network-disabled Release build transcribes the fixture corpus.
- `WHISPER-STORE-003`: English terms inside pt-BR speech retain or improve the current baseline.
- `WHISPER-STORE-004`: third-party notices include whisper.cpp and model licenses.
- `WHISPER-STORE-005`: cancellation can resume without a `.download` orphan; a failed
  update leaves the prior verified model byte-for-byte intact.
