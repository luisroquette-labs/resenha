# Step 21: site promotion and hosted form smoke

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 6
**Model:** opus
**Agent:** developer
**Depends on:** 16, 19, 20
**Parallel with:** None
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Enable Windows only after evidence projection and exact hosted form-to-artifact verification.

Own generated site/windows-release-evidence.json, Windows published record in site/release.mjs and final platform/gate evidence. This crosses artifact/source/hosting/form trust boundaries. Use promote-release.mjs as sole projection producer; no hand-authored passed flags. Keep native source/pins/fixtures/build inputs identical to candidate.

#### Expected Output

Reviewable site activation diff with complete evidence, tested mandatory form routing and unchanged Mac behavior.

#### Success Criteria

- Promotion succeeds only for the exact verified candidate/hosted report/form config; all negative evidence fixtures still leave Windows unavailable.
- An explicitly authorized real hosted-flow smoke reaches the Windows bytes matching manifest hash; automated tests use synthetic intercepted submissions.
- Name/email/WhatsApp stay required and macOS still resolves its original trusted form and DMG; native candidate tree is unchanged by site-only commits.

#### Subtasks

- [ ] Run full verify-release.ps1 and promote-release.mjs --manifest --download-report; review public allowlist projection and enable only matching Windows record.
- [ ] Run all site/release negative fixtures plus browser gate regression through mac-gate; verify latest platform copy and disclosures.
- [ ] Perform the real hosted form smoke only with authorized controlled submission, record resulting URL/hash and required-field proof without retaining lead PII; block activation if no valid smoke can be obtained.
- [ ] Add regression tests for newly observed routing issues, compare candidate native/pin/fixture/build trees to current branch, and attach immutable reports to the task PR evidence.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | New site commit is mistaken for candidate build SHA or modifies native inputs | High | Medium | Record both SHAs and compare exact build-input tree; changes require rebuilding and rerunning steps 17–20. |
| Blocker | Authorized real form submission or complete matching evidence unavailable | High | Medium | Leave Windows planned/unavailable; synthetic browser passes cannot establish hosted release completion. |
