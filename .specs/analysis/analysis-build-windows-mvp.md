# Windows MVP: codebase impact

Date: 2026-10-04. Baseline: `9e674c3` (`Merge pull request #11 from luisroquette/fix/resenha-whatsapp-required`). Task: `.specs/tasks/in-progress/build-windows-mvp.feature.md`. Scope of this document: repository analysis, proposed boundaries and evidence requirements; no Windows implementation or release is claimed.

## Current baseline

The repository has 230 tracked files, a Swift macOS application, one static website and one lightweight site-test workflow. There is no Windows source, Windows project/solution, Rust workspace, Windows packaging script or Windows binary. The pinned `Vendor/whisper.cpp` submodule is commit `4979e04f5dcaccb36057e059bbaed8a2f5288315`; it is the reusable inference source, whereas `Frameworks/whisper.xcframework` is an arm64 macOS artifact.

`project.yml` defines macOS 14, arm64, Swift, Metal and Accelerate. All app source lives in `Sources/WhisperKey`; AppKit, SwiftUI, AVFoundation and macOS permission APIs prevent direct reuse as a Windows app. Reuse the product contracts and test vectors without migrating the working Mac implementation.

The earlier completed sales-site task mentions intended WinUI shells and a shared Rust core. Those are historical intentions, not implemented dependencies. Choose the Windows shell/core during architecture after platform research; a shared-core migration is not necessary to reproduce the authorized Windows loop. Existing artifacts claiming an unborn repository or unavailable Mac release are stale: current `site/release.mjs` contains a published Mac DMG and public source record. This analysis verified files at the stated commit; it did not verify those external destinations live.

## Existing contracts and portability

| Existing source | Verified contract | Windows treatment |
|---|---|---|
| `Sources/WhisperKey/DictationCoordinator.swift` | `hotkeyPressed`, `hotkeyReleased`, `cancel`; idle → recording → transcribing → inserting → idle; failed → idle; attempt UUID rejects obsolete async completions | Port state and generation semantics into a Windows coordinator with injectable boundaries; no Swift change |
| `HotkeyMonitor.swift`, `DictationInteraction.swift` | Exact configured shortcut, independent press/release edges, repeated-key latch, release after interruption, reject self/menu/permission starts | New Windows input adapter and shortcut serialization; do not copy Mac key codes or automatically equate right Option with AltGr |
| `ProductPreferences.swift`, `ShortcutCaptureController.swift` | In-app shortcut capture/persistence; pt/en/es language enum; local preferences and bounded glossary | Reuse behavioral requirements; Windows storage and key naming are new; extensive Mac settings parity is optional beyond MVP |
| `AudioRecorder.swift` | Unique temporary 16 kHz mono 16-bit PCM WAV, actual input level, cancel cleanup, bounded stale WAV cleanup | New Windows microphone adapter, resampling if necessary, user-owned paths and reliable completion/cancel cleanup |
| `WhisperTranscriber.swift` | One serialized embedded engine, pinned model, local inference, no translation, no context, deterministic normalization/glossary, empty text rejection | Build Windows inference from the pinned upstream source; expose a narrow adapter with deterministic output policy |
| `WhisperModelManager.swift` | `ggml-small-q5_1.bin`, 190085487 bytes, SHA-256 `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`; download stages before promotion | Reuse this descriptor unless research proves unsupported; Windows must verify before marking ready and before loading an untrusted preexisting file |
| `TextInjector.swift` | Stage nonempty text first, retain clipboard recovery, target identity, bounded target activation, reject clipboard mutation before one paste | New Windows clipboard/foreground adapter; retain exact target identity, sequence guard and failure recovery; no claim of universal insertion |
| `TranscriptHistory.swift` | Optional last 10 texts; 100000-character item limit, 2 MiB file guard, copy/clear | Not required to add disk history for minimum Windows loop; if adopted, port explicit opt-in and bounds |
| `FloatingPanel.swift`, `FloatingStatusView.swift`, `MenuPresentation.swift`, `PanelPlacement.swift` | Nonactivating status UI; generation-safe dismissal, permission/error recovery and display-bound placement | New native tray/status UI; Mac views are reference only; preserve editor focus |
| `Tests/Fixtures/output-corpus.json` | Existing deterministic transcription/output fixtures | Reuse read-only from Windows tests rather than independently changing expectations |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Shortcut, state, clipboard staging, cleanup, output, bounded errors, late callback and UI fixtures; real inference test can skip without local model | Source of regression scenarios, not a Windows test suite; skipped model test never qualifies a release |

