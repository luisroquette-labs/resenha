---
title: Add context-aware transcription corrections with Jev
depends_on:
  - .specs/tasks/in-progress/add-transcription-feedback.feature.md
---

## Initial User Prompt

“A correção `rosto` → `Hostel` não pode virar uma substituição global, porque uso muito mais a palavra `rosto`. Precisamos usar inteligência artificial e o contexto aprendido do usuário para decidir a palavra correta, em um beta com Jev via OpenRouter. A chave fornecida é descartável, somente para o teste, e será revogada quando funcionar. Antes da implementação, traçar a SPEC seguindo SDD.”

Chave de teste: `[REDACTED — nunca persistir em arquivos, logs, commits ou memória]`.

## Research Reference

Use [context-aware-transcription-corrections](../../../.claude/skills/context-aware-transcription-corrections/SKILL.md) for the Jev API contract, conservative correction policy, privacy/latency safeguards, and synthetic-corpus validation; proposed limits require architectural confirmation.

## Description

**What:** Um beta opt-in de correção contextual usa correções explicitamente ensinadas pelo usuário para decidir se uma ocorrência deve permanecer como foi transcrita ou receber o termo corrigido. Jev exerce uma escolha estruturada entre alternativas conhecidas; não gera a próxima palavra nem reescreve livremente o ditado.

**Why:** Aprender `rosto → Hostel` como regra global corrompe frases legítimas sobre o rosto. O objetivo é preservar o significado e reduzir correções repetidas quando o contexto sustenta a intenção ensinada. A preferência operacional é abster-se diante de incerteza; evidência de integração não será apresentada como prova de qualidade linguística.

**Who:** Usuário do Resenha que dita em português, ensina termos ambíguos pelo feedback e quer manter controle sobre aprendizado, envio remoto e remoção dos exemplos. O mantenedor precisa conseguir distinguir falha técnica, decisão de manter e substituição válida.

**Scope Included:**

1. Correções novas do feedback como exemplos contextuais locais, associados à ocorrência e a uma frase explicitamente confirmada. Salvar não cria uma substituição global; exemplos podem ser consultados e apagados. O beta guarda no máximo 100 correções, com uma frase rotulada de até 600 caracteres Unicode por correção; ao atingir o limite, recusa o novo cadastro e oferece exclusão manual. Isso limita retenção e complexidade sem apagar aprendizado silenciosamente; FIFO depende de decisão futura explícita e não faz parte deste beta.
2. Decisão limitada a manter ou aplicar um par conhecido em uma ocorrência exata, usando contexto atual e aprendizado local selecionado. O aprendizado local seleciona candidatos; exemplos pessoais não são enviados ao provedor. Na autorização atual, o caminho remoto de ditado pessoal permanece indisponível mesmo com opt-in: apenas uma chamada de diagnóstico com dados sintéticos pode ser executada após planejamento.
3. Beta desligado por padrão, com consentimento claro, preservação do fluxo offline, prazo máximo, cancelamento e recuperação sem alteração posterior de texto já entregue.
4. Avaliação com dados sintéticos e comparações rotuladas; preparação de um teste remoto controlado com a chave descartável já autorizada, executável somente depois do planejamento. Não usar nem persistir essa chave nesta etapa.
5. Reversibilidade do beta e compatibilidade com glossário existente, histórico e saída do ditado, incluindo transparência sobre conflitos com regras globais previamente cadastradas.

**Scope Excluded:**

1. Treino/fine-tuning, geração de próxima palavra, reescrita aberta, novo motor de transcrição ou correções retroativas.
2. Envio de histórico completo, áudio, clipboard, app de destino, identificadores ou corpus real; a autorização atual cobre apenas dados sintéticos no teste remoto.
3. Migração, remoção ou reinterpretação silenciosa de regras globais antigas; aprender automaticamente a partir de likes, textos de terceiros ou toda transcrição.
4. Uso remoto recorrente, troca automática de modelo/provedor, credenciais pessoais de fallback, orçamento mensal escolhido pelo agente ou chamadas pagas durante planejamento/CI.
5. Promessa de precisão superior, ganho de velocidade ou prontidão geral baseada em um mock ou em uma única chamada.

**User Scenarios:**

Os cenários descrevem o comportamento futuro e os testes locais com fakes. A opção remota para ditado pessoal não pode ser habilitada com a autorização atual; seu desbloqueio exige decisão específica sobre dados e uso recorrente.

1. **Ensinar e reutilizar:** após uma transcrição elegível, o usuário confirma o par `rosto → Hostel` e a frase de hospedagem. O exemplo fica local; em futura frase de hospedagem, o beta pode aplicar apenas a ocorrência validada. Não modifica a saída anterior.
2. **Manter o sentido comum:** com o mesmo exemplo salvo, “Meu rosto ficou vermelho” permanece intacto. “O rosto ficou estranho” sem contexto suficiente também permanece; a existência do exemplo não constitui prova para substituir.
3. **Selecionar a ocorrência correta:** em frase com duas ocorrências, somente a ocorrência referenciada pela decisão válida muda. Termos dentro de outras palavras, intervalos inválidos e pares conflitantes não autorizam substituição.
4. **Falhar sem interromper:** beta desligado, sem credencial, offline, resposta malformada, baixa confiança, timeout ou novo ditado mantêm o texto da etapa anterior e não bloqueiam a próxima gravação. Resposta atrasada não escreve em histórico, clipboard ou aplicação.
5. **Reverter e controlar dados:** o usuário desliga o beta ou apaga um exemplo; futuras transcrições deixam de usá-lo. Uma regra global antiga `rosto = Hostel` permanece visível e precisa de decisão explícita do usuário antes de ser removida; o beta não anuncia esse conflito como resolvido.

