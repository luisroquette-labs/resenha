---
title: Preserve an on-time JEV decision through local validation
depends_on:
  - .specs/tasks/in-progress/add-jev-attempt-proof.feature.md
---

## Goal

Apply a valid JEV response that wins the deadline race, even when local validation finishes after the deadline, without accepting a provider response that arrived late.

## Physical evidence

The personal test produced two provider-confirmed responses. The lodging sentence returned `replace_1` with 0.98 confidence and 0.99 selected probability in 892 ms, but the app recorded it as discarded. The ordinary face sentence returned low confidence and was correctly preserved.

## Acceptance criteria

1. Provider completion is measured at the response boundary: before 900 ms for final resolution and before 200 ms for continuous preview.
2. A response that arrived on time remains eligible while local store, policy, decision and revision validation runs.
3. A response at or after either deadline still preserves the original text, with no retry or timeout increase.
4. Regression tests cover on-time arrival followed by post-deadline validation for both paths and retain the existing 199/200/201 ms and 899/900/901 ms boundaries.

## Execution loop

- Planning: use the existing race and clocks; add no transport or configuration.
- Review: verify all resolver and continuous-loop callers retain cancellation and stale-state checks.
- Implementation: timestamp provider completion once and remove only the redundant post-race clock check.
- Test: run focused boundary regressions, then the full serialized native gate; repeat on failure.
