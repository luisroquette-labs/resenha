# Interface refinement — item 1 evidence

## Marca Resenha no produto — 02/10/2026

- Símbolo original: balão de conversa com waveform em espaço negativo, gerado com fundo transparente.
- Asset catalog fornece variantes 1x/2x e renderização template monocromática.
- HUD `Ouvindo`: marca coral de 28 pt antes do cronômetro; onboarding e Sobre reutilizam a mesma identidade.
- Fixtures clara e escura inspecionadas: marca, estado, `00:07` e waveform permanecem legíveis.
- Gate canônico: 44 testes, 0 falhas; asset catalog compilado sem warnings.

## Feedback, recuperação e idioma — 02/10/2026

- Sons nativos distintos de início/fim, volume 35%, reprodução limitada a 250 ms e ajuste para silenciar.
- Transcrição concluída é colocada no clipboard antes da inserção e não restaura o conteúdo anterior.
- `Textos recentes` preserva localmente até 10 transcrições, com copiar e limpar mediante confirmação; áudio continua efêmero.
- Menu e painel Transcrição oferecem `PT-BR`, `EN` e `ES`; a escolha persistente vira `-l pt|en|es` no próximo ditado.
- Gate canônico final: 44 testes, 0 falhas; inclui clipboard persistente, limite/deduplicação do histórico, sons e idiomas.
- Menu real: `Idioma — PT-BR`, `Textos recentes`; submenus `PT-BR / EN / ES` e estado vazio confirmados via Accessibility. A troca ao vivo exibiu `Idioma — EN`, persistiu `en` e foi restaurada para `PT-BR`/`pt`.
- Bridge nativo voltou a retornar timeout; som ouvido e recuperação após ditado físico permanecem NOT RUN.

## Fluxo físico do produto — 02/10/2026

- TextEdit permaneceu como destino e recebeu a transcrição no cursor após hotkey, gravação e processamento local.
- Frase pretendida: `Testando o Resenha no meu Mac.`
- Texto inserido: `Testando o resenho no meu Mac.`
- Fluxo funcional: PASS. Fidelidade do nome `Resenha`: FAIL, registrada como OQ-001 na SPEC-011.
- Latência, restauração do clipboard, limpeza pós-sessão e Chromium continuam NOT RUN.

## Localização PT-BR do produto — 02/10/2026

- Menu real: `Resenha — Pronto`, instrução com o atalho configurado, Ajustes, configuração, permissões, Sobre e encerramento em PT-BR.
- HUD: `Ouvindo`, `Transcrevendo`, `Inserindo` e mensagens de recuperação em PT-BR.
- Permissões: nomes, finalidade, estado e recuperação em PT-BR.
- Fixture `hud-listening-light.png` regenerada e inspecionada; cronômetro e waveform continuam legíveis.
- Gate: 40 testes, 0 falhas.
- App relançado como um processo PID 81548, com status `Pronto`.

## Identidade pública Resenha — 02/10/2026

- Artefato `Resenha.app`, executável/processo `Resenha` e nome público Resenha.
- Módulo Swift interno `WhisperKey` e bundle ID `br.com.luisroquette.WhisperKey` preservados deliberadamente.
- Scheme, test host e module name foram separados explicitamente em `project.yml`.
- Gate: 40 testes, 0 falhas; assinatura estrita válida.
- Reabertura repetida manteve um processo PID 76169.
- Spotlight, Info.plist, menu nativo e Computer Use confirmaram a identidade Resenha.

## Ajustes nativos do produto — 02/10/2026

- Gate final: 40 testes, 0 falhas, via `mac-gate`.
- Uma janela nativa `Ajustes do Resenha` com Geral, Atalho, Áudio e Sobre.
- Reabertura repetida manteve uma janela e um processo.
- O microfone padrão real foi identificado como `Microfone (MacBook Pro)`.
- Troca de atalho para `Control + Espaço` atualizou imediatamente o menu; `Option direita` foi restaurado após a prova.
- Nenhum login item, permissão ou Ajuste do Sistema foi alterado durante a inspeção.

## Onboarding nativo de permissões — 02/10/2026

- Build testada: `build/Build/Products/Debug/WhisperKey.app`.
- Gate: 37 testes, 0 falhas, executados via `mac-gate`.
- Runtime: um único processo do app e uma única janela `Configurar Resenha`.
- Interface real: título `Fale. O Resenha escreve.`, estados reais das três permissões, indicação `Pronto para usar` e CTA `Começar a usar`.
- Recuperação: item nativo `Configurar Resenha…` confirmado no menu.

