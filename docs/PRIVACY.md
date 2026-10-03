# Política de Privacidade do Resenha

**Vigência:** 2 de outubro de 2026  
**Aplicável à versão:** 1.0.0

Resenha é um aplicativo de ditado local para macOS. Não criamos contas, não
operamos um backend do produto, não exibimos anúncios e não coletamos dados
pessoais, áudio, transcrições, diagnósticos ou métricas de uso.

## Processamento local

- O microfone é capturado somente durante um ditado iniciado pelo usuário.
- O áudio temporário é transcrito no Mac com whisper.cpp e apagado ao término.
- A transcrição é colocada no clipboard para recuperação imediata.
- Se “Textos recentes” estiver ativo, até 10 transcrições ficam apenas neste Mac.
- O usuário pode desativar e apagar esse histórico nos Ajustes do Resenha.

## Download do modelo

O arquivo do modelo Whisper é baixado diretamente de
`huggingface.co/ggerganov/whisper.cpp`. Esse servidor pode receber informações
técnicas normais de uma conexão HTTP, como endereço IP e user agent, conforme a
política do próprio provedor. Resenha não envia áudio ou transcrições nessa
conexão e não recebe esses registros.

## Permissões

- **Microfone:** capturar a fala enquanto o ditado estiver ativo.
- **Monitoramento de Entrada:** detectar quando o atalho de ditado é solto.

Resenha não solicita Acessibilidade. A inserção usa o mecanismo nativo de
Serviços do macOS.

## Contato

Questões de privacidade e segurança podem ser abertas publicamente em
https://github.com/luisroquette/resenha/issues. Não inclua transcrições ou
informações pessoais em uma issue pública.
