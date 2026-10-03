# Feature: feedback e recuperação do ditado

## Fonte

SPEC-012 e `docs/tasks/M1-TRUST-RECOVERY.md`.

## Contrato mínimo

- Som discreto após início e fim reais da captura.
- Texto no clipboard antes da inserção.
- Dez textos locais no menu, com copiar e limpar.
- Falha visível sem perder transcrição concluída.

## Fora

Áudio persistido, nuvem, busca, favoritos e IA.

## Evidência atual

- Implementação e assinatura: PASS.
- `mac-gate xcodebuild ... test`: 44 testes, 0 falhas.
- Bundle relançado como um processo.
- Som ouvido, clipboard persistente e menu populado após ditado físico: PENDENTE.
