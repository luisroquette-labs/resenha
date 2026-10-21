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

#### Expected Output

- `TimelineView(.animation)` deixa de existir na oferta. Entrada, repouso e saída são fases finitas iniciadas/canceladas pela apresentação, sem renderização periódica quando o HUD está oculto.
- `FloatingPanelController` continua o único dono do prazo de 4 segundos. Deadline e testes usam tempo monotônico injetável; animação nunca calcula prazo com `Date` de parede nem agenda dismiss independente.
- O painel visual permanece passivo. Dois overlays não ativadores, cada um exatamente do tamanho do target, recebem like/dislike e acompanham posição, Space/display e encerramento do HUD. Fora deles, o clique atravessa para o app abaixo.
- A sessão passiva contém somente token, PID opcional, fase visual e handlers fracos. A view não captura `DictationCompletion`, `NSRunningApplication` nem texto. Expiração, like, nova apresentação, novo ditado, HUD off e término removem overlays/tasks/callbacks.
- Testes provam ausência de task visual depois do terminal, deadline monotônico, pass-through fora dos targets, clique dentro de cada target, desalocação por probes e isolamento A→B/editor/status posterior.

#### Success Criteria

- [x] CK-12: sem `TimelineView(.animation)` ou atualização de 60 Hz; oferta e saída são animações finitas, e o estado oculto não mantém clock/task/render vivo. Inspeção e XCTest de fases/terminal aprovados; medição física de CPU/render ainda pendente.
- [ ] CK-12: fundo/área vazia do HUD não intercepta mouse; somente dois alvos fixos `44×44` acionam feedback.
- [x] CK-11/CK-12: deadline exato permanece `now + 4` em relógio monotônico; timer A não fecha sessão B, editor, notice, gravação ou HUD oculto. Testes de deadline/fases/gerações aprovados no gate conjunto de 21/10/2026.
- [x] CK-13: callbacks e views retêm somente token/PID mínimo; probes de contexto são liberados em todos os terminais. Inspeção e regressões de deinit/contexto aprovadas no gate conjunto de 21/10/2026.
- [ ] CK-1/CK-9: geometria, labels/hints, Reduce Motion, contraste e aparência das bolhas permanecem equivalentes, sem perda de ação por teclado/menu.

#### Validação deste passo

- `git diff --check`: aprovado após as alterações do passo 07.
- Cinco regressões XCTest adicionadas na região HUD: fases/deadline, overlays/ações/tela/Space, probes de app, desalocação do controller e isolamento de gerações. Teste legado atualizado para painel visual passivo.
- Gate conjunto de 21/10/2026: 96 testes; apenas o teste de overlays falhou em duas comparações de `collectionBehavior` (`321` contra `257`). `addChildWindow` acrescentava `.ignoresCycle` depois da configuração; a política compartilhada agora é aplicada após o vínculo, sem alteração do teste. Demais regressões de fases, deadline, contexto/deinit e isolamento passaram. Log: `/tmp/resenha-phase5-step10-native-gate-20261021.log`.
- Reteste focal via `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test -only-testing:WhisperKeyTests/WhisperKeyTests/testFeedbackOnlyTwoFixedNonactivatingTargetsReceiveActionsAndFollowScreenSpaceChanges -quiet`: exit 0, 1 teste aprovado, zero falhas/skips. Evidência: `build/Logs/Test/Test-WhisperKey-2026.10.21_09-39-20--0300.xcresult`. App instalado reaberto pelo trap; gate completo após esta correção ainda cabe à coordenação da fase.
- Pass-through por evento físico no app subjacente, múltiplos monitores/Spaces reais, VoiceOver, equivalência visual e medição de CPU oculta ainda não demonstrados. As assertions AppKit verificam janelas/targets/handlers e não substituem essas provas.

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
