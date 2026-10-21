# 04 — Testes físicos, privacidade e specs do candidato

**Task File:** `.specs/tasks/draft/add-transcription-feedback.feature.md` (usar localização atual se promovida).
**Phase:** 2
**Model:** sonnet
**Agent:** developer
**Depends on:** 03
**Parallel with:** None
**Note:** Sonnet por validação/documentação de desenho já fechado. Own `docs/specs/06-floating-ui.md`, `docs/specs/11-output-quality.md`, `docs/specs/08-testing.md` e `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Nenhuma instalação sobre o app existente nem integração PR #9/#13. Se teste físico achar defeito, devolver caso exato a 03 na mesma tarefa/branch e repetir só verificações afetadas; mudanças de produto mantêm regressão e gate obrigatório.
**Goal:** Demonstrar o comportamento do candidato certo e registrar somente resultados observados, com testes reproduzíveis para foco, VoiceOver, persistência e continuidade.

Usar o candidato de 03, a skill `.claude/skills/resenha-transcription-feedback/SKILL.md`, análise e contratos da task. Verificar origem do app instalado e divergências PR #9/#13 sem integrá-las; número de build sozinho não comprova SHA. Rodar candidato por caminho explícito, preservando app instalado e sessões abertas. Microfone, acessibilidade, Input Monitoring e VoiceOver devem ser disponíveis para provar o fluxo; não presumir permissão por testes unitários. Preparar modelo já local para distinguir download inicial de rede de feedback.

#### Expected Output

Quatro documentos existentes atualizados com uso/limites locais e evidência datada: commit/diff, binário, dispositivo/macOS, gate, fixtures e testes físicos separados. Roteiro próprio de testes descreve ação, resultado esperado, resultado observado e pendência. Revisão opus de fase recebe app testável, regressões e evidência final sem alegações acima do que foi visto.

#### Success Criteria

- CK-1–CK-3/CK-7/CK-9: fluxo sem mouse começa no menu de status (Control-F8/Fn-Control-F8 conforme Mac), alcança ações/campos com rótulos VoiceOver e Tab/Return/Escape, preserva draft inválido e entrega anúncios reais de erro/sucesso. Like e cancelar deixam glossário inalterado.
- CK-4–CK-6: cenário descartável “Coisa Energia = COESA Energia” persiste, reaparece após reabrir candidato e corrige próxima saída; texto anterior não é reescrito. Fronteiras e rollback P3 têm referência aos XCTest de 01/03, sem simular prova física de falha não observada.
- CK-7/CK-10: TextEdit e navegador demonstram inserção, clipboard, oferta ignorada, editor focado+hotkey, Alt-Tab, alvo encerrado e novo ditado; repetir history off/HUD off. Não fechar apps/abas pessoais para produzir cenário.
- CK-8: inspeção do diff e observação de rede durante like/dislike/cancel/save com modelo local demonstram ausência de novo envio de áudio/transcrição/feedback; somente par confirmado ganha persistência nova. Registrar método de observação e seus limites, sem alegar interceptação que não ocorreu.
- Specs removem proibição absoluta de controle focável para esta feature, preservam HUD passivo durante ditado e explicam limites/conflitos/rollback sem prometer retreinamento, criptografia ou flush síncrono. Nenhuma pendência física é marcada como sucesso.

#### Subtasks

1. Escrever testes manuais próprios reproduzíveis em `docs/specs/08-testing.md`: iniciar sem mouse, like/dislike, inválido, cancel/close/Escape, Save e reopen; acrescentar foco/hotkey/permission refresh/Alt-Tab/destino encerrado, HUD/history off e rede offline. Associar cada caso a CK e método de prova, com texto descartável.
2. Identificar revisão exata e binário de 03; conferir gate via mac-gate e fixtures temporárias. Abrir candidato pelo caminho explícito sem sobrescrever `/Applications/Resenha.app`; se não houver como executar com permissões necessárias, registrar impedimento e concluir apenas documentação/checagens independentes.
3. Executar casos físicos em TextEdit/navegador e VoiceOver, incluindo retorno de foco e próxima transcrição após reabrir, observação de rede e comparação de preferências. Usar somente regras de teste identificadas, sem apagar histórico/glossário real ou fechar Chrome/Terminal. Se estado real impedir teste sem mutação destrutiva, usar ambiente descartável ou registrar limite.
4. Atualizar `docs/specs/06-floating-ui.md` e `docs/specs/11-output-quality.md` para implementação final; registrar resultados/limites em `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Nenhuma transcrição pessoal, segredo ou draft deve entrar nos documentos. Falha física vira caso de regressão reproduzível para 03, não alteração silenciosa do esperado.
5. Conferir diff, correspondência SHA/binário/gate e cobertura CK-1–CK-10 para revisão única opus da fase. Reexecutar gate nativo via mac-gate se código mudou; workflow `Scripts/site.test.mjs` somente se site/scripts forem afetados. Não inventar npm/Vercel/next build para o app. Informar qualquer permissão/hardware faltante como pendência concreta.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Binário instalado de PR #9 confundido com candidato desta task | High | High | Registrar SHA e caminho real do processo/candidato; build number não basta; preservar instalação existente |
| Risk | Fixture parece acessível mas VoiceOver/foco real falha | High | Medium | Teste físico de entrada pelo menu, anúncios e sequência de foco; limitar claims se não observado |
| Risk | Teste altera glossário/histórico pessoal ou fecha sessão do usuário | High | Medium | Texto e ambiente descartáveis; não limpar dados reais nem encerrar Chrome/Terminal; documentar limite quando necessário |
| Blocker | Permissões, hardware, modelo local ou observador de rede indisponível | High | Medium | Concluir specs e revisão de fontes, registrar teste pendente e intervenção mínima necessária; não alegar passagem física |
| Risk | Download de modelo é confundido com envio de feedback | Medium | Medium | Preparar modelo local, delimitar janela da observação e destinos/método; sem chamada paga ou credencial pessoal |
