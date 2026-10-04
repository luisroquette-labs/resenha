# SPEC-007 — Permissions

Status: automated control flow implemented; native TCC validation pending

## Permission matrix

| Permission | Why | API |
|---|---|---|
| Microphone | capture speech | `AVCaptureDevice.authorizationStatus/requestAccess` |
| Input Monitoring | receive the configured shortcut outside Resenha | `CGPreflightListenEventAccess/CGRequestListenEventAccess` |
| Accessibility | Developer ID only: reactivate the target and post one paste command | `AXIsProcessTrusted/AXIsProcessTrustedWithOptions` |

## Requirements

- Developer ID explains and gates on all three permissions.
- Mac App Store explains and gates only on Microphone and Input Monitoring; it must never request Accessibility.
- Prompt only after explicit user action; polling and checks never open System Settings.
- Open the exact privacy pane for each missing permission.
- Keep the hotkey stopped until every permission required by the active channel is granted.
- Recheck every second and whenever the app becomes active.
- Permission loss during recording stops safely; already-running transcription is preserved.

## Acceptance

- Automated snapshots cover channel-specific grant combinations.
- In Developer ID, missing Accessibility is named and links to `Privacy_Accessibility`.
- In App Store, Accessibility is absent from onboarding and readiness.
- Restoring all permissions starts monitoring without replaying a held press.
- Real grant, revocation and recovery are recorded without resetting TCC to manufacture evidence.
