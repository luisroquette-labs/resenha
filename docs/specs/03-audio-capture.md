# SPEC-003 — Audio Capture

Status: accepted for M0

## Goal

Capture speech from the default input device for exactly the hotkey hold interval in a format accepted directly by whisper.cpp.

## Interface

```swift
protocol AudioCapturing {
    func start() throws
    func stop() throws -> URL
}
```

## Format

- WAV, linear PCM
- 16 kHz
- mono
- signed 16-bit little-endian
- temporary file unique to one dictation

## Requirements

- Use `AVAudioRecorder` from AVFoundation.
- Create the file in a dedicated temporary directory.
- Configure and prepare the recorder before starting.
- Treat a failed `record()` call as an error.
- Stop safely once; `stop()` without active recording is an error.
- Delete the file after the pipeline completes or fails.
- Cap every capture at five minutes using both `AVAudioRecorder.record(forDuration:)`
  and a coordinator deadline callback. Reaching the cap crosses the same
  AppDelegate-owned terminal edge as a matching key release: it first clears the
  physical-key latch and pressed interaction, then sends bounded audio to transcription.
- A lost matching key-up must never leave capture open: event-tap interruption,
  system sleep and session lock cancel capture, delete its temporary file and
  fail the active Service request.

## Edge cases

Recording shorter than 200 ms may be treated as empty. The five-minute cap is a
product limit, not a retained-history promise. Input-device selection, voice
activity detection, and continuous streaming are not M0.

## Acceptance

The resulting file exists, has non-zero size, and the embedded `WhisperTranscriber` accepts it without conversion.
