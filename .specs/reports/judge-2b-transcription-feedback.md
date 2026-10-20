# Judge 2b — Transcription feedback impact analysis

Artifact: `.specs/analysis/analysis-add-transcription-feedback.md`
Date: 2026-10-20. Independent, threshold-blind static evaluation; no product changes or runtime tests.

Cross-checked the task, Swift sources/callers, existing test names, documentation and local Git refs. HEAD and `origin/main` both resolve to `9e674c3ddeee8f7e05b8289f2e5c20ceba55fbc5`. Live GitHub reads confirm PR #9 OPEN at `0a6c7bcbee5a3da86b2378e71cc3466d3377947d` and PR #13 OPEN at `758f9b13f272ed64d80981794c80dd15afe1440d`; #13 has exactly the two paths identified in the analysis. Installed-binary provenance remains supplied context, not independently proven.

| Criterion | Weight | Score / 5 | Evidence |
|---|---:|---:|---|
| File Identification Accuracy | 0.35 | 4.7 | Seven concrete product/test files and four documentation files match the baseline; read-only integrations and optional Xcode registration are distinguished. PR #9/#13 are correctly kept outside integration scope. |
| Interface Documentation | 0.25 | 4.5 | Correct callback ordering, reset identity invalidation, MainActor ownership, panel flags, accessibility grouping, defaults key and parser limits. Success means insertion call completion in this baseline, not physical delivery proof. |
| Integration Point Mapping | 0.25 | 4.2 | Producer → coordinator → panel → explicit save → next-run glossary flow is sound; history independence and generation cleanup are concrete. Focused correction versus the app's self-target hotkey guard needs an explicit route. |
| Risk Assessment | 0.15 | 4.5 | Strong focus, accessibility, stale callback, storage-capacity, privacy and parallel-branch risks with tests and honest native-proof limitations. Keyboard entry into feedback and focus restoration need stronger acceptance mapping. |

Weighted score: `(4.7 × 0.35) + (4.5 × 0.25) + (4.2 × 0.25) + (4.5 × 0.15) = 4.495 / 5`.

## Issues

Critical: none. High: none.

| Priority | Location / evidence | Finding and bounded correction |
|---|---|---|
| Medium | Analysis lines 19–20, 42, 56; `Sources/WhisperKey/DictationInteraction.swift:15–22`; `Sources/WhisperKey/WhisperKeyApp.swift` hotkey routing | A focused native correction presentation makes Resenha the target; `canStart` rejects `targetIsSelf`. Merely clearing a draft when coordinator recording starts does not ensure the hotkey can start that recording. Map the concrete route for cancel/close/target restoration and the next accepted press, retaining the self-insertion guard. Add a regression for the chosen route and a physical focused-editor → external-target → new-dictation check. No mandatory modification to `DictationInteraction.swift` is implied. |
| Low | Analysis lines 20–21, 50, 56, 62; task scenarios 5 and CK-9; `Sources/WhisperKey/FloatingPanel.swift:109–128`; `Sources/WhisperKey/FloatingStatusView.swift:108` | The analysis addresses clickable actions, correction field focus and VoiceOver discovery, but does not explicitly map how a keyboard-only user reaches like/dislike in the nonactivating HUD or where focus returns after save/cancel. Name those entry/exit contracts during architecture and test the entire route, including validation error announcement, rather than only field operation after a click. |

The analysis is accurate and sufficiently concrete to support architecture, with the two focus-route clarifications above carried forward. Existing glossary regressions and native fixtures are real; extending them must retain current size assertions and distinguish rendered fixtures from microphone/insertion/VoiceOver evidence. Conflict handling must reject or explicitly resolve a changed destination, as required by the task; “upsert” must not become silent overwrite.

Not checked: native build, installed app, microphone/insertion, physical keyboard or VoiceOver. Remaining risk: static analysis cannot prove focus or successful text delivery.
