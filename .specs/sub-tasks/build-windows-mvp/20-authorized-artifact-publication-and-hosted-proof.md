# Step 20: authorized artifact publication and hosted proof

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 6
**Model:** sonnet
**Agent:** developer
**Depends on:** 18
**Parallel with:** None
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Publish only approved verified bytes and capture a real browser download/hash round trip.

Own versioned GitHub release assets and hosting report under the release evidence directory. This step is a future authorized implementation operation, not authority supplied by this plan. Before any external publication, establish explicit current-session publication authorization and show the exact version/tag/source/artifact/hash and impact. If already authorized, proceed without a redundant checkpoint.

#### Expected Output

Immutable windows-v<version> release assets, actual hosted-download report and completed manifest with separate checksum.

#### Success Criteria

- Only the exact signed/scanned/physically tested installer and sidecar are uploaded to the architecture's allowlisted versioned URL; asset overwrite is prohibited.
- Browser-download size/hash equals candidate and records Mark of the Web/SmartScreen/publisher outcome; detections or policy-enforced denial block promotion.
- Completed acyclic release manifest and hashed reports are retained/published only after actual hosting evidence; source candidate identity remains immutable.

#### Subtasks

- [ ] Run pre-host release verifier and inspect current remote authorization/target; prepare concrete release notes and immutable filenames/version/source/hash before publication.
- [ ] Under valid authorization, upload approved exact assets without rebuilding/repacking; do not expose Windows CTA yet.
- [ ] Download hosted installer through a real Windows browser, inspect hash/size/Mark of the Web/SmartScreen and publisher, and record actual outcome without disabling protection.
- [ ] Add regression fixture for any hosting/identity failure; complete full hosted-release verification, then publish acyclic manifest/reports/checksums with immutable references. Missing proof leaves release promotion blocked.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Publication authority, release hosting or browser verification absent | High | Medium | Stop external upload/promotion and provide exact prepared result plus required action; never claim a URL works untested. |
| Risk | Uploaded asset differs or is overwritten after QA | High | Medium | Use versioned immutable assets and actual round-trip hash; new bytes require new candidate sequence. |
