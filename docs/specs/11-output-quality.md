# SPEC-011 — Qualidade de transcrição e idiomas

## Status

Em implementação no M2. O corpus e o benchmark reproduzível são o gate de qualquer mudança de modelo ou parâmetro.

## Problema

O fluxo físico do M0 funciona, mas o primeiro teste real expôs uma falha lexical: “Resenha” foi inserido como “resenho”. Português com nomes próprios, termos técnicos e anglicismos também precisa permanecer fiel ao que foi falado, sem reescrita semântica disfarçada de transcrição.

## Objetivo

Melhorar a fidelidade do ditado local em PT-BR, inclusive quando a frase mistura palavras inglesas, mantendo latência mensurável, privacidade local e texto previsível.

## Modos do produto

1. **PT-BR:** padrão; idioma-base português, preservando anglicismos e nomes fornecidos pelo usuário.
2. **EN:** transcrição em inglês.
3. **ES:** transcrição em espanhol.
4. **Detectar idioma:** opt-in futuro; útil para uma fala inteira em outro idioma, não para corrigir termos isolados.
5. **Traduzir para inglês:** futuro; o whisper.cpp oferece esse destino localmente, sempre como ação explícita.
6. **Traduzir para português:** fora deste marco; exige outro modelo local ou um provedor aprovado. Não será rotulado como capacidade do Whisper.

Transcrição e tradução nunca compartilham um controle ambíguo.

## Requisitos funcionais

- O idioma padrão é `PT-BR`, configurável para `EN` ou `ES` sem editar arquivos.
- O menu da barra expõe `Idioma` com seleção única e estado atual visível; a mesma preferência aparece no painel Transcrição.
- Alterar o idioma afeta o próximo ditado, sem reiniciar o app e sem interromper uma gravação ativa.
- Um glossário local pode orientar nomes próprios, marcas e termos frequentes por prompt inicial.
- O usuário consegue adicionar, editar e remover termos pessoais sem enviar conteúdo à rede.
- O texto final preserva palavras inglesas reconhecidas; não traduz nem aportuguesa automaticamente.
- Correções determinísticas só podem alterar correspondências explícitas do glossário e pontuação segura.
- O glossário aceita uma entrada por linha em `forma ouvida = forma final`; uma linha sem `=` orienta o prompt e normaliza a grafia exata do termo no resultado.
- O comando explícito `Não, corrige. <novo trecho>.` substitui somente o complemento iniciado pelo último `para` ou `pra` da frase anterior; fora desse formato, o texto permanece literal.
- O marcador aceita pontuação natural entre as palavras, incluindo `Não. Corrige.` e `Não, corrige.`.
- Repetições de hesitação no marcador, como `Não, não, corrija.`, são aceitas. Quando a correção começa por `às`, o `para/pra` anterior é removido para evitar `pra às`.
- Áudio vazio, ruído e marcadores não verbais continuam sem inserção.

## Contrato do motor

O adaptador do whisper.cpp deve receber uma configuração imutável por execução:

```text
language: pt | en | es | auto
initialPrompt: String?
decodingProfile: fast | balanced | accurate
translateToEnglish: Bool
```

Perfis mapeiam apenas opções já suportadas pelo `whisper-cli` 1.9.2: modelo, beam/best-of e prompt. GPU e flash attention continuam ativos por padrão. Toda alteração de parâmetro deve ser comparada com o baseline atual `ggml-small-q5_1.bin`. O primeiro candidato é `ggml-large-v3-turbo-q5_0.bin`; ele só se torna padrão se vencer no mesmo corpus sem latência incompatível com o fluxo interativo.

O prompt inicial é um auxílio probabilístico, não uma garantia. Termos e correspondências explícitas do glossário são aplicados depois da transcrição com limites de palavra, preservação da grafia canônica configurada e teste de regressão. A normalização nunca altera substrings dentro de outra palavra.

## Corpus de avaliação

O corpus versionado começa pequeno e auditável, com áudio real anonimizado ou fixtures gravadas especificamente para teste:

- PT-BR cotidiano, números e pontuação.
- Marca e nomes próprios: Resenha, Willow, COESA, Éric.
- Anglicismos de produto: feedback, meeting, deadline, deploy, commit, prompt.
- Frases com code-switch: “Faz o deploy e manda o feedback no Slack.”
- Frases-base em inglês e espanhol para validar os três idiomas selecionáveis.
- Silêncio, ruído e fala curta para evitar alucinação.

Cada caso contém identificador, referência esperada, termos críticos, duração e origem consentida. Áudio pessoal não entra no Git.

O corpus inicial inclui também os cinco testes físicos observados em 2 de outubro de 2026: termos de desenvolvimento, entidades pessoais, data/moeda, correção falada e PT-BR com anglicismos. Como o áudio original foi apagado pela política de privacidade, fixtures sintéticas geradas pelo `say` servem apenas para comparação reproduzível; o aceite final continua exigindo voz real.

### Teste físico 2 — 2 de outubro de 2026

Saída observada: `Étri,Ô, Éric, avisa ao Luís que a Coisa atualizou o README do Resenha, rodou o benchmark do whisper.cpp e marcou a entrega pra terça-feira às 15h.Não. Corrige. Quarta-feira, às 16h30.`

