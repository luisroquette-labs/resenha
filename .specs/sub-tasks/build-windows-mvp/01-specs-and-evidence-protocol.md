# Step 01: specs and evidence protocol

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 1
**Model:** sonnet
**Agent:** developer
**Depends on:** None
**Parallel with:** 02, 03
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Turn the accepted architecture into versioned implementation and physical-test contracts.

Own docs/specs/23-windows-mvp.md, docs/testing/WINDOWS-MVP-EVIDENCE.md, docs/testing/WINDOWS-RELEASE-EVIDENCE.md, README.md, docs/architecture.md, docs/specs/00-constitution.md and docs/PRIVACY.md. Record exact Windows 10/11 build predicates, AVX2/FMA/F16C/SSE4.2/OS AVX state, SDK/runtime, no disk transcript history, privacy and publication blockers. The architecture is settled; document it without selecting another stack.

#### Expected Output

Versioned behavioral specification, blank evidence templates and executable manual test protocol; all release fields initially pending.

#### Success Criteria

- Documentation maps every CK/HR to an evidence producer and preserves the Windows 10 compatibility versus vendor-support distinction.
- Protocols cover Notepad/Chrome, ABNT2/AltGr, all named failures, ten cycles per OS, offline corpus, installation/removal and exact installer hash.
- No document claims Windows availability, certificate/host possession, completed tests or automatic insertion certainty.

#### Subtasks

- [ ] Create docs/specs/23-windows-mvp.md and update architecture/constitution/README links and requirements from the accepted task.
- [ ] Write both Windows evidence templates with source SHA, installer/model hashes, toolchain, physical hardware and observation fields, not prefilled pass values.
- [ ] Write owned-data removal, local-only microphone/model behavior and clipboard/RAM recovery contracts in docs/PRIVACY.md.
- [ ] Add and run documentation-contract tests for required protocol sections and links in Scripts/windows-docs.test.mjs through mac-gate; report missing prerequisites explicitly.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Physical Windows host and publisher certificate are not established | High | High | Record owners/prerequisites as pending; documentation work can finish but release cannot. |
| Risk | Earlier WinUI/Rust and Windows support claims conflict with settled WPF design | Medium | Medium | Use this task architecture as authority and test exact platform/CPU/privacy disclosures. |