Two inherited implementation details must not be advertised as stronger guarantees: the Mac engine checks cancellation and its ten-minute runtime bound around a blocking inference call, and model `refresh()` marks an existing path ready by existence. Windows should implement its own verifiable cancellation/timeout and integrity contracts; repairing Mac behavior is outside this task.

## Proposed Windows interfaces

Keep platform-independent policy separate from Windows integration. Types below are interface proposals, not declarations already present in the repository. The architecture phase must select language/framework and concrete filenames.

| Boundary | Proposed interface/data | Invariant |
|---|---|---|
| Shortcut input | `Configure(Shortcut)`, `Start()`, `Stop()`, `Pressed`, `Released`, `Interrupted`; shortcut includes physical key and exact modifiers | Hook callbacks do bounded work; never record arbitrary keystrokes; repeated press cannot begin a second attempt |
| Target capture | `CaptureTarget() -> TargetSnapshot`; target contains window identity and owning process/session identity | Capture before opening any Resenha UI; reject closed, replaced or disallowed target |
| Recorder | `Start(attemptId)`, `Stop() -> AudioLease`, `Cancel()`; level events optional | Recording occurs only during valid hold; owned audio is disposable and deleted on all terminal outcomes |
| Model store | `EnsureVerifiedModel() -> VerifiedModel`, `Download(progress, cancellation)` | Exact byte count/hash; atomic promotion; failed download cannot replace the last good model |
| Inference | `Transcribe(audio, model, language, cancellation, deadline) -> Transcript` | Local, serialized, finite and cancellation-aware; no transcript from an obsolete attempt can be inserted |
| Clipboard | `Stage(text) -> ClipboardToken`, `IsCurrent(token)` | Preserve completed text for manual recovery; no paste after unrelated clipboard update |
| Insertion | `Insert(target, clipboardToken, cancellation) -> InjectionResult` | Bounded focus recovery and one paste; blocked/elevated/secure destinations must fail safely with clipboard recovery |
| Coordinator | `Press`, `Release`, `Cancel`, `StateChanged`; monotonic attempt identity | Only coordinator advances lifecycle; stale work cannot reset or modify a new attempt |
| Presentation | Tray commands, first-run model/microphone setup, shortcut capture, nonactivating status/error feedback | Never focus-steal from the target during dictation; errors identify one actionable recovery |

Windows API choices, CPU/OS minimums, keyboard-layout behavior and installer technology require primary-source platform research and physical verification. An application-level API returning success is not proof that text reached the original field.

## Site and release integration

| File/interface | Current behavior | Required change |
|---|---|---|
| `site/release.mjs: releaseState` | Frozen `macos`, `source`, `store` records; no Windows record | Add `windows` initially planned with null URL/evidence; Mac publication remains independent |
| `resolveDestination(channel, record)` | Strict HTTPS GitHub release URL, evidence URL/channel/date matching; Mac requires SHA, notarization ID/status, version, architecture, OS | Add independent Windows evidence validation; never apply Apple notarization rules to Windows and never accept a Mac artifact as Windows |
| `applyReleaseState(root, state)` | Only macOS uses a button and `openDownloadGate`; other active channels become direct anchors | Both artifact channels must choose their own immutable platform download configuration; unknown/unverified platform stays inactive |
| `site/download-gate.mjs` | One global modal; hardcoded CF Gauss Mac form ID `0a702231-3472-412f-8e3b-00ecfa481100`, Mac embed, Mac redirect, DMG text, version 1.0.0 and analytics platform `macos_arm64` | Parameterize per validated platform; Windows requires its own provisioned form/redirect or a verified supported multi-platform contract; retain current Mac configuration |
| `isFormMessage(event, iframeWindow)` | Exact origin, iframe source, message source and form ID guard | Bind to current gate session + selected form; reject old/other-platform success events, including reopen/switch cases |
| `site/analytics.mjs: trackEvent` | Accepts event name and parameters; consent settings remain independent | No API change necessary; caller supplies accurate `windows_x64` and artifact version; never add PII, audio or text to events |
| `site/index.html` | Mac-only title, lead, schema, requirements and one Mac download slot | Add visibly qualified Windows slot and requirements; activate only after verified release; retain labels identifying existing screenshots as Mac UI |
| `site/alternativa-wispr-flow/index.html` | Comparison says Resenha only on macOS and suggests competitors if Windows is needed | Update release-dependent support claim; no premature broad feature parity or app compatibility claims |
| `site/privacy/index.html`, `docs/PRIVACY.md` | Mac paths/permissions and local processing; site separately explains GA4/CF Gauss | Document Windows storage/microphone/input/insertion behavior and continue separating app privacy from website lead capture |

