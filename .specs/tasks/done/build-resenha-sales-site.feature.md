---
title: Build the Resenha product sales and download site
---

## Research Skill

The [.claude/skills/open-source-dictation-site/SKILL.md](../../../.claude/skills/open-source-dictation-site/SKILL.md) supplies sourced Willow feature/configuration patterns and context for original content, release-aware CTAs, accessibility, performance and metadata. Claim and destination evaluation is defined in Acceptance Criteria below.

## Initial User Prompt

> veja mais features e configs. que o willow oferce e o nosso site.. nao! Esplehe na pagina de vendas do willow voice [dowenlaod page] par escrever e criar a nossa pagind e vendas [iremate do repo do github e depois, app srote]

### Requirements

- Product brand: Resenha.
- Positioning: open-source, local-first voice dictation for any text field.
- Core promise: hold a global hotkey, speak, release, and receive text at the cursor.
- Local transcription through whisper.cpp; optional OpenAI provider using the user's own API key.
- macOS first, Windows second; native SwiftUI and WinUI shells with a shared Rust core.
- Customizable global hotkeys are a required product capability.
- Apache 2.0 licensing.
- Study Willow Voice's sales and download pages as a functional benchmark without copying its protected branding, text, testimonials, metrics, or visual assets.
- Deliver in this order: local sales/download site, public GitHub repository, then App Store submission.
- Do not claim unavailable releases, integrations, metrics, certifications, reviews, or completed Windows support.

# Description

Build an original, local Resenha sales and download site for people who want to dictate into the text field they are already using. Explain the hold, speak, release and cursor-insertion workflow; show the product's feature and configuration direction; and help visitors identify what they can actually try today. The goal is an understandable product experience with an honest next action, rather than a release announcement unsupported by distributable software.

Resenha's intended positioning is open-source and local-first, with macOS first and Windows later. The site must distinguish demonstrated development behavior from planned capabilities and clearly explain local versus optional cloud processing. Study Willow's sales and download surfaces for functional patterns—workflow explanation, feature grouping, configuration guidance, FAQ and platform selection—while independently authoring Resenha's identity, copy and assets. Use pt-BR as the initial content language.

**Scope Included**

- Local sales and download surfaces with product positioning, workflow, features/configuration, provider/privacy explanation, platform requirements, FAQ and clear availability states.
- Original Resenha visuals and illustrative demonstrations, labeled where they represent planned or simulated behavior.
- Discoverable navigation, mobile layouts, keyboard and assistive access, accurate metadata and bounded local rendering performance.
- Release/source/store destinations that remain inactive when a verified destination is unavailable; maintainable status content for later delivery tasks.
- Local verification evidence and instructions that preserve the existing native application's behavior.

**Scope Excluded**

- Native application changes, configurable-hotkey implementation, cloud provider integration, Windows support, core migration, output/translation improvements or changes to permission/signing identity.
- Release packaging/signing/notarization, public GitHub remote creation or publication, deployment/domain configuration, and App Store submission. These are later tasks after the local site.
- Accounts, waitlist/contact submission, payment/checkout, invented pricing, analytics, trackers, API-key collection, microphone access or paid API/generation calls.
- Copied Willow branding, text, screenshots, testimonials, metrics or assets; unsupported compatibility, privacy, security-certification, integration or release claims.
- A claim that website verification completes pending native human-spoken acceptance or proves a distributable application.

**User Scenarios**

