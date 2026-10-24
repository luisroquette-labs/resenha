# 05 — Feedback compacto e temporizado no HUD

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** 3
**Model:** opus
**Agent:** developer
**Reviewer model:** opus
**Depends on:** 04
**Parallel with:** None

## Goal

Substituir o cartão de feedback grande e indefinido por dois controles discretos que emergem dentro do mesmo HUD `280×64` de transcrição/inserção, exatamente após uma conclusão elegível. A oferta passiva dura 4 segundos. Like encerra imediatamente; dislike cancela o timeout antes de abrir o editor existente, que permanece até ação explícita. Atualizar e validar o app instalado somente depois de o candidato passar gate e revisão.

O diff de produto fica restrito a `Sources/WhisperKey/FloatingStatusView.swift`, `Sources/WhisperKey/FloatingPanel.swift` e às regiões pertinentes de `Tests/WhisperKeyTests/WhisperKeyTests.swift`. Atualizar apenas `docs/specs/06-floating-ui.md`, `docs/specs/08-testing.md` e `docs/testing/UI-REFINEMENT-EVIDENCE.md` para o contrato/evidência. Não tocar `DictationCoordinator`, `WhisperKeyApp`, menu, glossário, preferências, inference, pós-processamento, rede, analytics, dependências ou projeto Xcode salvo se um teste provar incompatibilidade inevitável; nesse caso parar e reportar o blocker antes de ampliar escopo.

## Expected Output

- `.feedback` reutiliza a superfície, posição, material e frame `280×64` de `.transcribing`/`.inserting`; não mostra “Como foi a transcrição?”, cartão vertical ou botões com texto visível. Dois ícones pequenos de like/dislike mantêm labels/hints acessíveis completos e hit targets nativos.
- `offerFeedback` arma expiração em 4 segundos usando o mecanismo de dismissal existente, com geração e token da sessão. Expiração limpa somente a oferta ainda passiva, suas ações de menu/token e o painel; não escreve preferências nem mostra notice.
- `openCorrection` invalida a expiração antes de abrir a janela. Editor, draft, erro e Save existentes não expiram. Like, novo ditado, HUD off, cancelamento e encerramento preservam os contratos atuais.
- Timer da oferta A é incapaz de fechar oferta B, editor, gravação, notice ou estado posterior. Reduce Motion remove a transição, não os 4 segundos. VoiceOver anuncia controles pelos nomes, não apenas “botão”.
- Gate, fixtures e teste físico são registrados contra o mesmo SHA/binário; após aprovação, `/Applications/Resenha.app` recebe esse candidato com assinatura/permissões preservadas e a evidência identifica versão instalada e processo executado.

## Success Criteria

- [X] CK-1: feedback cabe em `280×64`, não altera centro/posição ao substituir o estado de processamento e usa somente os dois ícones discretos, sem nova janela/painel para a oferta.
- [X] CK-7/CK-11: deadline é `now + 4`; antes dele a oferta existe, no limite ela some sem persistência. Dislike/editor cancela timer. Geração + token + estado passivo tornam callbacks antigos inócuos; novo ditado e HUD off continuam encerrando sessão normalmente.
- [ ] CK-9: ambos os controles têm label, hint, contraste e área acionável verificáveis; VoiceOver os distingue. Reduce Motion produz transição imediata no mesmo frame, com timeout idêntico.
- [X] CK-2/CK-3/CK-8: like/expiração não mudam defaults/glossário; dislike abre o editor de dois campos já existente; nenhuma dependência, API, rede, telemetria ou persistência nova.
- [ ] CK-10: gate canônico verde via mac-gate; app instalado é atribuível ao SHA final e prova em TextEdit continuidade, expiração, dislike persistente, novo ditado, foco e clipboard sem fechar Chrome/Terminal nem apagar dados pessoais.

## Subtasks

1. [X] Traçar todos os callers de `offerFeedback`, `present`, `showTemporarily`, `dismissIfCurrent`, `invalidateDismissal`, `discardFeedback`, `.feedback` e `panelSize` antes de editar. Confirmar que o mesmo `PanelDismissal` pode receber geração+deadline sem criar timer/abstração paralela.
2. [X] Compactar somente a branch `.feedback`: frame `280×64`, mesma casca do processamento e dois botões de ícone em linha. Manter labels/hints “Transcrição correta” e “Corrigir transcrição”, hit targets adequados, contraste/transparência e animação curta apenas quando Reduce Motion estiver desligado.
3. [X] Armar 4 segundos em `offerFeedback`; no callback exigir geração atual, token original e sessão ainda `offered` antes de descartar. Invalidar o timer antes de dislike/editor e em todos os encerramentos existentes. Não reutilizar `showTemporarily` se seu `show()` descartar a sessão; adaptar o menor seam existente em `FloatingPanel.swift`.
4. [X] Atualizar XCTest/fixtures: dimensões/continuidade `280×64`, labels e ações, matriz claro/escuro/contraste/transparência/Reduce Motion; deadline 4s, antes/no limite, dislike cancelando, oferta A → B, oferta → editor, oferta → gravação/notice e HUD off. Provar que nenhum callback antigo limpa token/draft/estado novo ou escreve preferência.
5. [ ] Validar e instalar o candidato: rodar `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`, corrigir/repetir até verde, inspecionar fixtures, atualizar as três specs/evidências e passar pela revisão opus da Phase 3. Só depois produzir candidato assinado do SHA final, arquivar a instalação anterior de forma recuperável, instalar/abrir `/Applications/Resenha.app` e testar em TextEdit continuidade, expiração e dislike persistente. Registrar SHA/build/processo, VoiceOver, Reduce Motion, foco e clipboard; não alegar prova não observada.
   - [X] Gate final `68ddb7c`: 82 testes sem falhas; revisão Phase 3 4.53; candidato instalado com assinatura, hashes, PID 96641 e backup original recuperável verificados. Menu “Pronto” e input `Microfone (MacBook Pro)` observados; evidência registrada.
   - [ ] Prova física TextEdit/timeout/editor/VoiceOver/Reduce Motion/foco/clipboard: interrompida antes de teclas/TTS porque TextEdit não manteve primeiro plano. Clipboard e estado transitório preservados; instalação atualizada mantida. Não observado, não aprovado.

## Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Reusar `showTemporarily` chama `show()` e descarta a própria sessão | High | High | Armar deadline diretamente sobre a sessão ofertada e validar geração+token+estado no callback |
| Risk | Timer antigo fecha oferta nova, editor ou HUD de gravação | High | Medium | Guard triplo e testes A→B/A→editor/A→status posterior com relógio controlado |
| Risk | Ícones compactos ficam inacessíveis ou pequenos demais | High | Medium | Labels/hints, hit target nativo, contraste e teste VoiceOver físico; tamanho visual discreto não reduz área acionável |
| Risk | Animação altera prazo ou incomoda Reduce Motion | Medium | Medium | Deadline independente da animação; transição desativada no ambiente Reduce Motion e fixtures dedicadas |
| Blocker | Binário instalado não corresponde ao SHA ou perde assinatura/TCC | High | Medium | Identificar artefato, assinatura, bundle e processo antes/depois; backup recuperável e instalação somente após gate/review |
