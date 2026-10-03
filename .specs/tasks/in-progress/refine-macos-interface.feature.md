---
title: Refine the native macOS interface and component design
---

## Initial User Prompt

ótimo, agora vamos comecar a lapidar, em duas frntes o sistema: 1. Layout e design dos componentes em geral e 2. Melhroia do output: Melhria da dicção, etnendmento, capacitacao para anglicanismos dentro do protugues e melhroia no translate. Inicie traçando plano apra o item numero 1 e sóq uando exaustanete tratado, apssaremos apra o 2. SSe rpecisar, abra modo socratico comigo. Vamos coxntruir, como amnda nosso spec salvo no soul do codex: SSD

# Description

Refine item 1 of the request: the native macOS layout and component design of WhisperKey's existing M0 interface. People dictating into another application need to recognize whether WhisperKey is ready, listening, processing, or blocked, without losing their cursor or interrupting their work. The outcome is a coherent, legible, compact status interface and a discoverable menu for the existing controls.

This task plans that refinement before implementation. It does not authorize application changes, publishing, paid APIs, or starting item 2. The visual direction is a quiet macOS utility: native system typography, semantic colors, system symbols, restrained material, and clear hierarchy. Existing English UI copy remains consistent; changing the interface language is not part of this task. Existing M0 constraints remain authoritative.

**Owner Decision — Interface Footprint (2026-10-02)**

WhisperKey remains an invisible utility in daily use: a transient HUD plus menu bar controls. A lightweight onboarding/recovery surface may appear only when required for first-run setup or missing permissions. There is no persistent primary window or settings suite.

**Scope Included**

- Floating status panel: ready, listening, transcribing, inserting, failure, idle visibility, layout, sizing, spacing, typography, symbols, material, and placement.
- Menu bar icon, tooltip, status/instruction hierarchy, separators, and existing permission/check/quit controls.
- Permission presentation: identify the missing permission, explain its purpose, and provide deliberate navigation to the relevant System Settings pane through the menu.
- Light/dark appearance, increased contrast, reduced transparency/motion, keyboard access to the menu, assistive labels, and bounded long-message handling.
- A state-by-state visual specification and verification plan covering the existing dictation path, transient-panel lifetime, Spaces/full-screen, and multiple displays.

**Scope Excluded**

- **Item 2 is an explicit non-goal:** no improvement to dictation accuracy, pronunciation understanding, English words within Portuguese, translation, transcript normalization, model selection, decoding parameters, or output rewriting.
- Recording-only microphone-level waveform and elapsed duration are owner-approved item-1 refinements (2026-10-02), governed by SPEC-006. No decorative/random animation, transcript/history viewer, settings suite, hands-free mode, personal dictionary, login, billing, analytics, sync, network/API integration, or automatic launch at login.
- No new primary application window, Dock presence, interactive HUD, custom theme engine, third-party UI library, or distribution/release work.
- No changes to the hotkey contract, audio capture, transcription or insertion algorithms, permission acquisition policy, or retention policy. Minimal presentation-lifecycle corrections remain in scope when necessary to keep an active status visible.
- Planning does not complete the outstanding human-spoken CORE-001 acceptance check. A saved pending result cannot be reported as a pass; execution evidence must be gathered during implementation validation.

**User Scenarios**

