---
title: Add proactive real-time contextual guidance
depends_on:
  - .specs/tasks/todo/implement-continuous-context-intelligence.feature.md
---

## Initial User Prompt

“Vamos considerar o primeiro passo, onde o JEV atende de forma preventiva, cumprido. Vamos seguir para a parte mais difícil: o JEV na transcrição em tempo real, direcionando tudo que é falado juntamente para o contexto onde está inserido. A ideia maior é se aproximar do teclado do iPhone.”

# Description

**What:** Extend the existing rolling Whisper + JEV pipeline so it can propose and evaluate contextual alternatives without requiring a previous dislike. Whisper remains the local recognizer and candidate producer. JEV remains a bounded decision model: it chooses among exact alternatives attached to exact recognized spans. An accepted choice becomes ephemeral vocabulary for later rolling windows and the authoritative final pass of the same push-to-talk attempt.

**Why:** The current continuous path evaluates only terms already taught through feedback. It can correct `rosto -> Hostel` after learning that pair, but it cannot proactively use ambiguity exposed by Whisper itself. The new phase must detect uncertainty locally, obtain real acoustic alternatives from the same Whisper inference, and use the evolving sentence to choose conservatively.

**Who:** Resenha users dictating in Brazilian Portuguese on Apple Silicon. English and Spanish keep the current behavior until separately calibrated.

## Product Boundary

This phase is “iPhone-like” only in the following bounded sense: the current utterance is revised as new spoken context arrives. It does not predict words that were not spoken, read the destination field, listen outside push-to-talk, or freely rewrite prose.

JEV does not transcribe audio or generate alternatives. Whisper produces the transcript, token confidence, and top acoustic alternatives. Local code validates and binds candidates. JEV may only select an exact supplied option or keep the original.

## Scope Included

1. Extract chosen-token confidence and bounded top-k acoustic alternatives through public whisper.cpp APIs during the existing inference; never run a second recognition pass.
2. Convert only low-confidence lexical spans into exact candidate sets. Prefer acoustic alternatives; use a close canonical term from the local glossary/contextual store only when no safe acoustic alternative exists.
3. Evaluate eligible candidates repeatedly while recording, using the current sentence and rolling text. Keep one active request plus one replaceable latest pending request; an active result may reach a newer revision only through RT-6A validation and the strict deadline.
4. Feed accepted canonical terms into later rolling prompts and the final pass of the same dictation attempt; erase them on commit, cancel, failure, permission loss, opt-out, or app termination.
5. Apply a final decision only before the existing single insertion. Late work never changes external text.
6. Expose sanitized counters, latency, provider request ID, resolved model, and cost already available in the attempt audit; never persist transcript content or alternatives.

## Scope Excluded

1. Next-word completion, text generation, paraphrasing, punctuation style rewriting, grammar correction, or replacement of high-confidence spans.
2. Automatic persistence of accepted terms, training from history, clipboard/application context, screen capture, or cross-session personalization.
3. A second Whisper inference for alternatives, a new provider/model, embeddings, a backend, or a new dependency.
4. Expansion beyond PT-BR before an independent corpus proves safety and benefit.
5. Unlimited remote evaluation. The existing explicit personal-text opt-in and Keychain credential remain mandatory.

## Acceptance Criteria

