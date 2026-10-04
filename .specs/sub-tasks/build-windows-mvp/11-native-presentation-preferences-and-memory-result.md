# Step 11: native presentation preferences and memory result

**Task File:** .specs/tasks/in-progress/build-windows-mvp.feature.md
**Phase:** 3
**Model:** sonnet
**Agent:** developer
**Depends on:** 02
**Parallel with:** 09, 10
**Note:** Execute only this step. All paths are repository-relative. Read the task's accepted Architecture Overview and shared execution constraints; do not modify protected macOS paths or call paid AI APIs. The assigned model is a capability tier, not authorization to change providers. The design is settled; this is bounded implementation, documentation or evidence collection.

**Goal:** Provide the settled WPF tray/settings/HUD behavior and minimal local preferences.

Own Resenha.Windows/App.xaml, App.xaml.cs, app.manifest, TrayController.cs, SettingsWindow.xaml/.xaml.cs, StatusWindow.xaml/.xaml.cs, ProductViewModel.cs, Assets/Resenha.ico, and Platform/PreferencesStore.cs. Follow settled bindings/contracts with test doubles; real composition is step 12. There is no disk transcript history: Copy last result reads a single RAM value.

#### Expected Output

Native nonactivating status overlay, first-run settings, tray commands and atomic bounded preference persistence.

#### Success Criteria

- HUD never activates or steals focus; settings open cancels active dictation; dismissals are attempt-scoped.
- Persisted schema contains only shortcut, microphone endpoint and language; malformed settings recover safely and do not enable invalid defaults.
- Tray exposes settings/cancel/copy last/exit; last result can be cleared and disappears on exit; app manifest is asInvoker without uiAccess.

#### Subtasks

- [ ] Build WPF view model and tray/settings/overlay bindings for real level and Ready/Recording/Transcribing/Inserting/ManualPaste/CopyRequired/error states.
- [ ] Implement shortcut capture, explicit PT-BR/EN/ES/microphone/model setup and actionable permission/device messages.
- [ ] Implement PreferencesStore atomic schema validation and RAM-only result clear/copy behavior; create icon from approved existing branding without editing existing assets.
- [ ] Add PresentationTests.cs and PreferencesTests.cs for stale HUD dismissal, noactivation styles, malformed/restart settings and absence of transcript disk fields; run Windows tests.

#### Blockers & Risks

| Type | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | HUD or setup steals original editor focus | High | Medium | Use WS_EX_NOACTIVATE/ShowActivated=false; initial setup occurs outside recording and real focus is checked in QA. |
| Risk | History feature accidentally persists sensitive text | High | Low | Whitelist only three preference fields; keep result in RAM, test exit/clear and filesystem writes. |
