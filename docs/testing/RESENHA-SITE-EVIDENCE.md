# Resenha — local site evidence

Review the locally runnable site and reproduce its checks from the repository root. Results below identify exact files, not a public release. Recorded 2026-10-02; browser/Lighthouse evidence was produced by Step 03, then independently checked during Step 04. No required site case is unresolved. A later native TextEdit test passed the physical core flow and exposed `Resenha → resenho`; site evidence does not certify native compatibility or distribution.

## Tested revision and environment

The repository has no HEAD. SHA-256, rather than a fabricated commit, identifies the tested revision. Browser and Lighthouse manifests match each other and the current files. Their raw `environment.json` records are under `build/site-audit/{browser,lighthouse}/`.

| File | SHA-256 |
|---|---|
| `site/index.html` | `000e09416587a56230fe6d330a2cb0b3a7c96d4027e24cebe8346b0ef63a9c1e` |
| `site/styles.css` | `108c27a103465a946f87f81d223da01e419d5046646e107d0b32668b6c6a7cbc` |
| `site/release.mjs` | `1c2d916ebe7509763fe5c15417ea8cf5c56fc9cb66686cf703beb136de7042fa` |
| `Scripts/site.mjs` | `bc3f426e3527638f9bc8a47796917e5c6bacbf3f4596411acdd7a78672083c50` |
| `Scripts/site.test.mjs` | `3638d2608c76b9bab6f41a64a1f2f74d835dcf4aeca0cf48ed0698ef372187a6` |
| `Tools/site-audit/audit.mjs` | `65434b0c0dda41a921f622884f1db6f630febace6918f882f46d85778c3a31c5` |
| `Tools/site-audit/package.json` | `c06ec4e6059614422c95269c4db716372e953f909791607526495e682d36097c` |
| `Tools/site-audit/package-lock.json` | `de6e88a96536a332bcc755846a429e9f9ef1037f7f01637e08d861131174cd75` |

Environment: Node v26.5.0; darwin 25.1.0 arm64; Playwright 1.63.0; @axe-core/playwright 4.13.0; Lighthouse 13.5.0; Chromium 153.0.8010.12; local Playwright WebKit 26.6. Browser finished 19:52:15.359 UTC; Lighthouse finished 19:52:32.551 UTC. Browser summary: **139 PASS / 0 FAIL**; Lighthouse summary: **6 PASS / 0 FAIL**. Static stdlib gate: **37 PASS / 0 FAIL / 0 skipped**. Raw output directories are intentionally ignored by git; retain them locally with this evidence.

## Commands and execution ownership

| ID | Exact command / check | Observed result |
|---|---|---|
| S | `~/.local/bin/mac-gate node --test Scripts/site.test.mjs` | Step 03 and Step 04: 37 PASS / 0 FAIL / 0 skipped |
| B | `~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --browser` | Step 03: 139 passing; `browser/results.json`, `summary.json` |
| L | `~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --lighthouse` | Step 03: three serial runs and six passing assertions; `lighthouse/results.json`, `median-summary.json` |
| N | `~/.local/bin/mac-gate shasum -a 256 -c build/site-audit/native-before.sha256` | Step 03: 19/19 OK; Step 04 independently enumerated/hashes every scoped file, then checked `native-after.sha256`: 19/19 OK |
| D | Documentation smoke below, through mac-gate | PASS D1–D5: CLI root/subpath, matrix, paths, claims, manifests and README append-only preservation |

Accepted bootstrap was executed by Step 03: `~/.local/bin/mac-gate npm install --prefix Tools/site-audit --save-dev --save-exact playwright @axe-core/playwright lighthouse`. Repeatable setup is `~/.local/bin/mac-gate npm ci --prefix Tools/site-audit`, then `~/.local/bin/mac-gate Tools/site-audit/node_modules/.bin/playwright install chromium webkit`. Both were executed successfully by Step 03; bootstrap is not needed again and is not a release/build step.

