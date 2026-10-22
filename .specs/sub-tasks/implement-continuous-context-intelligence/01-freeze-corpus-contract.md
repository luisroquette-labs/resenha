# 01 — Freeze corpus contract

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 1
**Model:** sonnet
**Agent:** sonnet
**Depends on:** Integrated `add-context-aware-corrections` task; dedicated branch/worktree from current `main`.
**Parallel with:** None
**Note:** This step must be committed before any production implementation starts. It fixes expected inputs/outputs and controls so later code cannot tune the benchmark after seeing results.
**Goal:** Freeze the PT-BR semantic-orchestration corpus, references, controls and immutable checksum before changing capture, recognition, session, UI or Jev behavior.

Create `Tests/Fixtures/continuous-context-events.json`; modify `Tests/WhisperKeyTests/WhisperKeyTests.swift`, `project.yml` and generated `WhisperKey.xcodeproj/project.pbxproj`. Include at least 40 contextual cases and ten no-change controls with simulated partial/final **text events**, expected local/final text, allowed contextual alternatives and case categories. Store the fixture SHA-256 as an XCTest constant and make the loader fail on any later byte change unless this task is explicitly re-planned before implementation resumes. The fixture contains no audio/PCM and its timestamps are logical inputs, never measurements.

#### Expected Output

A versioned, synthetic, deterministic text-event corpus and loader test establish the immutable baseline for semantic candidate selection, revision ordering and mocked contextual comparisons. It proves orchestration only: it cannot prove acoustic accuracy, completed-WAV versus rolling ASR quality, capture-to-candidate latency, cold/warm behavior, realtime factor, CPU, memory or thermal impact. Those require Step 09's physical protocol.

#### Success Criteria

- The fixture has at least 40 PT-BR cases plus ten controls covering homophones, technical terms, names/identifiers, negation, numbers, code-switching, Unicode, pauses, retractions, repeated occurrences and topic changes.
- Every case declares source events, expected completed-recording result, expected final reference, allowed alternatives and whether no change is required; controls permit no semantic edit.
- Fixture/schema/test names label all timestamps simulated and reject use of this corpus as acoustic/performance evidence.
- `Tests/WhisperKeyTests/WhisperKeyTests.swift` loads only the bundled resource, validates schema/count/category coverage and asserts the exact pre-implementation SHA-256.
- `project.yml` includes the fixture in app/test resources and `xcodegen generate` produces matching `WhisperKey.xcodeproj/project.pbxproj` membership.
- Fixture tests and the full native gate pass through `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; commit the fixture/hash before Step 02.

#### Subtasks

1. Author the synthetic fixture and reference labels without running a new implementation against it; review every case for personal data and ambiguous expected meaning.
2. Add the strict loader/schema/category/checksum XCTest in `Tests/WhisperKeyTests/WhisperKeyTests.swift`.
3. Register the fixture in `project.yml`, regenerate `WhisperKey.xcodeproj/project.pbxproj` with XcodeGen and inspect both resource phases.
4. Run fixture/full gates through `mac-gate`, record the checksum in the test and commit this baseline before any Step 02–09 source edit.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Expected meaning is disputed before implementation | High | Medium | Resolve/review the synthetic reference now; do not freeze an ambiguous case |
| Risk | Corpus leaks real dictation or identifiers | High | Low | Use invented fixtures only and scan/review before commit |
| Risk | Later implementation silently edits references | High | Medium | Exact checksum test and prerequisite commit; any planned corpus revision restarts comparison from a new explicit baseline |
| Risk | Simulated text events are reported as ASR/latency proof | High | Medium | Explicit orchestration-only schema/assertion; Step 09 is the sole owner of acoustic/performance evidence |
| Risk | Resource loads from checkout rather than candidate bundle | Medium | Medium | Bundle-only loader test with no filesystem fallback |
