# Codebase impact: Resenha sales and download site

Date: 2026-10-02. Task: `build-resenha-sales-site.feature.md` (currently `.specs/tasks/draft/`; task identity remains stable as its status folder changes).

## Scope and recommendation

Create a self-contained static site under `site/`, with semantic HTML, CSS, optional small progressive-enhancement JavaScript, and first-party assets. No site framework, package manager, backend, API key field, audio capture, app bridge or new runtime dependency is needed. The site describes the product and its development status; it does not implement the roadmap. Its download section must be reviewable locally before repository publication or Store work.

The repository contains a Swift macOS application, not an existing website to redesign. The project directory and app bundle still use `WhisperKey`; Resenha is the accepted public product name, not an implemented app rename. Do not rename the native target/bundle during the site task: signing/TCC identity and the running development app are unrelated to page branding.

## Verified baseline

| Evidence | Observation | Consequence for this task |
|---|---|---|
| `git status --short`, `git rev-parse --verify HEAD` | Entire project is untracked; no HEAD exists | Preserve all app WIP; no clean baseline or previous commit diff can be claimed |
| `git remote -v` | No remote configured | No Resenha repository URL or release-download URL is verified |
| File inventory | No `site/`, `package.json`, lockfile, `.github/`, web framework, web server, deployment config, LICENSE or branding asset set | Add only site files and their verification/documentation; future publication is a separate gate |
| `project.yml` | Swift 5 mode, deployment macOS 14; local manual Apple Development signing; hardened runtime disabled | Not evidence of notarization, universal binary, Mac App Store readiness or a consumer installer |
| `Config/WhisperKey-Info.plist` | Version 0.1.0, build 1; `LSUIElement`, multiple instances prohibited; microphone usage description | Development version is known, but must not become a fake public release badge |
| `README.md`, `docs/testing/UI-REFINEMENT-EVIDENCE.md` | 35 tests passed in recorded 13:53 gate, 40 native fixture images; physical acceptance remains pending in repository | Historical test/fixture evidence is not fresh site validation or cross-app compatibility certification |
| Local tools | Node `/opt/homebrew/bin/node`, v26.5.0; mac-gate exists | Node stdlib suffices for a tiny static server/check if needed; no npm install required |

The memory registry search for WhisperKey/Resenha/Sussurro returned no relevant entry. No memory-derived product fact is used.

## Runtime interfaces and truthful copy contract

The page has **no runtime coupling** to these interfaces. They constrain marketing claims and supply original visual material.

| File / symbol | Actual interface and behavior | Public-copy implication |
|---|---|---|
| `Sources/WhisperKey/HotkeyMonitor.swift` | `start() throws`, `stop()`, `onPress: (() -> Void)?`, `onRelease: (() -> Void)?`; listens to `flagsChanged`, keycode 61 | Current prototype uses Right Option. Customizable hotkeys are required roadmap, not implemented settings |
| `Sources/WhisperKey/DictationCoordinator.swift` | `hotkeyPressed()`, `hotkeyReleased()`, `cancel()`; captures original frontmost app and sequences recording → transcription → insertion | Core hold/speak/release story exists. Do not promise universal compatibility or measured latency |
| `Sources/WhisperKey/AudioRecorder.swift` | `start() throws`, `stop() throws -> URL`, `cancel()`, `onLevel: (@MainActor (Float) -> Void)?`; 16 kHz mono WAV, 20 Hz level sampling | Real waveform is a valid prototype capability; recording is local and session-temporary |
| `Sources/WhisperKey/WhisperTranscriber.swift` | `WhisperPaths.resolve(environment: [String: String], home: URL) throws -> WhisperPaths`; finds external Homebrew CLI and local model. `transcribe(audioURL: URL) throws -> String` runs subprocess with `-l pt` | Local whisper.cpp is implemented; embedded/self-contained install is not. Portuguese is configured; multilingual selection and translation are not |
| Same file, `TranscriptNormalizer.normalize(_ raw: String) -> String` | Trims/join lines and drops bracketed non-speech lines | No smart rewrite, stylistic cleanup, personal dictionary or guaranteed punctuation correction |
| `Sources/WhisperKey/TextInjector.swift` | `insert(_ text: String, into target: NSRunningApplication?) async throws`; pasteboard snapshot, app activation, synthetic Cmd+V, guarded restore | Describe insertion at the cursor as intended workflow; no native integration logos or universal-app claim. Direct AX range insertion is not implemented |
| `Sources/WhisperKey/RecordingWaveformView.swift` | `RecordingMeter.append(level:at:)`, `displayLevels(reduceMotion:)`, `RecordingWaveformView(meter:fixtureReduceMotion:)` | Original 48-bar HUD visual can inspire an illustrative website demo. A scripted demo must be labeled, must not request microphone access, and must respect reduced motion |
| `Sources/WhisperKey/FloatingStatusView.swift` | `FloatingStatusView(model:...)`; `panelSize(for:available:)`; production listening panel 340 × 72 | Reuse original app proportions/visual idea; current UI labels are English, so Portuguese page illustrations must not be represented as an unmodified app screenshot |
| `Sources/WhisperKey/PermissionService.swift` | Snapshot, explicit microphone/Accessibility/Input Monitoring request and Settings actions | Explain permission requirements briefly in FAQ, not as web permission requests |

