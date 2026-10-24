# 02 — Oferta e editor acessíveis com fixtures

**Task File:** `.specs/tasks/draft/add-transcription-feedback.feature.md` (usar localização atual se promovida).
**Phase:** 1
**Model:** sonnet
**Agent:** developer
**Depends on:** None
**Parallel with:** 01
**Note:** Feature de apresentação delimitada, sem ownership de sessão/persistência; sonnet. Own `Sources/WhisperKey/FloatingStatusView.swift` e regiões `testHUDStateMappingIncludesInstructionsAndOperationMeaning` / `testHUDNativeFixturesForEveryStateAndAppearance` em `Tests/WhisperKeyTests/WhisperKeyTests.swift`. Step 01 usa a região de glossário. Não editar controller, app, menu, recorder nem métodos XCTest de persistência.
**Goal:** Disponibilizar views renderizáveis de oferta e correção, com ações injetadas, sem expor um fluxo de produção parcialmente integrado.

Ler `FloatingStatus`, `FloatingPanelModel`, `FloatingStatusView.panelSize(for:available:)`, `ResenhaDesign.swift`, `RecordingWaveformView.swift` e fixtures atuais. Adicionar `FloatingStatus.feedback`, `FloatingStatus.feedbackNotice(String)` para confirmação/orientação passiva e a view `TranscriptionCorrectionView` no mesmo arquivo. A oferta recebe `onApprove`/`onCorrect` como closures sem persistência; preferir parâmetros da view com defaults vazios para preservar `FloatingPanelController.makePanel()` enquanto 03 não conecta callbacks. O editor recebe bindings de `heard`, `canonical`, mensagem de erro e estado de Save, além de `onSave`/`onCancel`; a futura sessão do controller será sua dona. Nenhuma cópia de transcrição nem estado persistido. Comunicar assinatura exata a 03.

#### Expected Output

Oferta com “Transcrição correta” e “Corrigir transcrição”; formulário com exatamente “Saiu como”, “Correto é”, Salvar e Cancelar, erro visível e rótulos acessíveis. Views reutilizam estilo da casa e fixtures existentes. A aplicação mantém somente o comportamento anterior em produção até a integração 03; testes conseguem renderizar novos estados agora.

#### Success Criteria

- CK-9: feedback expõe filhos interativos; passivos preservam resumo acessível, aparência e waveform. Tab, Return/Escape e campo inicial são declarados na view; ativação da janela será devida em 03/04.
- `FloatingStatusView.panelSize(for:available:)` trata feedback com dimensão própria e mantém limites anteriores para ready/listening/transcribing/inserting/failure; sem afrouxar asserts globais.
- Campos começam vazios no fixture normal; erro mantém os bindings e retorna foco ao campo inválido. Não validar/gravar glossário na view; ações delegam ao owner futuro.
- Fixtures novas cobrem claro/escuro, contraste aumentado, transparência reduzida, Reduce Motion, termos/rótulos/erros longos e tela pequena sem controles cortados. Capturas são evidência visual, não prova física de VoiceOver/foco.

#### Subtasks

1. Traçar todos os switches/callers de `FloatingStatus` e `FloatingStatusView` antes de adicionar `.feedback`; atualizar os switches exaustivos necessários sem alterar o comportamento dos estados passivos.
2. Implementar branch da oferta e `TranscriptionCorrectionView` no arquivo existente com bindings/closures, campos vazios por contrato, hierarquia acessível por contenção e erro textual. Declarar `@FocusState`, default action e cancel action sem ativar qualquer app automaticamente.
3. Escrever testes próprios de mapeamento/dimensões e invocação dos handlers acessíveis usados pela view; ajustar somente casos novos no fixture harness, mantendo regressões e asserts dos estados passivos.
4. Escrever fixtures próprias de feedback/editor/erro e notice “Regra salva”/“Regra já existente” na matriz existente; inspecionar PNGs em `ResenhaTests/ui-fixtures` temporário e registrar cortes/legibilidade por aparência. Não introduzir snapshots versionados com conteúdo pessoal.
5. Entregar assinaturas e resultados a 03. Aguardar a escrita de 01 antes do gate único de fase coordenado por 01; fornecer capturas e diff à revisão opus. Falha de rendering deve ser corrigida, não compensada ampliando limites passivos.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | `.accessibilityElement(children: .ignore)` continua ocultando botões | High | High | Aplicar contenção somente à branch interativa e checar nomes/hierarquia; prova VoiceOver fica em 04 |
| Risk | Feedback quebra geometria ou waveform de gravação | Medium | Medium | Dimensões por estado, asserts passivos preservados, fixtures de toda matriz |
| Risk | View passa a armazenar draft independente do controller | Medium | Medium | Bindings e closures, sem gravação/local history na view; ownership único em 03 |
| Blocker | Novo case exige mudança fora do arquivo possuído | Medium | Low | Inspecionar switches antes; coordenar patch mecânico exaustivo com 01/03, sem apresentar placeholder em produção |
| Blocker | XCTest compartilhado recebe patch sobreposto | Medium | Medium | Regiões HUD separadas das de glossário; não reformatar helpers/imports ou rodar build durante escrita |
