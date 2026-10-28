# Resenha — Product Hunt e campanha social

Status: campanha social agendada; lançamento do Product Hunt preparado para 03/11/2026.

## Execução verificada em 28/10/2026

- `@thedoomguy_ai`: 17 posts distintos, às 10:15.
- `@luisroquette`: 17 posts distintos, às 18:20.
- LinkedIn de Luis Fernando Roquette: 17 posts distintos, às 08:40; filme de lançamento às 11:40.
- Cadência: 29/10 a 04/11 diariamente; 05, 07, 09 e 11/11; 13 e 17/11; 19, 21, 23 e 25/11.
- Filme: 03/11 no X das duas contas e no LinkedIn.

## Product Hunt

- Nome: `Resenha`
- Tagline: `Local voice typing with contextual AI, free`
- URL: `https://luisroquette-labs.github.io/resenha/`
- Preço: `Free`
- Categorias: `AI Dictation Apps`, `Note and writing apps`, `Writing assistants`
- Thumbnail: `AppStore/brand/app-icon/resenha-app-icon-1024.png`
- Galeria: `AppStore/screenshots/pt-BR/01-fale-solte-continue.png`, `AppStore/screenshots/pt-BR/03-atalho-global.png`, `AppStore/screenshots/pt-BR/06-privacidade-local.png`
- Filme principal: `site/assets/product/resenha-launch-16x9.mp4`
- Corte vertical para X: `site/assets/product/resenha-launch-9x16.mp4`
- Social card: `site/assets/product/resenha-social-card.png`

### Descrição curta

Resenha turns a global shortcut into private voice typing on macOS. Whisper runs locally; optional JEV reviews text context with your own OpenRouter key. No account, subscription, or audio upload.

### Primeiro comentário do maker

I built Resenha because voice typing felt like a choice between recurring fees and losing control of my audio.

The core loop is deliberately simple: hold a global shortcut, speak, release, and keep writing in the app already in focus. Whisper runs locally on the Mac. Audio never leaves the computer.

The optional JEV layer solves a different problem: transcription can be acoustically plausible and still be wrong in context. JEV reviews text only, using the user's own OpenRouter key, and may suggest a contextual correction. If it times out, is uncertain, or fails, Resenha keeps the original transcript.

The project is free and open source. I would especially value feedback on Portuguese transcription, mixed-language terms, latency, and the BYOK setup.

Repository: https://github.com/luisroquette-labs/resenha

## Calendário editorial

`T` é 03/11/2026, dia do Product Hunt. Horários em America/Sao_Paulo.

Prioridade de distribuição: X primeiro; Product Hunt concentra o pico de lançamento; LinkedIn recebe as peças técnicas de maior permanência.

| Período | Datas | Canal | Horário | Frequência |
|---|---|---|---:|---|
| Semana 1 | 29/10–04/11 | X `@thedoomguy_ai` | 10:15 | diária |
| Semana 1 | 29/10–04/11 | X `@luisroquette` | 18:20 | diária |
| Semana 1 | 29/10–04/11 | LinkedIn | 08:40 | diária; 03/11 às 11:40 |
| Semana 2 | 05, 07, 09 e 11/11 | três canais | horários acima | dia sim, dia não |
| Semana 3 | 13 e 17/11 | três canais | horários acima | 2 publicações |
| Semana 4 | 19, 21, 23 e 25/11 | três canais | horários acima | 4 publicações |

## Posts para X

### X1 — lista editorial, T-3

10 repositórios para entender o estado da voz local em 2026:

1. Resenha — ditado local no Mac com revisão contextual opcional. É o projeto em que estou trabalhando; está em primeiro porque transforma toda a pilha abaixo num produto utilizável.
2. openai/whisper — a base moderna de reconhecimento de fala.
3. ggml-org/whisper.cpp — Whisper eficiente em C/C++ e dispositivos locais.
4. SYSTRAN/faster-whisper — inferência acelerada com CTranslate2.
5. chidiwilliams/buzz — transcrição e tradução offline no desktop.
6. alphacep/vosk-api — reconhecimento offline para várias plataformas.
7. OHF-Voice/piper1-gpl — síntese de voz rápida e local.
8. snakers4/silero-vad — detecção de atividade de voz.
9. dscripka/openWakeWord — detecção local de palavra de ativação.
10. coqui-ai/TTS — toolkit de text-to-speech.

Links: https://github.com/luisroquette-labs/resenha

### X2 — demonstração, T-1

Segurar Option + Espaço, falar e soltar. O texto entra no campo que já estava ativo.

O Whisper roda no Mac. O áudio não sai dele. A revisão contextual por JEV é opcional e usa a chave do próprio usuário.

https://luisroquette-labs.github.io/resenha/

### X3 — lançamento, T

O Resenha está disponível: ditado local para macOS, gratuito e open source.

Sem conta, assinatura ou envio de áudio. Para quem quiser, o JEV revisa o contexto usando BYOK e preserva o original quando estiver em dúvida.

https://luisroquette-labs.github.io/resenha/

### X4 — arquitetura, T+2

“Rosto” e “hostel” podem soar próximos. Trocar sempre uma palavra pela outra seria uma correção burra.

No Resenha, o JEV avalia cada ocorrência pelo contexto. Timeout, erro ou baixa confiança mantêm a transcrição original.

Código: https://github.com/luisroquette-labs/resenha

## Posts para LinkedIn

### LinkedIn 1 — arquitetura, T-2

Um ditado por voz pode acertar todos os sons e ainda errar a frase.

Foi esse problema que me levou a trabalhar no Resenha, um projeto gratuito e open source para macOS. A transcrição acontece localmente com Whisper. O áudio nunca sai do computador.

A camada opcional de contexto usa JEV: ela recebe somente o texto, avalia a frase inteira e decide se deve manter ou corrigir cada ocorrência. Não existe substituição global automática. Se houver dúvida, timeout ou falha, o texto original vence.

É uma tentativa de aproximar o ditado da sensação de um bom teclado preditivo, sem transformar a privacidade em assinatura mensal.

https://github.com/luisroquette-labs/resenha

### LinkedIn 2 — lançamento, T

Coloquei no ar um projeto no qual venho trabalhando: Resenha.

Ele transforma um atalho global em ditado por voz no macOS. Você segura, fala, solta e continua escrevendo no aplicativo que já estava usando.

- Whisper local
- áudio permanece no Mac
- gratuito e open source
- JEV contextual opcional com BYOK
- falha segura: dúvida mantém o original

O objetivo não é esconder a tecnologia. É fazer a tecnologia desaparecer durante a escrita.

https://luisroquette-labs.github.io/resenha/

### LinkedIn 3 — privacidade, T+4

“IA local” não deveria ser apenas uma frase na página de vendas.

No Resenha, o áudio é processado localmente. A revisão contextual é separada e opcional: quando ativada, somente o texto transcrito vai ao OpenRouter, usando a chave do próprio usuário.

Isso cria uma divisão clara:

1. voz e transcrição permanecem no Mac;
2. contexto externo só existe se o usuário ativar;
3. custo e credencial pertencem ao usuário;
4. falhas nunca bloqueiam o texto original.

Arquitetura e código estão públicos:
https://github.com/luisroquette-labs/resenha

## Gate antes do agendamento

1. DMG da versão anunciada notarizado e público.
2. Link do site baixando o mesmo artefato e hash.
3. Instalação limpa e ditado físico aprovados no binário público.
4. Product Hunt preenchido e revisado antes do clique final.
5. Posts agendados somente depois de existir a URL pública do lançamento.
