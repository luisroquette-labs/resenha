# 04 — Diagnóstico e instalação final

**Task File:** `.specs/tasks/draft/add-context-aware-corrections.feature.md` (usar localização atual se promovida).
**Phase:** 2
**Model:** opus
**Agent:** developer
**Depends on:** 03 e revisão única da fase 1 concluída, com todos os gates locais no candidato final.
**Parallel with:** None
**Note:** Cruza a fronteira de rede paga e instalação física; opus por autorização/credencial/lifecycle, mesmo sem novo código. A chave descartável já autorizada cobre somente uma chamada sintética; não pedir novamente a mesma aprovação. Credencial indisponível, autorização nova para dados reais ou permissão exclusiva do usuário são impedimentos concretos, nunca convite a fallback. Não rearmar o guard.
**Goal:** Registrar a chamada sintética autorizada e instalar/provar o candidato final sem habilitar ditado remoto real.

Usar o cliente/controle seguro implementado em `ContextualCorrections.swift`/ajustes e a fixture allowlisted congelada em `Tests/Fixtures/contextual-corrections.json`, copiada explicitamente como recurso do target app e carregada de `Bundle.main`; não ler do checkout/bundle de testes nem criar script alternativo com segredo em ambiente/CLI. Confirmar o teste de carga do recurso no candidato e registrar seu hash antes do diagnóstico. O app candidato pode ser aberto do diretório de build **somente para diagnóstico**, sem microfone/ditado, antes de substituir qualquer instalação. A revisão/gate de fase 1 já deve estar concluída.

**Arquivos permitidos:** antes do merge, atualizar somente `docs/testing/context-aware-corrections.md` e os estados/evidências desta task pelo orquestrador. Depois do merge, registrar a prova física em `build/evidence/context-aware-corrections/<merge-sha>/physical.md`, confirmando que o diretório permanece local/não versionado, e publicar resumo com hashes/resultados em comentário no mesmo PR ou issue vinculada. Não abrir novo PR, criar commit pós-merge para essa evidência ou alegar que ela consta na documentação versionada. Nenhuma edição de produto/teste/config nesta fase; defeito volta ao passo dono e reabre os gates locais antes de prosseguir. Operações externas futuras permitidas dentro da implementação: único PR próprio/checks/integração e instalação local identificada ao fim. Não publicar release, loja, site ou novas declarações de privacidade externas.

#### Expected Output

Relatório pré-merge registra contrato/modelo/preço conferidos, payload sintético exato e estimativa antes da chamada, seguida de resposta ou erro, uso/custo observado quando disponível e estado consumido da autorização. O PR próprio fica integrado com checks aplicáveis verdes; candidato instalado corresponde ao commit integrado. A prova física posterior fica no artefato local identificado e no comentário do mesmo PR/issue com SHA, hashes do binário/recurso/relatório e resultados, sem novo PR ou documentação pós-merge apresentada como versionada. Nenhuma chamada sobre ditado pessoal, execução remota do corpus, retry ou promessa de qualidade Jev.

#### Success Criteria

- CK-7, CK-8, HR-1, HR-2: contador real passa de zero a no máximo um, sem retries/redirects/conta alternativa. A chave entra pelo controle seguro e fica só no Keychain/fluxo de autenticação; não aparece em arquivo/log/fixture/commit/memória. Timeout/erro/resultado desconhecido consome a autorização e não libera segunda chamada.
- CK-3, CK-4, CK-5, CK-10, CK-12: a evidência separa contrato remoto observado, corpus fake e qualidade semântica não medida. Uma decisão keep/abstenção/timeout é registrada honestamente; falha do provedor não é “correção funcionando” e não autoriza calibrar thresholds por essa amostra.
- CK-6, CK-7, CK-11: após o diagnóstico, confirmar opt-out/remover credencial com resultado SecItem verificado e operação local contínua. Ditado pessoal permanece sem transporte real; foco/clipboard/histórico não recebem resultado remoto tardio.
- CK-1, CK-2, CK-4, CK-9, CK-11: no último estágio físico, observar feedback/Save/exclusão/erro, os dois sentidos rosto/Hostel, novo ditado, teclado/VoiceOver e foco em campos descartáveis de TextEdit/navegador. Sem correção Jev sobre fala pessoal; fixture/fake eventual tem origem explicitada. Regra legada conflitante não é apagada automaticamente para fazer o teste passar.
- CK-12, HR-3: gate, revisão, PR/checks, merge SHA e bundle/assinatura/hash instalado registrados. Artefato local pós-merge e comentário no mesmo PR/issue identificam hashes/resultados e se distinguem do relatório versionado pré-merge; nenhum segundo PR. Nenhuma alegação de instalação/prova física com base só em XCTest, build ou abertura da janela; pendência de hardware/permissão fica pendente.

