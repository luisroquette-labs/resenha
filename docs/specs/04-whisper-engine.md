# SPEC-004 — Whisper Engine

Status: embedded engine implemented; final clean-install acceptance pending

## Goal

Convert the captured WAV to local text with whisper.cpp, optimized for Apple Silicon and requiring no external runtime.

## Runtime contract

- `whisper.xcframework` is embedded in the signed app and called through the public C API.
- The Release target is arm64 and enables Metal, flash attention and Accelerate.
- Inference is serialized behind one engine lock. The loaded model context is
  reused for 45 seconds, then released; warning/critical memory pressure releases
  it as soon as any active inference exits.
- The app never invokes `Process`, a shell, Homebrew, Python or a cloud API.
- Language is fixed per attempt from PT-BR, EN or ES; translation is off.
- The personal glossary becomes a bounded initial prompt and deterministic replacement table.

## Model acquisition

The initial model is `ggml-small-q5_1.bin` from the official `ggerganov/whisper.cpp` Hugging Face repository.

- Expected size: `190085487` bytes.
- Expected SHA-256: `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
- Download uses an ephemeral URL session and the sandbox network-client entitlement.
- Install is atomic inside Application Support after size and hash pass.
- Existing files with the wrong size/hash are rejected and replaced only by an explicit retry.

## Audio and output

- Input must be 16 kHz, mono PCM readable by `AVAudioFile`.
- Empty speech, invalid audio, model-load failure, non-zero inference status and timeout fail closed.
- Inference has a monotonic 4m30 deadline. Cancellation and timeout are passed to
  whisper.cpp through `whisper_full_params.abort_callback`; they interrupt
  `whisper_full` itself instead of discarding a late result.
- The callback token remains strongly alive for the complete synchronous C call.
  Context release and inference share one lock, while generation tokens prevent a
  stale idle callback from freeing a context reused by a newer request.
- The context-owning engine seam must prove actual idle release, deferred memory-
  pressure release during inference and serialization of concurrent requests.
- Segment text is joined, whitespace/non-speech markers normalized and the bounded local glossary applied.
- No raw audio or transcript content is logged.

## Performance

Initial target for a five-second utterance on Apple Silicon is P50 under three seconds after model load. The exact device/model benchmark is evidence, not a marketing guarantee.

## Licensing

whisper.cpp and the selected model are MIT-licensed. The repository and app distribution include their notices in `THIRD_PARTY_NOTICES.md`.

## Acceptance

1. An archived sandboxed app downloads and verifies the model once.
2. A deterministic fixture WAV produces non-empty text through the embedded engine.
3. The same model transcribes with the network disconnected after installation.
4. Binary inspection finds no external executable dependency or Python runtime.
