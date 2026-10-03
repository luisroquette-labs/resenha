# Judge 2a — Native macOS interface research

Date: 2026-10-02

Artifact: `.claude/skills/whisperkey-macos-ui/SKILL.md`

Task: Refine the native macOS interface and component design

Method: supplied weighted rubric; `prompts/judge.md` is absent from the installed workflow package. This review was assigned to the researcher that produced the artifact and is not an independent-author review. The artifact and current draft task were reread without editing either.

## Scores

| Criterion | Weight | Score / 5 | Weighted contribution | Evidence |
|---|---:|---:|---:|---|
| Resource Coverage | 0.30 | 4.3 | 1.29 | Nine primary references covering HIG accessibility/materials/color/progress, AppKit focus and geometry, native menu-bar capability, and official Willow workflow. Links map to concrete uses; inaccessible canonical HIG rendering is disclosed. Typography and SF Symbols lack dedicated references. |
| Pattern Relevance | 0.25 | 4.4 | 1.10 | Reuses existing AppKit/SwiftUI surfaces, preserves macOS 14 and nonactivation, maps all existing states, and explicitly excludes output improvements and unsupported product features. Revised visual dimensions remain for architecture/implementation to settle. |
| Issue Anticipation | 0.20 | 4.4 | 0.88 | Covers color-only signaling, unreadable materials, VoiceOver discovery, long messages, permission recovery, stale hide requests, multi-display placement and focus regression. Distinguishes source-level concern from a reproduced runtime defect. |
| Reusability | 0.15 | 3.8 | 0.57 | Native utility patterns and verification matrix transfer to future interface tasks. Embedded project names, dimensions and gate command reduce cross-project reuse but are useful within the intended repository. |
| Task Integration | 0.10 | 1.0 | 0.10 | Skill names the task and governing specs, but the inspected draft does not yet link back to the skill or direct its use. The researcher was expressly instructed not to modify the task; the orchestrator owns this handoff. |
| **Total** | **1.00** | **3.94** | **3.94** | **PASS** |

## Findings by priority

| Priority | Location | Finding | Follow-up |
|---|---|---|---|
| Medium | `.specs/tasks/draft/refine-macos-interface.feature.md` | Missing skill backlink leaves research outside the task's explicit reading path. It does not invalidate the sources or recommendations. | Orchestrator adds `.claude/skills/whisperkey-macos-ui/SKILL.md` as required design guidance during architecture synthesis, before promotion. |
| Low | Skill, Recommended approach / Primary references | System typography and SF Symbols are recommended without dedicated primary links. No API-specific claim depends on them. | Add official typography/symbol guidance if implementation introduces custom type scaling or symbol variants; unnecessary for retaining existing system defaults. |
| Low | Skill, Layout and native integration | The skill deliberately leaves exact layout dimensions and screen-selection policy undecided. It is suitable research guidance, not a finished visual specification. | Architecture specifies dimensions, overflow rules and display selection before implementation. |

No High or Critical findings. The research stays within item 1 and makes no claim of runtime acceptance or completed CORE-001 validation. No test run is required for this documentation review.

Verdict: **PASS — 3.94/5**, exceeding the required 3.5 threshold with no High/Critical finding. Follow-ups belong to task integration and architecture; no research rewrite is required.
