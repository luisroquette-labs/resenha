# Phase 2c scratchpad

Task: `.specs/tasks/draft/add-transcription-feedback.feature.md`.

1. Intent preserved: feedback after completion, explicit heard/canonical correction, local glossary learning only after confirmation. Initial User Prompt and Requirements unchanged.
2. Sources read: README native gate, SPEC-008 physical-versus-fixture proof, project.yml XCTest target, site-tests.yml conditional site gate, existing glossary parser and preference limits. Native macOS app: no npm or next build gate invented.
3. Scope boundaries: no model training, automatic learning, retroactive cross-app editing, feedback history, telemetry, account, network or dependencies. Existing history behavior remains in scope only as a regression boundary.
4. Failure analysis: malformed delimiter/newline injection, silently truncated rules, 200-term parser cap, 160-character line cap, 20,000-character preference cap, duplicate/conflicting mappings, stale callbacks and lost focus. Reject non-representable changes before any write; preserve existing glossary.
5. Coverage: 10 checklist rows (9 essential, 1 important); 4 regular checks; 5 rubric dimensions with weights totaling 1.0 and paired concrete anchors; 5 test types; 10 case groups containing 19 cases; 5 completion items. No code implemented, tests not executed in this planning phase.