1. **macOS prospect:** Read the core workflow and features, follow the download action, and see the actual development/release status and requirements without a fake file or store link.
2. **Privacy-conscious visitor:** Compare local processing with optional planned cloud processing and understand the transfer of audio, ownership of the API key and separate provider usage charges.
3. **Windows visitor:** Find Windows-later information and avoid a macOS-only or nonexistent download presented as Windows support.
4. **Keyboard/mobile visitor:** Navigate the same content, FAQ and download explanation with visible focus and readable layouts on a small screen.
5. **Unavailable destination:** A missing release, source repository or store listing produces a visible status explanation and an inactive action; an illustrative demo is never mistaken for a shipped capability.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
|---|---|---|---|
| CK-1 | Does the Resenha hero and workflow explain holding a global hotkey, speaking, releasing and receiving text at the original cursor without app switching? | hard_rule | essential |
| CK-2 | Does every capability/compatibility claim identify evidenced current behavior or planned behavior, without claiming universal tested text-field support or fabricating metrics, testimonials, certifications, integrations or release readiness? | hard_rule | essential |
| CK-3 | Does the configuration content identify customizable global hotkeys as a required planned capability while accurately identifying the current prototype's fixed Right Option behavior? | hard_rule | essential |
| CK-4 | Does provider content distinguish current local whisper.cpp processing from optional planned OpenAI BYOK, explicitly explaining opt-in audio transfer, user-supplied key and separate provider charges without suggesting the website accepts keys or performs transcription? | hard_rule | essential |
| CK-5 | Does source/licensing/architecture content describe the open-source Apache 2.0 goal and SwiftUI/WinUI/shared-Rust direction with current-versus-planned qualification, without asserting a published licensed repository or implemented Windows/Rust core without evidence? | hard_rule | essential |
| CK-6 | Does the download surface show macOS-first development status and Windows-later status, with requirements labeled as development or verified release requirements rather than treating the M0 Homebrew setup as a self-contained installer? | hard_rule | essential |
| CK-7 | Are Download, GitHub and App Store actions inactive with visible availability explanations whenever a verified release/source/listing destination is absent, including empty, malformed or unsupported destination data? | hard_rule | essential |
| CK-8 | Are Resenha copy, composition and assets independently authored, with Willow references limited to functional patterns and simulated/planned demonstrations explicitly labeled? | hard_rule | essential |
| CK-9 | Is essential content readable without horizontal overflow or clipped actions at 320, 768 and 1440 CSS pixels and at 200% zoom? | principle | essential |
| CK-10 | Can keyboard and assistive users reach navigation, FAQ and download information through named semantic controls with visible focus, no focus traps, appropriate text alternatives, readable contrast and reduced-motion behavior? | hard_rule | essential |
| CK-11 | Do document language, titles, descriptions and social metadata match visible Resenha/status content, with no fabricated public canonical URL, ratings, offers or availability schema? | principle | important |
| CK-12 | Do three documented local production-preview Lighthouse mobile runs achieve median LCP no greater than 2.5 seconds, CLS no greater than 0.1 and TBT no greater than 200 milliseconds, without labeling those lab results as production user measurements? | principle | important |
| CK-13 | Does implementation remain a local site with no GitHub remote creation/publication, deployment, App Store submission, paid API calls, personal credentials or visitor-data collection? | hard_rule | essential |
| CK-14 | Does the diff preserve the existing native dictation/output/provider/permission/signing behavior and keep pending native acceptance distinct from site verification? | hard_rule | essential |
| CK-15 | Is release/status/action logic owned once rather than duplicated across navigation, hero and download surfaces? | principle | important |
| CK-16 | Does every selected test type and every main, edge and error case listed below have a corresponding passing check, with no orphan checklist item or silently skipped case? | hard_rule | essential |
| CK-17 | If native/shared build configuration is touched, does the discovered native mac-gate command complete with zero failures for the tested revision? | hard_rule | essential |
| CK-18 | Are improvements to touched code bounded to small site-related cleanup rather than unrelated refactoring? | principle | optional |
| CK-19 | Does the implementation honor the architecture's applicable reuse directives instead of recreating the named behavior? | principle | important |

**Regular Checks:**