### Capability status for the page

| Capability | Observed status | Safe label/content |
|---|---|---|
| macOS push-to-talk, local whisper.cpp, ephemeral audio, floating level meter | Implemented in local development prototype | “Protótipo para macOS”; “Ditado local em desenvolvimento” |
| Hold → speak → release → insertion | Implemented flow; latest physical acceptance not closed in files | Product explanation/demo; avoid claiming an independently verified broad app list |
| Custom hotkey, settings UI, Fn support | Not implemented; explicitly deferred in `docs/architecture.md` | “Planejado” beside the capability, not buried in footer |
| OpenAI with user's key | No provider/network/Keychain implementation | “Opcional, planejado”; audio would be sent to provider; provider charges are separate. Do not create a key-entry form |
| Windows WinUI, Rust shared core | No Windows or Rust files | “Windows — planejado”; no executable badge/download |
| Translation, mixed-language tuning, smart formatting, dictionary, hands-free, history | Not present | Benchmark/roadmap only when useful; never a current feature claim |
| Apache 2.0 / open source | User-approved direction; no LICENSE file or public repository yet | “Licença planejada: Apache 2.0” / “Preparando a abertura do código” until actual license/publication exists |
| GitHub, DMG, App Store | No verified remote, artifact URL or Store listing | Visible unavailable states with explanatory text; no fabricated links, Store badge, star count or download CTA that does nothing |

Current constitution is local-only M0. The newer accepted optional-cloud product direction is not permission to change the native app in this task. The page must distinguish local mode from future opt-in cloud mode; “100% local” without that distinction would be misleading.

## Original assets and reuse boundaries

`build/ui-fixtures/` contains 40 PNGs: eight states × light/dark/increased-contrast/reduced-transparency/reduced-motion. `Tests/WhisperKeyTests/WhisperKeyTests.swift:testHUDNativeFixturesForEveryStateAndAppearance()` generates them from production SwiftUI with fixed/injected state, levels and clock.

Relevant candidate assets: `build/ui-fixtures/hud-listening-light.png`, `hud-listening-dark.png`, `hud-transcribing-light.png`. They are rendered fixtures, not live screenshots. `build/` is gitignored, so a deployed site cannot reference `../build/...`. If used, copy only selected safe fixture imagery into `site/assets/`, give it explicit “prévia ilustrativa” context/alt text, and record origin in evidence. Prefer an original inline HTML/CSS product illustration when that avoids extra binary assets. Do not publish the user's desktop/Terminal screenshot: it contains unrelated personal workspace content.

No existing logo, icon family, fonts, video, testimonials, metrics or brand-token source is available. Use original Resenha wordmark/SVG and system font stack. Willow assets are research-only and must not be hotlinked or copied.

## Expected file impact

This is a proposed minimal ceiling for architecture/decomposition, not implementation already performed. Architecture may omit optional JS/assets or co-locate the download section.

