# Release boundaries for platform downloads and validation

Status: accepted

## Platform downloads

The Windows download remains unavailable until a separate CF Gauss form has been provisioned and verified. A release record is accepted only for authored HTTPS destinations. Encoded separators and dot segments are rejected before URL matching so their interpretation cannot change the destination.

## Signed macOS package

The release app must contain exactly `com.apple.security.device.audio-input=true` in its entitlements. Hardened Runtime needs Audio Input even when macOS has already recorded microphone consent. Equality also rejects missing or additional privileges.

## Windows release runner

Native release validation uses `windows-2022` because the committed Windows toolchain is v143. The `windows-2025` image moved to Visual Studio 2026, so changing runners requires validating the native build first.