Step 03's final serialized invocation was `~/.local/bin/mac-gate sh -c 'npm ci --prefix Tools/site-audit && node Tools/site-audit/audit.mjs --browser && node Tools/site-audit/audit.mjs --lighthouse && node --test Scripts/site.test.mjs && shasum -a 256 -c build/site-audit/native-before.sha256'` (exit 0). The unchanged producer hashes justify retaining those raw runs; Step 04 does not overwrite them with redundant browser/performance runs. Setup traffic to registries/browser downloads is separate from visitor traffic; no paid AI call or credentials were used. Full handoff: `build/site-audit/step-03-report.md`.

Step 02 handoff was checked against its actual delivered resolver/server/tests and the reviewed Phase 1 record `.specs/scratchpad/f271cc8d-resenha-phase1-review.md` (37 passing tests, 19 native hashes, no functional gap). No separate Step 02 report file was found or fabricated; Step 04 reran the delivered suite rather than treating a missing prose report as execution evidence.

## Claims, destinations and original provenance

| Surface | Observed status and supporting fact |
|---|---|
| Hero/workflow | Hold Right Option, speak, release, insert at original cursor; native HotkeyMonitor keycode 61, DictationCoordinator and TextInjector implement this development flow. Adjacent compatibility/validation caveat; no universally tested app claim |
| Current ledger/provider | Portuguese whisper.cpp via local CLI/model (`WhisperTranscriber` uses `-l pt`); recording meter/timer exists in native source. No account/server in current transcription flow; installation remains external development setup |
| Planned/study ledger | Customizable hotkey is explicitly planned; mic/language/dictionary/hands-free/translation are “Em estudo”, not shipped controls |
| Optional cloud | OpenAI BYOK is planned, opt-in audio transfer/user key/separate provider charges explicit. Site has no key field, microphone request or transcription runtime |
| Platforms | macOS-first development target 14+ (`project.yml`), current Apple Silicon validation caveat and separate CLI/model requirement; no independent installer. Windows/WinUI/shared Rust are future plans, requirements/date undefined |
| Source/license/store | Apache 2.0 and public-source publication are goals/preparation, not an already licensed public release; SwiftUI is current, WinUI/Rust planned; App Store listing absent |
| Metadata | pt-BR, meaningful development-qualified title/description and matching Open Graph; no public canonical domain, fake ratings/prices/offers/availability schema |
| Privacy/compatibility | Temporary audio described as intended for deletion, not guaranteed failure-proof cleanup; no current transcript history. Native acceptance and broad field support remain unproven |

Release inventory: `releaseState.macos` is unavailable; `source` and `store` are planned; all three URLs/evidence are null and resolve inactive. Windows is static planned copy, not a release channel. All real navigation/hero/closing download links are local `#download`; there are no external destination links in the default page. One resolver/config/adapter owns enhancement; unavailable HTML remains readable without JavaScript. Verified future destination activation requires real publication evidence and is outside this task.

Independent provenance review: the complete page uses an original left-aligned warm-paper/charcoal/rust editorial composition, a rotated ruled note receiving a Portuguese sentence, static capsule/waveform and open capability ledger, then processing/platform/FAQ sections. Copy and wordmark were authored for Resenha; the illustration is HTML/CSS/inline geometric SVG and visibly labeled **Prévia ilustrativa**. Meaningful text is real document text; decorative SVG/HUD/symbols are aria-hidden. No competitor screenshot, font, logo, testimonial, metric, video, copied text or generated/purchased asset was imported. Willow research supplied only functional coverage (workflow, features/configuration, privacy, platforms and FAQ), not its protected expression or hero composition. Compared against the accepted research record `.claude/skills/open-source-dictation-site/SKILL.md` and Step 01 provenance, without downloading competitor assets. Source findings agree with `browser/visible-copy.json` and full-page screenshots. Original report: `build/site-audit/step-01-report.md`.

## Complete checklist / case matrix

PASS means the specified local site case was actually checked; it does not claim future public destinations or native human acceptance. Main, edge and error partitions are expanded below, not collapsed into a happy-path screenshot.

