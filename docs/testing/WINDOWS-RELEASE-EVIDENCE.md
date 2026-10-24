# Windows release — exact-artifact protocol and blank evidence

Status: pending. Windows download remains unavailable. No certificate, physical
host, successful release check or publication is established by this template.
Contract: [SPEC-023](../specs/23-windows-mvp.md).
Physical observations: [Windows MVP evidence](WINDOWS-MVP-EVIDENCE.md).

Preserve this blank template. Complete a versioned copy with actual observations,
immutable report references, SHA-256 and UTC times; all measured release fields
below start pending. No development fixture or `passed: true` assignment replaces
underlying observations. Report absent tools/hardware/signing/form authority as
blockers. Do not include private keys, credentials, transcripts or personal host IDs.

## Prerequisites and immutable source identity

| Field | Observed value |
| --- | --- |
| Dossier ID / UTC / verifier / owner-controlled physical build-host permission | pending |
| Physical Windows 11 build-host identity / Windows 10 QA installation | pending |
| Candidate version / platform / architecture / minimum OS predicates / CPU flags | pending |
| Clean checkout native source SHA / whisper.cpp submodule SHA | pending |
| Latest PR SHA / single PR URL / native-input tree comparison | pending |
| SDK / self-contained Desktop Runtime / C# / TFM / MSTest SDK | pending |
| Windows SDK / MSVC v143 compiler-linker / CMake / PowerShell 7 / Inno versions-hashes | pending |
| global.json / toolchain lock / package locks / preset hashes | pending |
| CMake cache / CPU flags / payload dependency and license inventory report hash | pending |
| Model name / byte length / SHA-256 / source | pending |
| Certificate availability / expected publisher / thumbprint / approved store-provider | pending |
| Dedicated CF Gauss Windows form ID / trusted origin / form URL / redirect URL | pending |
| Required name/email/WhatsApp server contract / evidence reference | pending |
| Missing prerequisite / owner / action / public-release blocker | pending |

Windows 10 Home/Pro 22H2 `10.0.19045` compatibility must not be labeled Microsoft
or .NET vendor support. Windows 11 Home/Pro 25H2 minimum `10.0.26200` and all CPU
features require physical proof. No recurrent paid Windows runner or automatic
certificate purchase is authorized. Inventory dependencies before first build;
unreviewed obsolete security patches block release.

## Build, signing and immutable artifact order

1. From a clean checkout of the candidate SHA, restore locked dependencies and
   run `pwsh -NoProfile -File Scripts/windows/preflight.ps1`. The script must
   select `Windows/` before dotnet calls and serialize with the host mutex.
   Save exact command, exit, log hash, toolchain and required test/CLI/corpus
   outcomes; missing tools/fixtures or skipped required tests fail.
2. Run `pwsh -NoProfile -File Scripts/windows/build-release.ps1 -Version <version>`.
   Publish untrimmed self-contained payload, inspect every dependency, sign
   application/native PEs using the approved publicly trusted publisher store
   or hardware provider; preserve and verify legitimate vendor signatures.
3. Package with Inno Setup 6.7.3 and signed uninstaller, then sign installer with
   SHA-256 and RFC 3161 timestamp. Verify every shipped PE, publisher/chain and
   timestamp (`signtool verify /pa /all /v <path>` and
   `Get-AuthenticodeSignature <path>`). A self-signed root is not public trust.
4. Hash only final signed bytes (`Get-FileHash -Algorithm SHA256 <artifact>`),
   write sidecar, scan installer and extracted payload, then run both physical
   OS install/offline/Notepad/Chrome/recovery/removal protocols. Save report hashes.
   Repackaging or signing after scan/QA invalidates all downstream proof.
5. Run `pwsh -NoProfile -File Scripts/windows/verify-release.ps1 -Artifact <path> -Evidence <json>`.
   Require matching signatures, hash, complete scans and physical reports. The
   scripts are implemented but remain unexecuted on Windows; no successful exit
   alone proves human observations or permits publication.

Expected generated directory: `artifacts/windows/<version>/<source-sha>/` with
`app/`, `Resenha-<version>-windows-x64-setup.exe`, matching `.sha256`,
`release-manifest.json` and `reports/`. Folder/internal ZIP is not the website
artifact. Manifest schema version 1 records build/payload/identity, signatures,
scan, physical QA and hosting. Manifest checksum is an external separate asset;
avoid self-hash or circular report/manifest hash dependencies.

| Field | Observed value |
| --- | --- |
| Preflight source SHA / command / exit / complete test count / no required skips | pending |
| Build command / source SHA / UTC / exit / report path and SHA-256 | pending |
| Payload file paths / sizes / hashes / inventory report hash | pending |
| Final installer filename / bytes / SHA-256 / sidecar path and value | pending |
| Per-PE signature Valid status / publisher / chain / digest / timestamp / report hash | pending |
| Installer and uninstaller signature / expected thumbprint / timestamp proof | pending |
| Manifest path / external checksum / schema/verifier report hash | pending |
| Final verifier command / exit / source and installer identity / report hash | pending |

## Defender installer and payload scans

Resolve the installed updated `MpCmdRun.exe`; use custom scans of the final
installer and its extracted payload with `-DisableRemediation`. Retain detailed
output and detection/remediation records, not just an exit code. Definitions must
be at most 24 hours old at scan time. Missing/old definitions, partial scan,
nonzero exit, any detection or remediation fails. A clean scan is not a universal
safety guarantee. Any changed package/payload bytes require rescanning and QA.

| Field | Observed value |
| --- | --- |
| Defender engine / platform / signature versions / definitions UTC and age | pending |
| Installer scan command / start-end UTC / exit / detailed report hash | pending |
| Installer hash matched / completed scan / detections / remediations | pending |
| Extracted payload inventory hash / extraction method / paths | pending |
| Payload scan command / start-end UTC / exit / detailed report hash | pending |
| Payload scan complete / detections / remediations | pending |

