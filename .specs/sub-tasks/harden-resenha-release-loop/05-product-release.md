# Step 05: Produto, site, mídia e release reproduzível

**Task File:** `.specs/tasks/done/harden-resenha-release-loop.feature.md`
**Phase:** Phase 5
**Model:** opus
**Agent:** developer
**Depends on:** `04-accessibility-qa`
**Parallel with:** None

**Goal:** Fechar a experiência e preparar o build correto para decisão de submissão.

#### Expected Output

- Histórico opt-in, busca/favoritos de sons e memória validada.
- Site com SEO/social/schema/lazy loading e demonstrações de interação real.
- Screenshot 05 reorientada ao valor principal.
- Validador dinâmico e documentação/evidência consolidada para SHA/build finais.

#### Success Criteria

- Instalação nova começa sem histórico persistente.
- Sons são pesquisáveis e favoritos persistem localmente.
- Vídeos mostram cursor, hotkey, HUD responsivo e inserção, sem congelamentos longos.
- canonical, OG, Twitter e `SoftwareApplication` são testados.
- Assets de conversão não destacam sons de zoeira como mensagem principal.
- Validador não contém build fixo e rejeita mismatch.
- Todos os gates finais passam; qualquer gate físico não executado fica explícito.

#### Subtasks

- [x] Implementar preferências e testes de produto.
- [x] Criar demos reais localmente, sem API paga.
- [x] Corrigir site e assets da loja com Frontend Design.
- [x] Tornar tooling de release dinâmico e consolidar SDD/evidências.
- [x] Criar o novo commit-fonte, gerar o archive com o SHA embutido e validar o pacote exato via `mac-gate`.

#### Blockers & Risks

- Archive `1.0.0 (2)` vinculado ao commit
  `c822e2def90ad973c3d284745bda19ea6f5472a6`; contrato ancestral, fronteira binária,
  positivos e negativos de versão/build/SHA passaram em checkout limpo no HEAD
  `deb96dada0235a651c5c3c1fcc3c71f307d937fb`.
- TextEdit, Chromium, Terminal, VoiceOver, múltiplos monitores/Spaces e macOS 14 são
  gates físicos externos ainda `NOT RUN`; não são promovidos por testes automatizados.
- Upload, submissão e mudança de auto-release requerem autorização explícita.