1. **Primary dictation:** With a caret in TextEdit, hold Right Option, speak, and release. Listening, transcribing, and inserting are understandable at a glance; the panel disappears on completion and the original target retains focus.
2. **Discovery and readiness:** Open the menu from the status icon using mouse or keyboard. Find the hotkey instruction, current readiness, permission actions, and Quit without navigating another window. Ready feedback is transient; idle has no persistent panel.
3. **Permission denial/recovery:** With any required permission missing or revoked, see which permission is blocking dictation and why it is needed. Choose its System Settings action explicitly; denial does not record or repeatedly prompt. Existing rechecking detects restored access or explains a required relaunch.
4. **Failure and overlapping feedback:** A missing local runtime/model, capture failure, empty result, or insertion failure produces a concise status and recovers to idle. A previous ready/error dismissal cannot hide a newer recording or processing status. The menu retains the current blocking permission explanation when the transient panel disappears.
5. **Environment and accessibility:** Repeat the interface review in light/dark mode, accessibility display settings, another Space/full-screen app, and a second display when available. Status stays readable and on-screen; recording is distinguishable without relying only on red.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
|---|---|---|---|
| CK-1 | Does the visual specification cover every existing surface and all six visibility/status conditions (idle, ready, listening, transcribing, inserting, failure), with explicit typography, spacing, sizing, symbol, material, and copy decisions? | principle | essential |
| CK-2 | Are recording, processing, ready, and failure distinguishable by text and a meaningful symbol/progress treatment, with a steady red recording dot while listening and indeterminate progress while processing? | hard_rule | essential |
| CK-3 | Does the floating panel remain borderless, non-activating and click-through, preserving the target app and caret through each state and never taking keyboard focus? | hard_rule | essential |
| CK-4 | Is the panel horizontally centered near the bottom of the target application's display, within its visible frame, and visible appropriately across Spaces/full-screen without duplicating on other displays? | hard_rule | essential |
| CK-5 | Do ready and failure feedback dismiss after approximately two seconds, idle remain hidden, and a newer active status survive any earlier scheduled dismissal? | hard_rule | essential |
| CK-6 | Does the menu expose the hotkey instruction, current readiness, existing permission/check/quit actions and explicit relevant System Settings actions in a readable native hierarchy, with matching icon/tooltip state? | principle | important |
| CK-7 | Does each missing permission have a named explanation and deliberate recovery action, without recording while denied, silent Settings navigation, repeated prompting, or changing the existing periodic/reactivation recheck policy? | hard_rule | essential |
| CK-8 | Is every status and menu control legible and identifiable in light/dark, increased-contrast and reduced-transparency settings, with keyboard-operable menu controls, meaningful accessibility labels, no color-only meaning and no added motion dependency? | hard_rule | essential |
| CK-9 | Do long existing permission/runtime failure messages remain readable without clipped essential meaning or off-screen content, while the ordinary status panel stays compact and shows no transcript/audio content? | principle | important |
| CK-10 | Do the focused automated gate and manual TextEdit dictation check pass for the implemented revision, with Chromium and display/Spaces observations recorded accurately and no change to transcription behavior, clipboard restoration or temporary-file cleanup? | hard_rule | essential |
| CK-11 | Does the delivered diff preserve local-only/native/least-privilege/ephemeral M0 behavior and exclude every item-2 improvement and the listed new product features? | hard_rule | pitfall |
| CK-12 | Are visual-state evidence, actual test commands/results, environment and limitations recorded, with the human-spoken CORE-001 result explicitly passed or still pending rather than inferred from synthetic input? | hard_rule | essential |

**Regular Checks:**

- [ ] Review the diff against the M0 constitution and Scope Excluded; preserve existing work and do not introduce a dependency or paid/network path (CK-11).
- [ ] Run the repository's documented gate: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` (CK-2, CK-5, CK-7, CK-10). There is no configured standalone lint command or GitHub workflow in this baseline; do not invent either.
- [ ] Launch the same signed bundle with `open build/Build/Products/Debug/WhisperKey.app`; verify a single active app and exercise menu/HUD states and appearance settings (CK-1 through CK-9). Do not reset real TCC permissions automatically to manufacture a clean state.
- [ ] Execute the existing human-spoken CORE-001 phrase in TextEdit, then the Chromium compatibility check; record focus, cursor insertion, clipboard restoration and cleanup observations (CK-3, CK-10, CK-12).
- [ ] Review evidence for the actual tested revision and available hardware; record untested second-display/oldest-OS scenarios as limitations, never passes (CK-4, CK-8, CK-12).

**Rubric:**

| Criterion | Weight |
|---|---|
| Native Visual Coherence | 0.30 |
| Uninterrupted Status Feedback | 0.30 |
| Accessible Recovery and Readability | 0.25 |
| Project Guidelines Alignment | 0.15 |

**Rubric Score Definitions:**

### Native Visual Coherence

Assess the consistency and completeness of the visual treatment across the menu and all panel states, including light/dark material and compact sizing. Covers CK-1, CK-2, CK-6 and CK-9. Compare explicit design decisions and visual evidence; do not award coherence based on the word “native” alone.

Anchors:

- `score_2`:
  ```text
  Listening: red mic.fill + Listening…; system semibold text.
  Failure: warning symbol + concise cause; typography unspecified.
  ```
- `score_4`:
  ```text
  Listening: red mic.fill + Listening…; system semibold text.
  Failure: warning symbol + concise cause; system semibold text.
  ```
- `contrast`: Failure typography is specified consistently with the other status.

### Uninterrupted Status Feedback

Assess focus preservation, placement, state identity and lifecycle ordering against observed transitions. Covers CK-2 through CK-5 and CK-10. A polished still image is insufficient evidence for transition behavior.

Anchors:

- `score_2`:
  ```text
  Ready shown; listening begins before ready timeout.
  At the old timeout: listening panel disappears; TextEdit remains focused.
  ```
- `score_4`:
  ```text
  Ready shown; listening begins before ready timeout.
  At the old timeout: listening panel remains visible; TextEdit remains focused.
  ```
- `contrast`: An earlier dismissal does or does not hide the current active status.

### Accessible Recovery and Readability

Assess whether permission recovery is discoverable, essential text fits, and state meaning survives the supported appearance and assistive-access conditions. Covers CK-6 through CK-9. An icon or color alone does not replace a comprehensible status.

Anchors:

- `score_2`:
  ```text
  Menu status: Microphone permission required — needed to capture your voice.
  Recovery action: Enable permissions.
  ```
