# SPEC-005 — Text delivery and recovery

Status: automated boundary implemented; physical matrix pending

## Goal

Insert the completed transcription at the cursor of the application that was active when dictation began, while keeping a recovery copy on the clipboard.

## Shared method

Every successful non-empty transcript is staged on the general pasteboard and
kept there for manual recovery. Delivery then follows the build channel.

## Developer ID method

1. Capture the frontmost application when the hotkey is pressed.
2. Stage the final non-empty transcript on the general pasteboard.
3. Reactivate the captured application and wait up to 400 ms for it to become frontmost.
4. Abort if the target disappeared or the clipboard changed.
5. Post one synthetic `Command-V` through `CGEvent`.

## Requirements

- Accessibility must be trusted before insertion.
- Never paste into an application other than the captured target.
- Never overwrite a clipboard change made after staging.
- Keep the successful transcript on the clipboard and optional ten-item history.
- Treat secure fields or hosts that reject synthetic paste as a bounded failure with manual `Command-V` recovery.
- The passive HUD must not become the insertion target.

## Mac App Store method

1. AppKit opens `Ditar com Resenha` with a real Service pasteboard request.
2. Resenha records until the exact initiating key is released.
3. The completed transcript is returned through `NSPerformService` completion.
4. The calling editor performs the insertion; Resenha does not post input events.

The Store build must remain sandboxed and must not request Accessibility.

## Acceptance

- Channel selection, target identity and clipboard guards are deterministic unit tests.
- A real TextEdit dictation inserts once at the cursor.
- Browser and terminal fields are recorded separately in the physical matrix.