## Physical Windows 10 and Windows 11 acceptance

Use the [physical manual protocol](WINDOWS-MVP-EVIDENCE.md) against the final
signed installer on both physical OS targets. Record standard-user installation,
toolchain-free runtime, verified model, offline speech in PT-BR/EN/ES, Notepad
and Chrome fields, ABNT2/AltGr, clipboard/RAM recovery, named failures, ten cycles
per OS and clean removal. A VM/cross-build or asserted pass is insufficient.

| Field | Windows 10 observed value | Windows 11 observed value |
| --- | --- | --- |
| Physical report path / hash / UTC / verifier / host permission | pending | pending |
| Edition / release / full OS build / x64 / update state | pending | pending |
| CPU / AVX2-FMA-F16C-SSE4.2 / OS AVX state / RAM / microphone | pending | pending |
| Native source / app version / exact installer size-hash / model size-hash | pending | pending |
| Install / offline corpus / Notepad / Chrome / ABNT2-AltGr / focus race | pending | pending |
| Recovery matrix / ten cycles / owned-file cleanup / default remove data | pending | pending |
| Clean removal / optional retained data / sentinel preservation / reviewer | pending | pending |

## Authorized hosting, Mark of the Web and SmartScreen

Only with publication authority upload the exact tested final bytes to the
versioned GitHub Release. Expected destination pattern is
`https://github.com/luisroquette-labs/resenha/releases/download/windows-v<version>/Resenha-<version>-windows-x64-setup.exe`;
it is a naming contract, not an existing verified download. Keep artifact URL
pending until actual hosting. Download through a browser on clean physical
Windows, preserving Mark of the Web (`Zone.Identifier`), measure bytes/hash and
record actual publisher display/SmartScreen behavior. Signature validity does
not guarantee warning-free installation. Disclose reputation-only warnings;
detection or policy-enforced denial blocks distribution. Do not disable protection.

| Field | Observed value |
| --- | --- |
| Publication authority / release tag / immutable release and asset IDs | pending |
| Actual versioned URL / uploaded filename-size-hash / UTC | pending |
| Browser / physical OS / downloaded byte length and SHA-256 / UTC | pending |
| Final candidate versus hosted-byte comparison / immutable report path-hash | pending |
| Mark of the Web stream / SmartScreen result / publisher display / screenshots | pending |
| Reputation disclosure or detection/policy blocker | pending |
| Release manifest asset / external checksum / release verification records | pending |

## Dedicated form, site promotion and latest-SHA gates

Keep Windows planned/unavailable until every matching release group and verified
dedicated Windows form/redirect exists. The proposed
`node Scripts/windows/promote-release.mjs --manifest <path> --download-report <path>`
only derives an allowlisted projection; it does not upload or submit forms.
Retain underlying reports and their hashes. A new site SHA requires a recorded
comparison proving native source/pins/fixtures/build inputs unchanged; otherwise
rebuild and repeat every artifact gate.

Use synthetic intercepted form tests for blank/invalid name, email and WhatsApp,
foreign origin, wrong iframe source/form, malformed/forged/duplicate success,
closed/reopened stale dialog and platform switching. Freeze the platform and
trusted redirect per dialog. Never route Windows to DMG or macOS to EXE. Final
real form submission/hosted smoke needs applicable authority and must compare
downloaded hash. Public release URLs are not protected by this website lead gate.

| Field | Observed value |
| --- | --- |
| Provisioned Windows form/redirect / server-required fields / verified ownership | pending |
| Trusted origin/source/form/success event contract / intercepted tests | pending |
| Windows platform route / final authorized hosted form smoke / download hash | pending |
| Existing macOS route regression / no PII in analytics | pending |
| Invalid/missing/stale evidence fixtures keep Windows unavailable | pending |
| Promotion command / validated projection / input report hashes | pending |
| Latest PR SHA / actual canonical mac-gate command and results / workflow inventory | pending |
| Applicable remote checks / actual provider configuration / current-SHA preview | pending |
| Merge commit / main CI terminal state / actual deployment identity | pending |
| Final public availability / actual download hash / remaining blocker | pending |

Mac doc gate: `~/.local/bin/mac-gate node --test Scripts/windows-docs.test.mjs`.
Site/release-contract gate when implemented:
`~/.local/bin/mac-gate node --test Scripts/site.test.mjs Scripts/windows-release.test.mjs`.
No invented root npm preflight, local `next build`, bypass or green check for
an absent provider. No commit/push/publication is authorized by this template.

## CK and HR release ledger

Every gate is independent; scores cannot waive a MUST. Map to producers in
[SPEC-023](../specs/23-windows-mvp.md) and attach observed reports, not booleans.

| Gate | Result / evidence references / reviewer |
| --- | --- |
| CK-1 | pending |
| CK-2 | pending |
| CK-3 | pending |
| CK-4 | pending |
| CK-5 | pending |
| CK-6 | pending |
| CK-7 | pending |
| CK-8 | pending |
| CK-9 | pending |
| CK-10 | pending |
| HR-1 | pending |
| HR-2 | pending |
| HR-3 | pending |
| Dictation loop reliability rubric / supporting observations | pending |
| Local multilingual quality rubric / supporting observations | pending |
| Distribution readiness rubric / supporting observations | pending |
| Truthful site integration rubric / supporting observations | pending |
| Physical host prerequisite / owner / action | pending |
| Trusted certificate prerequisite / owner / action | pending |
| Dedicated form / hosting authority / provider gate prerequisite | pending |
| Release completion | pending |
