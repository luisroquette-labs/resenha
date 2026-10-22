---
title: Implement continuous contextual transcription intelligence
depends_on:
  - .specs/tasks/done/add-context-aware-corrections.feature.md
---

## Initial User Prompt

“A ideia é que o JEV monitore e avalie sempre o sentido do que está sendo dito para adaptar, em milésimos de segundos, a transcrição. Precisamos evoluir para o plano completo em que o sistema atua como a previsão contextual do iPhone, tornando a escrita fluida.”

# Description

**What:** Evoluir o ditado do Resenha para avaliar o sentido continuamente enquanto a pessoa fala e adaptar hipóteses provisórias antes da inserção definitiva. A experiência desejada é a fluidez da previsão contextual do iPhone: acompanhar o significado em formação sem interromper o usuário. JEV é um possível avaliador de alternativas textuais; esta especificação não presume que ele transcreva áudio, gere próximos tokens ou cumpra as metas de tempo.

**Why:** Reduzir correções manuais de termos ambíguos, nomes e vocabulário pessoal, preservando o que a pessoa quis dizer. A melhoria deve demonstrar benefício sem introduzir frases inventadas, espera prolongada ou alterações inesperadas em texto já inserido.

**Who:** Pessoas que usam ditado push-to-talk no Resenha em Mac Apple Silicon, inicialmente em português brasileiro com termos técnicos em inglês. Os modos atuais em inglês e espanhol precisam continuar utilizáveis, sem promessa de melhoria sem avaliação própria.

**Scope Included:**

1. Avaliação contextual repetida durante o ditado ativo, com hipóteses provisórias visíveis no próprio Resenha e finalização ao soltar o atalho.
2. Adaptações limitadas ao conteúdo reconhecido e a alternativas justificadas pelo contexto recente e vocabulário confirmado; avaliação objetiva de fidelidade e fluidez.
3. Orçamentos mensuráveis de captura, reconhecimento, decisão e inserção, com degradação previsível e preservação da transcrição local.
4. Contexto limitado à sessão, controles de privacidade/custo, experiência offline e cancelamento seguro.
5. Prova em corpus e hardware real, incluindo acessibilidade, regressões e distinção entre capacidade pretendida e comprovada.

**Scope Excluded:**

1. Escuta ambiente fora do push-to-talk, leitura do campo de destino, captura de tela e coleta automática de conteúdo de outros aplicativos.
2. Autocompletar palavras ainda não ditas, geração livre de frases, agente de escrita geral ou afirmação de que JEV faz previsão de tokens.
3. Reescrita retroativa, inserção de parciais no aplicativo externo ou alteração do texto depois da inserção final.
4. Sincronização remota de histórico, treinamento automático com ditados, expansão do glossário sem confirmação e migração de dados existentes.
5. Nova assinatura, troca automática de provedor, chamadas pagas não autorizadas ou publicação de promessa de velocidade sem medição.

**User Scenarios:**

1. **Principal:** com a função habilitada, a pessoa dita uma frase ambígua; a hipótese aparece como provisória e acompanha o contexto que chega; ao soltar o atalho, uma única versão final é inserida no aplicativo original.
2. **Alternativo:** sem exemplos pessoais ou sem evidência suficiente para corrigir, o texto reconhecido permanece; nomes, números e negações não mudam por uma preferência semântica especulativa.
3. **Offline/opt-out:** sem internet ou com a função desabilitada, o ditado local continua disponível; nenhuma configuração aciona uma conta ou API remota por conta própria.
4. **Falha/atraso:** uma decisão falha, chega tarde ou pertence a uma hipótese antiga; o Resenha usa a transcrição local válida e ignora o resultado obsoleto, sem nova colagem.
5. **Interrupção:** cancelamento, perda de permissão, mudança do contexto consentido ou encerramento da sessão invalidam o trabalho pendente; uma nova sessão não recebe texto ou contexto da anterior.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
|---|---|---|---|
| CK-1 | Durante fala contínua com a função habilitada, há hipóteses e decisões contextuais repetidas antes de soltar o atalho, usando o contexto que chega, sem escuta fora do push-to-talk e sem afirmar que JEV gera tokens? | hard_rule | essential |
| CK-2 | As hipóteses são identificadas como provisórias, exibidas apenas no Resenha, atualizadas sem roubar foco e nunca enviadas ao clipboard, histórico definitivo ou campo externo antes da finalização? | hard_rule | essential |
| CK-3 | A medição monotônica atende aos orçamentos abaixo em hardware real, separa cada estágio e registra também falhas, fallback e amostras frias, sem confundir rapidez de fallback com rapidez da adaptação? | hard_rule | essential |
| CK-4 | Ao atingir o prazo rígido de 200 ms da decisão contextual, ou diante de indisponibilidade, erro, resposta inválida, ambiguidade ou orçamento excedido, o sistema preserva o candidato local válido, sem retry bloqueante nem alteração posterior por resposta tardia? | hard_rule | essential |
| CK-5 | Cada alteração aceita permanece vinculada ao candidato reconhecido e à ocorrência exata, rejeita geração livre, mudança de números/negações sem evidência e dados malformados ou desproporcionais, preservando o original se a validação falhar? | hard_rule | essential |
| CK-6 | Ao finalizar, o sistema reconcilia apenas a revisão final válida e insere uma única vez no aplicativo original, preservando proteções de foco, clipboard e Acessibilidade, sem reescrever qualquer texto após essa inserção? | hard_rule | essential |
| CK-7 | Cancelamento, nova tentativa, revisão superada, revogação de consentimento, exclusão de exemplos e perda de permissão invalidam resultados pendentes, impedindo mistura entre sessões e qualquer efeito tardio? | hard_rule | essential |
| CK-8 | A função inicia desligada, áudio permanece local e envio remoto de texto exige opt-in específico e revogável com dados/provedor/custo informados, sem reutilizar autorização do diagnóstico sintético nem acionar fallback pago automático? | hard_rule | essential |
| CK-9 | Sem internet, sem credencial, com modo remoto desligado ou provider indisponível, o ditado local continua funcionando e a interface informa o modo local sem bloquear a finalização? | hard_rule | essential |
| CK-10 | O contexto temporário usa somente a sessão atual, no máximo os últimos 30 segundos e 600 caracteres reconhecidos, mais até cinco exemplos locais pertinentes, e é descartado ao finalizar/cancelar, sem acesso ao histórico ou ao aplicativo externo? | hard_rule | essential |
| CK-11 | O trabalho contextual mantém no máximo uma avaliação ativa e uma revisão pendente substituível, não inicia avaliações a intervalos menores que 500 ms e limita eventual texto remoto serializado a 4096 bytes UTF-8, descartando exemplos mais antigos primeiro e falhando para local se ainda exceder? | hard_rule | essential |
| CK-12 | Um corpus congelado antes da implementação demonstra redução de erros contextuais contra o modo desligado, com pelo menos 40 casos PT-BR e dez controles sem correção necessária, zero novas alterações de sentido nos controles e critérios de comparação registrados antes da execução? | hard_rule | essential |
| CK-13 | O relatório identifica commit, build, modelo reconhecedor, avaliador, hardware e condições da medição, separa teste simulado de teste real e evita apresentar a capacidade como comprovada quando faltar prova de qualidade, latência ou provider autorizado? | hard_rule | essential |
| CK-14 | Com a função desligada, atalho, idioma, glossário, histórico opcional, mensagens de erro e inserção preservam o comportamento anterior, sem chamada remota ou custo adicional? | hard_rule | essential |
| CK-15 | A indicação provisório/final/local e o controle de ativação são acessíveis por teclado e VoiceOver, respeitam movimento reduzido e não anunciam cada revisão parcial de modo a interromper o ditado? | principle | important |
| CK-16 | O gate nativo aplicável compila e executa os testes sem falha, inclui regressão para os comportamentos alterados e mantém falhas conhecidas fora de push/integração? | hard_rule | essential |
| CK-17 | A implementação reutiliza os contratos existentes de sessão, cancelamento, política contextual e saída, sem duplicar responsabilidade nem adicionar dependência, provider genérico ou configuração sem necessidade demonstrada? | principle | important |
| CK-18 | Foram evitados logs de áudio/texto pessoal/credencial, persistência incidental de parciais e retenção por tarefas pendentes após cancelamento, com verificação de liberação de buffers e contexto? | hard_rule | pitfall |
| CK-19 | O fluxo respeita branch dedicada, único PR, gates locais por mac-gate e checks realmente aplicáveis ao app nativo, sem inventar npm/Vercel, instalar sobre o app do usuário ou publicar release sem autorização? | hard_rule | essential |

