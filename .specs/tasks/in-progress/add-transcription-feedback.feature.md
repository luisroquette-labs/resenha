---
title: Add local transcription feedback and correction learning
---

## Initial User Prompt

> Uma coisa que senti falta: uma aba de correção para dar nota a uma transcrição de forma rápida. Após a transcrição, mostrar dois balõezinhos, um de like e outro de dislike. Se clicar em dislike, abrir texto para reportar algo como: “Você transcreveu errado o nome ‘COESA Energia’ como ‘Coisa Energia’. Aprenda: é COESA Energia.”

> Escolha confirmada: opção 1 — o dislike abre dois campos, “Saiu como” e “Correto é”, e salva a regra no glossário local.

> Refinamento normativo após teste do piloto: like/dislike não podem ocupar um cartão grande nem permanecer indefinidamente. Devem emergir como detalhes sutis do mesmo HUD de voz ao terminar a transcrição e desaparecer sozinhos após um intervalo curto. A versão instalada deve ser atualizada para tornar o fluxo testável.

### Requirements

- Após uma transcrição concluída, exibir ações rápidas de aprovação e reprovação no HUD.
- Exibir essas ações como dois controles discretos dentro do mesmo HUD de processamento, sem cartão, título ou oferta visual separada, e dispensá-las automaticamente após 4 segundos.
- Aprovação encerra o feedback sem persistir conteúdo adicional.
- Reprovação abre uma correção curta com os campos “Saiu como” e “Correto é”.
- Salvar uma correção confirmada adiciona somente o termo canônico como dica local de vocabulário; nunca cria automaticamente uma substituição global `ouvido = correto`.
- A próxima transcrição pode usar o termo canônico como contexto do Whisper, mas palavras comuns continuam intactas: ensinar “Hostel” a partir de “rosto” não autoriza trocar toda ocorrência de “rosto”.
- Áudio, transcrição e feedback não podem ser enviados a servidores ou APIs externas.
- Não adicionar analytics, login, dependência ou API paga.
- A oferta passiva não pode manter animação contínua quando oculta, bloquear cliques fora dos alvos nem reter mais que token e PID necessários; o editor limita o draft antes de aceitar conteúdo excedente.
- Cancelar ou atingir o limite da transcrição deve interromper `whisper_full`, liberar o engine para a tentativa seguinte e remover o WAV pelo único owner definido.
- A versão instalada para uso cotidiano deve ser um produto Release, sem XCTest, `*.debug.dylib`, `get-task-allow` ou entitlements de `testmanagerd`.

## Description

Permitir que quem dita no Resenha avalie rapidamente o resultado no HUD e ensine uma correção explícita de vocabulário. O benefício é reduzir erros recorrentes de nomes próprios, como “Coisa Energia” → “COESA Energia”, usando o glossário local existente. O aprendizado ocorre somente ao confirmar uma correção válida; clicar em dislike, digitar ou cancelar não ensina nada.

### Scope Included

- Like e dislike compactos após uma transcrição concluída e não vazia, associados ao resultado atual e incorporados à mesma superfície/posição do HUD de processamento.
- Formulário curto com “Saiu como”, “Correto é”, salvar e cancelar; validação e confirmação local clara.
- Termo canônico explícito no glossário existente, preservando as demais entradas, seus limites e a compatibilidade com edição nas preferências, sem persistir a forma ouvida como substituição global.
- Disponibilização do termo canônico ao prompt das transcrições seguintes, persistência entre aberturas e operação acessível por teclado e VoiceOver; decisão contextual futura permanece fora desta task.
- Proteção contra confirmação duplicada, callbacks obsoletos e perda silenciosa de regras; preservação da inserção, clipboard e política opcional de histórico.

### Scope Excluded

- Retreinamento do modelo, aprendizado por like/dislike sem confirmação, interpretação de instruções em texto livre e avaliação automática de qualidade.
- Reescrita retroativa de texto já inserido em outro aplicativo ou de transcrições anteriores.
- Conta, sincronização, servidor, API, analytics, novas dependências e serviços pagos.
- Histórico persistente de notas, áudio, forma ouvida ou conteúdo de feedback separado do glossário.
- Inferência remota ou decisão contextual por JEV/OpenRouter; esta task apenas elimina a substituição global insegura e deixa o termo canônico como vocabulário local.

### User Scenarios

1. Após ditar, a pessoa vê por 4 segundos dois controles discretos no mesmo HUD que acabou de processar a fala, aprova e encerra o feedback sem salvar nota ou conteúdo adicional. Ignorar faz somente a oferta desaparecer e permite continuar ditando normalmente.
2. A pessoa reprova, informa “Coisa Energia” e “COESA Energia”, confirma e recebe indicação de salvamento. “COESA Energia” passa a integrar o vocabulário local após reabrir o app, mas “Coisa Energia” não vira uma substituição global determinística.
3. A pessoa abre a correção e cancela, fecha ou inicia outro ditado: nenhum rascunho vira regra e nenhuma confirmação obsoleta modifica o novo resultado.
4. Um campo vazio, entrada incompatível com o formato ou limite excedido mantém o formulário com orientação acessível; nada é truncado, descartado ou anunciado como salvo. Uma regra idêntica já existente é tratada sem duplicação; uma forma ouvida já mapeada para outro destino exige resolução explícita, nunca substituição silenciosa.
5. Quem usa teclado e VoiceOver consegue abrir, preencher, salvar e cancelar. O HUD não toma o foco durante gravação/inserção; ao abrir a correção o foco vai ao formulário e, ao sair, retorna de maneira previsível.
6. A pessoa informa “rosto” → “Hostel”; o app conserva “rosto” quando essa é a palavra dita em contexto comum e persiste, no máximo, o termo “Hostel” como dica de vocabulário. A forma ouvida e a frase não sobrevivem ao encerramento do editor.

## Acceptance Criteria

**Checklist:**

| ID | Question | Category | Importance |
| --- | --- | --- | --- |
| CK-1 | Um resultado concluído e não vazio substitui o processamento, no mesmo HUD e sem salto de geometria, por like/dislike compactos e acessíveis; gravação, processamento, falha e resultado vazio não apresentam avaliação acionável? | principle | essential |
| CK-2 | Like encerra o feedback sem persistir nota, áudio, transcrição ou conteúdo adicional e sem alterar o glossário? | hard_rule | essential |
| CK-3 | Dislike abre exatamente os campos “Saiu como” e “Correto é”, e somente Salvar com confirmação válida aprende uma regra? | hard_rule | essential |
| CK-4 | Campos vazios após trim, quebras de linha, delimitadores incompatíveis, termos iguais e entradas que excedem os limites efetivos do glossário são rejeitados com orientação, sem gravação parcial ou falso sucesso? | hard_rule | essential |
| CK-5 | Salvar preserva entradas existentes, persiste somente o termo canônico, não duplica dica idêntica e mantém esse vocabulário utilizável após reabrir o app, sem armazenar a forma ouvida? | hard_rule | essential |
| CK-6 | A próxima transcrição recebe “COESA Energia” no prompt local sem criar a substituição global “Coisa Energia = COESA Energia”; em especial, “rosto” continua “rosto” após ensinar “Hostel”? | hard_rule | essential |
| CK-7 | Cancelar, expirar, dispensar e trocar de ditado descartam a oferta/rascunho sem aprendizado, e timers, confirmações ou tokens repetidos/obsoletos não atingem nem ocultam outro resultado? | hard_rule | essential |
| CK-8 | O fluxo completo funciona sem enviar áudio, transcrição ou feedback para rede, sem analytics, login, dependência nova ou API paga, persistindo apenas a regra confirmada além do comportamento já existente? | hard_rule | essential |
| CK-9 | Teclado e VoiceOver operam os controles compactos e os campos por nomes acessíveis, foco e erros perceptíveis; os ícones não dependem só de forma/cor e Reduce Motion remove a transição sem alterar o timeout ou a disponibilidade? | principle | important |
| CK-10 | Ditado posterior, inserção no aplicativo original, clipboard e histórico opcional conservam seu comportamento, com testes pelo mac-gate e evidência física distinguida de fixtures? | hard_rule | essential |
| CK-11 | A oferta passiva expira exatamente após 4 segundos, enquanto dislike/editor cancela esse timeout; um timer antigo nunca fecha editor, notice, gravação ou oferta de uma sessão mais nova? | hard_rule | essential |
| CK-12 | O HUD oculto não mantém relógio/renderização contínua, o prazo usa tempo monotônico e somente os dois alvos `44×44` interceptam mouse; fundo e área vazia deixam o clique chegar ao app subjacente? | hard_rule | essential |
| CK-13 | Oferta/editor retêm somente token, PID e drafts limitados necessários; forma ouvida, app alvo e closures de sessão são liberados em like, expiração, cancelamento, nova tentativa, HUD off e encerramento? | hard_rule | essential |
| CK-14 | Cancelamento e timeout interrompem de fato `whisper_full`, liberam o engine para a próxima tentativa e removem o WAV uma única vez, inclusive durante espera pelo lock e inferência bloqueante? | hard_rule | essential |
| CK-15 | O candidato instalado é Release atribuível ao SHA, sem XCTest, `*.debug.dylib`, `get-task-allow` ou entitlements `testmanagerd`, com assinatura válida, backup recuperável e rollback comprovável? | hard_rule | essential |

