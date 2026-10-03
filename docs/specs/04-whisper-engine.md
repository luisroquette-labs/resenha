# SPEC-004 — Whisper Engine

Status: accepted for M0

## Goal

Convert the captured WAV to Portuguese text locally with whisper.cpp and Apple Silicon acceleration.

## M0 integration

The development build invokes an installed `whisper-cli` executable as a child process. This is still local whisper.cpp and contains no Python. Search order:

1. `WHISPER_CLI_PATH`
2. `/opt/homebrew/bin/whisper-cli`
3. `/usr/local/bin/whisper-cli`

Model search order:

1. `WHISPER_MODEL_PATH`
2. `~/Library/Application Support/WhisperKey/Models/ggml-large-v3-turbo-q5_0.bin`
3. `~/Library/Application Support/WhisperKey/Models/ggml-small-q5_1.bin`

The app must show the missing path when discovery fails. It must not download a model automatically.

## Invocation contract

Use the language selected for the current session, GPU enabled by default, text output (`-otxt`), a unique output prefix, and no timestamps. Capture stderr and require exit status zero. Stop a stuck local process after ten minutes.

## Output contract

- Read the generated `.txt` as UTF-8.
- Trim surrounding whitespace and Whisper bracket-only non-speech markers.
- Empty output is not injected.
- Delete generated output and bounded diagnostics even on failure.

## Performance target

For a five-second utterance with the small model on Apple Silicon: initial target P50 under 3 seconds after model load. M0 records actual elapsed time but does not promise sub-second latency.

## Distribution boundary

Before distributable M1, replace process discovery with an embedded whisper.cpp library/C bridge and define model acquisition, integrity verification, licensing, and updates. That work is explicitly outside M0.

## Acceptance

A deterministic fixture WAV produces non-empty Portuguese text with the network disabled.
