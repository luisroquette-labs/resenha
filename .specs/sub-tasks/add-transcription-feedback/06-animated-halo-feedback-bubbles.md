# 06 — Auréola animada e bolhas de feedback 3D

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** 4
**Model:** opus
**Agent:** developer
**Reviewer model:** opus
**Depends on:** 05
**Parallel with:** None

**Status:** in progress — revisão técnica 4.66/5 e gates automatizados aprovados; validação física parcial confirma somente o fluxo descrito abaixo.

**Evidência física confirmada em 2026-10-20:** com um documento vazio no TextEdit, a pessoa pressionou Option direita, ditou e confirmou que a auréola animou e que os dois emojis subiram e desapareceram. Não foram confirmados clique, editor, foco, VoiceOver, teclado alternativo, Reduce Motion, Increase Contrast ou clipboard.

## Goal

Restaurar no estado de escuta a auréola/orbe reativa do piloto anterior e transformar os dois controles compactos de feedback em pequenas bolhas com profundidade visual, entrada ascendente e desaparecimento gradual. O feedback continua dentro do mesmo HUD `280×64`, continua disponível por 4 segundos e o editor existente continua sendo a única superfície maior.

Usar somente SwiftUI/AppKit, SF Symbols, cores/gradientes/sombras já suportados e o meter/lifecycle existentes. O PR #13 (`feat/voice-orb-hud`, commit `758f9b13f272ed64d80981794c80dd15afe1440d`) é referência de leitura: portar apenas a composição nativa do orbe em `RecordingWaveformView.swift`, reconciliada com a branch atual. Não fazer merge/cherry-pick do PR, não copiar `site/assets/product/hud-listening.png` e não alterar site, áudio, captura, inference, glossário, preferências ou dependências.

## Expected Output

- Durante `.listening`, o antigo símbolo plano é substituído pela composição nativa do piloto: orbe de 44 pt com gradiente angular, brilho radial, sombra/auréola e reação ao `RecordingMeter.currentLevel`. A geometria permanece contida no HUD `340×72`; silêncio e fala são visualmente distintos. Não criar animação autônoma nem uma segunda fonte de nível.
- Durante `.feedback`, cada ação mantém target acionável mínimo `44×44` pt, mas apresenta um círculo visual menor com SF Symbol, gradiente, highlight, contorno e sombra leves para sugerir volume 3D. Os dois controles surgem de baixo para a posição de repouso, com pequeno stagger, e no trecho final da janela sobem suavemente enquanto perdem opacidade. O movimento fica dentro do frame e não move/redimensiona a janela.
- A animação é estritamente decorativa: não cria novo dono de timer, não altera o deadline de 4 segundos e não escreve estado. A expiração real continua em `FloatingPanelController`, protegida por geração + token + estado passivo. Reapresentar uma oferta reinicia somente a animação visual daquela apresentação; callback/animação da oferta A não fecha nem altera oferta B, editor, recording, notice ou HUD oculto.
- Com Reduce Motion, remover entrada/stagger/deslocamento e usar apenas fade curto e estável; manter deadline, targets e ações. Em light/dark, Increase Contrast e Reduce Transparency, preservar leitura do símbolo, borda e foco sem glow excessivo.
- Labels/hints continuam exatamente “Transcrição correta” e “Corrigir transcrição”; teclado/menu/VoiceOver continuam funcionais. Like encerra sem escrita; dislike invalida a expiração antes de abrir o editor persistente existente.

## Success Criteria

- [X] CK-1: o HUD de feedback segue `280×64`, sem cartão/título visível, e mostra duas bolhas pequenas que emergem/sobem/desaparecem sem alterar posição ou tamanho do painel. O listening segue `340×72` e recupera o orbe/auréola do piloto.
- [X] CK-7/CK-11: o deadline continua exatamente `now + 4`; a animação decorativa não agenda dismiss. Oferta A → B, oferta → editor, oferta → recording/notice e HUD off continuam protegidos contra callbacks antigos.
- [ ] CK-9: targets mínimos de `44×44`, labels/hints, foco de teclado e contraste são verificáveis. Reduce Motion remove deslocamento/stagger e conserva somente fade, sem mudar o prazo.
- [X] CK-2/CK-3/CK-8: ações e editor preservam o contrato existente; nenhuma nova persistência, rede, telemetria, API, asset, pacote ou configuração de projeto.
- [ ] CK-10: gate nativo verde, fixtures inspecionadas e app instalado atribuível ao SHA final; teste físico confirma auréola em silêncio/fala, bolhas subindo/fading, clique antes da expiração, editor persistente, foco e VoiceOver/Reduce Motion quando observáveis.

