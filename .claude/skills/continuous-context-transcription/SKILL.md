---
name: continuous-context-transcription
description: Design and evaluate continuous local transcription with revision-aware preview and asynchronous typed Jev decisions, separating measured latency, speech recognition, prediction, privacy, and delivery guarantees.
---

# Continuous contextual transcription

Use when evolving completed-recording dictation into a live, context-sensitive experience. Read the existing [contextual correction skill](../context-aware-transcription-corrections/SKILL.md) for bounded candidate selection, privacy eligibility, credentials, decoder validation, and PT-BR evaluation. Preserve those safeguards; streaming does not authorize broader data collection.

Primary documentation checked on 2026-10-21. This is research and implementation guidance, not permission to call paid APIs, download models, change providers, or transmit live user content. No inference calls were made.

## Feasibility and division of responsibilities

| Capability | Evidence | Engineering implication |
|---|---|---|
| Fast typed contextual decisions | Jev 1.14 listing shows P50 0.13 s and $0.042/M input tokens, free output. [J1] | 130 ms is a changing provider statistic, not a device-to-visible-text SLA. No evidence supports a 1–10 ms remote correction guarantee. |
| Open-ended prediction | Jev returns decisions rather than prose; Choice selects supplied alternatives. [J1, J3] | Local recognition supplies text; Jev may choose `keep_original` or a known candidate. It cannot serve as an arbitrary next-token generator. |
| Continuous evaluation | Decisions accepts a state snapshot plus questions and returns JSON; the checked schema has no streaming parameter or audio session contract. [J2] | Continuous operation means repeated bounded requests triggered by meaningful text revisions, not a persistent audio stream into Jev. |
| iPhone inspiration | Apple documents an on-device transformer for autocorrect and inline predictions accepted by the user. [A1, A2] | Adopt responsive provisional text and reversible corrections. These sources do not expose Apple's keyboard model as a general-purpose macOS API. |
| Local streaming recognition | Whisper.cpp's example repeatedly transcribes rolling audio; Apple Speech exposes intermediate/final results. [W1, A3, A5] | Recognition must begin during capture. A hook that runs only after Stop remains post-transcription correction. |

Jev's direct TypeSafe documentation says audio/video must first become text, English is its strongest language, and customer adaptation occurs through request context rather than per-user fine-tuning. Its default context limits and alias behavior differ from OpenRouter's listing. Use a pinned OpenRouter model ID, short text state, and the existing transport contract; do not copy direct-TypeSafe headers or aliases into OpenRouter. PT-BR accuracy remains unverified. [J4]

## Smallest complete live loop

1. Keep capture and recognition local. Feed bounded PCM windows to the installed recognizer through its supported API; serialize access to a shared model/context. Emit immutable revisions identified by attempt, revision, audio range, and source text. Keep a stable prefix separate from the provisional tail.
2. Render local partial text immediately in the app-owned preview. Coalesce repeated identical partials and never await a remote response to display recognition. A revision replaces its previous hypothesis for the same range; it does not append a duplicate. Show provisional state without relying solely on color.
3. Only for eligible, changed text with an actual ambiguous candidate, schedule a bounded Jev decision. Keep at most one request in flight and one replaceable latest pending snapshot. Batch independent occurrences in that snapshot. Do not accumulate a FIFO of obsolete transcripts, send on a millisecond timer, or retry every failed revision.
4. Apply an allowlisted answer only when attempt, revision, source span, context/example version, and delivery state still match. A new utterance, cancellation, deletion of learning, or disabling the feature invalidates pending work. Transport cancellation alone cannot prevent stale callbacks. Retain recognition text on uncertainty or failure.
5. At Stop, reconcile final local recognition with the preview and make exactly one final delivery to the original target. Reuse a valid decision or retain local text when its deadline expires. Never paste a second correction after delivery, rewrite a changed target, or let preview-only changes become confirmed learning.

These are application design recommendations, not vendor guarantees. The first implementation should use an app-owned preview during capture and preserve the existing single insertion boundary. Continuously rewriting arbitrary third-party editor content adds selection, undo, accessibility, and focus semantics that need a separate explicit design. Next-word completion must be visually distinguished from recognized speech and require acceptance; it is not needed to accomplish conservative live correction.

## Engine and framework selection