The platform configuration should carry `{platform, version, formId, formUrl, redirectUrl, artifactUrl}`. Gate activation must follow successful release validation, not accept arbitrary caller-supplied URLs. Each session should retain its configuration until close and cancel pending redirect timers when superseded. Test success from the wrong form, wrong window, wrong origin, stale dialog, duplicate message and platform switch.

Release metadata alone is not evidence generation. A proposed Windows record includes version, architecture, minimum OS, immutable release URL, SHA-256, source commit, artifact filename, build report, scan report, signing status and physical test report. Build/scan/physical reports must identify the SAME final packaged bytes. Packaging or signing after testing changes the artifact and invalidates that evidence. Explicitly distinguish unsigned/signed; a checksum or antivirus result does not imply signing or absence of SmartScreen prompts.

The existing CF Gauss redirect is an external dependency: inspecting this repository cannot establish a Windows form or redirect. Never reuse the Mac endpoint for Windows. Provision and verify the exact Windows destination in the authorized CF Gauss workflow, and keep the Windows CTA closed until it resolves to the verified artifact. No secret or lead data belongs in the static configuration.

## Create / modify / no-touch inventory

This is a bounded implementation map. Final Windows filenames depend on the architecture decision. Counts below distinguish existing-file impact from proposed new modules and the two analysis artifacts created now.

| Operation | Path or group | Purpose |
|---|---|---|
| CREATE | `windows/` solution/build metadata and dependency lockfiles | One native Windows target, pinned compiler/SDK/runtime dependencies and deterministic architecture selection |
| CREATE | Windows coordinator, shortcut, recorder, model-store, transcriber, clipboard/insertion, preferences and presentation modules | New runtime implementing the interfaces above; estimate 12–20 source/project files |
| CREATE | Windows unit/integration test project and fixtures | State, input edges, exact target, cleanup, model verification, output and error tests; estimate 5–8 files |
| CREATE | `Scripts/build-windows-release.ps1`, `Scripts/validate-windows-release.ps1` | Exact-artifact build/package, checksum, scan/signature inspection, fail-closed evidence validation |
| CREATE | `docs/specs/23-windows-mvp.md`, `docs/testing/WINDOWS-MVP-EVIDENCE.md`, `docs/testing/WINDOWS-RELEASE-EVIDENCE.md` | Windows behavior contract, physical runtime matrix and artifact promotion evidence |
| CREATE | Lightweight contract/test workflow only if needed; release workflow only after build-location decision | Do not silently add a paid Windows PR build runner under the global lightweight-Ubuntu policy |
| MODIFY | `site/release.mjs`, `site/download-gate.mjs` | Platform-specific release validation and form/redirect routing |
| MODIFY | `site/index.html`, `site/styles.css`, `site/alternativa-wispr-flow/index.html`, `site/privacy/index.html` | Windows status/download card, truthful claims and platform privacy |
| MODIFY | `Scripts/site.test.mjs`, `Tools/site-audit/audit.mjs` | Windows release matrix, gate behavior and fresh browser assertions |
| MODIFY | `.github/workflows/site-tests.yml` | Add new shared site-contract inputs to path filters only where needed |
| MODIFY | `README.md`, `docs/architecture.md`, `docs/PRIVACY.md`, `docs/specs/00-constitution.md`, `THIRD_PARTY_NOTICES.md`, `.gitignore` | Platform scope, run/release commands, privacy, Windows amendment, native dependency licensing and generated-file exclusions |
| NO TOUCH | `Sources/WhisperKey/**`, `Tests/WhisperKeyTests/**`, `WhisperKey.xcodeproj/**`, `project.yml`, `Config/**`, `Frameworks/**`, `AppStore/**` | Preserve the working Mac app, signing identity, permissions, tests and distribution |
| NO TOUCH | `Vendor/whisper.cpp` pin, `Tests/Fixtures/output-corpus.json`, existing brand assets | Reuse read-only; pin upgrade or output semantics changes require an independently justified scope |
| NO TOUCH | Mac release scripts, `site/analytics.mjs`, `Scripts/site.mjs`, `site/media.mjs`, host configuration | No implementation need established; analytics supports parameters and static server already serves nested files |

Projected existing-file modifications: **15** (9 site/test/workflow files, 6 documentation/ignore files). New implementation footprint: **22–34 files**, plus an optional workflow and any approved packaging assets. Total projected implementation impact: **37–50 files, zero deletions**. This estimate excludes later SDD decomposition artifacts. Current actual change: **2 created Markdown files**, no implementation edits and no task-file edits.

## Tests, workflows and release gates

