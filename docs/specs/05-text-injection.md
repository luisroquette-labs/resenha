# SPEC-005 — Text return and recovery

Status: sandboxed Service implemented; physical compatibility matrix pending

## Goal

Return the completed transcription to the editable field that invoked Resenha, while always leaving a recovery copy available through Command-V.

## Store method

1. The focused application invokes the `Ditar com Resenha` macOS Service.
2. `ResenhaServiceProvider` keeps that Services request open while recording and inference run.
3. On success, `TextInjector.stage` writes the transcript to the general pasteboard.
4. The provider declares UTF-8 plain text plus the legacy string pasteboard type on the Service pasteboard.
5. The requesting application receives and inserts that returned string through its responder chain.

No application activation, `AXUIElement`, synthetic Command-V or `CGEvent.post` is permitted.

## Requirements

- Reject blank text.
- Allow only one active Service request.
- Return no placeholder after cancellation, failure or the ten-minute timeout.
- Keep every successful transcript on the general pasteboard for manual recovery.
- Optionally add it to the bounded ten-item local history before finishing the request.
- Preserve the active application and selection; Resenha's HUD is passive.

## Compatibility ceiling

Insertion depends on the host application's public Services responder support. Unsupported or secure fields may not accept the returned text. In those cases, the completed transcript remains available through Command-V and the UI reports a specific failure when detectable.

## Acceptance

- TextEdit inserts the returned text at the selection.
- Supported browser and terminal fields pass the documented physical matrix.
- An unsupported host never loses a completed transcript.
- Binary scanning finds no Accessibility or post-event insertion symbol.