**Autoridade vigente:** esta task é a SPEC dedicada da correção contextual e substitui os limites de autorização conflitantes do addendum Phase 5 da task dependente. A chave descartável já foi autorizada para um teste controlado e não exige nova aprovação por ser descartável. Essa autorização cobre somente uma chamada sintética posterior ao planejamento; ditado pessoal/remoto real permanece indisponível. Não inclui persistência da chave durante planejamento, histórico/corpus real, uso recorrente ou teto mensal. O opt-in não amplia essa autorização, e a chamada de diagnóstico não desbloqueia o uso remoto do app. O aprendizado local descrito aqui é comportamento futuro a implementar, não licença para ler o histórico do usuário durante planejamento.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
| --- | --- | --- | --- |
| CK-1 | Salvar uma correção nova exige confirmação explícita do par e da frase local, rejeita ausência de ocorrência, preserva o draft em erro e não acrescenta uma regra global ao glossário? | hard_rule | essential |
| CK-2 | O armazenamento contextual separado permite listar/apagar item/apagar tudo, limita-se a 100 correções com uma frase rotulada de até 600 caracteres Unicode cada, recusa novo cadastro ao atingir o limite sem FIFO e preserva exemplos anteriores se a gravação falhar ou a versão for desconhecida? | hard_rule | essential |
| CK-3 | A decisão permite somente manter/aplicar um par existente, com identidade da ocorrência e confiança finita entre 0 e 1, aplicando somente a ocorrência exata quando a confiança for pelo menos 0,90? | hard_rule | essential |
| CK-4 | A regressão mantém “Meu rosto ficou vermelho” e “O rosto ficou estranho”, e permite “Reservei um rosto perto da estação” → “Reservei um Hostel perto da estação” somente após decisão válida, sem modificar texto fora da ocorrência? | hard_rule | essential |
| CK-5 | Toda indisponibilidade, resposta inválida, decisão incerta, ausência de candidato ou mais de três ocorrências candidatas preserva o texto recebido pelo resolvedor, sem retry automático e com prazo total de no máximo 900 ms? | hard_rule | essential |
| CK-6 | A decisão termina antes de entregar/persistir a saída, usa a mesma saída final em histórico e inserção, respeita cancelamento e ignora resultados de tentativa obsoleta sem reinserção ou edição retroativa? | hard_rule | essential |
| CK-7 | O beta nasce desligado, mantém o ditado pessoal/remoto real indisponível na autorização atual mesmo com opt-in, mostra o escopo exato de dados, não envia requisições quando desligado e interrompe novas requisições/uso de resultados pendentes ao desligar ou apagar a credencial? | hard_rule | essential |
| CK-8 | O request capturado contém apenas idioma, par candidato, alternativas e frase sintética autorizada de no máximo 600 caracteres, sem chave no corpo, exemplos pessoais, áudio, histórico, clipboard, identificadores, texto adicional ou logs de conteúdo? | hard_rule | essential |
| CK-9 | Os exemplos contextuais ficam separados das regras legadas, nenhuma regra é alterada automaticamente e um conflito global anterior é identificado sem prometer que o beta consegue recuperar texto já transformado por essa regra? | hard_rule | essential |
| CK-10 | O corpus sintético contém pelo menos cinco pares ambíguos com positivos, negativos e ambíguos, separa exemplos de aprendizado de avaliação e reporta acertos, falsos positivos e abstenções sem tratar fakes como resultado de Jev? | principle | essential |
| CK-11 | Controles de beta, consentimento e exclusão são utilizáveis por teclado/VoiceOver, têm rótulos claros e preservam foco, clipboard e continuidade do ditado, com aviso de erro acessível? | principle | important |
| CK-12 | A evidência identifica o candidato testado e separa teste local, uma chamada remota autorizada e prova física, sem declarar produção/qualidade comprovadas por código, mocks ou planejamento? | principle | essential |
| HR-1 | Planejamento e testes automatizados fazem zero chamadas pagas, e o teste controlado posterior usa somente a chave descartável autorizada, sem persistir seu valor em arquivos, logs, fixtures, commits ou memória? | hard_rule | essential |
| HR-2 | Antes da chamada controlada ficam registrados sem segredos o modelo/contrato vigentes, payload sintético, quantidade de uma chamada sem retry e estimativa de custo, sem habilitar uso recorrente, impor teto mensal ou usar fallback de conta/provedor? | hard_rule | essential |
| HR-3 | O trabalho usa o gate nativo serializado por mac-gate, preserva alterações alheias, cumpre branch/PR/checks aplicáveis e revisa as promessas de privacidade antes de disponibilizar qualquer funcionalidade remota? | hard_rule | essential |

**Regular Checks:**

Estes checks validam a implementação futura; não são executados para concluir a etapa exclusivamente documental da SPEC.

- [ ] Executar o gate nativo descoberto no README: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. O app é nativo; não inventar `npm run preflight:ci` ou Vercel Preview para esse target. CK-1–CK-7, CK-9, CK-11, HR-3.
- [ ] Inspecionar request capturado e logs com fakes sem rede, verificar ausência de segredos/dados excluídos e confirmar zero tentativas em opt-out, cancelamento, falta de credencial e planejamento. CK-7, CK-8, HR-1, HR-2.
- [ ] Executar corpus sintético separado e registrar matriz de confusão/abstenções por par; distinguir resultado do fake de eventual avaliação real, que exige autorização própria além da chamada única. CK-3, CK-4, CK-10.
- [ ] Revisar diff e evidência de privacidade, persistência, exclusão, identidade da tentativa e proveniência do candidato; se arquivos do site mudarem, executar também `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`, gate do workflow existente. CK-2, CK-6, CK-8, CK-9, CK-12, HR-3.
- [ ] Realizar roteiro físico em app candidato identificado: dois sentidos de rosto/Hostel, opt-out, novo ditado, teclado/VoiceOver e foco em TextEdit/navegador; registrar bloqueio de permissão/hardware sem substituir observação por fixture. CK-4, CK-6, CK-7, CK-11, CK-12.

**Rubric:**

| Criterion | Weight |
| --- | --- |
| Preservação de significado e decisão limitada | 0.30 |
| Privacidade e autorização do beta | 0.25 |
| Continuidade e reversibilidade | 0.20 |
| Evidência de aprendizado contextual | 0.15 |
| Project Guidelines Alignment | 0.10 |

**Rubric Score Definitions:**

### Preservação de significado e decisão limitada

Avaliar se a substituição depende de evidência da ocorrência e conserva texto legítimo. Cobertura: CK-1, CK-3, CK-4, CK-9.

Anchors:
- score_2:
  ```text
  Entrada: Meu rosto ficou vermelho. Saída: Meu Hostel ficou vermelho.
  ```
- score_4:
  ```text
  Entrada: Meu rosto ficou vermelho. Saída: Meu rosto ficou vermelho.
  ```
- contrast: A única diferença é a preservação da ocorrência corporal.

### Privacidade e autorização do beta

Avaliar se consentimento e payload respeitam o recorte aprovado, inclusive no teste controlado. Cobertura: CK-7, CK-8, HR-1, HR-2.

Anchors:
- score_2:
  ```text
  Chamada única; dados sintéticos; payload contém idioma, par, alternativas, frase atual e histórico pessoal.
  ```
- score_4:
  ```text
  Chamada única; dados sintéticos; payload contém idioma, par, alternativas e frase atual.
  ```
- contrast: A única diferença é a inclusão indevida de histórico pessoal.

### Continuidade e reversibilidade

Avaliar se falhas e ações do usuário preservam a entrega e tornam resultados antigos inócuos. Cobertura: CK-2, CK-5, CK-6, CK-7, CK-11.

Anchors:
- score_2:
  ```text
  Tentativa A cancelada; tentativa B inserida; resposta tardia de A: reinserida.
  ```
- score_4:
  ```text
  Tentativa A cancelada; tentativa B inserida; resposta tardia de A: ignorada.
  ```
- contrast: A única diferença é o efeito da resposta da tentativa cancelada.

### Evidência de aprendizado contextual

Avaliar se a evidência distingue a qualidade semântica do provedor da validação determinística do fluxo e mantém separação entre aprendizado e avaliação. Cobertura: CK-4, CK-10, CK-12.

Anchors:
- score_2:
  ```text
  Corpus sintético; respostas do fake; conclusão: qualidade linguística de Jev comprovada.
  ```
