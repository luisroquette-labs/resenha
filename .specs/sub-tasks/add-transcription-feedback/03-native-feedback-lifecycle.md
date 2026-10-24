# 03 — Sessão, janela, menu e hotkey integrados

**Task File:** `.specs/tasks/draft/add-transcription-feedback.feature.md` (usar localização atual se promovida).
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 01, 02
**Parallel with:** None
**Note:** Opus por contrato compartilhado entre quatro fontes e invariantes de tentativas/foco. Own `Sources/WhisperKey/DictationCoordinator.swift`, `Sources/WhisperKey/FloatingPanel.swift`, `Sources/WhisperKey/WhisperKeyApp.swift`, `Sources/WhisperKey/NativeMenuController.swift` e testes de lifecycle/roteamento em `Tests/WhisperKeyTests/WhisperKeyTests.swift`. Usar API `ProductPreferences.saveTranscriptionCorrection(heard:canonical:)`, `FloatingStatus.feedback` e `TranscriptionCorrectionView` de 01/02; corrigir qualquer incompatibilidade estreita nesses contratos, sem redesenhar glossário/UI. Não criar novo arquivo Swift ou infraestrutura de injeção genérica.
**Goal:** Entregar o fluxo completo utilizável, sem salvar rascunho, roubar foco na inserção ou permitir ação obsoleta.

Ler a task inteira, contratos de 01/02 e todos os callers de `hotkeyPressed`, `hotkeyReleased`, `reset`, `cancel`, `show`, `showTemporarily`, `hide`, `handleHotkeyPress`, `handleHotkeyRelease`, `startHotkeyIfReady`, `refreshPermissionState`, `updateStatusItem` e `NativeMenuController.configure/update`. Implementar o `onCompleted` proposto no coordinator; contexto sem texto, somente token único e destino. No panel implementar `offerFeedback`, `approveFeedback`, `openCorrection`, `cancelFeedback` e consulta `hasFeedback`/`isEditingCorrection`; todos os handlers de ação capturam/verificam token. Métodos auxiliares seguem padrão existente. O panel é único dono de sessão none/offered/editing, draft e janela; AppDelegate conecta preferências/menu/hotkey.

#### Expected Output

Após `insertStaged` sem erro, tentativa ainda atual e HUD habilitado, reset limpa gravação/áudio antes da oferta. Oferta não ativante recebe mouse, sem timeout próprio; dislike abre NSWindow normal e dois campos vazios. Like/cancel não escrevem; Save usa resultado verificado, erro mantém draft, sucesso anuncia “Regra salva”/“Regra já existente” e encerra sessão. Menu usa os mesmos handlers sem criar estado paralelo. Na falha excepcional de rollback, cancelar fecha sem mutação mas conserva o par em memória para retomada do mesmo resultado; reabrir por “Corrigir transcrição” reconcilia a baseline antes de permitir novo Save, conforme J4-1 em Implementation Process.

#### Success Criteria

- CK-1/CK-2/CK-3: feedback não nasce de `onTranscript`; nenhuma conclusão em vazio/falha/fallback/cancelamento. Aprovação não muda defaults/histórico. Somente Save explícito chama API de 01 e erro P3 preserva janela/campos/token; falha de rollback mantém Save desabilitado enquanto `canSaveTranscriptionCorrection` for false. Return e callbacks também não podem confirmar nesse estado.
- J4-1: Cancelar/Escape/fechar permanecem disponíveis sem escrita; retiram token ativo, fecham a janela e conservam um único draft de recuperação efêmero vinculado ao resultado. “Corrigir transcrição” permite retomar esse draft enquanto o resultado continuar atual; chama explicitamente `reloadTranscriptionGlossaryForCorrection()` e só em sucesso verificado libera Save com novo token. Falha mantém mensagem, bloqueio e draft. Novo ditado/HUD off/encerramento apagam recuperação e ações antigas, sem transferir draft a outro resultado ou criar persistência.
- CK-7: nova gravação aceita aposenta oferta na mesma pressão; editor focado consome a primeira pressão até release e pede nova pressão externa. Editor após Alt-Tab é descartado sem reativar destino antigo. Timers/callbacks/status/permissões obsoletos não escondem nova sessão nem gravam regra antiga.
- CK-9/CK-10: produção remove `handleHotkeyPress(targetIsSelf: false)` de `configureHotkeyRouting`, calcula alvo real e preserva guard de `DictationInteraction`. Janela só ativa por ação explícita; fechamento devolve foco uma vez somente se Resenha ainda frontal e alvo vivo. Se restauração falhar, orientar retorno manual sem alegar sucesso.
- CK-8: HUD desligado encerra editor/token/menu; encerramento não ativa outro app. History off continua permitindo feedback; sem transcrição no contexto, nova rede/chave/log ou mudança de clipboard/texto já inserido.

