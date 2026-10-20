# 03 — Privacidade e evidência local

**Task File:** `.specs/tasks/draft/add-context-aware-corrections.feature.md` (usar localização atual se promovida).
**Phase:** 1
**Model:** sonnet
**Agent:** developer
**Depends on:** 02
**Parallel with:** None
**Note:** Escopo isolado de documentação e evidência já produzida; não modifica persistência, rede, lifecycle ou testes. Se uma falha exigir código, devolvê-la ao passo 01/02 com seus testes antes de concluir esta fase. Não executar API/instalação/ditado real.
**Goal:** Entregar candidato e documentação consistentes para a única revisão local que libera o diagnóstico final.

Ler o diff real de 01/02, task completa, README e workflows atuais. Registrar o que os testes provaram, sem converter fakes em qualidade Jev. A regra do `mac-gate` aplica-se a qualquer reexecução necessária; evidência de outro SHA não substitui o candidato final.

**Arquivos permitidos:** `README.md`, `docs/PRIVACY.md`, `docs/specs/00-constitution.md`, `docs/architecture.md`, `docs/specs/11-output-quality.md`, `docs/specs/08-testing.md` e novo `docs/testing/context-aware-corrections.md`. Fontes, testes, workflows, site, manifest/entitlements e metadados de loja são somente leitura. O relatório é evidência adicional à superfície de produto prevista na análise.

#### Expected Output

Documentação distingue ditado offline, exemplos locais e diagnóstico remoto sintético único; explica exclusão/limites e preserva a proibição de ditado pessoal remoto. Relatório identifica branch/base/SHA/diff, bundle candidato, gate, versão do corpus, payload sintético previsto e evidências com origem explícita. A fase 1 pode ser revisada sem usar chave, instalar o app ou executar o diagnóstico.

#### Success Criteria

- CK-1, CK-2, CK-9: documentos descrevem Save contextual separado, 100 registros/uma frase <=600, exclusão confirmada, nenhum FIFO/migração e conflito global ainda possível.
- CK-3, CK-4, CK-5, CK-6, CK-10: relatório local distingue raw/pós-processado/entrada do resolvedor, baseline manter/global e fonte fake; registra corpus e resultados por par, abstenções e limites de 900 ms/até três ocorrências. Os gates reais de zero trocas indevidas e recall >=80% continuam não medidos.
- CK-7, CK-8, HR-1, HR-2: privacidade/consentimento/constituição não prometem que o diagnóstico remoto fica no Mac ou que o servidor tem retenção zero. Não há chave, exemplo pessoal, log bruto, orçamento mensal ou alegação de uso real autorizado.
- CK-11, CK-12, HR-3: candidato e gate completo de 02 são rastreáveis; revisão distingue acessibilidade local de teclado/VoiceOver/foco físicos ainda pendentes. O próximo passo contém exatamente uma chamada e instalação somente ao final.
- HR-3: checklist da revisão local confirma diff mínimo, fontes/fixture no projeto, regressões, gates aplicáveis e preservação da dependência; nenhuma publicação externa nesta fase.

#### Subtasks

1. Atualizar os seis documentos existentes conforme o comportamento de 01/02; a emenda de `00-constitution.md` restringe apenas a promessa absoluta de texto local para explicar o diagnóstico sintético. Preservar áudio local, ausência de analytics e proibição de reescrita arbitrária.
2. Escrever `docs/testing/context-aware-corrections.md` com proveniência do candidato, comandos/resultados locais, versão e matriz do corpus/fakes, captura sanitizada do request sintético e limites não medidos. Não copiar saída que contenha segredo, header de autorização ou texto pessoal.
3. Preparar o roteiro final: revalidar contrato/modelo/preço antes do despacho; registrar payload exato synthetic-only, uma chamada sem retry, custo estimado e resultado esperado. Reservar campos para uso/custo observado antes do merge; instalação/prova física continuam pendentes na documentação versionada. Indicar que resultados pós-merge serão registrados em artefato local identificado e comentário no mesmo PR/issue, com hashes/resultados, sem novo PR ou promessa de atualização versionada posterior.
4. Fazer as verificações próprias desta entrega documental: conferir links/paths, IDs CK/HR, consistência de limites e declarações de privacidade contra o código, além de `git diff --check`. Conferir resultado do gate nativo completo do último diff de código; reexecutar via `mac-gate` somente se fonte/projeto/teste mudou ou surgir uma falha concreta. Não criar teste que apenas replique prosa.
5. Entregar a fase 1 à revisão única opus com task, arquivos dos passos, diff/candidato e relatório. Achado de implementação volta a 01/02 antes de passar; não acionar diagnóstico enquanto revisão/gates/documentação não estiverem concluídos.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Gate/candidato não corresponde ao diff final | High | Medium | Identificar SHA e diff; repetir apenas o gate afetado via mac-gate antes da revisão |
| Risk | Texto "100% local" omite diagnóstico remoto | High | High | Conciliar README/PRIVACY/constituição com About/onboarding; distinguir áudio local de frase sintética transmitida |
| Risk | Corpus fake parece avaliação semântica Jev | High | High | Registrar fonte por evidência e marcar qualidade/latência reais não medidas; não derivar rollout da chamada única |
| Risk | Documentação amplia autorização para recorrência/PII | High | Medium | Registrar escopo synthetic-only, zero retry e ditado pessoal bloqueado; sem teto mensal ou provider fallback |
| Blocker | Contrato alpha atual diverge do implementado | High | Medium | Registrar divergência e devolver ajuste a 01 com novos testes/gates; não consumir chamada tentando adivinhar schema |
