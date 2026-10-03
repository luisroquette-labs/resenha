---
name: whisperkey-macos-ui
description: Refine native macOS menu-bar utilities and nonactivating status panels with SwiftUI and AppKit, preserving keyboard focus, accessibility, and local-only dictation boundaries.
---

# Native macOS utility interface

Use this skill for visual hierarchy, component layout, state presentation, permission guidance, and accessibility in WhisperKey. Research verified on 2026-10-02. This is implementation guidance, not authorization to add product capabilities.

## Scope and invariants

Preserve the existing menu-bar utility and transient status-panel model. The target app and its editable field must remain focused throughout dictation. Keep microphone audio and transcripts local and ephemeral. This task does not change recognition, Portuguese/English handling, translation, model choice, formatting, text insertion, or language quality.

The current baseline explicitly excludes settings suites, history, login, analytics, waveform, duration display, and decorative animation. Visual polish alone does not authorize these features. If a future task changes a baseline restriction, update its specification explicitly before implementation.

Local contracts: `docs/specs/00-constitution.md`, `docs/specs/01-core-dictation.md`, `docs/specs/06-floating-ui.md`, `docs/specs/07-permissions.md`, `docs/specs/08-testing.md`, and `docs/architecture.md`. The planning task is named `refine-macos-interface.feature.md` and may move between `.specs/tasks/` status folders.

## Recommended approach

1. Reuse `FloatingPanelController`, `FloatingStatus`, `FloatingStatusView`, and the existing `NSStatusItem`/`NSMenu`. A polished menu and compact panel do not need a main window, navigation framework, design-system package, or third-party dependency. SwiftUI and AppKit already cover the needed surfaces; SwiftUI `MenuBarExtra` is available as an alternative, not a reason to migrate working AppKit code. [S7]
2. Keep the panel nonactivating and noninteractive. Preserve `.nonactivatingPanel`, `.borderless`, and mouse pass-through. Do not add a clickable repair button to a panel that ignores mouse events; place deliberate actions in the native menu. The style-mask contract prevents app activation; actual cross-app focus preservation still requires a manual check. [S5]
3. Give every state a concise label plus a distinct symbol or native progress indicator. Color reinforces meaning rather than carrying it alone. Keep the symbol column and text alignment stable across states. Use `ProgressView` for unmeasured work, never an invented percentage. [S1, S3]
4. Use system typography, semantic foreground colors, SF Symbols, and the existing standard material. Test on light, dark, and busy backgrounds. Respect Increase Contrast and Reduce Transparency with an opaque semantic fallback if the chosen material does not remain readable. Do not add Liquid Glass or raise the macOS 14 deployment target just to refresh the appearance. [S1, S2, S4]
5. Make permission problems understandable and recoverable from the menu: name the missing permission, explain its purpose, and offer an explicit action. Mirror the real permission state; never imply readiness from appearance alone. Willow is useful only for its documented cursor → hold shortcut → release workflow and concise permission explanations, not its identity, paid account flow, or output promises. [S8, S9]

## State presentation

This mapping is a recommendation for presentation, not a new pipeline or persistence layer. Reuse the existing state source; avoid independent UI booleans that can disagree with it.

| Existing state | Panel presentation | Menu/accessibility treatment |
|---|---|---|
| Idle / ready | Hidden during normal idle; brief readiness confirmation only when requested or already provided by lifecycle | Product name, readiness, and the actual Right Option instruction |
| Listening | Microphone symbol, recording color, concise listening text | Textual recording state; no color-only signal |
| Transcribing | Native indeterminate spinner and clear operation text | Equivalent understandable status |
| Inserting | Same indicator footprint and insertion text | Do not claim success until the existing pipeline reports it |
| Failure / missing permission | Error symbol plus short actionable explanation | Full explanation remains discoverable while the underlying problem exists; explicit permission controls |

Do not add a success animation, waveform, timer, or transcript preview to make a state more visible. A status phrase beside a spinner communicates which pipeline step is running; it does not describe the spinner itself. [S3]

## Layout and native integration

