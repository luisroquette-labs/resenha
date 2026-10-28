# 06 — Revision-bound Jev loop

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 2
**Model:** opus
**Agent:** opus
**Depends on:** 03
**Parallel with:** 04 and 05
**Note:** This changes shared contextual-correction contracts and repeated transport concurrency. Use doubles only; no paid call or personal text transmission is authorized here.
**Goal:** Evaluate eligible changed revisions through bounded typed Jev choices while keeping local preview/finalization non-blocking and preserving the original on every uncertain path. Local code may enumerate safe literal alternatives mechanically, but Jev is the sole semantic authority for keep/replace.

Modify `Sources/WhisperKey/ContinuousContextSession.swift` and `Sources/WhisperKey/ContextualCorrections.swift`. Extend requests/results with immutable revision/window identity and apply only locally supplied literal alternatives from acoustic evidence, vocabulary or confirmed examples. Deterministic code must not decide semantic fit; it only bounds and validates the alternatives that Jev evaluates. Run fuzzy enumeration off the MainActor, bound it to 600 characters, 200 terms, four-word/64-character terms and 4,096 edit-similarity evaluations per revision, then revalidate revision/policy/store authority before transport. Admit work no faster than every 500 ms, with one active request and one replaceable pending snapshot. Keep 0.90 confidence/probability thresholds, 200 ms hard decision deadline and 4096-byte payload ceiling.

#### Expected Output

The semantic loop repeatedly observes meaningful current revisions, asks only bounded keep/replace questions, and overlays a current decision on provisional text. Timeout, offline, ambiguity, malformed output, stale identity, changed examples/policy or unauthorized state preserve the exact local candidate with no retry or late edit.

#### Success Criteria

- Requests bind session, revision, source span, policy/store generation and deadline; application revalidates all fields against the current immutable window.
- Numbers, negations, identifiers, overlaps, conflicting examples, absent alternatives and invented output abstain unless existing deterministic validation proves safety.
- Dispatch respects 499/500/501 ms boundaries, one-active/one-pending latest-wins behavior and 4095/4096/4097-byte boundaries.
- `DecisionsStreamingTransport` proves callback/body/task isolation across a cancelled old request and a new request; no retry or alternate provider occurs.
- Tests with fake clock/provider cover 199/200/201 ms, 401/429/5xx, offline, invalid schema/probabilities, stale callbacks and repeated occurrences; zero real network calls.

#### Subtasks

1. Extend contextual occurrence/request/result types with immutable revision/window identity while preserving the existing one-shot diagnostic contract.
2. Add candidate admission, coalescing and strict response application to `ContinuousContextSession.swift`; keep the local path independent of network completion.
3. Isolate transport callbacks by session/task identity or prove a non-aliasing lifetime in `ContextualCorrections.swift`.
4. Add deterministic scheduler, validator and transport-overlap tests in `Tests/WhisperKeyTests/WhisperKeyTests.swift`; run targeted and full native gates via `mac-gate`.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Existing transport aliases task identifiers across sessions | High | Medium | Key state by connection/session plus task or restrict lifetime; prove cancelled-old/new overlap before enabling repeats |
| Risk | Network response rewrites committed text | Critical | Medium | Delivery-state guard before application and adversarial late-callback tests |
| Risk | Partial introduces PII after an earlier eligible snapshot | High | Medium | Re-run local eligibility on the full prospective payload before every dispatch |
| Risk | Frequent calls create latency/cost growth | High | High | 500 ms floor, meaningful-change gate, one-active/one-pending coalescing, no retry |
