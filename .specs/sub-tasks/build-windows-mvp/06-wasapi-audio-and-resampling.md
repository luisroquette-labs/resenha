# Step 06: wasapi audio and resampling

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 02
**Parallel with:** 04, 05, 07, 08
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. Complexity trigger: new subsystem, cross-module contract, concurrency or data-integrity boundary described below.

**Goal:** Produce an owned 16 kHz mono PCM16 WAV only for the valid held interval.

Own Resenha.Platform/WasapiRecorder.cs, PcmConverter.cs, Resenha.Core/AudioPolicy.cs and Resenha.Platform.Tests/AudioTests.cs. WASAPI thread ownership, QPC trimming and Media Foundation resampling are a new concurrent subsystem. Consume AudioLease/owned-session contracts without editing SessionFiles implementation.

#### Expected Output

Microphone enumeration/selection, event-driven capture, exact interval conversion, energy summary and actionable typed device failures.

#### Success Criteria

- PCM16/24/32/float32 source formats convert using actual rate/channel mask and quality 60 resampler, with validated WAV/frame counts.
- Press/release QPC boundaries trim samples; uncertain timestamps, discontinuities and device loss fail rather than returning partial complete audio.
- Start/stop deadlines and cancellation are idempotent; empty/short/silent audio cannot reach inference; no microphone switching mid-session.

#### Subtasks

- [x] Implement selected-endpoint shared-mode WASAPI worker, packet release on owning thread and silent-buffer handling.
- [x] Implement Media Foundation conversion/drain and QPC interval trimming; reject unavailable Media Feature Pack or unsupported format.
- [x] Implement AudioPolicy minimum 300 ms capture and at least 200 ms energetic frames above -50 dBFS RMS, maximum 120-second hold contract.
- [x] Write conversion/packet/timing/silence/device-removal portable tests and physical capture protocol.
- [ ] Verify permission denial/retry and native device behavior on physical Windows.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Post-release or pre-press samples leak into committed WAV | High | Medium | Trim using reliable QPC packet positions; uncertain timing cancels and deletes attempt audio. |
| Risk | Audio stop cannot acknowledge while UI reports idle | High | Medium | Return shutdown failure and require coordinator fail-closed app termination after recovery notice. |
