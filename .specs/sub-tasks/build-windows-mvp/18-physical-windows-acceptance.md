# Step 18: physical windows acceptance

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 5
**Model:** sonnet
**Agent:** reviewer
**Depends on:** 17
**Parallel with:** 19
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Prove the exact candidate works on both physical supported Windows releases.

Own actual observations in docs/testing/WINDOWS-MVP-EVIDENCE.md and physical sections of WINDOWS-RELEASE-EVIDENCE.md, plus immutable report artifacts. Use physical Windows 10 Home/Pro 22H2 build 19045 and Windows 11 Home/Pro 25H2 build 26200 x64; a dual-boot physical machine is acceptable. VMs/mocks/cross-builds cannot substitute.

#### Expected Output

Hash-bound install/offline dictation/recovery/uninstall evidence and measured corpus/latency on both OS targets.

#### Success Criteria

- Normal-user install, microphone-to-text-to-clipboard-to-Notepad/Chrome and ten consecutive cycles pass on each OS for the same final installer hash.
- PT-BR/EN/ES corpus passes declared WER/anglicism thresholds offline; silence causes no text/paste and temp files are absent after every terminal path.
- ABNT2/AltGr/focus-race/same-window field/caret changes/elevated targets/device loss/clipboard contention/cancel/crash cleanup and clean removal have real observations.

#### Subtasks

- [ ] Verify physical hardware/OS/source/app/model/installer identities and install exact bytes in clean normal-user profiles with spaces/non-ASCII paths.
- [ ] Execute the versioned physical speech, ten-cycle, target/privacy/error/restart matrix; record hardware/model/duration/latency without promising unmeasured speed.
- [ ] Run offline corpus and install/remove/retained-data checks, gather collector reports and distinguish SendInput dispatch from actual editor insertion.
- [ ] For every defect, the reviewer reproduces and documents the failure, records its regression scenario and returns correction plus automated regression-test implementation to the original owning step's agent; the reviewer does not edit product code. After the owner reruns its gates, any rebuilt/re-signed bytes return to step 17 and repeat both physical OS gates. The reviewer reruns the failed physical case and final pre-host verifier.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Either supported physical OS environment is missing | High | High | Leave that matrix row unverified and public release blocked; VM evidence remains supplemental. |
| Risk | Manual tester writes passed without reproducible underlying observations | High | Medium | Record exact case, expected/observed behavior, artifact identity and immutable report hashes. |