| CK | Type | Cases and result | Command / artifacts (under `build/site-audit/` unless stated) |
|---|---|---|---|
| CK-1 | e2e | PASS: hero and hold/speak/release/original-cursor workflow at both mounts | B honest-content root/subpath; `browser/visible-copy.json`; provenance above |
| CK-2 | e2e | PASS: complete visible claims current/planned qualified; no invented metrics/reviews/certification/integrations/universal support | B honest-content; independent claim/source review above |
| CK-3 | e2e | PASS: fixed Right Option current, customization planned | B honest-content; visible-copy; native keycode/source review |
| CK-4 | e2e | PASS: current local vs optional planned BYOK; opt-in transfer/key/cost; no collection/transcription controls | B honest-content/network; provider inventory |
| CK-5 | integration | PASS: source/license/SwiftUI/WinUI/Rust qualification, no fabricated public release | S actual-document test at root/subpath; B content; inventory |
| CK-6 | e2e | PASS: macOS development requirements versus installer; Windows later | B content at both mounts; platform inventory |
| CK-7 | unit/integration/e2e | PASS: all 31 finite cases; malformed/empty/unsafe/missing evidence; real source/store absent; separate inactive mouse and keyboard; synthetic positive interception | S CK-7 tests; B adapter/mouse/keyboard per-fixture; fixture table below; network trace |
| CK-8 | e2e | PASS: complete original copy/composition/artwork provenance and labeled simulation; benchmark comparison | B content; independent review above; Step 01 report; `browser/root-1440.png` |
| CK-9 | e2e | PASS: 320/768/1440, minimum and every breakpoint boundary; genuine 200% browser zoom, no clipping/overflow | B width/zoom cases; `{root,subpath}-{width}.{json,png}`; `actual-zoom-200-observation.json` |
| CK-10 | e2e | PASS: keyboard names/order/focus/no trap; seven FAQ; motion/no-JS; landmarks/decorative alternatives and AA contrast; local WebKit | B keyboard/FAQ, axe, motion, no-JS, WebKit; focus/contrast reports below |
| CK-11 | integration | PASS: direct root/subpath/download-fragment content and truthful pt-BR/share metadata; no fabricated canonical/schema | S actual-document; B honest-content; metadata inventory |
| CK-12 | e2e | PASS: three identical-preset serial local mobile runs; all median targets met | L `mobile-{1,2,3}.{json,html}`, `median-summary.json`; metrics below |
| CK-13 | e2e | PASS: local resources, six synthetic requests intercepted, no escaped requests; no form/key/paid API/microphone/publication | B network/unchanged cases; `browser/network-trace.json`; scoped review |
| CK-14 | e2e | PASS: exact native area inventory/hashes preserved; pending native acceptance explicitly unchanged | N/D before/after manifests; native boundary below; existing M0 evidence |
| CK-15 | integration | PASS: shared resolver/adapter across slots and local nav/hero anchors, default and synthetic state; no-JS inactive equivalence | S authored-state/actual-document; B default/adapter/no-JS root/subpath |
| CK-16 | integration | PASS: selected unit/integration/e2e and every named main/edge/error mapped; safe GET/HEAD root/subpath/error recovery | S 37 cases; B 139 cases; L six assertions; D completeness/path checks; HTTP partitions below |
| CK-17 | integration | NOT APPLICABLE, verified: native/shared config untouched, same complete 19-file manifests | N/D; no historical native test substituted for this conditional gate |
| CK-18 | integration | PASS: bounded site/tooling/docs/ignore work; no unrelated native cleanup | D fingerprints/native inventory and scoped output review |
| CK-19 | integration | PASS: exact release exports, shared `destinationFixtures`, shared preview lifecycle imported by tests/audit; native docs reused only as facts | S fixture-import/actual-document; B fixture/adapter; source imports inspected; no existing web runtime to duplicate |

## All 31 destination partitions

Each row passed its named `CK-7: <fixture>` stdlib unit and three separate browser adapter/mouse/keyboard checks in `browser/results.json`. Inactive cases record no navigation, no download and no intercepted destination request; active positives record locally intercepted navigation only (never a real installer/store/source fetch). Subpath adapter also passed unavailable and the three positive cases. The fixture catalogue is imported once from `Scripts/site.test.mjs`, which registers no tests when imported by the audit.

