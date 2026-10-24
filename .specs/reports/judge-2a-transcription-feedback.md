# Judge 2a — Transcription feedback research

Date: 2026-10-20. Independent review; acceptance threshold was not supplied or inferred.

Artifact: `.claude/skills/resenha-transcription-feedback/SKILL.md`.

Reviewed the full skill, current draft task, research handoff, codebase analysis, and relevant Swift implementations. No artifact edits or product execution. Two Apple documentation URLs were checked; their HTML returned JavaScript shells, so this review does not independently attest every external API statement.

| Criterion | Weight | Score / 5 | Evidence |
|---|---:|---:|---|
| Resource Coverage | 0.30 | 4.4 | Seven Apple references map to concrete UI/persistence concerns; seven source/test resources cover the local pipeline. Access limitations are disclosed at skill lines 60–72. Dedicated keyboard-only access and focus-restoration guidance is thinner. |
| Pattern Relevance | 0.25 | 4.4 | Lines 18–36 reuse preferences, parser, postprocessor, attempt identity and native controls without new services. Historical HUD restrictions are reconciled explicitly. Conflict update advice needs alignment with the newer task requirement. |
| Issue Anticipation | 0.20 | 4.5 | Lines 38–58 cover truncation, parser capacity, case-insensitive conflicts, stale timers, focus theft, accessibility flattening, sequential replacements and isolated defaults. Missing an explicit keyboard entry route into the initially nonactivating HUD. |
| Reusability | 0.15 | 4.3 | Clear trigger, local contracts, pitfalls, primary references and reusable verification sequence. Project paths and current numeric limits are deliberate coupling; readers should refresh these against source. |
| Task Integration | 0.10 | 3.0 | Line 76 names the exact architecture backlink and decisions to settle. The current draft has no backlink. This is a documented orchestrator handoff caused by concurrent task editing, not an unexplained producer omission. |
| **Weighted total** | **1.00** | **4.27** | Unrounded total: 4.265. No threshold verdict. |

## Findings

| Priority | Evidence | Required follow-up |
|---|---|---|
| P2 | Skill line 45 recommends that explicit Save update an existing source mapping. Task scenario 4, CK-5 and its integration test require explicit conflict resolution and prohibit silent replacement. A generic Save can leave the old target undisclosed. | Architecture must require showing the existing mapping and an explicit replace decision, or reject the conflict. Align the skill recommendation with that constraint before implementation. |
| P2 | Skill lines 33–34 and 57 require keyboard operation but do not explain how a keyboard-only user reaches the first feedback action while the HUD remains nonactivating. Tab inside an already-open editor does not establish this entry path. | Name a keyboard-accessible entry route and test opening correction without a mouse, plus predictable return to the external app. |
| P3 | Skill line 76 requests architecture integration, but `.specs/tasks/draft/add-transcription-feedback.feature.md` currently contains no `resenha-transcription-feedback` reference. | Orchestrator links the skill in architecture references and records completion boundary, editor surface, conflict policy and lifecycle owner. Avoid concurrent producer edits to the draft. |

The local constants and primary blockers match source: 160-character physical line truncation, 200 accepted entries before deduplication, 20,000-character stored text, 8,000-character prompt, mouse pass-through and ignored accessibility children. The research is useful planning guidance; it is not implementation, microphone accuracy, restart durability, focus or VoiceOver proof.

Not checked: running app, native tests, full Apple Markdown bodies. Main remaining risk: an architecture that interprets ordinary Save as authorization to overwrite an undisclosed conflicting rule.
