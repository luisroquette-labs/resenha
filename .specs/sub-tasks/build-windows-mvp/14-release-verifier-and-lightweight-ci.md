# Step 14: release verifier and lightweight ci

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 4
**Model:** opus
**Agent:** developer
**Depends on:** 03, 12
**Parallel with:** 13, 15, 16
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Create exact-artifact verification and CI contracts without fabricating physical success.

Own Scripts/windows/verify-release.ps1, collect-physical-evidence.ps1, promote-release.mjs, .github/workflows/windows-contracts.yml, site-tests.yml path filters and verifier test fixtures. Step 03 owns schema; schema amendments require serialized review. This is the release integrity boundary across all producers.

#### Expected Output

Fail-closed verifier/collector/promotion tooling, tamper fixtures and lightweight Linux contract checks.

#### Success Criteria

- Verifier recomputes final/payload/report hashes and rejects invalid publisher/chain/timestamp/PE coverage, failed/partial scans, definitions over 24 hours and absent physical observations.
- Collector records real OS/hardware/hash/test observations but never invents pass from script success; promotion requires hosted-byte report and exact allowlisted identity.
- Routine CI uses Ubuntu, five-minute timeout and concurrency cancellation, with no native/app/next build; Mac canonical tests stay behind mac-gate.

#### Subtasks

- [x] Implement signature/Defender/hash/report verification with remediation disabled and explicit candidate versus full hosted-release stages; no circular manifest hash.
- [x] Implement physical evidence collection and public projection allowlist; promote-release.mjs only writes validated projection and never uploads, submits forms or mutates CF Gauss.
- [ ] Add PowerShell/Node negative tests for tampered bytes/report refs, stale definitions, insufficient OS coverage, forged passed flags and self-signed chains; run portable tests through mac-gate and native tests on Windows.
- [ ] Create windows-contracts.yml and update site-tests.yml filters for all policy inputs; inspect actual repo deployment/protected checks and record missing Vercel configuration as unresolved rather than green.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Scanner exit zero hides detections or incomplete scan | High | Medium | Inspect detailed reports, complete payload inventory, signatures version/time and both final installer/extracted payload results. |
| Blocker | Required provider/check configuration is not established | High | Medium | Resolve live configuration/owner requirement before integration without creating paid runners/providers or waiving the gate. |
