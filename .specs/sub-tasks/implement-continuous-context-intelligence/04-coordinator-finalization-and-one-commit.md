# 04 — Coordinator finalization and one commit

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 2
**Model:** opus
**Agent:** opus
**Depends on:** 03
**Parallel with:** 06
**Note:** This crosses the shared session/output contract and protects user text. Reuse `DictationOutputSink`; do not introduce a second insertion path or rewrite third-party editors.
**Goal:** Integrate one continuous session into the push-to-talk lifecycle while preserving authoritative final transcription and exactly-once external output.

Modify `Sources/WhisperKey/DictationCoordinator.swift` and `Sources/WhisperKey/WhisperKeyApp.swift`. Start one session under the existing attempt identity, route local provisional state to a preview callback, stop admission on release, reconcile against the final completed-WAV transcription and pass one frozen string through the current sink. Lifecycle, permission, hotkey and preference changes invalidate pending work.

#### Expected Output

The app can run local rolling mode behind a disabled-by-default capability, show session-local preview through a test double and still perform exactly one established history/clipboard/insertion transaction at release. Offline, cancellation and feature-off paths behave as before.

#### Success Criteria

- `DictationCoordinator` owns one active `ContinuousContextSession` under the current attempt UUID and invalidates it on every existing terminal path.
- Release performs final local recognition, freezes one string and calls the existing `DictationOutputSink` once; duplicate/late callbacks cannot paste again.
- Provisional text never reaches clipboard, transcript history, feedback learning or external target.
- Permission loss, app termination, new attempt and mode changes cancel work and clear preview without blocking final fallback.
- Integration tests cover final-partial disagreement, duplicate callbacks, focus/clipboard recovery, offline mode and all feature-off regressions.

#### Subtasks

1. Trace all coordinator terminal paths and output-sink callers before changing ownership.
2. Inject the session factory/preview callback into `DictationCoordinator.swift`, retaining current defaults for production and tests.
3. Compose and invalidate the pipeline in `WhisperKeyApp.swift` without repurposing synthetic diagnostic authorization.
4. Add coordinator/output regression tests in `Tests/WhisperKeyTests/WhisperKeyTests.swift`; run targeted tests and the full native gate through `mac-gate`.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Existing coordinator has an untraced terminal path | High | Medium | Enumerate every `show`, completion, cancel and sink call before editing; add a state-table test |
| Risk | Partial text leaks into history or clipboard | High | Medium | Keep preview callback type separate from `DictationOutputSink`; spies assert zero provisional writes |
| Risk | Release waits indefinitely for rolling inference | High | Medium | Bound child wait and use authoritative final path on expiry |
| Risk | New attempt receives old preview/result | High | Medium | Guard every callback with attempt/session identity and test overlap |