Date: 2026-10-02, observations 13:06–13:18 BRT (-0300).
Status: **IMPLEMENTED; PHYSICAL TEXTEDIT FLOW PASSED WITH ONE QUALITY REGRESSION**. Output quality is specified in SPEC-011.

Recording refinement reopened 2026-10-02: SPEC-006 and Step 03/05 acceptance were updated before code. The revised metering HUD is implemented; the new 35-test gate and 40 fixtures are recorded below. The original 31-test fingerprints/gate/24-fixture record is historical baseline evidence. Actual physical microphone/caret acceptance remains pending. Item 2 remains unstarted.

## Current recording-HUD revision — 13:53–13:56 BRT

The existing recorder's 16 kHz mono WAV settings are unchanged. Only AVAudioRecorder metering was enabled; a common-mode main-run-loop timer reads averagePower(channel: 0) at 20 Hz and passes finite normalized scalar values to the panel. `RecordingMeter` retains 48 readings, applies bounded 0.65 attack / 0.18 decay and formats injected monotonic elapsed time. No randomized input, waveform animation task, per-frame accessible label, extra permission, output-quality change or stored level history was introduced.

Canonical mac-gate **PASS: 35 tests, 0 failures**, 2026-10-02 13:53:46 BRT. Log: `build/recording-hud-mac-gate-rerun.log`. Result: `build/Logs/Test/Test-WhisperKey-2026.10.02_13-53-40--0300.xcresult`. Four new checks cover power normalization/attack/decay, fixed ordered history/reset, injected-clock rollover and stopped-state rejection, and stationary Reduce Motion/stable accessible status. The first attempt compiled but could not launch the test host (LaunchServices Code 20) while the old single-instance baseline process PID 11547 was running. Only that exact app process was terminated; the full gate passed on retry without TCC/reset/check bypass.

The same stable signed bundle passed `codesign --verify --deep --strict` and was relaunched once. Repeated open retained one process **PID 44816**. Bundle/signing identifiers and project.yml remain unchanged. All production Swift files are at most 198 lines. No repository HEAD exists; these changed-source/project/binary fingerprints, together with unchanged baseline entries below, identify the current tested revision:

| Changed artifact | SHA-256 |
|---|---|
| AudioRecorder.swift | 5938eefb6df1edf972876466155610847b21eafc31450398a24aa1ee74aa7f08 |
| DictationCoordinator.swift | 14e724dab54a14c2dfbdfbb478520a17dfb5838821e955793fdd1af7c5250336 |
| FloatingPanel.swift | 2855c23c08e336b2fc0a27ce7adfcd43c3a01bd0a8cf97d38aa22cfd4aed46bb |
| FloatingStatusView.swift | 6250c2aa944e80a247e699bd41500c141cea1614d0ae5ad5fe5effa7d327bbb9 |
| PanelPlacement.swift | 863228a59effd52df7b68daa3ebffc0dfca422fa4b587af1cd9bac7a15162cae |
| RecordingWaveformView.swift | 76e3a858083639629b9b18a5eae22184ad1995b12631444795dda2fcbd5c75ef |
| Tests/WhisperKeyTests/WhisperKeyTests.swift | 0ca75f63591555127f0939ea56cccaacafd1e2242cbaa61528fb1df808adc379 |
| WhisperKey.xcodeproj/project.pbxproj | 14f5249dd9faff25c0246edf59c5c7a7c4ed795790678227d6b676b235fe0f1c |
| Stable app executable | 6682d9f405982e5172bed5edae260637938311e0c3c5ecccc4647dfb42c75c1d |
| Stable app WhisperKey.debug.dylib | dae94aa7598ed89a8a8b8a06ba09f88e89dafa1cb07557f17c2826bd31d93587 |

