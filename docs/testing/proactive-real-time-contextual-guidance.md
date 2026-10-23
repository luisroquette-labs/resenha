# Proactive real-time contextual guidance evidence

Status: automated candidate validation complete; physical/provider proof pending.

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

## Pending physical evidence

The signed-app hardware corpus, real provider request proof, p50/p95/max latency, resource measurements, accessibility checks and installed-build provenance are intentionally not claimed here until Task 7 records them.
