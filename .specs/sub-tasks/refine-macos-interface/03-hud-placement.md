# 03 — Passive HUD and target placement

**Task File:** `.specs/tasks/in-progress/refine-macos-interface.feature.md`
**Phase:** 2
**Model:** sonnet
**Agent:** developer
**Depends on:** 01
**Parallel with:** 04
**Note:** Own `Sources/WhisperKey/FloatingPanel.swift` and `DictationCoordinator.swift` in this phase. Add tests immediately before `testDictationStateMachineRejectsOverlap`, leaving Step 04's permission-test region untouched. Do not edit AppDelegate or PermissionService. Consume Step 01's phase/error/target contracts without renaming them. Use the current task-file location if promoted.
**Goal:** Deliver the specified readable, passive native HUD on the target display without changing dictation output.

Implement Architecture state/visual tables and C1/C2/C3/C5/C6 using existing SwiftUI/AppKit. Ready/processing remain 280 × 64; the owner-approved recording capsule is 340 × 72; error expansion is bounded to 360 × 104 and the available frame. Follow docs/specs/06-floating-ui.md's recording-meter contract: red recording indicator, monotonic mm:ss timer, 48 rounded bars, real existing AVAudioRecorder levels, bounded smoothing/decay and memory-only recent history. Capture target identity at recording start, resolve read-only AX window geometry, and retain the selected screen through that dictation. Standalone feedback uses the architecture's external-target fallback chain. Preserve focus/click-through and the Step 01 lifetime contract.

#### Expected Output

All panel states render through the existing panel, with concise safe errors, deterministic geometry/target selection and internal-only fixture access. Native captures/observations are handed to Step 05 with state, appearance, environment and whether they are fixtures or real interactions.

Recording refinement: update this specification and Step 05 acceptance/evidence first, then implement only the Listening appearance and a read-only metering callback in the existing capture path. Expose deterministic injected clock/samples for checks; do not alter format, decoding, insertion, permissions or item 2. Keep production Swift files at most 200 lines.

#### Success Criteria

- State text/symbol/progress and ordinary/error dimensions match Architecture; long essential cause remains readable and no transcript/raw stderr appears.
- AX/AppKit conversion, largest intersection/tie-break, negative display coordinates, session retention, standalone fallbacks and display removal keep the panel inside fresh visibleFrame with the specified margin.
- Light/dark, increased contrast and reduced transparency use native semantic treatments; accessible status is meaningful without duplicate decorative labels or forced announcements.
- Panel never activates WhisperKey, takes focus or intercepts clicks; no new permission, display service or UI dependency is added.
- Exactly 48 real-level bars, timer rollover/reset, fixed recent-history capacity, bounded silence/smoothing/decay and stopped-state rejection pass deterministic tests. Reduced Motion has no shifting history/interpolation; per-sample updates do not trigger VoiceOver announcements. Fixtures and physical microphone evidence remain distinct.

#### Subtasks

1. Read all callers and Step 01 contracts; implement `FloatingStatusView` layout/state mapping and internal fixture access in `FloatingPanel.swift`, preserving the passive NSPanel flags.
2. Implement read-only target geometry and pure frame-selection/clamping helpers in the existing files; wire recording and standalone target selection through the existing contract without editing parallel-owned AppDelegate. Handle fresh frames, disconnects and missing AX access without prompting.
3. Map known coordinator error types to concise safe presentation at its UI boundary; retain only safe paths/exit/recovery detail for Step 04's existing contract and clear it on resolution/new attempt.
4. Add XCTest mapping/geometry regressions at the state-machine anchor, including negative frames, small visible frames, ties, no focused window, disconnected display, missing Accessibility, transient layout replacement and deterministic recording-meter clock/levels; provide silence/speech/decay/reduced-motion fixtures alongside the existing state/appearance set.
5. After Step 04's writes settle, run/share `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; launch the same bundle and verify focus, click-through, Spaces/full-screen and available display cases. Record unavailable hardware and fixture-only coverage explicitly for Step 05.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
|---|---|---|---|---|
| Risk | Coordinate conversion or target choice places HUD on wrong display | High | Medium | Value-based negative/mixed-layout tests plus actual second-display check when available; document AX fallback |
| Risk | SwiftUI accessibility/layout change activates or intercepts input | High | Low | Preserve AppKit flags; native focus and pointer verification, not screenshots alone |
| Risk | Error dump exposes transcript or overflows panel | Medium | Medium | Known-type concise mapping, safe diagnostic allowlist and bounded native layout checks |
| Blocker | AX geometry/full-screen behavior unavailable in a target app | Medium | Medium | Use explicit architecture fallback and record limitation; do not request additional privileges |
