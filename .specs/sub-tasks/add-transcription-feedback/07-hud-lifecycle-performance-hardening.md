# 07 — Lifecycle, performance e pass-through do HUD

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** Phase 5
**Model:** opus
**Agent:** developer
**Depends on:** `06-animated-halo-feedback-bubbles`
**Parallel with:** `09-preemptive-whisper-cancellation`
**Note:** Possui `FloatingPanel.swift` e a branch de feedback de `FloatingStatusView.swift`. O passo 08 só pode tocar nas regiões do editor/save depois deste passo concluir.

## Goal

Eliminar trabalho visual contínuo e interceptação ampla de mouse no feedback, usando um único lifecycle monotônico e retenção mínima. A oferta continua parecendo parte do HUD `280×64`, mas somente os dois alvos `44×44` recebem eventos; todo o restante deixa o clique chegar ao aplicativo subjacente.

Não alterar glossário, persistência, engine Whisper, captura de áudio, scripts de release ou a semântica dos botões. Não criar monitor global de mouse, polling permanente, display link ou segundo dono do deadline.

Refinamento visual solicitado em 21/10/2026: durante feedback, a superfície visual é transparente e exibe somente os glyphs 👍/👎, sem cartão, material, círculo, borda ou título. Após teste humano, os glyphs ficam sólidos por 3,25 segundos, sobem 20 pontos no total e fazem fade nos 0,75 segundos finais do mesmo prazo de 4 segundos. Reduce Motion conserva fade/timeout sem deslocamento; não há stagger nem timer adicional.

#### Expected Output

- `TimelineView(.animation)` deixa de existir na oferta. Entrada, repouso e saída são fases finitas iniciadas/canceladas pela apresentação, sem renderização periódica quando o HUD está oculto.
- `FloatingPanelController` continua o único dono do prazo de 4 segundos. Deadline e testes usam tempo monotônico injetável; animação nunca calcula prazo com `Date` de parede nem agenda dismiss independente.
- O painel visual permanece passivo. Dois overlays não ativadores, cada um exatamente do tamanho do target, recebem like/dislike e acompanham posição, Space/display e encerramento do HUD. Fora deles, o clique atravessa para o app abaixo.
- A sessão passiva contém somente token, PID opcional, fase visual e handlers fracos. A view não captura `DictationCompletion`, `NSRunningApplication` nem texto. Expiração, like, nova apresentação, novo ditado, HUD off e término removem overlays/tasks/callbacks.
- Testes provam ausência de task visual depois do terminal, deadline monotônico, pass-through fora dos targets, clique dentro de cada target, desalocação por probes e isolamento A→B/editor/status posterior.

#### Success Criteria

- [x] CK-12: sem `TimelineView(.animation)` ou atualização de 60 Hz; oferta e saída são animações finitas, e o estado oculto não mantém clock/task/render vivo. Inspeção e XCTest de fases/terminal aprovados; medição física de CPU/render ainda pendente.
- [x] CK-12: fundo/área vazia do HUD não intercepta mouse; somente dois alvos fixos `44×44` acionam feedback. Comprovado por WindowServer e mouseDown/up no XCTest; clique humano no Release permanece validação separada.
- [x] CK-11/CK-12: deadline exato permanece `now + 4` em relógio monotônico; timer A não fecha sessão B, editor, notice, gravação ou HUD oculto. Testes de deadline/fases/gerações aprovados no gate conjunto de 21/10/2026.
- [x] CK-13: callbacks e views retêm somente token/PID mínimo; probes de contexto são liberados em todos os terminais. Inspeção e regressões de deinit/contexto aprovadas no gate conjunto de 21/10/2026.
- [ ] CK-1/CK-9: glyphs soltos sem moldura, geometria, labels/hints, Reduce Motion e contraste preservados, sem perda de ação por teclado/menu. Fixtures e regressões nativas aprovadas; VoiceOver/teclado e aparência no Release físico ainda pendentes.

#### Validação deste passo