- `score_4`:
  ```text
  Menu status: Microphone permission required — needed to capture your voice.
  Recovery action: Open Microphone Settings.
  ```
- `contrast`: The recovery action identifies the relevant permission destination.

### Project Guidelines Alignment

Assess the implemented scope and the truthfulness of native, local-only and test evidence against the project's existing constraints. Covers CK-10 through CK-12. Plans, synthetic tests and human-spoken acceptance are distinct evidence types.

Anchors:

- `score_2`:
  ```text
  Synthetic Portuguese fixture: PASS.
  Human-spoken CORE-001: PASS, inferred from synthetic fixture.
  ```
- `score_4`:
  ```text
  Synthetic Portuguese fixture: PASS.
  Human-spoken CORE-001: PENDING, not yet performed.
  ```
- `contrast`: The recorded human acceptance result reflects the evidence actually collected.

**Test Strategy:**

Criticality: user-interface refinement with focus, input and permission boundaries. Wrong visual state can conceal recording or imply readiness while blocked; cross-app focus regression can insert into the wrong destination. Automated checks cover deterministic presentation decisions and lifecycle rules; native interaction and hardware remain manual integration gates. The planning stage specifies these checks and does not claim to execute them.

| Type | Size | Framework | Dependencies | Gate |
|---|---|---|---|---|
| unit | small | Existing XCTest target | Status/lifecycle and permission presentation logic; controlled time where needed | Documented mac-gate xcodebuild test |
| manual-visual | small | Native app + screenshots/inspection | Built signed app, appearance/accessibility display settings | State and appearance evidence reviewed |
| manual-integration | medium | Existing CORE-001 procedure + native app | Microphone, locally granted permissions, local Whisper runtime/model, TextEdit and Chromium | Human TextEdit pass; browser limitations explicitly recorded |
| review | small | Specification and diff review | Constitution, task scope, test log and revision | No scope violation or unsupported success claim |

Test Cases to Cover

#### CK-1: Surface and state completeness

- [manual-visual] Inspect idle, ready, listening, transcribing, inserting, failure and the open menu against the state specification; idle has no HUD. Use a development preview/fixture only where a fleeting state cannot be captured reliably, and label that evidence.
- [review] Verify each surface has explicit layout and native appearance decisions, without introducing a settings suite or visual framework.

#### CK-2: State meaning

- [unit] Verify each presentation state selects its correct title, symbol/progress treatment and listening emphasis, including failure content.
- [manual-visual] Confirm the actual panel distinguishes listening from processing and failure with text/symbols when color differences are ignored.

#### CK-3: Focus and pointer behavior

- [manual-integration] Run a dictation into TextEdit and Chromium; retain the active app/caret through visible states, and verify a click at the panel's location reaches the underlying app rather than activating WhisperKey.

#### CK-4: Screen, Space and full-screen placement

- [manual-integration] Show each representative panel state in the target app's Space and full-screen mode; verify its bounds stay within the display's usable area, including a moved/visible Dock.
- [manual-integration] Where a second display is available, focus its editable app while the pointer remains on the other display; ensure the panel follows the target display and does not appear twice. Record unavailable hardware as untested.

#### CK-5: Transient visibility ordering

- [unit] With controlled time, show ready/failure then start listening before dismissal; advancing the old timeout must not hide listening or subsequent processing. Verify hide and replacement invalidate obsolete dismissal work.
- [manual-integration] Observe ready/error dismissal at approximately two seconds, successful completion returning to hidden idle, and processing remaining visible for its entire active interval.

#### CK-6: Menu hierarchy

- [manual-visual] Open the menu in ready and blocked states; verify status, hotkey instruction, grouping, icon/tooltip consistency and permission/check/quit controls.
- [manual-integration] Activate Check permissions and Quit through the menu and confirm their existing effects; relaunch the same signed bundle afterward.

#### CK-7: Permission explanation and recovery

- [unit] Exercise each individual missing permission, multiple missing permissions, all granted, and revoked access; verify named blocker, explanation, recovery destination and no false-ready presentation.
- [manual-integration] Use an available denied-permission state or controlled test setup; choose the named Settings action, verify its destination, and confirm no navigation or request loop occurs without deliberate action. Observe recovery through existing rechecks; record any macOS-required relaunch.

#### CK-8: Accessible native appearance

- [manual-visual] Review light/dark, increased contrast and reduced transparency/motion, including busy and failure states; essential text/symbols remain readable and no new decorative animation is required.
- [manual-integration] Navigate and activate menu controls by keyboard; inspect meaningful accessibility labels and logical reading order with VoiceOver or Accessibility Inspector without changing the non-activating panel's focus behavior.

#### CK-9: Bounded error content

- [manual-visual] Render the longest current missing-permission/runtime error and an intentionally long fixture: preserve cause and recovery meaning without clipping or leaving the visible frame; normal status remains compact.
- [review] Verify the HUD/menu do not display transcript text, audio content or retained history.

