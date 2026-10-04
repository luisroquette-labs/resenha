# Step 08: pinned whisper process and corpus

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 02
**Parallel with:** 04, 06, 07
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Run deterministic finite local inference from the existing pinned upstream source.

Own Windows/native/CMakePresets.json, Resenha.Platform/ChildProcessJob.cs, WhisperCliTranscriber.cs, Resenha.Platform.Tests/ModelProcessTests.cs, InferenceCorpusTests.cs and Windows/Fixtures/. Step 05 consumes ChildProcessJob via its frozen interface; coordinate its implementation before broker integration. Process/job cancellation, native flags and new inference boundary earn opus.

#### Expected Output

CPU-only bundled CLI adapter, kill-on-close job wrapper, licensed versioned corpus and measurable local multilingual results.

#### Success Criteria

- Upstream commit stays 4979e04f5dcaccb36057e059bbaed8a2f5288315; native tuning/GPU/network/BLAS/OpenMP stay off with the declared AVX2/FMA/F16C baseline.
- CLI launches by absolute bundled path with argument list/no shell; explicit pt/en/es, no translation/context/fallback, bounded output, deadline and confirmed exit precede deletion.
- At least five reference utterances per language plus silence have ownership/licenses and immutable expectations committed before measurement; WER <=20% per language and PT-BR/ES anglicism retention >=90% are measured with real engine.

#### Subtasks

- [ ] Implement locked CMake preset and ChildProcessJob kill-on-close/2-second termination contract with at most two native build workers.
- [ ] Implement WhisperCliTranscriber exact pinned CLI arguments, min(4, logical CPU count) threads, 120-second deadline and bounded 256 KiB/100000-character UTF-8 result validation.
- [ ] Create owned/licensed audio fixtures, reference transcripts, WER normalization and anglicism annotations before running inference; preserve existing output-corpus.json read-only.
- [ ] Write process crash/cancel/oversize/malformed output/argument-contract tests and real offline corpus tests; missing model/fixtures/CLI fails instead of skipping.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | No authorized Windows host or licensed/owned audio corpus available | High | Medium | Record missing prerequisite; create fixtures only with rights and run real CLI on authorized Windows. |
| Risk | Process exits but orphan child or late result survives cancellation | High | Medium | Contain full tree in job, invalidate attempts and confirm exit before owned-file cleanup. |