**Regular Checks:**

- [X] CK-1–CK-15: executar `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`, conforme README e SPEC-008; preparar framework embarcado e projeto Xcode pelas instruções existentes se ausentes. Não executar `next build` nem inventar script npm para o app nativo.
- [X] CK-4–CK-8: revisar diff e testes de preferências/glossário para limites, preservação de dados, ausência de persistência de rascunho e ausência de chamadas de rede/telemetria introduzidas.
- [ ] CK-1–CK-3, CK-7, CK-9–CK-11: validar app real em TextEdit, incluindo continuidade visual, timeout, teclado, VoiceOver, Reduce Motion, gravação seguinte, clipboard e foco; registrar ambiente, commit, resultado e limitações em evidência de teste, sem conteúdo pessoal.
- [X] CK-10: executar `~/.local/bin/mac-gate node --test Scripts/site.test.mjs` somente se o diff atingir site/scripts cobertos pelo workflow existente. O workflow de site e eventual preview do site não provam comportamento do app nativo.
- [ ] CK-12–CK-15: medir processo oculto, clique pass-through, liberação de probes, cancelamento bloqueante/WAV e validar o bundle Release antes de qualquer substituição de `/Applications/Resenha.app`; teste Debug não satisfaz CK-15.

**Rubric:**

| Criterion | Weight |
| --- | --- |
| Feedback explícito e continuidade do ditado | 0.25 |
| Integridade e aplicação do glossário | 0.30 |
| Privacidade local do aprendizado | 0.20 |
| Acessibilidade da correção | 0.15 |
| Project Guidelines Alignment | 0.10 |

**Rubric Score Definitions:**

### Feedback explícito e continuidade do ditado

Avaliar CK-1–CK-3, CK-7 e CK-11: ações discretas pertencem ao resultado atual; só a confirmação válida aprende; ignorar expira em 4 segundos e cancelar permite continuar.

Anchors:
- score_2:
  ```text
  Dislike → formulário; cancelar → glossário contém a regra digitada.
  ```
- score_4:
  ```text
  Dislike → formulário; cancelar → glossário não contém a regra digitada.
  ```
- contrast: presença da regra cancelada no glossário.

### Integridade e aplicação do glossário

Avaliar CK-4–CK-6, CK-10 e CK-13: o termo canônico é representável, não destrói entradas, não retém a forma ouvida e não cria substituição global determinística.

Anchors:
- score_2:
  ```text
  Correção confirmada: rosto → Hostel. Glossário persistido: “rosto = Hostel”. Próxima saída comum: “Meu Hostel está vermelho.”
  ```
- score_4:
  ```text
  Correção confirmada: rosto → Hostel. Glossário persistido: somente “Hostel”. Próxima saída comum: “Meu rosto está vermelho.”
  ```
- contrast: ausência de mapeamento global da forma ouvida e preservação da palavra comum.

### Privacidade local do aprendizado

Avaliar CK-2, CK-8 e CK-13: somente o termo canônico confirmado é persistido; forma ouvida, frase, rating e alvo são efêmeros e nenhum dado de feedback transita por rede ou alimenta analytics.

Anchors:
- score_2:
  ```text
  Salvar correção → forma ouvida e termo canônico gravados; requisições de feedback observadas: POST /feedback.
  ```
- score_4:
  ```text
  Salvar correção → somente termo canônico local gravado; forma ouvida liberada; requisições de feedback observadas: nenhuma.
  ```
- contrast: emissão de requisição de feedback.

### Acessibilidade da correção

Avaliar CK-1, CK-3 e CK-9: nomes falados, sequência de foco, operações por teclado e indicação acessível de validação acompanham o fluxo visual.

Anchors:
- score_2:
  ```text
  VoiceOver no botão de reprovação anuncia: “botão”.
  ```
- score_4:
  ```text
  VoiceOver no botão de reprovação anuncia: “Corrigir transcrição, botão”.
  ```
- contrast: nome acessível que identifica a ação.

### Project Guidelines Alignment

Avaliar CK-10, CK-12, CK-14, CK-15 e os checks do projeto: gates nativos via mac-gate, lifecycle medido, cancelamento real e prova de bundle Release identificada separadamente de fixtures; não acionar APIs pagas.

Anchors:
- score_2:
  ```text
  Validação: xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
  ```
- score_4:
  ```text
  Validação: ~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
  ```
- contrast: execução do gate pela fila compartilhada mac-gate.

**Test Strategy:**

Criticality: alta para integridade do glossário e privacidade; o risco principal é aprender silenciosamente uma regra incorreta ou persistir dados além da confirmação. Usar testes determinísticos para estado/persistência e app físico para foco, acessibilidade e ditado real. Modelo previamente instalado evita confundir download inicial com rede de feedback.

| Type | Size | Framework | Dependencies | Gate |
| --- | --- | --- | --- | --- |
| unit | small | XCTest | Preferências isoladas e estado/controlador determinístico | mac-gate xcodebuild test canônico dos Regular Checks |
| integration | medium | XCTest | Preferências temporárias, glossário e pós-processamento real; sem rede | mac-gate xcodebuild test canônico dos Regular Checks |
| visual | medium | Fixtures nativas NSHostingView existentes | Estados de feedback, aparências, texto longo e Reduce Motion | mac-gate xcodebuild test canônico e inspeção das fixtures |
| manual | large | App macOS, TextEdit e VoiceOver | Apple Silicon, modelo local e permissões já concedidas | Evidência física identificada por commit |
| review | small | Inspeção de diff e observação de rede | Fluxo offline; fontes e preferências de teste sem dados pessoais | Sem novos destinos de rede, analytics ou dependências |

Test Cases to Cover:

#### CK-1: Ações no resultado correto
- [unit] Concluir transcrição não vazia disponibiliza as duas ações; demais estados não as disponibilizam.
- [visual] Comparar HUD em claro/escuro, contraste aumentado e Reduce Motion; feedback usa exatamente `280×64`, mesma geometria/posição do processamento imediatamente anterior, sem título, cartão vertical ou controles cortados.

#### CK-2: Aprovação sem conteúdo adicional
- [unit] Like encerra a interação; snapshot de preferências/glossário permanece idêntico e não é criado registro de feedback.

#### CK-3: Confirmação explícita
- [unit] Dislike e edição não escrevem; salvar par válido escreve somente a regra confirmada.
- [manual] Abrir os dois campos nomeados, confirmar e observar indicação local compreensível de salvamento.