- score_4:
  ```text
  Corpus sintético; respostas do fake; conclusão: contrato local validado; qualidade linguística de Jev não medida.
  ```
- contrast: A única diferença é a conclusão permitida pela origem das respostas.

### Project Guidelines Alignment

Avaliar uso de gates reais, preservação do trabalho existente e rastreabilidade das evidências. Cobertura: CK-12, HR-1, HR-3.

Anchors:
- score_2:
  ```text
  Gate nativo XCTest executado diretamente por xcodebuild no Mac.
  ```
- score_4:
  ```text
  Gate nativo XCTest executado por mac-gate xcodebuild no Mac.
  ```
- contrast: A única diferença é a serialização obrigatória do gate.

**Test Strategy:**

Criticality: alta para integridade do texto, saída ao usuário, dados pessoais e credenciais. Falsos positivos em negativos protegidos bloqueiam habilitação do beta; abstenção segura é um resultado válido. Uma chamada controlada pode confirmar o contrato, mas não satisfaz avaliação semântica do corpus nem habilita rollout recorrente.

Test Matrix:

| Type | Size | Framework | Dependencies | Gate |
| --- | --- | --- | --- | --- |
| unit | Pequeno | XCTest | Exemplos sintéticos e storage isolado | Gate nativo via mac-gate |
| integration | Médio | XCTest | Provider falso, relógio controlado, transporte HTTP interceptado, saída falsa | Gate nativo via mac-gate; sem rede |
| corpus | Pequeno | XCTest/fixtures rotuladas | Pelo menos cinco pares sintéticos com conjunto de avaliação separado | Gate local; resultado fake identificado |
| manual | Roteiro limitado | App macOS + VoiceOver | Candidato identificado e permissões locais | Evidência física registrada |
| controlled-remote | Uma chamada | Cliente com request delimitado | Contrato vigente, chave descartável autorizada e payload sintético | Somente após planejamento; zero retry |

Test Cases to Cover:

#### CK-1: Salvar somente correção explícita
- [unit] Par válido e frase contendo a ocorrência salvam exemplo; ausência de ocorrência, vazio, identidade, conflito e entrada acima do limite não salvam nem alteram glossário.
- [integration] Salvar duas vezes não duplica; erro preserva draft e permite tentativa posterior; like, cancelar e expiração não aprendem.

#### CK-2: Persistência e exclusão
- [unit] Reabrir mantém exemplos; apagar item/tudo remove apenas dados contextuais; falha de escrita/leitura e versão desconhecida preservam dados válidos anteriores.
- [unit] Cadastros 99→100 são aceitos; 100→101 é recusado preservando os 100 registros; frases de 599/600 caracteres Unicode são aceitas e 601 é recusada sem truncar; cada correção tem somente uma frase rotulada.
- [integration] Excluir enquanto há decisão pendente invalida seu uso; limite atingido informa erro e exclusão manual, sem FIFO ou apagamento silencioso.

#### CK-3: Decisão restrita
- [unit] Validar `0,899`, `0,900`, `1`, valores não finitos/fora de faixa, opção desconhecida, campos inesperados, par inexistente e resposta truncada.
- [unit] Unicode composto/decomposto, termos inteiros, duas ocorrências e intervalo fora da frase não alteram posições erradas; output livre ou instrução embutida não vira comando.

#### CK-4: Preservação do sentido
- [corpus] Incluir rosto corporal, hospedagem, ambiguidade e frase mista; negativos protegidos não podem sofrer substituição.
- [integration] Resposta falsa válida aplica somente o Hostel da ocorrência autorizada; manter e baixa confiança preservam frase inteira.
- [manual] Ditar os dois sentidos e observar exatamente o texto entregue, identificando se a decisão veio de fake ou provedor real.

#### CK-5: Prazo e falhas
- [integration] Simular offline, 401/429/5xx, timeout, decoding inválido e falha de modelo; deadline antes/no/depois de 900 ms preserva saída e não repete requisição.
- [unit] Zero, três e quatro candidatos respeitam limite e abstenção; cronômetro total inclui preparação/resolução, não só tempo HTTP.

#### CK-6: Lifecycle da saída
- [integration] Cancelar A, iniciar B e receber A depois não altera B; saída final vai uma vez a histórico e inserção; candidato não recebe mutação retroativa.
- [integration] Erro de persistência/entrega existente continua com o tratamento original; resposta remota não mascara erro nem provoca nova inserção.

#### CK-7: Consentimento e desligamento
- [integration] Primeiro uso, opt-out, chave ausente/apagada e desligar durante request produzem zero novas chamadas e nenhum efeito tardio.
- [integration] Com a autorização sintética atual, ativar opt-in não habilita envio de ditado pessoal; concluir a chamada de diagnóstico não muda essa restrição.
- [manual] Conferir informação de dados/custo, controle de desligar e comportamento offline após reabrir.

#### CK-8: Fronteira de dados e autorização — HR-1, HR-2
- [integration] Capturar payload de 599/600/601 caracteres: respeitar teto sem cortar silenciosamente contexto necessário; rejeição mantém original. Conferir ausência de histórico, exemplos, áudio, identificadores e segredo em corpo/logs.
- [unit] Frase sintética contendo instruções maliciosas permanece dado; opções/contrato não são substituídos por seu texto.
- [controlled-remote] Após planejamento, uma chamada com frase sintética e chave autorizada confirma request/response/erro e registra uso/custo observado sem chave ou conteúdo pessoal; não repetir nem ampliar para corpus sem autorização específica.

#### CK-9: Legado e conflitos
- [integration] Vocabulário manual inequívoco e regras antigas continuam iguais; nova correção contextual não altera suas linhas; conflito preexistente rosto=Hostel fica explícito.
- [unit] Corpus e diagnóstico distinguem texto bruto, pós-processado e entrada do resolvedor para não atribuir ao beta uma transformação anterior.

#### CK-10: Evidência semântica
- [corpus] Pelo menos cinco pares têm exemplos distintos de aprendizado e avaliação; registrar por par aplicar/manter/abster, falso positivo e falso negativo, incluindo rosto/Hostel.
- [corpus] Relatório indica fonte das decisões e modelo quando houver; sem execução real autorizada o resultado de Jev consta como não medido.

#### CK-11: Uso acessível
- [manual] Percorrer consentimento, exemplo, salvar, erro, excluir e desligar por teclado/VoiceOver; validar nomes, foco restaurado e continuidade em TextEdit/navegador.
- [integration] Novo ditado durante editor/feedback conserva guards existentes e não reutiliza token antigo.

#### CK-12: Gates e prova — HR-3
- [integration] Registrar candidato e resultado do comando nativo serializado; nenhum gate de app é substituído por teste do site ou por mocks isolados.
- [manual] Conferir diff, documentação de privacidade e resultados persistidos; marcar separadamente prova física pendente, chamada controlada realizada e qualidade semântica ainda não medida.

**Definition of Done:**

**SPEC — entrega documental desta etapa:**

