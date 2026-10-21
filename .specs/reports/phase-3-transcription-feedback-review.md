# Phase 3 code review — compact timed feedback

```yaml
phase: Phase 3
review_iteration: 1
combined_score: 4.53
spec_compliance_score: 4.42
builtin_score: 4.68
review_scope:
  - 05-compact-timed-feedback
issues:
  - id: P3-1
    step: 05-compact-timed-feedback
    priority: Medium
    source: phase acceptance and CK-9/CK-10/CK-11
    description: The reviewed candidate has not yet replaced the installed app, so the approximately-four-second dismissal, editor persistence, VoiceOver speech, OS Reduce Motion behavior, focus and clipboard continuity are not physically demonstrated on the final installed SHA.
    evidence: docs/testing/UI-REFINEMENT-EVIDENCE.md compact feedback candidate section explicitly records these cases as pending and says the previous installation was reopened.
    impact: Deterministic lifecycle and rendering contracts are covered, but installation and assistive-technology/runtime observations cannot be claimed from this review.
    suggestion: Commit the reviewed sources, build that SHA through the canonical gate, install it recoverably, record installed hashes, and run the bounded physical script against that exact binary.
  - id: P3-2
    step: 05-compact-timed-feedback
    priority: Low
    source: CK-9 accessibility evidence
    description: Source labels, hints and the availability announcement are correct, but a nonactivating panel's actual VoiceOver announcement and navigation remain operating-system behavior not established by XCTest or fixtures.
    evidence: Sources/WhisperKey/FloatingPanel.swift offerFeedback and Sources/WhisperKey/FloatingStatusView.swift feedbackContent; the evidence document preserves the physical boundary.
    impact: No source defect is established; only the spoken/runtime proof remains uncertain.
    suggestion: Observe the two action names and hints with VoiceOver on the installed candidate before completing the task-level DoD.
blast_radius:
  affected_steps:
    - 05-compact-timed-feedback
  unaffected_steps:
    - 01-safe-glossary-save
    - 02-feedback-views
    - 03-native-feedback-lifecycle
    - 04-physical-evidence-and-specs
  requires_phase_rework: false
```

## Evaluation

### Spec compliance

- Feedback now replaces processing inside the same `280 × 64` panel and position. The rendered fixture contains only two compact thumb controls, with no visible heading or separate card.
- A monotonic deadline is scheduled at `now + 4`. Expiration checks the dismissal generation, feedback token, passive editor state and current `.feedback` status before clearing the session and menu.
- Opening correction invalidates dismissal before exposing the editor. Existing draft, validation-error, notice, recording, hidden-HUD and replacement-offer paths reject stale callbacks.
- Like and expiration reuse the existing `hide()` path and perform no preference write. Dislike continues into the existing local editor; no network, analytics, dependency, inference or new persistence surface is introduced.
- Reduce Motion disables only the short opacity transition; the four-second lifecycle remains controller-owned and independent of SwiftUI environment state.

### Built-in quality and Muda review

- The change reuses `PanelDismissal`, `FloatingPanelController`, `FloatingStatusView` and the existing XCTest/fixture harness. It adds no service, timer abstraction, source file, dependency or project configuration.
- The timer carries only the minimum extra identity needed for correctness: one optional feedback token alongside the existing generation and deadline.
- Tests exercise just-before/exact-deadline behavior, defaults immutability, geometry continuity and the relevant stale-timer transitions through the production controller.
- Documentation replaces the superseded indefinite-offer contract and clearly distinguishes deterministic, visual and physical evidence.

## Evidence checked

- Canonical result bundle `build/Logs/Test/Test-WhisperKey-2026.10.20_14-40-25--0300.xcresult`: 82 passed, 0 failed, 0 skipped on macOS 26.1 arm64.
- Current source/test SHA-256 values exactly match the hashes recorded with that result bundle; candidate executable and debug-dylib hashes also match.
- `codesign --verify --deep --strict` succeeds; designated requirement preserves bundle identifier `br.com.luisroquette.Resenha` and the existing Apple Development identity.
- `git diff --check` is clean. The diff is limited to the two production files, one test file and three Phase 3 documentation files; project/dependency configuration is unchanged.
- The inspected light fixture is `560 × 128` pixels for a `280 × 64` logical HUD and shows two centered compact thumb buttons without title, clipping or a second surface. All five feedback accessibility/appearance fixtures share that footprint.

## Blast-radius assessment

The production blast radius is limited to passive HUD rendering and dismissal ownership. Existing glossary validation/persistence, correction-window behavior, coordinator completion, menu routing and hotkey contracts are unchanged and remain covered by the full native suite. The remaining work is final-SHA installation and physical evidence, not code rework indicated by this review.

## Evidence boundary

This report does not treat fixtures, source accessibility metadata or deterministic clock tests as proof of real VoiceOver speech, focus/caret preservation, clipboard behavior, OS Reduce Motion rendering or the installed app's runtime. Those observations remain explicitly pending until the reviewed candidate is committed and installed.
