# Phase 3 architecture decision record

Artifact: `.specs/tasks/draft/add-transcription-feedback.feature.md`, Architecture Overview.
Date: 2026-10-20. Planning only; no product implementation or runtime execution.

## Inputs reviewed

- Research skill `.claude/skills/resenha-transcription-feedback/SKILL.md`.
- `.specs/analysis/analysis-add-transcription-feedback.md`.
- Judge reports 2a, 2b and 2c; full task including acceptance criteria.
- Coordinator, floating panel, app routing, interaction guard, native menu, preferences and glossary source.

## Bounded decisions

1. Successful insertion return plus current attempt is completion boundary; reset then completion callback avoids hiding new feedback.
2. Feedback offered without timeout; no transcript retained. Optional initial menu actions enable keyboard-only entry.
3. Use normal key-capable correction NSWindow; preserve nonactivating HUD and ordinary passive click handling.
4. Reject conflicts with visible old mapping and direction to existing Settings. No overwrite workflow.
5. MainActor candidate validation before one existing preference assignment, including effective parser capacity and prompt.

## Judge follow-up resolution

- 2a conflict: generic Save cannot replace; reject and disclose existing destination. Architecture explicitly supersedes the skill's generic update recommendation.
- 2a/2b keyboard entry: menu status actions accessible through system keyboard navigation and VoiceOver. New NativeMenuController modification required.
- 2b focus/new dictation: first press in focused editor cancels/restores, consumes until release; next press starts only in confirmed external app. If already switched externally, cancel editor without restoring old target and start normally.
- Found configureHotkeyRouting currently passes targetIsSelf false; plan removes bypass in actual callback. Interaction guard stays unchanged.
- 2c ignored feedback: explicit same-press next recording case plus old timer regression.
- Backlinks added to skill, analysis and reports.

## Scope

12 existing product/test/documentation files modified in future implementation; 0 new product files, 0 deletions. Task and this scratchpad are planning-only changes.
PR #9/#13 baseline divergence is a future reconciliation check, not authorization to merge either.

## Limits of this phase

No app launch, audio, unit gate, VoiceOver, network observation, installed-binary attribution, push, merge, paid API or product mutation.
Architecture decisions about focus/restoration require physical verification on the eventual candidate.
