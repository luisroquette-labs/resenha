# SPEC-024 — Windows Store MSIX distribution

Status: implementation in progress. Partner Center company verification and
product reservation passed; exact candidate build and Store submission remain.

Owner decision (2026-10-05): publish from a Company developer account whose
verified legal entity is `CF GAUSS SERVICOS LTDA`. The manifest publisher and
publisher display name come verbatim from the verified Partner Center product.

Reserved product (2026-10-05): Store ID `9P4M40MZH627`, identity
`CFGaussServiosLtda.Resenha`, publisher
`CN=423DACA4-6A0B-4E80-BFA4-9BF1E35E6AC1` and display publisher `CF Gauss`.
`Windows/Store/identity.json` is the checked-in identity contract.

## Problem

The website beta is an unsigned Inno Setup EXE. Microsoft Defender SmartScreen
correctly warns before it runs, which is unacceptable as the primary onboarding
path for non-technical users. Authenticode signing improves a direct download but
does not guarantee that a new binary avoids reputation warnings.

## Decision

The Microsoft Store MSIX channel is the primary Windows consumer distribution.
Microsoft signs an accepted MSIX, provides the trusted install surface and owns
updates. The website will link to the Store only after the exact submitted package
is certified and publicly available. The explicit unsigned EXE remains a temporary
owner-authorized physical-test channel and is never represented as the final app.

## Goals

1. Package the existing self-contained x64 WPF payload, target broker, local
   whisper.cpp CLI, notices and visual assets into one deterministic MSIX.
2. Use the exact package identity and publisher values copied from Partner Center;
   never guess, normalize or commit credentials.
3. Preserve local-only transcription, explicit model download and the existing
   Windows 10 22H2 / Windows 11 x64 runtime requirements.
4. Produce an unsigned Store candidate because Microsoft signs an accepted MSIX;
   separately label synthetic CI packages as never submit/install.
5. Keep direct EXE and Store evidence independent so one channel cannot promote
   the other accidentally.
6. Prepare complete pt-BR, en-US and es-ES listing copy, five real screenshot
   scenarios, certification notes and the restricted capability justification.

## Non-goals

- No paid certificate purchase, Azure Artifact Signing enrollment or Defender
  bypass in this milestone.
- No backend, account, billing, AI rewrite or cloud transcription.
- No public Store claim before certification and a real Store install.
- No self-signed package offered to end users.

## Package contract

- Format: `.msix`, x64, `Windows.Desktop`, full-trust desktop application.
- Entry point: `Resenha.exe` with `Windows.FullTrustApplication`.
- Capabilities: `runFullTrust`, microphone and internet client. Internet is used
  only for the explicit first model download.
- Minimum OS: `10.0.19045.0`; maximum tested declaration: `10.0.26200.0`.
- Version: four numeric components; revision is `0` for Store ownership.
- Required assets: 44, 50 and 150 pixel logos plus 200% variants.
- Required payload: `Resenha.exe`, `Resenha.TargetBroker.exe`,
  `native/whisper-cli.exe`, runtime dependencies and license notices.
- Package output is immutable and carries a SHA-256 sidecar and JSON build record.

## Identity boundary

`Identity/Name`, `Identity/Publisher` and `PublisherDisplayName` are supplied from
the reserved Partner Center product. Candidate mode fails closed if any value is
missing, synthetic, an example or inconsistent. CI may use an explicitly named
synthetic identity only to prove MakeAppx structure; its filename contains
`SYNTHETIC-NOT-FOR-SUBMISSION`, is not uploaded and creates no release evidence.
The exact non-secret values are retained in `Windows/Store/identity.json`; every
candidate build must match that file byte-for-byte.

## State machine

```text
identity pending
  -> identity reserved
  -> exact candidate built
  -> package validation passed
  -> Partner Center submitted
  -> certification passed
  -> Store install verified
  -> website Windows channel activated
```

Any failed or missing gate returns to the immediately preceding state. A Store
acknowledgement is not certification, and certification is not physical workflow
acceptance.

## Acceptance

- `MSIX-001`: MakeAppx packs and unpacks the exact synthetic payload on Windows.
- `MSIX-002`: manifest declares desktop full trust, microphone, x64 and exact OS
  bounds; all tokens are resolved.
- `MSIX-003`: missing Partner Center identity blocks candidate creation.
- `MSIX-004`: required binaries/assets/notices exist after package extraction.
- `MSIX-005`: package and sidecar hashes match retained bytes.
- `MSIX-006`: production website remains explicit Beta until Store certification.
- `MSIX-007`: a clean physical Windows Store install completes dictation and
  uninstall without SmartScreen or orphaned owned session data.
- `MSIX-008`: the candidate workflow requires all exact Partner Center fields,
  retains the package privately for one day and never creates a GitHub Release.
- `MSIX-009`: localized Store copy respects Microsoft field limits and screenshots
  remain pending until captured from the physical Windows build.
