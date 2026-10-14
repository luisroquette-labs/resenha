# SPEC-015 — Lapidação contínua do produto

Status: active for the App Store and Developer ID channels defined by Amendment 004.

## Objetivo

Elevar o Resenha por ciclos completos de inspeção, correção e validação até que duas rodadas consecutivas não encontrem correções ou otimizações relevantes.

## Invariantes

- Uma interrupção do monitor global nunca pode deixar uma gravação presa.
- Combinações com modificadores extras não acionam um atalho diferente do configurado.
- Áudio e texto temporários ficam em diretórios acessíveis somente ao usuário e são removidos após uso ou abandono.
- Toda instrução de interface continua correta depois que o usuário troca a hotkey.
- Ajustes permanecem utilizáveis por teclado, VoiceOver, janela menor e janela ampliada.
- README, site e specs descrevem somente recursos e limitações atuais.
- Ambos os builds usam Hardened Runtime e whisper.cpp embarcado. App Sandbox é obrigatório na App Store e ausente no Developer ID.

## Validação

Cada rodada executa analyzer, testes nativos, testes do site, inspeção das fixtures e execução do app assinado. Todo bug corrigido recebe teste de regressão. A rodada só conta como limpa se não produzir mudança relevante de código, segurança, desempenho ou UI/UX.