## Files and impact

| Path | Allowed change |
| --- | --- |
| `Sources/WhisperKey/RecordingWaveformView.swift` | Portar minimamente do PR #13 a composição SwiftUI do orbe/auréola e manter os helpers `RecordingResonance`, meter e acessibilidade atuais. |
| `Sources/WhisperKey/FloatingStatusView.swift` | Extrair no máximo uma pequena view local para a bolha; aplicar aparência 3D, targets, fases visuais e fallback Reduce Motion à branch `.feedback`. Não alterar o editor salvo se necessário para manter contrato compartilhado. |
| `Sources/WhisperKey/FloatingPanel.swift` | Somente se a inspeção provar que a view atual não recebe uma identidade de apresentação suficiente para reiniciar a animação; preferir o lifecycle existente. Não criar outro timer nem alterar persistência. |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Cobrir geometria/contrato visual calculável, reinício de apresentação e regressões do timer/token; atualizar fixtures da matriz existente. |
| `docs/specs/06-floating-ui.md` | Registrar orbe reativo, bolhas, fases, 44 pt, aparências e Reduce Motion. |
| `docs/specs/08-testing.md` | Acrescentar verificações determinísticas, fixture e roteiro físico do refinamento. |
| `docs/testing/UI-REFINEMENT-EVIDENCE.md` | Registrar SHA/binário, gate, fixtures e apenas observações físicas realmente executadas. |

Antes de editar, rastrear todos os usos de `RecordingWaveformView`, `RecordingResonance`, `FloatingStatusView`, `feedbackContent`, `offerFeedback`, `present`, `PanelDismissal` e fixtures. Se a solução exigir tocar em arquivo fora da tabela, parar e reportar o motivo antes de ampliar o escopo.

## Subtasks

1. Inspecionar o diff do PR #13 contra a implementação atual e portar somente o orbe nativo de `RecordingWaveformView.swift`. Preservar o mesmo nível normalizado, bounds, limpeza do meter, `.accessibilityHidden(true)` decorativo e Reduce Motion; não portar o PNG do site.
2. Implementar as duas bolhas no `feedbackContent` com uma área interativa `44×44` e círculo visual menor. Reusar os handlers, símbolos, labels e hints atuais; usar gradiente/highlight/contorno/sombra modestos, sem asset ou dependência. Não introduzir configuração genérica ou componente público.
3. Ligar a animação à apresentação da view: entrada curta de baixo, pequeno stagger entre as duas bolhas e fase final ascendente com fade antes do descarte de 4 segundos. Com Reduce Motion, não deslocar nem escalonar; usar somente fade. Nenhuma animação pode chamar approve/correct/dismiss ou alterar deadline.
4. Adicionar regressões mínimas: listening mantém `340×72` e valores do orbe finitos/limitados; feedback mantém `280×64`, duas ações e targets `44×44`; matriz light/dark/contraste/transparência/Reduce Motion sem corte; reapresentação reinicia visualmente sem permitir que callbacks antigos alcancem sessão nova/editor/status posterior. Reusar os testes de deadline existentes, sem duplicar o controller.
5. Atualizar as três specs/evidências, rodar o gate canônico via `mac-gate`, corrigir/repetir até verde e passar por uma única revisão opus da Phase 4. Depois da aprovação, produzir/instalar candidato preservando assinatura, bundle/TCC e backup recuperável; registrar hashes, processo e limitações do teste físico.

## Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Animação visual ganha timer/lifecycle paralelo | High | Medium | Controller continua único dono dos 4 segundos; view só anima propriedades e nunca descarta estado |
| Risk | Oferta A permanece montada e sua animação contamina B | High | Medium | Confirmar identidade/recriação da apresentação; adicionar o menor seed somente se o host existente não reiniciar a view |
| Risk | Visual pequeno reduz área clicável | High | Medium | Círculo visual menor dentro de frame/contentShape mínimo `44×44`, com foco e labels preservados |
| Risk | Glow/gradiente perde contraste ou vira ruído | Medium | Medium | Cores adaptativas, contorno reforçado em Increase Contrast, fixtures light/dark/transparência e sombra contida |
| Risk | Portar PR #13 traz asset/site ou regressão do waveform | Medium | Low | Port manual somente do trecho SwiftUI; comparar diff e manter captura/meter/layout atuais |