**Regular Checks:**

- [ ] Executar o gate nativo descoberto: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Não existe script separado de lint/typecheck; o compilador e XCTest cobrem o target nativo. Registrar dependências ausentes como bloqueio, sem omitir testes. CK-4–CK-11, CK-14, CK-16–CK-18.
- [ ] Executar `git diff --check` e revisar o diff contra o escopo, incluindo chamadas, fixtures, configuração do target e documentação afetados. Se `project.yml` mudar, regenerar com `xcodegen generate` e repetir o gate nativo. CK-16, CK-17, CK-19.
- [ ] Executar corpus congelado e medição abaixo com candidato local identificado, TextEdit e um campo de navegador descartável; registrar resultado realmente observado no campo, inclusive foco/clipboard e VoiceOver. CK-1–CK-7, CK-12–CK-15.
- [ ] Inspecionar transporte e retenção com doubles locais para comprovar zero envio sem consentimento, cancelamento e descarte. Medição remota real só após autorização explícita de custo na conversa de execução; opt-in do produto não autoriza o agente a gastar. CK-8–CK-11, CK-18.
- [ ] Antes de push/integração, reinspecionar workflows e checks do SHA atual; para o workflow de site apenas se seu escopo mudar: `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`. Acompanhar checks aplicáveis após merge; release, instalação e notarização ficam fora da autorização desta tarefa documental. CK-13, CK-16, CK-19.

Orçamentos de comportamento para CK-3: são metas de aceitação propostas, ainda não medidas. `capture` é o instante monotônico do último frame utilizado por uma hipótese, não o início da frase. `candidate` é a publicação da hipótese reconhecida com ID de sessão/revisão; `decision` é a aceitação ou fallback dessa revisão; `preview` é a atualização visível no Resenha; `commit` é a confirmação de conclusão do mecanismo de inserção única. Registrar separadamente a observação do texto no campo externo: a emissão de Command-V sozinha não comprova inserção física.

| Caminho | Meta p95 | Limite/medição |
|---|---|---|
| capture → candidate | 500 ms | Janela/contexto e tempo de fila entram no intervalo; medir por revisão, inclusive primeira hipótese |
| candidate → decision | 100 ms | Prazo rígido de 200 ms; após isso o original prevalece |
| decision → preview | 50 ms | Sem bloqueio da captura ou foco |
| Último frame até hipótese adaptada visível | 650 ms | Medido diretamente, sem somar percentis de amostras diferentes |
| Soltar atalho → candidate final → decision final → commit | 500 + 100 + 150 ms; total 750 ms | Medir total diretamente, incluindo drenagem/finalização do áudio; apenas uma inserção |

Medir ao menos 100 revisões provisórias e 30 finalizações em três execuções do mesmo corpus, com idioma, duração, hardware, carga e versão do modelo registrados. Relatar p50, p95, máximo, tamanho da amostra, resultados descartados e proporção de fallback. Medir partida fria separadamente; durante carregamento mostrar indisponibilidade sem perder áudio nem prometer adaptação ativa. Comparar modo desligado e ligado no mesmo ambiente. Um pipeline que sempre dá fallback pode atender à espera limitada, mas não atende CK-1/CK-12. Se ASR ou avaliação não cumprir a meta, a função permanece experimental/desligada e a conclusão registra a lacuna; não atribuir ao JEV desempenho não medido.

**Rubric:**

| Criterion | Weight |
|---|---|
| Transcript integrity | 0.25 |
| Bounded responsiveness | 0.25 |
| Privacy and cost control | 0.20 |
| Contextual usefulness | 0.20 |
| Project Guidelines Alignment | 0.10 |

