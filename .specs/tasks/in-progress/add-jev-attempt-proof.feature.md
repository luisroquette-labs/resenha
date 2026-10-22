---
title: Add privacy-preserving proof for personal JEV attempts
depends_on:
  - .specs/tasks/done/add-context-aware-corrections.feature.md
  - .specs/tasks/todo/implement-continuous-context-intelligence.feature.md
---

## Goal

Prove locally whether personal transcription reached JEV without storing dictated text, audio, correction pairs, credentials, clipboard content, or destination-app data.

## Acceptance criteria

1. The single personal `OpenRouterDecisionsClient` emits a correlated start and terminal event for every evaluation requested by both continuous preview and final resolution.
2. A successful provider response persists only timestamp, status, resolved model, provider request ID, decisions, minimum confidence/probability, latency, token counts, reported USD cost, and whether the response was applied, kept, or discarded.
3. Failure persists only a sanitized category. Records never accept content or credentials, are capped at 20, use a separate versioned local file, and can be deleted.
4. Settings show the latest attempt and distinguish `requested`, provider-confirmed success, failure, and whether a successful response actually guided the output. Only success may claim that JEV answered.
5. XCTest covers success, failure, persistence, cap, deletion, and verifies serialized bytes contain no supplied sensitive sentinel.

## Execution loop

- Planning: map the shared personal client and settings composition; reject instrumentation duplicated in both resolver loops.
- Implementation: wrap observation at the personal client boundary and expose the bounded local record in Transcription settings.
- Test: run focused RED/GREEN tests, regenerate the project, then run the serialized native gate.
- Repeat any failed stage until green; prepare a physical test that checks the UI record against one controlled dictation.