1. Descrição, escopo, cenários, checklist, rubrica, estratégia de testes, arquitetura e decomposição ficam consistentes e rastreáveis; limites mensuráveis e decisões pendentes estão explícitos.
2. A revisão da SPEC distingue critérios futuros de evidência já obtida, sem marcar implementação, chamada real ou prova física como concluídas.
3. O planejamento termina sem alterar produto, persistir/usar chave, chamar API paga ou publicar. A autorização de uma chamada sintética futura e a indisponibilidade do ditado pessoal remoto permanecem explícitas.

**Implementação futura — não exigida para concluir o planejamento:**

1. CK-1–CK-12 e HR-1–HR-3 possuem evidências identificadas do escopo implementado; critérios não observados permanecem pendentes, sem claims de qualidade real.
2. Gate nativo e regressões sem rede passam no candidato final, incluindo falso positivo rosto/Hostel, limites de armazenamento, timeout, cancelamento e payload.
3. Beta permanece desligado e reversível; ditado pessoal/remoto real segue indisponível até autorização específica; regras legadas e dados anteriores são preservados.
4. A chamada sintética controlada só é marcada concluída com resposta/erro e uso observados. Ela não comprova qualidade de Jev nem autoriza uso recorrente; eventual avaliação semântica real permanece pendente de autorização própria.
5. O candidato final pré-merge tem gates e prova física registrados em evidência versionada suficiente; a revisão única da fase 2 avalia esse candidato/evidência e exige PASS >= 4 antes de mover a task para `done`, fazer commit/push, conferir checks do SHA mais recente e integrar o único PR. Prova física pré-merge ausente impede esse fechamento. Rebuild/instalação do tree integrado após o merge são verificação operacional separada, não condição da fase 2/DoD; divergência ou falha posterior é incidente registrado sem reescrever a conclusão histórica nem alegar conclusão operacional. Uso remoto pessoal e avaliação semântica real continuam dependentes de autorização própria.

## Architecture Overview

### Fronteira e componentes

Esta arquitetura descreve implementação futura. A SPEC prevalece sobre propostas anteriores da skill: **100 itens, uma frase por item, 600 `String.count`, 900 ms totais, abstenção integral acima de três ocorrências e uma única chamada sintética posterior ao planejamento**. Não autoriza implementação, chamada, persistência de chave ou publicação nesta etapa.

| Componente | Responsabilidade mínima e integração |
| --- | --- |
| `DictationCoordinator` + `DictationCompletion` | Capturar tentativa, idioma e destino; aguardar o resolvedor antes de qualquer saída; entregar uma única string final; emitir conclusão somente após inserção bem-sucedida. A conclusão acrescenta snapshot imutável de texto final/idioma, sem defaults vazios que ocultem callers não atualizados. |
| `ContextualCorrections.swift` | Concentrar tipos internos `Codable`, store separado, seleção local de candidatos, identidade de ocorrências, validação conservadora, cliente Decisions e adaptador Keychain. Usar Foundation/Security existentes, sem SDK, embeddings, protocolo genérico de providers ou nova dependência. Injetar somente decisão/transporte, relógio e credencial necessários aos testes. |
| `FloatingPanelController` + editor existente | Receber o snapshot da conclusão, confirmar par/frase/ocorrência, salvar no store contextual e mostrar erro acessível preservando draft. Aposentar token e referências ao contexto no encerramento; Save nunca reenvia nem reinsere texto. |
| `ProductPreferences` + ajustes | Guardar apenas opt-in desligado por padrão e preferências operacionais; listar/apagar exemplos, apagar credencial e explicar a separação do glossário. Indicar que ditado pessoal remoto permanece indisponível, inclusive após opt-in ou diagnóstico. |
| `AppDelegate` + destinos existentes | Compor uma instância do store/resolvedor/credencial; invalidar operações em alterações de política, exclusões e término. Preservar `TextInjector`, histórico opcional, menus, foco e tratamento de erros existentes. Abrir ajustes, iniciar o app e salvar aprendizado não fazem requisições. |

O mapa completo de callers, testes, fixtures, configuração e documentação está em [analysis-context-aware-corrections.md](../../analysis/analysis-context-aware-corrections.md). A superfície prevista é a registrada ali: 14 arquivos existentes e dois novos, sem remoções. A implementação deve atualizar todos os construtores de `DictationCompletion`, callbacks e testes de Save; registrar a fixture em `project.yml` e regenerar o projeto Xcode. Alterações visuais/testes já presentes no worktree ficam preservadas.

### Fluxo e contrato de saída

```text
Whisper local -> pós-processamento/glossário legado -> original imutável
                                                       |
store local -> candidatos -> elegibilidade -> decisão limitada / manter
                                                       |
                                    validar tentativa + política + prazo
                                                       |
                                    final -> stage(final) [clipboard]
                                          -> onTranscript(final) [histórico opcional]
                                          -> insertStaged [destino capturado]
                                          -> conclusão -> feedback -> store local

transporte real: apenas diagnóstico sintético autorizado, uma vez
ditado pessoal: bloqueado para transporte real; testes usam fakes
```

“Original” é exatamente a saída do pós-processamento local recebida pelo resolvedor, antes da correção contextual. Não é o texto bruto do Whisper, e não se executa novamente substituição global depois da decisão.

O coordinator permanece em `.transcribing` durante a resolução. Após seu término e os guards, uma única variável `final` entra em `stage(final)` e em `onTranscript(final)`; `insertStaged` usa esse mesmo clipboard preparado e seus guards atuais. Preserva-se a ordem existente: histórico após stage e antes do retorno da inserção. Falha de inserção continua podendo deixar texto no clipboard/histórico para recuperação e não emite conclusão de sucesso.

CK-6 exige **a mesma decisão semântica e a mesma string na entrada dos destinos**, não igualdade irrestrita do arquivo de histórico com o clipboard. `TranscriptHistory.add` continua aplicando seu trim de espaços/quebras nas extremidades, `prefix(100_000)`, deduplicação e retenção de dez itens. Não se limita nem altera a inserção para imitar essa representação histórica. Testes verificam a igualdade nas chamadas e, separadamente, essas transformações legadas; copiar histórico não reexecuta o resolvedor.

### Aprendizado local, persistência e recuperação

O arquivo exclusivo será `Application Support/Resenha/ContextualCorrections/v1.json`, com envelope `schemaVersion: 1` e até 100 registros. Cada registro contém UUID local, idioma, `heard`, `canonical` e **uma única frase literal confirmada**, rotulada por ordinal da ocorrência ouvida. O ordinal começa em 1, conta os matches inteiros da mesma forma ouvida da esquerda para a direita e permite reconstruir o intervalo; não se persistem `String.Index`, transcrição completa, áudio, destino, chave nem resposta do modelo.

O editor obtém a frase do snapshot da conclusão, usando segmentação local de frases da Foundation e intervalo verificável no texto original. Mostra a frase e a ocorrência que receberá o rótulo; se houver múltiplas ocorrências, exige seleção explícita. Ausência de match, fronteira de frase duvidosa, par vazio/idêntico/inválido ou frase acima de **600 `String.count`** recusam Save sem truncar. Reusar as validações puras aplicáveis dos campos existentes, sem chamar o salvamento de glossário nem importar seus limites de quantidade/prompt.

