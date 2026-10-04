# Step 22: current sha integration and release proof

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 6
**Model:** sonnet
**Agent:** tech-lead
**Depends on:** 21
**Parallel with:** None
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Close the single task PR only with current-SHA checks and persisted deployment evidence.

Own final PR/release evidence updates in docs/testing/WINDOWS-RELEASE-EVIDENCE.md and task completion status. Keep all changes on the dedicated branch and exactly one PR to main. This step follows existing approved integration authority; missing provider/check or merge authority is reported concretely. The plan itself executes none of these actions.

#### Expected Output

Final review/gate record and, only when actually authorized and successful, persisted merge/main-run/deployment/download proof.

#### Success Criteria

- Actual workflows/provider/check configuration is inspected; canonical applicable local checks pass via mac-gate and Windows evidence still identifies candidate bytes.
- Required Vercel Preview is green at latest PR SHA where configured; absence/conflict with required policy is resolved by owner rather than invented or silently waived.
- After authorized integration, main CI/provider reach terminal green and live required-form Windows/Mac routes match evidence; task remains incomplete when any release prerequisite is blocked.

#### Subtasks

- [ ] Run canonical mac-gate site/release/docs tests and applicable portable checks; verify Windows preflight/candidate tree evidence and all required current-SHA remote checks without bypass.
- [ ] Update only the existing task PR with candidate SHA/hash, latest PR SHA, Windows evidence, actual provider/check URLs and known SmartScreen disclosure; no direct main push.
- [ ] Under existing authorization merge/deploy through the verified real provider workflow, then monitor main CI and deployment to terminal state; no invented Vercel green or substitute provider.
- [ ] Add final live verification cases for release/form/download regressions, execute scoped post-deploy smoke with authorized test data, record commit/run/deployment/hosted hashes and leave incomplete gates unchecked.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Required Preview/provider configuration or integration authority unresolved | High | Medium | Stop integration, name missing exact check/authorization, retain single reviewable PR and prepared evidence. |
| Risk | Success is reported from older SHA or only HTTP 200 | High | Medium | Record latest commit/check/deployment identities and verify final downloaded bytes plus trusted completed-form route. |