Current fixture manifest: `build/ui-fixtures/hud-{state}-{appearance}.png`, eight states (ready, listening, listening-silence, listening-decay, transcribing, inserting, failure, long-failure) × five profiles (light, dark, increased-contrast, reduced-transparency, reduced-motion), **40 files**. Listening uses known injected dB values, a fixed 00:07 clock and the production renderer. Silence and decay are injected fixtures, not audio captures. Reduced Motion uses a stationary current-level array; contrast/transparency/motion fixtures use internal overrides rather than changing system settings. Six representatives inspected: listening-light, listening-dark, listening-silence-light, listening-decay-dark, listening-reduced-motion and listening-reduced-transparency. Labels/timer and dense rounded bars are readable; still images do not prove time progression or live microphone sampling. Recording footprint is now 340 × 72; ready/processing and error sizing/placement remain unchanged.

Fixtures are regenerated build outputs: names shared with the historical baseline now contain the current revision. Historical inspection notes describe the prior result; those earlier PNG versions were not separately archived.

Current native attempt: `cua.getApp` with the exact stable bundle path again returned **-10005 timeoutReached**. No native state or recording interaction was obtained. Real microphone responsiveness, physical hotkey/timer behavior, caret/click-through, VoiceOver, actual accessibility-setting changes, target-v-pointer/multiple displays and Spaces/full-screen remain **NOT RUN** on this revision. Hardware remains three online displays; presence is not a placement pass. Minimum macOS 14 and human CORE-001 remain pending.

Required manual check (60 seconds): in TextEdit, hold Right Option for 5–10 seconds; alternate silence and speech and confirm the bars follow the microphone, the timer increments and stops/resets on release, and the caret stays active. Then speak “Testando o nosso sistema de voz” for CORE-001 and record actual insertion/timing, clipboard preservation and owned-file cleanup. No pass is inferred from injected levels.

## Historical baseline — before the recording refinement

## Environment and tested revision

macOS 26.1 (25B78), Apple M5 arm64; Xcode 26.3 (17C529), Swift 6.2.4, Swift 5 project language mode; minimum deployment macOS 14. whisper.cpp 1.9.2 from Homebrew, local `ggml-small-q5_1.bin` (190085487 bytes). Current hardware: built-in 3024 × 1964 display plus two online LG 2560 × 1080 ultrawides (60/75 Hz), non-mirrored. Their presence does **not** prove target-screen placement. macOS 14 execution is NOT RUN.

There is no HEAD/commit in this newly initialized, untracked repository. Exact source/binary fingerprints identify the tested working tree; no historical diff against a commit is claimed. All production/test/project file mtimes predate the final 13:01:47 gate. Step 05 changed documentation only and reused that exact unchanged passing revision.

| Artifact | SHA-256 |
|---|---|
| AudioRecorder.swift | 5382e24c3850c8417c542d5061138d6109d81c7797fce5aa534cd037eaa86bc8 |
| DictationCoordinator.swift | eaf2f508eb9eddd68a6c1c7590aed9b8bda70bb9b51f04339afffaf27bbd59a0 |
| DictationInteraction.swift | a96fd9bf311df2333f25b4dff20c1465edb72426ffb952460a35e7e47559c9c6 |
| FloatingPanel.swift | 688729b5f7f05b0b8294f15e2ab4aad75e4e6e6cae662fa26bcf644c843324b9 |
| FloatingStatusView.swift | b791d2451281ac3c8e963724b03f6a507babee9cafdb6d99bb243f9bca79faea |
| HotkeyMonitor.swift | 0c6dbc6bcaefdee2d698fa66e70e32905a7a3570c5d52aa0fb34ed463c7c011b |
| MenuPresentation.swift | 365babd75132df28e9434a31aa288c3864abf200cae65e93d6991cf422297552 |
| NativeMenuController.swift | 7b6ab6d8d9763e5141e00a3995736320fbaa28a086d3a58b0cd4d1e852fbed1a |
| PanelPlacement.swift | ad8e060c1bab7879bbd55f2081d88fb387849639655a0843915ec241b431be50 |
| PermissionService.swift | 3f38949347bc7bf58c149a4283595eedcccfcccc3388a8b641974023669f31c9 |
| TextInjector.swift | ed02b9ec060d30bdaf399d7fb73da75e1609c95bc8b8084f282cb0b59d244c61 |
| WhisperKeyApp.swift | 3bc0a5abfc338cb8adf42214791b71c704dbf13b827b4dfc942f8b73534e6d41 |
| WhisperTranscriber.swift | 27510d86ab479dd7f706d1018c9a2f9f25c918b905ebee71b1ca992d40e2bc5a |
| Tests/WhisperKeyTests/WhisperKeyTests.swift | 05377cd165f56c510d57d761329aa669fdeb2ec931dc8a4946395e7f9dd26c29 |
| project.yml | e0cf53e10999d7cffeb1edb0de6500283f4448fd404e56132174ea75ef2403e9 |
| WhisperKey.xcodeproj/project.pbxproj | 53de33f4fb134bce23366e5f03e0c107376813bd6fcd1571589aee1d5a0a991b |
| Config/WhisperKey-Info.plist | 2047be71145c600bec1b3d7dcf4cfc34fe575376db599778ba2794282273061f |
| Stable app executable | 584f28b2cc68741c1cb1b367121b87bf3132c2148d25bb952c49fdb9c362657b |
| Stable app WhisperKey.debug.dylib (implementation) | a935ed04602e4e71fc6c5ba2a5c3ec84fe5f230efaaf002858facf5c1e02292f |
| Stable app __preview.dylib | 0a18d0739d98d6f82e77b58ab582d7a90b0ba27fe09fab14ef410bf9e1d34697 |