Mesmo idioma, frase, ocorrência e par constituem duplicata idempotente. Mesma frase/ocorrência/idioma com outro destino é conflito e exige exclusão explícita do exemplo anterior; frases distintas podem registrar o mesmo par. O registro 100 é permitido; o 101 é recusado com orientação para exclusão manual, sem FIFO. O histórico desligado não impede aprendizado explicitamente confirmado; seus controles e retenção são independentes.

O store serializa mutações, valida todo o envelope e só publica o novo snapshot após escrita atômica com leitura de confirmação. Diretório `0700`, arquivos e temporários `0600`; leitura/serialização têm teto operacional de 2 MiB, separado do limite de caracteres, para evitar alocação ilimitada. Preparar e validar candidato em arquivo temporário no mesmo diretório; preservar a versão anterior até validar a substituição final. Em falha, restaurar e conferir a anterior; se a recuperação também falhar, manter a cópia anterior, bloquear mutações e oferecer erro/releitura explícita. Nunca responder sucesso com dados apenas em memória.

Arquivo ilegível, corrompido, grande demais ou com versão desconhecida permanece preservado e indisponibiliza o store para novas mutações; não vira uma lista vazia gravável. Se já houver snapshot confiável em memória, ele não é perdido, mas resolução usa original enquanto a saúde do store for incerta. Não há migração automática de schema desconhecido. Apagar item/tudo exige persistência confirmada e invalida a geração da política; apagar tudo também cobre somente temporários/backups de transação pertencentes a esse store, sem tocar histórico, glossário ou modelos. A interface não anuncia exclusão concluída se algum arquivo contextual conhecido permanecer por erro.

### Snapshot efêmero e ownership

`DictationCompletion` carrega texto final/idioma apenas após sucesso de `insertStaged`, capturados antes de `reset`. O panel torna-se dono do contexto de feedback; nunca busca texto em histórico, clipboard, app de destino ou sessão anterior. Expiração passiva de quatro segundos, aprovação, Save concluído, cancelamento normal, substituição por nova oferta, novo ditado, HUD desligado e término liberam esse snapshot.

Em `offerFeedback`, extrair `let token = context.id` antes de construir as actions e capturar apenas esse UUID e `weak self`. Capturar `context.id` diretamente pode reter o contexto inteiro no `NSHostingView` que continua instalado após `orderOut`. Encerrar o editor também deve remover sua view/contexto retido; esconder janela ou zerar somente `feedback` não comprova liberação.

Erro de Save mantém o editor e o draft necessário à recuperação. Ao fechar para recuperação pendente, reter somente par, frase de até 600 caracteres, ordinal, idioma e referência mínima de foco; liberar a transcrição completa. Se não houver frase validada, preservar os campos digitados e exigir nova confirmação contextual antes de Save, sem carregar a transcrição indefinidamente. Novo ditado/HUD-off/término retiram também esse draft.

Uma regressão com probe fraco mantém panel e closures antigas vivos, encerra cada caminho e comprova liberação do contexto após processar o main actor/autorelease. Closures aposentadas podem reter UUID, mas não texto nem poder de agir na próxima sessão. Isso prova ausência de ownership residual; não promete zerar todas as cópias de bytes de `String` na memória.

### Seleção, ocorrência e decisão Jev

A seleção local consulta somente exemplos confirmados do mesmo idioma cujo `heard` corresponde a termo inteiro na entrada imutável. Deduplica pares; a frase armazenada permanece evidência local auditável, nunca prompt remoto. Não há recuperação de histórico, aprendizado de likes/resultados automáticos ou similaridade vetorial. Exemplos que oferecem destinos conflitantes para uma ocorrência não autorizam escolha arbitrária: manter a entrada inteira.

Enumerar matches Unicode com o padrão de fronteira de palavras já usado no projeto, sem normalizar/mutar a entrada depois de obter os ranges. Cada ocorrência tem par local, ordinal por `heard` dentro da frase e span Swift validado tanto na frase quanto na entrada completa. Sobreposição de ranges, divergência de ordinal/span ou impossibilidade de segmentar sem ambiguidade tornam a resolução inelegível.

Contar todas as ocorrências candidatas antes de qualquer request ou substituição. Zero retorna original imediatamente; **mais de três retorna toda a entrada original, com zero requests**, sem escolher as primeiras três. Para uma a três, este beta envia no máximo uma frase por request: todas precisam caber na mesma frase intacta de até 600 `String.count`. Se exigirem frases diferentes ou contexto acima do teto, abster-se integralmente; não concatenar nem truncar contexto. Essa limitação deliberada evita um fluxo de múltiplas chamadas e deve aparecer nos testes e rótulos de elegibilidade do corpus.

O contrato pesquisado é `POST https://openrouter.ai/api/alpha/decisions`, modelo fixado `typesafe/jev-1.14`; revalidar schema/modelo antes da única chamada futura, pois a rota é alpha. Uma questão `choice` por ocorrência oferece somente `keep_original` ou `replace_1`, mapeados ao par local. Questões podem compartilhar a frase. IDs técnicos das questões correlacionam respostas; o ordinal é descrito nas instruções geradas, sem UUID de usuário/tentativa, offsets fornecidos pelo modelo ou marcadores inseridos no texto. Esses metadados de estrutura não acrescentam outra fonte de dados ao payload permitido em CK-8.

Validar HTTP, envelope, conjunto exato de questões, tipo, labels, probabilidades e confiança. Rejeitar resposta truncada, campos incompatíveis com o schema esperado, questão extra/ausente, números não finitos/fora de `[0,1]`, distribuição inválida, empate ou choice inconsistente. Campos de metadados documentados do envelope não autorizam dados extras na decisão. A resposta pode identificar um snapshot datado do modelo, sem exigir igualdade textual com o alias solicitado.

Aplicar apenas se **confidence >= 0,90 e probabilidade da alternativa escolhida >= 0,90**, com vencedor único. São barreiras conservadoras do produto, não precisão comprovada; confidence não equivale à probabilidade escolhida. Congelar esses thresholds antes da avaliação e registrar margem para a segunda opção no relatório sintético. `keep_original` válido preserva somente seu span e não veta `replace_1` válido e confiante em outra ocorrência da mesma frase. A abstenção integral fica reservada a resposta inválida/incerta, timeout, erro ou conjunto inelegível. Com todas as decisões válidas, aplicar somente os spans de `replace_1`, do último para o primeiro, com o `canonical` local literal, preservando os spans de `keep_original`. `$` e `\\` nunca são interpretados como template de regex. Texto fora dos spans substituídos permanece idêntico.

### Autorização, privacidade e transporte

Há duas barreiras independentes: preferência opt-in e escopo autorizado. O segundo permanece **synthetic-only**: o resolvedor de ditado pessoal não possui caminho habilitável para transporte real, mesmo com chave/opt-in. Fakes podem exercitar a decisão contextual no fluxo completo sem rede. Uma única execução de diagnóstico, separada desse fluxo e posterior ao plano, usa uma fixture sintética previamente revisada; ela não muda a política do app.

