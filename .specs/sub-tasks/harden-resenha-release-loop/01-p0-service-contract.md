# Step 01: Corrigir contrato P0 do Serviço

**Task File:** `.specs/tasks/in-progress/harden-resenha-release-loop.feature.md`
**Phase:** Phase 1
**Model:** opus
**Agent:** developer
**Depends on:** None
**Parallel with:** None

**Goal:** Tornar o atalho publicável e a inserção verdadeira, eliminando rotas silenciosas.

#### Expected Output

- Specs 001/002/017 e arquitetura reconciliadas.
- `Config/ResenhaStore-Info.plist`, monitor, app e provider com um único contrato.
- Testes reais do provider e controles de release/build obsoleto.

#### Success Criteria

- `NSKeyEquivalent` é válido e não usa VO-Space.
- Qualquer personalização exposta é implementável pelo Serviço e descrita honestamente.
- A soltura só completa uma requisição ativa; rota direta não promete inserção.
- Provider não espera dez minutos no `MainActor` sem uma fronteira explícita e limitada.
- SERVICE-001–003 possuem cobertura automatizada do provider real.
- Nenhuma mutação App Store é feita sem aprovação explícita.

#### Subtasks

- [x] Planejar o contrato único e registrar a decisão SDD.
- [x] Implementar Serviço, hotkey e UI coerentes.
- [x] Adicionar testes de regressão do provider e configuração.
- [x] Atualizar verificação de build submetido e release manual segura.
- [x] Rodar testes da fase via `mac-gate`.

#### Blockers & Risks

- NSServices é síncrono; justificar e limitar qualquer nested run loop exigido por AppKit.
- Alterar/remover build submetido é ação externa fora deste step sem aprovação.