#### CK-4: Entradas inválidas e limites
- [unit] Rejeitar vazio, apenas espaços, nova linha, delimitador incompatível e termos iguais, preservando o rascunho e exibindo erro.
- [integration] Exercitar fronteiras do limite de linha de 160 caracteres, de 200 termos e de 20.000 caracteres de preferências; regra que seria truncada ou ignorada é recusada integralmente. Cobrir entrada no limite e imediatamente acima.

#### CK-5: Persistência sem perda
- [integration] Salvar e reinstanciar preferências isoladas mantém somente o termo canônico e todas as entradas anteriores; a forma ouvida não aparece no domínio persistido.
- [integration] Salvar termo canônico duplicado não adiciona entrada; falha de validação nunca produz sucesso nem mapeamento `ouvido = correto`.

#### CK-6: Aprendizado aplicado
- [integration] Com “Hostel” salvo como termo, o prompt recarregado o contém, mas pós-processar “Meu rosto está vermelho.” conserva “rosto”.
- [integration] Nenhuma forma ouvida vira substituição; resultado já inserido não é reescrito pelo salvamento.

#### CK-7: Cancelamento e isolamento entre ditados
- [unit] Cancelar, dispensar e iniciar outro ditado descartam rascunho sem mudar preferências; confirmação do resultado anterior não altera o atual.
- [unit] Confirmar repetidamente produz no máximo uma regra efetiva; ações e timers tardios após encerramento são inócuos.

#### CK-8: Privacidade local
- [review] Inspecionar fluxo e observar rede durante like, dislike, cancelar e salvar, com modelo já local: nenhum envio de áudio/transcrição/feedback, analytics, login ou nova dependência.
- [integration] Comparar armazenamento antes/depois: somente a regra confirmada muda no glossário; rascunhos, notas e áudio não ganham persistência nova, inclusive com histórico desativado.

#### CK-9: Teclado e VoiceOver
- [manual] Executar fluxo completo por teclado e VoiceOver, incluindo anúncio dos dois ícones compactos, erro, correção, salvar e Escape/cancelar; verificar rótulos e foco previsível antes da expiração.
- [visual] Verificar que os ícones têm labels/hints acessíveis, contraste suficiente e hit targets nativos; com Reduce Motion a troca processamento → controles é imediata, sem remover os 4 segundos de disponibilidade.

#### CK-10: Continuidade real e gates
- [manual] Ditar no TextEdit, abrir/cancelar correção, ditar novamente e confirmar inserção no destino original, clipboard e opção de histórico; repetir com regra salva e app reaberto.
- [review] Conferir comando e resultado do gate nativo via mac-gate, commit do binário testado e distinção entre fixtures, testes determinísticos e validação física.

#### CK-11: Timeout e geração da oferta
- [unit] Ao oferecer feedback, armar deadline em `now + 4`; antes de 4 segundos a oferta/token/menu permanecem, no limite expiram juntos e nenhuma preferência muda.
- [unit] Dislike invalida o timer antes de abrir o editor; avanço arbitrário do relógio não fecha janela, não limpa draft e não executa callback de oferta.
- [unit] Timer da oferta A não fecha oferta B, gravação, notice nem qualquer estado posterior; novo ditado e HUD off continuam encerrando a sessão atual pelos contratos existentes.
- [manual] Ignorar os ícones faz somente a oferta desaparecer em aproximadamente 4 segundos; acionar dislike dentro da janela mantém o editor aberto até ação explícita.

#### CK-12: Lifecycle e pass-through do HUD
- [unit] Substituir `TimelineView(.animation)` por fases finitas dirigidas por estado; depois de ocultar/expirar não existe publisher, task ou clock visual vivo. Deadline e transições derivam de uptime/relógio monotônico injetável.
- [integration] Clicar fora dos dois alvos `44×44` atravessa o HUD e alcança a janela subjacente; clicar dentro aciona exatamente a ação correspondente.
- [manual] Medir o processo com HUD oculto por janela estável e registrar CPU sem atribuir ruído do sistema ao app; repetir clique no fundo e nos dois alvos.

#### CK-13: Retenção mínima e limites antecipados
- [unit] Probes de sessão/alvo/draft desalocam em like, expiração, cancelamento, nova tentativa, HUD off e término; callbacks SwiftUI capturam somente token/handlers fracos.
- [unit] Digitação/colar além do limite é recusada antes de construir candidato persistível; nenhum draft sem limite fica retido e somente o termo canônico confirmado chega a UserDefaults.

#### CK-14: Cancelamento real do Whisper
- [unit] Engine bloqueante falso observa cancelamento e deadline monotônico, retorna prontamente e permite uma segunda inferência sem esperar a primeira.
- [integration] Callback de aborto do whisper.cpp consulta controle lock-safe; cancelamento enquanto aguarda o engine e durante `whisper_full` converge para `CancellationError`/timeout sem resultado tardio.
- [integration] WAV é removido pelo owner único após leitura ou em qualquer falha/cancelamento; dupla limpeza é idempotente e nenhuma tentativa nova herda arquivo/lock da anterior.

#### CK-15: Release instalado endurecido
- [integration] Validador rejeita fixtures com `*.debug.dylib`, `libXCTest*`, `get-task-allow=true` ou entitlements `testmanagerd`, e aceita somente bundle Release assinado com Hardened Runtime.
- [manual] Build Release parte do SHA congelado; instalador confere hashes antes/depois, preserva backup recuperável, executa rollback em falha injetada e prova PID/caminho do bundle instalado.
- [review] Testes continuam pelo `mac-gate`; build/install Release é etapa separada e nunca reutiliza `build/Build/Products/Debug/Resenha.app` produzido por `xcodebuild test`.

**Definition of Done:**

- [ ] CK-1–CK-15 demonstrados por casos acima; nenhuma forma ouvida vira substituição global, nenhum dado pessoal adicional é persistido/enviado e nenhum trabalho visual oculto permanece ativo.
- [X] Cenário “rosto” → “Hostel” prova persistência somente de “Hostel” e preservação de “rosto” em contexto comum, mantendo entradas anteriores e texto já inserido.
- [X] Cancelamento/timeout preemptivo e ownership único do WAV provados sem bloquear a tentativa seguinte.
- [X] Gates locais aplicáveis verdes via mac-gate após a Phase 5; erros conhecidos corrigidos sem afrouxar checks, dependências ou privacidade.
- [ ] Evidência física datada por commit cobre ditado, foco, teclado e VoiceOver; itens não executados são declarados como pendência, nunca como sucesso.
- [ ] Bundle Release instalado e executado corresponde ao SHA final, passa validação negativa de artefatos/entitlements de teste e possui backup recuperável verificado.
- [X] Spec, testes e documentação de uso/privacidade refletem o fluxo contextual-seguro, lifecycle finito, cancelamento real e instalação Release; revisão do diff confirma ausência de API paga, analytics ou novo serviço.

## Architecture Overview

### Strategy and references

Implementar uma sessão efêmera de feedback depois da conclusão da inserção, separada da atividade do gravador. Reutilizar o HUD, o menu nativo, `ProductPreferences.transcriptionGlossary`, `TranscriptionGlossary` e o pós-processamento existentes. O formulário será uma pequena `NSWindow` normal com conteúdo SwiftUI, criada pelo controlador do HUD somente após ação explícita. Não criar serviço, banco, dependência, framework de testes ou infraestrutura genérica de injeção.

Referências normativas deste plano: [skill de feedback](../../../.claude/skills/resenha-transcription-feedback/SKILL.md), [análise de impacto](../../analysis/analysis-add-transcription-feedback.md), [judge 2a](../../reports/judge-2a-transcription-feedback.md), [judge 2b](../../reports/judge-2b-transcription-feedback.md) e [judge 2c](../../reports/judge-2c-transcription-feedback.md). Os caminhos são relativos à task tanto em `draft/` quanto em `todo/`. A decisão de **rejeitar conflitos**, abaixo, especializa e substitui a recomendação genérica de atualização por Save da skill; não existe substituição silenciosa.

