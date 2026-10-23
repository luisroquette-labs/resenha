# Resenha architecture

Status: direct-distribution architecture implemented; physical cross-app acceptance pending

## Runtime flow

```text
configured global shortcut → listen-only CGEvent tap
        │ press                         │ release
        ▼                               ▼
capture target app → AVAudioRecorder → embedded whisper.cpp
                         │                  │
                         │ rolling local    │ completed WAV
                         ▼                  ▼
              provisional HUD       authoritative final candidate
                         │                  │
                         └──── bounded reconciliation
                                            │
                                            ▼
                                  general pasteboard
                                            │
                           reactivate target + Command-V
```

## Distribution shape

One XcodeGen application target (`WhisperKey`, product name `Resenha`) and one unit-test target produce bundle `br.com.luisroquette.Resenha`. The arm64 macOS 14 app uses Hardened Runtime and direct distribution without App Sandbox. It embeds `whisper.xcframework`; no Homebrew, Python, shell, cloud transcription or API key is required.

## Components

| Component | Responsibility | Boundary |
|---|---|---|
| `HotkeyMonitor` | observe the exact user-selected press/release | listen-only; never suppresses events |
| `ShortcutCaptureController` | record and persist a shortcut inside Settings | local events only while recording |
| `AudioRecorder` | capture one temporary 16 kHz mono WAV | deletes stale/current audio |
| `WhisperTranscriber` | serialized embedded inference | local model and Metal/Accelerate |
| `TextInjector` | stage text, restore target focus and post `Command-V` | target, permission and clipboard guards |
| `DictationCoordinator` | own state, cancellation and cleanup | one active attempt; fail closed |
| `TranscriptHistory` | retain up to ten successful texts when enabled | local only; no audio or sync |
| `ContextualCorrectionStore` | retain up to 100 confirmed sentence/occurrence examples | local file, 600-character sentence cap, separate from glossary |
| `ContextualCorrectionResolver` | match occurrences and preserve the local candidate on failure | personal scope requires distinct consent, credential and eligible local examples |
| `SyntheticDiagnosticController` | run the allowlisted fixture once | separate network authority; 900 ms, zero retry, one-shot guard |
| `ContinuousContextSession` | bind rolling revisions to one attempt and reconcile one final candidate | one active evaluation, latest pending revision, no external partial writes |
| `RevisionBoundJevLoop` | evaluate allowlisted occurrence alternatives asynchronously | 200 ms hard deadline; local fallback on failure |
| `ContextualAttemptStore` | retain provider-call proof without dictated content | 20 records, 256 KiB file cap, user deletion |

## Permissions

- Microphone captures speech only while the shortcut is held.
- Input Monitoring powers the global listen-only event tap.
- Accessibility reactivates the captured application and posts one paste command.

The app requests permissions only after explicit user action and exposes separate recovery destinations. It does not inspect another app's accessibility tree.

## Data lifecycle

- Audio: unique temporary file, deleted after success, failure or cancellation.
- Transcript: kept on the general pasteboard and optionally in a bounded local history.
- Model: persistent local file accepted only after exact size and SHA-256 verification.
- Preferences: local `UserDefaults`; no account or sync.
- Diagnostics: no raw audio or transcript content in logs.
- Contextual examples: local language/heard/canonical/sentence/ordinal records;
  individual/all deletion mutates the shared policy generation.
- Synthetic diagnostic: ephemeral HTTPS session to OpenRouter/TypeSafe using
  `typesafe/jev-1.14`; no personal dictation, examples, history or clipboard.
- Personal contextual evaluation: optional HTTPS text-only requests to the same
  provider using a distinct Keychain account; current bounded sentence and up
  to three exact options only, with at most six dispatches per dictation; no
  audio, logits, probabilities, full vocabulary, history, clipboard or target-app content.
- Personal evaluation proof: local bounded metadata only (time, status, model,
  provider request ID, decision, confidence, latency, tokens, cost and sanitized
  failure); no dictated text, correction pair or credential.

## Continuous contextual boundary

Rolling whisper.cpp output is a local, provisional presentation. It is never a
second insertion path: only the completed-WAV final candidate reaches the
existing single-commit output sink. Jev is a bounded decision evaluator, not an
ASR engine or next-token generator. It may only keep or select allowlisted
alternatives tied to an exact recognized occurrence. Invalid, late, cancelled
or unauthorized work preserves the local candidate. Accepted options feed a
five-term, per-attempt prompt used by later rolling inference and the completed
WAV pass, then are erased.

`PersonalRemoteReleaseDecision.current` is available, but personal requests
require a separate disabled-by-default opt-in, credential, healthy local store
and current policy/store generations. Either a learned example or proactive
Whisper evidence may produce a candidate, but a concrete candidate is mandatory
for dispatch. The synthetic diagnostic cannot upgrade that scope. The 1,200 ms
rolling deadline remains an acceptance target until acoustic hardware evidence
is recorded; deterministic clocks prove orchestration, not physical latency.

## Validation boundary

Unit tests prove shortcut serialization/matching, permission combinations, clipboard staging and target identity. A signed app with real TCC grants must still prove physical TextEdit insertion, then browser and terminal compatibility. The legacy sandboxed Service design remains documented in SPEC-017 but is not registered in the direct bundle.