Production basenames above are under `Sources/WhisperKey`. Stable bundle: `build/Build/Products/Debug/WhisperKey.app`; identifier `br.com.luisroquette.WhisperKey`. Earlier pre-refactor fingerprints/logs remain historical and are not substituted for this revision.

## Automated gate and local launch

Command:

```sh
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

**PASS: 31 tests, 0 failures, 0 skipped**, completed 2026-10-02 13:01:55 BRT.
Log: `build/phase2-refactor-integrated-mac-gate.log`.
Result: `build/Logs/Test/Test-WhisperKey-2026.10.02_13-01-47--0300.xcresult`.
No standalone lint/remote workflow exists in this baseline. Prose-only integration did not rerun the unchanged gate.

`codesign --verify --deep --strict` returned success for the same bundle. Designated requirement is the existing Apple Development identity; identifier remains unchanged. `LSMultipleInstancesProhibited=true` and `LSUIElement=true`. LaunchServices inventory shows one registered WhisperKey app at the stable path. Repeated `open build/Build/Products/Debug/WhisperKey.app` returned success and retained one PID **11547**, observed again at 13:18. This proves launch/process identity, not visible menu/HUD/caret behavior. This Debug test bundle contains Xcode's Apple test-support frameworks/plugin; they are not third-party application dependencies or a distributed release.

Lifecycle log for that PID reports `Hotkey monitoring active` at 13:02:38. This is start/readiness evidence, not a physical hotkey/voice acceptance. Idle inspection found no owned WAV files in the app temp subdirectory or `WhisperKey-*.txt` output files; it does not prove post-dictation cleanup on this revision.

## Capture manifest — fixtures only

All files below are `build/ui-fixtures/hud-{state}-{appearance}.png`, generated by `testHUDNativeFixturesForEveryStateAndAppearance` during the exact gate. They host the production SwiftUI view in NSHostingView, not a live dictation window. Light/dark override colorScheme/native appearance; contrast/transparency use internal fixture overrides. The reduced-transparency set combines dark, increased contrast and opaque background. It is not an independent OS-setting toggle test.

| State | Light | Dark | Increased contrast | Reduced transparency |
|---|---|---|---|---|
| ready | hud-ready-light.png | hud-ready-dark.png | hud-ready-increased-contrast.png | hud-ready-reduced-transparency.png |
| listening | hud-listening-light.png | hud-listening-dark.png | hud-listening-increased-contrast.png | hud-listening-reduced-transparency.png |
| transcribing | hud-transcribing-light.png | hud-transcribing-dark.png | hud-transcribing-increased-contrast.png | hud-transcribing-reduced-transparency.png |
| inserting | hud-inserting-light.png | hud-inserting-dark.png | hud-inserting-increased-contrast.png | hud-inserting-reduced-transparency.png |
| failure | hud-failure-light.png | hud-failure-dark.png | hud-failure-increased-contrast.png | hud-failure-reduced-transparency.png |
| long-failure | hud-long-failure-light.png | hud-long-failure-dark.png | hud-long-failure-increased-contrast.png | hud-long-failure-reduced-transparency.png |

Step 05 visually inspected ready-light, listening-dark, transcribing-increased-contrast, inserting-reduced-transparency, failure-light, and long-failure in dark/increased-contrast/reduced-transparency. These eight representative fixtures are legible, with stable alignment and a two-line long cause/recovery. The remaining files exist and were generated successfully; no full real-screen background/contrast coverage is claimed. Ordinary footprint is 280 × 64 points; failure is bounded to 360 × 104. Idle has no screenshot because the HUD is hidden. No native menu screenshots were obtained.

## Verification matrix

PASS means only the named evidence type passed. NOT RUN is not a failure diagnosis and is not covered by another row.

| Scenario | Type / result | Observation or limit |
|---|---|---|
| All six visibility/status conditions, copy/symbol/progress mapping | Unit / PASS | State mapping and idle-hide tests; fixtures for five visible states plus long failure |
| Ready/failure dismissal; obsolete timeout survives listening/processing | Unit / PASS | Current generation/deadline, cancellation/callback and repeated automatic failure cases |
| Live approximately-two-second timeout and ready → real recording overlap | Native / NOT RUN | CUA could not bind the app window; no physical input |
| Focus/caret, click-through and one physical panel | Unit/source / PASS; native / NOT RUN | Passive flags and panel replacement exercised; TextEdit/Chromium behavior not observed |
| Menu-open-mid-recording release, rejected held press, request/self guards | Unit / PASS; native / NOT RUN | Actual AppDelegate routing exercised with controlled phases; no live recording/request |
| Partial permissions, all combinations, recording-only loss cleanup | Unit / PASS; native / NOT RUN | Snapshot/control-flow checks; real revocation and microphone cleanup not performed |
| Named Settings action success/failure/manual guidance | Unit / PASS; native / NOT RUN | Destinations and Boolean handling verified; actual Settings panes/TCC not visited |
| No-speech, capture and insertion failure titles/details | Unit / PASS; native / NOT RUN | Typed errors map to concise safe causes; hardware/model-error simulation not performed |
| Long diagnostic paths and safe recovery | Unit / PASS; native / NOT RUN | Wrapping rows, bounded width, complete safe paths tested; native scrolling/assistive reading pending |
| Appearance/status readability | Fixture / PASS (eight inspected); OS settings / NOT RUN | Production view rendering only; busy backgrounds/actual settings not observed |
| Keyboard menu actions, Quit/relaunch, VoiceOver reading order/discovery | Native / NOT RUN | No reliable native app binding; no forced announcements or permission resets |
| Negative geometry, target-v-pointer selection, fallbacks/disconnection | Unit / PASS; native / NOT RUN | Three screens present, but real moved target/pointer/Dock/disconnection behavior pending |
| Another Space/full-screen | Native / NOT RUN | No reliable native UI access; no level increase used to manufacture coverage |
| Physically spoken TextEdit CORE-001 | Human / NOT RUN — PENDING | Required phrase not spoken/observed for this revision |
| Chromium voice insertion, clipboard restoration and session cleanup | Human/native / NOT RUN | Baseline plumbing evidence retained separately; no new compatibility pass inferred |
| Minimum supported macOS 14 | Hardware/OS / NOT RUN | Current machine is macOS 26.1 |
| Local/native/ephemeral/item-1 boundary | Source/review / PASS within inspected revision | Apple frameworks; no new dependency/network/logged transcript/history/output algorithm changes |

## Native automation limits

Step 05 tried `cua.getApp("WhisperKey")` and the full stable bundle path: both returned server `-10005: timeoutReached`. Inventory succeeded; `cua.getApp("com.apple.TextEdit")` returned `-10005: cgWindowNotFound`. No native app state/capture or test action was obtained. Existing Step 04 observations record the same WhisperKey timeout. Real TCC was not reset, models/runtime were not renamed, and no other input technology was used to bypass the native bridge. These are environment/tool limits; they do not establish an app defect or successful behavior.

## Remaining completion gate

**The task remains in-progress.** Human TextEdit acceptance and native behavior cannot be closed from fixtures or historical microphone plumbing. Item 2 must stay unstarted.

Indispensable next action (60 seconds): in a new TextEdit document, physically hold Right Option, say **“Testando o nosso sistema de voz”**, release, then report the actual inserted text, approximate release-to-insertion seconds and whether TextEdit/caret stayed active. Record the observed result against the executable fingerprint above. Clipboard preservation and owned temporary-file cleanup must also be observed before CORE-001 is marked passed; repeat in an editable Chromium field for compatibility. Remaining keyboard/assistive, recovery and display/Spaces observations require a working native bridge or direct operator access and stay NOT RUN until performed.
