# Notas para a equipe de revisão

Resenha é um app de barra de menus. Não há conta, compras ou conteúdo pago.

## Fluxo principal

1. Abra o Resenha e conceda apenas Microfone.
2. Clique em “Baixar” para instalar o modelo local verificado de 181 MB.
3. Em um campo de texto, pressione `Command + Shift + E` para iniciar.
4. Fale e clique em “Concluir” no painel do Resenha. Se preferir, abra o ícone
   do Resenha na barra de menus e selecione “Concluir gravação”.
5. Aguarde a transcrição ser devolvida ao campo pelo Serviço “Ditar com Resenha”.

O atalho é um `NSServices` key equivalent gerenciado pelo macOS. O app não
registra um atalho global, não observa teclas, não pede Monitoramento de Entrada
e não injeta eventos.

O build 7 corrige a rejeição 2.1 do build 6: o painel flutuante agora aceita
cliques durante a gravação e o menu da barra oferece uma segunda ação explícita
para encerrá-la.

## Rede e privacidade

A única conexão de rede do produto baixa o modelo de
`https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin`.
O arquivo esperado tem 190.085.487 bytes e SHA-256
`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
Áudio e transcrições nunca são enviados.

## Sandbox

O app usa apenas:

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client`

Resenha não solicita Acessibilidade e não usa `AXUIElement` ou `CGEvent.post`.
