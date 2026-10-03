# SPEC-012 — Feedback e recuperação do ditado

## Status

Aceita pelo dono em 02/10/2026. Implementar antes de retomar a SPEC-011.

## Problema

Um ditado sem confirmação sonora deixa dúvida sobre o início e o fim da captura. Uma mudança de foco, campo incompatível ou falha de inserção pode fazer o usuário acreditar que perdeu uma fala longa.

## Objetivo

Dar confirmação imediata e garantir que toda transcrição concluída possa ser recuperada, mesmo quando a inserção falhar.

## Fluxo

1. A gravação inicia com sucesso: tocar um som curto de início e mostrar `Ouvindo`.
2. A hotkey é solta e o WAV é fechado: tocar um som curto de fim e mostrar `Transcrevendo`.
3. Na abertura, após permissões e hotkey estarem realmente prontas, tocar uma única confirmação distinta com o significado `FALE AGORA`.
3. O Whisper devolve texto: gravar texto no clipboard e no histórico local antes da inserção.
4. A inserção funciona: concluir sem roubar foco adicional.
5. A transcrição ou inserção falha: mostrar erro recuperável; se havia texto, mantê-lo no clipboard e histórico.

## Sons

- Sons usam API nativa do macOS, sem serviço externo.
- Início e fim são distintos, discretos e duram menos de 400 ms.
- O som só toca depois da operação correspondente funcionar; permissão negada não produz falso início.
- Um ajuste `Sons de funcionamento` permite silenciar abertura, início e fim.
- O som de abertura não se repete ao ativar a janela, abrir o menu ou atualizar permissões; só toca uma vez por processo, quando o app fica pronto.
- A abertura usa dois tons ascendentes exclusivos do Resenha, sintetizados localmente, e não um alerta do macOS.
- VoiceOver e HUD continuam suficientes sem áudio; som não é o único indicador de estado.

## Clipboard e destino

- O aplicativo de destino é capturado quando a gravação começa e não muda durante a sessão.
- A transcrição concluída substitui o clipboard e permanece nele após a tentativa de inserção.
- O app não restaura automaticamente o clipboard anterior.
- Se o destino original terminou ou rejeitou a inserção, o erro diz `Texto salvo no clipboard`.
- Texto vazio nunca entra no clipboard nem no histórico.

## Histórico local

- Armazena no máximo 10 transcrições não vazias, da mais recente para a mais antiga.
- Persiste localmente entre aberturas; nunca armazena áudio.
- Duplicata consecutiva atualiza o item mais recente em vez de criar outra linha.
- O menu `Textos recentes` exibe prévias truncadas; selecionar um item o copia inteiro.
- O menu oferece `Limpar textos recentes…` com confirmação.
- O painel Geral oferece `Guardar os últimos 10 textos`, ligado por padrão, com explicação de privacidade.
- Desligar o ajuste apaga imediatamente o histórico persistido após confirmação.

## Privacidade e segurança

- Arquivo local em Application Support, escrita atômica e permissões somente do usuário.
- Sem áudio, telemetria, rede, logs de texto, iCloud ou sincronização.
- Diagnósticos e erros nunca incluem o conteúdo transcrito.
- Histórico não é exibido em notificações nem no HUD.

## Falhas

- Falha ao persistir: clipboard continua sendo a recuperação primária e o menu informa que o histórico local está indisponível.
- Falha ao escrever no clipboard: não tentar inserção e apresentar erro.
- Falha de som: não bloqueia gravação, transcrição ou inserção.
- Arquivo corrompido: ignorar o conteúdo, preservar o arquivo para diagnóstico sem exibi-lo e iniciar lista vazia.

## Aceite

1. Som de início ocorre somente após `AudioRecorder.start()` passar; som de fim somente após `stop()` passar.
2. Uma transcrição permanece no clipboard depois de inserida.
3. Com o destino encerrado antes da inserção, o texto continua no clipboard e em `Textos recentes`.
4. O 11º texto remove apenas o mais antigo; limpar remove todos.
5. Com sons desligados, o fluxo continua idêntico sem reprodução sonora.
6. Testes não gravam texto real do usuário em logs ou fixtures versionadas.

## Não objetivos

Histórico de áudio, busca, favoritos, edição, sync, conta, billing, analytics, nuvem e reescrita por IA.
