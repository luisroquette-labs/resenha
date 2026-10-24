# Step 19: verified windows form configuration

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 5
**Model:** opus
**Agent:** developer
**Depends on:** 15, 16
**Parallel with:** 17, 18
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Obtain a dedicated verified Windows form/redirect without weakening mandatory fields.

Own the Windows entry in site/download-platforms.mjs and form-contract evidence in docs/testing/WINDOWS-RELEASE-EVIDENCE.md. CF Gauss is an external system: inspect current contract read-only first; make provisioning writes or real submissions only under explicit existing authorization for those actions. Cross-system trusted completion/redirect integrity earns opus; absence of authorization or service access is a concrete blocker.

#### Expected Output

Real verified Windows form ID/embed/redirect allowlist, required server-side fields, and pending hosted-byte smoke record.

#### Success Criteria

- Windows form/redirect are dedicated and distinct from unchanged macOS form/redirect; destination is fixed to the intended versioned Windows EXE.
- Server-side name/email/WhatsApp validation and documented trusted success-event shape are verified; no invented form ID or arbitrary redirect parameter enters config.
- Without real provisioned/verified configuration the Windows entry stays null and unavailable; no real lead is created by automated tests.

#### Subtasks

- [ ] Inspect actual CF Gauss form/embed/redirect contract and existing authority; prepare concrete configuration with name, email, WhatsApp mandatory and exact Windows asset URL.
- [ ] Provision only if the current session authorizes external configuration; otherwise report precise required external action and continue independent candidate/QA work.
- [ ] Verify required fields server-side and trusted event/redirect identity; populate immutable Windows config only from observed IDs/URLs while keeping release unavailable until hosted evidence.
- [ ] Write/update synthetic form/redirect contract tests for blank/invalid fields, wrong form/source and Mac regression; save non-sensitive evidence and run site suite through mac-gate.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Dedicated form/redirect or authorization to provision is unavailable | High | High | Keep Windows config null; hand off exact requested form and destination for authorized setup. |
| Risk | A client-only required field or generic success event bypasses the lead gate | High | Medium | Prove server-side validation and exact form-bound success; reject all other events. |
