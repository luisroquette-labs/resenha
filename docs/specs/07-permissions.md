# SPEC-007 — Permissions

Status: automated control flow implemented; native TCC validation pending

## Required permissions

| Permission | Why | API |
|---|---|---|
| Microphone | capture speech | `AVCaptureDevice.authorizationStatus/requestAccess` |
| Input Monitoring | receive the configured shortcut outside Resenha | `CGPreflightListenEventAccess/CGRequestListenEventAccess` |
| Accessibility | reactivate the target and post one paste command | `AXIsProcessTrusted/AXIsProcessTrustedWithOptions` |

## Requirements

- Explain all three permissions in onboarding and expose their individual status in the menu.
- Prompt only after explicit user action; polling and checks never open System Settings.
- Open the exact privacy pane for each missing permission.
- Keep the hotkey stopped until all three permissions are granted.
- Recheck every second and whenever the app becomes active.
- Permission loss during recording stops safely; already-running transcription is preserved.

## Acceptance

- Automated snapshots cover all eight grant combinations.
- Missing Accessibility is named and links to `Privacy_Accessibility`.
- Restoring all permissions starts monitoring without replaying a held press.
- Real grant, revocation and recovery are recorded without resetting TCC to manufacture evidence.
