# Step 03: Local browser, accessibility and performance audit

**Task File:** `.specs/tasks/todo/build-resenha-sales-site.feature.md`

> The task file moves between `.specs/tasks/{draft,todo,in-progress,done}/` as work progresses; if it is not at this path, resolve it by its filename under `.specs/tasks/`.

**Phase:** Phase 2
**Model:** sonnet
**Agent:** sdd:developer
**Depends on:** `01-static-product-page`, `02-release-preview-boundary`
**Parallel with:** None
**Note:** Start only after Phase 1 review. Own `Tools/site-audit/` and the `.gitignore` addition. Correct failed site/tests only in the smallest relevant owning source, with regression evidence; never alter native sources/configuration or weaken accepted audit conditions.
**Goal:** Verify the actual locally served page and retain runnable browser/a11y/performance evidence for every required scenario.

Consume `createPreviewServer({root,prefix,port})`/close from `Scripts/site.mjs`, `destinationFixtures` from `Scripts/site.test.mjs`, and `applyReleaseState(root,state)`/resolver from `site/release.mjs`. Use the fixed `[data-release-channel]` slots and `#download`; no second availability catalogue or production fixture/query switch is created. Chromium invokes the real adapter on test-only records. Intercept synthetic GitHub/Apple positive actions and reserved example.invalid paths; never request a release or external service.

Use only accepted isolated dev tooling: exact compatible versions of Playwright, @axe-core/playwright and Lighthouse in `Tools/site-audit/package.json` and lockfile, with plain Node runner. Nothing under shipped `site/` depends on npm or an audit package. Registry/browser setup is allowed development traffic; no paid call, personal credential or visitor-data collection is permitted.

#### Expected Output

- `Tools/site-audit/package.json`, `package-lock.json`, `audit.mjs`: reproducible dev-only tooling and fail-closed `--browser`/`--lighthouse` commands.
- `.gitignore`: append only `Tools/site-audit/node_modules/`; retain all existing ignores.
- Ignored `build/site-audit/`: exact environment/package/browser versions, case outcomes, focus/network traces, viewport/zoom/appearance screenshots, axe reports and three serial mobile Lighthouse reports/median summary.

#### Success Criteria

- [x] `mac-gate node Tools/site-audit/audit.mjs --browser` checks all task e2e/adapter partitions against the actual local page at root/subpath, closes owned resources and exits nonzero on failure or missing tooling. No request escapes local/test interception.
- [x] CK-9 widths 320/768/1440, minimum boundary 319/320/321 and every actual breakpoint B-1/B/B+1 have recorded dimensions/screenshots. Actual 200% browser zoom is observed and documented; device scale/screenshot scaling alone never substitutes.
- [x] Keyboard mouse-inactive cases are separate; navigation/FAQ/focus/order, no-JS/reduced-motion equivalence, status slots, semantics/alternatives and AA contrast are checked, with serious/critical axe findings resolved. A local Safari/WebKit smoke observation is recorded where available (CK-7, CK-10, CK-15).
- [x] `mac-gate node Tools/site-audit/audit.mjs --lighthouse` performs three serial audits of the unchanged static page using a recorded consistent mobile preset/browser; median LCP <=2.5 s, CLS <=0.1, TBT <=200 ms; no field-performance claim is made (CK-12).
- [x] Each main/edge/error case has a raw result/path for Step 04's matrix. Unavailable actual zoom/browser or other required check is an explicit blocker, not a passing skip. Native acceptance and conditional native gate remain distinct (CK-13/14/16/17–19).

#### Subtasks

- [x] Add exact compatible accepted dev packages/lockfile under `Tools/site-audit/`, bootstrap via the task's npm install command and installed Playwright Chromium, and append only the isolated node_modules ignore; record versions and make subsequent setup reproducible with npm ci.
- [x] Implement `audit.mjs` server/browser lifecycle and write browser checks using the existing fixtures/adapter/server: honest claims, all destination partitions, mouse/keyboard unavailable actions, intercepted positives, root/subpath/no-JS and request-scope assertions.
- [x] Write responsive/breakpoint, keyboard/FAQ/focus, reduced-motion, semantics/alternatives/contrast and axe cases in `audit.mjs`; record actual 200% zoom and local Safari/WebKit smoke observations with explicit method/result, not device scale inference.
- [x] Add serial three-run mobile Lighthouse measurement and median assertions to `audit.mjs`, writing raw reports/environment to `build/site-audit/`; run browser and Lighthouse commands through mac-gate and correct measured root causes without lowering targets or disabling checks.
- [x] Rerun affected stdlib/browser/performance checks through mac-gate after any correction; hand all result paths, tested SHA-256/revision, network/focus traces, claim/provenance findings, screenshots and unperformed mandatory checks to Step 04. Do not publish, deploy or change native code.

#### Blockers & Risks

| Type | Item | Impact | Likelihood | Mitigation / Resolution |
|---|---|---|---|---|
| Blocker | Chromium/audit packages, actual-zoom method or required browser observation unavailable | High | Medium | Complete independent checks, retain failure/context and obtain only the missing environment/operator observation; never substitute screenshot scale or pass a missing case |
| Risk | Synthetic positive CTAs request real GitHub/Apple destinations | High | Medium | Register request interception before adapter activation and assert no outbound request/download escapes |
| Risk | Lab measurement falsely claims production experience or uses different presets | Medium | Medium | Serve identical static files; serialize three recorded mobile runs; retain per-run values and calculate required medians |
| Risk | Browser failures are hidden by disabled cases, softened assertions or native mutation | High | Low | Fail nonzero, fix the bounded site producer and retain regression evidence; preserve native manifests and every accepted case |
