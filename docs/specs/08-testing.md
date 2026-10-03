# SPEC-008 — Testing

Status: accepted for M0

## Strategy

Use the smallest checks that prove boundaries. Pure state and path discovery are unit tested. macOS permission, hardware, global input, Whisper runtime, and cross-app insertion are validated locally as integration/manual gates.

## Automated checks

Recording refinement: injected monotonic clock and level samples verify dB normalization, fixed 48-bar history order, bounded attack/decay, silence, timer rollover/reset, stopped-state rejection and stationary Reduce Motion. Forty native-view fixtures cover the state/appearance matrix, including injected speech/silence/decay. They do not prove physical microphone responsiveness or cross-app caret preservation.

Brand resonance uses the existing microphone samples. Unit checks verify bounded HUD scale/halo values and five menu-bar frames; fixtures compare silence, speech, decay and Reduce Motion. A physical spoken check remains required to prove that the logo follows real speech rhythm.

- Pipeline state rejects overlapping presses and invalid releases.
- Whisper path resolution respects environment overrides and reports missing files.
- Transcript normalization trims whitespace and rejects non-speech-only output.
- Clipboard restoration occurs only when its change token is still current.

All local test/build commands run through `~/.local/bin/mac-gate` and use `-derivedDataPath build`, so tests and manual launch share one signed app bundle.

Interface checks cover current-generation/deadline dismissal, obsolete callbacks, repeated hotkey-start failure feedback, menu/request/self-target guards with unconditional recording release, partial permission changes, Settings failure guidance, safe errors, negative display coordinates/fallback/disconnection, panel layout and accessible copy. These deterministic checks do not prove hardware/TCC/caret behavior.

The NSHostingView fixture test renders six states across four configurations (24 PNGs in `build/ui-fixtures`). Overrides reproduce appearance values without changing system settings. Images are fixtures, not actual dictation screenshots; progress stills do not prove movement. Idle is verified as absence, not a seventh HUD image.

## Local integration gates

1. Build the `.app` bundle and launch it via LaunchServices.
2. Confirm the process remains alive and the menu bar item appears.
3. Grant Microphone, Accessibility and Input Monitoring through explicit setup when needed; never reset real TCC automatically.
4. Run a real Portuguese dictation into TextEdit.
5. Repeat in a Chromium text field and verify clipboard restoration.

## CORE-001 evidence

Record date, commit (or source/binary fingerprints when HEAD does not exist), macOS version, chip, Whisper version/model, target app, spoken phrase, actual inserted text, release-to-insertion time, clipboard restoration, cleanup and pass/fail in `docs/testing/M0-EVIDENCE.md`.

Record native focus/click-through, ready-to-recording overlap, menu-open active release, permission request/recovery, keyboard/VoiceOver, long errors, display/Spaces/full-screen and supported appearance observations in `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Use PASS/FAIL/NOT RUN and identify evidence type. Connected screens alone do not establish display behavior; a CUA timeout is a tool limitation, not an app pass or defect.

Reuse an exact unchanged passing gate for prose-only changes. Code changes require the canonical mac-gate command. Quit the exact stable instance before testing if LaunchServices prevents test-runner launch; never create a second Derived Data identity to bypass it.

## Exit criteria

No known deterministic test failure; `.app` launches locally; `CORE-001` passes in TextEdit. Browser compatibility may remain a separately recorded M0 limitation only if TextEdit passes.
