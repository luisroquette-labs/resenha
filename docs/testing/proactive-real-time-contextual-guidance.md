# Proactive real-time contextual guidance evidence

Status: candidate acceptance complete; merge and installed-build smoke remain.

## Frozen inputs and automated gates

- Corpus: `Tests/Fixtures/proactive-context-guidance.json`, SHA-256 `563e70806d2d980767943e49a0243d27b90755ccb7256be0494ce811785975b4`.
- Calibration: 15 rows. Evaluation: 60 rows across 15 families. Controls: 30 rows. Thresholds are token probability `0.85`, maximum logit gap `1.5`, and vocabulary similarity `0.45`.
- Exact product SHA `2e903ce641fe34c01ed54b6b6dff60b67d046a38`, tree `e60186c61e23f9fb0d22cd3f99aa934dc2e7d00e`.
- Full native suite: 236/236 passed, zero failures, `build/full-suite-2e903ce/Logs/Test/Test-WhisperKey-2026.10.22_23-41-05--0300.xcresult`.
- Focused contextual transport/corpus suite: 39/39 passed, zero failures, `build/threshold-085/Logs/Test/Test-WhisperKey-2026.10.22_23-40-14--0300.xcresult`.
- The real-engine alternating 20+20 warm benchmark passed its enforced evidence-collection p95 limit of at most 15% over the same engine with collection disabled. The callback also passed transcript-identity, selected-prefix alignment, 256-record, 128-prefix/token, and four-alternative bounds.
- Deterministic evaluation passed at least 20% relative error reduction, all 15 families, zero unauthorized changes, zero harmful span changes, and zero control regressions.

## Candidate artifact

- Release app `1.0.0` (`20261026`) and DMG were produced from the clean product SHA. Strict deep signature and designated-requirement checks passed.
- Executable SHA-256: `ef69e5131ede18f4ace0a705c2f5bddf9f23e8fec03ec8e5d3c451acc38b518b`.
- DMG SHA-256: `fd8ddcd09d4688496b8aa45f683e1c3712a60b8caba4844129f3cad9eb9d1f06`.
- Candidate app: `build/proactive-candidate-2e903ce/export/Resenha.app`. Candidate DMG: `build/proactive-candidate-2e903ce/Resenha-1.0.0-arm64.dmg`.
- The isolated candidate is signed but not notarized. Notarization and the final artifact are generated from the integrated SHA after merge.

## Real microphone and JEV proof

- Ten complete blocks plus two bounded cases produced 52 finalizations, 42 successful rolling provider decisions, and a conservative 110 rolling revisions from the content-free revision records. The required minima are 30, 20, and 100.
- Candidate-to-decision latency across the 42 successful rolling decisions: p50 `500 ms`, p95 `1,009 ms`, max `1,147 ms`; every accepted rolling decision completed below the `1,200 ms` hard deadline.
- The same run recorded 20 successful final decisions and 84 bounded timeouts. Timeouts caused no retry and preserved the local transcript. All ten complete blocks kept clipboard equal to the one inserted transcript.
- Unseen proof without a learned pair: the store contained only the unrelated learned `rosto -> Hostel` example. Synthetic `guite` produced user-visible `GitHub`, and the matching final JEV record has attempt `9C98EBC8-10D2-48C3-86AB-EC915250872F`, request `gen-dec-1792725131-w84ET0OyMeEvkR7qNJbR`, model `typesafe/jev-1.14-20261014`, `appliedReplacement`, 390 input/37 output tokens, USD `0.00001638`, and `690 ms`. Temporary test state was restored before the proof; no personal sentence was used.
- Learned ambiguity also produced visible `Hostel` with rolling and final `appliedReplacement` records on this candidate. Ordinary control text inserted unchanged with no provider record.
- Provider instability was observable rather than hidden: learned output succeeded in only 8 of the 52 stress cases because many final calls timed out or abstained. This does not violate fail-safe behavior, but it prevents a claim of 100% correction accuracy.

## Privacy, lifecycle, and UI

- The audit keeps only IDs, stage/revision/dispatch, confidence/probability, model, provider request ID, token usage/cost, latency, disposition, status, and sanitized failure. Literal scans found no synthetic sentence, heard value, replacement value, prompt, credential, authorization header, clipboard, history, or destination content.
- JEV receives one bounded sentence and exact choices only after explicit opt-in. Audio, logits/probabilities, full vocabulary, history, clipboard, app identity, and destination context remain local.
- Feature-off preserved local output and made no audit change. An app-scoped offline proxy test preserved local output after a bounded timeout; proxy variables were removed afterward. Cancellation while the hotkey was held produced no insertion and no late audit record.
- TextEdit and one disposable Chrome textarea each received one transcript with no duplication; the system clipboard matched the committed transcript. The disposable browser tab was closed without touching existing tabs.
- VoiceOver was enabled for the candidate window, exposed the expected accessible controls, then restored off. Reduce Motion reported active in-process, preserved control insertion, and was restored. These checks ran on product SHA `04956ed`; the only later product change was the candidate-admission threshold and its tests/fixture, with no UI, accessibility, focus, clipboard, or insertion-path change.
- At-rest observation on the final candidate was 35,440 KiB RSS and 0.0% CPU. `pmset` reported no thermal, performance, or CPU-power warning. Audio mute, glossary, correction store, proxy variables, VoiceOver, Reduce Motion, and disposable TextEdit documents were restored after testing.

## Consecutive clean reviews

Reviewed product SHA `2e903ce641fe34c01ed54b6b6dff60b67d046a38`, tree `e60186c61e23f9fb0d22cd3f99aa934dc2e7d00e`.

- Pass 1: no substantive finding. Reviewed complete diff/spec coverage, exact-choice schema, candidate safety, deadline/cost caps, cancellation/lifecycle, privacy/audit fields, corpus partitioning, physical attribution, and `git diff --check`.
- Pass 2: no substantive finding on the unchanged SHA/tree. Rechecked callback bounds/selected-prefix alignment, thresholds/fixture hash, accessibility/reduced-motion paths, full-suite result, clean worktree, and sanitized real-provider evidence.

## Remaining integration gate

Move the task spec to `done`, run the full suite on that evidence-only SHA, push the single task branch, merge the green PR, then build/sign/install and smoke-test the exact integrated SHA.
