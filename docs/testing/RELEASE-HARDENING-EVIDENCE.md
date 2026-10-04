# Resenha 1.0 release-hardening evidence

Status: ready for source commit. Archive/package validation is deliberately blocked
until the orchestrator creates the real source commit; physical target-app gates and
remote App Store actions remain explicitly blocked.

## Candidate identity

| Field | Evidence |
|---|---|
| Source branch | `fix/release-hardening-loop` |
| Source baseline | `ae34e157eca5c9df51555dcc5a84916562ddd338` |
| Final commit | PENDING — orchestration commit after Phase 5 review |
| Version / build | `1.0.0 (2)` derived from `project.yml` and archive Info.plist |
| Archive | BLOCKED — must be rebuilt by `Scripts/archive-release-candidate.sh` after source commit |
| Executable SHA-256 | PENDING — derived only from the provenance-bound archive |
| Signing | PENDING new archive; distribution export not performed |

The old `/private/tmp/Resenha-1.0.0-b2.xcarchive` lacks `ResenhaSourceCommit` and the
validator rejects it. After the source commit, run `Scripts/prepare-release-candidate.sh`,
then `Scripts/archive-release-candidate.sh`; the package validator requires the same
real 40-character commit in Git, release state and archive Info.plist, with release
sources unchanged from that commit.

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
   sources and a nonexistent commit. Release-state validation rejects the pending null
   SHA; package validation rejects the old archive without provenance.
5. Archive/package positive validation: PENDING source commit by design. No stale
   archive is accepted as release evidence.

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
  `NOT RUN` on the future provenance-bound archive. See `RELEASE-PHYSICAL-QA.md`; tests do not
  promote those rows to PASS.
- `AppStore/release-state.json` retains the observed build 1 state
  `WAITING_FOR_REVIEW` / `AFTER_APPROVAL`; it was not re-read or mutated in Phase 5.
- Owner approval is required before withdrawing/replacing build 1 or changing release
  mode. Impact: withdrawal stops the active review; replacement uploads a new binary;
  manual release prevents automatic publication after approval.
- No upload, submit, withdrawal, auto-release change, GitHub publication or paid media
  API call occurred in this phase.