Antes desse diagnóstico, registrar sem segredo modelo/contrato revalidados, payload sintético exato, uma chamada sem retry e estimativa de custo. O guard de execução única é consumido atomicamente antes do despacho e registrado sem conteúdo pessoal/credencial, para impedir repetição por concorrência, novo clique ou reinício. Timeout, erro e resultado desconhecido consomem a autorização; nunca reiniciar o guard automaticamente. Não criar orçamento mensal, reabastecimento, troca de conta/modelo/provedor ou credencial de fallback.

Elegibilidade é local e anterior à serialização: nomes pessoais, emails, telefones, documentos, usernames, endereços ou classificação duvidosa no par/frase tornam o request inelegível, inclusive menções incidentais. Regex de identificadores sozinha não prova ausência de nomes. Sem mecanismo local confiável, a fronteira efetiva deste beta é a allowlist de fixtures sintéticas revisadas e imutáveis; texto arbitrário do usuário continua bloqueado. Não chamar detector remoto nem redigir a frase para contornar o bloqueio. Fixtures de nomes/PII sintéticos devem produzir zero requests.

Payload de domínio contém apenas idioma, par(es) candidato(s), alternativas e a frase sintética autorizada; o envelope técnico contém modelo e questões do contrato. Nunca inclui exemplos armazenados, histórico, áudio, clipboard, app/destino, IDs locais, texto adicional ou chave no corpo. A amostra mais ampla da skill, com `confirmed_examples`, **não é o request deste beta**.

Usar cliente dedicado `URLSessionConfiguration.ephemeral`, sem caches, cookies ou credential storage, HTTPS/host fixos e rejeição de redirects. Limitar resposta a 64 KiB, verificando o limite durante leitura. Autenticação somente no header. Não reutilizar `URLSession.shared` nem o delegate de download de modelos. Sem retry para offline, 401/402/403, 429, 5xx, timeout ou modelo indisponível.

A chave descartável, somente na etapa futura autorizada, entra pelo controle seguro e adaptador `SecItem` com service/account fixos, sem sincronização, acesso amplo ao Keychain, defaults, ambiente/CLI ou arquivos. Conferir cada `OSStatus`, incluindo item ausente, atualização, Keychain bloqueado/negado e exclusão. Falhas deixam a disponibilidade remota desativada. Testes usam double de credencial e nunca o Keychain pessoal. Exclusão/revogação permite continuar ditando localmente; não afirmar exclusão local se `SecItemDelete` falhar.

Não adicionar analytics nem logs de texto. Diagnóstico local pode registrar somente categoria de resultado/erro, duração, contagem de candidatos/chamadas, versão de schema/corpus e modelo/uso/custo do teste sintético, sem headers, corpos, pares, frases, caminhos pessoais ou erro bruto do provedor. Ephemeral controla armazenamento do cliente; não prova retenção zero no servidor. Revisar consentimento, documentação e declarações de privacidade antes de disponibilizar qualquer função remota; políticas do endpoint e uma futura autorização real precisam de verificação própria.

### Prazo, cancelamento e saída única

O prazo monotônico de **900 ms** começa na entrada do resolvedor e inclui seleção local, elegibilidade, encoding, rede, decoding, validação e preparação do resultado. O prazo do cliente HTTP usa somente o saldo restante. Um encerramento único aceita o primeiro resultado válido ou o deadline; cancelar o transporte e descartar callbacks tardios não deve esperar indefinidamente um filho não cooperativo de task group. Testar esse comportamento com relógio controlado e transporte que conclui depois do cancelamento.

| Evento | Resultado e efeitos permitidos |
| --- | --- |
| Beta desligado, autorização/credencial ausente, store indisponível, ineligibilidade, falta de candidato, ambiguidade ou falha | Original inalterado; continuar uma vez pelo fluxo existente, sem chamada quando a falha for conhecida antes do despacho. |
| Prazo atingido ou resposta inválida/incerta | Original uma vez; cancelar/desconsiderar request pendente, sem retry ou alteração posterior. |
| Opt-out, exclusão de exemplo(s) ou credencial durante decisão | Incrementar geração da política, cancelar trabalho e rejeitar resultado dessa geração; tentativa ainda válida continua localmente com original. |
| Cancelamento completo do ditado, tentativa substituída ou término | Abandonar a tentativa; nenhum novo stage, histórico ou inserção. Não converter cancelamento em fallback que ressuscita a saída. |
| Resposta válida e tentativa/política/prazo atuais | Revalidar snapshot/spans e entregar final uma vez. Após entrega, resposta/ação antiga não pode editar qualquer destino. |

Guardar snapshot de texto, idioma, pares, tentativa, destino e geração de política antes de suspender. Conferir identidade/cancelamento antes de trabalho remoto e após cada `await`; conferir a geração e o prazo imediatamente antes dos efeitos. Manter proteções de destino/changeCount do injetor e guard pós-inserção do coordinator. Cancelamento posterior a um stage já ocorrido impede novos efeitos, mas não desfaz clipboard/histórico preexistentes nem promete retirar texto já entregue.

### Compatibilidade, ADRs e rollback

| Decisão | Motivo / tradeoff |
| --- | --- |
| ADR-1 — Store contextual separado; nenhuma migração de glossário | O glossário continua alimentando prompt Whisper e substituições globais explícitas. Feedback novo deixa de chamá-lo. Regras antigas ambíguas são exibidas como conflito e só mudam por ação explícita; o resolvedor não recupera uma palavra já alterada antes de sua entrada. |
| ADR-2 — Um resolvedor anterior aos destinos; fail-closed | Preserva o fluxo e o mecanismo de recuperação existentes. Timeout/abstenção reduzem recall, mas não autorizam segunda inserção ou reescrita livre. Texto bruto, pós-processado e entrada contextual ficam distintos na evidência sintética. |
| ADR-3 — Uma frase, até três ocorrências, escolha binária por ocorrência | Mantém payload, spans e custo limitados. Frases múltiplas, conflitos e conjuntos parcialmente incertos abstêm por inteiro; o corpus congela essas condições antes de medir recall. |
| ADR-4 — Uso real bloqueado; diagnóstico consumível uma vez | Cumpre a autorização existente sem usar opt-in como permissão para uso recorrente. A chamada única prova contrato, não qualidade PT-BR, latência de produção ou prontidão para rollout. |
| ADR-5 — JSON versionado, sem FIFO, transporte nativo | Reaproveita padrões do app sem dependências nem infraestrutura nova. Lotações/erros exigem ação explícita; schema desconhecido fica preservado em vez de migrado por adivinhação. |

Desligar o beta invalida operações e volta imediatamente ao fluxo local legado; não remove dados ensinados sem pedido. Apagar exemplos ou chave tem controles próprios. Reverter o código da feature deixa seu arquivo separado preservado e ignorado pela versão anterior, sem migrar dados de volta ao glossário. Rollback não altera histórico/clipboard/texto já entregue. Antes de um release remoto, atualizar declarações do app, documentação e materiais de publicação conforme o comportamento efetivo; esta SPEC não publica nem altera respostas de loja.

### Validação e riscos de habilitação

