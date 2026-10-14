# Step 03: Integridade local e licenças

**Task File:** `.specs/tasks/todo/harden-resenha-release-loop.feature.md`
**Phase:** Phase 3
**Model:** opus
**Agent:** developer
**Depends on:** `02-runtime-bounds`
**Parallel with:** None

**Goal:** Proteger modelo, histórico e bundle distribuído contra corrupção e drift.

#### Expected Output

- Verificação SHA-256 no lançamento e instalação atômica com rollback.
- Download cancelável/retomável e limpeza imediata de falhas.
- Limpeza completa do histórico/quarentenas.
- Override de modelo somente Debug e licenças incluídas no bundle.

#### Success Criteria

- Arquivo existente só fica pronto após hash válido.
- Falha de atualização preserva o modelo anterior válido.
- Cancelar/retomar não deixa parciais órfãos.
- `Limpar textos` remove todos os artefatos de histórico.
- Binário Release não contém o override e bundle contém notices/licenças.
- Testes da fase passam.

#### Subtasks

- [x] Atualizar SDD de integridade e privacidade.
- [x] Implementar verificação e substituição atômica.
- [x] Implementar cancelamento/retomada/limpeza do download.
- [x] Corrigir limpeza de histórico e empacotar licenças.
- [x] Validar Debug e Release via `mac-gate`.

#### Blockers & Risks

- Não apagar um modelo válido antes da confirmação do substituto.
