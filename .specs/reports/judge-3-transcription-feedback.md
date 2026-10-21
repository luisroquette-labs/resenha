# Judge 3 — Architecture Overview

Data: 2026-10-20. Avaliação independente, sem consulta a notas de outros judges ou a threshold de aprovação. Escopo avaliado: somente `Architecture Overview` da task `../tasks/draft/add-transcription-feedback.feature.md`, linhas 220–334; critérios de aceitação, skill e análise usados como contratos de comparação.

**Score ponderado: 4.77 / 5.00** (valor não arredondado: 4.765).

| Critério | Peso | Nota | Fundamentação |
| --- | ---: | ---: | --- |
| Solution Strategy Clarity | 0.30 | 4.60 | Define fronteira de sucesso, dono do estado, token, janela, hotkey, persistência e tratamento de conflitos. Resta esclarecer a pós-condição do armazenamento no erro excepcional de round-trip. |
| Reference Integration | 0.20 | 4.80 | Integra a skill e a análise por links relativos corretos, resolve explicitamente a recomendação de atualização de conflitos e distingue divergências de PRs de dependências. |
| Section Relevance | 0.25 | 4.90 | Decisões, fluxo, ciclo de vida, limites e evidências atendem CK-1–CK-10 sem ampliar para serviço, treinamento, histórico paralelo ou infraestrutura de testes. |
| Expected Changes Accuracy | 0.25 | 4.80 | Enumera 12 arquivos existentes e justifica o acréscimo do menu à estimativa de 11 da análise; fontes, testes, fixtures e documentação estão contemplados. |

## Achado

**P3 — Pós-condição do erro de round-trip incompleta.** A task, linhas 295–297, determina uma atribuição, leitura posterior e, se houver incoerência, erro com preservação do draft. Não define se o valor anterior é restaurado, se a nova regra permanece, ou qual estado deve ser comunicado ao usuário. Isso não compromete a validação normal antecipada, mas deixa o ramo excepcional descrito pela própria arquitetura sem contrato completo: a pessoa pode receber erro após uma mutação já realizada. CK-4/CK-5 exigem integridade e ausência de gravação parcial; a skill, linhas 35 e 54–55, exige confirmação pelo valor efetivamente armazenado.

Correção recomendada: explicitar a pós-condição e um teste desse ramo. Se a inconsistência for tratada como quebra de contrato sem recuperação automática, declarar que não há garantia de rollback e definir como impedir nova confirmação ambígua. Se houver recuperação, conciliar a política com a exigência de atribuição única. Prioridade baixa porque limites e candidato são validados antes da escrita síncrona, e o setter atual é simples (`ProductPreferences.swift`, linhas 140–146).

Nenhum achado P0, P1 ou P2 identificado no desenho analisado. A nota não equivale a comprovação de implementação ou funcionamento físico.

## Verificações de coerência

1. **Regras e glossário.** A rejeição de conflitos é decisão explícita, não conflito não resolvido com a skill: esta recomenda atualização, mas exige sobretudo política determinística. A task explica a especialização nas linhas 226 e 237 e orienta resolução em Ajustes. Valida 160 caracteres por linha, 200 entradas aceitas antes da deduplicação, 20.000 no armazenamento e 8.000 no prompt; preserva bytes anteriores, lê o glossário atual no Save e trata duplicata efetiva como no-op. Rejeitar `=` nos dois campos é permitido pela skill. A correção apenas de caixa é explicitamente diferenciada de igualdade exata. Sequenciamento e escaping permanecem no motor existente.

2. **Foco, mouse, teclado e VoiceOver.** Oferta não ativante; mouse habilitado somente no feedback; editor em `NSWindow` normal aberto por ação explícita. O menu fornece entrada sem mouse e usa os mesmos handlers. Tab/Return/Escape, rótulos, erro e sucesso anunciados, restauração condicional do destino e hierarquia acessível estão definidos nas linhas 263–280. A arquitetura exige prova física e não confunde `FocusState`, fixture ou anúncio programado com entrega efetiva ao VoiceOver.

3. **Novo ditado e `targetIsSelf`.** Oferta ignorada é aposentada na mesma pressão aceita. Editor focado consome a primeira pressão até release e solicita retorno ao destino; uma nova pressão externa inicia o ditado. Se o usuário já alternou para outro app, grava no alvo atual sem reativar o anterior. A task identifica corretamente o bypass real `handleHotkeyPress(targetIsSelf: false)` em `WhisperKeyApp.swift:84`, preservando o guard de `DictationInteraction.swift:15–23` sem exigir alteração desse arquivo. Também cobre atualização de permissões ao ativar o app, callbacks obsoletos e timers.

4. **Privacidade e divergências.** Contexto do feedback não contém transcrição; campos vazios geram somente draft efêmero. Apenas o par confirmado vai à chave existente; histórico continua independente. Não há novo envio, log de conteúdo, API, analytics ou promessa de criptografia/flush síncrono. PR #9 e PR #13 são registrados como divergências a reavaliar; não há dependência, proposta de merge ou equivalência indevida entre main, candidato e app instalado. Nenhuma verificação remota adicional de PR foi necessária para avaliar essa coerência documental.

5. **Arquivos e evidências.** Confirmei a existência dos 12 caminhos de Expected Changes: sete fontes de produto, `Tests/WhisperKeyTests/WhisperKeyTests.swift` e quatro documentos. `NativeMenuController.swift` é o único acréscimo à estimativa da análise, motivado pela entrada acessível. As fixtures permanecem no harness existente, com dimensões específicas para o conteúdo novo. Sem Swift novo, não há registro novo no Xcode; não surgiu dependência obrigatória ausente da lista. Gates nativos via `mac-gate`, prova física, fontes de rede e binário atribuído ao commit são distinguidos corretamente.

## Evidência consultada e limites

Leitura integral da skill `.claude/skills/resenha-transcription-feedback/SKILL.md`, da análise `.specs/analysis/analysis-add-transcription-feedback.md` e da task. Inspeção focal de `WhisperKeyApp.swift`, `DictationInteraction.swift`, `WhisperTranscriber.swift`, `ProductPreferences.swift`, `NativeMenuController.swift` e referências de `DictationCoordinator.swift`; confirmação dos caminhos previstos. Os relatórios dos demais judges não foram lidos.

Não alterei a task, a análise, a skill ou código de produto. Não executei build, testes, app, VoiceOver, instalação ou chamadas pagas. Risco restante: foco, acessibilidade e inserção continuam hipóteses de projeto até validação física do candidato.
