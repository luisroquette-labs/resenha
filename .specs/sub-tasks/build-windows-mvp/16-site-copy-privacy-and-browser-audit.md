# Step 16: site copy privacy and browser audit

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 4
**Model:** sonnet
**Agent:** developer
**Depends on:** 01, 15
**Parallel with:** 13, 14
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Make website claims and browser evidence match actual platform availability.

Own site/index.html, site/styles.css, site/alternativa-wispr-flow/index.html, site/privacy/index.html and Tools/site-audit/audit.mjs. Update docs/PRIVACY.md only after step 01 ownership is complete. Follow settled platform release/gate APIs; do not redesign Mac assets or app.

#### Expected Output

Truthful Windows status/requirements/privacy copy and current browser regression evidence with input fingerprints.

#### Success Criteria

- Windows remains explicitly unavailable without evidence; macOS screenshots stay labeled and no parity/universal insertion/vendor support promise is added.
- Name/email/WhatsApp requirement and Windows local storage/microphone/manual-paste limits are disclosed consistently.
- Browser audit reflects current UI, fingerprints platform config/release evidence/gate and covers desktop/mobile CTA behavior with synthetic intercepted forms.

#### Subtasks

- [ ] Add release-dependent Windows card/copy and exact OS/CPU/RAM requirements in home and comparison page without altering the Mac destination.
- [ ] Update website and application privacy disclosures for model download, temporary owned audio, RAM-only result and required site WhatsApp.
- [ ] Refresh audit.mjs stale prototype assertions, current fingerprints and platform-specific modal flows; keep existing supported browser layouts.
- [ ] Write browser regression cases for keyboard navigation, close/reopen/platform switch, required blank fields and no real submission; run browser checks through mac-gate and retain reports.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Static copy advertises Windows before release validator accepts | High | Medium | Bind availability text/CTA to release state and test planned/malformed/valid fixtures. |
| Risk | Audit generates real leads or captures personal data | Medium | Medium | Intercept synthetic submissions and limit captured reports to non-sensitive state/identity evidence. |
