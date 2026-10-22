# 09 — Physical proof, docs and delivery

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 3
**Model:** sonnet
**Agent:** sonnet
**Depends on:** 08
**Parallel with:** None
**Note:** Do not replace the user's installed app, publish a release/store build, make a paid API call or merge the PR before the Phase 3 reviewer. Missing physical/provider authority is a recorded unmet gate, not a simulated pass.
**Goal:** Freeze the final product tree, then validate that exact candidate on real Apple Silicon and document exactly what deterministic, physical and separately authorized remote evidence proves before integration.

First finish every product-code, resource, fixture, smoke-test and documentation-baseline change, including the exact ship/closed branch from 07. Run all applicable gates, commit that candidate, record its commit/tree plus a source/config/resource manifest, and build from that exact clean tree in an isolated path. Only then run microphone-to-HUD-to-final-field proof without overwriting the installed app. `docs/testing/continuous-context-intelligence.md`, `README.md`, `docs/PRIVACY.md` and `docs/architecture.md` must already contain their final non-result baseline before the physical run. Afterward, only append sanitized result/provenance fields to the testing evidence; any other tracked change invalidates the candidate and requires a new gate/build/physical run. A frozen synthetic remote run remains separately authorized.

#### Expected Output

An exact committed product tree has green gates and a hashed isolated candidate. Physical evidence from that candidate compares completed-WAV and rolling ASR and measures real capture-to-candidate/cold-warm/resource behavior; deterministic Step 08 results remain labeled orchestration-only. A later evidence-only commit may append the tied results and prepare the unmerged PR for Phase 3 review.

#### Success Criteria

- Before physical testing, all product/resource/test/docs-baseline changes are committed; the report identifies that candidate commit/tree, source/config/resource manifest, binary hash/signature, model, hardware, OS and corpus hash.
- Across three physical runs, at least 100 real provisional revisions and 30 real finalizations compare completed-WAV versus rolling ASR and report actual last-frame capture→candidate, candidate→decision, decision→preview and release→commit p50/p95/max, cold/warm state, fallbacks, dropped/coalesced revisions, CPU, RAM and thermal observations.
- No fake clock, JSON event timestamp, mock provider or UI callback timing is accepted as acoustic accuracy, capture→candidate, cold/warm or resource evidence.
- Physical observation confirms provisional text stays in Resenha, target focus/clipboard are preserved, release inserts once and late/cancelled work creates no external edit.
- Keyboard, VoiceOver, increased contrast and reduced motion checks pass on the candidate; offline/feature-off dictation preserves current behavior with zero requests.
- README/privacy/architecture state that Jev chooses allowlisted alternatives asynchronously, not audio or arbitrary next tokens, and distinguish intended from measured capability.
- `Tests/WhisperKeyTests/WhisperKeyTests.swift` has smoke assertions for the final user-facing preview/fallback labels and remote-disabled state documented here.
- Ship branch has manifest/public/App Store/site evidence and green conditional site tests; closed branch has executable proof of unavailable personal remote dispatch and no misleading publication change.
- After proof, the only allowed tracked delta against the tested candidate is the appended result/provenance block in `docs/testing/continuous-context-intelligence.md`; any source, config, resource, fixture, test or other documentation change forces a new candidate, gate, build and physical run.
- The evidence commit records both `tested_product_sha/tree` and its own SHA; the single PR may be opened/updated but remains unmerged until the Phase 3 reviewer passes it.

#### Subtasks

1. Finish product code/resources, add final XCTest smoke assertions, complete README/privacy/architecture plus the non-result testing-report baseline, run native/conditional site gates and commit the clean candidate.
2. From that exact commit/tree, create an isolated signed candidate; record source/config/resource manifest and hashes before launching it, without replacing `/Applications/Resenha.app`.
3. Execute three real-hardware runs totaling at least 100 provisional revisions and 30 finalizations; compare completed-WAV/rolling transcripts and collect real monotonic stage latency, cold/warm, fallback/churn and CPU/RAM/thermal evidence.
4. If and only if separately authorized, run the frozen eligible synthetic remote sample once; otherwise record it unrun and keep remote mode off.
5. Append only sanitized results/provenance to `docs/testing/continuous-context-intelligence.md`, verify the post-proof diff allowlist and hashes, commit/push and prepare/update the unmerged PR for reviewer inspection.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Microphone/Accessibility/VoiceOver is unavailable | High | Medium | Record the exact unmet physical gate and keep the capability off; fake events cannot replace the run |
| Risk | Test candidate overwrites the working installed app | High | Low | Use isolated build path/bundle and verify installed bundle remains unchanged |
| Risk | Documentation turns vendor median or fake result into product claim | High | Medium | Label every evidence class and cite actual candidate/model/hardware/sample |
| Risk | Any tracked non-evidence change occurs after physical proof | High | Medium | Enforce the one-file result-append allowlist; otherwise create a new candidate and repeat gate/build/physical proof |
| Risk | PR merges before whole-phase review | High | Low | Step ends with an unmerged PR; only the task-level post-review directive may integrate it |