- [ ] Compare visible copy, metadata, illustrations and every active destination with current implementation/release evidence; confirm absence states and original asset provenance (CK-1–8, CK-11).
- [ ] Exercise the local sales/download flow, direct route access, FAQ and inactive mouse/keyboard actions; record widths, zoom, accessibility results and three local mobile-performance runs (CK-7, CK-9, CK-10, CK-12).
- [ ] After implementation, run `~/.local/bin/mac-gate node --test Scripts/site.test.mjs` for finite availability and served-output checks. This is a new site gate, not an existing project command; the native suite does not substitute for it (CK-7, CK-11, CK-15, CK-16).
- [ ] Run `~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --browser` and `~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --lighthouse` against the unchanged static files. These new commands own their loopback server/browser lifecycle, exit nonzero on failures, and write raw reports/screenshots under `build/site-audit/`. Record exact package/browser versions and outcomes in `docs/testing/RESENHA-SITE-EVIDENCE.md` (CK-9, CK-10, CK-12, CK-16).
- [ ] If native/shared configuration is touched, run `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; otherwise record native source/configuration as unchanged. Any future `next build` is restricted to Vercel Preview under the owner rule and cannot be run locally (CK-14, CK-17).
- [ ] Inspect touched files for scope/cost/credential/data-collection violations, duplicate status ownership, bounded cleanup and architecture reuse; preserve concurrent work. The checkout currently has no HEAD: record before/after SHA-256 manifests of `Sources/`, `Tests/`, `Config/`, `project.yml` and `WhisperKey.xcodeproj/`, excluding user-specific Xcode state, rather than claiming an unavailable baseline diff proves preservation (CK-13–15, CK-18, CK-19).

**Rubric:**

| Criterion | Weight |
|---|---|
| Capability Status Clarity | 0.20 |
| Honest Download Path | 0.20 |
| Original Resenha Identity | 0.10 |
| Accessible Navigation | 0.15 |
| Truthful Discoverability | 0.10 |
| Measured Rendering Cost | 0.10 |
| Project Guidelines Alignment | 0.15 |

**Rubric Score Definitions:**

### Capability Status Clarity

Evaluate whether visitors can distinguish current development behavior from configuration, provider and platform roadmap. Covers CK-1–6.

Collect the visible status clauses and their implementation evidence. Compare qualification of the same capability against these excerpts; polished copy does not establish availability.

Anchors:

- `score_2`:
  ```text
  Atalho personalizável: disponível.
  ```
- `score_4`:
  ```text
  Atalho personalizável: planejado; protótipo atual usa Right Option.
  ```
- `contrast`: The customization claim carries its actual planned status.

### Honest Download Path

Evaluate whether the next action matches verified artifact/destination availability, including unavailable platform and source/store states. Covers CK-6, CK-7 and CK-15.

Collect platform CTA semantics, synthetic availability checks and browser request traces. Compare absent-artifact behavior against the anchors; a real local development app is not a distributable release.

Anchors:

- `score_2`:
  ```text
  macOS: Download (sem versão/artefato).
  ```
- `score_4`:
  ```text
  macOS: download público indisponível.
  ```
- `contrast`: A missing artifact produces an unavailable state instead of Download.

### Original Resenha Identity

Evaluate independently authored content and assets, using Willow's explanation/FAQ/platform patterns as functional reference only. Covers CK-8.

Inspect original copy and asset provenance against the benchmark research. Place the evidence against these excerpts; similarity to Willow's protected expression earns no credit.

Anchors:

- `score_2`:
  ```text
  Proveniência da composição do hero Resenha: reprodução da composição do hero Willow, com o nome substituído.
  ```
- `score_4`:
  ```text
  Proveniência da composição do hero Resenha: composição original de uma nota pautada recebendo uma frase, com legenda de prévia ilustrativa.
  ```
- `contrast`: The recorded hero composition is independently authored instead of reproduced; changing the brand name alone does not demonstrate originality.

### Accessible Navigation

Evaluate access to the same product/download explanation on small screens, with keyboard or assistive technology and without motion dependency. Covers CK-9 and CK-10.

Collect keyboard focus traces, semantic names, responsive screenshots and accessibility checks. Compare usable navigation with the anchors rather than evaluating decorative visual style.

Anchors:

- `score_2`:
  ```text
  Tab: link Downloads sem foco visível.
  ```
- `score_4`:
  ```text
  Tab: link Downloads com foco visível.
  ```
- `contrast`: The Downloads link has visible keyboard focus.

### Truthful Discoverability

Evaluate whether served metadata describes the same product and availability as visible content. Covers CK-11.

Inspect document language, title, description, share metadata and any structured data. Compare the platform/status assertion against these excerpts without inventing a public domain.

Anchors:

- `score_2`:
  ```text
  Meta description: aplicativo disponível para macOS e Windows.
  ```
- `score_4`:
  ```text
  Meta description: ditado local-first em desenvolvimento, macOS primeiro.
  ```
- `contrast`: The description qualifies development instead of advertising unavailable platforms.

### Measured Rendering Cost

Evaluate the documented local production-preview rendering measurements and the causes of unnecessary resource cost. Covers CK-12.

Collect environment/preset, runs and trace artifacts for LCP, CLS and TBT. Compare measured rendering outcomes with the anchors; local lab evidence does not imply field traffic results.

Anchors:

- `score_2`:
  ```text
  LCP no relatório local: 4.0 s.
  ```
- `score_4`:
  ```text
  LCP no relatório local: 2.0 s.
  ```
- `contrast`: The local measured LCP meets the stated target.

### Project Guidelines Alignment

Evaluate local validation, native scope preservation, credential/cost restraint and minimal reuse against the owner's AGENTS instructions, existing README and native M0 constitution. Covers CK-13–19.

Collect exact commands, evidence revision and relevant diff. Binding native/owner rules outweigh stylistic preferences. New website positioning does not authorize a native cloud provider or an external release action.

Anchors:

- `score_2`:
  ```text
  Validação local: testes executados fora de mac-gate.
  ```
- `score_4`:
  ```text
  Validação local: testes executados via mac-gate.
  ```
- `contrast`: Local checks execute through the shared mac-gate.

**Test Strategy:**

**Criticality:** MEDIUM-HIGH. Misstated capability or enabled nonexistent downloads can mislead prospects. Verify finite availability decisions and local browser paths; no real provider calls, personal keys, native installation or external publication is needed.

**Test Matrix:**

| Type | Size | Framework | Dependencies | Gate |
|---|---|---|---|---|
| unit | small | Node `node:test` + `node:assert/strict` in `Scripts/site.test.mjs` | Exact resolver exported by `site/release.mjs`; finite synthetic records | `mac-gate node --test Scripts/site.test.mjs` |
| integration | medium | Node HTTP/markup assertions in the same test file | `Scripts/site.mjs` loopback server; no remote dependency | Same stdlib gate, including root and `/resenha/` mount |
| e2e | medium | Plain Node audit runner using Playwright, `@axe-core/playwright` and Lighthouse; no test framework | `Tools/site-audit/audit.mjs`; local Chromium/site only | `mac-gate node Tools/site-audit/audit.mjs --browser` and `--lighthouse` |

**Tooling and evidence ownership:** These are planned files/commands, not claims of executed checks. `Tools/site-audit/package.json` contains only the three dev dependencies named above at exact compatible versions selected at implementation; commit the corresponding lockfile. Bootstrap once with `npm install --prefix Tools/site-audit --save-dev --save-exact playwright @axe-core/playwright lighthouse`; subsequent setup uses `npm ci --prefix Tools/site-audit`, followed by `Tools/site-audit/node_modules/.bin/playwright install chromium`. No npm/framework runtime belongs to `site/`. Registry/browser downloads are setup traffic, not visitor traffic or paid AI calls. The audit runner launches the installed browser itself and always closes its own resources. Missing tools are blockers, never passing skips.

`Scripts/site.test.mjs` exports the named fixture catalogue below and registers its Node tests only when executed as the test entrypoint. The browser runner imports the same catalogue without executing the test suite. Production `site/release.mjs` contains no fixture selector or query-string override. Test-only records use reserved `example.invalid` paths where possible; host-restricted positives use syntactically representative GitHub/Apple URLs whose requests are intercepted and never fetched. The evidence document owns the CK-to-command/artifact matrix, manual copy/provenance findings and any unresolved blocker; raw results remain in ignored `build/site-audit/`.

Lighthouse uses the locally served static files directly because this site has no compilation or separate production bundle. Run three mobile audits serially with the same recorded browser/version, viewport and throttling preset. Record per-run metrics plus medians; do not run native gates concurrently. Browser coverage includes Chromium automation and a local Safari/WebKit smoke observation where available; inability to execute a required case remains explicit rather than being inferred from screenshots.

**Test Cases to Cover**

#### CK-1: Core workflow

- [e2e] Given the local homepage, read the hero/workflow and identify hold, speak, release and insertion at the original cursor.

#### CK-2: Evidenced claims

- [e2e] Given current M0 evidence, inspect all visible claims and find current/roadmap qualification with no fabricated metric, testimonial, certification, integration or universal compatibility statement.

#### CK-3: Hotkey configuration status

- [e2e] Given the fixed-hotkey prototype, inspect configuration content and find Right Option as current behavior and customization as planned.

#### CK-4: Provider tradeoffs

- [e2e] Given local M0 and planned BYOK, inspect provider guidance and identify whisper.cpp local inference, optional OpenAI transfer, user key and separate usage cost; no key input or transcription request exists on the site.

#### CK-5: Source/license/architecture status

- [integration] Given served product content without published source/license evidence, verify Apache 2.0 and SwiftUI/WinUI/shared-Rust statements are correctly qualified rather than presented as a completed public release.

#### CK-6: Platform availability

- [e2e] Given macOS development evidence, inspect download information and find macOS development requirements plus Windows-later status; the Homebrew development setup is not labeled a self-contained release.

#### CK-7: Destination gating

- [unit] Given a synthetic verified-release record with matching version/platform and permitted destination, resolve the correct active link; the fixture does not enable a real release claim.
- [unit] Given missing version, platform, artifact evidence or URL, verify each named partition stays inactive.
- [unit] Given a planned/unavailable platform, verify the action stays inactive even if a candidate URL is present.
- [unit] Given an empty, malformed or unsafe destination such as a script URL, verify inactive state; malformed release state fails closed.
- [unit] Use one finite fixture catalogue: `unavailable`, `planned-with-url`, `missing-url`, `empty-url`, `whitespace-url`, `malformed-url`, `http-url`, `javascript-url`, `data-url`, `file-url`, `credentialed-url`, `wrong-host`, `missing-evidence`, `evidence-url-mismatch`, `unknown-state`, `unknown-channel`, `unknown-platform`, `missing-version`, `missing-architecture`, `missing-minimum-os`, `artifact-platform-mismatch`, `artifact-version-mismatch`, `missing-evidence-channel`, `missing-evidence-url`, `missing-verified-at`, `missing-artifact`, `missing-artifact-platform`, `missing-artifact-version`, `valid-macos-release`, `valid-public-source`, and `valid-published-store`. The first 28 resolve inactive; the last three resolve active synthetic actions. Every missing required field is exercised separately, not only in an all-empty record.
- [integration] Given absent source/store destinations, inspect served output and confirm no fake, empty or unrelated external link is rendered.
- [e2e] Given unavailable downloads, click the action and confirm no request/navigation or download occurs; repeat with keyboard activation as a separate check.

#### CK-8: Original content

- [e2e] Given the local site assets/copy, verify recorded provenance identifies independently authored Resenha materials; an illustrative or planned demo carries a visible label and no copied Willow expression.
- [e2e] Compare the complete page with benchmark research: independently authored hero/copy, different page composition and original illustration must all be documented. A replaced wordmark alone does not satisfy CK-8; do not download competitor assets for comparison.

#### CK-9: Responsive bounds

- [e2e] At 320, 768 and 1440 CSS pixels, verify essential text/actions remain readable with no horizontal overflow; repeat at 200% zoom.
- [e2e] Record actual browser zoom or a manual local 200% zoom observation; changing screenshot/device pixel ratio alone is not zoom evidence. The browser runner emits screenshots and document/viewport widths for each automated size, while the evidence record names the browser and method for the zoom observation.
- [e2e] For every implemented responsive breakpoint B, test B-1, B and B+1 pixels; inspect 319/320/321 around the required minimum width, with the no-overflow guarantee applying from 320.

#### CK-10: Accessible controls

- [e2e] Navigate to download information using keyboard only and verify named controls, visible focus, logical order and no focus traps.
- [e2e] Exercise FAQ and navigation under reduced motion; verify essential content does not depend on animation or hover.
- [e2e] Run the local accessibility audit and inspect semantic headings/landmarks, relevant alt text and AA text/control contrast; resolve serious/critical findings in the delivered surfaces.

#### CK-11: Accurate metadata

- [integration] Load sales/download surfaces directly and verify pt-BR language, meaningful title/description and status-consistent share metadata.
- [integration] Given no authorized public domain, verify canonical metadata does not fabricate one; any structured data omits invented ratings, prices and availability.

#### CK-12: Rendering performance

- [e2e] Run three local production-preview Lighthouse mobile audits with environment/preset recorded; check median LCP <=2.5 seconds, CLS <=0.1 and TBT <=200 milliseconds and retain lab artifacts.

#### CK-13: Local-only scope

- [e2e] Inspect navigation/network traces and change evidence; confirm no visitor collection, key submission, paid provider call, remote creation, publication, deployment or store submission occurred.

#### CK-14: Native preservation

- [e2e] Compare the scoped diff with the native baseline and confirm no pipeline/output/provider/permission/signing changes; site results leave pending native acceptance pending.

#### CK-15: Single status ownership

- [integration] Given identical unavailable/available synthetic records, verify hero/navigation/download actions resolve consistent status from the same owner.
- [integration] Confirm navigation/hero use the same local `#download` destination and all external action slots consume the single exported resolver/config. With JavaScript disabled, essential copy and unavailable explanations remain present and no external CTA becomes active.

