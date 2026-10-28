# Resenha 1.2.0 — prontidão de distribuição

Verificado em 28 de outubro de 2026. Este documento separa versão do código,
publicação direta e submissões às lojas.

## Escopo da versão

- macOS: Whisper local, feedback de transcrição e JEV contextual opcional com
  chave pessoal OpenRouter, incluindo avaliação durante a fala e revisão final.
- Windows: a implementação JEV está no repositório, mas a versão pública da
  Microsoft Store permanece 0.1.0 até existir pacote assinado e prova física do
  candidato exato.
- Privacidade: áudio sempre local; somente texto e alternativas elegíveis podem
  seguir ao JEV após consentimento explícito.

## Estado por canal

| Canal | Estado 1.2.0 | Próxima prova obrigatória |
| --- | --- | --- |
| GitHub / DMG macOS | Código pronto para release | DMG notarizado, hash publicado e download verificado |
| Mac App Store | Não submetida | edição sandboxada atualizada, certificados e revisão Apple |
| Microsoft Store | Código Windows não publicado | pacote assinado, testes Windows 10/11 e certificação |

## Evidência técnica disponível

- Gate macOS: 242 testes, zero falhas.
- JEV físico: cinco avaliações durante a fala e uma revisão final aplicada.
- Latência observada do JEV via OpenRouter: 336–559 ms durante a fala e 385 ms
  na revisão final; a meta de 200 ms não foi atingida.
- Falha, timeout ou confiança insuficiente preservam a transcrição local.

Este arquivo não prova submissão, certificação nem publicação em loja.