| Option | Relevant contract | Recommendation |
|---|---|---|
| Existing Whisper.cpp integration | Upstream stream example uses repeated windows, including a 500 ms sample cadence; it explicitly describes itself as a naive example. [W1] Apple Silicon acceleration exists in the library. [W2] | First benchmark the installed version and model with bounded rolling windows. Preserve the supported completed-recording path if the hardware cannot keep up. Do not add SDL2 or spawn its CLI solely to obtain preview. |
| Apple SpeechTranscriber / SpeechAnalyzer | Native asynchronous volatile/final results and audio ranges; SpeechTranscriber starts at macOS 26 and requires device/locale availability checks. [A3, A4] | A viable optional backend only after a compatibility decision. Do not raise the app's deployment floor or silently replace the recognizer as part of the live-loop change. |
| Older SFSpeechRecognizer | `shouldReportPartialResults` exposes intermediates. On-device enforcement must be paired with `supportsOnDeviceRecognition`; the setting alone is insufficient. [A5, A6] | Evaluate only with explicit local-only eligibility and locale checks. Never silently fall back to server recognition. |
| Core ML / ANE | Core ML runs models on local compute; Apple's optimized DistilBERT study reports millisecond forward passes on specific devices. [A7, A8] | Evidence that small local models can be fast, not a contextual-dictation benchmark. Add a local ranker only if measured deficiencies justify model packaging and maintenance. |
| Foundation Models | Apple provides on-device generation on compatible systems; the macOS 26 introduction depends on Apple Intelligence availability. [A9] Current framework also supports server models. [A10] | An optional later experiment, not the keyboard predictor or a guaranteed millisecond solution. Select on-device explicitly and check availability; never automatic cloud fallback. |

The Resenha checkout's `project.yml` currently targets macOS 14 and links `Frameworks/whisper.xcframework`; verify again at implementation. Local existing code is authoritative for the shipped version and all callers. Upstream examples do not prove the packaged library exposes the same APIs or can run real time on the supported hardware.

## Latency and operating cost

Instrument monotonic timestamps at audio arrival, partial availability, preview render, decision dispatch/completion, final recognition, and final delivery. Report separately: audio-to-first-partial, partial-to-preview, decision round trip, Stop-to-delivery, correction age, dropped/coalesced revisions, and frame stalls. Use p50/p95/p99, cold/warm model states, and sustained-session CPU/RAM/thermal measurements. A fast UI callback is not fast speech understanding.

Proposed benchmark hypotheses, not release claims: partial-to-preview p95 ≤50 ms; warm first useful partial ≤1 second; local recognition faster than real time with no growing queue. Start rolling-window evaluation near 500 ms cadence and vary window/overlap against PT-BR accuracy. Choose the final latency budget from measured oldest-supported hardware. Network delay must not block partial rendering; remote finalization must have a bounded overall deadline.

Illustrative arithmetic at a fixed 1,000 input tokens/request and the checked model price: `cost/hour = calls/second × 3,600 × 1,000 / 1,000,000 × $0.042`. One call/second is $0.1512/hour; two are $0.3024/hour; 1,000 are $151.20/hour. These are hypothetical input charges, not a usage estimate, rate-limit entitlement, authorization, or configured spending cap. Repeated context and questions cost tokens. Reconcile actual `usage.cost` after separately authorized testing. [J1, J2]

## Privacy and failure containment

Continuous listening here means only an explicitly active dictation session. No background ambient surveillance, raw-audio upload to Jev, clipboard scraping, active-document extraction, or full-history transmission. The local eligibility gate must assess the entire snapshot and examples before each dispatch; a new partial can introduce identifying content. Keep the previous skill's conservative personal-data policy. When a local classifier cannot establish eligibility, live cloud evaluation stays unavailable; use reviewed synthetic cases for testing. ZDR does not make disallowed content eligible.

OpenRouter documents optional content logging and retained request metadata. Account settings and upstream endpoint policy need separate verification; no-training is not zero retention. `provider.zdr: true` can constrain eligible routes, but documentation alone does not establish that the user's Jev endpoint qualifies. Never weaken privacy routing to make a request succeed. [J5, J6] Ephemeral networking and redacted application diagnostics remain necessary but are not server-retention guarantees.

Cancel remote work on feature disablement and stop admission of requests on authentication/billing errors. Preserve text on timeout, 429, 5xx, invalid probabilities, unknown options, stale replies, and offline state. A retry can both exceed the latency budget and incur cost; no automatic alternate model/provider. Store only sanitized operational metrics and explicitly confirmed learning, with deletion invalidating matching cached decisions. Repetition and model output never constitute user confirmation.