Base inspecionada: `origin/main` em `9e674c3ddeee8f7e05b8289f2e5c20ceba55fbc5`. PR #9 e PR #13 são divergências a reavaliar contra a main atualizada antes da implementação, inclusive origem do binário instalado; não são dependências, nem autorização para integrar suas branches. Preservar o waveform de gravação da base efetiva. Testar um binário desta task não valida automaticamente o app instalado de PR #9.

Para a Phase 4, o PR #13 permanece somente referência de leitura. Portar manualmente apenas a composição SwiftUI do orbe/auréola de `RecordingWaveformView.swift` no commit `758f9b13f272ed64d80981794c80dd15afe1440d`; não integrar a branch nem o PNG do site. O refinamento das bolhas usa somente recursos nativos e preserva os contratos de sessão, timeout e acessibilidade já entregues.

### Phase 5 normative hardening

A Phase 5 substitui quatro premissas históricas desta task. Primeiro, feedback confirmado não grava mais `heard = canonical`: persiste apenas o termo canônico como dica de vocabulário. A sintaxe de substituição continua compatível para regras manuais já existentes em Ajustes, mas deixa de ser output do fluxo de feedback. Segundo, a view não possui relógio contínuo; animações são finitas e o controller usa somente tempo monotônico. Terceiro, cancelar/timeout precisa abortar `whisper_full`, não apenas descartar seu resultado após retorno. Quarto, um app Debug/test host nunca é candidato instalável, mesmo com assinatura profunda válida.

O guardrail term-only não implementa a task separada `add-context-aware-corrections` nem autoriza OpenRouter/JEV. Ele evita o dano global imediatamente, retém somente o termo canônico e deixa decisão por ocorrência para a especificação contextual futura. Nenhum texto abaixo que descreva “próxima saída corrigida” ou “regra `ouvido = correto`” permanece normativo para o feedback depois da Phase 5; esses trechos são evidência histórica das fases 1–4.

### Decisions and tradeoffs

| Decisão | Consequência e limite |
| --- | --- |
| Oferecer feedback somente após `insertStaged` retornar sem erro, com tentativa ainda atual | `onTranscript` continua exclusivo do histórico e não é gatilho de sucesso. Retorno do injetor prova o contrato de envio existente, não que o aplicativo remoto exibiu o texto; essa última prova é física. |
| Mostrar a oferta passiva por **4 segundos** no próprio HUD e então descartá-la | Corrige a permanência indefinida e reduz intrusão. Dislike invalida o timer antes de abrir o editor; o editor não expira. O deadline usa geração + token da sessão, portanto timer antigo não fecha estado novo. VoiceOver recebe nomes/anúncio durante a janela; o menu reflete somente a oferta ainda válida. |
| Manter HUD não ativante; usar janela normal para os dois campos | A apresentação automática preserva foco. A janela tem semântica nativa de teclado/fechamento sem converter toda gravação em painel focalizável. |
| Rejeitar fonte já mapeada para outro destino | Menor fluxo completo: mostrar o destino existente e orientar edição explícita em Ajustes → Transcrição → glossário. Não introduzir diálogo de sobrescrita, migração ou novo editor. |
| Salvar somente uma regra validada no texto existente | Mantém compatibilidade e histórico independente. Substituição continua determinística e sequencial; não promete retreinamento, reconhecimento perfeito ou transformação semântica. |

### Components, contracts and data flow

```text
Whisper local → stage → histórico opcional → insertStaged
  → checar tentativa atual → capturar {id, aplicativo de destino}
  → reset da gravação → callback de conclusão → controles compactos no mesmo HUD + ações no menu
      ├─ aprovar/expirar/dispensar → limpar sessão; nenhuma escrita
      └─ corrigir → janela com dois campos vazios
          → Salvar → validar glossário atual → uma atribuição de preferência
          → reler/parsear valor armazenado → confirmação → fechar/restaurar destino
Próximo hotkeyReleased → closure glossaryText atual → parser → pós-processamento
```

| Componente | Contrato proposto |
| --- | --- |
| `DictationCoordinator` | Callback `onCompleted` com token único e `NSRunningApplication` de destino, sem texto. Capturar contexto antes do reset; emitir depois da limpeza e somente se `showsHUD()` continuar true. Rechecar `attemptID` e cancelamento após o `await insertStaged`; callback antigo não completa tentativa nova. Falha/vazio/cancelamento nunca emitem conclusão. |
| `FloatingPanelController` | Único dono da sessão `none / offered(context) / editing(context, draft, error)`, do controller da janela e da geração de callbacks/timer. `offerFeedback` arma 4 segundos; expiração valida geração, token e estado passivo antes de apagar sessão/menu e esconder somente aquela oferta. Dislike invalida o timer antes de abrir o editor. Toda ação recebe/valida token; ação/timer repetido ou aposentado é inócuo. |
| `FloatingStatusView` e view de correção no mesmo arquivo | Recebem estado e ações; não escrevem preferências. Oferta reutiliza a superfície `280×64` de processamento, sem título/cartão vertical, e mostra somente dois botões discretos de ícone com labels/hints “Transcrição correta” e “Corrigir transcrição”. Formulário continua contendo exatamente “Saiu como”, “Correto é”, Salvar, Cancelar e mensagem de validação. Campos começam vazios; não copiar transcrição inteira. |
| `AppDelegate` + `NativeMenuController` | Conectam conclusão, callbacks de gravação, preferência HUD, menu acessível, fechamento e hotkey. Menu reflete disponibilidade do token atual e usa os mesmos handlers do HUD; não cria sessão/histórico paralelo. |
| `TranscriptionGlossary` + `ProductPreferences` | Helper puro constrói candidato ou retorna erro específico; método de save em `@MainActor` lê preferência atual, valida, atribui uma vez e confere round-trip. Resultado distingue regra adicionada, regra já existente e erro. Reusar constantes e parser; sem mudanças no motor de reconhecimento ou algoritmo de substituição. |

Na Phase 5, o contrato desse último componente passa a produzir um candidato **term-only** para feedback. `TranscriptionGlossary` continua aceitando substituições manuais legadas, mas `ProductPreferences.saveTranscriptionCorrection` não pode serializar a forma ouvida. O contexto da sessão passa a ser value-type mínimo (`token`, PID opcional e drafts limitados); aplicativo alvo é resolvido pelo PID somente ao restaurar foco.

Atividade do coordinator permanece `idle / recording / transcribing / inserting / failed`. Feedback não vira fase de gravação, não mantém `task`/arquivo de áudio vivo e não impede o próximo ditado. A conclusão captura apenas identidade/destino; o `reset()` normal pode continuar escondendo estados anteriores antes de a oferta nova ser mostrada.

### Lifecycle, focus and accessibility

