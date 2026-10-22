# Continuous contextual intelligence evidence

Status: candidate baseline; physical acceptance pending

## Shipping contract

- Audio and recognition remain local. The optional rolling preview is confined
  to the Resenha HUD and never writes partial text to clipboard, history or the
  target application.
- The completed-WAV transcript remains authoritative and uses the existing
  single-insertion path. Late or cancelled revisions cannot edit committed text.
- Jev is a bounded decision evaluator for allowlisted occurrence alternatives.
  It is not an audio transcriber, next-token predictor or free-text generator.
- `PersonalRemoteReleaseDecision.current` is
  `personalRemoteUnavailable`; production personal dictation issues `.disabled`
  scope and makes zero remote requests. The separately authorized synthetic
  diagnostic does not change this release decision.
- The 500/100/50/650/750 ms values are acceptance targets, not measured product
  claims. Deterministic Step 08 results prove orchestration only.

## Deterministic evidence

The frozen `continuous-context-events.json` corpus contains 43 contextual cases
and 10 no-change controls. XCTest verifies revision ordering, strict decision
deadline behavior, bounded work, fail-open behavior, single final insertion,
cancel/revocation handling, corpus metrics and the closed remote authority. This
does not prove acoustic accuracy, capture-to-candidate latency, cold/warm model
behavior, real focus/clipboard preservation, VoiceOver speech, CPU, RAM or
thermal behavior.

## Candidate protocol

The product candidate must be committed and clean before physical execution.
The result append must record:

| Field | Required value |
|---|---|
| `tested_product_sha` / `tested_product_tree` | exact committed product tree |
| Source/config/resource manifest | sorted paths and SHA-256 from the same tree |
| App identity | isolated bundle path, executable SHA-256 and code-sign result |
| Environment | Mac model, Apple Silicon chip, RAM, macOS and recognizer model hash |
| Corpus | immutable fixture SHA-256 and physical spoken corpus/protocol |

Three hardware runs must total at least 100 real provisional revisions and 30
real finalizations. Each run compares completed-WAV and rolling ASR, then reports
sample counts, fallback/drop/coalescing counts and real monotonic p50/p95/max for
last-frame capture→candidate, candidate→decision, decision→preview and
release→commit. Cold/warm state, CPU, RAM and thermal observations are separate.
JSON timestamps, fake clocks, provider mocks and UI callbacks are not acoustic
or physical evidence.

## Physical checks required

1. Microphone → rolling HUD → completed-WAV final → one insertion in TextEdit
   and a disposable browser field, with target focus and clipboard behavior
   observed.
2. Late/cancelled work produces no external edit; feature-off and offline paths
   preserve current local dictation and make zero requests.
3. Keyboard, VoiceOver, increased contrast and reduced motion checks run against
   the exact isolated candidate without replacing `/Applications/Resenha.app`.
4. Frozen synthetic remote evidence remains unrun unless separately authorized;
   the previously supplied key was revoked.

## Physical result and provenance

PENDING. No physical/acoustic claim is made until a sanitized append identifies
the frozen candidate and satisfies the protocol above. If permissions, hardware
or user presence prevent 100 revisions, 30 finalizations, VoiceOver or target
field observation, that gate is recorded as unmet and personal remote capability
remains unavailable.