#### CK-16: Complete verification

- [integration] Map every selected type and named main/edge/error case to executed passing checks with exact commands and tested revision; no uncovered checklist group remains.
- [integration] Exercise the loopback preview at `/` and `/resenha/`: assets use relative paths and correct MIME types; GET/HEAD work; traversal, symlink escape, malformed URL encoding and unsupported methods do not expose files or crash the server. Fixtures for these checks use an isolated temporary directory, never the user's private files.

#### CK-17: Existing conditional gate

- [integration] If native/shared configuration was touched, execute the actual discovered mac-gate xcodebuild test command and retain a zero-failure result for that revision; if untouched, verify absence of native/configuration edits and record the gate as not applicable.

#### CK-18: Bounded cleanup

- [integration] Inspect changed source and verify any cleanup belongs to the site rather than unrelated native refactoring.

#### CK-19: Architecture reuse

- [integration] Inspect applicable architecture reuse directives and verify the implementation calls/imports the identified behavior; record not applicable when no reusable web behavior exists.

**Definition of Done:**

- [X] All essential checklist conditions and Regular Checks pass; exact local commands, tested revision and browser/performance evidence are recorded.
- [X] The local sales/download surfaces explain workflow, hotkey/provider direction, privacy/cost tradeoffs, source/license goals and macOS-first/Windows-later status using independently authored Resenha content.
- [X] All selected test types and named cases pass, including unavailable destination partitions, keyboard activation, responsive bounds, metadata and local performance targets.
- [X] Download/source/store controls reflect verified availability; absent destinations remain inactive and clearly explained without fabricated releases or public links.
- [X] Native behavior and pending acceptance remain intact; public GitHub/publication and App Store submission remain later external tasks, with no paid calls or visitor-data collection added.