| Evento | Comportamento verificável |
| --- | --- |
| Oferta automática | No mesmo frame/posição `280×64` de transcrição/inserção, trocar o progresso por dois ícones discretos; sem título, painel adicional, `activate`, `makeKey` ou first responder. `orderFrontRegardless` mantém a superfície; apenas a oferta recebe mouse (`ignoresMouseEvents = false`). Like remove oferta sem mudar foco nem persistir nota. Um timer de 4 segundos remove oferta/token/menu se ainda forem os atuais. |
| Entrada sem mouse | Adicionar ao menu do status item as ações “Transcrição correta” e “Corrigir transcrição”, habilitadas somente para a oferta atual. Acesso pelo comando de teclado do macOS para itens de status (`Control-F8`/`Fn-Control-F8`, conforme configuração), setas e Return; VoiceOver usa os itens de status. Sem atalho global novo. Validar o percurso real completo, não somente Tab depois de uma abertura por mouse. |
| Dislike por HUD ou menu | Invalidar o timer da oferta **antes** de ocultar o HUD e abrir uma `NSWindow` titulada/fechável, key-capable. O editor não tem auto-dismiss. Só essa ação explícita ativa Resenha e usa `makeKeyAndOrderFront`. `@FocusState` posiciona “Saiu como”; respeitar navegação por teclado do sistema e sequência campos → Salvar → Cancelar, com Return para salvar e Escape para cancelar. |
| Expiração passiva | Aos 4 segundos, se geração + token + estado `offered` ainda coincidirem, limpar sessão e ações de menu, restaurar pass-through e ocultar o HUD sem ativar app, escrever preferência ou mostrar notice. Expiração não atua em `editing`, em sessão mais nova nem em qualquer status posterior. |
| Save válido, Cancelar, Escape ou botão de fechar | Consumir token e limpar draft antes de fechar; restaurar pass-through. Se Resenha ainda está em primeiro plano e o destino original continua vivo, pedir sua ativação uma vez. Se outro app já ganhou foco, preservá-lo. Nunca reabrir app terminado, inserir texto ao fechar ou insistir num destino indisponível. Falha de restauração informa “Volte ao campo de texto para ditar” sem reivindicar foco restaurado. |
| Novo ditado com oferta ignorada | Pressão aceita no app externo aposenta oferta/token, cancela o timer de 4 segundos, restaura modo passivo e inicia normalmente na mesma pressão. Um timer antigo não esconde o novo HUD. Isso cobre explicitamente o cenário de ignorar ambos os controles antes da expiração. |
| Hotkey com editor focado | A primeira pressão fecha/cancela o draft e solicita retorno ao destino, sem iniciar gravação. Consumir a pressão até release; orientar “Solte e pressione novamente para ditar”. A próxima pressão só inicia se o app em primeiro plano já for externo e os guards normais permitirem. Não gravar enquanto se espera ativação e não redirecionar inserção ao editor. |
| Hotkey após usuário alternar do editor para outro app | A pressão aceita descarta o editor sem forçar retorno ao antigo destino e grava no app externo atual. A limpeza não deve alterar o destino capturado por essa nova gravação. |
| Ocultar HUD, cancelamento global, encerramento ou nova apresentação incompatível | Invalidar token e callbacks; fechar janela, apagar draft, cancelar timers e remover ações do menu. Preferência desligada não deixa um feedback invisível acionável. No encerramento não ativar outros apps. |

O caminho real de `configureHotkeyRouting()` hoje chama `handleHotkeyPress(targetIsSelf: false)`. Remover esse bypass no caminho de produção e calcular o alvo real, preservando o guard de `DictationInteraction`; interceptar somente o caso de editor ativo descrito acima antes da tentativa normal. Reutilizar a marca de pressão/release para não disparar gravação com repetição da mesma tecla. Não alterar o guard para permitir inserção em Resenha e não exigir mudanças em `DictationInteraction.swift`.

Callbacks de status/permissões que normalmente são permitidos em `idle` não podem sobrescrever uma sessão de correção: a apresentação rotineira de “pronto” deve respeitar a sessão ativa; perda de permissão/invalidação explícita encerra feedback e mostra o erro adequado. Validar também `applicationDidBecomeActive`, que pode iniciar atualização de permissões ao abrir a janela.

Usar `.accessibilityElement(children: .contain)` ou hierarquia equivalente somente nas superfícies interativas; preservar o resumo acessível dos estados passivos. Os botões compactos podem ser apenas ícones visualmente, mas têm labels/hints completos e anúncio único de disponibilidade; campos têm rótulo, erro tem texto visível associado ao campo e anúncio acessível na tentativa inválida. Restaurar foco ao campo inválido, sem fechar nem apagar draft. Sucesso é texto “Regra salva” ou “Regra já existente”, também anunciado antes do fechamento, seguido de status passivo temporário; invalidar seu timer ao próximo estado. Preservar contraste, transparência reduzida, fonte/estilo da casa e clamping da tela. Com Reduce Motion, a troca processamento → oferta é instantânea e o timer continua em 4 segundos; sem Reduce Motion, admitir apenas transição curta de opacidade/escala dentro do mesmo frame, sem prolongar o deadline. Validação física deve confirmar que o anúncio chega ao VoiceOver; renderizar uma fixture não demonstra isso.

### Persistence, limits and conflicts

Save executa sincronamente no MainActor a partir do **glossário atual**, nunca de snapshot feito ao abrir a janela. Assim uma edição em Ajustes durante o draft não é sobrescrita. O helper não normaliza nem reordena linhas existentes; adiciona no máximo um separador de linha e a linha nova, preservando bytes do conteúdo anterior.

| Entrada/condição | Resultado |
| --- | --- |
| Trim deixa campo vazio; fonte e destino idênticos após trim | Erro inline sem escrita. Igualdade aqui é exata: correção apenas de maiúsculas/minúsculas pode ser útil e é permitida. |
| Quebra de linha em qualquer campo, ou `=` em qualquer campo | Rejeitar com orientação curta. Embora o parser atual permita `=` no destino, este formulário escolhe a gramática menor e explícita; o editor de Ajustes continua compatível com entradas antigas. |
| Fonte equivalente pela comparação case-insensitive do motor, mesmo destino exato | Idempotente somente se a regra completa já for efetiva no parser e não houver outro destino conflitante para essa fonte. Não gravar nem duplicar; confirmar “Regra já existente”. |
| Mesma fonte case-insensitive, destino diferente; ou duplicatas antigas conflitantes | Rejeitar, mostrar a regra existente e orientar edição em Ajustes. Inspecionar também linhas existentes fora da janela efetiva de 200 entradas para não acrescentar ambiguidade escondida. Preservar integralmente as entradas originais. |
| Linha serializada acima de 160 caracteres; candidato acima de 20.000; nova regra fora das primeiras 200 entradas aceitas antes da deduplicação | Rejeitar integralmente antes do setter. Contar pela mesma semântica Swift/parser existente, não pelo número final de termos únicos. Não truncar, remover termos, reorganizar linhas nem expandir limites. Regra idêntica efetiva continua sendo no-op mesmo se não houver espaço adicional. |
| Prompt prospectivo ultrapassa 8.000 caracteres | Recusar a nova regra com orientação para reduzir o glossário, usando a representação de prompt completa antes do `prefix` existente. Isso evita anunciar vocabulário aprendido que foi silenciosamente cortado. Não mudar o limite nem o comportamento legado do parser. |

Validar o candidato com o parser real antes da atribuição: a substituição exata precisa estar presente e todas as substituições previamente efetivas permanecem. Depois da única atribuição, conferir a string relida pelo armazenamento injetado e o parser antes de anunciar sucesso; incoerência é erro, preserva o draft e não gera confirmação. Como a operação é síncrona e os limites já foram conferidos, tal incoerência é uma quebra de contrato a cobrir por teste, não um caminho esperado a mascarar.

Não introduzir `synchronize()`, prometer flush imediato ou tratar UserDefaults como storage criptografado. Reconstrução de `ProductPreferences(defaults:)` prova leitura persistida pelo mecanismo de preferências; reinício físico do app é evidência separada. Manter chave `resenha.transcriptionGlossary`, edição em Ajustes e closure atualizada na próxima liberação do hotkey. Escaping de regex/template, Unicode, termos completos, prioridade por fonte mais longa e substituições sequenciais continuam inalterados; testes com `$`, barra invertida, pontuação, acentos e regras em cascata delimitam esse contrato.

### Failure handling and privacy

Falha de reconhecimento, texto vazio, falha de inserção, clipboard alterado ou fallback mantêm o comportamento/diagnóstico existente e não apresentam avaliação de sucesso. Salvar uma regra não altera texto já inserido, clipboard, histórico ou áudio. A nova sessão não guarda transcrição completa; apenas o draft digitado existe em memória até confirmação/fechamento. Só o par confirmado entra nas preferências. Histórico opcional continua sob sua configuração atual, inclusive seu callback anterior à inserção.

Não emitir rede, telemetria ou logs contendo draft, frases, ratings ou transcrição. O download inicial de modelo existente deve ser distinguido de qualquer envio de dados: preparar modelo local antes da observação offline. Falta de ferramenta, permissão física ou binário atribuível ao commit é impedimento de verificação, nunca evidência de funcionamento.

### Tests and evidence