**Rubric Score Definitions:**

### Transcript integrity

Verifica que revisões provisórias e resultados tardios não alteram uma inserção final. Coletar traces de sessão, testes de ordem adversarial e prova no campo externo; considerar CK-2, CK-5–CK-7, CK-14 e CK-15. O padrão existente de saída única e invalidação de tentativa é a referência.

Anchors:

- `score_2`:
  ```text
  Evento: revisão contextual chega após commit. Efeito: texto externo é reescrito.
  ```
- `score_4`:
  ```text
  Evento: revisão contextual chega após commit. Efeito: texto externo permanece igual.
  ```
- `contrast`: efeito de uma revisão tardia sobre o texto já inserido.

### Bounded responsiveness

Verifica a evidência dos tempos de captura, reconhecimento, decisão e inserção, incluindo degradação e fila. Coletar medições reais separadas das simulações, identificar a fronteira de cada estágio e confrontar os resultados com CK-1, CK-3, CK-4 e CK-11. Fallback limitado não substitui adaptação útil.

Anchors:

- `score_2`:
  ```text
  Trace da revisão r12: capture→candidate ausente; candidate→decision 80 ms; decision→preview 30 ms.
  ```
- `score_4`:
  ```text
  Trace da revisão r12: capture→candidate 420 ms; candidate→decision 80 ms; decision→preview 30 ms.
  ```
- `contrast`: presença da medição da captura até o candidato.

### Privacy and cost control

Verifica consentimento, escopo da coleta, limites do contexto e descarte. Coletar registros sem conteúdo pessoal, transporte interceptado e testes de revogação; aplicar CK-8–CK-11 e CK-18. O bloqueio atual de ditado pessoal remoto permanece a referência até existir autorização específica.

Anchors:

- `score_2`:
  ```text
  Modo remoto: desligado. Requisição com transcrição pessoal antes de opt-in: observada.
  ```
- `score_4`:
  ```text
  Modo remoto: desligado. Requisição com transcrição pessoal antes de opt-in: ausente.
  ```
- `contrast`: envio de transcrição pessoal sem opt-in.

### Contextual usefulness

Verifica que acompanhar o sentido melhora a transcrição sem geração especulativa. Coletar pares baseline/ativado do corpus congelado e a origem das alternativas, distinguindo avaliador de reconhecedor e gerador. Aplicar CK-1, CK-5, CK-12 e CK-13; uma hipótese futura ou apenas um benchmark simulado não comprova a capacidade.

Anchors:

- `score_2`:
  ```text
  Mesmo corpus: baseline 10 erros de sentido; ativado 12 erros de sentido; controles sem nova alteração.
  ```
- `score_4`:
  ```text
  Mesmo corpus: baseline 10 erros de sentido; ativado 8 erros de sentido; controles sem nova alteração.
  ```
- `contrast`: contagem de erros de sentido no modo ativado.

### Project Guidelines Alignment

Verifica uso dos gates nativos, reaproveitamento dos contratos, preservação de trabalho alheio e integridade do processo de entrega. Coletar comandos realmente executados, diff e checks do mesmo commit; aplicar CK-16, CK-17 e CK-19. Ausência de gate web para o target nativo não é falha.

Anchors:

- `score_2`:
  ```text
  Gate: xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
  ```
- `score_4`:
  ```text
  Gate: ~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
  ```
- `contrast`: serialização do gate local pelo mac-gate.

**Test Strategy:**

**Criticality:** HIGH: decisões alteram texto do usuário e podem cruzar uma fronteira de privacidade. A estratégia aplica-se à implementação futura; esta etapa documental não executa o produto nem APIs.

| Type | Size | Framework | Dependencies | Gate |
|---|---|---|---|---|
| unit | small | XCTest | Candidatos sintéticos e relógio controlado | Native mac-gate |
| integration | medium | XCTest | Captura/provider/output falsos, transporte interceptado, storage isolado | Native mac-gate |
| property-based | small | XCTest com sequências determinísticas por seed | Relógio e saída falsos; sem dependência nova | Native mac-gate |
| e2e | large | App nativo e evidência do campo real | Apple Silicon, permissões locais, TextEdit e navegador | Candidato local identificado |
| performance | large | Traces monotônicos e corpus real | Áudio local, hardware identificado, saída real | Candidato local identificado |
| smoke | large | App nativo | Modelo local disponível; rede desligada | Mesma execução física de e2e |

**Test Cases to Cover:**

#### CK-1: Avaliação durante fala

- [integration] Fala com três revisões de significado antes de release produz decisões distintas ligadas às respectivas revisões.
- [e2e] Ditado longo mostra adaptação antes de soltar; soltar interrompe captura; idle nunca captura.

#### CK-2: Hipótese provisória

- [integration] Cada revisão altera apenas o estado provisório, com zero chamadas ao sink e histórico.
- [e2e] Rótulo provisório é visível, o destino mantém foco e nenhuma parcial aparece no clipboard/campo.

#### CK-3: Latência observada

- [unit] Limites de 50, 100, 150, 500, 650 e 750 ms são classificados com B−1, B e B+1 ms, sem usar relógio civil.
- [performance] Executar o protocolo de amostras acima, reportando percentis reais por estágio, totais, partida fria, fallback e latência da observação no campo.

#### CK-4: Fail-open

- [unit] Decisão em 199 ms ainda elegível, em 200 e 201 ms descartada; resposta inválida mantém texto original.
- [integration] Timeout, desconexão, erro de provider e cancelamento cooperativo recusado não seguram a finalização nem criam retry.

#### CK-5: Fidelidade e validação

- [unit] Ocorrências repetidas, Unicode, negação, valor monetário, nome próprio, texto vazio, alternativa ausente e instrução maliciosa no conteúdo não produzem substituição livre.
- [integration] Payload inválido, resposta excessiva e proposta com token inventado retornam original sem efeito parcial.

#### CK-6: Inserção única

