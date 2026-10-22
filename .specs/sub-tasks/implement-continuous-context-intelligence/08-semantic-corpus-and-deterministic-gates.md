# 08 — Semantic corpus and deterministic gates

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 3
**Model:** sonnet
**Agent:** sonnet
**Depends on:** 07
**Parallel with:** None
**Note:** Execute the immutable text-event fixture/hash from 01; do not create or relabel references here. Simulated clocks/events prove no acoustic or performance property. Real paid Jev calls remain prohibited without separate explicit approval.
**Goal:** Prove deterministic semantic orchestration, fidelity, queue bounds, timeout behavior and feature-off regressions before physical acoustic/performance validation.

Modify `Tests/WhisperKeyTests/WhisperKeyTests.swift` to execute the already frozen `Tests/Fixtures/continuous-context-events.json` without changing its bytes or checksum. Use fake monotonic clocks to verify ordering, boundaries and sanitized instrumentation fields. Compare local textual candidates and mocked contextual decisions against the references fixed in 01. Do not label fixture values as measured capture, ASR or hardware performance.

#### Expected Output

Automated tests execute the frozen text-event fixture and report correction benefit/regression counts, fallback behavior, queue bounds and instrumentation completeness. They prove orchestration only. Step 09 separately measures completed-WAV versus rolling ASR, capture-to-candidate, cold/warm behavior and resources on the final physical candidate.

#### Success Criteria

- Corpus covers homophones, technical terms, names/identifiers, negation, numbers, code-switching, Unicode, pauses, retractions, repeated occurrences and topic changes, with ten controls frozen before execution.
- Mock-contextual mode reduces semantic orchestration errors against the frozen textual baseline with zero new meaning changes in controls; otherwise the capability remains off and the failure is recorded.
- Tests explicitly reject treating fake-clock percentiles or event timestamps as capture-to-candidate, completed-WAV/rolling ASR, cold/warm or resource evidence.
- Fixture bytes still match the exact SHA-256 fixed in 01; tests load the declared app/test resource and never read checkout-relative data or personal captures.
- Full native test gate passes through `mac-gate`; `git diff --check` and secret/content-log scans are clean.

#### Subtasks

1. Verify the Step 01 fixture/checksum commit predates product changes and fail immediately if its current bytes differ.
2. Add fixture-driven integration/property tests and fake-clock instrumentation assertions in `Tests/WhisperKeyTests/WhisperKeyTests.swift`.
3. Execute all frozen text cases across local-candidate and mocked contextual modes; do not edit references or claim acoustic comparison after observing results.
4. Run corpus, boundary and full native gates via `mac-gate`; record actual results for 09 without changing expected outputs after observation.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Corpus is tuned after seeing failures | High | Medium | Step 01 checksum/commit must remain unchanged; a planned revision invalidates and reruns every comparison |
| Risk | Fake-clock/event results are presented as physical latency | High | Medium | Mark every result deterministic/orchestration-only; Step 09 owns all measured distributions |
| Risk | Fixture contains personal text | High | Low | Use reviewed synthetic content only and scan before commit |
