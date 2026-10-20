---
title: Context-aware corrections with Jev
parent: ../../tasks/in-progress/add-transcription-feedback.feature.md
phase: 5
step: 07
model: opus
agent: developer
depends_on: 06
status: planned
---

# Step 07 — Correções contextuais com Jev

## Objective

Impedir que feedback ambíguo vire substituição global. O caso `rosto → Hostel` deve manter “rosto” em contexto corporal e aplicar “Hostel” apenas quando o contexto indicar hospedagem. Implementar o menor beta reversível: aprendizado local explícito, decisão remota tipada e opt-in, com original preservado em toda falha.

Este passo fica **bloqueado para implementação/ativação remota** até o dono aprovar o recorte de dados e o teto mensal. Não usar a chave publicada na conversa. Revogá-la é ação do dono; a futura chave nova entra apenas pelo app e fica no Keychain.

## Product decision required

Recomendação a aprovar ou rejeitar: enviar ao OpenRouter somente a frase atual limitada a 600 caracteres, o par `ouvido/correto` e o idioma, com teto local de US$ 0,10/mês. Sem aprovação, implementar no máximo storage, interfaces e testes fake/offline; não emitir request real.

Fatos para a implementação: Jev 1.14 oferece escolha estruturada com probabilidades/confidence; endpoint informado `POST /api/alpha/decisions`; preço informado em 20/10/2026 US$ 0,042/M tokens de entrada, output grátis. Antes de codificar o cliente, confirmar na documentação oficial o model ID e o schema atuais. Mudança de preço/schema volta a bloquear ativação; nunca adaptar silenciosamente.

## Contract

### Separation of correction types

- Linhas simples e `heard = canonical` já presentes em `TranscriptionGlossary` continuam locais, determinísticas e compatíveis; não migrar, apagar nem reclassificar.
- Save novo pelo formulário cria `ContextualCorrection` por padrão e não chama `saveTranscriptionCorrection` nem anexa linha ao glossário.
- O registro contém versão, UUID, par validado e um único exemplo rotulado, limitado à frase atual que contém a forma ouvida. Persistir por escrita atômica em `Application Support/Resenha/ContextualCorrections/v1.json`, no máximo 200 registros/20.000 caracteres; não guardar áudio, transcrição inteira, app de destino ou histórico.
- Se a forma ouvida não existir na transcrição efêmera, mostrar erro e não persistir. Duplicata idêntica atualiza no máximo o exemplo confirmado; conflito do mesmo `heard` com outro destino exige resolução explícita, sem overwrite.
- Ajustes mostram que “Vocabulário pessoal” é global e “Correções contextuais” dependem de contexto; permitir apagar uma ou todas as correções e apagar a chave.

### Decision pipeline

1. Whisper e o pós-processamento determinístico atual produzem o texto candidato.
2. Antes de `TextInjector.stage`, histórico ou inserção, detectar correspondências de termo completo para correções contextuais; limitar a três ocorrências por ditado.
3. Para cada ocorrência, fornecer ao resolver apenas idioma, par e frase atual delimitada (máximo 600 caracteres UTF-8). Não fornecer exemplos salvos ao provedor no beta inicial.
4. Aceitar somente payload fechado com escolha `manterOriginal`/`aplicarCorrecao` e confidence finita entre 0 e 1. Aplicar apenas `aplicarCorrecao` com confidence `>= 0,90` e par/ID correspondente.
5. Resolver ocorrências em paralelo sob deadline total de 900 ms, sem retry. Opt-out, chave ausente, offline, orçamento, quarta ocorrência, timeout, cancelamento, tentativa obsoleta, HTTP/429/5xx, schema inválido e confiança baixa mantêm o original.

O resolver não corrige livremente, não gera texto e não faz previsão geral de próxima palavra. Ele escolhe entre dois resultados já conhecidos. A substituição acontece antes da inserção; nunca editar texto já enviado ao aplicativo destino.

### Privacy, credential and cost

- Toggle desligado por padrão com disclosure do request exato e do preço/teto.
- Guardar a chave nova em Keychain usando Security.framework; nunca em UserDefaults, fonte, log, fixture ou documentação.
- `URLSession.ephemeral`, timeout de 900 ms, sem cookies/cache, sem retry. Não adicionar SDK/dependência.
- Contador mensal local conservador usa o tamanho enviado para bloquear antes do request ao atingir o teto aprovado. Não prometer billing exato; exibir uso estimado e data de reset.
- Nenhum log contém frase, par ou chave. Erros exibem somente categoria operacional.
- Desligar o toggle ou apagar a chave restaura imediatamente operação offline. Apagar correções remove apenas o store contextual, nunca o glossário legado.

## Files and impact