| Fixture | Resolution | Unit / adapter / mouse / keyboard |
|---|---|---|
| unavailable | inactive | PASS / PASS / PASS / PASS |
| planned-with-url | inactive | PASS / PASS / PASS / PASS |
| missing-url | inactive | PASS / PASS / PASS / PASS |
| empty-url | inactive | PASS / PASS / PASS / PASS |
| whitespace-url | inactive | PASS / PASS / PASS / PASS |
| malformed-url | inactive | PASS / PASS / PASS / PASS |
| http-url | inactive | PASS / PASS / PASS / PASS |
| javascript-url | inactive | PASS / PASS / PASS / PASS |
| data-url | inactive | PASS / PASS / PASS / PASS |
| file-url | inactive | PASS / PASS / PASS / PASS |
| credentialed-url | inactive | PASS / PASS / PASS / PASS |
| wrong-host | inactive | PASS / PASS / PASS / PASS |
| missing-evidence | inactive | PASS / PASS / PASS / PASS |
| evidence-url-mismatch | inactive | PASS / PASS / PASS / PASS |
| unknown-state | inactive | PASS / PASS / PASS / PASS |
| unknown-channel | inactive | PASS / PASS / PASS / PASS |
| unknown-platform | inactive | PASS / PASS / PASS / PASS |
| missing-version | inactive | PASS / PASS / PASS / PASS |
| missing-architecture | inactive | PASS / PASS / PASS / PASS |
| missing-minimum-os | inactive | PASS / PASS / PASS / PASS |
| artifact-platform-mismatch | inactive | PASS / PASS / PASS / PASS |
| artifact-version-mismatch | inactive | PASS / PASS / PASS / PASS |
| missing-evidence-channel | inactive | PASS / PASS / PASS / PASS |
| missing-evidence-url | inactive | PASS / PASS / PASS / PASS |
| missing-verified-at | inactive | PASS / PASS / PASS / PASS |
| missing-artifact | inactive | PASS / PASS / PASS / PASS |
| missing-artifact-platform | inactive | PASS / PASS / PASS / PASS |
| missing-artifact-version | inactive | PASS / PASS / PASS / PASS |
| valid-macos-release | active synthetic | PASS / PASS / PASS / PASS |
| valid-public-source | active synthetic | PASS / PASS / PASS / PASS |
| valid-published-store | active synthetic | PASS / PASS / PASS / PASS |

Additional S error cases passed: null/undefined/empty/string/array/malformed records, `__proto__` channel, wrong evidence channel/date, query/fragment/nonstandard port, latest shortcut, branch archive, encoded/dot/whitespace path, malformed authority, source without repository and store without concrete ID. Resolver returns frozen presentation without mutating input. These are guards, not release-authenticity verification.

## Preview, browser and accessibility observations

| Partition | Recorded PASS behavior |
|---|---|
| Root `/` and `/resenha/` | Identical served document; relative CSS/module 200 with correct MIME; GET HTML and HEAD 200/empty body; bind 127.0.0.1; imported server opens/closes explicit handle |
| HTTP path boundaries | Isolated owned temp fixtures: `../outside.txt`, `%2e%2e/outside.txt`, `%2e%2e%2foutside.txt`, `%ZZ`, `%00`, `escape.txt` symlink, `%5c..%5coutside.txt`, `/outside.txt` all denied without outside sentinel; no private user files used |
| Error/lifecycle | POST 405; missing file 404; wrong mount 404; invalid traversal prefix and port reject; valid request still 200 after errors; tests/import leave no open server |
| Responsive | Both mounts at 319/320/321, 599/600/601, 768, 899/900/901, 1440 CSS px. Breakpoints are actual 600/900 CSS media rules; all measured `scrollWidth === clientWidth`, no clipped actions. Required guarantee starts at 320; 319 is diagnostic |
| Actual 200% zoom | Isolated Chromium MV3 `chrome.tabs.setZoom(2)` + `getZoom=2`, default 1; physical browser window resizing retains zoom 2 at actual innerWidth 320/768/1440. Initial innerWidth 1440→720 demonstrates zoom. Not device-scale/CSS/page-scale substitution; screenshots are 640/1536/2880 physical px wide |
| Keyboard / FAQ | 16 controls, logical tab order/names, visible outline, section navigation and seven native FAQ controls at both mounts; `focus-trace.json`, `keyboard-faq-focus.png`, `trace-{root,subpath}.zip` |
| No JS / motion / dark | Essential text and inactive slots preserved, FAQ works; no motion dependency; root/subpath `{no-js,reduced-motion,dark}.{json,png}` |
| Axe / contrast | Four desktop/mobile mount audits: zero violations. Raw color-contrast indeterminates are resolved fail-closed in `contrast-{root,subpath}-{desktop,mobile}.json`: aria-hidden decorative shapes need no textual contrast; note text 14.39:1 on paper / 11.24:1 on darker rules, above 4.5:1. Unexpected unresolved nodes fail; no rule disabled |
| WebKit | Local Playwright WebKit 26.6 content/status/nav/FAQ/reflow smoke passed at 768; `webkit-smoke.{json,png}`. Not installed Safari UI or human VoiceOver certification |
| Network | `network-trace.json`: six positive mouse/keyboard actions intercepted locally, escaped requests 0; owned deny-only proxy blocked 16 background events. Default page resources and Lighthouse requests are loopback HTML/CSS/module only |

