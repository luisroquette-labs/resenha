# Proactive real-time contextual guidance evidence

Status: automated candidate validation complete; physical/provider proof partially collected.

## Frozen inputs

- Corpus: `Tests/Fixtures/proactive-context-guidance.json`
- File SHA-256: `a5a2c1f25be5c6270f7f5c5c07f4cd2fef473560e732794e247383b432254dff`
- Calibration: 15 rows; evaluation: 60 rows across 15 families; controls: 30 rows.
- Runtime thresholds: token probability 0.65, maximum logit gap 1.5, vocabulary similarity 0.45.

## Automated evidence

- Local Whisper evidence adds no second inference or network request.
- Candidate order is learned, acoustic, then vocabulary; protected terms fail closed.
- JEV can return only `keep_original` or one of `replace_1...replace_3`.
- Rolling decisions require two identical proactive sightings, expire at 1,200 ms and share a six-dispatch attempt budget with the 900 ms final decision.
- Accepted terms are kept only for the active attempt, capped at five, used by later rolling and completed-WAV prompts, and cleared on terminal paths.
- Evaluation replay is deterministic, covers all 15 families, requires at least 20% relative error reduction, and permits zero unauthorized/control changes.

## Privacy boundary

JEV receives the bounded current sentence and exact option labels/values only after opt-in. Audio, token logits/probabilities, full vocabulary, history, clipboard, target-application context, API credentials and free-form output remain outside the request and local audit.

## Partial physical/provider evidence

Candidate product SHA: `de8962ddb44523c5ce2bf6a2f8d5cd47aa397c82` (tree `613f397ec64d042ffa6011e4b708553c30732071`).

- Release app `1.0.0` (`20261024`) passed strict deep signature verification. The exported candidate is not notarized, so Gatekeeper assessment rejects it as `Unnotarized Developer ID`; it remains a test candidate and has not replaced `/Applications/Resenha.app`.
- Executable SHA-256: `661006ca407a4ce614bb35daf780c7bf995e86b2db9fdd834cbb04f698d10afe`.
- Model SHA-256: `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
- DMG SHA-256: `e0ca8183307b67256a94cfb5d5ec45dd70c3181cd10bc6ad265a1386772b9957`.
- The content-free audit contains 17 correlated successful provider decisions across nine dictation attempt IDs: eight rolling and nine final. Five attempts have rolling evidence whose per-attempt maximum revisions establish a conservative lower bound of 27 real provisional revisions. Rolling candidate-to-decision latency was 393/451/457/465/468/541/553/612 ms (median 466.5 ms; p95/max 612 ms), below the 1,200 ms deadline.
- The correlated decisions contain provider request IDs and resolve to `typesafe/jev-1.14-20261014`. The entire audit contains 20 records, two failed requests, seven applied replacements, 11 discarded results and USD 0.000301686 total reported cost.
- A literal scan against every frozen fixture sentence, vocabulary term, selected token and acoustic alternative found zero content matches in the persisted audit. Its JSON paths contain no authorization, credential, prompt, sentence, heard-term, canonical-term or replacement-value field.
- One learned-ambiguity dictation has matching rolling and final records for the same attempt ID, exact dispatch ordinals 2 and 3, applied replacement dispositions, provider request IDs, resolved model, usage/cost and 612/570 ms latency. The user-visible output contained `Hostel`; this proves JEV participated in that attempt without storing the sentence or option values in the audit.
- A short unseen-ambiguity probe produced user-visible `seção`, `sexta` and `senso`, while `célula` remained `cela`. Those outputs are not attributed to JEV because the interrupted overlapping run did not preserve reliable per-case correlation and the local Whisper glossary prompt could independently produce them.
- At rest after the interrupted probe, the candidate used 34,304 KiB RSS and 0.3% CPU. The temporary glossary was restored to the pre-probe value, audio output was remuted, and no test launcher or synthetic speech process remained.

Task 7 remains open: the evidence does not yet satisfy 100 rolling revisions, 30 finalizations, 20 rolling provider decisions, unseen/learned/control attribution, offline/cancellation/feature-off, browser/focus/clipboard/single-insertion, VoiceOver/reduced-motion, thermal observations, or installed merged-build smoke proof. Physical UI automation is suspended while the owner is using the Mac.

## Consecutive clean reviews

Reviewed product SHA: `de8962ddb44523c5ce2bf6a2f8d5cd47aa397c82`.

- Pass 1: no substantive finding. Checked spec coverage, full diff, selected-beam alignment, exact-choice schema, privacy/cost bounds, cancellation/lifecycle, corpus partitioning, UI copy/accessibility, correlated audit context, rolling latency measurement and atomic dispatch ordinals.
- Pass 2: no substantive finding on the unchanged SHA/tree. Repeated the same checklist and confirmed a clean worktree plus targeted regression evidence. The earlier 233-test result predates the final audit-correlation refinements; the full native gate remains intentionally skipped under the owner's explicit preflight bypass.