The only checked-in workflow is `.github/workflows/site-tests.yml`: Ubuntu, five-minute timeout, concurrency cancellation, pinned checkout and `node Scripts/site.test.mjs`; it triggers for site/script/workflow changes. There is no root `package.json`, `preflight:ci`, Vercel configuration or checked-in Windows execution mechanism. Canonical site checks currently run with `~/.local/bin/mac-gate node Scripts/site.test.mjs`. Do not invent an available `npm run preflight:ci` or treat a missing Vercel check as passed. Source URLs and canonical metadata point to GitHub Pages; verify real deployment configuration before publication.

The global policy puts local typecheck/lint/tests behind `mac-gate` and routine Actions on lightweight Ubuntu. Pure portable core checks may run on Mac; Windows hardware/API/build checks cannot be proven there. Architecture must name an available Windows machine and release build location or explicitly identify that remaining external prerequisite. No routine Windows runner, Codespace, paid API, or new deployment provider is implicitly approved by this analysis.

| Gate | Required evidence |
|---|---|
| Deterministic runtime | State transition/overlap matrix; repeated and interrupted key events; exact shortcut modifiers; rejected self-target; release during UI interaction; stale completion; cancellation/timeout; no paste on empty/failed inference |
| Data and integrity | Invalid/truncated/wrong-hash model; failed download retains good file; cleanup success/error/cancel/crash leftovers only within owned paths; clipboard contention/change; target disappears or changes; no transcript content in diagnostics |
| Inference | Actual pinned Windows library + exact model + fixture, with version/architecture evidence; no fallback cloud call; offline run after provisioning |
| Physical Windows loop | Fresh install; configurable hold shortcut; real microphone; local recognition; clipboard and insertion into Notepad and browser text field; focus/caret retention; closed target/elevated target/manual recovery; keyboard layout and restart persistence; uninstall behavior |
| Distribution/site | Final bytes built/scanned/checksummed; report identifies same SHA/version/source; published URL resolves to those bytes; Windows form routes there; missing or mismatched evidence keeps CTA inactive; Mac regression stays green |

The site unit suite currently uses an exact 33-fixture catalogue and indices (`slice(30)`, `[31]`, `[32]`), so add Windows cases without accidentally reclassifying the existing positive fixtures. Prefer named groups as the catalogue expands. Preserve all existing negative URL/evidence cases.

`Tools/site-audit/audit.mjs` is stale relative to the current site: it expects prototype text, Windows-planned/WinUI/Rust copy, absence of video/iframe/canonical/schema and unavailable links, and writes an unborn-repository evidence label. It cannot serve as a truthful release gate until its assertions/evidence fingerprints are updated to the current platform/gate model. Include `download-gate.mjs` and relevant platform config in audit fingerprints. Browser automation must intercept synthetic form navigation and avoid generating real CRM leads.

The Mac tests need not run for an isolated Windows + site change if their runtime/configuration remains untouched. They become mandatory through the canonical `mac-gate xcodebuild ... -derivedDataPath build test` command if shared assets/configuration actually change. A green site test is not Windows acceptance; mock success is not hardware proof.

## Risks and implementation order

| Risk | Level | Concrete control |
|---|---|---|
| Wrong platform download through current fixed Mac gate | Critical | Independent validated platform configuration; CF Gauss redirect verification; reject cross-platform/stale events |
| Focus/clipboard race inserts into wrong field | High | Capture before UI, retain process/window identity, check foreground and clipboard token, fail closed, test physically |
| Mac behavior accidentally changed by shared-core migration | High | Add Windows side-by-side; no-touch Swift/Xcode/framework areas; reuse specifications and fixtures |
| Binary called ready after cross-compilation/unit test alone | High | Exact packaged artifact evidence from a real Windows installation; no CTA until all release predicates pass |
| Model/inference cancellation or integrity overstated | High | Verify on load, bounded and observable engine lifetime, generation guards and known corrupted-model tests |
| Unknown signing/build/runtime dependency cost | High | Resolve supported architecture/toolchain/installer/signing policy before provisioning; record unsigned status truthfully if allowed |
| Stale documentation/audit conflicts with current behavior | Medium | Current-source baselines, platform-specific claims and refreshed audit evidence rather than inherited historical assertions |

Recommended dependency sequence: freeze Windows MVP/platform and evidence contract → implement portable lifecycle + Windows adapters → prove real offline dictation and insertion → package/scan/checksum/test the final artifact → provision platform download routing and activate the site only with matched release evidence. Keep all task work on the same dedicated branch and PR; publication is a distinct state transition, not a side effect of creating the Windows record.