## Architecture Overview

### References

- Research: [open-source dictation site skill](../../../.claude/skills/open-source-dictation-site/SKILL.md).
- Codebase: [impact analysis](../../analysis/analysis-build-resenha-sales-site.md).
- Design decisions: [architecture record](../../scratchpad/e328f599.md).

### Solution Strategy

**Architecture Pattern:** Static document with progressive enhancement. The repository has no web runtime and this product surface needs neither an application framework nor a backend. Deliver one pt-BR document at `site/index.html` with a first-class `#download` section; links and assets are relative so the same files can later be hosted under a repository subpath.

**Key decisions:**

1. One sales/download document with native anchors and `details`/`summary` for FAQ. Core content is present before JavaScript; no router, template engine, compilation, form, microphone request or transcription demo runtime.
2. One small release module owns all external destination data and resolution. Navigation/hero lead to `#download`; source, platform and store action slots consume that module. Default HTML shows readable unavailable status without fake links.
3. Original HTML/CSS illustration, system typography and inline decorative SVG. No imported screenshots, competitor assets, fonts or animation dependencies; an explicit “Prévia ilustrativa” caption accompanies the composed dictation example.
4. Node stdlib serves and checks the local files. Playwright/axe/Lighthouse are isolated development audit dependencies under `Tools/site-audit/`; the shipped `site/` tree has zero third-party runtime dependencies.
5. Native sources, tests, bundle identity and build configuration remain separate. README bridges public Resenha branding to internal WhisperKey development instructions. Public repository, licensing publication, releases and store listing remain later work.

