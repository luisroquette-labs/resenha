# Step 17: signed candidate hash and scan

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 5
**Model:** sonnet
**Agent:** developer
**Depends on:** 13, 14
**Parallel with:** 19
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Build and freeze one real signed candidate with complete hash and malware-scan evidence.

Execute the settled Windows pipeline on the identified owner-authorized physical Windows 11 host. Own generated artifacts/windows/<version>/<source-sha>/ and the build/sign/scan portions of docs/testing/WINDOWS-RELEASE-EVIDENCE.md. This is a bounded operational application of reviewed scripts, not permission to buy services, use secrets from a new source or publish.

#### Expected Output

Signed installer, SHA-256 sidecar, payload inventory and real build/sign/Defender reports for identical final bytes.

#### Success Criteria

- Clean checkout and exact source/submodule/toolchain/model identity are recorded; preflight is green for that source.
- Every shipped PE/installer/uninstaller has accepted trusted signature and timestamp; final hashing occurs after final signing.
- Final installer and extracted payload scan completely with <=24-hour definitions, zero detections/remediations and report identity matching final bytes; candidate remains unpublished.

#### Subtasks

- [ ] Confirm existing authorization for host/certificate use and inspect real workflow/provider requirements; record exact unmet prerequisites without attempting unavailable signing.
- [ ] Run preflight.ps1 and build-release.ps1 -Version on clean recorded source; inventory dependencies and retain non-sensitive toolchain output.
- [ ] Hash final signed installer, scan installer and extracted payload with current Defender definitions/remediation disabled, and archive immutable reports.
- [ ] Add regression fixtures for any newly observed packaging/verifier defect and rerun appropriate gates; validate generated candidate evidence against schema and stage verifier before physical QA.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Host, certificate or fresh scanner signatures unavailable | High | High | Stop candidate/publication progression; retain development work and precise missing prerequisite. |
| Risk | Artifact mutated between signing, scan and physical tests | High | Medium | Freeze file/hash after final signature and invalidate reports on any byte change. |
