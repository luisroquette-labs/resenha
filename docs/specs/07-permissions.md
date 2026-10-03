# SPEC-007 — Permissions

Status: implemented presentation; native TCC recovery validation pending

## Required permissions

| Permission | Why | API |
|---|---|---|
| Microphone | capture speech | `AVCaptureDevice.authorizationStatus/requestAccess` |
| Accessibility | insert text into the original app and read focused-window geometry | `AXIsProcessTrustedWithOptions` |
| Input Monitoring | receive the configured hotkey down/up outside Resenha | `CGPreflightListenEventAccess/CGRequestListenEventAccess` |

## Requirements

- Include `NSMicrophoneUsageDescription` in the app bundle.
- Explain the purpose before or alongside the system prompt.
- Never loop system prompts.
- If denied, keep the app running with a direct status explaining the missing permission.
- Recheck permissions when the app becomes active.
- Recheck permissions every second while the app is running because a menu-bar utility may not become active after System Settings closes.
- Provide an explicit control to open the relevant System Settings pane; never navigate there silently.

## M0 onboarding

The first incomplete launch presents one native onboarding window explaining all three permissions. Closing it records that it was presented; it does not loop on later launches. The menu remains the durable recovery path: it exposes current activity, the configured hotkey, permission activation/checking, named System Settings destinations and **Encerrar Resenha** (Command-Q). Failed Settings navigation retains manual guidance in the menu.

Only explicit Enable requests existing rights; the microphone prompt runs only from notDetermined. Check, one-second polling and reactivation inspect without prompting or opening Settings. Partial snapshot changes update menu/icon/tooltip while monitoring is stopped. No unchanged poll forces an announcement.

Real activity takes precedence: Listening/Transcribing/Inserting remain honest, while tooltip/accessibility text includes all blockers. Idle missing access uses a warning waveform icon; recording uses a microphone. A two-second blocked HUD appears on explicit idle Check; ready feedback is never queued during activity.

Menu/request interaction rejects new starts but forwards an active release. Permission loss stops monitoring and, during recording only, invokes recorder cleanup through the coordinator failure path. It preserves an already-transcribing/inserting phase. Restored rights allow later recordings without replaying a held press.

## Acceptance

On a clean permission state, the microphone prompt contains the product explanation. Denial produces no recording attempt. After Accessibility is granted, hotkey monitoring starts without relaunch where macOS permits it; otherwise the app asks for one relaunch.

Do not reset real TCC to manufacture evidence. Automated snapshots/actions verify control flow; actual Settings destinations, request completion and revocation/recovery remain separately observed checks in [UI evidence](../testing/UI-REFINEMENT-EVIDENCE.md).
