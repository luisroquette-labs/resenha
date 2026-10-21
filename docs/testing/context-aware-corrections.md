# Context-Aware Corrections Evidence

## Candidate

- Branch: `feat/context-aware-corrections`
- Base SHA: `b72b9d3962e172002f20b8000755ad365d86529f`
- Tested product source SHA: `9c1beac20df5468e14376cd0d279ce6aaf6cc8b0`
- Tested product source-manifest SHA-256: `1904d5268c3e6dd1e18f8030bc93580360a1a618338914873f4c672e0dbcc7ce`
- Tested executable SHA-256: `6f31320161e2c8166d2ad793c1bcff2e5d7d7a9ae6e980dff5c5701c14285582`
- Corpus: `2026-10-20.1`, 100 synthetic cases
- App resource SHA-256: `8c53cbc31ced6448aa7629d070794093c04acf3faf50e647a3f596305884393d`

## Offline evidence

- Native gate: PASS on 2026-10-21; 160/160 tests; `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`.
- Requests observed in XCTest: 0 real; injected protocol only.
- Frozen alpha contract: retrieved 2026-10-21T20:30:00Z from [Decisions API](https://openrouter.ai/docs/api/api-reference/decisions/create-decisions), [Jev tutorial](https://openrouter.ai/docs/guides/community/jev-tutorial), and [Jev 1.14](https://openrouter.ai/typesafe/jev-1.14). Endpoint/model: `POST https://openrouter.ai/api/alpha/decisions`, `typesafe/jev-1.14`. Request fields are `model`, `questions[].id`, `questions[].question`, and `questions[].options[].id|label`; response reads `answers[].question_id`, `choice`, `confidence`, `probabilities`, plus typed `model` and `usage`. Golden owner: `testFrozenAlphaDecisionsDTOEncodesRequestAndDecodesOfficialResponseFixture`.
- Independent corpus audit: `/root/corpus_independent_audit_v2`, 2026-10-21T19:35:52Z; fixture SHA-256 `8c53cbc31ced6448aa7629d070794093c04acf3faf50e647a3f596305884393d`; local audit SHA-256 `23d5d2c87bdd32e2c267c5a296627714a654230571c3285ac40b946a54597ea4`; 100/100 PASS. The seven-column, 100-row table is retained locally at `build/evidence/context-aware-corrections/offline/corpus-review.md` and identified by that hash.
- Corpus report: `build/evidence/context-aware-corrections/offline/corpus-report.json`; SHA-256 `e37cdee9a56142fb521c95747e37fdf1c72182448dc978edf137eb29762672a3`.
- Acceptance gate: all 65 evaluation rows covered; 20 eligible positives; contextual recall 1.00; zero false positives, unauthorized mutations, and harmful span changes. Calibration and diagnostic rows are excluded from acceptance.
- Interpretation: contract and safety logic only; Jev PT-BR quality is not measured.

| Strategy | total | correct | false positives | unauthorized | harmful spans | eligible | recall | abstentions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Contextual | 100 | 100 | 0 | 0 | 0 | 20 | 1.00 | 15 |
| Keep original | 100 | 70 | 0 | 0 | 0 | 20 | 0.00 | 35 |
| Global replacement | 100 | 30 | 36 | 36 | 52 | 20 | 1.00 | 0 |

Each of `censo-senso`, `cesta-sexta`, `conserto-concerto`, `rosto-hostel`, and
`sessao-secao` has 20 rows. Contextual results are 20/20, 4/4 recall, zero
false positives/unauthorized/harmful changes, 3 abstentions, minimum margin
0.94 and median margin 0.96. Keep-original is 14/20 with 7 abstentions per
pair. Global replacement is 6/20 per pair; the first four pairs each have 7
false positives, 7 unauthorized mutations and 10 harmful changes, while
`sessao-secao` has 8, 8 and 12 respectively.

## Controlled diagnostic contract

- Endpoint: `POST https://openrouter.ai/api/alpha/decisions`
- Requested model: `typesafe/jev-1.14`
- Fixture: `pt-rosto-hostel-diagnostic-001`
- Dispatch: one call, zero retry, one-shot guard consumed before send
- Current listed price checked 2026-10-21: input US$0.042/M tokens; output US$0/M tokens. With the bounded fixture below 1,000 input tokens, upper bound is US$0.000042, excluding OpenRouter fees or future price changes.
- Result: NOT RUN until Task 7 replaces this line pre-merge with the sanitized observed result/error, usage/cost when available, and local raw-evidence hash.

## Physical evidence

- Status: NOT RUN until the exact pre-merge PR candidate is exercised in Task 7 Step 6.

## Phase 1 review

- Status: NOT RUN until Task 6 Step 7.
