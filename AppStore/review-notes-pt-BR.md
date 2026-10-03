# Notas para a equipe de revisão

> Arquivo histórico: a distribuição pela Mac App Store foi substituída pela distribuição direta em 03/10/2026. Estas notas não descrevem o bundle atual.

Resenha é um app de barra de menus. Não há conta, compras ou conteúdo pago.

## Fluxo principal

1. Abra o Resenha e conceda Microfone e Monitoramento de Entrada.
2. Clique em “Baixar” para instalar o modelo local verificado de 181 MB.
3. Em um campo de texto, mantenha `Control + Option + Espaço` pressionado.
4. Fale e solte a barra de espaço.
5. Aguarde a transcrição ser devolvida ao campo pelo Serviço “Ditar com Resenha”.

O atalho é um `NSServices` key equivalent e pode ser alterado em Ajustes do
Sistema → Teclado → Atalhos de Teclado → Serviços. O app usa um event tap
`listenOnly` apenas para detectar a soltura do atalho. Não injeta eventos.

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
