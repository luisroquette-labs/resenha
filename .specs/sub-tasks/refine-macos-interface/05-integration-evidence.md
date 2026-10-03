# 05 — Integration evidence and documentation

**Task File:** `.specs/tasks/in-progress/refine-macos-interface.feature.md`
**Phase:** 3
**Model:** sonnet
**Agent:** developer
**Depends on:** 03, 04
**Parallel with:** None
**Note:** Own documentation/evidence integration and final verification. Prior steps own implementation; route defects to the responsible step and repeat only affected checks plus the canonical gate after a code correction. Do not invent a second implementation path. Reviewer is a separate phase-level reviewer, not this agent. Use the task's current location if promoted.
**Goal:** Prove the integrated item-1 interface works on the actual Mac and record accurate final behavior and outstanding environment limits.

Read Architecture Expected changes, Acceptance Criteria and evidence handed off by Steps 01–04. Update `docs/specs/06-floating-ui.md`, `07-permissions.md`, `08-testing.md`, `docs/architecture.md` and README to match the delivered contracts. Update `docs/testing/M0-EVIDENCE.md` without replacing pending human evidence with synthetic results. Create `docs/testing/UI-REFINEMENT-EVIDENCE.md` with an environment/revision record, capture manifest and PASS/FAIL/NOT RUN observations. These seven documentation outputs complete the architecture's twelve-file envelope; screenshot artifacts are separately manifested.

#### Expected Output

Current user/engineering documentation, one UI evidence manifest and preserved/updated M0 evidence linked to the actual tested revision. A human-spoken TextEdit result determines the existing implementation completion gate. No item-2 work, commit/push/deploy or paid API action is implied by this step.

#### Success Criteria

- [X] Canonical mac-gate passes for the final code revision; no known deterministic test failure is skipped or hidden.
- [ ] Native checks cover focus, lifetime, menu/request interaction, explicit Settings recovery, error content, appearance/accessibility and available Space/display configurations; fixture evidence is clearly labeled.
- [ ] Physically spoken CORE-001 TextEdit acceptance records phrase, actual inserted text, timing, clipboard/cleanup observations and environment; browser behavior and unavailable hardware/OS checks remain explicit.
- [X] Final docs describe implemented reality, preserve local-only/native/ephemeral/identity constraints and leave item 2 unstarted; if required human evidence is absent, implementation remains pending.

#### Subtasks

1. [X] Reconcile final diff and step results against CK-1 through CK-12; review item-2 exclusions, bundle/signing identity, dependencies, safe diagnostics and absence of audio/transcript retention. Correct documentation drift in the five named spec/architecture/README files.
2. [X] Run the final gate when code has changed since the last integrated passing revision: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Reuse a recorded passing run for the exact unchanged code revision rather than rerunning for prose-only changes; launch the same signed bundle via `open build/Build/Products/Debug/WhisperKey.app`.
3. [ ] Execute native scenarios from the task, explicitly including no-speech/capture/insertion-failure presentation through safe test setup, ready-to-recording timeout, menu opened during recording, permission request guard, keyboard/assistive access and available display/Spaces checks. Add a focused regression test to the responsible existing test region for any newly discovered deterministic bug before its fix is considered complete; run its gate through mac-gate.
4. [X] Perform the physical human-spoken TextEdit CORE-001 phrase and Chromium compatibility check when user/hardware is available; record actual outputs, elapsed time, focus, clipboard restoration and cleanup. If unavailable, finish the independent matrix and leave the human gate PENDING with only the indispensable next action identified.
5. [X] Create UI evidence and capture manifest, update M0 evidence with real outcomes and tested revision/environment, then hand the complete artifacts to the Phase 3 reviewer. Preserve older evidence and separate NOT RUN, fixture and real native results.

Verification limits: native binding attempts returned CUA -10005 timeoutReached / cgWindowNotFound. Subtask 4's unavailable-input branch is complete; the actual human success criterion is still unchecked. See `docs/testing/UI-REFINEMENT-EVIDENCE.md` for the exact revision, attempts, NOT RUN matrix and required 60-second phrase action. No task step/phase review status was changed.

## Owner-approved recording refinement — reopened 2026-10-02

- [X] Validate the new exact revision through mac-gate; replace current-revision fingerprints/results while preserving the prior baseline as historical evidence.
- [X] Manifest deterministic silence/speech/decay fixtures, light/dark, contrast/transparency and stationary Reduce Motion. State explicitly that injected samples are synthetic presentation evidence.
- [ ] Physically compare silence, quiet speech and loud speech: bars must follow the real microphone, elapsed time must progress/reset, release must stop meter updates, and the external caret must remain usable. If direct/native access is unavailable, record NOT RUN rather than infer a pass from fixtures. CORE-001 remains independently pending.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
|---|---|---|---|---|
| Blocker | Physical human-spoken acceptance cannot be performed by automation alone | High | Medium | Complete all independent work, request only the physical phrase check, retain PENDING and do not close implementation |
| Risk | Screenshots/synthetic input are misreported as native focus/TCC/human proof | High | Medium | Label evidence type and tested revision; apply CK-12 review before handoff |
| Blocker | Two LG external displays are online, but native/CUA access prevented placement verification; minimum supported macOS 14 is unavailable on the current macOS 26.1 machine | Medium | High | Record display placement and macOS 14 execution as NOT RUN, with known AX/fallback limits; hardware presence alone does not prove placement behavior |
| Risk | Documentation overstates error recovery or menu accessibility | Medium | Medium | Base wording on observed current app and step evidence; route real defects back to their owning step |
