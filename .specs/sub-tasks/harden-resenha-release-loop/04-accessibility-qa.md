# Step 04: Acessibilidade, layout e isolamento de QA

**Task File:** `.specs/tasks/todo/harden-resenha-release-loop.feature.md`
**Phase:** Phase 4
**Model:** opus
**Agent:** developer
**Depends on:** `03-local-integrity`
**Parallel with:** None

**Goal:** Tornar a interface legível, adaptável, multimonitor e testável sem poluir produção.

#### Expected Output

- Paleta WCAG AA, tipografia semântica e janelas redimensionáveis/roláveis.
- HUD posicionado pela janela do app alvo com fallback determinístico.
- Identidade e container Debug/test separados do Release.
- Plano e evidência física atualizados para VoiceOver e apps alvo.

#### Success Criteria

- Texto essencial mede pelo menos 4,5:1.
- Texto ampliado não corta ações nem impede navegação.
- HUD usa monitor alvo quando detectável e fallback documentado quando não.
- Testes passam com `/Applications/Resenha.app` aberto e não tocam preferências reais.
- LaunchServices não acumula cópias de produção por causa do runner.

#### Subtasks

- [x] Aplicar decisões Apple Design sem perder a identidade do Resenha.
- [x] Corrigir contraste, semântica e responsividade.
- [x] Implementar resolução de tela/janela e testes.
- [x] Separar configurações Debug/test e limpar fixtures.
- [x] Rodar testes, análise e roteiro de QA disponível.

#### Blockers & Risks

- VoiceOver físico e macOS 14 exigem ambiente real; nunca registrar PASS sem execução.