| Cobertura | Evidência mínima e CK |
| --- | --- |
| Estado e integração do app | XCTest para conclusão apenas depois de inserção sem erro, tentativa obsoleta após await, like/cancel/expiração sem escrita, deadline 4s, dislike cancelando timer, geração+token impedindo timer antigo de fechar sessão nova/editor/notice/gravação, oferta ignorada → próxima gravação, draft → hotkey consumido → release → próxima pressão externa, guarda self preservada, desativação HUD e ações antigas do menu. Exercitar handlers/seam de estado existente ou pequeno helper no mesmo arquivo, sem mockar todo o pipeline de áudio. CK-1–CK-3, CK-7, CK-10–CK-11. |
| Glossário e preferências | Suites UserDefaults únicas; fronteiras 160/161, 200/201 entradas aceitas, 20.000/20.001 e prompt 8.000/8.001; duplicatas antes/depois da capacidade, conflitos case-insensitive, formato inválido, conteúdo antigo preservado, leitura atualizada no Save, reconstrução e “Coisa Energia” → “COESA Energia” via pós-processador real. Invalid/no-op não escrevem. CK-4–CK-6, CK-8. |
| Fixtures | Substituir a oferta alta pelo estado compacto `280×64` nas aparências existentes. Provar continuidade geométrica com transcribing/inserting, dois ícones com hit targets/rótulos acessíveis, contraste/transparência e Reduce Motion sem salto ou corte. Editor mantém dimensão própria. Inspecionar imagens temporárias em `ResenhaTests/ui-fixtures`. CK-1, CK-9, CK-11. |
| Mac físico | Binário/commit identificados; TextEdit e navegador com texto descartável; continuidade processamento → dois ícones no mesmo HUD, expiração aproximada de 4s, dislike antes do deadline mantendo editor, fluxo sem mouse desde menu de status, VoiceOver/erro/sucesso, foco e destino terminado. Repetir com Reduce Motion, oferta ignorada, editor aberto + hotkey, troca para outro app, histórico/HUD desligados e regra depois de reabrir app. Microfone/inserção e rede observada são evidência distinta de XCTest/fixtures. CK-1–CK-11. |
| Gates e registro | Rodar gate nativo canônico dos Regular Checks via `mac-gate`, registrar SHA, comando, resultado e pendências em `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Workflow do site só se afetado; sem npm artificial, `next build`, API paga ou alegação de Vercel como deploy do app nativo. |

### Expected Changes

**Implementação prevista: 12 arquivos existentes modificados, 0 arquivos de produto criados, 0 removidos.** O menu acessível acrescenta `NativeMenuController.swift` aos 11 caminhos estimados pela análise. Os artefatos SDD desta etapa são separados dessa contagem.

| Caminho | Alteração exata prevista |
| --- | --- |
| `Sources/WhisperKey/DictationCoordinator.swift` | Guard pós-inserção, captura de contexto e callback terminal após reset; aposentar feedback ao iniciar/cancelar e proteger rotina de estado. |
| `Sources/WhisperKey/WhisperKeyApp.swift` | Conectar conclusão/save/menu, disponibilidade do HUD e permissões; rota de hotkey com alvo real, editor aberto e release; encerramento seguro. |
| `Sources/WhisperKey/FloatingPanel.swift` | Sessão/token/draft, timeout de 4 segundos protegido por geração+token, modos mouse passivo/interativo, janela nativa da correção, fechamento/restauração do destino e invalidação de timers/callbacks. |
| `Sources/WhisperKey/FloatingStatusView.swift` | Estado de oferta com dois ícones discretos dentro do frame `280×64` do processamento, view de correção/validação e acessibilidade; sem cartão/título grande nem regressão dos estados passivos. |
| `Sources/WhisperKey/NativeMenuController.swift` | Dois itens acessíveis de feedback, disponibilidade por sessão e ações compartilhadas com HUD. |
| `Sources/WhisperKey/ProductPreferences.swift` | Save validado contra valor atual, uma atribuição e verificação de leitura, sem nova chave nem mudança do editor existente. |
| `Sources/WhisperKey/WhisperTranscriber.swift` | Helper de candidato/validação junto ao glossário reutilizando semântica e limites; nenhuma mudança de inference ou pós-processamento. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Regressões de estado, roteamento, persistência/limites/conflitos e extensão delimitada das fixtures. |
| `docs/specs/06-floating-ui.md` | Documentar continuidade no mesmo HUD, oferta compacta de 4 segundos, janela/menu/foco e Reduce Motion. |
| `docs/specs/11-output-quality.md` | Aprendizado explícito local, limites/conflitos e ausência de retreinamento. |
| `docs/specs/08-testing.md` | Casos determinísticos e roteiro físico completo, incluindo geometria, timeout/stale timer, Reduce Motion, VoiceOver, ignorar oferta e keyboard entry. |
| `docs/testing/UI-REFINEMENT-EVIDENCE.md` | Resultados reais com commit/build, aparelho, compactação/timeout, foco/VoiceOver, persistência e pendências explícitas. |

Dependências somente de leitura: `DictationInteraction.swift`, `TextInjector.swift`, `TranscriptHistory.swift`, `PanelPlacement.swift`, `ResenhaDesign.swift`, `RecordingWaveformView.swift`, `HotkeyMonitor.swift`, `project.yml`, projeto/scheme Xcode, README e workflow de site. Sem arquivo Swift novo, não há registro novo no projeto Xcode, export, entitlement, configuração de provider, migração, asset de site ou dependência a alterar.

**Addendum Phase 5:** a contagem histórica acima descreve as fases 1–4. A Phase 5 pode modificar `DictationCoordinator.swift`, `FloatingPanel.swift`, `FloatingStatusView.swift`, `ProductPreferences.swift`, `WhisperTranscriber.swift`, `NativeMenuController.swift`, `Tests/WhisperKeyTests/WhisperKeyTests.swift`, `Scripts/build-release-dmg.sh`, `Scripts/validate-release-dmg.sh`, `docs/specs/06-floating-ui.md`, `docs/specs/08-testing.md`, `docs/specs/11-output-quality.md` e `docs/testing/UI-REFINEMENT-EVIDENCE.md`; pode criar somente `Scripts/install-local-release.sh` e um teste shell de release com nome definido pelo passo 10. Não alterar provider, rede, entitlements produtivos, dependências, site ou assets. Os passos 07/09 possuem arquivos de produto exclusivos e apenas regiões XCTest separadas; 08 roda depois deles por compartilhar editor/glossário; 10 possui scripts/docs e depende do código congelado.

## Implementation Process

Lançar **um agente por passo**, passando o caminho atual desta task e o caminho do respectivo sub-task; usar exatamente o `Model` e o `Agent` indicados e implementar somente aquele passo. Lançar passos paralelos simultaneamente, com propriedade de arquivos/regiões descrita nos sub-tasks; não iniciar gate enquanto houver escrita concorrente. Ao concluir os passos de cada fase, executar **uma revisão de código por fase**, no `Reviewer model` da fase, usando diff, testes e evidências reais. Corrigir achados antes de avançar. A revisão não substitui o gate nativo nem prova física. Os caminhos de task nos sub-tasks devem acompanhar sua movimentação draft → todo → in-progress; o diretório de sub-tasks permanece fixo.

**Resolução normativa de P3 do judge 3 e J4-1:** a atribuição única descreve o caminho normal de Save. Se a escrita ou sua verificação falhar, restaurar a preferência ao valor anterior e o armazenamento à representação anterior, inclusive ausência original da chave; essa restauração excepcional é a única segunda atribuição permitida. Revalidar a restauração, retornar erro e preservar campos, token e janela para correção; nunca anunciar sucesso nem consumir a sessão. Teste deve provocar uma leitura divergente depois da escrita e confirmar rollback tanto na instância quanto em preferências reconstruídas. Se o próprio armazenamento recusar a restauração, manter o valor anterior em memória, preservar draft e comunicar falha de recuperação; **Save permanece desabilitado enquanto o estado persistido estiver sem verificação**, inclusive ao reabrir o editor. O método de Save também rejeita chamadas diretas nesse estado. Cancelar/Escape/fechar permanecem disponíveis e fecham sem mutação; somente neste erro de recuperação, conservar o par em memória no mesmo controller para uma tentativa posterior do mesmo resultado, aposentando o token ativo. Reabrir pela ação existente “Corrigir transcrição” inicia uma recarga/reconciliação explícita do armazenamento real, sem nova gravação e sem restaurar automaticamente snapshot antigo. Reabilitar Save somente após carregar e verificar uma baseline persistida consistente com a leitura real e o parser, atualizar a preferência em memória sem disparar o setter de persistência e emitir novo token; se a recarga falhar, manter Save bloqueado, mensagem e draft. A baseline verificada pode refletir a escrita anterior que não foi possível reverter; o próximo Save a valida novamente e exige confirmação explícita, podendo resultar em regra já existente. Cancelar não significa descartar esse draft excepcional; novo ditado, HUD desligado ou encerramento o invalidam e apagam, sem persistência extra ou reutilização em outro resultado. Testar bloqueio, cancelamento sem escrita, recarga falha e bem-sucedida, retomada e rejeição do token aposentado. Este contrato especializa apenas a falha de rollback e complementa a pós-condição incompleta da arquitetura, sem alterar o caminho normal de Save/cancelamento.

### Parallelization Overview

```text
Phase 1 — fundamentos locais; app atual continua executável
    [01 glossary/save + testes]   [02 views + fixtures]
                \                 /
                 +---- review opus ----+
                                      |