| Path | Operation | Responsibility |
|---|---|---|
| `site/index.html` | Create | Portuguese sales page, semantic landmarks, feature status, FAQ, download section and original illustrative product surface |
| `site/styles.css` | Create | Original visual system, responsive layout, visible focus, contrast and reduced-motion handling |
| `site/script.js` | Create only if interaction earns it | Progressive enhancement for a demo; content/navigation remain usable without JS; no mic/API/telemetry |
| `site/assets/resenha.svg` | Create only if a separate asset earns it | Original lightweight mark/favicon; may be inline instead |
| `Scripts/site.mjs` | Create | Node-stdlib local preview and/or focused verification; document exact command; server binds loopback and serves only `site/`, with traversal rejection |
| `docs/testing/RESENHA-SITE-EVIDENCE.md` | Create | Page-content/status audit, local browser observations, viewport/keyboard/reduced-motion checks, commands and release-link inventory |
| `README.md` | Modify append-only | Local site preview/check instructions and product-name bridge; preserve native run/TCC guidance |

Affected-file estimate: **7 files: 6 create, 1 modify, 0 delete**, with optional JS/logo removable. Planning task/research/analysis/sub-task artifacts are additional SDD outputs, not production footprint. Native `Sources/`, `Tests/`, `project.yml`, Info.plist and Xcode project require **zero edits** for this site task.

A separate `/download` page is optional. A clear `#download` section reproduces the functional desktop-choice intent without a router, URL rewrite, duplicate copy or added framework. If architecture chooses `site/download/index.html`, include it as an additional file and verify relative links at a repository subpath.

## Integration points and gates

1. **Content → code evidence:** capability badges must track the table above. Architecture decisions are roadmap until implemented. Root README remains the bridge from public Resenha name to internal WhisperKey build instructions.
2. **Preview → static deployment:** use relative asset URLs and same-page anchors so local preview and future GitHub project Pages both work. No root-absolute `/styles.css` paths. Do not invent canonical URL, social preview URL or sitemap origin before a deployment target exists.
3. **Download → release availability:** unavailable entries are ordinary status content, not dummy anchors or misleading disabled “Download” buttons. Activate a link only after its exact repository/release/Store URL is verified. Native signing identity is not a release URL.
4. **Tests → mac-gate:** existing app command is `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. There is no current web lint/test/build command. Proposed focused check uses `~/.local/bin/mac-gate node Scripts/site.mjs --check` if architecture adopts that helper. Do not pretend this command exists until implementation. Site-only work does not justify re-running native tests unchanged. Browser inspection must run against actual local server output.
5. **Site → publication:** no remote, workflows or host config exists. This task should leave a locally validated, reviewable static site. Later GitHub work must select/verify repository, review public-file scope (source, docs, local identities/paths, no build outputs), install the agreed license, configure remote and only then publish. Store work is separately blocked on sandbox/injection/hotkey feasibility, embedded runtime/model packaging, distribution signing/notarization as appropriate, metadata/privacy and a verified listing. No public install link is implied by finishing HTML.

Recommended local checks: links and asset resolution including a repository subpath; one h1 and useful title/description/lang; semantic keyboard navigation, visible focus, no horizontal overflow at narrow/mobile and desktop widths; reduced-motion behavior; usable no-JS content; honest release states; no external requests for fonts/analytics/API. If a scripted demo is included, leave one small runnable check for its state transitions/stop/reset behavior rather than installing a testing framework for static text.

## Risks and mitigations

| Risk | Level | Evidence / mitigation |
|---|---|---|
| Marketing roadmap as shipping product | High | Most Willow-like controls and cloud/Windows support do not exist. Adjacent status labels and review every feature/CTA against source evidence |
| Publishing a development binary as consumer-ready | High | External CLI/model, Apple Development signing, hardened runtime off, no distribution workflow. Keep download unavailable until release gates are proven |
| Rebranding native app breaks TCC or concurrent UI task | High | Bundle identity is intentionally stable; current UI task remains in-progress. Isolate all implementation to site/docs |
| Disclosure through screenshots/generated outputs | Medium | User desktop screenshot and build evidence contain workspace context. Use original illustration or isolated first-party HUD fixtures; do not publish build directory |
| Future project Pages path breaks assets | Medium | No host chosen. Relative paths, tested subpath preview, no invented canonical domain |
| Oversized web framework/tooling | Low | No dynamic backend or data needs. Static HTML/CSS + only necessary JS is sufficient |

Analysis only: no site implementation, native mutation, test execution, release publication or external account action was performed.