**Trade-offs:** A single document has no separate download-page title or route; its download section is directly addressable by fragment. Release-link enhancement fails closed if JavaScript fails. Future release activation is an explicit editorial update backed by evidence, not an automatic API lookup. No scripted demo means the illustration explains the flow without suggesting actual browser transcription.

### Components and Flow

| Component / path | Responsibility | Dependencies / reuse |
|---|---|---|
| `site/index.html` | Complete semantic product document, status labels, FAQ and external-action slots | New web document; reuses verified native docs as facts, not executable Swift |
| `site/styles.css` | Original typography, color/spacing tokens, layout and focus/motion presentation | CSS/platform primitives; no existing stylesheet to reuse |
| `site/release.mjs` | Authored release records, pure destination resolution and small DOM enhancement | Standard `URL` and DOM; no external imports |
| `Scripts/site.mjs` | Loopback static preview with exported server lifecycle | Node `http`, `fs`, `path`; serves only `site/` |
| `Scripts/site.test.mjs` | Finite fixture catalogue and stdlib checks | Imports exact release resolver and preview server; shared fixtures are reused by audit runner |
| `Tools/site-audit/audit.mjs` | Browser/audit orchestration and local evidence output | Imports shared fixture catalogue/server; dev-only Playwright/axe/Lighthouse |
| `docs/testing/RESENHA-SITE-EVIDENCE.md` | Claim provenance and implementation evidence record | Existing native evidence remains separate |

```text
authored release records → pure resolver → marked HTML action slots
complete static HTML ───────────────────→ usable no-JS document
site/ → loopback preview → stdlib + browser audits → local evidence
```

`site/release.mjs` exports `releaseState`, `resolveDestination(channel, record)` and `applyReleaseState(root, state)`. Node imports do not touch the DOM; browser boot calls the adapter only when `document` exists. The adapter accepts an explicit root/state, avoiding global fixture switches. No new classes, provider adapters or general-purpose utilities are needed.

`Scripts/site.mjs` exports `createPreviewServer({root, prefix, port})` with an explicit close handle and supports `node Scripts/site.mjs --serve --port 4173 --prefix /`. It binds `127.0.0.1`, serves GET/HEAD and correct HTML/CSS/module MIME types, and refuses decoded traversal, paths escaping the real site root, symlink escapes, malformed escapes and unsupported methods. An optional `/resenha/` prefix serves the identical static files. It cannot expose the repository, native build outputs or local credentials.

### Release Contract

The single exported `releaseState` contains three independent records: `macos`, `source`, `store`; Windows remains explicit planned content. Each record has `state` (`unavailable`, `planned`, `published`), nullable `url` and nullable `evidence`. Initial authored values are unavailable/planned with null URLs/evidence. There is no publishable artifact in the inspected baseline.

`resolveDestination(channel, record)` returns an immutable presentation value: `active`, `href` (URL or null), `label`, and `reason`. Unknown/missing values resolve inactive. A published record requires nonempty evidence with matching `channel`, exact `url` and `verifiedAt`; authored evidence is maintained by the later release/publication task from a real inspected destination, never fabricated by this site task.