- `git diff --check`: aprovado após as alterações do passo 07.
- Cinco regressões XCTest adicionadas na região HUD: fases/deadline, overlays/ações/tela/Space, probes de app, desalocação do controller e isolamento de gerações. Teste legado atualizado para painel visual passivo.
- Gate conjunto de 21/10/2026: 96 testes; apenas o teste de overlays falhou em duas comparações de `collectionBehavior` (`321` contra `257`). `addChildWindow` acrescentava `.ignoresCycle` depois da configuração; a política compartilhada agora é aplicada após o vínculo, sem alteração do teste. Demais regressões de fases, deadline, contexto/deinit e isolamento passaram. Log: `/tmp/resenha-phase5-step10-native-gate-20261021.log`.
- Reteste focal via `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/WhisperKeyTests/testFeedbackOnlyTwoFixedNonactivatingTargetsReceiveActionsAndFollowScreenSpaceChanges -quiet`: exit 0, 1 teste aprovado, zero falhas/skips. Evidência: `build/Logs/Test/Test-WhisperKey-2026.10.21_09-39-20--0300.xcresult`. App instalado reaberto pelo trap; gate completo após esta correção ainda cabe à coordenação da fase.
- Pass-through por evento físico no app subjacente, múltiplos monitores/Spaces reais, VoiceOver, equivalência visual e medição de CPU oculta ainda não demonstrados. As assertions AppKit verificam janelas/targets/handlers e não substituem essas provas.
- Reabertura após bug físico de clique (21/10/2026): a nova regressão consulta `NSWindow.windowNumber(at:)` antes de despachar mouseDown/up; o baseline encaminhou o clique à janela subjacente. Diagnóstico registrou bounds do filho relativos ao pai no WindowServer apesar de `NSWindow.frame` em coordenadas globais, seguidos de deriva. Overlays agora são janelas independentes criadas após apresentar o HUD, com a mesma política espacial/level e teardown conjunto; alpha de fundo `0.01` mantém superfície de hit-test (controles totalmente transparentes eram atravessados).
- Reteste em `/tmp/resenha-feedback-independent-overlays-20261021.log`: contrato de geometria/ações/Space aprovado; regressão WindowServer ainda sem validação verde porque a janela `161335` de `loginwindow`, layer `2003`, interceptou inclusive os pontos de controle do fundo durante sessão bloqueada. Evidência: `build/Logs/Test/Test-WhisperKey-2026.10.21_12-04-51--0300.xcresult`. Desbloquear sessão e repetir focal antes de considerar o clique corrigido; não houve skip/afrouxamento do teste.
- Bloqueio de sessão resolvido no reteste focal de **13:23:51 BRT**: `build/Logs/Test/Test-WhisperKey-2026.10.21_13-23-51--0300.xcresult` confirmado por xcresulttool com **2 passed, 0 failed, 0 skipped**. Integração operacional do passo 10, sem lógica adicional, repetiu o canônico completo via `mac-gate`: **98 passed, 0 failed**, `build/Logs/Test/Test-WhisperKey-2026.10.21_13-26-45--0300.xcresult`, log `/tmp/resenha-final-overlay-native-20261021.log`. Isso encerra o bloqueio dos gates sobre overlays independentes/WindowServer; não substitui o teste humano no Release final nem marca as pendências físicas como PASS.
- Refinamento glyph-only: `mac-gate xcodebuild ... test -only-testing:` aprovou **4 focais** (motion, pixels, targets, WindowServer/mouseDown/up), zero falhas, em `build/Logs/Test/Test-WhisperKey-2026.10.21_13-52-06--0300.xcresult`, log `/tmp/resenha-feedback-glyphs-focal-20261021.log`. Mais **2 focais de lifecycle/generation** passaram em `build/Logs/Test/Test-WhisperKey-2026.10.21_13-53-21--0300.xcresult`, log `/tmp/resenha-feedback-glyphs-lifecycle-20261021.log`. Nenhuma suíte completa adicional rodada neste refinamento.
- 15 PNGs em `/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/ResenhaTests/feedback-glyphs`: light/dark/contrast/reduced-transparency/reduced-motion × 0/2/4s. Regressão verifica zero pixels pintados fora dos glyphs e zero pintura aos 4s; inspeção visual de início/meio/fim, contraste e Reduce Motion confirma ausência de cartão/círculo/borda. Movimento reduzido mantém posição; fade e deadline permanecem. O painel visual desliga sua sombra somente no feedback; overlays mínimos necessários ao hit-test continuam intactos.
- Integração operacional final dos glyphs, passo 10: canônico completo via `mac-gate` **99 passed, 0 failed, 0 skipped**, `build/Logs/Test/Test-WhisperKey-2026.10.21_13-56-09--0300.xcresult`; shell negativo/rollback PASS. Release **2026102105** gerado/validado/instalado depois dos gates, PID **76605**, executável SHA-256 `453a7aadea4830ea226908024888aca92a73df0d27155aaf48031c2db109a5d7`. Fonte produtiva congelada `2c4fddb21c505b441073eb093a203d644fdc79cc7cce9d6d4d12f9981152d870` sobre HEAD `4b04c7c27dd922b453b0b7c794b40adc377ff7ab`; sem lógica adicional. Entitlement assinado somente audio-input=true, backup verificado e input global preservado. Detalhes no registro 2026102105 de `docs/testing/UI-REFINEMENT-EVIDENCE.md`; aparência humana deste Release ainda pendente, sem marcar CK-1/CK-9 como PASS.
- Lapidação após teste humano: o fade linear do Release 2026102105 deixava os glyphs desbotados cedo. Release **2026102106** mantém opacidade 1 por 3,25 s, concentra saída nos 0,75 s finais, amplia o desenho para 30 pt e a subida para 20 pt. Focais **2/2 PASS** e canônico **99/99 PASS** (`Test-WhisperKey-2026.10.21_14-11-44--0300.xcresult`). Instalado com executável `0795bc33ab7c1b001e4a8bb6178dbe554863653c9a5c8382430a53f27b9b3ceb`; o usuário ditou “Teste visual local.” e aprovou aparência/timing como “ficou ótimo”. VoiceOver/Reduce Motion físicos permanecem separados.

