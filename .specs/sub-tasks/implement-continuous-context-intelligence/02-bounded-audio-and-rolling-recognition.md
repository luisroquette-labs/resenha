# 02 — Bounded audio and rolling recognition

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 1
**Model:** opus
**Agent:** opus
**Depends on:** 01
**Parallel with:** None
**Note:** Concurrency in the realtime audio callback and the shared Whisper engine makes this open-design work. Keep the completed-WAV path authoritative and unchanged when rolling mode is off.
**Goal:** Expose owned, timestamped PCM snapshots and serialized rolling Whisper hypotheses without blocking audio capture or creating an unbounded inference queue.

Modify `Sources/WhisperKey/AudioRecorder.swift` and `Sources/WhisperKey/WhisperTranscriber.swift`. Add the smallest internal event and rolling-inference contracts needed by the next step. The audio callback may copy/convert and enqueue samples only. `EmbeddedWhisperEngine` remains the single model owner, with one active inference and one replaceable pending snapshot. Do not add Apple Speech, a CLI, a model, a dependency, or final text insertion.

#### Expected Output

A disabled-by-default rolling recognition seam emits immutable local hypotheses with sample ranges and monotonic capture/candidate instants. Queue depth and retained PCM stay bounded; stop, cancel, interruption and unsupported/slow inference preserve the existing final WAV flow.

#### Success Criteria

- `AudioRecorder` emits 16 kHz mono owned samples without retaining mutable `AVAudioPCMBuffer` memory or doing inference/UI/network work on the tap thread.
- `WhisperTranscriber` serializes the installed engine, coalesces equal snapshots and keeps at most one active plus one latest pending inference.
- Cancellation reaches `WhisperExecutionControl`; stale results are tagged and cannot become a final transcript.
- Feature-off recording/transcription behavior and current language/glossary tests remain unchanged.
- Tests cover buffer bounds, replacement, cancellation, interruption, unsupported rolling inference and final-WAV fallback via the native `mac-gate` test command.

#### Subtasks

1. Trace every caller of `AudioRecorder.start/stop/cancel` and `WhisperTranscriber.transcribe`; define internal timestamped sample/hypothesis values without changing external output contracts.
2. Add bounded PCM delivery and terminal cleanup in `AudioRecorder.swift`, preserving metering, private temporary WAV ownership and exactly-once stop behavior.
3. Add serialized rolling-window inference and latest-wins backpressure in `WhisperTranscriber.swift`, with injected scheduling values and native abort support.
4. Add focused XCTest coverage in `Tests/WhisperKeyTests/WhisperKeyTests.swift`, including long sessions and late callbacks; run affected tests through `~/.local/bin/mac-gate xcodebuild ... test`.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Packaged whisper API cannot accept rolling sample arrays as assumed | High | Medium | Inspect the linked headers first; retain completed-WAV behavior and expose no live capability until a supported call is proven |
| Risk | Realtime callback allocates or blocks long enough to lose audio | High | Medium | Copy minimally into a bounded owner and enqueue; benchmark callback duration and test overflow |
| Risk | Semaphore queues every snapshot | High | High | One active/one replaceable pending state; assert maximum depth under a long deterministic sequence |
| Risk | Cancellation races with final WAV completion | High | Medium | Separate rolling child cancellation from authoritative recorder finalization and test both event orders |
