# 03 — Continuous session state machine

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 1
**Model:** opus
**Agent:** opus
**Depends on:** 02
**Parallel with:** None
**Note:** This step owns the new concurrency and data-integrity boundary. It must not absorb coordinator, output-sink, UI or provider responsibilities.
**Goal:** Create one cohesive owner for immutable revisions, bounded context, latest-wins scheduling and the transition from capture to one frozen final candidate.

Create `Sources/WhisperKey/ContinuousContextSession.swift`. Consume the rolling events from 02 and model `idle -> capturing -> finalizing -> committed`, plus terminal cancelled/failed paths. Keep stable prefix and mutable suffix explicit; never carry `String.Index` across snapshots. The session may expose provisional values and one frozen final result, but cannot paste, persist learning or call a provider yet.

#### Expected Output

`ContinuousContextSession` produces ordered, session-bound revisions and rejects duplicate, reordered, expired, superseded and post-terminal work. It retains no more than 30 seconds/600 characters of session context and releases PCM/text/tasks on every terminal path.

#### Success Criteria

- Every revision contains attempt UUID, monotonic revision, sample range/snapshot ID, source text, language, provisional/final state, generation IDs and monotonic timestamps.
- Equal hypotheses do not emit work; stable text is not reprocessed; source spans are recomputed against the exact immutable snapshot.
- A long adversarial event stream keeps bounded context and one active/one replaceable local job without duplicate append or queue growth.
- Cancel/failure/finalize invalidate child work and release buffers; a late child cannot change the frozen result.
- Tests exercise repeated/retracted text, split words, Unicode, overlap, out-of-order callbacks, stop during inference and memory-release probes.

#### Subtasks

1. Implement session/revision value types and the explicit state transition table in `ContinuousContextSession.swift` using the existing monotonic clock conventions.
2. Implement stable-prefix/mutable-suffix reconciliation and bounded PCM/text retention without persisting provisional state.
3. Connect the rolling stream from 02 behind an internal protocol; keep coordinator and provider calls out of this file.
4. Add deterministic session tests to `Tests/WhisperKeyTests/WhisperKeyTests.swift` and run the phase's full native gate through `mac-gate`.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Step 02 cannot provide immutable sample ranges/timestamps | High | Low | Fix the source contract in 02 before proceeding; do not infer ranges from text |
| Risk | Swift indices from an old snapshot corrupt a newer string | High | High | Store offsets/ordinals tied to snapshot identity and recompute indices before use |
| Risk | Stable-prefix heuristic locks an incorrect word | High | Medium | Keep thresholds injectable and capability off until corpus calibration; final WAV remains authoritative |
| Risk | Child task retains session after cancellation | High | Medium | Structured task ownership plus weak retention probes and terminal cleanup tests |