All browser paths above are under `build/site-audit/browser/`. Layout/zoom images include corresponding JSON viewport/document/image dimensions. Step 03 visually reinspected full desktop and corrected 200%-zoom 320 captures; initial capture clipping was fixed in tooling and rerun, not accepted as a layout pass. Step 04 compares report findings and original source/provenance without representing those images as native runtime evidence.

## Mobile Lighthouse — local lab only

Same Chromium/version/static manifest across all three serial audits. Simulated mobile preset: 412×823 CSS px, DPR 1.75, simulated throttling, RTT 150 ms, throughput 1638.4 Kbps, CPU slowdown 4; Lighthouse 13.5.0, performance category, locale pt. Full settings and local request lists are retained per run and in `median-summary.json`. No compiled production bundle exists; directly served unchanged static files are the production-preview input.

| Run | LCP ms | CLS | TBT ms | Raw report |
|---|---|---|---|---|
| 1 | 902.4740 | 0 | 0 | `lighthouse/mobile-1.json`, `mobile-1.html` |
| 2 | 902.9518 | 0 | 0 | `lighthouse/mobile-2.json`, `mobile-2.html` |
| 3 | 904.7143 | 0 | 0 | `lighthouse/mobile-3.json`, `mobile-3.html` |
| Median | **902.9518** | **0** | **0** | `lighthouse/median-summary.json` |
| Maximum accepted median | 2500 | 0.1 | 200 | All targets met |

These are local laboratory measurements, not production-user Core Web Vitals, traffic metrics or certifications.

## Native preservation and scope

Step 01 captured `build/site-audit/native-before.sha256`; Step 04 independently enumerated/hashes the complete current `Sources/`, `Tests/`, `Config/`, `project.yml`, `WhisperKey.xcodeproj/`, excluding xcuserdata/xcuserstate. `build/site-audit/native-after.sha256` contains the resulting 19 files. Exact inventories and hashes match; no added, removed or modified native/shared configuration path or concurrent native difference was found. No unavailable git baseline was used. The conditional canonical xcodebuild gate is **not applicable**, not an unexecuted PASS. Native historical 35-test/fixture evidence remains separate in [M0 evidence](M0-EVIDENCE.md) and [UI evidence](UI-REFINEMENT-EVIDENCE.md).

Step 04 edited only this evidence and an appended README section, plus ignored verification artifacts. Earlier site/tooling hashes remain unchanged. No framework/backend/build/runtime package, visitor collection, secret/key handling, AI request, external remote/publication/deployment/store action or unrelated cleanup was introduced. Public GitHub/license/release/App Store work remains separately authorized future work. The later native TextEdit pass is recorded separately in [M0 evidence](M0-EVIDENCE.md); output fidelity continues in SPEC-011.

## Documentation smoke cases

