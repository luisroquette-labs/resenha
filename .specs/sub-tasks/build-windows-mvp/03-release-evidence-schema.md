# Step 03: release evidence schema

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 1
**Model:** opus
**Agent:** developer
**Depends on:** 02
**Parallel with:** 01
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Define fail-closed artifact evidence identity before implementing producers or consumers.

Own Windows/release-manifest.schema.json, Windows/Resenha.Core/ReleasePolicy.cs only after coordinating the Core project scaffold, Scripts/windows-release.test.mjs and synthetic fixtures under Scripts/fixtures/windows-release/. The new evidence trust boundary spans build, signatures, scan, hardware and hosting, so opus applies. Fixtures are conspicuously synthetic and cannot be promoted as production proof.

#### Expected Output

Schema v1, deterministic release policy and positive/negative contract fixtures with immutable report-reference rules.

#### Success Criteria

- Manifest validates exact platform/x64/version/filename/source/whisper/model/build/payload/signature/scan/physical/hosting groups from the architecture.
- Absent or contradictory evidence, old Defender definitions, incomplete PE inventory, wrong OS coverage, arbitrary URL and changed artifact bytes are rejected.
- Manifest has no self-hash or circular report digest; pre-host candidate status cannot enable the public site.

#### Subtasks

- [ ] Define full schema and deterministic ReleasePolicy validation, including candidate-ready versus hosted-ready prerequisites without weakening final release requirements.
- [ ] Create named synthetic fixtures for every missing/mismatched group, invalid timestamps/certificate, stale scan and cross-platform artifact.
- [ ] Add schema/fixture tests to Scripts/windows-release.test.mjs and portable ReleasePolicy tests; run node tests through mac-gate.
- [ ] Document report hash DAG and immutable expected GitHub asset URL in fixture README; reserve real evidence for release steps.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Boolean passed values accepted without hashed underlying reports | High | High | Require report identities/inventory and verifier-produced projection; reject hand-authored success records. |
| Risk | Schema accidentally requires its own digest or hosting before candidate QA | High | Medium | Use acyclic report references and explicit staging; final hosted evidence remains mandatory for activation. |