#### CK-10: Pipeline regression

- [unit] Run the existing XCTest suite plus focused checks for newly introduced presentation branches and dismissal ordering; a behavioral bug fix includes its regression check in the same change.
- [manual-integration] Physically hold Right Option, say “Testando o nosso sistema de voz”, release in TextEdit, and record observed insertion without app switching/manual paste; repeat in Chromium and verify clipboard restoration and temporary-artifact cleanup.
- [review] Compare output-engine/capture/insertion behavior with baseline and confirm no accuracy or translation changes were introduced.

#### CK-11: M0 and item-2 boundary

- [review] Inspect the diff for dependencies, network paths, retained data, added permissions, new windows/features and output-engine changes; reject item-2 work or a changed permission acquisition policy.

#### CK-12: Evidence integrity

- [review] Verify date, revision, macOS/chip, local model/runtime, target app, spoken phrase, observed text, elapsed transcription time and pass/fail are recorded for CORE-001; keep visual fixtures and real interaction evidence distinct.
- [review] Check that unavailable display/OS coverage and pending human input remain stated as limitations and that this planning artifact is not presented as an implemented redesign.

**Definition of Done:**

- [ ] The implemented interface meets the checklist and visual specification for the existing M0 surfaces, with reviewable evidence for the specified states and supported appearance settings.
- [ ] The documented mac-gate test command passes for the implemented revision, and deterministic behavior changes have focused regression checks.
- [ ] Human-spoken TextEdit CORE-001 is recorded as passed; Chromium compatibility and any unavailable hardware/OS coverage are accurately recorded under the existing M0 limitation policy.
- [ ] No known focus, permission, lifecycle, accessibility or essential-text clipping defect remains; evidence identifies the tested revision and current limits.
- [ ] The change stays within item 1, preserves M0 invariants, and leaves item 2 explicitly unstarted. Completing this plan alone does not satisfy implementation completion.

## Architecture Overview

### Solution strategy and inputs

Implement the owner's **Direction A**: WhisperKey stays invisible during ordinary idle, with one passive transient HUD and the existing native menu bar controls. Reuse the current SwiftUI/AppKit components on macOS 14. Permission guidance lives in the menu only while setup/recovery is needed; no onboarding wizard, persistent main window, new settings suite or stored first-run flag is required.

Inputs: [native UI research](../../../.claude/skills/whisperkey-macos-ui/SKILL.md), [codebase analysis](../../analysis/analysis-refine-macos-interface.md), and the Owner Decision above. The analysis found two competing HUD producers and an unowned readiness timeout; resolve that presentation boundary before refining appearance. The following design changes presentation and its lifecycle only. Capture format, hotkey semantics, model invocation, normalization, insertion and clipboard algorithms remain unchanged.

### Components and ownership

| Component | Existing location | Responsibility after refinement |
|---|---|---|
| App/menu controller | `Sources/WhisperKey/WhisperKeyApp.swift`, `AppDelegate` | Own NSStatusItem/NSMenu, permission polling, current menu snapshot, named Settings actions and a native status-details submenu. Track menu interaction to reject new dictation starts without dropping an active recording's release event. Observe coordinator phase changes without owning another pipeline state machine. |
| Dictation state owner | `Sources/WhisperKey/DictationCoordinator.swift`, `DictationCoordinator` | Remain the authoritative DictationPhase owner and original-target capture point. Publish a small main-actor phase-change callback/read-only phase for the menu, provide target display at recording start, and delegate transient failure dismissal to the panel. |
| HUD controller and view | `Sources/WhisperKey/FloatingPanel.swift`, `FloatingPanelController`, `FloatingPanelModel`, `FloatingStatusView` | Own a single reusable NSPanel, current visual state, transient generation/deadline, view layout and native accessibility. Keep placement calculation in this file; no display service or theme package. |
| Permission presentation | `Sources/WhisperKey/PermissionService.swift`, `PermissionService`/`PermissionGate` | Continue existing status reads/requests; expose named permission explanations and explicit Settings destinations. A snapshot must reflect all three permissions, including partial changes while monitoring is stopped. |
| Verification seam | `Tests/WhisperKeyTests/WhisperKeyTests.swift` with internal symbols in the existing source files | Exercise pure presentation mapping, deadline/generation, menu-start guards and session/standalone frame decisions without real microphone/TCC/model calls. Use the existing XCTest target and native view hosting for labeled visual fixtures. |

### State and surface specification

The pipeline phase remains the source of activity truth. Permission availability is orthogonal: a missing permission can be shown in the menu while an already-started processing phase is still visible. Neither successful permission checking nor a timer may report pipeline success.

