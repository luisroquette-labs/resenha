# Phase 4 scratchpad — add-transcription-feedback

2026-10-20. Leitura: plan-task/SKILL.md integral; task, skill local, analysis e judge-3 integrais; fontes focalizadas e métodos XCTest. O diretório instalado de plan-task não contém scripts/create-scratchpad.sh nem agente tech-lead; scratchpad criado via apply_patch, contrato usado da Phase 4/Judge 4 na própria skill. Nenhum produto implementado.

Scope: 7 fontes + XCTest + 4 documentos previstos na arquitetura. Sem mudança em DictationInteraction/TextInjector/History/Waveform/projeto/config/site. Primeira fase constrói saver íntegro e views independentes, sem feature incompleta exposta; segunda integra ownership/callbacks/menu/hotkey e realiza prova física. Quatro passos; reviewer opus em ambas, largura 2. Duas edições concorrentes XCTest usam regiões distantes; gates depois do fim das escritas. Nenhum agente extra necessário para esta decomposição.

Models: 01 opus por integridade de preferência e rollback; 02 sonnet por view no módulo existente; 03 opus por contrato compartilhado em quatro fontes; 04 sonnet por documentação e validação das decisões fechadas. Haiku não se aplica. Reviewer opus é teto; não requer tier inexistente acima.

P3: uma atribuição no sucesso; rollback excepcional explicitamente permite segunda atribuição. Snapshot de valor publicado e existência/valor original da chave. Ler armazenamento real, não só propriedade. Rejeição/duplicata não escrevem. Divergência pós-write restaura preferência e chave e deixa draft; teste UserDefaults isolado com fault de leitura única e reconstrução após remover fault. Caso rollback recuse persistência, reportar falha, valor antigo em memória e sessão bloqueada para nova confirmação até recuperação explícita; não inventar garantia de flush.

Tests ownership: 01 antes de testPersonalGlossaryCanonicalizesObservedPhysicalTranscripts; 02 região testHUDStateMappingIncludesInstructionsAndOperationMeaning/testHUDNativeFixturesForEveryStateAndAppearance e fixtures locais. 03 região coordinator/panel/interaction após fase 1. 04 procedimentos manuais próprios em docs/specs/08-testing.md e execução/evidência em UI-REFINEMENT-EVIDENCE.md, sem gate por passo duplicado.

Main risks: truncamento/conflicts silenciosos; callbacks/timers antigos; foco e hotkey self bypass; provas do binário instalado confundidas com main; ausência de permissão física. Mitigações específicas nos quatro sub-tasks. Nenhuma API paga, instalação sobre app existente, integração PR9/13 ou alegação de execução nesta etapa.