- [integration] Revisão final diferente da última parcial é reconciliada; sink recebe apenas uma versão final; callback duplicado não reinsere.
- [e2e] Verificar texto final em TextEdit/navegador; mudar clipboard e encerrar app alvo mantém proteções e recuperação existentes.

#### CK-7: Invalidação

- [property-based] Permutar revisões, cancelamento, nova sessão, deadline, exclusão de exemplos e revogação: nunca mais de um commit por sessão nem efeito de revisão inválida.
- [integration] Perda de microfone/Acessibilidade e cancelamento durante captura, decisão ou inserção impedem efeitos pendentes não autorizados.

#### CK-8: Consentimento

- [integration] Instalação limpa e autorização só do diagnóstico sintético enviam zero dados pessoais; opt-in específico permite apenas o payload consentido; revogação cancela pendências.
- [e2e] Controle explica dados/provedor/custo antes da ativação remota; nenhuma conta ou chave é selecionada automaticamente.

#### CK-9: Offline

- [smoke] Iniciar app offline com modelo local existente, ditar e inserir; repetir sem credencial e com provider simulado indisponível.

#### CK-10: Contexto limitado

- [unit] Verificar 599/600/601 caracteres, 29/30/31 segundos e quatro/cinco/seis exemplos; nunca incluir sessão anterior ou histórico.
- [integration] Finalizar e cancelar liberam contexto temporário sem modificar exemplos confirmados.

#### CK-11: Trabalho e payload limitados

- [unit] Limites 4095/4096/4097 bytes UTF-8 respeitam corte seguro e fallback; intervalos 499/500/501 ms respeitam frequência máxima.
- [property-based] Sequência longa de parciais mantém uma avaliação ativa e uma pendente substituível; nenhuma fila cresce com duração.

#### CK-12: Benefício contextual

- [integration] Congelar pelo menos 40 frases PT-BR com referências e dez controles; incluir homófonos, termos técnicos, nomes, pausas, autocorreção falada e mudança de assunto.
- [e2e] Comparar saídas ligadas/desligadas com as referências congeladas e contar correções, regressões e alterações de sentido, sem editar o corpus depois de ver resultados.

#### CK-13: Evidência e limites

- [performance] Relatório separa medições reais e doubles, identifica artefato/modelos/hardware e registra meta não atendida como não atendida.
- [smoke] Quando faltam prova ou configuração autorizada, a interface não apresenta a capacidade contextual remota como ativa/comprovada.

#### CK-14: Modo desligado

- [integration] Reexecutar cenários atuais de idiomas, glossário, histórico opcional, atalho e falhas com contexto desligado; zero transporte remoto.

#### CK-15: Acessibilidade

- [e2e] Navegar controles por teclado/VoiceOver; distinguir provisório/final/local sem cor; revisões não deslocam foco nem inundam anúncios; movimento reduzido respeitado.

#### CK-16: Gate e regressões

- [integration] Suite nativa inclui uma regressão de cada comportamento alterado, passa pelo comando descoberto e identifica eventuais dependências ausentes como bloqueio real.

#### CK-17: Reuso

- [integration] Percorrer produção com doubles dos contratos existentes comprova um único dono de política, sessão e commit, sem caminho paralelo de inserção.

#### CK-18: Retenção e logs

- [integration] Após cancelamento/finalização, probes comprovam liberação de contexto/buffers e descarte de tarefas; logs não contêm transcrição, áudio, exemplos ou chave.

#### CK-19: Entrega

- [smoke] Registrar SHA, resultado do gate nativo e checks aplicáveis do mesmo commit; verificar que o candidato de teste não substituiu a instalação existente.

**Definition of Done:**

- [ ] CK-1–CK-19 têm evidência correspondente; casos adversariais e regressões passam no gate nativo, sem ignorar falhas ou substituí-lo por checks web.
- [ ] Corpus congelado prova benefício sem regressões semânticas nos controles; a origem das alternativas e o papel real de JEV estão documentados.
- [ ] Medição real prova os orçamentos da adaptação contínua e da inserção final; previsão, hipótese parcial e texto comprometido são diferenciados. Falta de viabilidade não é declarada conclusão funcional.
- [ ] Offline, opt-out, consentimento, limites, descarte, acessibilidade e uma única inserção são verificados em candidato identificado; nenhuma API paga foi usada sem autorização explícita da conversa de execução.
- [ ] Branch/PR/checks aplicáveis encerram verdes no commit entregue, documentação corresponde ao comportamento comprovado e quaisquer limites restantes são registrados; release/instalação não ocorrem por autorização implícita do planejamento.

## Research Skill

Use [continuous-context-transcription](../../../.claude/skills/continuous-context-transcription/SKILL.md) before architecture or implementation. It distinguishes local streaming recognition and preview from asynchronous bounded Jev decisions, records current primary-source latency/cost evidence, and defines privacy, revision, compatibility, and validation safeguards. Retain the predecessor contextual-correction skill's conservative eligibility rules; the research does not authorize paid calls or promise millisecond remote inference.

## Architecture Overview

### Solution Strategy

Implement two coupled loops with different guarantees. The **local live loop** owns responsiveness: bounded PCM snapshots are recognized locally, converted into immutable hypothesis revisions and rendered only inside Resenha. The **optional semantic loop** observes meaningful changed revisions, finds alternatives from explicitly confirmed correction examples and asks Jev only to choose between `keep_original` and an allowlisted replacement. The local preview never waits for a network result, and any missing, uncertain, late or invalid decision preserves the local candidate.

This translates “Jev always evaluates the meaning” into continuous session-level observation, not a remote request for every audio frame. A request is admitted only when the current revision contains an eligible ambiguous occurrence, at least 500 ms has elapsed since the previous dispatch, and the privacy, authority, payload and concurrency gates pass. Equal and superseded revisions are coalesced. There is at most one contextual request active and one latest pending snapshot; no FIFO can grow with dictation length.

The completed-WAV path remains the authoritative final fallback while rolling recognition is calibrated. At release, the session stops accepting new work, obtains one final local transcription, reuses only a still-current contextual decision within the hard deadline and freezes one string. The existing `DictationOutputSink` path stages, records and inserts that string once. Partial hypotheses never enter the clipboard, history, feedback learning or another application's field.