The current panel is 280 × 64 pt with two text lines, hosted through `NSHostingView`; these are existing implementation values, not Apple requirements. Validate the longest real permission and error strings before choosing revised dimensions. Prefer bounded wrapping or content-driven height over truncating recovery instructions. Keep text leading-aligned, use a stable icon/progress slot, and keep spacing/radius decisions local until multiple components actually need shared values.

Position within a freshly obtained `NSScreen.visibleFrame`, which excludes areas reserved by Dock and menu bar. Do not cache screen geometry. Define and verify which screen owns the panel; `NSScreen.main` must not be assumed to mean the external application's focused display. Check negative display coordinates, Dock placement, display disconnection, full screen, and Spaces without increasing the panel to an intrusive window level. [S6]

Keep all UI mutations on the main actor. Reusing the same panel avoids focus churn and unnecessary window creation. If transient-hide behavior changes, cancel or supersede an older hide request so a previous readiness timer cannot hide a newer recording state. This is a UI-lifecycle concern; it does not authorize modifying transcription behavior.

## Accessibility and failure modes

| Pitfall | Required response |
|---|---|
| Recording/error distinguished only by red | Pair color with text and different symbols; verify in grayscale. [S1] |
| Status is visible but not discoverable by assistive technology | Supply meaningful accessibility labels, avoid duplicate decorative-symbol announcements, verify with VoiceOver and Accessibility Inspector. Do not assume a nonactivating overlay is announced automatically. [S1] |
| Transparency makes text disappear over another app | Use semantic colors and test Reduce Transparency / Increase Contrast; provide a native opaque fallback where necessary. [S2, S4] |
| Permission error disappears before it can be read | Keep recovery reachable through the menu while the permission remains missing; transient panel timing and durable problem state are different concerns. |
| Visual refactor steals focus or leaves stale timers | Preserve AppKit window behavior; verify active-app identity during every state and rapid consecutive uses, including a ready message followed immediately by recording. [S5] |

If optional motion is approved in a later scope, honor Reduce Motion and avoid perpetual pulses or bouncing effects. No decorative motion is required here. [S1]

## Verification

1. Render or capture every existing status, including longest real error copy, in light/dark appearances and accessibility contrast/transparency settings. Record the app build and macOS version; do not treat mockups as runtime evidence.
2. Inspect menu keyboard navigation, accessible names, contrast, and VoiceOver discovery. Reading order should match visual order. Document any announcement limitation instead of claiming universal accessibility from labels alone.
3. In TextEdit and a browser field, show the panel through the existing dictation sequence and verify the target app stays active, the cursor remains usable, and the panel disappears correctly. Add a focused regression check for any changed nontrivial status mapping, placement math, or timer behavior.
4. Repeat placement checks across available screens, Spaces, full screen, Dock positions, and scaling. If hardware is unavailable, identify that limitation explicitly rather than recording a pass.
5. Run the repository's existing native test gate through `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. This skill does not require executing tests for documentation-only research. Preserve the existing signing/bundle identity to avoid unnecessary permission resets.

## Primary references

All references are Apple documentation or official Willow pages. Search-indexed official Apple text was used where the canonical page returned only a JavaScript shell; no third-party HIG mirror was used. Recommendations above that go beyond cited platform guidance are project design judgments.

| ID | Source | Application |
|---|---|---|
| S1 | [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Redundant state cues, legibility, VoiceOver, Reduce Motion |
| S2 | [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | Semantic materials, background separation, restrained glass, contrast |
| S3 | [Apple HIG: Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) | Honest indeterminate progress and stable indicator placement |
| S4 | [Apple HIG: Color](https://developer.apple.com/design/human-interface-guidelines/color) | System colors across light, dark, and increased contrast |
| S5 | [AppKit: nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) | Panel does not activate its owning app |
| S6 | [AppKit: NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe) | Fresh usable display bounds, including Dock/menu-bar exclusions |
| S7 | [Apple WWDC22: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10052/) | Native menu-bar scene capability; migration is optional |
| S8 | [Willow official product site](https://willowvoice.com/) | Cursor, hold shortcut, release interaction only; marketing claims are not benchmarks |
| S9 | [Willow official installation and permissions guide](https://help.willowvoice.com/en/articles/10876111-install-and-setup-willow-voice-mac-windows) | Explain Microphone/Accessibility permissions and explicit recovery routes |