## Verification before enabling

1. Replay deterministic partial/final event sequences offline, including repeated/retracted hypotheses, contradictory later context, split words, overlaps, long pauses, cancellation, focus changes, Stop during inference, and late callbacks. Verify bounded memory/queue, no duplicate text, no obsolete edit, and exactly-once final delivery.
2. Use synthetic PT-BR audio and timestamped expected transcripts, including correct common words, supported corrections, ambiguous context, names/identifiers, negation, numbers, code-switching, accents/emoji, and repeated occurrences. Preserve a held-out split separate from threshold tuning. Compare completed-recording baseline, streaming local-only, and mocked contextual decisions.
3. Stub transport/clock and test privacy-ineligible or unchanged revisions cause zero calls, one-in-flight/one-latest coalescing, request and response size limits, deadlines, all error paths, and decisions invalidated by source/example changes. Mock correctness proves orchestration only.
4. Measure the real audio-to-preview-to-target path on supported Mac hardware; report word error rate, unintended edits, correction precision/recall, abstention, stability/churn, latency distributions, and resource use. The always-keep baseline cannot establish correction utility. Run applicable local gates through `mac-gate`.
5. Only with explicit authorization, run frozen eligible fixtures through the pinned remote model and record actual version, tokens, costs, and latency. Retain release gating if PT-BR utility, endpoint privacy, hardware performance, or cost authorization is unresolved. Planning, unit tests, and vendor median latency do not prove a production outcome.

## Primary references

Eighteen sources; Apple symbol pages A4–A7 were read through their public documentation JSON because rendered HTML required JavaScript. All cited URLs are primary owners. Recheck changing price, schemas, platform eligibility, and provider policies before implementation.

| ID | Source | Purpose |
|---|---|---|
| J1 | [OpenRouter Jev 1.14](https://openrouter.ai/typesafe/jev-1.14) | Typed decisions, current pricing and latency snapshot. |
| J2 | [OpenRouter Decisions API](https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-request) | Snapshot request/response contract; no documented streaming field. |
| J3 | [TypeSafe Choice](https://docs.typesafe.ai/primitives/choice) | Bounded choices and distribution semantics. |
| J4 | [TypeSafe Models](https://docs.typesafe.ai/models) | Input, language, personalization and version caveats. |
| J5 | [OpenRouter Data Collection](https://openrouter.ai/docs/guides/privacy/data-collection) | Content settings versus request metadata. |
| J6 | [OpenRouter ZDR](https://openrouter.ai/docs/guides/features/zdr) | Routing constraints versus endpoint eligibility. |
| A1 | [Apple iOS 17 announcement](https://www.apple.com/sg/newsroom/2023/06/ios-17-makes-iphone-more-personal-and-intuitive/) | On-device transformer autocorrect and separate dictation model. |
| A2 | [Apple predictive text guide](https://support.apple.com/en-mt/guide/iphone/iphd4ea90231/27/ios/27) | Inline prediction acceptance/rejection interaction. |
| A3 | [Apple WWDC25 SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/) | Async audio/result streams, volatile-to-final replacement. |
| A4 | [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) | macOS 26 introduction and runtime support checks. |
| A5 | [Partial Speech results](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/shouldreportpartialresults) | Intermediate recognition availability. |
| A6 | [On-device Speech enforcement](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition) | Must also verify recognizer capability. |
| A7 | [Core ML](https://developer.apple.com/documentation/coreml) | Local model execution and platform integration. |
| A8 | [Apple ANE transformer research](https://machinelearning.apple.com/research/neural-engine-transformers) | Device-specific latency evidence, not dictation parity. |
| A9 | [Apple Foundation Models introduction](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/) | macOS 26 on-device framework requirements. |
| A10 | [Current Foundation Models overview](https://developer.apple.com/foundation-models-framework/) | Distinguish local and server model options. |
| W1 | [Whisper.cpp stream example](https://github.com/ggml-org/whisper.cpp/blob/master/examples/stream/README.md) | Rolling-window baseline and limits. |
| W2 | [Whisper.cpp official repository](https://github.com/ggml-org/whisper.cpp) | Local native integration and Apple acceleration. |