| Condition | HUD title / secondary text | Indicator | Visibility and menu status |
|---|---|---|---|
| Idle, permitted | No HUD | Menu `waveform` | Hidden; menu `Ready`, followed by `Hold Right Option to dictate` |
| Ready confirmation | `Ready` / `Hold Right Option to dictate` | `waveform` | Approximately 2 seconds on existing startup-ready event or explicit Check; no recurring idle flash |
| Recording | `Listening` / elapsed `mm:ss`; release instruction in menu/accessibility status | Steady red recording dot and 48 real microphone-level rounded bars | Entire recording interval; menu and accessible status say `Listening` |
| Transcribing | `Transcribing…` / no secondary line | Native small indeterminate ProgressView | Entire processing interval; menu says `Transcribing` |
| Inserting | `Inserting…` / no secondary line | Same ProgressView footprint | Until actual pipeline completion; menu says `Inserting` |
| Failure or explicit blocked check | Concise named cause / `Open the WhisperKey menu for help` | `exclamationmark.triangle.fill` | Approximately 2 seconds; durable blocking permission remains in menu after HUD hides |

The menu groups product/status and the hotkey instruction, permission/recovery controls, then Quit. Keep **Enable permissions**, **Check permissions**, and **Quit WhisperKey** (Command-Q). Show each missing permission with its purpose and a named **Open … Settings** action; group long explanations in a native Permissions submenu. Granted permissions are identified as granted, not presented as blockers. Hide setup explanations when all rights are available. The icon uses `mic.fill` during recording, `waveform` during processing/ready, and `waveform.badge.exclamationmark` for an idle blocker; tooltip/accessibility text carries the complete current activity and any blocker, so icon priority cannot conceal missing access.

### Native visual system

Ready/processing use one leading-aligned HStack with a fixed 20-point indicator slot, 12-point gap and 18-point horizontal inset, retaining the 280 × 64-point footprint. Use a 14-point semibold system title and 12-point regular secondary line in semantic secondary color. Vertically center one-line states; two-line states use a 3-point text gap. Keep the rounded 18-point shape and 4-point outer margin for these states; Listening uses SPEC-006's 340 × 72 capsule. These are project design values, not Apple requirements.

Use regularMaterial with system primary/secondary foregrounds and the existing restrained shadow. Reduce Transparency uses an opaque native window-background color; Increase Contrast adds a 1-point semantic separator outline and promotes secondary text to primary when necessary for readability. Ready/error retain an SF Symbol; processing retains native ProgressView. Listening alone now uses SPEC-006's 340 × 72 recording capsule: 48 rounded real-level bars, steady red dot, elapsed monotonic mm:ss, bounded smoothing/decay and stationary Reduce Motion. No random waveform, pulse, decorative transition or invented percentage is added. Native menu typography, padding and keyboard behavior remain AppKit-owned.

Failure titles wrap up to two lines with content-driven height, bounded to 360 × 104 points and the selected screen's available width/height. Ready/processing stay at 280 × 64; Listening alone is 340 × 72. Essential cause is never replaced by a truncated file path or subprocess dump: adapt known error types at the coordinator's presentation boundary to concise titles such as `Microphone unavailable`, `Whisper model not found`, `No speech detected`, `Original app unavailable` or `Dictation failed`.

For a missing executable/model, retain the attempted paths as safe diagnostic detail; for a subprocess failure retain the exit code and recovery guidance, not arbitrary stderr or transcript text. A native **Status details** submenu presents this current-error information inside the existing menu surface. Use named cause/recovery rows and read-only wrapping native text for long paths, with width bounded to 360 points or the available screen width and native menu scrolling for overflow. Preserve accessibility reading and keyboard navigation into/out of the submenu; never depend on an off-screen title or tooltip as the sole source of essential information. Its memory-only detail clears when the problem is resolved or a new attempt starts. No runtime-error alert, separate diagnostic window or history is introduced.

### Integration contracts

**C1 — Focus and pointer.** Preserve `.borderless`, `.nonactivatingPanel`, `ignoresMouseEvents=true`, `.floating`, `hidesOnDeactivate=false`, and a single panel instance. HUD code must not call NSApp activation, makeKeyAndOrderFront or add focusable controls. Capture the original application before displaying listening, as today. AppDelegate uses NSMenu tracking callbacks to reject a new hotkey press while its menu/submenus are open; it also rejects starts whose frontmost target is WhisperKey itself. Do not stop HotkeyMonitor to implement this guard: a release for an already-started recording must still reach the coordinator even if the menu opens mid-recording. Closing the menu does not replay a rejected press; require a fresh press after release. This is a presentation-interaction gate, not a new hotkey mapping. Menu and Settings actions remain deliberate interaction; automatic status updates never open or activate them.

