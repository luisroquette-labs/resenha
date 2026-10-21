# 08 — Aprendizado seguro e privacidade da correção

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** Phase 5
**Model:** opus
**Agent:** developer
**Depends on:** `07-hud-lifecycle-performance-hardening`, `09-preemptive-whisper-cancellation`
**Parallel with:** None
**Note:** Executar depois de 07/09 para reutilizar o contexto mínimo e evitar colisão nas regiões compartilhadas de `FloatingPanel.swift`, `FloatingStatusView.swift`, `WhisperTranscriber.swift` e XCTest.

## Goal

Impedir que feedback explícito crie substituições globais perigosas. Confirmar “rosto” → “Hostel” pode persistir somente “Hostel” como termo canônico de vocabulário; nunca `rosto = Hostel`. A forma ouvida existe apenas no draft limitado até Save/cancelamento e é liberada em todo terminal.

Este passo não implementa decisão contextual por JEV/OpenRouter, não faz chamada externa e não promete que o prompt do Whisper sempre produzirá o termo desejado. O sistema contextual completo continua na task `add-context-aware-corrections`; esta fase é o guardrail local imediato.

#### Expected Output

- `saveTranscriptionCorrection` deixa de serializar `heard = canonical`. Ele valida ambos os campos para UX/consistência, mas persiste somente uma linha term-only canônica no glossário atual, preservando bytes/entradas anteriores e limites existentes.
- A forma ouvida, a frase, rating, target e texto inserido não entram em UserDefaults, history, log, clipboard novo ou arquivo. Depois de Save/like/expiração/cancel/nova tentativa/HUD off/termination, probes confirmam liberação.
- Campos têm limites explícitos e antecipados coerentes com a menor gramática aceita. Digitação e paste acima do limite ficam no editor com erro/contador, sem truncar silenciosamente, construir linha gigante ou escrever parcialmente.
- Duplicata term-only é no-op “Regra já existente”; conflito legado no glossário não é sobrescrito. Rollback/read-back continuam protegendo o valor anterior, mas nunca reintroduzem a forma ouvida.
- Testes centrais: `rosto` → `Hostel` persiste só `Hostel`; `TranscriptPostprocessor.process("Meu rosto está vermelho")` permanece igual; prompt recarregado contém `Hostel`; nenhum storage contém `rosto = Hostel`.

#### Success Criteria

- [x] CK-5/CK-6: feedback persiste somente termo canônico; “rosto” permanece “rosto” e o prompt local passa a conter “Hostel”.
- [x] CK-4/CK-13: limites são aplicados no draft antes do Save, com erro acessível, sem truncamento silencioso, allocation persistente sem limite ou escrita parcial.
- [x] CK-8/CK-13: forma ouvida/frase/rating/target não sobrevivem ao terminal e nunca entram em rede, logs, history ou storage.
- [x] CK-5: entradas anteriores, duplicata, falha/rollback/reload e ausência original da chave continuam seguros sob a nova serialização term-only.
- [x] CK-3/CK-9: os dois campos e confirmação explícita permanecem; cópia/mensagem não afirma substituição global nem “aprendizado contextual” já disponível.

#### Subtasks

1. Atualizar o contrato de candidato/save para produzir somente termo canônico. Reusar parser e limites atuais para validar efeito no prompt; manter conteúdo anterior byte a byte e rejeitar linha canônica inválida/fora de capacidade.
2. Introduzir limites de draft nomeados e compartilhados pela view e pelo save. O binding rejeita/preserva input acima da fronteira com mensagem associada ao campo; o método de save repete a validação para callers diretos.
3. Reconciliar `CorrectionSession` com o contexto mínimo entregue por 07: drafts limitados e PID/token, sem `DictationCompletion`/`NSRunningApplication`/transcrição. Limpar strings e retirar closures no terminal antes de fechar UI.
4. Atualizar mensagens/documentação visível para “termo adicionado ao vocabulário”/“termo já existente”; não dizer que toda ocorrência futura será substituída. Preservar VoiceOver, Return, Escape e recuperação de erro.
5. Substituir regressões antigas de mapeamento global por testes term-only, storage diff, prompt recarregado, `rosto` negativo, COESA como dica, early limit e deinit probes. Manter testes do parser legado para regras manuais existentes, pois esta etapa muda o fluxo de feedback, não remove compatibilidade do editor de Ajustes.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Código morto ainda chama `correctionCandidate` e grava `ouvido = correto` | Critical | Medium | Teste de storage negativo, busca de callers no diff e API de feedback term-only com nome distinto |
| Risk | Alterar parser quebra regras manuais legadas | High | Medium | Não remover sintaxe `heard = canonical` do glossário de Ajustes; mudar somente o save originado pelo feedback |
| Risk | Prompt não garante correção desejada | Medium | High | Copy honesta de “vocabulário”; teste apenas presença no prompt e ausência de substituição global |
| Risk | Paste enorme fica retido antes da validação | High | Medium | Binding/formatter bounded e validação redundante no save; probe de draft e teste imediatamente acima do limite |
| Blocker | Produto exigir aplicação contextual automática nesta task | High | Low | Não improvisar heurística; encaminhar para `add-context-aware-corrections`, que possui contrato próprio de privacidade/provider |