The research and source findings that constrain this design are recorded in [continuous-context-transcription](../../../.claude/skills/continuous-context-transcription/SKILL.md) and [analysis-implement-continuous-context-intelligence.md](../../analysis/analysis-implement-continuous-context-intelligence.md). Jev is a typed decision engine, not an audio recognizer or arbitrary next-token generator; its reported provider latency is not an end-to-end product SLA. The proposed budgets in Acceptance Criteria remain release gates to measure, not promises established by this plan.

### Components and Ownership

| Component | Architectural responsibility |
|---|---|
| `AudioRecorder` | Preserve private completed-WAV ownership and the existing meter while adding a bounded, timestamped PCM event seam. The audio callback may copy/convert owned samples and enqueue only; it never performs recognition, UI work or networking. Interruption, device change, cancel and stop close the stream exactly once. |
| `WhisperTranscriber` / `EmbeddedWhisperEngine` | Add rolling-window recognition through the installed whisper framework while retaining the serialized engine owner, native abort callback and final completed-recording path. One inference may run with one replaceable latest pending snapshot; concurrent chunks must not accumulate behind the semaphore. Full-string normalization runs only at the final boundary or inside the explicitly mutable suffix. |
| `ContinuousContextSession` (new) | Own one active push-to-talk session: bounded PCM/text context, immutable revisions, stable-prefix/mutable-suffix state, local and semantic schedulers, cancellation, deadlines and the transition to one committed final string. It is a cohesive owner, not a generic stream/provider framework. |
| `ContextualCorrections` contracts | Reuse the local store, candidate matcher, probability validator, monotonic clock and typed Decisions client. Extend requests/results with revision and snapshot identity, build occurrences from the exact immutable window, and reject stale policy/store/session state. Fix or prove isolation of transport request contexts before repeated personal traffic is possible. |
| `DictationCoordinator` | Create and invalidate the session under the existing attempt UUID, snapshot language/mode/store generation, route provisional values to the HUD and pass exactly one frozen final string into the existing sink. Current focus, clipboard, history, target and recovery guards remain the only external side-effect boundary. |
| `FloatingPanelController` / `FloatingStatusView` | Hold only the active session's transient preview, distinguish provisional/local/final without color alone, coalesce rendering and clear on every terminal path. Do not steal focus or announce every partial revision; respect reduced motion. |
| `WhisperKeyApp` / `ProductPreferences` | Compose one clock and one session pipeline, expose a disabled-by-default local-preview capability and truthful status, invalidate work on lifecycle/preference changes and keep the synthetic diagnostic authorization separate from any future personal-data opt-in. |

`TextInjector`, `TranscriptHistory`, `DictationInteraction`, permission routing and the feedback lifecycle remain final-output invariants. They are review surfaces, not new streaming owners. There is deliberately no mechanism for backspacing or rewriting text in arbitrary editors because the app has no target-range, undo or concurrent-edit ownership contract.

### Session and Revision Contract

Each hypothesis is an immutable value containing at least:

- session/attempt UUID and monotonically increasing revision;
- source sample range and snapshot identity;
- source text, language and provisional/final marker;
- policy generation and correction-store generation;
- monotonic capture, candidate and deadline timestamps.

The session state is `idle -> capturing -> finalizing -> committed`, with terminal `cancelled` and `failed` paths. Preview and semantic tasks are children of that state and cannot outlive it. A result may mutate the preview only when every identity/generation still matches and its source span remains in the mutable suffix. Duplicate, reordered, expired, post-finalization or superseded results are discarded even if transport cancellation failed.

Swift `String.Index` values never cross snapshot boundaries. Candidate spans and occurrence ordinals are recomputed against the exact immutable sentence window being sent and are revalidated against unchanged source text immediately before application. A committed prefix never passes through whole-string glossary or spoken-correction processing again; final reconciliation runs the established postprocessor once over the authoritative final recognition.

The session retains at most the Acceptance Criteria limits: the last 30 seconds/600 characters of current-session context, five pertinent confirmed examples, one active evaluation and one replaceable pending revision. PCM capacity, rolling window, overlap and stability thresholds are injected scheduling values selected by a local benchmark before enablement; source research does not justify hardcoding release values. Overflow drops obsolete provisional work, never final audio ownership.

### Local Recognition and Backpressure

The first implementation extends the current installed Whisper integration instead of adding Apple Speech, a CLI process, another model or a dependency. Rolling inference uses bounded windows over 16 kHz mono samples and the same engine owner. The implementation benchmark starts from the upstream 500 ms observation cadence but varies cadence, window and overlap on supported hardware; it records cold/warm latency, real-time factor, queue depth, churn, CPU, memory and thermal behavior. Chosen values and evidence go into the task's testing document before the capability is presented as active.

The local scheduler follows latest-wins backpressure:

```text
audio callback -> bounded sample buffer -> active local inference
                                      \-> one replaceable pending snapshot

local result -> immutable revision -> immediate Resenha preview
                              \-> eligible contextual scheduler
```

An equal hypothesis produces no new preview or semantic work. A new pending snapshot replaces an older unstarted one. Cancellation reaches both Swift tasks and `WhisperExecutionControl`; a noncooperative child cannot hold finalization past its budget. If rolling recognition is unsupported, too slow or fails, the HUD truthfully reports local fallback and release still uses the completed-WAV flow.

### Contextual Decision Loop

The semantic loop is conservative candidate selection, not prose generation:

```text
hypothesis revision
  -> current-session bounded context
  -> confirmed-example candidate matching
  -> eligibility + consent + cost + rate gates
  -> typed Jev keep/replace questions
  -> exact schema/probability/span validation
  -> current-revision guard
  -> provisional overlay or original
```

Only locally supplied literal replacements are legal. Preserve the existing confidence and selected-probability minimum of 0.90, strict winning probability, bounded occurrences and exact answer-ID validation. Numbers, negations, identifiers, overlaps, conflicting examples, malformed responses and unsupported windows abstain unless the existing deterministic rules explicitly prove the replacement safe. There is no retry, alternate provider, open-ended rewrite or persistent semantic cache.

