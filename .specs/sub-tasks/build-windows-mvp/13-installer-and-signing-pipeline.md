# Step 13: installer and signing pipeline

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 4
**Model:** opus
**Agent:** developer
**Depends on:** 12
**Parallel with:** 14, 15, 16
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Implement reproducible per-user packaging with explicit signing prerequisites.

Own Windows/Installer/Resenha.iss, LICENSES.txt, Scripts/windows/build-release.ps1, THIRD_PARTY_NOTICES.md and .gitignore. Packaging/signing encompasses source integrity, payload inventory and destructive removal boundaries, requiring opus. This step implements and tests the pipeline; step 17 creates the final signed candidate.

#### Expected Output

Inno Setup 6.7.3 per-user x64 installer recipe and clean-source build/sign/hash manifest producer.

#### Success Criteria

- Pipeline uses exact SDK/runtime/native pins and recorded clean source SHA, runs native preflight and writes only ignored artifacts/windows/<version>/<sha>/.
- Sign payload then signed-uninstaller package then installer using approved trusted store/hardware certificate and RFC3161 timestamp; verify each shipped PE and preserve accepted vendor signatures.
- Removal exits children/hooks and removes owned model/settings by explicit default-selected option without deleting imported files, user documents or clipboard.

#### Subtasks

- [x] Implement Inno per-user fixed-AppId installer with PrivilegesRequired=lowest, exact product OS/CPU guards, no startup/service/updater and complete notices.
- [x] Implement build-release.ps1 host/tool/source checks, cwd pinning, self-contained publish/native dependency inventory and signing sequence; keep secrets/private keys out of output.
- [x] Emit unsigned-development versus release-blocked states truthfully; no self-signed root or unavailable certificate can satisfy public readiness.
- [ ] Add packaging contract tests and Windows installer lifecycle tests for spaces/non-ASCII/normal-user/retained-data/uninstall; test missing certificate and stale source rejection.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Approved publicly trusted publisher certificate unavailable | High | High | Produce a precise release blocker; no purchase, paid signing service or private-key fallback is authorized. |
| Risk | Packaging after scan/QA changes shipped bytes | High | Medium | Enforce immutable stage transitions; changed payload/package invalidates every downstream record. |