Adotar corpus sintético mínimo de **100 casos e pelo menos cinco pares ambíguos**: 30 negativos de sentido comum, 20 positivos elegíveis, 20 ambíguos/contraditórios, 15 de ocorrências/Unicode e 15 de segurança/lifecycle. Separar frases de aprendizado/calibração/avaliação por famílias, congelando elegibilidade, thresholds e respostas esperadas antes de executar. Incluir “Meu rosto ficou vermelho”, “O rosto ficou estranho”, hospedagem, frase mista, 599/600/601 caracteres Unicode, limite 99/100/101, zero/três/quatro ocorrências e frases distintas.

Gates semânticos exigidos conjuntamente: **zero trocas indevidas em todo o conjunto de avaliação e recall >= 80% em pelo menos 20 positivos elegíveis predefinidos** — no mínimo 16 reparos corretos por ocorrência. Abstenção, timeout e erro em positivo contam como falha; casos inelegíveis por privacidade continuam checks separados de zero requests. Não retirar positivos do denominador após observar resultados. Comparar com manter-original e substituição global; manter sempre passa segurança e falha utilidade.

Caso misto obrigatório no corpus e no gate de ocorrência: “Lavei o rosto no banheiro do rosto” recebe `keep_original` válido no ordinal 1 (corporal) e `replace_1` válido/confiante no ordinal 2 (hospedagem), produzindo exatamente “Lavei o rosto no banheiro do Hostel”. O primeiro span e todo o restante ficam intactos. Com fake, esse caso comprova o contrato local; na avaliação real autorizada, trocar o primeiro span viola o gate de zero trocas indevidas e não corrigir o segundo conta como falha de recall.

Fakes, `URLProtocol`, credencial falsa e storage temporário validam contrato, payload, persistência/rollback, spans, deadline, liberação de contexto e ordem/exatamente-uma-entrega. Não medem qualidade de Jev. A chamada sintética única também não executa esse corpus: avaliação real permanece pendente de autorização própria, e o gate semântico real permanece **não medido**, bloqueando habilitação de correção automática remota para ditado pessoal. Relatório identifica fonte das decisões, versão do corpus/prompt, modelo efetivo, precisão/recall, falsos positivos, abstenções e, quando medidos, latência p50/p95/p99, chamadas/tokens/custo.

Implementação futura executa o gate nativo via `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; testes do site só se seu escopo mudar. A fase documental verifica consistência e diff, sem rodar o app/API. Prova física posterior usa candidato identificado, campos descartáveis em TextEdit/navegador, teclado/VoiceOver e permissões reais; testes locais não substituem esse resultado.

| Risco residual | Controle / condição de liberação |
| --- | --- |
| Confiança não calibrada e menor domínio de PT-BR | Threshold não é garantia; exigir corpus real autorizado com ambos os gates antes de disponibilizar correção remota automática. |
| Uma regra legada já corromper/biasar reconhecimento | Mostrar conflito; preservar regra até ação explícita; não atribuir esse resultado ao resolvedor contextual. |
| PII não detectada ou política de retenção desconhecida | Ditado real indisponível; allowlist sintética e zero uploads de exemplos; verificar políticas antes de qualquer expansão autorizada. |
| Resposta atrasada ou contexto retido em janela/closure | Guard de tentativa/geração/deadline e regressões de transporte tardio/ownership; nenhuma reinserção. |
| Falha de disco/Keychain ou mudança do contrato alpha | Preservar dados, bloquear mutação/remote e manter ditado local; revalidar contrato antes da chamada e nunca trocar provedor automaticamente. |

## Implementation Process

Esta seção planeja trabalho futuro; não autoriza iniciá-lo nesta etapa documental. Antes de 01, concluir e integrar na `main` a dependência `add-transcription-feedback` até seu feedback visual/Phase 4, registrar o SHA integrado e criar um worktree limpo com uma branch própria a partir dessa `main` atualizada. O antigo Step 07/Phase 5 de Jev é substituído por esta task e **não** é pré-requisito, evitando dependência circular. Não implementar sobre `feat/transcription-feedback`, transportar WIP visual sem integração, reaproveitar seu PR ou apagar alterações existentes. Esta feature usa um único PR próprio; os caminhos da task abaixo acompanham sua localização caso seja promovida pelo orquestrador.

**Diretiva de execução:** lançar um agente por passo, fornecendo o caminho desta task e o arquivo do passo; usar seu `Model`/`Agent`, implementar exatamente aquele escopo e executar passos marcados paralelos em paralelo. Aqui a largura é 1: 01 e 02 compartilham contratos e o arquivo XCTest, 03 documenta o comportamento efetivamente entregue, e 04 depende da revisão local completa. Não criar agentes adicionais por arquivo. Executar o code reviewer **uma única vez por fase**, no modelo indicado, após seus passos; corrigir achados antes de avançar. O marco da fase 1 inclui revisão de código/privacidade, gates e candidato identificados antes de qualquer chamada real. A revisão única da fase 2 avalia o candidato final instalado/testado **pré-merge** e sua evidência versionada; somente após PASS >= 4 o orquestrador move a task para `done`, faz commit/push na mesma branch, confere checks do SHA mais recente e integra o único PR. A verificação operacional pós-merge não cria quinto passo nem nova revisão de fase.

Nenhum passo introduz SDK, dependência, provider genérico, gasto recorrente ou migração do glossário. Persistência, transporte, credencial e lifecycle usam `opus`; somente documentação/evidência isoladas usam `sonnet`. Os tiers são atribuições de execução futura, não autorização para acionar outra API paga. Testes usam transporte/credencial falsos e storage isolado. Gate nativo: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Reinspecionar os workflows reais na branch futura; não inventar npm/Vercel para este target nativo nem executar gates fora de `mac-gate`.

A fixture de diagnóstico de `Tests/Fixtures/contextual-corrections.json` deve constar explicitamente como recurso do target app `WhisperKey` em `project.yml` e na fase Copy Bundle Resources do projeto Xcode gerado, além do uso nos testes. O diagnóstico carrega a cópia do bundle candidato; XCTest comprova essa carga sem depender do checkout ou do bundle de testes. A fixture continua inteiramente sintética, sem segredos/dados reais.

**Ordem de fechamento vigente:** após a chamada sintética e os gates, 04 instala/testa fisicamente o candidato final pré-merge e completa `docs/testing/context-aware-corrections.md` antes da revisão da fase 2. As pendências físicas registradas em 03 são preenchidas em 04; esta ordem substitui qualquer orientação anterior que adie a prova necessária ao DoD para depois do merge. A evidência identifica snapshot de source/config/recursos, candidato/binário, assinatura, hashes e resultados. Depois do PASS, alterações de fechamento são apenas documentais; o commit final deve conservar exatamente o source testado. Alteração de source invalida a prova correspondente e exige sua revalidação antes da integração.

Após merge, comparar o tree do commit final da branch com o tree integrado e confirmar a equivalência de source/config/recursos com o candidato aprovado; registrar commit final, tree IDs, merge SHA e hashes. Rebuild/instalação do tree integrado e checagem operacional ficam em artefato local identificado e comentário no mesmo PR/issue, sem segundo commit/PR. Essa verificação é posterior à fase 2/DoD: divergência de tree/source ou falha de build/instalação/uso gera incidente e impede afirmar conclusão operacional, preservando o registro histórico do candidato pré-merge avaliado.

### Parallelization Overview

```text
Feedback visual integrado na main + branch própria
                         |
