# Continuous contextual intelligence evidence

Status: current SHIP candidate baseline; physical acceptance pending

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

PENDING. Candidate `11cb1ffe900107893b216895b3ab35ed911a90bd` is the
current SHIP baseline. No physical/acoustic claim is made until a sanitized
append satisfies the protocol above. If permissions, hardware or user presence
prevent 100 revisions, 30 finalizations, VoiceOver or target-field observation,
that gate remains unmet rather than being replaced by deterministic evidence.

### Current SHIP candidate provenance — 2026-10-22

| Field | Observed value |
|---|---|
| `tested_product_sha` | `11cb1ffe900107893b216895b3ab35ed911a90bd` |
| `tested_product_tree` | `b01fdc994b8e9c6322f6ffd03269524472f31e19` |
| Evidence commit | commit containing this append; its SHA is the Git object identifier and is intentionally not self-embedded |
| Source/config/resource manifest SHA-256 | `725faed4cf971d0d12a12cf20b02c5d2a38fdc0b7e5ec8d60f3e707e7d3a6a8b` |
| App-content manifest SHA-256 | `b70e3fb3de090622884561bd1b3d1ad5a5bd7f7d08e73e9975268e1de17233f8` |
| Isolated app | `build/continuous-context-candidate-11cb1ffe900107893b216895b3ab35ed911a90bd/DerivedData/Build/Products/Debug/Resenha.app` |
| Executable SHA-256 | `c17d68ec073b248dda8ad2632562a3f688846bc1c6713737424a64197de27db7` |
| Implementation dylib SHA-256 | `7ff25b1567e74537665f4cfb62912a97bed901922d51ba97e06888a225da2e62` |
| Packaged privacy resource SHA-256 | `05ec7b59faf0bd18201e1f11334c1306f962923b56101ee3268a5d2a9754f59b` |
| Fixture SHA-256, source and packaged | `46c5794007c61b5135374cc275f01d5a012838807c28df6624d77fd556dd9415` |
| Recognizer model | `ggml-small-q5_1.bin`, 190085487 bytes, SHA-256 `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb` |
| Hardware / OS | MacBook Pro `Mac17,2`, Apple M5, 16 GB; macOS 26.1 (`25B78`) |

The two sorted manifests are retained beside the ignored isolated build under
`evidence/`. The app is arm64, bundle `br.com.luisroquette.Resenha`,
development-signed by team `S3YCFYY8SC`; `codesign --verify --deep --strict`
passed. This is a Debug proof candidate, not a Release, notarized or publication
artifact. It did not replace `/Applications/Resenha.app`.

### Gates and bounded hardware state

- Native gate on the exact clean SHA: PASS, 201/201, result
  `build/Logs/Test/Test-WhisperKey-2026.10.22_12-02-53--0300.xcresult`.
  An immediately preceding attempt compiled but ran zero tests because
  LaunchServices refused the XCTest host while installed Resenha PID `66936`
  held the same bundle identity. After the owner-authorized graceful TERM, the
  exact command passed; the installed bundle was neither deleted nor replaced.
- Conditional static-site gate on the exact SHA: PASS, 41/41 through
  `mac-gate node Scripts/site.test.mjs`.
- Isolated signed candidate: BUILD PASS through `mac-gate`; strict deep-sign
  verification PASS. Static source/privacy scans found the SHIP authority,
  consent and revocation paths expected by the current task.
- Physical microphone corpus and completed-WAV/rolling comparison: **NOT RUN —
  unmet gate**. There are no current-candidate stage percentiles, cold/warm,
  CPU, RAM or thermal measurements.
- TextEdit/browser focus, clipboard, keyboard, spoken VoiceOver, increased
  contrast and reduced-motion observation: **NOT RUN — unmet gate**.
- Personal provider call: **NOT RUN**. No credential was entered and no paid or
  remote API request was made while preparing this candidate.

Commits `33de02a` and `b9e5ea7` remain superseded historical evidence for the
former closed-authority candidate and do not support this SHIP result. No claim
of iPhone-like measured prediction speed is approved from this baseline.
