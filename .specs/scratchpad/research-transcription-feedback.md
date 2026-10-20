# Phase 2a research scratchpad

Task: `.specs/tasks/draft/add-transcription-feedback.feature.md` (the orchestrator may promote it).
Date: 2026-10-20.
Output: `.claude/skills/resenha-transcription-feedback/SKILL.md`.

## Resources and findings

7 primary Apple references and 7 local source/test resources, plus 1 historical project skill reviewed. Apple web HTML was a JS shell; Markdown links failed in the web reader with unsupported `text/markdown`. Direct curl reads of canonical Apple Markdown succeeded for `FocusState`, `ignoresMouseEvents`, and HIG Feedback. Other API details came from Apple search-indexed documentation. No third-party source used.

The route already exists: preferences string → fresh coordinator glossary closure → local Whisper prompt and deterministic postprocessor. No model-training mechanism is needed. Current limits: line 160 characters, 200 parsed terms, 20,000 stored characters, 8,000 prompt characters. A blind append risks a false success at parser/storage capacity. Current parser splits at the first equals sign and postprocessor applies case-insensitive escaped replacements sequentially.

Three concrete HUD blockers: `ignoresMouseEvents = true`, root `.accessibilityElement(children: .ignore)`, and coordinator `reset()` hiding the panel at successful completion. A fourth concern is keyboard focus: SwiftUI FocusState cannot fix an ineligible AppKit panel. Architecture must explicitly settle the form window surface and preserve target focus until insertion completes.

Historical UI-only skill forbids interactivity and lists old scope exclusions. Current explicit feedback requirements supersede that prohibition for post-completion feedback only; recording/transcription/insertion remain passive. Keep rating and correction storage independent from history.

## Handoff to architecture

Integrate reference `.claude/skills/resenha-transcription-feedback/SKILL.md` in the task's architecture. No task-file edit here to avoid concurrent business-analysis conflict. Choose completion timing; choose keyboard-capable correction surface; decide feedback lifetime/new-session invalidation and same-source conflict update policy. Explicit Save must validate that the complete rule survives actual parser bounds and preserve unrelated lines. Do not promise synchronous disk durability or machine-learning improvements.

## Verification status

Documentation-only artifacts written. Product code, native app, VoiceOver, microphone accuracy, and restart persistence were not changed or tested. No AI/API calls, product network operations, or dependencies introduced. Source and Apple references support planning recommendations, not runtime proof.
