# SPEC-015 — Lapidação contínua do produto

Status: active, with the App Store/Sandbox gate superseded by SPEC-021 for direct distribution.

## Objetivo

Elevar o Resenha por ciclos completos de inspeção, correção e validação até que duas rodadas consecutivas não encontrem correções ou otimizações relevantes.

## Invariantes

- Uma interrupção do monitor global nunca pode deixar uma gravação presa.
- Combinações com modificadores extras não acionam um atalho diferente do configurado.
- Áudio e texto temporários ficam em diretórios acessíveis somente ao usuário e são removidos após uso ou abandono.
- Toda instrução de interface continua correta depois que o usuário troca a hotkey.
- Ajustes permanecem utilizáveis por teclado, VoiceOver, janela menor e janela ampliada.
- README, site e specs descrevem somente recursos e limitações atuais.
- O build macOS usa Hardened Runtime; App Sandbox e empacotamento do whisper.cpp ficam como gate explícito da distribuição pela App Store.

## Validação

Cada rodada executa analyzer, testes nativos, testes do site, inspeção das fixtures e execução do app assinado. Todo bug corrigido recebe teste de regressão. A rodada só conta como limpa se não produzir mudança relevante de código, segurança, desempenho ou UI/UX.