The current OpenRouter client remains pinned to the reviewed model/route when a personal path is authorized. Chunked HTTP response delivery is not treated as semantic streaming. Before repeated requests, `DecisionsStreamingTransport` must either key callbacks by session plus task identity or enforce and prove a lifetime in which task identifiers cannot alias across URLSession instances. Tests must overlap a cancelled old request with a new request and prove bodies, continuations and cancellation never cross.

### Privacy, Cost and Authority Boundary

Local capture, recognition and preview work offline and are available without a credential. Remote personal evaluation starts disabled. The existing Keychain item and `SyntheticDiagnosticAuthorizationOwner` authorize only the frozen one-shot synthetic diagnostic and cannot be interpreted as standing permission.

A shipped personal Jev mode requires a distinct, revocable authorization owner. Before activation it must disclose the exact text/examples sent, provider, request frequency and cost behavior; require the user's deliberate opt-in and available credential; enforce the 4096-byte payload, 500 ms minimum dispatch interval, one-active/one-pending limits and stop admission on authentication or billing errors. No implementation or test may spend through a paid API without the separate conversation-time approval required by project policy.

Every request is rechecked locally because a later partial can introduce personal data. Audio, clipboard contents, target application content, transcript history, local IDs and unrelated examples are excluded. Context exists only for the active session, is not logged or persisted and is cleared on commit, cancel, failure, opt-out, credential/example deletion or app termination. Ephemeral networking and ZDR constraints reduce client/provider retention but do not constitute a zero-retention claim.

### Finalization, Failure and Rollback

| Event | Required result |
|---|---|
| Local partial arrives | Render promptly if current; semantic work remains optional and non-blocking. |
| Jev is late, offline, invalid, uncertain or unauthorized | Keep the exact local candidate; no blocking retry and no later edit. |
| Newer revision supersedes work | Cancel where possible and discard by identity regardless of callback arrival. |
| Release | Stop admission, produce final local recognition, accept only a current decision before the final deadline, freeze one string and call the existing sink once. |
| Cancel, permission loss, device interruption, mode change or app termination | Invalidate session/revisions, stop capture/inference/transport, clear preview/context and produce no new external effect. |
| Rolling mode misses quality/latency/resource gates | Keep capability experimental/off and preserve the completed-recording behavior; rollback is a preference/configuration disablement, not a data migration. |

There is no schema migration: confirmed contextual examples keep their existing v1 store and remain the only persistent learning. Preview output never creates a glossary rule or example. Feature-off behavior is the current path with zero additional provider calls or cost.

### Verification Architecture

Deterministic XCTest uses the existing clocks, provider/transport doubles, engine controls, sink spies and retention probes. Add an event fixture for partial/final revisions, Unicode windows, overlap, cancellation, delay and expected final spans. Tests cover latest-wins queue bounds, stable/volatile text, stale and duplicated events, exact one commit, cancelled old/new transport isolation, byte/time boundaries, offline/opt-out, memory release and all current final-output regressions.

The frozen PT-BR corpus compares completed-recording baseline, local rolling mode and mocked contextual mode before thresholds are tuned. It must include at least the Acceptance Criteria cases and controls. Mock results prove orchestration only. Physical Apple Silicon runs then measure the full microphone -> preview -> final target path with monotonic traces and identify commit, model, hardware, cold/warm state and sample counts. A separately authorized frozen remote run is the only evidence for actual Jev latency/cost/schema; it still does not prove broad PT-BR quality.

No phase may claim success merely because fallback is fast. If quality, latency, privacy, cost or hardware evidence is missing, the capability remains off and the testing report names the unmet gate. Native source validation runs through the repository's `mac-gate xcodebuild ... test`; site checks apply only if the conditional public/privacy surface changes.

### Architecture Decisions and Trade-offs

| Decision | Reason and trade-off |
|---|---|
| ADR-1 — App-owned live preview, one external commit | Gives continuous feedback without inventing editor-range and undo ownership. It does not provide inline third-party text before release. |
| ADR-2 — Existing Whisper engine first | Avoids a new dependency, deployment-floor increase and silent cloud fallback. Rolling quality/performance must be calibrated; completed-WAV remains fallback. |
| ADR-3 — One cohesive session owner | Centralizes revisions, backpressure, retention and commit guards without duplicating coordinator/output responsibilities. It adds one source file instead of a generic streaming framework. |
| ADR-4 — Candidate-bound Jev decisions | Preserves fidelity and the established contextual-correction validator. It cannot invent the next word or fix an error for which no confirmed alternative exists. |
| ADR-5 — Local path never waits for network | Makes perceived latency and offline behavior deterministic. Semantic improvement may arrive too late and safely abstain. |
| ADR-6 — Personal remote mode separately authorized | Prevents a synthetic diagnostic key/toggle from becoming recurring paid personal transmission. Until consent and cost controls exist, real personal Jev traffic stays closed. |
| ADR-7 — Benchmark-gated window constants | Avoids false precision from upstream examples. It requires a local calibration milestone before live mode can be enabled. |

### Expected Changes

Baseline scope is **14 existing files modified, 3 files created and 0 files deleted**. This is the smallest complete native surface from the codebase analysis; review-only invariants change only if their established contract is proven insufficient.