Phase 2 — feature integrada e prova do candidato
                [03 lifecycle/menu/hotkey + testes]
                                      |
                [04 specs + testes físicos + evidência]
                                      |
                              review opus
                                      |
Phase 3 — refinamento do feedback observado pelo usuário
                [05 HUD compacto + timeout + regressões]
                                      |
                              review opus
                                      |
Phase 4 — auréola restaurada e feedback com profundidade
                [06 orbe + bolhas 3D + regressões]
                                      |
                              review opus
                                      |
Phase 5 — hardening P0 de lifecycle, privacidade, cancelamento e instalação
       [07 HUD lifecycle/pass-through]   [09 cancelamento Whisper/WAV]
                         \               /
                    [08 aprendizado term-only]
                              |
                    [10 Release + instalação]
                              |
                         review opus
```

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
| --- | --- | --- | --- | --- | --- | --- |
| `01-safe-glossary-save` [DONE] | Phase 1 | opus | developer | None | `02-feedback-views` | [.specs/sub-tasks/add-transcription-feedback/01-safe-glossary-save.md](../../sub-tasks/add-transcription-feedback/01-safe-glossary-save.md) |
| `02-feedback-views` [DONE] | Phase 1 | sonnet | developer | None | `01-safe-glossary-save` | [.specs/sub-tasks/add-transcription-feedback/02-feedback-views.md](../../sub-tasks/add-transcription-feedback/02-feedback-views.md) |
| `03-native-feedback-lifecycle` [DONE] | Phase 2 | opus | developer | `01-safe-glossary-save`, `02-feedback-views` | None | [.specs/sub-tasks/add-transcription-feedback/03-native-feedback-lifecycle.md](../../sub-tasks/add-transcription-feedback/03-native-feedback-lifecycle.md) |
| `04-physical-evidence-and-specs` [DONE] | Phase 2 | sonnet | developer | `03-native-feedback-lifecycle` | None | [.specs/sub-tasks/add-transcription-feedback/04-physical-evidence-and-specs.md](../../sub-tasks/add-transcription-feedback/04-physical-evidence-and-specs.md) |
| `05-compact-timed-feedback` [DONE] | Phase 3 | opus | developer | `04-physical-evidence-and-specs` | None | [.specs/sub-tasks/add-transcription-feedback/05-compact-timed-feedback.md](../../sub-tasks/add-transcription-feedback/05-compact-timed-feedback.md) |
| `06-animated-halo-feedback-bubbles` | Phase 4 | opus | developer | `05-compact-timed-feedback` | None | [.specs/sub-tasks/add-transcription-feedback/06-animated-halo-feedback-bubbles.md](../../sub-tasks/add-transcription-feedback/06-animated-halo-feedback-bubbles.md) |
| `07-hud-lifecycle-performance-hardening` | Phase 5 | opus | developer | `06-animated-halo-feedback-bubbles` | `09-preemptive-whisper-cancellation` | [.specs/sub-tasks/add-transcription-feedback/07-hud-lifecycle-performance-hardening.md](../../sub-tasks/add-transcription-feedback/07-hud-lifecycle-performance-hardening.md) |
| `09-preemptive-whisper-cancellation` | Phase 5 | opus | developer | `06-animated-halo-feedback-bubbles` | `07-hud-lifecycle-performance-hardening` | [.specs/sub-tasks/add-transcription-feedback/09-preemptive-whisper-cancellation.md](../../sub-tasks/add-transcription-feedback/09-preemptive-whisper-cancellation.md) |
| `08-safe-feedback-learning-and-privacy` | Phase 5 | opus | developer | `07-hud-lifecycle-performance-hardening`, `09-preemptive-whisper-cancellation` | None | [.specs/sub-tasks/add-transcription-feedback/08-safe-feedback-learning-and-privacy.md](../../sub-tasks/add-transcription-feedback/08-safe-feedback-learning-and-privacy.md) |
| `10-release-candidate-install-hardening` | Phase 5 | opus | developer | `07-hud-lifecycle-performance-hardening`, `08-safe-feedback-learning-and-privacy`, `09-preemptive-whisper-cancellation` | None | [.specs/sub-tasks/add-transcription-feedback/10-release-candidate-install-hardening.md](../../sub-tasks/add-transcription-feedback/10-release-candidate-install-hardening.md) |

Largura máxima real: **2**; os caminhos críticos anteriores convergem em **06 → (07 ∥ 09) → 08 → 10**. 07 e 09 possuem produção disjunta (`FloatingPanel`/`FloatingStatusView` versus `DictationCoordinator`/engine Whisper) e regiões XCTest ancoradas separadamente; devem ser lançados simultaneamente e não executar gate enquanto houver escrita concorrente. 08 espera ambos porque reconcilia contexto mínimo, editor, preferências e a região de glossário do mesmo arquivo de transcriber. 10 espera todo o código, executa o único gate estabilizado da fase e trabalha em scripts/docs/artefatos Release. Todos usam opus devido a concorrência C/Swift, retenção, privacidade e instalação recuperável.

### Phase Overview

#### Phase 1 — Save verificável e superfícies renderizáveis [REVIEWED]

Steps: `01-safe-glossary-save`, `02-feedback-views`.

Reviewer model: opus — o passo 01 exige integridade de dados; teto da escala. O passo 02 é sonnet, mas não reduz o tier da revisão.

Acceptance Criteria that should be fulfiled: app existente continua compilável/executável com o comportamento atual; API local de Save e views novas são exercitáveis por XCTest/fixtures sem ativar feedback incompleto na produção. Gate nativo dos Regular Checks verde após ambas as escritas. Ainda não declarar oferta automática, foco real, VoiceOver real ou captura de microfone demonstrados.

Checklist items:
- CK-4: validação completa, limites, rollback excepcional e bloqueio de Save até recarga de baseline persistida verificada, sem perda de draft no contrato de retorno.
- CK-5: preservação, duplicata/conflito e reconstrução de preferências isoladas.
- CK-6: próxima saída corrigida pelo pós-processador real, sem alteração retroativa.
- CK-8: helper/views não introduzem rede, chave, histórico ou dependência; recorte de privacidade desta fase.
- CK-9, CK-10: hierarquia/layout por fixtures e gate nativo desta fase; foco/VoiceOver e continuidade física ficam devidos na fase 2.

Rubrics:
- Integridade e aplicação do glossário.
- Privacidade local do aprendizado — fontes e persistência dos fundamentos, sem alegar observação física final.
- Acessibilidade da correção — layout/hierarquia renderizada, sem alegar entrega ao VoiceOver.
- Project Guidelines Alignment — gate serializado e evidência identificada.

#### Phase 2 — Feedback utilizável e evidência final [REVIEWED]

Steps: `03-native-feedback-lifecycle`, `04-physical-evidence-and-specs`.

Reviewer model: opus — 03 altera contrato compartilhado entre coordinator, panel, app e menu; teto da escala.

Acceptance Criteria that should be fulfiled: app oferece avaliação apenas após conclusão elegível, salva correção explícita local, permite novo ditado e mantém foco/clipboard/histórico. Candidato atribuível ao commit passa gate e roteiro físico; specs/evidências registram resultados reais. Pendência de permissão ou hardware impede afirmar CK correspondente concluído; registrar o impedimento concreto. Não substituir prova física por fixtures.

Checklist items:
- CK-1, CK-2: oferta correta, like sem escrita e menus disponíveis apenas para token atual.
- CK-3, CK-4, CK-5: campos/Save explícitos, erro preserva draft, rollback real e preferências após reabrir; falha de rollback permite Cancelar sem escrita e retomar draft somente após recarga verificada.
- CK-6, CK-7: próxima transcrição corrigida, cancelamentos, obsolescência, pressão/release e timers isolados.
- CK-8, CK-9: rede observada com modelo local, operação sem mouse, VoiceOver, rótulos, erro/sucesso e foco real.
- CK-10: TextEdit/navegador, clipboard, histórico/HUD desativados, gates e proveniência do candidato.

Rubrics:
- Feedback explícito e continuidade do ditado.
- Integridade e aplicação do glossário.
- Privacidade local do aprendizado.
- Acessibilidade da correção.
- Project Guidelines Alignment.

#### Phase 3 — Oferta compacta, temporizada e instalada [REVIEWED]

Steps: `05-compact-timed-feedback`.

Reviewer model: opus — o diff visual é pequeno, mas a expiração compartilha estado e geração com notices, gravação, editor, menu e tokens; teto da escala para impedir regressão assíncrona silenciosa.

Acceptance Criteria that should be fulfiled: o candidato substitui o cartão grande e indefinido por dois ícones discretos dentro do mesmo frame `280×64` de processamento, expira somente a oferta passiva após 4 segundos e preserva editor, novo ditado e estados posteriores contra timer obsoleto. Gate nativo, fixtures e prova física usam o mesmo SHA; a versão instalada deve ser atualizada somente depois da validação e identificada por commit/build.

Este contrato da Phase 3 substitui explicitamente a decisão anterior “sem timeout próprio” e o Expected Output histórico do Step 03 que a reproduz; o editor continua sem timeout, mas a oferta passiva não.

Checklist items:
- CK-1: continuidade geométrica e visual processamento → feedback, sem painel/título grande.
- CK-7, CK-11: timeout determinístico, cancelamento ao abrir editor, geração+token e lifecycle de novo ditado/HUD off.
- CK-9: labels/hints dos ícones, hit targets, contraste, VoiceOver e Reduce Motion sem alterar deadline.
- CK-10: gate via mac-gate, candidato instalado atribuível ao SHA, TextEdit/clipboard/foco e app reaberto.
- CK-2, CK-3, CK-8: like/expiração não escrevem; dislike mantém editor local existente; nenhuma rede, dependência, inference ou glossário novo.

Rubrics:
- Feedback explícito e continuidade do ditado.
- Privacidade local do aprendizado.
- Acessibilidade da correção.
- Project Guidelines Alignment.

#### Phase 4 — Auréola restaurada e bolhas ascendentes

Steps: `06-animated-halo-feedback-bubbles`.

Reviewer model: opus — o diff visual deve permanecer pequeno, mas precisa reconciliar o PR #13 divergente, animações SwiftUI, identidade de apresentação, timeout e targets acessíveis sem criar um segundo lifecycle.

Revisão técnica: **4.66/5**. Implementação e gates automatizados aprovados; a fase continua em andamento porque a validação física é parcial e não integra este score.

Evidência física confirmada em 2026-10-20: em um documento vazio do TextEdit, a pessoa pressionou Option direita, ditou e confirmou que a auréola animou e que os dois emojis subiram e desapareceram. Não houve confirmação de clique, editor, foco, VoiceOver, teclado alternativo, Reduce Motion, Increase Contrast ou clipboard.

Acceptance Criteria that should be fulfiled: o listening recupera o orbe/auréola reativo do piloto dentro do frame `340×72`; a oferta continua no mesmo HUD `280×64`, mas seus dois controles parecem pequenas bolhas 3D que emergem, sobem e desaparecem gradualmente durante a janela de 4 segundos. Reduce Motion remove deslocamento/stagger e conserva fade simples. O editor e todos os guards de geração+token permanecem iguais. Gate, fixtures, revisão e instalação usam o mesmo candidato; observações físicas não executadas continuam declaradas como pendência.

Checklist items:
- CK-1: orbe no listening e bolhas no feedback sem salto de janela, cartão, título visível ou novo painel.
- CK-7, CK-11: animação sem timer/dismiss paralelo; deadline 4s, editor persistente e callbacks antigos inócuos.
- CK-9: target `44×44`, labels/hints/teclado/VoiceOver, light/dark, contraste, transparência e Reduce Motion.
- CK-10: gate via mac-gate, fixtures inspecionadas e binário instalado atribuível ao SHA final.
- CK-2, CK-3, CK-8: like/dislike/editor e privacidade continuam inalterados; sem asset, dependência, API ou telemetria.

Rubrics:
- Feedback explícito e continuidade do ditado.
- Privacidade local do aprendizado.
- Acessibilidade da correção.
- Project Guidelines Alignment.

#### Phase 5 — Hardening P0 de lifecycle, privacidade, cancelamento e Release

Steps: `07-hud-lifecycle-performance-hardening`, `09-preemptive-whisper-cancellation`, `08-safe-feedback-learning-and-privacy`, `10-release-candidate-install-hardening`.

Reviewer model: opus — a fase cruza AppKit/SwiftUI, cancelamento C/Swift, integridade de preferências e instalação recuperável. A revisão ocorre uma única vez depois dos quatro passos e recebe os artefatos reportados por todos eles.

Acceptance Criteria that should be fulfiled: o HUD não consome CPU oculto nem bloqueia cliques fora das ações; deadline/animação usam lifecycle monotônico e contexto mínimo. Feedback persiste somente termo canônico, com draft bounded e prova negativa `rosto → Hostel`. Cancelamento/timeout abortam o Whisper e liberam WAV/engine. O único candidato instalado é Release validado, atribuível ao SHA e recuperável. Testes XCTest rodam pelo `mac-gate`; build/install Release e prova física são etapas posteriores distintas. Nenhuma chamada paga, rede de feedback, push, merge, notarização ou publicação pertence à fase.

Checklist items:
- CK-12: animação finita, zero clock visual oculto, monotonicidade e pass-through apenas nos dois targets.
- CK-13: contexto/token/PID/drafts mínimos, early bounds e liberação comprovada em todos os terminais.
- CK-5, CK-6, CK-8: persistência term-only; forma ouvida ausente de storage/rede/log; `rosto` preservado e “Hostel” apenas no prompt.
- CK-14: aborto preemptivo durante lock/inferência, timeout real, tentativa seguinte livre e ownership único do WAV.
- CK-15: Release sem XCTest/debug/test entitlements, assinatura/hashes/PID verificáveis, backup e rollback recuperáveis.
- CK-1–CK-4, CK-7, CK-9–CK-11: ausência de regressão no feedback, editor, acessibilidade, expiração, foco, clipboard, history e próximo ditado.

Rubrics:
- Feedback explícito e continuidade do ditado.
- Integridade e aplicação do glossário.
- Privacidade local do aprendizado.
- Acessibilidade da correção.
- Project Guidelines Alignment.

O Checklist desta task contém CK-1–CK-15 e nenhum ID HR; não inventar HR. Esta seção distribui os critérios existentes, sem criar IDs adicionais na implementação.
