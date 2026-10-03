# Step 01: Original static product page

**Task File:** `.specs/tasks/todo/build-resenha-sales-site.feature.md`

> The task file moves between `.specs/tasks/{draft,todo,in-progress,done}/` as work progresses; if it is not at this path, resolve it by its filename under `.specs/tasks/`.

**Phase:** Phase 1
**Model:** sonnet
**Agent:** sdd:developer
**Depends on:** None
**Parallel with:** `02-release-preview-boundary`
**Note:** Own only `site/index.html`, `site/styles.css` and the before-native manifest/report. Do not edit the parallel-owned release/preview/test files. Use the fixed slots below; coordinate the final integrated gate after both agents stop writing.
**Goal:** Deliver an original, complete pt-BR sales/download document that explains Resenha and remains useful with JavaScript disabled.

Apply the task's accepted editorial spoken-note direction using semantic HTML, CSS, native anchors and details/summary. This is a static product explanation, not a live transcription demo. Public Resenha branding does not rename the existing WhisperKey app. Local prototype evidence, planned hotkeys/BYOK/Windows/Rust and license/publication goals must remain adjacent to their correct status. There is no verified public release/source/store destination.

Use relative `styles.css` and `release.mjs` URLs, one `#download` section and navigation/hero anchors to it. External action slots are readable elements marked `data-release-channel="macos"`, `"source"` or `"store"`; their initial HTML contains unavailable status/reason and no href. `site/release.mjs` from Step 02 progressively enhances those slots through `applyReleaseState(root, state)`; no duplicate release decision is added here.

#### Expected Output

- `site/index.html`: semantic product/workflow, capability/configuration status, local versus planned opt-in cloud/cost explanation, platform requirements, original illustrative note, FAQ and `#download`.
- `site/styles.css`: system typography, original warm-neutral/charcoal/rust composition, responsive bounds, visible focus and reduced-motion presentation.
- `build/site-audit/native-before.sha256` and a step report with claim/asset provenance and a runnable semantic smoke check; these are local evidence, not published assets.

#### Success Criteria

- [ ] CK-1–6 copy matches current development evidence; Right Option is current, customization/BYOK/Windows/WinUI/Rust and Apache 2.0/public source are accurately planned. No universal compatibility or shipped release assertion is fabricated.
- [ ] CK-8 original composition/copy/inline graphics have recorded provenance and a visible “Prévia ilustrativa” label. No competitor, user-desktop or generated paid asset is imported.
- [ ] Essential copy, unavailable status and anchors/FAQ work without JavaScript; external slots have no dummy links. pt-BR title/description/share text agree with development status and fabricate no canonical origin/schema (CK-7, CK-11, CK-15).
- [ ] Source-level semantic checks pass through mac-gate; the integrated served-output gate from Step 02 passes after both writes settle. CK-9/10/12 browser and performance acceptance remain due in Phase 2.
- [ ] Native before manifest covers `Sources/`, `Tests/`, `Config/`, `project.yml`, `WhisperKey.xcodeproj/` excluding user-specific Xcode state; native code/configuration and existing app are untouched (CK-13, CK-14, CK-17–19).

#### Subtasks

- [ ] Capture the before SHA-256 manifest to `build/site-audit/native-before.sha256` before site writes; inspect task-linked research, native docs and current release evidence for the claim/provenance inventory, without invoking paid APIs or creating public destinations.
- [ ] Author `site/index.html` with the complete workflow, current/planned feature ledger, provider transfer/key/cost guidance, source/license direction, macOS-development/Windows-later explanation, `#download`, semantic navigation and native FAQ.
- [ ] Implement the original illustration and `site/styles.css` layout, explicit illustration label, meaningful text alternatives/decorative hiding, relative assets, focus visibility, non-hover access and reduced-motion/static behavior.
- [ ] Write and run focused Node-stdlib source/semantic smoke assertions through mac-gate, retaining the exact runnable check in the step report; specify the corresponding durable served-output assertions to Step 02 through the orchestrator, without editing its `Scripts/site.test.mjs`.
- [ ] After both agents' writes settle, use `node Scripts/site.mjs --serve --port 4173 --prefix /` for local preview, share the serialized `mac-gate node --test Scripts/site.test.mjs` result and hand off selectors, CSS breakpoints, copy provenance and known browser-verification limits to Step 03.

#### Blockers & Risks

| Type | Item | Impact | Likelihood | Mitigation / Resolution |
|---|---|---|---|---|
| Risk | Roadmap language implies released customization/cloud/Windows or an installer | High | Medium | Qualify each capability locally; compare visible copy/metadata with task/native evidence and keep destination slots inactive |
| Risk | Competitor expression or private desktop content becomes an asset | High | Low | Independently compose inline HTML/CSS/SVG; record provenance; never import competitor/desktop images |
| Risk | Small-screen illustration obscures status or creates overflow | Medium | Medium | Reflow semantic text first, constrain decorative shapes and record all breakpoints for Phase 2 B-1/B/B+1 checks |
| Blocker | Concurrent native work changes the preservation baseline | High | Medium | Capture exact baseline, coordinate source/configuration ownership with the orchestrator and identify concurrent changes rather than rewriting or declaring equality |
