# 02 — Permission presentation values

**Task File:** `.specs/tasks/in-progress/refine-macos-interface.feature.md`
**Phase:** 1
**Model:** sonnet
**Agent:** developer
**Depends on:** None
**Parallel with:** 01
**Note:** Own `Sources/WhisperKey/PermissionService.swift` only in production. In `Tests/WhisperKeyTests/WhisperKeyTests.swift`, add permission cases immediately before `testPermissionGateStartsWhenPermissionsArriveAfterLaunch`; do not touch the state-machine anchor owned by Step 01. No whole-file formatting. Use the task's current location if promoted.
**Goal:** Expose complete permission presentation values and named recovery destinations without changing permission request policy.

Read Architecture C4 and existing `PermissionService`/`PermissionGate` callers. Retain their working API while adding the smallest internal snapshot/descriptor needed by the native menu. Values must identify Microphone, Accessibility and Input Monitoring individually, with purpose, granted/missing status and their named Settings destination. This step defines destinations; Step 04 implements explicit menu navigation and failure feedback.

#### Expected Output

`PermissionService.swift` provides a truthful snapshot including partial changes while hotkey monitoring is stopped. Existing enable/check behavior and `missingPermissionMessage` remain usable, so this change can run with the unchanged menu.

#### Success Criteria

- All granted, each single missing, multiple missing and restored/revoked cases have deterministic named presentation; none reports ready with a missing right.
- Snapshot equality/change detection can detect partial permission changes without polling-triggered announcements or requests.
- Existing explicit requests, microphone `notDetermined` guard and least-privilege behavior are unchanged; no Settings navigation occurs here.

#### Subtasks

1. Inspect `PermissionService.swift`, AppDelegate and coordinator call sites; keep compatibility with the Phase 1 lifecycle work without editing those callers.
2. Add native permission names, short purposes, availability snapshot and named Settings destinations as internal values; reuse existing booleans/request methods and avoid a permission framework.
3. Add XCTest cases before the permission-test anchor for the available/missing combinations, partial snapshot changes and destination identity; test data only, with no real TCC resets or system prompts.
4. Hand exact descriptor/snapshot names to Step 04; wait for Step 01 to finish writing, then share its integrated mac-gate result at the same revision. If executing the gate yourself, use `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` only after editing settles.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
|---|---|---|---|---|
| Risk | Prioritized single missing message conceals a second revoked right | Medium | Medium | Snapshot contains all three flags; test partial changes and multiple blockers |
| Risk | Adding presentation accidentally triggers requests or changes authorization | High | Low | Keep descriptors pure; preserve existing request entry points and test request-free construction |
| Blocker | Named Settings route unsupported by the running macOS | Medium | Medium | Carry explicit destination identity; Step 04 verifies runtime open result and preserves manual instructions |