The URL is an absolute HTTPS URL with no credentials. Source and release destinations use `github.com` with repository paths; release download paths name a concrete tagged release asset rather than a branch archive or `/latest` shortcut. Store URLs use `apps.apple.com` and a concrete product ID. A macOS release additionally carries nonempty `version`, `architecture`, `minimumOS` and artifact evidence with matching version and `platform: macos`. Source/store publication is independent of whether an installer exists. This authored metadata check is a publication guard, not a claim that a client-side boolean proves release authenticity.

Raw URLs are assigned only after resolution, using DOM properties/text nodes rather than interpolated HTML. Inactive action slots are readable status elements; no empty href, `href="#"`, fake Store badge or click handler that silently does nothing. The finite acceptance fixtures and their single owner are specified under Acceptance Criteria.

### Original Visual Direction

Use an editorial “spoken note becoming written text” composition: generous warm-neutral canvas, charcoal typography, one restrained rust accent and a left-aligned product statement beside a ruled-note illustration. The illustration shows a short Portuguese sentence, a compact locally inspired HUD and the three actions “segure / fale / solte”; it is a composed explanation rather than an app screenshot. Below it, use an open capability/status ledger and a practical platform/download panel, followed by the FAQ.

The first screen emphasizes the product sentence and working “Conhecer o Resenha” / “Disponibilidade” anchors. Feature/configuration rows pair each capability with its own current/planned label. Local processing and future optional cloud occupy a clear comparison with the cost/transfer explanation adjacent. Avoid competitor card composition, testimonial strips, app-logo grids, copied hero proportions, marketing metrics and decorative fake controls. The wordmark is plain independently styled Resenha text; decorative graphics use simple inline shapes, not a generated or purchased asset pipeline.

### Expected Changes

| Operation | Paths | Purpose |
|---|---|---|
| Create | `site/index.html`, `site/styles.css`, `site/release.mjs` | Dependency-free delivered surface |
| Create | `Scripts/site.mjs`, `Scripts/site.test.mjs` | Local serving, finite fixtures and standard-library checks |
| Create | `Tools/site-audit/package.json`, `Tools/site-audit/package-lock.json`, `Tools/site-audit/audit.mjs` | Reproducible dev-only browser/audit tools |
| Create | `docs/testing/RESENHA-SITE-EVIDENCE.md` | Local evidence and source/claim provenance |
| Modify | `README.md`, `.gitignore` | Append preview/setup commands; ignore `Tools/site-audit/node_modules/`; preserve existing instructions and ignores |

Nine created files, two modified files, no deletions; generated browser reports use existing ignored `build/`. The extra audit files extend the analysis's smaller tentative footprint because the accepted task explicitly requires Playwright/accessibility/Lighthouse. No site assets folder or demo script is added; inline artwork/static explanation cover those needs. No native/configuration, remote, deployment, license-publication or release files are changed.

## Implementation Process

You MUST launch for each step a separate agent, instead of performing all steps yourself. And for each step marked as parallel, you MUST launch separate agents in parallel.

**CRITICAL:** For each agent you MUST:

1. Use the **Model** and **Agent** type specified in the step's sub-task file.
2. Provide the path to THIS task file AND the path to that step's sub-task file, plus `CLAUDE_PLUGIN_ROOT`.
3. Require the agent to implement exactly that step, not other steps, and preserve unrelated/native work.

**CRITICAL:** Verification is done at PHASE level, not per step. When every step of a phase is complete, you MUST launch `sdd:code-reviewer` ONCE for that phase, at the **Reviewer model** named in the Phase Overview. Resolve any phase findings before proceeding.

Parallel agents own the paths named in their sub-task files. Do not run integration gates against a moving tree: wait for both Phase 1 agents to stop writing, then share one serialized `mac-gate node --test Scripts/site.test.mjs` result. Phase 2 consumes that reviewed runnable site. All validation uses mac-gate; native validation is conditional on actual native/shared configuration changes. This task ends with local evidence, without native roadmap implementation, paid calls, remote creation, release/publication, deployment or store submission.

### Parallelization Overview