#### Subtasks

1. Traçar `offerFeedback`, `present`, `hide`, `discardFeedback`, `dismissIfCurrent`, `FeedbackBubblesView`, reposicionamento de tela/Space e ações de menu. Definir uma única identidade de apresentação e uma máquina pequena de fases visuais.
2. Substituir o `TimelineView` por transições SwiftUI finitas disparadas por estado. Cancelar qualquer task de fase junto com geração/token; usar o mesmo relógio monotônico do controller para deadline e seam determinístico de teste.
3. Tornar o painel visual `ignoresMouseEvents = true` e criar somente os dois hit-targets não ativadores necessários, presos à geometria da oferta. Encerrar/recriar esses targets atomicamente com a sessão; não usar monitor global de mouse.
4. Trocar capturas de contexto por token e PID. Resolver aplicativo por PID somente no momento de restauração; closures de hosting view capturam controller fracamente e token por valor.
5. Adicionar regressões nas regiões de HUD/lifecycle de `Tests/WhisperKeyTests/WhisperKeyTests.swift`, incluindo probes de deinit, contagem de tarefas/targets, pass-through, relógio monotônico, screens/spaces e caminhos terminais. Não rodar gate neste passo isoladamente se o passo 09 estiver escrevendo testes em paralelo.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | `hitTest(nil)` ainda faz a janela engolir o evento | High | High | Painel visual ignora mouse; targets vivem em overlays próprios de `44×44`, com teste real de janela subjacente |
| Risk | Overlays se separam do HUD em monitor/Space diferente | High | Medium | Um owner, mesma screen/level/collectionBehavior e reposicionamento atômico em toda mudança de frame/tela |
| Risk | Fases visuais viram novo timer de lifecycle | High | Medium | Tasks finitas só publicam fase visual; dismissal continua exclusivo do controller e valida geração+token |
| Risk | Refactor retém app alvo ou sessão antiga | High | Medium | Contexto value-type mínimo, PID em vez de `NSRunningApplication`, closures fracas e probes em todos os terminais |
| Blocker | Pass-through seletivo não é demonstrável por XCTest puro | Medium | Medium | Teste AppKit de hit-target + caso físico controlado na Phase 5; não marcar prova física sem evento observado |
