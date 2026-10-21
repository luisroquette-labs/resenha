# 09 — Cancelamento preemptivo do Whisper e ownership do WAV

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** Phase 5
**Model:** opus
**Agent:** developer
**Depends on:** `06-animated-halo-feedback-bubbles`
**Parallel with:** `07-hud-lifecycle-performance-hardening`
**Note:** Possui `DictationCoordinator.swift` e a região de engine/runtime de `WhisperTranscriber.swift`. Não tocar no parser/glossário nem nas regiões de HUD/persistência.

## Goal

Fazer cancelamento e timeout interromperem efetivamente `whisper_full`, inclusive enquanto a tentativa aguarda o engine compartilhado. Definir um único owner para remover o WAV assim que seus samples forem materializados, em sucesso, erro ou cancelamento, e garantir que uma tentativa cancelada não bloqueie a seguinte.

O limite continua local, sem processo auxiliar, rede, novo framework ou encerramento forçado do app. Não mascarar inferência que excedeu o prazo com uma verificação retrospectiva depois do retorno.

#### Expected Output

- Um controle de execução lock-safe, criado por tentativa, contém cancelamento e deadline monotônico. O `abort_callback` de `whisper_full_params` consulta somente esse controle; nunca captura Task, coordinator, URL, samples ou texto.
- Cancelar o task ou vencer o deadline sinaliza o controle imediatamente. Espera pelo engine também é cancelável; nenhuma thread fica presa indefinidamente em `NSLock.lock()`.
- `whisper_full` abortado é mapeado de forma determinística para `CancellationError` ou `WhisperError.timedOut`, sem entregar transcript parcial/tardio e sem resetar tentativa mais nova.
- O transcriber torna explícito o owner do arquivo: lê/valida samples, remove o WAV de modo idempotente antes da inferência longa e também limpa falhas de leitura. O coordinator não mantém um segundo owner concorrente.
- Teste com engine bloqueante/injetável prova cancelamento durante lock e inferência, timeout curto sem esperar minutos, liberação da segunda tentativa e remoção exata do arquivo.

#### Success Criteria

- [X] CK-14: cancelamento durante `whisper_full` faz o callback retornar aborto e a operação converge prontamente, sem depender do retorno natural do modelo.
- [X] CK-14: timeout é monotônico e preemptivo; o teste não se limita a comparar datas depois da inferência.
- [X] CK-14: uma tentativa nova adquire o engine após o cancelamento da anterior e não recebe resultado/callback do attempt aposentado.
- [ ] CK-14/CK-8: WAV é removido em todos os caminhos por ownership único, sem logar áudio/path pessoal nem criar persistência nova.
- [ ] CK-10: inserção, histórico, erro seguro, reset e state machine atuais permanecem cobertos; nenhum bypass de teste ou redução do limite produtivo.

#### Subtasks

1. [X] Confirmar no header vendorizado a assinatura suportada de `abort_callback`/`abort_callback_user_data` e os códigos de retorno de aborto. Planejar lifetime do ponteiro para durar até `whisper_full` terminar, sem unsafe dangling pointer.
2. [X] Introduzir controle por tentativa com flag de cancelamento e deadline baseado em uptime/clock monotônico injetável. Tornar aquisição do engine cancelável e remover `Date`/checagem exclusivamente retrospectiva do caminho de runtime.
3. [X] Conectar `DictationCoordinator` ao controle antes de criar a tarefa destacada; `onCancel` sinaliza o controle. Revalidar `attemptID` depois do await e descartar qualquer resultado tardio.
4. [X] Consolidar leitura/remoção do WAV no transcriber ou lease explícito: apagar imediatamente após samples próprios existirem, e em falha anterior por cleanup idempotente. Remover dupla responsabilidade do coordinator.
5. [ ] Adicionar testes na região Whisper/coordinator de `Tests/WhisperKeyTests/WhisperKeyTests.swift` com engine fake bloqueante, relógio curto e diretório temporário. Provar ordem cancel→abort→unlock→segunda tentativa, timeout e zero WAV residual. Não rodar gate enquanto o passo 07 estiver escrevendo em paralelo.

#### Verificação desta entrega

- [X] Inspeção dos headers/source vendorizados, callers e ownership; `git diff --check` sem erros.
- [X] Regressões escritas para callback, cancelamento/timeout durante espera e inferência, segunda tentativa, lifetime do controle, limpeza exata e callback obsoleto do coordinator.
- [X] Integração com `whisper_full` real via `mac-gate` em 2026-10-21: `testRealWhisperCancellationAndDeadlineAbortThenRecoverOnSameEngine`, 1 PASS, 0 skips, 1,523 s; resultado em `build/Logs/Test/Test-WhisperKey-2026.10.21_09-52-55--0300.xcresult`. Modelo small local, callback observado antes da interrupção, aborto C confirmado em cancelamento e deadline, recuperação no mesmo engine e quatro WAVs removidos uma vez cada.
- [ ] Gate completo da Phase 5 após o ajuste de revisão; a integração focal não substitui as regressões de inserção, histórico e lifecycle.
- [ ] Verificação física de cancelamento/timeout do modelo embarcado e continuidade do ditado.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Callback C acessa objeto Swift desalocado | Critical | Medium | Contexto retido explicitamente até retorno de `whisper_full`; ponteiro opaco criado/liberado no mesmo escopo e coberto por teste |
| Risk | Abort retorna código indistinguível de falha | High | Medium | Controle registra causa antes do callback; após retorno, mapear pela causa lock-safe, nunca só pelo status C |
| Risk | Cancelamento enquanto espera `NSLock` continua bloqueante | High | High | Substituir espera cega por coordenação cancelável/condição bounded; teste inicia segunda tentativa durante bloqueio |
| Risk | WAV removido antes de terminar a leitura | High | Low | Só remover após array de samples próprio existir; falha de leitura usa cleanup terminal separado |
| Risk | Seam de teste vira abstração pública excessiva | Medium | Medium | Menor protocolo/closure internal na região do engine; produção continua com um único engine embutido |
