# Step 02: Limitar e cancelar o runtime

**Task File:** `.specs/tasks/in-progress/harden-resenha-release-loop.feature.md`
**Phase:** Phase 2
**Model:** opus
**Agent:** developer
**Depends on:** `01-p0-service-contract`
**Parallel with:** None

**Goal:** Garantir término determinístico de hotkey, gravação e inferência.

#### Expected Output

- Monitor associado à tecla/modificadores armados.
- Deadline de gravação e eventos de suspensão/tap desabilitado tratados.
- Abort callback cooperativo do whisper.cpp e descarregamento de contexto.
- Testes de concorrência, timeout, cancelamento e memória lógica.

#### Success Criteria

- `keyUp` não relacionado não encerra a sessão.
- Gravação nunca permanece ativa além do limite documentado.
- Timeout/cancelamento interrompe `whisper_full`, não apenas descarta resultado tardio.
- Contexto é liberado após ociosidade ou pressão de memória sem race/use-after-free.
- Testes e análise estática passam.

#### Subtasks

- [x] Especificar estado, deadlines e política de interrupção.
- [x] Implementar monitor e lifecycle de captura.
- [x] Implementar cancelamento e timeout cooperativos do Whisper.
- [x] Implementar política de liberação de contexto.
- [x] Rodar testes e benchmark de regressão via `mac-gate`.

#### Blockers & Risks

- Callback C deve manter contexto de cancelamento válido durante toda a inferência.