| Action | Path | Expected change |
|---|---|---|
| Modify | `Sources/WhisperKey/AudioRecorder.swift` | Add bounded PCM/sample-format/session events and terminal cleanup while preserving meter, private WAV and ownership behavior. |
| Modify | `Sources/WhisperKey/WhisperTranscriber.swift` | Add serialized rolling-window inference, immutable result callbacks and final-only normalization without another recognizer. |
| Create | `Sources/WhisperKey/ContinuousContextSession.swift` | Own revisions, bounded buffers/context, latest-wins scheduling, preview validity, finalization and one commit decision. |
| Modify | `Sources/WhisperKey/DictationCoordinator.swift` | Start/invalidate the session, route preview, reconcile the final result and call the existing sink once. |
| Modify | `Sources/WhisperKey/ContextualCorrections.swift` | Bind requests/results to immutable revision windows, preserve bounded validation/authority and isolate repeated transport contexts. |
| Modify | `Sources/WhisperKey/WhisperKeyApp.swift` | Compose the session pipeline and invalidate it across application, permission and preference lifecycle changes. |
| Modify | `Sources/WhisperKey/ProductPreferences.swift` | Add disabled-by-default live-preview/remote status and explicit consent disclosures without repurposing synthetic authorization. |
| Modify | `Sources/WhisperKey/FloatingPanel.swift` | Present and clear session-bound preview without focus, clipboard or feedback leakage. |
| Modify | `Sources/WhisperKey/FloatingStatusView.swift` | Render accessible provisional/local/final state with coalesced updates and reduced-motion behavior. |
| Modify | `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Extend existing doubles/probes with revision, queue, transport-isolation, authority, retention and exactly-once tests. |
| Create | `Tests/Fixtures/continuous-context-events.json` | Store synthetic deterministic partial/final event sequences; never bundle personal capture data. |
| Modify | `project.yml` | Register the new test fixture; source-directory inclusion continues to cover Swift. |
| Modify | `WhisperKey.xcodeproj/project.pbxproj` | Regenerate with XcodeGen after fixture membership changes; do not hand-maintain divergent membership. |
| Modify | `README.md` | Explain live preview versus final insertion and truthful local/optional-network boundaries. |
| Modify | `docs/PRIVACY.md` | Document session-only context, deletion/retention, default-local behavior and remote authorization limits. |
| Modify | `docs/architecture.md` | Record capture -> hypothesis -> contextual decision -> one final output ownership and failure flow. |
| Create | `docs/testing/continuous-context-intelligence.md` | Record corpus, SHA/model/hardware, latency/resource distributions, physical proof, remote authorization/cost evidence and unrun gates. |

Review without modification unless a test proves the contract must change: `TextInjector.swift`, `TranscriptHistory.swift`, `DictationInteraction.swift`, `PermissionService.swift`, `RecordingWaveformView.swift`, `WhisperModelManager.swift`, `HotkeyMonitor.swift`, existing fixtures/specs, scheme, entitlements and privacy manifest. If personal remote transmission is actually shipped, public site/App Store privacy copy, `Config/PrivacyInfo.xcprivacy` and applicable site tests become mandatory conditional changes; planning does not authorize publication or store submission.

## Implementation Process

Esta seção governa a implementação futura; o planejamento não autoriza chamada paga, instalação sobre o app atual, publicação, troca de provider/modelo ou aumento do deployment target. Partir da `main` atualizada em branch/worktree próprios, preservar alterações alheias e manter um único PR desta task. Antes de código de produto, 01 congela e commita corpus, referências, controles e checksum; nenhuma etapa posterior pode alterá-los sem reiniciar formalmente a avaliação.

**Diretiva de execução:** lançar um agente por passo, passando o caminho desta task e o arquivo do passo; usar exatamente seu `Model`/`Agent`, implementar somente aquele escopo e executar passos marcados paralelos em paralelo. Colisões de edição no XCTest monolítico são coordenadas operacionalmente e não criam dependências arquiteturais falsas. Executar o code reviewer **uma única vez por fase**, no `Reviewer model` indicado, depois dos passos/testes da fase. Corrigir achados antes de avançar. Cada fase mantém o app compilável, o completed-WAV utilizável e a capacidade incompleta desligada/fail-open.

Todo passo escreve seus testes. Rede usa doubles, relógio/storage isolados e conteúdo sintético; opt-in do produto não autoriza gasto do agente. Gate nativo: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Mudança em `project.yml` exige `xcodegen generate` e novo gate. A branch condicional de 07 que altera site executa `~/.local/bin/mac-gate node --test Scripts/site.test.mjs`. Não inventar Vercel/native CI inexistente.

O JSON de 01 e os testes de 08 provam somente orquestração semântica determinística. Relógio falso/eventos simulados nunca satisfazem ASR, capture→candidate, cold/warm ou recursos. 09 termina todo source/config/resource/test/documentação-base, roda gates, commita e identifica o tree/binário antes de medir. Esse candidato executa três runs físicos com pelo menos 100 revisões e 30 finalizações. Depois, somente o bloco de resultados de `docs/testing/continuous-context-intelligence.md` pode mudar; qualquer outra alteração repete gate/build/prova.

07 toma uma decisão executável: ou personal remote é autorizado e todos os gates de elegibilidade/provider/custo permitem atualizar fonte, revisar/alterar `Config/PrivacyInfo.xcprivacy`, atualizar `docs/specs/20-privacy-review.md`, `site/privacy/index.html` e seus testes; ou o binário mantém personal remote indisponível/off e prova zero requests. Nenhuma publicação ocorre nesta task sem autorização separada. 09 pode commit/push e abrir/atualizar o único PR, mas **não faz merge**. Só depois do reviewer da Phase 3 aceitar o diff/evidência, o orquestrador integra o PR e acompanha checks pós-merge; qualquer mudança posterior invalida a revisão correspondente.

### Parallelization Overview

```text
Dependência integrada + branch/worktree próprios
                     |
Fase 1 — baseline pré-código + núcleo local
01 Congelar corpus/checksum (sonnet)
                     |
02 Áudio + rolling ASR (opus)
                     |
03 Sessão/revisões (opus)
                     |
             revisão opus
                     |
Fase 2 — dois ramos sobre o contrato de sessão
          +----------+----------+
          |                     |
04 Coordinator/finalização   06 Loop Jev/revisões
          |                     |
05 HUD/controle local           |
          +----------+----------+
                     |
07 Gate ship/closed + privacidade
                     |
             revisão opus
                     |
Fase 3 — orquestração + candidato físico final
08 Corpus semântico determinístico (sonnet)
                     |
09 Prova física/docs/PR sem merge (sonnet)
                     |
             revisão opus
                     |
       integração pós-review pelo orquestrador