**C2 — Display and placement.** At recording start, read the already-authorized target application's focused-window frame through Accessibility; do not request Screen Recording or any new permission. Convert its desktop coordinates into AppKit screen coordinates and select the screen with the largest window intersection, using the window center as a tie-breaker. If the window query fails, fall back to the last valid display for that target, then NSScreen.main/first screen; document this fallback rather than claiming exact placement in apps without usable AX window geometry. Use this screen identity throughout that dictation, including its failure feedback, not pointer location. Standalone ready/failure feedback uses the current external frontmost application and the same read-only AX resolver; when WhisperKey/menu interaction prevents identifying an external frontmost app, use the latest known external target, then its valid screen identity, then NSScreen.main/first screen. Missing Accessibility skips the AX query and uses these explicit fallbacks without prompting. Obtain fresh visibleFrame on each presentation and screen-configuration change; if disconnected, select a remaining screen. Center horizontally, prefer visibleFrame.minY + 88 vertically, and clamp all edges inside visibleFrame with a 12-point margin. Convert negative screen coordinates correctly. Keep canJoinAllSpaces/fullScreenAuxiliary and one physical panel; verify actual full-screen behavior rather than raising its level. Geometry and session/standalone selection accept frames and optional target identity as values for unit checks.

**C3 — Transient lifecycle and precedence.** FloatingPanelController is the sole owner of delayed HUD dismissal. Each show/hide invalidates the previous generation, cancels the previous dismissal Task and updates an internal monotonic deadline. A delayed completion must check both generation and cancellation before hiding; `try? sleep` followed by unconditional hide is prohibited. `showTemporarily(_:onDismiss:)` accepts an optional main-actor completion for the current generation only. Coordinator failure uses that completion to finish failed → idle, replacing its separate two-second failure reset Task; successful completion/cancel still explicitly hides and clears state. AppDelegate may request ready/permission feedback only while the coordinator is idle; Check during recording/transcribing/inserting/failed updates the menu without replacing the HUD. No ready message is queued to appear unexpectedly later. A minimal internal `dismissIfCurrent(generation:now:)` decision and explicit deadline allow tests to advance time without sleeping or introducing a scheduler framework.

**C4 — Permissions and recovery.** Preserve the existing request policy: only the explicit Enable action triggers the existing requests, microphone prompts only from notDetermined, and the existing one-second/reactivation checks remain. Update menu/tooltip on snapshot changes even when the monitor stays stopped; never repeatedly announce an unchanged snapshot. Each Settings action opens only its named destination after a click; if macOS rejects navigation, retain instructions in the menu. Permission polling never opens onboarding or Settings. Any external setup/recovery UI is restricted to first-use setup or missing permissions under Direction A; this design meets that need through the existing system permission prompts and named System Settings actions, with guidance in the menu. Runtime diagnostics stay in the Status details submenu. While a permission request is in progress, reject new starts through the same AppDelegate interaction guard as menu tracking, without swallowing an active release; release that guard when the request completes, without replaying a press. If permission loss occurs during recording, stop monitoring and invoke the coordinator's existing recorder cleanup/failure path so the HUD cannot hide a still-recording microphone. Do not cancel/reset a transcribing or inserting phase merely to change its permission appearance: the existing detached worker can still complete. Keep its real phase visible, expose the blocker in the menu, and block subsequent recordings through the existing gate. This bounded recording cleanup does not change recording format, transcription or insertion algorithms.

**C5 — Accessibility.** Treat title plus optional secondary line as one understandable status; hide decorative symbols from duplicate VoiceOver announcements and give ProgressView a meaningful operation label. The status item and menu expose the same state text and keyboard-operable native controls. Accessible names never rely on red or a glyph alone. Preserve logical reading order, system colors and native display-setting adaptations. Do not move focus or force a spoken announcement on every poll; inspect real VoiceOver discoverability and record any nonactivating-overlay announcement limit. No decorative motion exists; native indeterminate progress remains the honest processing signal.

**C6 — Data, identity and evidence.** All presentation state and safe diagnostic detail are memory-only. Do not retain/display audio or transcripts, add a dependency/network path, change bundle/signing identity or duplicate the installed app. Tests/builds use the existing mac-gate command and `-derivedDataPath build`. Unit fixtures and still images prove presentation only; target focus, actual menu actions, TCC recovery, Spaces and human CORE-001 require the existing native integration procedure. No UI planning result closes the human-spoken acceptance gap.

### Decisions and tradeoffs

| Decision | Chosen approach | Tradeoff |
|---|---|---|
| D1 — Footprint | Existing NSMenu plus passive HUD; permission guidance and runtime details remain in native submenus, with external system setup only for first use/missing permissions | Long detail requires opening a submenu, but runtime failures add no window or persistent onboarding state |
| D2 — State ownership | Existing coordinator owns phases; panel owns visual dismissal; menu observes phase and permission snapshots | A small callback/guard is required, avoiding a second state machine or event framework |
| D3 — Appearance | Current native material/system controls, compact fixed ordinary size and bounded error expansion | No new glass framework or branding engine; rendering varies naturally with macOS appearance |
| D4 — Target display | Read-only AX focused-window bounds with explicit fallback and fresh visibleFrame | Exact screen selection depends on target AX support; pointer position is not a substitute for the target screen |
| D5 — Verification | Existing XCTest target plus native fixtures and manual focus/accessibility evidence | Hardware/OS/TCC coverage cannot be inferred from snapshots; unavailable cases stay NOT RUN |