Fase 1 — app utilizável localmente, rede real bloqueada
01 Fundamentos e transporte isolado (opus)
                         |
02 Integração do aprendizado e lifecycle (opus)
                         |
03 Privacidade, gates e candidato (sonnet)
                         |
               Uma revisão opus
                         |
Fase 2 — diagnóstico autorizado e prova física pré-merge
04 Uma chamada sintética -> gates -> instalação/prova final (opus)
                         |
          Uma revisão opus: PASS >= 4
                         |
       done -> commit/push -> checks do SHA final -> merge
                         |
Rebuild/instalação operacional do tree integrado (fora da fase 2/DoD)
```

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
| --- | --- | --- | --- | --- | --- | --- |
| 01 — Fundamentos locais e transporte isolado | 1 | opus | developer | Dependência integrada; branch própria | None | [01-local-core-and-transport.md](../../sub-tasks/add-context-aware-corrections/01-local-core-and-transport.md) |
| 02 — Aprendizado, controles e lifecycle | 1 | opus | developer | 01 | None | [02-contextual-feedback-lifecycle.md](../../sub-tasks/add-context-aware-corrections/02-contextual-feedback-lifecycle.md) |
| 03 — Privacidade e evidência local | 1 | sonnet | developer | 02 | None | [03-privacy-and-local-evidence.md](../../sub-tasks/add-context-aware-corrections/03-privacy-and-local-evidence.md) |
| 04 — Diagnóstico e instalação final | 2 | opus | developer | 03 e revisão da fase 1 | None | [04-controlled-diagnostic-and-physical-proof.md](../../sub-tasks/add-context-aware-corrections/04-controlled-diagnostic-and-physical-proof.md) |

Caminho crítico: **dependência integrada → 01 → 02 → 03 → revisão da fase 1 → 04 com prova física pré-merge → revisão da fase 2 PASS >= 4 → done/commit/push/checks/merge**. Largura máxima: **1**. Quatro passos; nenhuma instalação física ou chamada real em 01–03. O passo 04 é uma fase própria porque cruza a fronteira entre comprovação local, única transmissão autorizada e ambiente físico; agrupá-lo com código permitiria gastar a autorização antes da revisão local. A verificação operacional pós-merge é acompanhamento da integração, não requisito retroativo para fechar a fase 2/DoD.

### Phase Overview

#### Phase 1 — Aprendizado local e candidato validado sem rede

Steps: 01, 02, 03.

Reviewer model: opus — integridade do store, fronteira de credencial/rede e contrato compartilhado entre coordinator, panel e app; teto da escala.

Acceptance Criteria that should be fulfiled: candidato nativo compilável/executável salva e administra exemplos locais, preserva glossário e ditado offline, tem integração contextual exercitada por fakes e mantém bloqueado todo transporte real de ditado pessoal. Corpus, captura de request, regressões, gate completo e documentação correspondem ao candidato final. O diagnóstico real também não foi executado. A revisão ocorre antes de abrir o passo 04; não exige confirmação humana adicional para ações já autorizadas.

Checklist items:
- CK-1, CK-2, CK-9: Save explícito, armazenamento/exclusão recuperáveis e legado preservado, incluindo conflito visível.
- CK-3, CK-4, CK-5, CK-10: spans, contrato, limites e corpus sintético local; qualidade semântica real de Jev permanece não medida.
- CK-6, CK-7: ordem dos destinos, cancelamento/ownership, opt-out e barreira sintética, incluindo invalidação pendente.
- CK-8, HR-1, HR-2: payload e autorização única provados com fakes; nenhum segredo real/dispatch; preparação do diagnóstico sem consumir a chamada.
- CK-11, CK-12, HR-3: acessibilidade verificável localmente, privacidade, proveniência e gate serializado; teclado/VoiceOver/foco físicos e integração remota ainda pendentes.

Rubrics:
- Preservação de significado e decisão limitada.
- Privacidade e autorização do beta.
- Continuidade e reversibilidade.
- Evidência de aprendizado contextual.
- Project Guidelines Alignment.

#### Phase 2 — Uma chamada sintética e prova física atribuível

Steps: 04.

Reviewer model: opus — valida a fronteira de uma única chamada paga e a proveniência/segurança da instalação; teto da escala. Nenhum novo desenho de produto nesta fase.

Acceptance Criteria that should be fulfiled: somente após a fase 1 concluída, uma chamada sintética delimitada usa a chave descartável pelo controle seguro; o resultado/erro e uso observado são registrados sem segredo. A autorização é consumida mesmo em timeout/resultado desconhecido. Após os gates, instalar/testar fisicamente o candidato final **pré-merge** em campos descartáveis e registrar evidência versionada suficiente para a revisão única desta fase. PASS >= 4 libera o fechamento documental/commit/push/checks do SHA mais recente e merge do único PR; merge e rebuild/instalação operacional posteriores não são pré-condições desta revisão. Ditado pessoal remoto e avaliação real do corpus continuam bloqueados. Falha de credencial, serviço, permissão ou hardware fica explícita e não vira sucesso ou licença para repetir a chamada; prova física obrigatória pendente impede PASS/DoD.

Checklist items:
- CK-7, CK-8, HR-1, HR-2: diagnóstico sintético real isolado, opt-out, exclusão da credencial e nenhuma ampliação de autoridade.
- CK-1, CK-2, CK-9, CK-11: confirmação/exclusão local, transparência do conflito legado, teclado/VoiceOver e foco observados no candidato instalado.
- CK-4, CK-5, CK-6: os dois sentidos são ditados localmente; nenhuma chamada de ditado ou mutação tardia. Substituição contextual física, se exercitada, usa fixture/fake sintético identificado, sem alegar inferência Jev sobre fala pessoal.
- CK-10, CK-12: corpus fake, chamada única e prova física separados; gates semânticos reais continuam não medidos.
- HR-3: snapshot de source/config/recursos, candidato instalado pré-merge, gate e hashes/resultados físicos rastreáveis em evidência versionada. Após PASS, preservar esse source no commit final e verificar checks antes do merge; equivalência do tree integrado e resultado operacional posterior ficam em artefato local/comentário no mesmo PR/issue, fora da fase 2/DoD e sem segundo commit/PR. Publicação de release/loja/site não faz parte deste passo.

Rubrics:
- Preservação de significado e decisão limitada — limites da observação física e ausência de alteração indevida.
- Privacidade e autorização do beta — transmissão única e ditado remoto indisponível.
- Continuidade e reversibilidade — desligamento, exclusão e continuidade física local.
- Evidência de aprendizado contextual — proveniência e limites de cada evidência.
- Project Guidelines Alignment — candidato final pré-merge efetivamente instalado/testado e evidência suficiente antes do fechamento e integração.