| ID | Requirement |
|---|---|
| RT-1 | Real whisper.cpp inference returns the recognized text plus chosen-token probability and top-k alternatives captured from the same decode; test doubles may return text-only evidence and must safely produce no proactive request. |
| RT-2 | The logits callback is observational: it never modifies logits, retains no audio, filters special/invalid/non-lexical tokens, caps candidates, and proves that alternatives are bound to the selected beam prefix before use. |
| RT-2A | Collector state is capped at 256 callback records, 128 suffix prefix-IDs per record, and four alternatives per record. On the frozen local audio benchmark, evidence collection adds no more than 15% to warm Whisper inference p95 versus the same build with collection disabled. |
| RT-3 | Candidate generation is deterministic, PT-BR-only, restricted to low-confidence lexical spans in the current rolling text, produces at most one occurrence with at most three exact alternatives per rolling request, and preserves numbers, currency, URLs, email, code-like identifiers, and negations unless the original is selected. |
| RT-3A | A proactive rolling candidate is dispatched only after the same heard span, ordinal, and exact option set survive two consecutive accepted Whisper revisions. Learned exact pairs retain their current behavior; the authoritative final pass does not require two rolling sightings. |
| RT-4 | Acoustic alternatives outrank local-vocabulary fallback. Fallback uses only the current glossary and confirmed contextual canonical values, is similarity-bounded, and never searches history or remote data. |
| RT-5 | JEV receives one bounded sentence, language, heard span, ordinal, and exact choices. Its response must name a supplied choice; confidence and selected probability must both be at least 0.90, otherwise the original remains unchanged. |
| RT-6 | Rolling evaluation is non-blocking with a 1,200 ms hard deadline and no retry. Work remains one active plus one replaceable pending item, starts no more often than every 500 ms, and is additionally capped at six provider dispatch attempts per dictation attempt. The budget is consumed before calling the provider and is never refunded. |
| RT-6A | A rolling result may rebase onto a newer hypothesis only when the complete source text evaluated by JEV remains an exact prefix of the newer text and the same heard occurrence/options still validate there. Any edit inside the evaluated prefix, occurrence, or options discards the result. |
| RT-7 | An accepted choice updates only the Resenha provisional preview and an in-memory session vocabulary of at most five terms. The next rolling inference and final inference receive that vocabulary; external text and history remain untouched before commit. |
| RT-8 | Finalization uses the completed WAV as authority, permits one bounded final JEV decision under the existing 900 ms deadline, inserts once, and ignores every late/stale/cancelled result. |
| RT-9 | Feature off, unsupported language, missing/invalid credential, offline state, timeout, malformed response, alignment failure, no safe candidate, exhausted call budget, or any internal error preserves the existing local transcript with zero blocking retry. |
| RT-10 | Remote text continues to require the existing explicit personal-text authorization. Authorization may be enabled without a saved feedback example when proactive local evidence is available, but dispatch still requires a concrete safe candidate. Audio, token logits/probabilities, complete vocabulary, app identity, clipboard, history, and destination content never leave the Mac. |
| RT-11 | A frozen PT-BR corpus separates calibration and evaluation. Evaluation has at least 60 ambiguous utterances across 15 term families plus 30 no-change controls; zero unauthorized span changes and zero semantic regressions in controls are mandatory, with at least 20% relative error reduction versus current main. |
| RT-12 | Real hardware proof records at least 100 rolling revisions, 30 finalizations, and 20 real rolling provider decisions; candidate-to-decision p95 must remain below the 1,200 ms hard deadline and evidence-collection overhead must satisfy RT-2A. Record p50/p95/max for all existing stages, provider dispatch-attempt count, actual provider request count, stale/rebased/fallback rate, CPU/RAM/thermal observations, and exact build/model provenance. It must include unseen ambiguity, learned ambiguity, ordinary controls, cancellation, offline, and cost evidence. |
| RT-13 | UI labels this as contextual correction during speech, not prediction of unspoken words. VoiceOver does not announce every revision; reduced motion, focus, clipboard, hotkey, and single-insertion behavior remain intact. |
| RT-14 | Native gates pass through `~/.local/bin/mac-gate`, one task branch/PR is used, applicable latest-SHA checks are green, and the exact merged build is installed only after physical approval. |

## Candidate Rules

- A lexical span is eligible only when the selected token probability is below the calibrated threshold and the span belongs to the current rolling text. A result for an older revision can affect the latest preview only through RT-6A rebase validation.
- A captured acoustic alternative is eligible only when it maps to one complete lexical span, differs from the original after case/diacritic folding, is within the calibrated logit-gap threshold, and survives protected-content checks.
- Vocabulary fallback considers canonical glossary terms and confirmed contextual canonical values only. It selects one deterministic nearest term after bounded normalized Damerau-Levenshtein comparison; below-threshold similarity produces no candidate.
- Learned heard/canonical examples retain priority when the exact heard term occurs. Proactive evidence supplements them; it does not weaken their existing validation.
- Proactive rolling stability is keyed only by folded heard value, ordinal, and ordered exact options. Any change resets the count; no transcript content is persisted.
- Thresholds are selected on calibration rows and frozen before evaluation. Evaluation rows never tune thresholds.

## Required Tests

1. Pure unit tests for beam-prefix alignment, top-k filtering, lexical span construction, protected content, deterministic fuzzy fallback, candidate priority, threshold boundaries, and exact-option response parsing.
2. Integration tests for rolling prompt updates, final prompt handoff, six-dispatch budget, stale revisions, deadline races, opt-out/credential deletion, cancellation, session erasure, and one final insertion.
3. A real whisper.cpp fixture proving the callback produces evidence aligned to the returned selected transcript without changing that transcript.
4. Frozen corpus comparison against `origin/main`, with independent row audit and deterministic replay.
5. Physical microphone E2E on the exact candidate build, followed by installed merged-build smoke tests.

## Evidence and Claim Limits

- Mock/deterministic tests prove orchestration, not acoustic quality or latency.
- A provider response proves JEV participated only when request ID, resolved model, cost/usage, disposition, and matching revision are present.
- A corrected output alone does not prove JEV caused it; Whisper prompting and local postprocessing must be separated in the trace.
- If the evaluation or physical gate fails, the feature remains experimental/off by default and the failed claim is documented rather than softened.
