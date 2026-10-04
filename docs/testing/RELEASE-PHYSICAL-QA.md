# Resenha release physical QA matrix

Status: executable checklist; results below apply only when the exact version, build,
commit and binary hash fields are filled. Historical passes never carry forward.

## Build under test

| Field | Value |
|---|---|
| Version / build | `1.0.0 (2)` |
| Commit | `PENDING — final branch commit; archive built from working tree based on ae34e157eca5c9df51555dcc5a84916562ddd338` |
| Binary SHA-256 | `d6226404b5b2ccee0024be20bfd0d58519df16053488549353644bf0ca458b4c` |
| Hardware / OS | `Apple M5 / macOS 26.1` |
| Minimum macOS 14 hardware | `NOT RUN — unavailable in this session` |

## Physical matrix

| Gate | Exact observation required | Status |
|---|---|---|
| TextEdit / SERVICE-001 | Hold ⌘⇧E, speak CORE-001, release E; record text, caret, clipboard and latency | NOT RUN on final archive |
| Chromium / SERVICE-002 | Repeat in an editable browser field; record insertion, focus and clipboard | NOT RUN on final archive |
| Terminal / SERVICE-003 | Repeat at a safe empty prompt; verify no command is submitted | NOT RUN on final archive |
| VoiceOver | Navigate menu/settings; verify names, order, selected values and that ⌘⇧E does not invoke VO-Space | NOT RUN — requires physical assistive-tech session |
| Multiple displays / Spaces | Put target window on each display/full-screen Space; verify HUD target/fallback and no focus theft | NOT RUN on final archive |

## Automated evidence boundary

- Debug bundle/container isolation, target-window selection, coordinate conversion,
  fallback, contrast ratios and resizable window contracts are unit-tested.
- `CGWindowListCopyWindowInfo` is best effort. A unit pass proves selection logic, not
  that every sandboxed host exposes window metadata.
- VoiceOver, microphone, caret insertion, browser/terminal compatibility and macOS 14
  remain physical gates. Do not convert `NOT RUN` to `PASS` from fixtures or source review.

### Phase 4 automated run — 2026-10-03

- Installed production app remained open at `/Applications/Resenha.app` throughout
  the gate. Its preferences file retained the same timestamp and size (`1791066228`,
  `123` bytes) before and after the test run.
- Debug host resolved to `br.com.luisroquette.Resenha.Debug` / `Resenha Dev`; Release
  analysis resolved to `br.com.luisroquette.Resenha` / `Resenha`.
- The post-review `mac-gate xcodebuild test` passed **90 tests, 0 failures, 0 skips**
  without a bundle override. Result:
  `/tmp/resenha-phase4-refine-full/Logs/Test/Test-WhisperKey-2026.10.03_20-39-07--0300.xcresult`.
- The post-review `mac-gate xcodebuild analyze` passed for Release. Derived data:
  `/private/tmp/resenha-phase4-refine-analyze`.
- Light/dark settings and HUD fixtures were inspected at native rendering size. A
  deterministic `accessibility3` fixture now renders every HUD state inside its
  accessibility-aware panel bounds; this is automated layout evidence, not a physical
  enlarged-text or VoiceOver session. Enlarged onboarding/settings, VoiceOver and target
  apps remain `NOT RUN` above.
- The focused Phase 4 review-fix gate passed **2 tests, 0 failures, 0 skips** for every
  adaptive text color against both gradient endpoints and all enlarged HUD states.
  Result: `/tmp/resenha-phase4-review-fixes/Logs/Test/Test-WhisperKey-2026.10.03_20-37-29--0300.xcresult`.
  The full-suite and Analyze results above include these localized fixes.
- LaunchServices cleanup resolved paths before mutation, unregistered only test/build
  copies, and retained one canonical `/Applications/Resenha.app` registration. Legacy
  production-ID Debug registrations went from `22` to `0`; current task build
  registrations are `0`.
- The isolated model clone, generated UI images and temporary preference suites used by
  this run were moved to Trash after evidence capture. Production data was not removed.

## Recording a result

For each row, replace only that row's status with `PASS` or `FAIL`, then append date,
tester, target app/version, actual transcript, elapsed seconds and unexpected behavior.
Retain failures; a new build requires a new observation.

## Phase 5 automated archive

- Archive: `/private/tmp/Resenha-1.0.0-b2.xcarchive` (9.5 MB), arm64,
  `Apple Development: luis roquette (K74FG72F9W)`. This is a validated local
  archive, not an exported/uploaded App Store package.
- Final Debug gate: **91 tests, 0 failures, 0 skips** with the production app still
  open and a SHA-256-verified model copied only into the isolated Debug container.
  Result: `/tmp/resenha-phase5-final-derived/Logs/Test/Test-WhisperKey-2026.10.03_21-06-27--0300.xcresult`.
- Release static analysis: PASS. Derived data: `/private/tmp/resenha-phase5-analyze`.
- Package validation: exact candidate accepted; a synthetic `99.99.99` candidate
  mismatch was rejected. The validator also requires exactly Sandbox, microphone
  input and network-client entitlements.