### Expected changes

The original synthesis named 12 text/source files. Reviewed cohesive source extraction and the owner-approved recording refinement extend that historical envelope with native presentation helpers and read-only AudioRecorder metering. README documents recovery and the recording capsule; M0 evidence receives the actual integration outcome. Screenshot artifacts are separate evidence outputs, manifested as fixtures or real interactions.

| Operation | Path | Bounded change |
|---|---|---|
| Modify | `Sources/WhisperKey/FloatingPanel.swift` | State presentation, native layout/accessibility, transient generation/deadline, target-screen geometry and internal fixture access |
| Modify | `Sources/WhisperKey/WhisperKeyApp.swift` | Native menu/status/detail submenus, snapshot refresh, menu/request interaction guard, external-target fallback and explicit named Settings actions |
| Modify | `Sources/WhisperKey/PermissionService.swift` | Named permission presentation and explicit Settings destinations; preserve requests and polling policy |
| Modify | `Sources/WhisperKey/DictationCoordinator.swift` | Read-only phase/callback, captured target display, safe error presentation, panel-owned failure dismissal and recording-only permission-loss cleanup |
| Modify/Create | `Sources/WhisperKey/AudioRecorder.swift`, `FloatingStatusView.swift`, `RecordingWaveformView.swift` | Existing AVAudioRecorder's level-only callback, injected-clock meter, bounded 48-level history and recording-only capsule; preserve capture format and transcription |
| Modify | `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Focused mapping, partial permissions, timer generation, menu/request start-versus-release guards and session/standalone screen checks in the existing test target |
| Modify | `docs/specs/06-floating-ui.md` | Implemented visual/focus/placement/lifecycle contract |
| Modify | `docs/specs/07-permissions.md` | Actual contextual explanations and explicit recovery controls |
| Modify | `docs/specs/08-testing.md` | Fixture versus runtime verification and new focused regressions |
| Modify | `docs/architecture.md` | Final presentation ownership and integration contracts |
| Modify | `README.md` | Menu/recovery usage matching the delivered controls |
| Modify | `docs/testing/M0-EVIDENCE.md` | Actual tested revision and human/browser integration outcomes; preserve pending status unless performed |
| Create | `docs/testing/UI-REFINEMENT-EVIDENCE.md` | State/appearance captures, tested revision/environment, manifest and honest PASS/FAIL/NOT RUN observations |

No changes are planned to HotkeyMonitor, WhisperTranscriber or TextInjector algorithms, project dependencies, deployment target, plist identity or signing. AudioRecorder gains existing-AVFoundation metering only: no format, microphone-route, captured content or transcription change. Internal preview/test access may relax `private` to module-internal for the existing view/model or pure helpers; it does not create a public API or runtime preview menu. Item 2 remains unstarted.

## Implementation Process

Execution directive: after implementation is authorized, launch one agent per step using that step's **Model** and **Agent**, passing both the current task-file path and its sub-task file. Implement exactly that step. Launch independent steps marked parallel concurrently; share their completed contracts before starting dependent work. Run one `reviewer` agent once per phase at the recorded reviewer model, after integrating that phase and collecting its checks. Fix review findings within the same phase before proceeding. Do not start item 2 or publish/deploy.

Parallel steps own disjoint production files. Their additions to the existing XCTest file must use the separate anchors named in their sub-task files, with narrow patches and no file-wide formatting. Wait until both agents have finished writing before building or testing the shared tree. Execute the documented mac-gate command once for the integrated phase; its result validates both steps on the same settled revision. Gate execution is serialized even when editing is parallel. Record the exact diff/revision, do not validate a moving tree, and preserve unrelated work.

### Parallelization Overview

```text
Phase 1 — runnable lifecycle and permission foundation
    [01 Lifecycle + contracts]     [02 Permission presentation]
                \                    /
                 [integrated gate + phase review]
                   |                |
Phase 2 — complete native interface
    [03 HUD + placement]          [04 Menu + recovery]
       depends on 01              depends on 01,02
                 \                 /
                 [integrated gate + phase review]
                              |
Phase 3 — accepted integration and current documentation
                 [05 Integration + evidence + docs]
                 [native checks + phase review]
