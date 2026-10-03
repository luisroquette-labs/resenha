# Step 04: Evidence and local usage handoff

**Task File:** `.specs/tasks/todo/build-resenha-sales-site.feature.md`

> The task file moves between `.specs/tasks/{draft,todo,in-progress,done}/` as work progresses; if it is not at this path, resolve it by its filename under `.specs/tasks/`.

**Phase:** Phase 2
**Model:** sonnet
**Agent:** sdd:tech-writer
**Depends on:** `03-browser-audit`
**Parallel with:** None
**Note:** Own only `docs/testing/RESENHA-SITE-EVIDENCE.md` and append-only site guidance in `README.md`. Consume the settled page/resolver/server, Step 03 reports and Step 01 before-native manifest. Do not change implementation or infer missing acceptance.
**Goal:** Leave reviewable local-site instructions and complete evidence tied to actual executed checks, while retaining native acceptance and later publication boundaries.

The site is the accepted one static document with `#download`; it has no compilation, framework, public remote, installer or store listing. Document the exact exports/commands already delivered, current/planned claims and independently authored assets. Raw reports belong to ignored `build/site-audit/`; the evidence document records paths, environment and CK-to-case outcomes. README remains a bridge between public Resenha name and internal WhisperKey development commands, preserving native/TCC instructions.

#### Expected Output

- `docs/testing/RESENHA-SITE-EVIDENCE.md`: tested revision/SHA-256, before/after native manifest comparison, release/status/link inventory, original copy/asset provenance, complete case/command/artifact matrix and local browser/performance outcomes.
- Append-only `README.md` site section: preview/root/subpath, stdlib test, isolated audit setup/browser/Lighthouse commands and explicit public repository/release/App Store follow-up boundary.

#### Success Criteria

- [X] CK-1–19 and every named main/edge/error case map to passing executed evidence or an explicit unresolved required blocker; no skipped required check becomes PASS and no native/human acceptance is inferred from the site (CK-16, CK-14).
- [X] All 31 destination fixtures and preview path/method/security partitions have recorded results; browser mouse/keyboard, responsive/breakpoint/actual zoom, no-JS/motion, accessibility and local Safari/WebKit observations match Step 03 artifacts.
- [X] Three Lighthouse runs/preset/versions/per-run metrics/medians meet the task thresholds and are labelled local lab evidence; claim/metadata/provenance findings identify current versus planned capabilities and unavailable destinations.
- [X] Before/after native manifests match when unchanged; conditional native gate is accurately not applicable. If native/shared configuration was touched, retain the actual zero-failure canonical native gate for the tested revision rather than claiming preservation from unavailable git HEAD.
- [X] Documented preview/test/setup/audit commands are smoke-checked locally through mac-gate where they execute validation; README preserves existing instructions and no public destination, paid call, credential collection, publication or unrelated cleanup is introduced (CK-13, CK-18, CK-19).

#### Subtasks

- [X] Read settled Step 01/02/03 reports and actual `build/site-audit/` artifacts, build the full CK/type/main-edge-error evidence matrix and independently compare visible claim/metadata/illustration provenance against task/native facts.
- [X] Capture after SHA-256 manifests of the exact native source/test/configuration/project areas, excluding user-specific Xcode state; compare with `build/site-audit/native-before.sha256`, record concurrency/edits honestly and apply the task's conditional canonical native gate only when relevant.
- [X] Write `docs/testing/RESENHA-SITE-EVIDENCE.md` with tested site/tooling fingerprints, environment, all 31 fixture outcomes, served root/subpath/security cases, network/focus/a11y/zoom/screenshots and three mobile Lighthouse runs plus medians; preserve unresolved blockers without an implementation-complete claim.
- [X] Append Resenha/WhisperKey name bridge, `node Scripts/site.mjs --serve --port 4173 --prefix /` and `/resenha/` instructions, canonical stdlib gate and isolated npm ci/Playwright/browser/Lighthouse setup to `README.md`; state GitHub/release/App Store remain separate tasks.
- [X] Write and execute documentation smoke-check cases in the evidence record for every documented command/artifact path and current/planned/absence statement; reuse existing delivered checks through mac-gate, validate case-matrix completeness and hand off one final reviewed evidence document without changing source or claiming pending checks passed.

#### Blockers & Risks

| Type | Item | Impact | Likelihood | Mitigation / Resolution |
|---|---|---|---|---|
| Blocker | Step 03 lacks a required zoom/browser/a11y/performance case or failing report | High | Medium | Finish independent documentation; name exact missing case/environment input and keep the required acceptance open until actual evidence arrives |
| Risk | Historical native tests or fixture images become site/current human acceptance | High | Medium | Separate native historical/pending evidence from current site runs, record exact tested hashes and preserve CORE-001 pending status |
| Risk | Native manifest differs due to concurrent work and is falsely called unchanged | High | Medium | Identify exact differing paths and provenance; coordinate ownership, never overwrite WIP or fabricate a baseline diff |
| Risk | README replaces working native instructions or invents publication/setup commands | Medium | Low | Append site-specific guidance only; smoke-check actual delivered commands and state external tasks remain unauthorized here |