#### Subtasks

1. Confirmar fase 1 revisada, candidato e gates válidos; revalidar em fontes oficiais endpoint/schema/modelo/preço/política aplicáveis. Completar no relatório o payload sintético exato, uma chamada sem retry e custo estimado. Se houver divergência de contrato, corrigir via 01 e seus gates **antes** de usar a autorização.
2. Abrir somente o diagnóstico do candidato validado; inserir a chave descartável pelo controle seguro, confirmar guard ainda não consumido e executar uma vez. Registrar categoria, decisão/erro, duração, modelo efetivo e uso/custo disponível sem header/segredo. Se o resultado for desconhecido, marcar como desconhecido e encerrar tentativas remotas; não recuperar a chave de arquivos/ambiente ou usar outra conta.
3. Confirmar autorização consumida após reabrir, opt-out e exclusão de credencial sem rearmar guard; escrever os resultados no relatório. Os testes próprios deste passo são o roteiro controlado e suas observações, sem novo teste automatizado que acione rede. Não enviar corpus completo, ditado real ou exemplos salvos. Falha de transporte não impede concluir verificações locais independentes, mas bloqueia alegação de integração remota bem-sucedida.
4. Revisar diff final, abrir/atualizar o único PR da branch própria e acompanhar checks efetivamente aplicáveis ao SHA mais recente; integrar autonomamente com gates verdes. Inspecionar main após merge; se o merge mudar código ou surgir risco novo, repetir o gate nativo via `mac-gate`. Não inventar Vercel/nativo no Actions, ignorar check ou fazer push direto à main. Registrar SHA integrado e proveniência do binário antes da instalação.
5. **Somente agora instalar fisicamente** o candidato final identificado, preservando instalação recuperável, dados, permissões e sessões do usuário; identificar app/processo/atalho antes do teste. Observar o roteiro local em TextEdit/navegador e VoiceOver com campos/frases sintéticos descartáveis, sem transmissão real. Salvar sucesso/pendências no artefato local `build/evidence/context-aware-corrections/<merge-sha>/physical.md`, calcular SHA-256 do binário, recurso e relatório, e comentar resultados/limites/hashes no mesmo PR ou issue vinculada. Não abrir segundo PR nem alegar que a prova física pós-merge está nas docs versionadas. Remover apenas dados de teste explicitamente criados e encaminhar artefato/comentário à única revisão opus da fase 2; não pedir ao usuário para revisar/mesclar PR.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Chave indisponível/negada ou contrato/provider incompatível | High | Medium | Não usar fallback; concluir evidência independente e pedir somente credencial/permissão indispensável ou registrar falha externa |
| Risk | Repetir chamada após timeout/reinício amplia gasto | High | Medium | Guard durável consumido antes do despacho; unknown/error também encerra autorização; nenhuma segunda chamada |
| Risk | Candidato ou instalação errados invalidam prova | High | Medium | Verificar commit/hash/assinatura/processo/atalho e backup recuperável; instalação só depois de merge/gates e diagnóstico |
| Risk | Roteiro físico transmite fala pessoal ou apaga legado | High | Medium | Rede de ditado bloqueada, campos descartáveis e fixtures sintéticas; preservar glossário/histórico/dados existentes |
| Blocker | TCC, hardware, checks ou serviço impedem conclusão | High | Medium | Registrar etapa/evidência pendente e intervenção mínima; nunca usar mocks para declarar prova física/remota concluída |