Case D1 checks the exact documented preview CLI twice (root and `/resenha/`, port 4173), local assets and exit/cleanup. D2 compares audit fingerprints, result summaries and 31 × 3 named browser checks. D3 checks CK-1–19 mapping, required paths and current/planned/absence statements. D4 compares complete native inventories/hashes. D5 validates README append-only prefix hash and relative documentation links. Setup/B/L commands were successfully executed by Step 03 against these same hashes; they are consumed evidence, not claimed to be rerun by Step 04.

Execute this smoke code block from the repository root under mac-gate (for example, pass the block to `~/.local/bin/mac-gate node --input-type=module` on stdin). It never fetches an external destination or invokes native work; it closes only its own preview subprocess. Port collision is a failure, not authority to kill another user's process.

```javascript
// documentation-smoke
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { resolve, dirname } from 'node:path';
import { destinationFixtures } from './Scripts/site.test.mjs';
import { releaseState, resolveDestination } from './site/release.mjs';
const read = p => readFileSync(p, 'utf8');
const hash = p => createHash('sha256').update(readFileSync(p)).digest('hex');
const json = p => JSON.parse(read('build/site-audit/' + p));
const evidence = read('docs/testing/RESENHA-SITE-EVIDENCE.md');
const readme = read('README.md');
const oldReadme = readme.split('\n## Resenha local sales/download site\n')[0];
assert.equal(createHash('sha256').update(oldReadme).digest('hex'), 'f02c0dec24f3023a8938102e27614be301db9590e52f1e0339067aa7b6780f9f');
for (let n = 1; n <= 19; n++) assert.ok(evidence.includes('| CK-' + n + ' |'));
const env = json('browser/environment.json');
assert.deepEqual(env.fingerprints, json('lighthouse/environment.json').fingerprints);
for (const [p, h] of Object.entries(env.fingerprints)) assert.equal(hash(p), h);
const results = json('browser/results.json');
assert.equal(results.length, 139);
assert.ok(results.every(r => r.status === 'PASS'));
assert.equal(json('browser/summary.json').failed, 0);
assert.equal(json('lighthouse/summary.json').failed, 0);
assert.equal(destinationFixtures.length, 31);
for (const fixture of destinationFixtures) {
  assert.ok(evidence.includes('| ' + fixture.name + ' |'));
  assert.equal(resolveDestination(fixture.channel, fixture.record).active, fixture.active);
  for (const kind of ['adapter', 'mouse', 'keyboard'])
    assert.ok(results.some(r => r.name === 'CK-7 ' + kind + ' ' + fixture.name && r.status === 'PASS'));
}
for (const [channel, record] of Object.entries(releaseState)) assert.equal(resolveDestination(channel, record).active, false);
const metrics = json('lighthouse/median-summary.json');
assert.equal(metrics.runs.length, 3);
assert.ok(metrics.medians.LCP <= 2500 && metrics.medians.CLS <= .1 && metrics.medians.TBT <= 200);
const zoom = json('browser/actual-zoom-200-observation.json');
assert.equal(zoom.observed.zoom, 2);
assert.deepEqual(zoom.sizes.map(s => s.innerWidth), [320, 768, 1440]);
for (const path of ['browser/focus-trace.json', 'browser/network-trace.json', 'browser/webkit-smoke.json',
  'browser/visible-copy.json', 'step-01-report.md', 'step-03-report.md', 'native-before.sha256', 'native-after.sha256'])
  assert.ok(existsSync('build/site-audit/' + path));
for (const run of metrics.runs) for (const key of ['report', 'html']) assert.ok(existsSync('build/site-audit/lighthouse/' + run[key]));
for (const r of results) if (r.evidence?.screenshot) assert.ok(existsSync('build/site-audit/browser/' + r.evidence.screenshot));
const walk = p => readdirSync(p, {withFileTypes: true}).flatMap(e =>
  e.name === 'xcuserdata' || e.name.endsWith('xcuserstate') ? [] : e.isDirectory() ? walk(p + '/' + e.name) : [p + '/' + e.name]);
const nativePaths = [...walk('Sources'), ...walk('Tests'), ...walk('Config'), ...walk('WhisperKey.xcodeproj'), 'project.yml'].sort();
const native = nativePaths.map(p => hash(p) + '  ' + p).join('\n') + '\n';
assert.equal(nativePaths.length, 19);
assert.equal(native, read('build/site-audit/native-before.sha256'));
assert.equal(native, read('build/site-audit/native-after.sha256'));
for (const p of ['README.md', 'docs/testing/RESENHA-SITE-EVIDENCE.md'])
  for (const [, target] of read(p).matchAll(/\]\(([^)]+)\)/g))
    if (!target.includes('://') && !target.startsWith('#')) assert.ok(existsSync(resolve(dirname(p), target.split('#')[0])), target);
const html = read('site/index.html');
for (const phrase of ['Prévia ilustrativa', 'Right Option', 'Planejado', 'Apache 2.0', 'chave API fornecida por você', 'cobrança separada', 'Ainda não há um download público']) assert.ok(html.includes(phrase), phrase);
assert.doesNotMatch(html, /<(?:form|input|iframe)\b|rel="canonical"|href="https?:|src="https?:/);
for (const prefix of ['/', '/resenha/']) {
  const child = spawn(process.execPath, ['Scripts/site.mjs', '--serve', '--port', '4173', '--prefix', prefix], {stdio: ['ignore', 'pipe', 'pipe']});
  const closed = once(child, 'exit');
  try {
    await Promise.race([once(child.stdout, 'data'), closed.then(() => { throw Error('Preview CLI exited before ready'); }),
      new Promise((_, reject) => { const timer = setTimeout(() => reject(Error('Preview timeout')), 5000); timer.unref(); })]);
    for (const asset of ['', 'styles.css', 'release.mjs']) assert.equal((await fetch('http://127.0.0.1:4173' + prefix + asset)).status, 200);
    assert.equal((await fetch('http://127.0.0.1:4173' + prefix, {method: 'HEAD'})).status, 200);
  } finally { child.kill('SIGTERM'); await closed; }
}
console.log('PASS D1–D5: CLI root/subpath, 19 CK mappings, 31 fixtures, raw artifacts, 8 fingerprints, 19 native hashes, append-only README, local claims/links');
```

