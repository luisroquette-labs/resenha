# Feature: melhorar qualidade de transcrição local

## Fonte

SPEC-011 e `docs/tasks/M2-OUTPUT-QUALITY.md`.

## Estado observado

O fluxo real passou no TextEdit. A frase pretendida “Testando o Resenha no meu Mac.” foi inserida como “Testando o resenho no meu Mac.”

## Próxima unidade executável

Criar o menor corpus versionado e um runner local que compare referência, termos críticos e tempo sem fazer rede. Não ajustar prompt, glossário, modelo ou decoding antes desse baseline.

Depois do baseline, expor seleção persistente `PT-BR | EN | ES` no menu; PT-BR deve preservar os anglicismos do corpus.

## Pronto quando

- OQ-001 é reproduzível.
- O baseline atual é salvo em resultado legível.
- O runner falha quando `Resenha` não aparece exatamente.
