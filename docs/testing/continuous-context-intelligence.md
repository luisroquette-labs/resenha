# Continuous contextual intelligence evidence

Status: superseded candidate; SHIP authority change requires a new candidate and all evidence rerun

## Shipping contract

- Audio and recognition remain local. The optional rolling preview is confined
  to the Resenha HUD and never writes partial text to clipboard, history or the
  target application.
- The completed-WAV transcript remains authoritative and uses the existing
  single-insertion path. Late or cancelled revisions cannot edit committed text.
- Jev is a bounded decision evaluator for allowlisted occurrence alternatives.
  It is not an audio transcriber, next-token predictor or free-text generator.
- `PersonalRemoteReleaseDecision.current` is `personalRemoteAvailable`.
  Production personal transport still defaults off and requires distinct
  consent, Keychain credential and eligible local examples. Synthetic
  diagnostic authority cannot enable it.
- The 500/100/50/650/750 ms values are acceptance targets, not measured product
  claims. Deterministic Step 08 results prove orchestration only.

## Deterministic evidence

The frozen `continuous-context-events.json` corpus contains 43 contextual cases
and 10 no-change controls. XCTest verifies revision ordering, strict decision
deadline behavior, bounded work, fail-open behavior, single final insertion,
cancel/revocation handling and corpus metrics. The former closed-authority
candidate is superseded and cannot evidence the SHIP branch. This
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

INVALIDATED. Commits `33de02a` and `b9e5ea7` describe the former closed release
decision and are not provenance for the SHIP source. No physical/acoustic claim is made until a sanitized append identifies
the frozen candidate and satisfies the protocol above. If permissions, hardware
or user presence prevent 100 revisions, 30 finalizations, VoiceOver or target
field observation, that gate is recorded as unmet and personal remote capability
remains unavailable.

### Superseded candidate provenance — 2026-10-22 (not current evidence)

| Field | Observed value |
|---|---|
| `tested_product_sha` | `33de02a46eaf719e3f5b6f33f355ad99f3632764` |
| `tested_product_tree` | `57bd819e286c8497782f87752af67642b3003cfb` |
| Evidence commit | commit containing this append; its SHA is the Git object identifier and is intentionally not self-embedded |
| Manifest SHA-256 | `52cf669f84d8a8d3a66e3ccc98c45b0802a43f94daf7eca6c8dba5b6719454bd` |
| Isolated app | `build/continuous-context-candidate-33de02a46eaf719e3f5b6f33f355ad99f3632764/DerivedData/Build/Products/Debug/Resenha.app` |
| Executable SHA-256 | `6bdb7b0804f02437a7390810303950f684f4d55ec7bd61bc5839c03a9f7dc5cd` |
| Implementation dylib SHA-256 | `6a8478fa8b56131bc03a30c84adbe1dbc0543df2169b7ec5ce3b389a76213453` |
| Fixture SHA-256 | `46c5794007c61b5135374cc275f01d5a012838807c28df6624d77fd556dd9415` |
| Recognizer model | `ggml-small-q5_1.bin`, 190085487 bytes, SHA-256 `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb` |
| Hardware / OS | MacBook Pro `Mac17,2`, Apple M5, 16 GB; macOS 26.1 (`25B78`) |

The sorted source/config/resource manifest is retained beside the ignored
isolated build at `evidence/source-config-resource-manifest.sha256`. The app is
arm64, bundle `br.com.luisroquette.Resenha`, development-signed by team
`S3YCFYY8SC`; `codesign --verify --deep --strict` passed. This is a Debug proof
candidate, not a release, notarized or publication artifact.

### Gates and bounded hardware attempt

- Native gate: PASS, 197/197, result
  `build/Logs/Test/Test-WhisperKey-2026.10.22_10-01-17--0300.xcresult`.
  A prior loaded run exposed a 100 ms test-only scheduling assumption; the test
  now polls with a one-second bound and its focused rerun plus the full gate pass.
- Conditional static-site gate: PASS, 41/41. No site/publication file changed.
- Isolated signed candidate: BUILD PASS; process launch PASS and clean TERM exit
  PASS. `/Applications/Resenha.app` was not copied over or replaced and was
  reopened afterward from its installed path.
- Physical microphone corpus: **NOT RUN — unmet gate**. The owner was away, so
  no spoken input existed to produce three runs, 100 acoustic provisional
  revisions or 30 finalizations. Consequently there are no physical
  completed-WAV/rolling comparisons, stage percentiles, cold/warm, CPU, RAM or
  thermal measurements.
- TextEdit/browser focus, clipboard, keyboard, spoken VoiceOver, increased
  contrast and reduced-motion observation: **NOT RUN — unmet gate**. Unit and
  fixture coverage is not substituted for these observations.
- Synthetic remote run: **NOT RUN**. No call, credential, paid API or provider
  request was used; the prior synthetic key was revoked. This observation
  belongs only to the superseded closed candidate.

Result: the historical candidate was attributable, signed and green, but the
SHIP authority source change invalidates it. A new exact candidate, gates and
physical evidence are required. No claim of iPhone-like measured prediction
speed is approved from this evidence.
