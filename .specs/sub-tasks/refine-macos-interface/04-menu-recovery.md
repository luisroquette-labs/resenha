# 04 — Native menu and deliberate recovery

**Task File:** `.specs/tasks/in-progress/refine-macos-interface.feature.md`
**Phase:** 2
**Model:** sonnet
**Agent:** developer
**Depends on:** 01, 02
**Parallel with:** 03
**Note:** Own `Sources/WhisperKey/WhisperKeyApp.swift` and `PermissionService.swift` in this phase. Add interaction/snapshot tests immediately before `testPermissionGateStartsWhenPermissionsArriveAfterLaunch`; do not edit the state-machine test region. Read but do not edit parallel-owned panel/coordinator files. Use Step 01's phase/error/recording-cleanup contracts and Step 02's permission values without renaming. Use the current task-file location if promoted.
**Goal:** Make readiness, permission recovery and safe runtime details discoverable through the existing native menu while preserving the current dictation session.

Implement Architecture C1/C4/C5/C6 and the menu hierarchy with native NSMenu controls. Subscribe to real coordinator activity and complete permission snapshots. Add contextual missing-permission explanations/named Settings actions and a memory-only Status details submenu using the safe error contract. System setup occurs only on explicit existing Enable or named Settings actions; no runtime-error window, onboarding state or settings suite is added.

#### Expected Output

Working native menu/status icon/tooltip/accessibility text for ready, recording, processing and blocked states; deliberate recovery actions, bounded wrapping diagnostics, and interaction guards that reject new starts while allowing an existing recording to finish.

#### Success Criteria

- Menu grouping, Enable/Check/Quit and named Settings actions match Architecture; granted permissions are not blockers and partial changes update even while monitoring remains stopped.
- Menu/submenu tracking, self-target and permission-request guards reject new presses without stopping hotkey monitoring for that purpose; active recording releases remain delivered and rejected presses are never replayed.
- Check while active updates the menu only; permission loss during recording invokes Step 01's cleanup, while transcribing/inserting remains visible and is not reset.
- Status details preserve safe cause/path/exit/recovery meaning in bounded native submenu content; keyboard navigation and accessibility reading remain usable, without transcript/raw stderr or history.

#### Subtasks

1. Wire coordinator callbacks and permission snapshots to native menu status/icon/tooltip; retain real activity priority and durable permission explanations without repeated unchanged announcements.
2. Implement named Settings actions with checked navigation result and in-menu manual recovery instructions; preserve the existing explicit request policy and release the request guard on completion/failure.
3. Implement NSMenu tracking/self-target/request start guards and safe native Status details content, consuming Step 01/02 values; do not modify capture/transcribe/insertion behavior or introduce an interactive HUD.
4. Add XCTest cases at the permission-test anchor for partial snapshot refresh, menu/request/self-target blocked starts, active release delivery, fresh-press requirement and safe detail filtering; verify native keyboard, accessibility and explicit Settings actions without resetting TCC automatically.
5. After Step 03's writes settle, run/share `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; launch the same bundle and supply actual menu/permission observations and labeled captures to Step 05. Test menu-open-mid-recording and permission loss using an available or deliberately controlled state; record unperformed real TCC checks.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
|---|---|---|---|---|
| Risk | Menu/request guard swallows release and leaves microphone recording | High | Medium | Guard new starts only; test active release while menu/request guard is true and verify native interaction |
| Risk | Status icon implies readiness while a permission is revoked | Medium | Medium | Derive tooltip/menu from full snapshot and real phase; test partial permission changes |
| Risk | Custom wrapping submenu content breaks keyboard/VoiceOver access | Medium | Medium | Keep NSMenu navigation native; inspect actual assistive reading/order and scrolling |
| Blocker | macOS rejects a permission pane URL or requires relaunch | Medium | Medium | Keep named instructions visible and report actual OS result; no silent fallback navigation or repeated prompts |