```

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
| --- | --- | --- | --- | --- | --- | --- |
| 01 — Congelar contrato do corpus | 1 | sonnet | sonnet | Dependência integrada; branch própria | None | [01-freeze-corpus-contract.md](../../sub-tasks/implement-continuous-context-intelligence/01-freeze-corpus-contract.md) |
| 02 — Áudio limitado e reconhecimento rolling | 1 | opus | opus | 01 | None | [02-bounded-audio-and-rolling-recognition.md](../../sub-tasks/implement-continuous-context-intelligence/02-bounded-audio-and-rolling-recognition.md) |
| 03 — Máquina de estados da sessão contínua | 1 | opus | opus | 02 | None | [03-continuous-session-state-machine.md](../../sub-tasks/implement-continuous-context-intelligence/03-continuous-session-state-machine.md) |
| 04 — Finalização e inserção única | 2 | opus | opus | 03 | 06 | [04-coordinator-finalization-and-one-commit.md](../../sub-tasks/implement-continuous-context-intelligence/04-coordinator-finalization-and-one-commit.md) |
| 05 — Preview e controles locais | 2 | sonnet | sonnet | 04 | 06 | [05-preview-ui-and-local-controls.md](../../sub-tasks/implement-continuous-context-intelligence/05-preview-ui-and-local-controls.md) |
| 06 — Loop Jev vinculado à revisão | 2 | opus | opus | 03 | 04, 05 | [06-revision-bound-jev-loop.md](../../sub-tasks/implement-continuous-context-intelligence/06-revision-bound-jev-loop.md) |
| 07 — Autoridade e privacidade remotas pessoais | 2 | opus | opus | 05, 06 | None | [07-personal-remote-authority-and-privacy.md](../../sub-tasks/implement-continuous-context-intelligence/07-personal-remote-authority-and-privacy.md) |
| 08 — Corpus semântico e gates determinísticos | 3 | sonnet | sonnet | 07 | None | [08-semantic-corpus-and-deterministic-gates.md](../../sub-tasks/implement-continuous-context-intelligence/08-semantic-corpus-and-deterministic-gates.md) |
| 09 — Prova física, docs e PR sem merge | 3 | sonnet | sonnet | 08 | None | [09-physical-proof-docs-and-delivery.md](../../sub-tasks/implement-continuous-context-intelligence/09-physical-proof-docs-and-delivery.md) |

Caminho crítico: **dependência → 01 → 02 → 03 → revisão 1 → 04 → 05 → 07 → revisão 2 → 08 → 09 → revisão 3 → integração**; 06 roda em paralelo com 04/05 e converge em 07. Largura máxima: **2**. O corpus/checksum é um commit pré-implementação. O merge não pertence a 09 nem antecede a revisão final.

### Phase Overview

#### Phase 1 — Baseline congelado e núcleo local cancelável

Steps: 01, 02, 03.

Reviewer model: opus — inclui baseline de aceitação, callback realtime, engine serializado, estado concorrente e retenção de buffers.

Acceptance Criteria that should be fulfiled: antes do produto, corpus/referências/controles/checksum ficam congelados. Depois, o app continua utilizável e possui costura local desativada para áudio/hipóteses e sessão limitada, sem UI/inserção parcial/rede.

Checklist items:
- CK-1, CK-3, CK-4: revisões locais e timestamps/deadlines existem; falha mantém candidato local.
- CK-7, CK-10, CK-11: invalidação, limites e backpressure sem fila crescente.
- CK-12: corpus de 40+10 casos e checksum são congelados antes de 02.
- CK-14, CK-16, CK-17, CK-18: modo desligado, gate, reuso e liberação permanecem íntegros.

Rubrics:
- Transcript integrity.
- Bounded responsiveness.
- Contextual usefulness.
- Project Guidelines Alignment.

#### Phase 2 — Preview, Jev limitado e gate de privacidade

Steps: 04, 05, 06, 07.

Reviewer model: opus — integra sink/UI com decisão/transporte, consentimento, credencial e superfícies públicas condicionais.

Acceptance Criteria that should be fulfiled: preview fica no Resenha e commit externo ocorre uma vez. Jev só escolhe alternativas literais com doubles. 07 implementa uma branch única: ship com manifest/política pública/App Store/site coerentes, ou closed com personal remote indisponível e zero requests.

Checklist items:
- CK-1, CK-2, CK-4, CK-5, CK-6, CK-7: preview, decisão por ocorrência, fidelidade, commit único e invalidação tardia.
- CK-8, CK-9, CK-10, CK-11: consentimento/closed gate, offline, contexto, frequência, bytes e concorrência.
- CK-14, CK-15, CK-16, CK-17, CK-18: regressões, acessibilidade, gate, reuso, descarte/logs e superfícies de privacidade coerentes.

Rubrics:
- Transcript integrity.
- Bounded responsiveness.
- Privacy and cost control.
- Contextual usefulness.
- Project Guidelines Alignment.

#### Phase 3 — Evidência atribuível e PR pronto para revisão

Steps: 08, 09.

Reviewer model: opus — revisão cruza qualidade semântica, privacidade, hardware, performance, publicação condicional e integridade de entrega.

Acceptance Criteria that should be fulfiled: 08 demonstra apenas orquestração contra o JSON imutável. 09 congela o código/tree/binário final antes de três runs físicos (100 revisões/30 finalizações) que demonstram — ou recusam — completed-WAV versus rolling ASR, latência real, recursos, acessibilidade, offline e inserção única. Só um append de evidência tied ao tree ocorre depois; o PR permanece não mergeado.

Checklist items:
- CK-1, CK-2, CK-3, CK-4, CK-5, CK-6, CK-7: fluxo completo, deadlines, fidelidade, commit e eventos tardios no corpus/hardware.
- CK-8, CK-9, CK-10, CK-11: branch ship/closed, consentimento, offline, contexto e limites observados.
- CK-12, CK-13: benefício semântico contra baseline congelado fica separado de prova acústica/física tied ao SHA/tree/modelo/hardware.
- CK-14, CK-15, CK-16, CK-17, CK-18, CK-19: regressões, acessibilidade, gates nativo/site condicionais, retenção e único PR no mesmo SHA.

Rubrics:
- Transcript integrity.
- Bounded responsiveness.
- Privacy and cost control.
- Contextual usefulness.
- Project Guidelines Alignment.