- Passou: `README`, `Resenha`, `benchmark`, `whisper.cpp`, dia e horários.
- Falhou: alias contextual de `COESA`, espaço após sentença e variante `Não. Corrige.`.
- Hesitação inicial permanece literal por segurança; remoção agressiva de falsos começos continua fora do marco.

### Teste físico 3 — 2 de outubro de 2026

Saída observada: `Éric, avisa ao Luís que a COESA atualizou o README da Resenha, rodou o benchmark do whisper.cpp e marcou entrega pra quarta-feira às 16h30. Não, não, corrija. Às 17h00.`

- Passou: entidades, termos técnicos, data e hora.
- Falhou: repetição `Não, não` no marcador e concordância da substituição iniciada por `Às`.
- Resultado esperado: `Éric, avisa ao Luís que a COESA atualizou o README da Resenha, rodou o benchmark do whisper.cpp e marcou entrega às 17h00.`

### Teste físico 4 — 2 de outubro de 2026

Saída observada: `Eriq, a Viva Luís que a COESA atualizou o README da Resenha, rodou o benchmark do whisper.cp e marcou a entrega às 17 horas.`

- Passou: `COESA`, `README`, `Resenha` e conteúdo semântico do horário.
- Falhou: nome `Éric`, expressão `avisa ao Luís` e extensão `.cpp`.
- O glossário pessoal corrige os dois primeiros; variantes reais `whisper.cp` e `whisper.ctp` passam a aliases técnicos padrão.
- Horas inteiras após `às` são normalizadas para `h00`.

## Métricas e gates

- **WER PT-BR:** não pode piorar em relação ao baseline no mesmo corpus.
- **Acurácia de termos críticos:** alvo inicial de 95%, comparando caixa, acentos e pontuação literalmente; OQ-001 exige `Resenha` exato.
- **Alucinação em silêncio:** zero inserções.
- **Latência:** registrar P50/P95 por perfil; o perfil padrão só muda se a melhoria justificar o custo no Apple M5.
- **Regressão funcional:** hotkey, captura, HUD e inserção continuam passando no mesmo gate físico.

Nenhuma afirmação de “melhor” é aceita sem resultados lado a lado no mesmo áudio e hardware.

### Evidência local — Apple M5, 2 de outubro de 2026

| Configuração | WER | Termos críticos | P50 | P95 |
|---|---:|---:|---:|---:|
| `small-q5_1`, sem prompt | 17,1% | 12/25 | 0,60 s | 0,67 s |
| `large-v3-turbo-q5_0`, sem prompt | 4,8% | 16/25 | 1,13 s | 1,29 s |
| `large-v3-turbo-q5_0`, prompt padrão | 1,0% | 21/25 bruto; 25/25 após glossário pessoal | 1,23 s | 1,41 s |

O candidato com prompt reduziu o WER em 94% relativo. A contagem anterior de 96% ignorava caixa e acentos e foi invalidada nesta rodada; o runner agora exige correspondência literal. O pós-processamento do glossário pessoal fecha deterministicamente as quatro diferenças restantes (`Resenha`, `Éric`, `Luís`, `COESA`) em teste de regressão. O P95 permanece abaixo da meta inicial de 3 s. Resultado sintético; não substitui o gate físico com voz real.

## Privacidade

- Inferência, glossário, corpus de desenvolvimento e pós-processamento permanecem locais.
- O app não grava áudio; texto continua limitado ao buffer local de 10 itens definido na SPEC-012.
- Arquivos temporários são apagados após cada execução, inclusive em falha.
- Cancelar ou encerrar um ditado termina também o subprocesso `whisper-cli`; nenhum processo órfão pode continuar consumindo CPU.
- API paga, telemetria e upload continuam proibidos sem decisão explícita posterior.

## Falhas e recuperação

- Modelo ausente ou incompatível: explicar o caminho e não inserir texto parcial.
- Idioma automático incorreto: manter seleção manual `pt` disponível.
- Termo ambíguo no glossário: não substituir por substring nem dentro de outra palavra.
- Modelo mais preciso porém lento: manter o perfil anterior como padrão até o gate de latência passar.
- Saída extensa do `whisper-cli`: drenar para arquivo temporário, evitando bloqueio por pipe cheio, e apagar o diagnóstico ao concluir.
- Tradução solicitada sem mecanismo compatível: bloquear com mensagem clara; nunca simular tradução via substituições.

## Aceite

1. OQ-001 insere “Testando o Resenha no meu Mac.” exatamente.
2. O corpus registra baseline e candidato com WER, termos críticos e latência.
3. Uma frase PT-BR com pelo menos dois anglicismos mantém esses termos corretamente.
4. Trocar PT-BR → EN → ES no menu altera `-l pt|en|es` no ditado seguinte e persiste após reabrir.
5. Glossário local corrige um nome explícito sem alterar palavras vizinhas; nenhum teste faz rede, usa Python no app ou chama API paga.
6. `Não, corrige. Quarta-feira às 16h30.` transforma `Marque a apresentação para terça-feira às 15 horas.` sem reescrever frases que não sigam esse comando.

## Não objetivos

Reescrita por IA, remoção agressiva de hesitações, mudança de tom, resumo, contexto de tela, aprendizado automático do usuário, tradução geral para português, backend e sincronização.
