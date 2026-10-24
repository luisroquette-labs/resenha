# Phase 2 code review — transcription feedback

```yaml
phase: Phase 2
review_iteration: 1
combined_score: 4.24
spec_compliance_score: 4.08
builtin_score: 4.47
review_scope:
  - 03-native-feedback-lifecycle
  - 04-physical-evidence-and-specs
issues:
  - id: P2-1
    step: 04-physical-evidence-and-specs
    priority: Medium
    source: phase acceptance and CK-5/CK-8/CK-9/CK-10
    description: The physical record is intentionally partial: it does not isolate a confirmed Save through relaunch and next dictation, actual VoiceOver speech, continuous keyboard/focus/clipboard behavior, or bounded network observation across all feedback actions.
    evidence: docs/testing/UI-REFINEMENT-EVIDENCE.md:31-35,48
    impact: The implementation and deterministic tests support these contracts, but the phase cannot use this run to assert those physical observations or mark every task-level demonstration complete.
    suggestion: Keep the explicit pending status; before a full task-level completion claim, run the bounded F2-F8 cases on the committed candidate or record the concrete external blocker. The user's manual thumbs/correct-incorrect confirmation supplements the flow but does not establish the omitted measurements.
  - id: P2-2
    step: 03-native-feedback-lifecycle
    priority: Low
    source: CK-9 accessibility evidence
    description: Success requests an accessibility announcement and immediately closes the correction window that is used as the announcement element.
    evidence: Sources/WhisperKey/FloatingPanel.swift:214-224
    impact: No source-level defect is established, but actual delivery of the success announcement remains uncertain until VoiceOver is exercised; XCTest and AX labels cannot resolve the timing question.
    suggestion: Verify the spoken success message physically. Change announcement lifetime only if that observation reproduces a missed announcement.
blast_radius:
  affected_steps:
    - 04-physical-evidence-and-specs
  unaffected_steps:
    - 03-native-feedback-lifecycle
  requires_phase_rework: false
```

## Evaluation

### Spec compliance

- The completion callback is emitted only after successful insertion, with post-suspension attempt/cancellation guards and cleanup before the offer. Empty/error/cancelled paths do not share that callback.
- The panel owns one tokenized session, one recovery draft and the editor window. Approval, normal cancel and stale callbacks do not write; exceptional rollback recovery blocks Save until an explicit verified reload issues a fresh token.
- App/menu routing uses the same tokenized handlers. New accepted dictation, HUD disablement, permission loss and termination retire feedback; the editor/self hotkey latch requires release before a new external press.
- The feedback diff adds no destination, analytics, login, dependency, API or persistence key. The only new durable mutation remains the confirmed glossary pair supplied by Phase 1.
- Documentation accurately separates deterministic, fixture, process/UI, user-reported and unexecuted physical evidence. It does not convert the user's manual confirmation into stronger persistence, focus, VoiceOver or network claims.

### Built-in quality

- The smallest existing seams are reused: `DictationCoordinator`, `FloatingPanelController`, `NativeMenuController`, `ProductPreferences` and the established XCTest file. No generic service or dependency was introduced.
- Token replacement for menu items prevents a queued old menu action from inheriting current state. Timer generations and phase/attempt guards prevent stale completion or dismissal from reaching a later session.
- Recovery semantics preserve data integrity under failed write/read-back and failed rollback. Draft retention is memory-only and is explicitly erased on a new dictation, HUD-off and termination.
- Test seams exercise the real controllers and windows rather than copying the state machine into a second implementation. The remaining uncertainty is native assistive-technology delivery, correctly left to physical evidence.

## Evidence checked

- Canonical result bundle: `build/Logs/Test/Test-WhisperKey-2026.10.20_11-40-18--0300.xcresult` — 80 tests, 80 successful, 0 skipped, 0 unsuccessful on macOS 26.1 arm64.
- Candidate identity: executable SHA-256 `b092604d77495b79ed59ed6573ee30dfc58bec401233ad423e07980722702146`; implementation dylib SHA-256 `04a09691f18a9eefee04195702a56e56e49485cdede7c005a57190dda13b9523`.
- Physical observation: explicit candidate process inserted a synthesized local phrase into a disposable TextEdit document and exposed the real feedback offer with two buttons. The user separately confirmed exercising the thumbs and correct/incorrect flow.
- Cleanup: installed app was preserved and reopened as PID 51337; final input was `Microfone (MacBook Pro)`.
- `git diff --check` is clean. Product/test changes are confined to the expected five Phase 2 files; documentation changes are confined to the four expected Step 04 files.

## Blast-radius assessment

The outstanding work is evidence collection in Step 04, not structural rework. Step 03 has deterministic coverage for lifecycle, storage recovery, token retirement, timers, menu routing, permission transitions and hotkey behavior, and the full native gate is green. If physical VoiceOver testing exposes a missed announcement, the likely repair is local to the success-notice lifetime in `FloatingPanelController`; no current evidence justifies changing it preemptively.

## Evidence boundary

The following remain unverified in a controlled physical run: VoiceOver speech, Save/relaunch persistence and next dictated correction, continuous clipboard/caret/focus behavior, and bounded network/offline observation. These are not counted as observed results.
