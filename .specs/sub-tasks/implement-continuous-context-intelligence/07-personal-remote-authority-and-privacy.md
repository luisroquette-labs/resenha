# 07 — Personal remote authority and privacy

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 2
**Model:** opus
**Agent:** opus
**Depends on:** 05 and 06
**Parallel with:** None
**Note:** This establishes a distinct recurring personal-data/cost authority and contains an executable ship/no-ship gate. Do not reuse `SyntheticDiagnosticAuthorizationOwner`, automatically select credentials/providers, make a paid call or weaken eligibility/ZDR constraints.
**Goal:** Decide and enforce whether personal remote Jev evaluation is shippable; either complete every privacy/publication surface for a disabled-by-default revocable mode or prove the production route remains unavailable/off.

First write a checked release decision from the current source and policy evidence. **Ship branch:** only when the owner has explicitly authorized recurring personal transmission/cost and local eligibility plus current provider/privacy routing are verifiable, modify `Sources/WhisperKey/ProductPreferences.swift`, `Sources/WhisperKey/WhisperKeyApp.swift`, `Sources/WhisperKey/ContinuousContextSession.swift` and `Sources/WhisperKey/ContextualCorrections.swift`; audit `Config/PrivacyInfo.xcprivacy` and either update it or record why its Apple schema is unaffected; update `docs/PRIVACY.md`, `docs/specs/20-privacy-review.md`, `site/privacy/index.html` and `Scripts/site.test.mjs`. Expose a disabled-by-default, revocable control that discloses exact text/examples, provider and frequency/cost behavior. **Closed branch (default if any prerequisite is absent):** add no enabling personal-remote control/production dispatch authority; compile the route unavailable, show truthful local-only status and assert zero personal requests. In both branches, revocation/error/termination clear pending/transient state.

#### Expected Output

One mutually exclusive branch is implemented and tested. If shipping is authorized, a user can deliberately enable/revoke the disclosed remote capability without affecting local dictation and all manifest/public-copy/site-test surfaces agree. Otherwise the release binary has no personal-remote authority or enabled control and local contextual preview remains available. Session context is bounded, never persisted/logged and discarded on every terminal/authority change.

#### Success Criteria

- A deterministic test records exactly one release decision: `personalRemoteAvailable` or `personalRemoteUnavailable`, with no runtime fallback between branches.
- Ship branch: fresh installs/upgrades default off; synthetic authorization cannot enable it; consent names OpenRouter/TypeSafe, content/examples, dispatch/cost bounds and credential requirement.
- Ship branch: `Config/PrivacyInfo.xcprivacy` has a recorded schema audit/change, while `docs/PRIVACY.md`, `docs/specs/20-privacy-review.md`, `site/privacy/index.html` and `Scripts/site.test.mjs` truthfully cover personal text transmission; native and site gates pass.
- Closed branch: no user path or production token can authorize personal text; tests prove zero requests and local-only status, while existing manifest/public claims remain accurate.
- Revocation and 401/billing failure cancel/invalidate current work and prevent new dispatch while local recognition/final insertion continue.
- Tests prove zero requests when off/offline/no credential/ineligible, transient context release, no content/secret logs and no retained tasks after cancellation.
- Settings are keyboard/VoiceOver accessible and never claim Jev latency/PT-BR quality or ZDR status that has not been measured/verified.

#### Subtasks

1. Evaluate the ship prerequisites and encode one explicit release decision with a failing test for the opposite/unintended branch.
2. Ship branch: introduce the minimum distinct authority, gate every dispatch, add settings/lifecycle invalidation, audit/update the privacy manifest, update public policy plus `docs/specs/20-privacy-review.md`, and add site assertions. Closed branch: remove/omit production personal authority and assert the route/control are unavailable.
3. In either branch, preserve local/offline dictation and add revocation, auth/billing, retention, log-redaction and accessibility tests in `Tests/WhisperKeyTests/WhisperKeyTests.swift`.
4. Run the full native gate via `mac-gate`; when the ship branch changes `site/**` or `Scripts/site.test.mjs`, also run `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`. No publication or provider call occurs.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Product cannot reliably classify personal data locally | High | Medium | Keep personal remote mode unavailable; allow only manually reviewed synthetic fixtures |
| Blocker | Recurring personal transmission/cost lacks current owner authorization | High | Medium | Select the closed branch; do not expose a production enablement path |
| Risk | Diagnostic consent is treated as recurring consent | Critical | Medium | Separate owner/key and explicit tests proving no authority inheritance |
| Risk | Cancellation leaves context retained by tasks | High | Medium | Structured ownership, generation invalidation and weak-reference/buffer probes |
| Risk | UI implies zero retention or guaranteed low cost | High | Medium | Use factual disclosures and verified account/provider state only; no guarantee language |
