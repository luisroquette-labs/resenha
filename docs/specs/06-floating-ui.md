# SPEC-006 — Floating UI

Status: M0 implementation refined; native integration acceptance pending

## Goal

Communicate state without stealing focus from the target application.

## Form

- One borderless, non-activating, floating panel, centered near the bottom of the target application's display.
- SwiftUI content hosted in AppKit.
- Compact status only; ordinary idle remains hidden. No persistent primary window or focusable HUD controls.
- The panel ignores mouse events and is visible across Spaces as appropriate for a transient utility.

## Requirements

- Showing the panel must not make WhisperKey the active app.
- Recording state has a steady mist-green recording indicator, an elapsed timer and a live microphone-level waveform.
- Processing state has an indeterminate progress indicator.
- Failure remains visible for approximately 2 seconds, then returns to idle.
- Owner-approved item-1 refinement (2026-10-02): a recording-only level waveform and elapsed timer are in scope. Decorative/random animation, settings, retained recordings and transcript history remain excluded.

## Acceptance

The focused text field remains focused while every pipeline status is displayed.

## Delivered state contract

| Condition | Title / secondary copy | Indicator | Lifetime |
|---|---|---|---|
| Idle | None | Menu waveform | Hidden |
| Ready confirmation | `Pronto` / `Segure seu atalho para ditar` | waveform | Approximately 2 seconds on startup or explicit Check |
| Recording | `Listening` and monospaced `mm:ss`; release instruction remains in menu/accessibility status | Steady mist-green dot and 48 microphone-driven rounded bars | Entire recording interval |
| Transcribing | `Transcribing…` | Native indeterminate progress | Entire transcription interval |
| Inserting | `Inserting…` | Same progress footprint | Until actual insertion completion |
| Failure | Concise cause / `Open the WhisperKey menu for help` | Warning symbol | Approximately 2 seconds; recovery stays in menu |

Ready/processing states use 280 × 64 points, a 20-point indicator slot, 12-point gap, 18-point horizontal inset and 4-point outer margin. Titles use 14-point semibold system font; secondary copy uses 12-point regular system font with a 3-point gap. The background uses an 18-point radius, regularMaterial and semantic colors. One-line processing states are vertically centered. Listening alone uses a horizontally arranged 340 × 72 capsule, clamped by the same fresh visible-frame rules.

Failure titles wrap up to two lines, with measured height bounded to 104 points and width to 360 points or usable screen width. Known errors map to concise causes. Complete attempted runtime/model paths, exit code and guidance remain in the native **Status details** submenu; arbitrary stderr/transcript content is excluded.

Reduce Transparency uses opaque windowBackgroundColor. Increase Contrast adds a one-point semantic outline and promotes secondary text to primary. No decorative motion/percentage is added. The accessible status combines title/instruction and hides decorative symbols from duplicate reading. Actual VoiceOver discovery of this passive overlay remains a validation requirement.

## Recording meter — implemented, native validation pending

Use the existing AVAudioRecorder's metering, not another capture pipeline: enable metering, call updateMeters and read averagePower(forChannel: 0) at 20 Hz while recording. Normalize finite dB readings from -60…0 to 0…1; nonfinite/below-floor readings yield silence. Keep the capture format, start/stop behavior, model and transcript path unchanged.

The waveform contains exactly 48 thin, evenly spaced, round-ended vertical bars, centered vertically, with an approximately 3-point silence floor and 32-point maximum height. Oldest readings are on the left; new readings arrive on the right, retaining only 2.4 seconds of scalar levels. Bounded attack/decay smooths changes without fabricated/random motion. A steady mist-green dot and `Listening` label sit beside the waveform; elapsed `mm:ss` uses monospaced system digits and a monotonic clock starting with this recording, resetting on stop/failure/cancel/new attempt. Timer sampling stops with recorder cleanup; meter history stays memory-only and is cleared when listening ends.

Reduce Motion replaces shifting history with a stationary current-level display and disables interpolation. Native contrast/transparency and light/dark behavior remain supported. The waveform and per-sample updates are decorative accessibility children; the understandable Listening/release status remains stable, with no forced VoiceOver announcements or per-frame accessible-label updates. No WhatsApp logo, colors, branded control or product behavior is copied.

Acceptance: deterministic injected clock/level checks cover normalization, fixed history length/order, silence, bounded smoothing/decay, timer rollover/reset, stopped-state rejection and reduced-motion rendering. Labeled fixtures cover silence, speech and decay in every supported appearance. A physical speaking-versus-silence check must confirm real levels, elapsed time, release cleanup and preserved caret; synthetic fixtures cannot close that check or CORE-001.

## Brand resonance

While listening, `ResenhaMark` responds to the same smoothed microphone level used by the waveform. The foreground mark scales from 84% to 116% and a faint duplicate expands to 152% at 30% opacity, producing a visible resonance without random or autonomous animation. Silence returns to the resting mark; loud speech never exceeds the HUD bounds.

The menu-bar mark uses five size steps from 12 to 18 pt driven by the live level. It returns to the full, static brand mark outside recording. No layout-width change, color flash or VoiceOver announcement is allowed. Reduce Motion keeps the HUD mark fixed and removes its halo; the waveform remains the existing stationary real-level display.

Acceptance: deterministic tests cover nonfinite input, clamping, monotonic scale/opacity, Reduce Motion and the finite menu-frame set. Native fixtures must show distinct silence/speech states without changing the HUD footprint.

## Placement and lifecycle

Read the original target's focused-window frame using already-granted Accessibility, convert AX coordinates to AppKit and choose the largest display intersection with center tie-breaking. Retain that display through the session. If geometry is unavailable, use the last valid target display, then main/first; exact placement cannot be promised without usable AX geometry. Standalone feedback uses the current external app or latest known external target with the same fallback. Pointer position does not select the display.

Refresh visibleFrame on presentation/display changes; recover from disconnected displays. Center horizontally, prefer visibleFrame.minY + 88 and clamp every edge with a 12-point margin, including negative coordinates. Preserve click-through, hidesOnDeactivate=false, canJoinAllSpaces/fullScreenAuxiliary and one physical panel.

The panel solely owns dismissal: replacement/hide cancels the prior task and invalidates its generation/deadline. Delayed hide applies only to the current generation. Failed → idle uses that completion. Check during activity updates the menu without replacing or queuing HUD feedback.

The coordinator owns real activity; the menu observes it. New starts are rejected while menus/submenus or a permission request are active, or the target is WhisperKey. Active recording release still reaches the coordinator. A rejected held press never replays; require a fresh release/press.

Fixture/automated evidence and actual caret, click-through, full-screen and appearance observations are separated in [UI evidence](../testing/UI-REFINEMENT-EVIDENCE.md). No recognition, translation, model, history or retention change belongs to this refinement; human CORE-001 remains required.