| Path | Required change |
| --- | --- |
| `Sources/WhisperKey/WhisperTranscriber.swift` | Reusar matching de termo completo e separar claramente o pós-processamento global da enumeração de candidatos contextuais; não fazer rede dentro do motor Whisper. |
| `Sources/WhisperKey/DictationCoordinator.swift` | Await do resolver entre transcrição e `stage`; guardar resultado somente em variável da tentativa, respeitar cancelamento/attemptID e preservar original em toda falha. Injetar seam pequeno para fake. |
| `Sources/WhisperKey/FloatingPanel.swift` | Manter transcript apenas na sessão efêmera até expiração/Save e encaminhar contexto confirmado ao storage; limpar em cancelamento, timeout, novo ditado e hide. Não alterar WIP visual da Phase 4. |
| `Sources/WhisperKey/ProductPreferences.swift` | Opt-in, teto/uso estimado e integração dos controles de correções; não guardar chave nem payload textual no defaults. |
| `Sources/WhisperKey/WhisperKeyApp.swift` | Compor storage/resolver/Keychain e atualizar callbacks; não criar request no lifecycle de launch/settings. |
| `Sources/WhisperKey/ContextualCorrections.swift` | Um arquivo novo contendo modelo versionado, store local limitado, matcher/resolver fail-closed, cliente Decisions API e adapter Keychain. Manter tipos internos ao módulo; nenhuma arquitetura genérica. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Unit/integration tests de storage, matching, pipeline, Keychain seam, limite/cancelamento/fail-closed e nenhuma mutação pós-inserção. |
| `Tests/Fixtures/contextual-corrections.json` | Corpus sintético rotulado, balanceado, sem texto real do usuário, incluindo `rosto/Hostel`. |
| `project.yml` / `WhisperKey.xcodeproj` | Regenerar somente se o fluxo normal do projeto exigir para incluir o novo arquivo; não mudar entitlements nem dependências. |
| `docs/PRIVACY.md`, `README.md`, `docs/specs/11-output-quality.md`, `docs/specs/08-testing.md` | Divulgar opt-in, dados enviados, provedor, preço/teto, fallback, retenção local e exclusões; remover promessas absolutas incompatíveis apenas quando o beta for habilitado. |

Antes de editar, rastrear todos os callers de `WhisperTranscriber.transcribe`, `TranscriptPostprocessor.process`, `saveTranscriptionCorrection`, `DictationCompletion`, `onTranscript`, `TextInjector.stage`, `offerFeedback` e `ProductPreferences`. Se outro caminho insere texto sem passar pelo coordinator, parar e ampliar os testes antes do código.

## Tests

1. Corpus: mínimo cinco pares ambíguos, cada um com pelo menos quatro exemplos aplicar/quatro manter. Casos obrigatórios: “Meu rosto ficou vermelho” → manter; “Reservei um rosto perto da estação” + decisão confiante → “Reservei um Hostel perto da estação”. O fake lê expected choice; nenhum teste chama rede.
2. Decision validation: choice desconhecida, NaN/infinito, confidence fora de 0...1, ID/par divergente, `0,899` e `0,900`; somente o último threshold válido pode aplicar.
3. Fail-closed: opt-in off, Keychain missing, offline, timeout 900 ms, 401, 429, 500, malformed JSON, budget exhausted, quatro candidatos, cancellation e stale attempt preservam texto byte-for-byte e não repetem request.
4. Persistence/privacy: Save contextual não altera `resenha.transcriptionGlossary`; store relido preserva limites e conflitos; apagar item/tudo funciona; request capturado contém somente campos permitidos e no máximo 600 caracteres; logs/fixtures não contêm segredo.
5. Integration: decisão ocorre antes de `onTranscript`/`stage`; successful apply chega uma vez ao clipboard/histórico/inserção; falha chega original uma vez; Save após inserção não altera o texto anterior.

Rodar somente pelo gate canônico:

```sh
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

Uma chamada real delimitada é teste manual separado, só após aprovação explícita nesta conversa, com chave nova no Keychain. Registrar modelo, request redigido, latência, choice/confidence, tokens/custo observado e apagar o exemplo de teste em seguida. Nunca registrar a chave ou frase pessoal.

## Success criteria

- [ ] CK-12: Save do formulário não cria substituição global; storage contextual é versionado, limitado, relido e apagável.
- [ ] CK-13: somente typed choice válida e confidence `>= 0,90` aplica o destino exato antes da inserção.
- [ ] CK-14: todos os caminhos offline/erro/custo/latência/cancelamento preservam original sem retry.
- [ ] CK-15: opt-in, Keychain e request mínimo são comprovados; documentação deixa claro o que sai do Mac.
- [ ] CK-16: corpus sintético e regressões `rosto/Hostel` passam sem rede; gate canônico verde.
- [ ] Revisão opus da Phase 5 não encontra envio excedente, segredo, mutação retroativa ou bypass do orçamento.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Frase ainda contém dado pessoal | High | Opt-in explícito, recorte de uma frase/600 caracteres, disclosure e decisão bloqueante do dono |
| Modelo aplica correção errada | High | Escolha binária, threshold 0,90, exact matching, corpus contrastivo e original em dúvida |
| Rede degrada ditado | High | Deadline único 900 ms, paralelo, sem retry, original imediato ao expirar |
| Chave vaza | High | Revogar chave exposta; Keychain para chave nova; redaction e testes sem segredo |
| Custo foge do controle | Medium | Teto mensal local aprovado, tamanho/request limitados e bloqueio antes da chamada |
| Regra legada ambígua continua global | Medium | Não migrar silenciosamente; documentar e permitir que o usuário remova manualmente antes de cadastrar versão contextual |
