# Step 02: Release gating and local preview boundary

**Task File:** `.specs/tasks/todo/build-resenha-sales-site.feature.md`

> The task file moves between `.specs/tasks/{draft,todo,in-progress,done}/` as work progresses; if it is not at this path, resolve it by its filename under `.specs/tasks/`.

**Phase:** Phase 1
**Model:** sonnet
**Agent:** sdd:developer
**Depends on:** None
**Parallel with:** `01-static-product-page`
**Note:** Own `site/release.mjs`, `Scripts/site.mjs`, `Scripts/site.test.mjs`. Step 01 owns HTML/CSS. Preserve the accepted contract; final HTTP/content tests wait for both agents' writes to settle, but resolver fixtures may run independently.
**Goal:** Make unavailable destinations fail closed through one resolver and provide a confined loopback preview with finite, reusable regression fixtures.

Implement the task's settled exports: `releaseState`, `resolveDestination(channel, record)`, `applyReleaseState(root, state)` in `site/release.mjs`; `createPreviewServer({root, prefix, port})` with a close handle in `Scripts/site.mjs`. Standard URL/DOM/http/fs/path APIs suffice. The server is local development tooling, not a backend or distribution channel.

The HTML contract is `[data-release-channel="macos"]`, `[data-release-channel="source"]` and `[data-release-channel="store"]`; navigation/hero use the same `#download` anchor. The adapter uses only the resolver and DOM properties/text nodes. No Node import touches document. Export the single CK-7 catalogue as `destinationFixtures` from `Scripts/site.test.mjs`; register Node tests only when that file is the executed test entrypoint, so Step 03 can import fixtures without starting another suite. The 31 names and record/evidence partitions are authoritative in Acceptance Criteria; use all of them exactly.

#### Expected Output

- `site/release.mjs`: unavailable/planned authored records with null URL/evidence, pure resolution and small progressive DOM enhancement.
- `Scripts/site.mjs`: exported loopback server plus `node Scripts/site.mjs --serve --port 4173 --prefix /` entrypoint; supports `/resenha/` with identical files.
- `Scripts/site.test.mjs`: exact 31-fixture catalogue, resolver checks and confined-server/served-content regression cases.

#### Success Criteria

- [ ] `resolveDestination()` returns immutable `active/href/label/reason` values; first 28 CK-7 fixtures are inactive and the three positive synthetic fixtures active. Published records require matching evidence channel/URL/verifiedAt; macOS additionally validates version/architecture/minimumOS/artifact platform/version.
- [ ] URLs require absolute HTTPS without credentials; GitHub source paths, tagged concrete release assets and concrete Apple product IDs are validated. Unknown channel/state/platform, malformed URLs and every individual missing field fail closed; no fabricated default destination exists (CK-7, CK-15).
- [ ] `createPreviewServer()` binds only 127.0.0.1, confines real paths to site root, supports correct MIME/GET/HEAD at root/subpath and rejects traversal, symlink escape, malformed escapes and unsupported methods without crashes/exposure (CK-13, CK-16).
- [ ] Served HTML preserves meaningful pt-BR/status metadata, license/architecture qualifications, relative files, one download destination and no fake source/store links; durable semantic checks from Step 01 are included (CK-5, CK-11, CK-15, CK-19).
- [ ] `~/.local/bin/mac-gate node --test Scripts/site.test.mjs` passes after settled Phase 1 edits; fixture imports register no suite, all test/server resources close, and native/configuration files remain untouched (CK-14, CK-17, CK-18).

#### Subtasks

- [ ] Write resolver tests and export `destinationFixtures` in `Scripts/site.test.mjs`, covering every named CK-7 partition separately, permitted positive synthetics and immutability; no fixture activates production availability or fetches external URLs.
- [ ] Implement `releaseState`, `resolveDestination()` and `applyReleaseState()` in `site/release.mjs` using exact task evidence/URL requirements and the fixed data slots, with safe text/DOM assignment and browser-only boot.
- [ ] Implement `createPreviewServer()` and CLI in `Scripts/site.mjs` with explicit lifecycle, root/subpath and path/method/MIME confinement; exercise denial fixtures only in an isolated temporary directory and remove owned fixtures on completion.
- [ ] Add HTTP/served-output integration cases to `Scripts/site.test.mjs` for CK-5/7/11/15/16, including source/metadata claims, shared anchors, relative asset MIME, GET/HEAD, traversal/symlink/malformed/method errors, and import-without-registration behavior.
- [ ] After Step 01 settles, run/share the canonical stdlib mac-gate result, manually serve the actual document at `/` and `/resenha/`, and hand Step 03 the exported server/close interface, fixtures, selectors and exact failure results; do not install audit dependencies or run native gates when unchanged.

#### Blockers & Risks

| Type | Item | Impact | Likelihood | Mitigation / Resolution |
|---|---|---|---|---|
| Risk | URL appears valid but evidence is mismatched or absent | High | Medium | Check every required field independently; use exact finite negative/positive fixtures and no fallback URL |
| Risk | Decoding/traversal/symlink escape reveals repository or private files | High | Medium | Decode safely, confine real paths, reject escapes and test in a temporary root containing disposable sentinels |
| Risk | Audit import accidentally starts tests/server or opens real URLs | Medium | Medium | Guard entrypoints, export values/functions only and verify import lifecycle; fixtures never fetch destinations |
| Blocker | Parallel HTML not yet available for HTTP assertions | Medium | High | Run pure fixture checks first; wait for both writes to settle before final served-output gate rather than treating missing page as a pass |