#### Subtasks

1. Adicionar `onCompleted` em `DictationCoordinator` e guard pós-`await insertStaged` antes de capturar contexto/reset/emitir; manter `onTranscript` separado. Aposentar feedback em início/cancelamento/falha e preservar atividade e cleanup existentes.
2. Em `FloatingPanelController`, implementar sessão/token e handlers compartilhados, timer generation, pass-through por estado e NSWindow/NSHostingView do editor. Guardar e apagar draft em um owner; fechar/restaurar destino condicionalmente e manter erro/P3 visível sem confirmar. Para rollback falho, preservar um único par efêmero ao cancelar, aposentar token e permitir retomada pela ação existente de correção; reconciliação explícita de 01 deve verificar baseline antes de habilitar Save/Return e emitir novo token. Não adicionar botão/campo ou persistência para recuperação. Novo ditado/HUD off/encerramento apagam esse draft excepcional. Conectar views de 02 e anúncio acessível de erro/sucesso.
3. Em AppDelegate e `NativeMenuController`, conectar Save e disponibilidade das duas ações do menu, `onHUDChange`, `applicationWillTerminate`, permissões e status rotineiro. Corrigir rota real da hotkey e latch press/release para self/editor/Alt-Tab sem alterar `DictationInteraction.swift` ou inserir em Resenha.
4. Escrever testes próprios do seam real mínimo no arquivo pertinente e XCTest: token pós-await/cancelado, sem oferta nos erros, like/cancel/dislike sem escrita, P3 e J4-1 (rollback falho → Save/Return bloqueados → Cancelar fecha sem escrita e preserva draft → reabrir com recarga falha mantém bloqueio → recarga verificada habilita Save com draft e token novo), rejeição do token aposentado e descarte da recuperação no novo ditado/HUD off/encerramento. Cobrir Save repetido, menu antigo, oferta ignorada, editor+self → release → pressão externa, Alt-Tab, permission refresh/applicationDidBecomeActive e timers antigos. Preservar testes de clipboard/histórico e pass-through; não mockar pipeline inteiro nem copiar lógica para testes.
5. Executar gate nativo canônico via `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`, corrigir causas antes de produzir candidato e entregar SHA/diff, resultados e caminho do binário a 04. Gate de fase final é repetido só se 04 alterar código ou surgir falha/risco novo; revisão opus única vem após 04.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Reset/callback pós-await oferece sucesso de tentativa cancelada | High | High | Rechecar identidade/cancelamento após await, capturar contexto antes de reset e emitir somente depois; teste ordenado |
| Risk | NSPanel passivo impede cliques ou editor sequestra destino de inserção | High | High | Mouse só no feedback; oferta não ativa; janela normal após dislike; destino anterior e foco condicionais |
| Risk | Bypass self e repetição da hotkey gravam no editor | High | High | Remover false fixo, consumir pressão até release e exigir nova pressão externa; testes de rota real |
| Risk | `applicationDidBecomeActive`/permissões e timer anterior encerram draft | High | Medium | Status rotineiro respeita sessão; invalidação explícita limpa token; mesma geração protege callbacks/menu |
| Risk | Cancelar depois de rollback falho perde draft ou reabrir libera Save sem baseline confiável | High | Low | Recuperação efêmera no mesmo owner, token aposentado, reload explícito e Save/Return bloqueados até verificação; teste de cancel/reabrir/falha/sucesso |
| Blocker | API/resultado entregue por 01/02 diverge do contrato ou gate falha | High | Medium | Integrar tipos reais e corrigir diff mínimo; gate obrigatório, sem bypass; não encaminhar candidato quebrado a 04 |
