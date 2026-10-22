# 05 — Preview UI and local controls

**Task File:** `.specs/tasks/draft/implement-continuous-context-intelligence.feature.md` (use its current location if promoted).
**Phase:** 2
**Model:** sonnet
**Agent:** sonnet
**Depends on:** 04
**Parallel with:** 06
**Note:** The session and coordinator contracts are settled. Keep this a bounded application of existing panel/preferences patterns; no redesign, external inline editing or new animation system.
**Goal:** Render accessible app-owned provisional/local/final status and expose a disabled-by-default local preview control without stealing focus or flooding accessibility announcements.

Modify `Sources/WhisperKey/FloatingPanel.swift`, `Sources/WhisperKey/FloatingStatusView.swift` and `Sources/WhisperKey/ProductPreferences.swift`. Use the coordinator preview callback from 04. Coalesce visual updates, identify provisional/local/final state without color alone, clear on all terminal paths and respect reduced motion. The control enables only local preview; it must not imply remote Jev authorization.

#### Expected Output

During active push-to-talk, Resenha can show bounded provisional text in its HUD while the external target remains untouched. Keyboard and VoiceOver expose truthful state; turning the feature off restores the current HUD and incurs no extra provider cost.

#### Success Criteria

- Preview stays inside the Resenha panel, preserves target focus and disappears on commit/cancel/failure/new attempt.
- Provisional, finalizing and local-fallback states have text/symbol accessibility distinctions, not color-only cues.
- Rendering is coalesced, VoiceOver does not announce every revision and reduced-motion settings remove nonessential movement.
- `ProductPreferences` defaults the capability off and labels local preview separately from any remote evaluator.
- View/model tests cover long Unicode text, rapid revisions, small screens, increased contrast, keyboard navigation and terminal cleanup.

#### Subtasks

1. Extend `FloatingStatus`/model/controller with session-bound preview state and an explicit clear operation.
2. Render bounded preview/status in `FloatingStatusView.swift` using existing design tokens and accessibility patterns.
3. Add the local-preview preference in `ProductPreferences.swift`; avoid provider/account settings in this step.
4. Add model/view/lifecycle tests in `Tests/WhisperKeyTests/WhisperKeyTests.swift`, then run Phase 2's full native gate through `mac-gate`.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Preview callback lacks terminal clear identity | High | Low | Fix the contract in 04 before UI work; never infer ownership from visible text |
| Risk | Frequent rendering steals CPU from recognition | Medium | Medium | Coalesce on the main actor and measure update rate with deterministic tests |
| Risk | VoiceOver repeats every partial | High | Medium | Announce only state transitions/final result; inspect accessibility tree and test labels |
| Risk | Toggle is mistaken for remote consent | High | Medium | Name it local preview and keep remote settings absent until 07 |
