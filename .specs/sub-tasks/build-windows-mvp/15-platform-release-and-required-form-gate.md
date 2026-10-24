# Step 15: platform release and required form gate

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 4
**Model:** opus
**Agent:** developer
**Depends on:** 03
**Parallel with:** 13, 14
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Add Windows release routing while preserving required name, email and WhatsApp.

Own site/release.mjs, site/windows-release-evidence.json, site/download-platforms.mjs, site/download-gate.mjs and Scripts/site.test.mjs. Trusted form messages and cross-platform artifact identity affect download integrity across modules and require opus. Real Windows form provisioning remains step 19; all Windows production config/evidence starts null.

#### Expected Output

Windows planned/unavailable slot, immutable validated platform configs and session-bound trusted form completion.

#### Success Criteria

- resolveDestination rejects missing/malformed/stale-source/cross-platform evidence and arbitrary URLs; planned Windows never renders an active destination.
- Gate requires exact trusted origin, current iframe event.source, message source, expected form ID and documented success; closing/reopening/switching cancels old handler/timer.
- All three form fields remain required, macOS original form/redirect remains unchanged, duplicate/forged/stale events cannot redirect and analytics contains no PII.

#### Subtasks

- [x] Implement Windows evidence validation and immutable platform configuration carrying platform/version/formId/formUrl/redirectUrl/artifactUrl/artifactSha256.
- [x] Refactor openDownloadGate(platform) around a fresh iframe/session generation, frozen config, one success and canceled stale handlers/timers; bound height messages.
- [x] Extend named site fixture groups while preserving every existing Mac negative/positive case and required-field checks; synthetic interception creates no real lead.
- [x] Run mac-gate node --test Scripts/site.test.mjs Scripts/windows-release.test.mjs, covering false completion, wrong platform, absent config, unavailable release and valid synthetic Windows/Mac routes.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | A stale Mac success event unlocks Windows or a Windows CTA yields DMG | High | High | Bind exact platform/form/window/generation and verify artifact extension/hash against immutable config. |
| Blocker | Real dedicated CF Gauss Windows form and redirect unknown | High | High | Keep Windows config null until authorized provisioning/verification in step 19; never invent query parameters. |
