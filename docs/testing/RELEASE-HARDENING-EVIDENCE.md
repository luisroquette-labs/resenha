# Resenha 1.0 release-hardening evidence

Status: READY FOR NEW SOURCE COMMIT. The previous provenance-bound archive is retained
as historical evidence but is superseded by release-contract/script changes. Physical
target-app gates and remote App Store actions remain explicitly blocked.

## Candidate identity

| Field | Evidence |
|---|---|
| Source branch | `fix/release-hardening-loop` |
| Source baseline | `ae34e157eca5c9df51555dcc5a84916562ddd338` |
| Final commit | PENDING — new commit required after provenance review iteration 2 |
| Version / build | `1.0.0 (2)` derived from `project.yml` and archive Info.plist |
| Archive | SUPERSEDED — rebuild `1.0.0 (2)` after the new source commit |
| Archive tree SHA-256 | `0bcd1aa641c041ff170a70e486d7a093ac2a9c15b322a0ee8c132607cd3dee17` over 15 sorted file hashes and relative paths |
| Executable SHA-256 | `f183195d35d1ec05a580e65b4e10a773aa68ffc68409382b1b631455025c229e` |
| App Info.plist SHA-256 | `1938616959de23e1fd213d38d64bd3fd3d740d18a79d0d8e0f22015f86c23cd8` |
| Archive Info.plist SHA-256 | `4ad63f8bef12f18d310281ffffaa55b510d30e67b3e93866d59186082793ae5e` |
| Signing | Apple Development, team `S3YCFYY8SC`; strict verification passed; distribution export not performed |

The historical archive embeds `ResenhaSourceCommit =
9dc4aa1b3877c06569bb8b2635c5107c41dc1c15`. The package validator requires that same
real commit in Git, release state and archive Info.plist, with release sources unchanged
from it. Review iteration 2 expanded the audited relevant paths, so a new source commit
and archive are required; neither historical archive is an upload candidate.

## Automated gates — 2026-10-03 BRT

1. Swift: `mac-gate xcodebuild test` passed **96/96**, zero failures/skips, including
   the real local Whisper model. XCResult:
   `/tmp/resenha-phase5-review1-final-derived/Logs/Test/Test-WhisperKey-2026.10.03_21-48-52--0300.xcresult`.
2. Static analysis: Release `xcodebuild analyze` passed with derived data at
   `/tmp/resenha-phase5-review1-analyze`.
3. Site: `mac-gate node Scripts/site.test.mjs` passed **38/38**. It parses canonical,
   Open Graph, Twitter Card and `SoftwareApplication`, checks six lazy images and
   verifies media dimensions, 30 fps, absence of audio, continuous motion and six
   visibly distinct semantic settings states.
4. Source contract: its self-test accepted a real commit and rejected dirty relevant
   sources and a nonexistent commit. The release state and archive both identify the
   exact current source commit.
5. Archive/package: `ARCHIVE SUCCEEDED`; positive release/package validators passed.
   Negative fixtures rejected version `99.99.99`, build `3` and a zero source commit.
   The app is arm64, strictly signed, and contains exactly the three allowed entitlements:
   App Sandbox, microphone input and network client.
6. Bundle inspection: privacy manifest plus all three notice/license files are present;
   `WHISPER_MODEL_PATH` is absent from the Release binary. Privacy manifest SHA-256 is
   `5c20dbcb4ab17c390d6c89c0d6c7f7a274f377c2304159f01bb2ebb88a2cd069`.

## Review iteration 2 gates — 2026-10-03 BRT

1. Source-contract self-test passed: a metadata/evidence-only descendant is accepted;
   committed or working-tree changes to app source, release scripts, configuration,
   site media and App Store media are rejected. Nonexistent commits are rejected.
   `docs/**`, `.specs/**`, README files and `AppStore/release-state.json` are explicitly
   non-binary evidence/metadata exclusions.
2. No-argument `Scripts/build-site-media.sh` regenerated both 1440×900, 8-second,
   240-frame videos from `$TMPDIR/ResenhaTests/ui-fixtures`; no production-container
   fallback is used. No-argument `Scripts/export-app-store-screenshots.sh` regenerated
   all ten 2880×1800 screenshots from that same deterministic fixture output.
3. `mac-gate node Scripts/site.test.mjs` passed 38/38. Swift passed 96/96 at
   `/tmp/resenha-phase5-review2-derived/Logs/Test/Test-WhisperKey-2026.10.03_22-18-19--0300.xcresult`.
4. Automated negative-validator mode executed and rejected version `99.99.99`, build
   `3` and a zero source commit. Positive package validation waits for the new archive.

## Product and media

| Asset | Properties | SHA-256 |
|---|---|---|
| `resenha-flow.mp4` | 1440×900, 8.0 s, 240 frames, 30 fps, no audio, 32/32 distinct 4-fps samples | `0d321d68de44599bb32803013c1076f20c3386b0e5e6764e6774a38ff4a44ce4` |
| `resenha-settings.mp4` | 1440×900, 8.0 s, 240 frames, 30 fps, no audio; native navigation/search/favorite states | `0106ca21684830cd5fbbd6d59f1694bb571416fe48e8dade511df1ab1410595c` |
| `resenha-og.png` | 1200×630, first-party social card | `f11e420ca4394f79220834b9b07587e20258356d1cb263d2e1307f1165bc5117` |

The flow demo uses native HUD fixtures on a disclosed editorial writing surface. It
shows a moving cursor, held `Shift + Command + E`, responsive waveform states,
processing and progressive insertion. It is not labeled as a physical microphone or
cross-app recording. Screenshot 05 now leads with clipboard recovery/history opt-in;
none of the ten App Store screenshots foreground bodily/humor sounds.

## Privacy and product defaults

- Clean `UserDefaults` starts transcript history disabled; an existing explicit value
  is preserved. If the old preference is absent, the one-time migration removes the
  canonical history and quarantines before marking completion; failure remains pending
  for retry and completion is idempotent. Every transcript still enters the clipboard.
- Sound search is local and matches name/category/number; validated favorite IDs persist
  locally. No account, telemetry, backend or paid API was added.
- The website now has the declared GitHub Pages canonical origin and makes no live
  App Store/download claim while those release slots remain unavailable.

## Physical and external blockers

- TextEdit, Chromium, Terminal, VoiceOver, multiple displays/Spaces and macOS 14 remain
  `NOT RUN` on this provenance-bound archive. See `RELEASE-PHYSICAL-QA.md`; tests do not
  promote those rows to PASS.
- `AppStore/release-state.json` retains the observed remote build 1 state
  `WAITING_FOR_REVIEW` / `AFTER_APPROVAL`; only the local candidate `sourceCommit` was
  filled after the source commit. No remote state was re-read or mutated.
- Owner approval is required before withdrawing/replacing build 1 or changing release
  mode. Impact: withdrawal stops the active review; replacement uploads a new binary;
  manual release prevents automatic publication after approval.
- No upload, submit, withdrawal, auto-release change, GitHub publication or paid media
  API call occurred in this phase.