```text
Phase 1 — complete static page and safe local boundary
  01-static-product-page             02-release-preview-boundary
  [sdd:developer / sonnet]           [sdd:developer / sonnet]
          independent editing, fixed contract, width 2
                \                       /
             settled stdlib gate + Phase 1 review
                            |
Phase 2 — browser verification and accurate local handoff
                     03-browser-audit
                 [sdd:developer / sonnet]
                            |
                  04-evidence-and-usage
                [sdd:tech-writer / sonnet]
                            |
                    Phase 2 review
```

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
|---|---|---|---|---|---|---|
| `01-static-product-page` [DONE] | 1 | sonnet | sdd:developer | None | `02-release-preview-boundary` | [.specs/sub-tasks/build-resenha-sales-site/01-static-product-page.md](../../sub-tasks/build-resenha-sales-site/01-static-product-page.md) |
| `02-release-preview-boundary` [DONE] | 1 | sonnet | sdd:developer | None | `01-static-product-page` | [.specs/sub-tasks/build-resenha-sales-site/02-release-preview-boundary.md](../../sub-tasks/build-resenha-sales-site/02-release-preview-boundary.md) |
| `03-browser-audit` [DONE] | 2 | sonnet | sdd:developer | `01-static-product-page`, `02-release-preview-boundary` | None | [.specs/sub-tasks/build-resenha-sales-site/03-browser-audit.md](../../sub-tasks/build-resenha-sales-site/03-browser-audit.md) |
| `04-evidence-and-usage` [DONE] | 2 | sonnet | sdd:tech-writer | `03-browser-audit` | None | [.specs/sub-tasks/build-resenha-sales-site/04-evidence-and-usage.md](../../sub-tasks/build-resenha-sales-site/04-evidence-and-usage.md) |

Dependencies name actual consumed artifacts; phase review is an additional barrier. The first two steps apply the accepted data-slot/export contract without shared-file edits. Browser audits require both the rendered page and tested preview/resolver/fixtures; final documentation requires actual audit reports. Peak concurrent width is 2.

### Phase Overview

#### Phase 1 — Runnable static sales/download document [REVIEWED]

**Steps:** `01-static-product-page`, `02-release-preview-boundary`.
**Reviewer model:** opus.
**Acceptance Criteria that should be fulfiled:** A complete original pt-BR page serves locally at root and repository prefix, works without JavaScript, explains truthful current/planned capabilities and unavailable destinations, and passes the finite stdlib resolver/HTTP/metadata checks. The native before-manifest and claim/provenance report permit inspection without changing the application. Required browser/accessibility/zoom/performance acceptance is due in Phase 2 and is not inferred here.

**Checklist items:**

- CK-1–5 — workflow, capability evidence, current fixed/planned configurable hotkey, local/planned BYOK and source/license/architecture status.
- CK-6–8 — platform development requirements, fail-closed destinations and original/labeled content.
- CK-11 — status-consistent pt-BR document and share metadata without invented public identity.
- CK-13–15 — local-only scope, native preservation and single release/status owner; served-output and source evidence at this checkpoint.
- CK-17–19 — conditional native gate or manifest-backed not-applicable result, bounded site cleanup and applicable architecture reuse.

**Rubrics:**

- Capability Status Clarity; Honest Download Path.
- Original Resenha Identity.
- Truthful Discoverability.
- Project Guidelines Alignment.

**Verification artifact:** Runnable `node Scripts/site.mjs --serve --port 4173 --prefix /` page, `/resenha/` serving checks, passing `mac-gate node --test Scripts/site.test.mjs`, the exact finite fixture catalogue and local claim/provenance/native-before reports. Reviewer opus checks essential mixed content/control/path boundaries; both producer steps remain typical sonnet implementations of fixed contracts.

#### Phase 2 — Verified browser behavior and evidence handoff [REVIEWED]

**Steps:** `03-browser-audit`, `04-evidence-and-usage`.
**Reviewer model:** opus.
**Acceptance Criteria that should be fulfiled:** The same runnable static page passes the complete accepted case catalogue with raw browser/accessibility/zoom/performance evidence, accurately documented commands and provenance, and preserved native state. Three serial local mobile Lighthouse runs satisfy the recorded medians. Missing required observations/tools remain concrete blockers to completion; public distribution and native human acceptance remain separate tasks.

**Checklist items:**

- CK-1–8 — final observed workflow/status/provider/license/platform claims, complete destination partitions and independently authored assets.
- CK-9–10 — required widths/breakpoint boundaries/actual zoom, keyboard/FAQ/focus, no-JS/reduced-motion behavior, semantics/alternatives and accessibility contrast.
- CK-11–12 — direct served metadata and three local mobile Lighthouse runs with recorded presets, versions and medians.
- CK-13–15 — request/publication/data-collection boundaries, manifest-backed native preservation and actual shared adapter consistency.
- CK-16–19 — complete case-to-command/artifact evidence matrix, conditional native gate, bounded cleanup and architecture reuse.

**Rubrics:**

- Capability Status Clarity; Honest Download Path.
- Original Resenha Identity.
- Accessible Navigation.
- Truthful Discoverability; Measured Rendering Cost.
- Project Guidelines Alignment.

**Verification artifact:** `docs/testing/RESENHA-SITE-EVIDENCE.md` and appended README instructions, passing stdlib/`--browser`/`--lighthouse` commands, raw artifacts under `build/site-audit/`, exact tested fingerprints and before/after native manifests. Reviewer opus evaluates essential mixed browser/content/evidence conditions; missing required cases cannot be closed from another evidence type.
