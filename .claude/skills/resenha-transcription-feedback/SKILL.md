---
name: resenha-transcription-feedback
description: Plan or implement local post-transcription rating and explicit glossary corrections in a SwiftUI/AppKit macOS dictation utility, preserving focus, lifecycle, accessibility and offline processing.
---

# Local transcription feedback and correction learning

Research verified on 2026-10-20. Use for optional ratings, correction forms, and deterministic local glossary updates. This document is guidance, not authorization for additional features.

## Scope and evidence

The requested interaction is two quick HUD actions after completion: approve or correct. Approval dismisses feedback without storing extra content. Correction opens labeled fields “Saiu como” and “Correto é”; explicit Save persists a glossary rule used on the next transcription. “Learning” means updating a local replacement dictionary and prompt vocabulary, not training model weights, general semantic understanding, or correcting every possible future pronunciation.

Audio, transcripts, correction input, and ratings stay on the Mac. Reuse the existing glossary and preferences; add no analytics, login, network service, dependency, or paid API. Keep the existing history preference independent: rating must neither force transcript history on nor introduce a second transcript archive.

The historical `.claude/skills/whisperkey-macos-ui/SKILL.md` forbids an interactive HUD for an earlier visual-only task. The present feature explicitly supersedes that restriction for post-transcription feedback. Preserve its focus/pass-through behavior during recording, transcription, and insertion. Its historical exclusions of settings/history/waveforms are not a description of today's source.

## Existing local contracts

| Source | Reusable contract and implication |
|---|---|
| `Sources/WhisperKey/WhisperTranscriber.swift` | `TranscriptionGlossary` parses `heard = canonical`, bounds lines at 160 characters, accepts at most 200 terms, and caps the prompt at 8,000 characters. `TranscriptPostprocessor.process(_:glossary:)` uses escaped, case-insensitive, whole-term replacements, longest source first. Reuse this route. |
| `Sources/WhisperKey/ProductPreferences.swift` | `ProductPreferences.transcriptionGlossary` is observable and stored in injected `UserDefaults`, capped at 20,000 characters. Settings already explain `forma ouvida = forma final`. Preserve this editor and storage format. |
| `Sources/WhisperKey/DictationCoordinator.swift` | Each attempt has identity; asynchronous completion is guarded. Successful insertion currently transitions to idle then calls `reset()`, which hides the HUD. Feedback must survive deliberate session cleanup without allowing stale callbacks to affect the next attempt. |
| `Sources/WhisperKey/FloatingPanel.swift` | `NSPanel` is borderless/nonactivating and ignores mouse events. `PanelDismissal` invalidates old timer generations. New buttons cannot work until the feedback presentation accepts mouse events; every exit path must restore passive behavior. |
| `Sources/WhisperKey/FloatingStatusView.swift` | Root accessibility currently ignores children. A feedback branch must expose buttons and text fields rather than inheriting that flattening. Existing appearance/contrast/transparency treatments remain useful. |
| `Sources/WhisperKey/WhisperKeyApp.swift` | The coordinator receives a glossary closure from preferences. Preserve fresh lookup for the next attempt and the existing `showsHUD` preference. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | XCTest covers preference persistence, glossary bounds/replacement, panel timer generations, and coordinator error/reset behavior. Extend these patterns rather than adding a second framework. |

## Implementation approach

1. Attach feedback to a completed attempt, with transient identity and only the context necessary for the form. Keep inference and insertion success/failure distinct. Do not show an insertion-success claim on clipboard fallback or failure. A new recording, cancellation, disabling HUD, or app termination must retire old feedback and cancel its timers.
2. Render thumbs as native `Button`s with Portuguese accessible names such as “Transcrição correta” and “Corrigir transcrição”. Do not automatically activate the app when merely presenting feedback. Keep feedback optional and nonmodal; the correction editor may take keyboard focus only after an explicit user action. [A1, A2, A6]
3. Use two native labeled text fields, Save, and Cancel. Tab must reach all controls; Escape cancels without writing. `@FocusState` supports a predictable initial field, but does not itself make an AppKit window eligible for keyboard input. The architect must choose and test either a key-capable correction panel or an existing normal-window presentation. [A2, A5]
4. Validate the complete prospective glossary before assigning preferences once. Reject invalid input inline; preserve the draft for correction. Only confirm a save when reparsing the actual stored value yields the complete intended replacement. Subsequent dictation must read that updated preference. [A7; project validation policy]
5. Clear ephemeral feedback on approval/cancel/dismiss. Do not persist ratings or transcript copies. Existing `UserDefaults` storage is local and unencrypted; it is not a secure store or proof of synchronous durable disk flush. Save only the user-confirmed phrase mapping, never a whole transcript or audio. [A7]

## Validation and lifecycle pitfalls

