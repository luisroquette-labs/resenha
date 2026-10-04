# Step 07: owned storage and verified model

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 02
**Parallel with:** 04, 05, 06, 08
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Enforce private owned storage and verified, immutable model leases.

Own Resenha.Platform/SessionFiles.cs, ModelStore.cs, Windows/model-manifest.json and storage/model test files. Path ownership, reparse points, atomic integrity and cross-process model leases form a new security/data-integrity subsystem. No executable runtime download is introduced.

#### Expected Output

Owned session cleanup and model download/import with exact size/hash, atomic promotion and read lease held throughout inference.

#### Success Criteria

- Model descriptor matches ggml-small-q5_1.bin, 190085487 bytes and task SHA-256; every acquisition revalidates and denies write/delete until disposal.
- Explicit download/import stages .partial then atomically promotes; failed replacement retains prior valid model; 30-second no-progress and 15-minute total deadlines apply.
- Only app-owned canonical session directories are cleaned on all outcomes and next startup; traversal/reparse inputs are rejected and cleanup failure is visible.

#### Subtasks

- [ ] Implement private canonical local-app-data directories and attempt GUID ownership checks in SessionFiles.cs; preserve imported source files and user data.
- [ ] Implement ModelStore download/import, byte/size/hash limits, lease locking, cancellation and atomic verified promotion.
- [ ] Create pinned model-manifest.json using the existing trusted HTTPS source and exact descriptor; no remote inference or paid API.
- [ ] Write model corruption/truncation/symlink-reparse/failed replacement/lease tampering/crash-remnant tests in StorageModelTests.cs, and run Windows filesystem checks.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Cleanup follows reparse points into user documents | High | Medium | Validate canonical ownership and reject reparse traversal at every destructive boundary. |
| Risk | Model changes between validation and CLI read | High | Medium | Hold validated file lease denying write/delete through the complete inference job. |