```

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
|---|---|---|---|---|---|---|
| 01 — Lifecycle and presentation contracts [DONE] | 1 | opus | developer | None | 02 | [.specs/sub-tasks/refine-macos-interface/01-lifecycle-contracts.md](../../sub-tasks/refine-macos-interface/01-lifecycle-contracts.md) |
| 02 — Permission presentation values [DONE] | 1 | sonnet | developer | None | 01 | [.specs/sub-tasks/refine-macos-interface/02-permission-presentation.md](../../sub-tasks/refine-macos-interface/02-permission-presentation.md) |
| 03 — Passive HUD and target placement [DONE] | 2 | sonnet | developer | 01 | 04 | [.specs/sub-tasks/refine-macos-interface/03-hud-placement.md](../../sub-tasks/refine-macos-interface/03-hud-placement.md) |
| 04 — Native menu and deliberate recovery [DONE] | 2 | sonnet | developer | 01, 02 | 03 | [.specs/sub-tasks/refine-macos-interface/04-menu-recovery.md](../../sub-tasks/refine-macos-interface/04-menu-recovery.md) |
| 05 — Integration evidence and documentation | 3 | sonnet | developer | 03, 04 | None | [.specs/sub-tasks/refine-macos-interface/05-integration-evidence.md](../../sub-tasks/refine-macos-interface/05-integration-evidence.md) |

Dependencies are artifact dependencies; phase review is an additional barrier, so no Phase 2 edits start before the integrated Phase 1 passes review. Structural critical paths are 01 → 03 → 05 and 01/02 → 04 → 05; elapsed critical path depends on actual durations. Maximum concurrent implementation width is **2**. Step 01 earns opus because it changes the shared coordinator/panel/menu lifecycle contract; subsequent sonnet steps apply the settled architecture. No mechanical-only step warrants haiku.

### Phase Overview

#### Phase 1 — Stable lifecycle and permission foundation [REVIEWED]

**Steps:** 01, 02.
**Reviewer model:** opus.
**Acceptance Criteria that should be fulfiled:** The current app still builds and runs with its existing appearance. One owner manages transient dismissal; phase/error/interaction contracts are available to subsequent UI steps, existing entry points work, and permission values preserve request semantics. This phase does not claim the redesigned interface is finished.

**Checklist items:**

- CK-5 — transient ownership and stale-dismissal regression pass.
- CK-11 — item-1 boundary and M0 invariants are preserved in the phase diff.

**Rubrics:**

- Uninterrupted Status Feedback — lifecycle ownership only.
- Project Guidelines Alignment — scoped diff and real integrated gate.

**Verification artifact:** Integrated XCTest result, launch smoke observation and lifecycle cases at the actual phase revision; produced by the two step agents and assessed together by the phase reviewer.

#### Phase 2 — Complete native interface [REVIEWED]

**Steps:** 03, 04.
**Reviewer model:** opus.
**Acceptance Criteria that should be fulfiled:** The executable app contains the specified HUD, placement, native appearance, menu, permission explanations and safe status details. Automated mapping/geometry/interaction checks pass. Native focus, menu navigation, Settings actions and available appearance/Space/display checks are exercised; unavailable environments are explicitly NOT RUN. Final human dictation acceptance remains Phase 3.

**Checklist items:**

- CK-1, CK-2 — complete state specification and meaningful native status rendering.
- CK-3, CK-4, CK-5 — passive focus/pointer behavior, documented placement/fallback and correct lifetime.
- CK-6, CK-7 — menu hierarchy and deliberate permission recovery.
- CK-8, CK-9 — accessible appearance and bounded essential error content.
- CK-11 — no item-2 or other excluded product work.

**Rubrics:**

- Native Visual Coherence.
- Uninterrupted Status Feedback.
- Accessible Recovery and Readability.
- Project Guidelines Alignment.

**Verification artifact:** Integrated gate plus labeled native/fixture captures and focused manual observations handed to Step 05. A fixture is not evidence that focus or TCC recovery works.

#### Phase 3 — Verified integration and accurate handoff

**Steps:** 05.
**Reviewer model:** opus.
**Acceptance Criteria that should be fulfiled:** The integrated app remains executable; full scoped native validation and human-spoken TextEdit acceptance are recorded against its final revision, documentation matches the delivered behavior, and evidence accurately identifies unavailable coverage. If human input or hardware is unavailable, complete independent work and leave that acceptance explicitly pending; do not declare implementation done.

**Checklist items:**

- CK-10 — final gate, human TextEdit acceptance and recorded browser behavior.
- CK-12 — revision/environment/evidence completeness and honest limitations.
- CK-11 — final scope/privacy/identity review, with item 2 unstarted.
- CK-1, CK-2, CK-6, CK-7, CK-8, CK-9 — final evidence matches the integrated visual and recovery behavior.
- CK-3, CK-4, CK-5 — final focus, placement and lifetime observations match the implemented contracts.

**Rubrics:**

- Native Visual Coherence.
- Uninterrupted Status Feedback.
- Accessible Recovery and Readability.
- Project Guidelines Alignment.

**Verification artifact:** `docs/testing/UI-REFINEMENT-EVIDENCE.md`, its capture manifest, updated `docs/testing/M0-EVIDENCE.md` and final documented mac-gate result. Apply the existing Definition of Done in Acceptance Criteria; no separate completion rule is introduced here.