| Pitfall | Required handling |
|---|---|
| Blank/whitespace-only input, identical source and target | Trim surrounding whitespace and show a short actionable validation message; do not append a useless rule. |
| Newlines or `=` in “Saiu como” | Reject inputs that change the existing line/delimiter grammar. Newlines in either field are not a short single-rule correction. Literal `=` in canonical text can be represented by the current first-split parser; explicitly test or reject it consistently without broad parser changes. |
| A 161-character rule or full glossary appears saved | Enforce the existing full serialized-line limit and total stored-text limit before mutation. Verify the rule falls within the parser's effective 200-term window. The current parser truncates/ignores excess; this must not silently discard learned text or existing entries. |
| Duplicate or conflicting source phrase | Exact existing mapping should be idempotent. Define deterministic behavior for same source/different canonical text; recommended: explicit Save updates that source mapping while preserving unrelated lines. Match conflicts consistently with the case-insensitive replacement engine. Do not leave duplicate conflicting mappings with unstable order. |
| Regex characters, Unicode, prefix/substrings | Keep the existing escaping and whole-term boundaries. Test accented Portuguese, punctuation, `$`, backslashes, and `COESA Energia` without replacing text inside a larger word. |
| Existing mappings cascade into other rules | Current postprocessing is sequential. Preserve its established behavior; test representative overlapping rules and do not claim simultaneous/global semantic correction. Broader engine redesign is outside this task. |
| HUD swallows clicks or VoiceOver cannot see buttons | Switch mouse handling only for interactive presentation; use accessible child containment or an equivalent explicit hierarchy rather than `.ignore` on the interactive root. Restore pass-through after dismiss/new recording. [A1, A3, A4] |
| Two-second timer closes a partially filled form | Suspend/invalidate transient dismissal while editing. Never discard an active draft due to a stale status timer. Timing for optional initial feedback is a product decision, not an Apple-specified duration. |
| Focus is stolen before text insertion | Present feedback after the established completion boundary. Explicitly opening the form may focus it, but feedback display alone must not change the target app or cause text to be pasted into the correction editor. [A2, A5] |

## Verification

1. Add focused XCTest cases for blank/invalid/oversized input, exact duplicate, conflicting mapping policy, preservation of unrelated entries, total capacity, effective parser capacity, and preference reconstruction using a unique test suite. Tests must not write real user preferences.
2. Prove the pipeline `save mapping → reconstruct preferences → build TranscriptionGlossary → TranscriptPostprocessor.process` turns “Coisa Energia” into “COESA Energia”. Verify approval, cancel, and failed validation leave glossary/history unchanged. This proves deterministic correction, not recognition accuracy on microphone audio.
3. Exercise attempt replacement and stale timers: completed feedback → new recording; open form → old dismissal; repeated Save; cancellation; insertion failure; HUD disabled. Check that one completion cannot hide or mutate another session.
4. On a real Mac, test mouse clicks, keyboard Tab/Return/Escape, VoiceOver discovery, and external-app focus using TextEdit and a browser. Check ordinary recording/insertion pass-through, form focus only after explicit action, and a second dictation using the learned mapping. Capture build/version and limitations. Unit tests or screenshots alone cannot prove focus or assistive-technology behavior.
5. Run repository-native gates only through `~/.local/bin/mac-gate`, using the real versioned preflight for the current task. This planning/research document requires no product build/test run. No external call carrying audio, transcript, or feedback is needed for validation.

## Primary references

Seven Apple resources were consulted. Apple pages may return a JavaScript shell to the web reader; canonical `.md` content was directly retrieved for A1, A5, and A6, and official search-indexed text supplied A2, A3, A4, and A7. No third-party forum guidance is normative here. Recommendations on validation, timeouts, duplicate mappings, and completion state are project design judgments derived from source and requirements.

| ID | Primary source | Application |
|---|---|---|
| A1 | [AppKit: ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents) | A transparent-to-mouse window cannot receive the requested button clicks. |
| A2 | [AppKit: becomesKeyOnlyIfNeeded](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded) | Key-window behavior for nonactivating panels depends on views needing keyboard input; setting a property alone does not prove focus works. |
| A3 | [SwiftUI: AccessibilityChildBehavior.contain](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain) | Groups children while retaining their discoverability. |
| A4 | [SwiftUI: AccessibilityChildBehavior.ignore](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/ignore) | Existing flattened status behavior must not hide interactive descendants. |
| A5 | [SwiftUI: FocusState](https://developer.apple.com/documentation/swiftui/focusstate) | Focus binding for labeled form fields; available before the project's macOS 14 baseline. |
| A6 | [Apple HIG: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) | Passive status near context, actionable failures, accessible feedback; does not prescribe thumbs or a timeout. |
| A7 | [Foundation: UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) | Existing preference persistence, immediate memory updates and asynchronous disk write; unencrypted storage. |

## Planning integration

The architecture must link this document as `.claude/skills/resenha-transcription-feedback/SKILL.md` under its references, then name the chosen completion boundary, keyboard-capable editor surface, duplicate conflict policy, limits/error behavior, and lifecycle ownership. Do not infer that this research implemented or validated any product behavior.
