# M2 — Qualidade de output

## Ordem

1. [x] Versionar o corpus PT-BR/code-switch e o runner de benchmark; incluir OQ-001 (`Resenha`, não `resenho`) e os cinco testes físicos observados.
2. [x] Medir o baseline `small-q5_1` com WER, termos críticos e P50/P95 no Apple M5.
3. [x] Comparar `small-q5_1` com `large-v3-turbo-q5_0`, ambos com os mesmos parâmetros; o Turbo venceu em WER e termos críticos.
4. [x] Implementar prompt, glossário local editável e o comando determinístico de correção especificado.
5. [ ] Repetir o fluxo físico em TextEdit e Chromium; registrar texto, latência, clipboard e limpeza temporária.

## Rodada de lapidação 2

1. [x] Tornar termos simples do glossário canônicos no texto final, com limites Unicode e sem corrupção de substrings.
2. [x] Corrigir o benchmark para exigir caixa e acentos exatos e recontar as três configurações.
3. [x] Encerrar `whisper-cli` ao cancelar e eliminar risco de deadlock nos pipes do subprocesso.
4. [x] Validar regressões, build assinado, instância única e ausência de subprocessos órfãos: 50/50 testes, PID único `92604`, nenhum `whisper-cli` residual.

## Regra de avanço

Cada candidato roda sobre os mesmos arquivos do baseline. Código só entra depois do corpus e do runner; o perfil padrão só muda com evidência melhor e sem regressão funcional.

## Fora deste marco

Reescrita por LLM, API OpenAI, tradução geral para português, expansão do histórico além da SPEC-012, login, billing, backend e Windows.