Documentation smoke outcome: **PASS D1–D5**, Step 04, 2026-10-02 20:03 UTC; exit 0. The same serialized gate reran S (**37 PASS, 0 FAIL, 0 skipped**) and `shasum -a 256 -c build/site-audit/native-after.sha256` (**19/19 OK**). `build/site-audit/documentation-smoke-results.md` retains the exact invocation and observed summary. No implementation file changed after the audited revision.

## Self-critique and evidence limits

| Question | Result / evidence | Gap |
|---|---|---|
| Technical accuracy against actual exports/native facts? | PASS: source imports/CLI/release fields inspected; eight tested hashes unchanged; claim inventory qualified | No claim of future release authenticity |
| Every documented procedure backed by execution? | PASS: setup/B/L/N executed by Step 03; S/D repeated by Step 04 with recorded outcome above | No fabricated duplicate browser run |
| Can a local developer follow the guidance? | PASS: root cwd, Node/tooling prerequisites, URLs, Ctrl-C, serial gates and expected output documented | Native setup preserved unchanged |
| Complete named cases and errors? | PASS: CK-1–19, all 31 fixtures, preview security, actual zoom, motion/FAQ/axe/Lighthouse mapped | Native human/Safari UI/VoiceOver evidence deliberately not inferred |
| Paths/links current? | PASS: D validates relative links and raw evidence paths; producer fingerprints validated | Ignored raw artifacts must be retained locally |

| Revision made during self-critique | Resolution |
|---|---|
| Avoid treating unknown HEAD as preservation | Independently compare complete before/after native SHA-256 inventories |
| Avoid unsupported zoom/Safari/contrast completion | Record actual Chromium zoom method, WebKit-only limit, and raw indeterminate contrast resolution |
| Avoid rerun/availability ambiguity | Distinguish Step 03 executed setup/audits, Step 04 smoke, and synthetic positives from shipped state |

No unresolved required site blocker is claimed closed from screenshots alone. Public publication/distribution and current native human acceptance remain outside this local-site handoff.
