# Synthetic Windows release contract fixtures

Every file here is **SYNTHETIC TEST DATA, NOT RELEASE EVIDENCE**. The `MZ` strings
are not executable binaries. No build, certificate, malware scan, microphone,
physical machine or browser download was observed. Version `0.0.0`, fake
publisher/host/scanner values and `evidenceClass: synthetic` make this explicit.
`ReleasePolicy` can accept their contract shape but always returns
`CandidateReady = HostedReady = CanEnablePublicDownload = false` for them.
Never copy these files into `artifacts/`, `site/` or a GitHub release.

## Contract and immutable hashes

`Windows/release-manifest.schema.json` is schema v1. Every object rejects unknown
fields. `ReleasePolicy.SchemaSha256` pins the exact UTF-8 schema bytes: callers
cannot provide a permissive replacement. The schema checks structure; Core
additionally checks byte hashes, source/publisher/verifier identity, dates,
Defender freshness, complete payload/signature inventory, physical OS coverage,
report projections and the immutable URL. JSON duplicate keys are rejected.

The consumer passes independently expected source, publisher, certificate,
verifier-script SHA and evaluation UTC, plus the installer stream, the actual
browser-downloaded stream for hosted readiness, the complete independently
extracted payload and retained evidence files. Stream positions
are consumed; seekable streams are required. Production producers must inspect
real Authenticode/Defender/physical observations, enumerate extraction safely,
and reject links/traversal before providing these inputs. This pure policy
does not execute Windows verification and cannot authenticate human truth from
JSON alone. A hash is integrity evidence, not proof that an observation occurred.

Hash DAG (arrows mean “depends on”):

```text
payload -> build
signatures -> payload
scan -> signatures
physical-windows10 -> scan
physical-windows11 -> scan
hosting -> physical-windows10, physical-windows11
verification -> all available groups above, in that order
manifest -> group reports including verification
external manifest checksum -> manifest
```

Grouped reports are exact UTF-8 bytes at
`reports/<kind>-<sha256>.json`. Each envelope contains only `schemaVersion`,
`kind`, `evidenceClass`, `sourceCommit`, `artifactSha256`, `dependsOn`, and
`observations`. `observations` equals its manifest group **without** `report`.
Thus no report embeds its own digest, the final manifest, or a manifest digest.
The full ordered dependency list is checked against already verified report
references. Missing reports, bytes changed under the same reference, cycles,
extra dependency edges and hand-written success booleans cannot pass.
Raw preflight/scan/corpus/download records and build inputs also carry byte
hashes and must be present in the evidence map; build paths are anchored by
the expected immutable source commit. Production raw records remain retained.

The payload inventory is sorted by case-sensitive ordinal relative path;
case-insensitive path collisions are forbidden for Windows. Its hash covers
compact UTF-8 JSON with recursively ordinal-sorted object keys, array order
preserved, no whitespace/BOM/newline, and unescaped Unicode. File sizes are
integers. Every shipped file must match independently supplied bytes; every
file beginning `MZ` requires a signature record, as do all EXE/DLL paths.
Required owned PEs include `Resenha.exe`, `Resenha.TargetBroker.exe`,
`native/whisper-cli.exe`, `unins000.exe`, plus the final installer. Inventory,
signature and extracted-file map paths use the same relative `/` separator;
the root-level `whisper-cli.exe` does not satisfy the required native path.
Legitimate `authority: vendor` signatures may cover other dependencies; owned
PEs use `authority: release` and require the approved publisher.

Times use second-precision UTC (`YYYY-MM-DDTHH:MM:SSZ`) and real calendar dates.
Release signing must follow build; an already signed vendor dependency may have
an earlier timestamp. Both authorities require valid certificate/chain and
timestamp evidence. Scans follow signature verification, physical QA follows
both scans, and browser download follows both physical runs. Definitions are at most
24 hours old through scan completion. Trusted RFC 3161 signing time must fall
within certificate validity; a properly timestamped certificate need not still
be unexpired at the later verification time. No future observations are accepted.

Anglicism retention is a measured ratio of at least 0.9 only for PT-BR (`pt`)
and Spanish (`es`). English (`en`) must use the literal `not-applicable`, with
no invented ratio. The schema and Core enforce this language-specific contract;
the WER threshold and minimum corpus size still apply to all three languages.
The positive synthetic bundles include a vendor timestamp preceding the build.

`candidate-ready` requires build, payload, signatures, scans and both physical
OS runs; `hosting` must be null. It is suitable for the explicit publication
step, never public site activation. `hosted-ready` additionally requires actual
download-byte identity, immutable release/asset IDs, Mark of the Web, publisher
display and SmartScreen outcome. A reputation-only warning needs disclosure;
detection/policy denial fails. Both stages require verifier report identity.

The only permitted hosted URL is exactly:

```text
https://github.com/luisroquette-labs/resenha/releases/download/windows-v<version>/Resenha-<version>-windows-x64-setup.exe
```

No `latest`, arbitrary host, query string, redirect parameter or macOS asset is
accepted. An HTTP success response alone is not hosted-byte proof. Real reports
are reserved for Steps 13–14 and 17–22; Step 03 does not publish anything.

## Validation

1. `mac-gate node --test Scripts/windows-release.test.mjs` checks the schema,
   deterministic fixture bytes, full DAG and named schema-positive/negative
   mutations. Semantic cases are explicitly labeled as requiring Core execution.
2. With the exact SDK installed and reviewed package locks, from `Windows/` run
   `mac-gate dotnet test --project Resenha.Core.Tests/Resenha.Core.Tests.csproj -c Release`.
   `ReleasePolicyTests.cs` exercises both synthetic stages, every negative case,
   changed report/schema bytes, duplicate keys and incomplete PE signatures.
3. Native compile/signature/scan/hardware/hosting remain separate required gates.
   Node success is not proof that .NET compiled or Windows worked.

The committed bundles are generated by the pure `createSyntheticBundle` helper;
Node tests require exact reproducibility. `negative-cases.json` contains named
single mutations with the expected structural result and, where relevant,
the specific Core rejection. Missing SDK/tooling is a blocker, never a skip.
