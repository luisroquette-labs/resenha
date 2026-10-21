# 02 — Aprendizado, controles e lifecycle

**Task File:** `.specs/tasks/draft/add-context-aware-corrections.feature.md` (usar localização atual se promovida).
**Phase:** 1
**Model:** opus
**Agent:** developer
**Depends on:** 01
**Parallel with:** None
**Note:** Contrato compartilhado entre coordinator, feedback, ajustes e app, com ownership e efeitos de saída. Usar o núcleo interno de `ContextualCorrections.swift` de 01; ler task/analysis completos. Nenhuma chamada real, instalação física ou acesso ao histórico pessoal.
**Goal:** Tornar o aprendizado contextual local utilizável e ligar o resolvedor antes dos destinos, mantendo toda rede de ditado pessoal bloqueada.

Atualizar todos os callers de `DictationCompletion`, `completeInsertion`, `configureFeedback`, `offerFeedback`, `saveCorrection`, `hotkeyReleased` e callbacks de preferências/AppDelegate. O snapshot de conclusão recebe texto final/idioma explícitos, sem defaults vazios. O feedback deixa de chamar `saveTranscriptionCorrection`, mas essa API e seus testes legados continuam válidos.

**Arquivos permitidos:** `Sources/WhisperKey/DictationCoordinator.swift`, `Sources/WhisperKey/FloatingPanel.swift`, `Sources/WhisperKey/ProductPreferences.swift`, `Sources/WhisperKey/WhisperKeyApp.swift`, `Sources/WhisperKey/PermissionOnboarding.swift`, `Tests/WhisperKeyTests/WhisperKeyTests.swift`; `ContextualCorrections.swift` apenas para completar a integração do contrato de 01. `TextInjector.swift`, `TranscriptHistory.swift`, `NativeMenuController.swift`, `DictationInteraction.swift`, `FloatingStatusView.swift` e `RecordingWaveformView.swift` são leitura; não redesenhar o feedback visual integrado.

#### Expected Output

Após inserção bem-sucedida, o editor confirma a frase e uma ocorrência antes de guardar exemplo no store separado. Ajustes mostram exemplos, exclusão, conflito legado, opt-in inicialmente desligado, controle seguro da credencial e diagnóstico sintético isolado. O app informa claramente que ditado remoto real está indisponível. Iniciar app, abrir ajustes e salvar aprendizado não enviam requests.

#### Success Criteria

- CK-1, CK-2, CK-9: Save confirma par/frase/ordinal, rejeita match ausente/ambíguo/limites, preserva draft em erro e não cria regra global. Listar/apagar item/tudo usa persistência verificada, inclusive history-off; conflito legado é visível sem remoção automática.
- CK-3, CK-4, CK-5, CK-6: `hotkeyReleased` resolve enquanto `.transcribing`; `stage(final)` e `onTranscript(final)` recebem a mesma string uma única vez antes de `insertStaged`. Falha de inserção preserva recuperação existente e não emite conclusão; trim/limite/dedup de histórico continuam sendo transformações legadas separadas.
- CK-6, CK-7: tentativa cancelada/obsoleta/término nunca produz novos efeitos; opt-out/exclusão de exemplo/chave invalida geração e usa original apenas se a tentativa continua válida. Nenhum resultado antigo edita clipboard/histórico/destino depois da entrega.
- CK-7, CK-8, CK-11, HR-1: controles têm rótulo/erro acessíveis, e produção não possui caminho de ditado pessoal remoto mesmo com toggle/chave. Captura com fake confirma zero requests em launch/settings/Save/opt-out/ausência de chave; credencial real nunca entra nos testes/defaults/logs.
- CK-11, CK-12, HR-3: regressões existentes de foco/hotkey/tokens/rollback ficam preservadas; probe fraco comprova descarte do contexto em sessões e closures aposentadas. Gate nativo completo passa pelo `mac-gate` no candidato a documentar em 03.

#### Subtasks

1. Em `DictationCoordinator.swift`, injetar o resolvedor mínimo, capturar tentativa/idioma/destino/política e aguardar antes de stage; revalidar após cada suspensão e antes dos efeitos. Atualizar `DictationCompletion` e `completeInsertion` para snapshot apenas após sucesso, capturado antes de reset; manter os guards atuais.
2. Em `FloatingPanel.swift`, trocar Save global por exemplo confirmado, mostrar frase/seleção explícita de ocorrência e estado de recuperação do store. Extrair UUID antes das closures; liberar contexto/view em expiry, Save, cancel, substituição, HUD-off e término. Recuperação retém só par/frase <=600/ordinal/idioma/foco mínimo; texto completo não fica oculto em hosting view.
3. Em `ProductPreferences.swift` e `WhisperKeyApp.swift`, compor uma instância do núcleo, ligar invalidação de política, opt-in, lista/exclusão e Keychain seguro. Expor diagnóstico somente com fixture allowlisted e guard de uma chamada, nunca uma entrada livre ou toggle que libere ditado remoto. Esclarecer processamento local versus diagnóstico remoto no About e `PermissionOnboarding.swift`.
4. Escrever/adaptar os testes próprios em `WhisperKeyTests.swift`: Save com reabertura/erro/idempotência, todas as construções de conclusão, cancel A/iniciar B/retorno A, opt-out/exclusões pendentes, ordenação e unicidade dos sinks, failure recovery, history-off e closures antigas. Manter vivo o panel/probe fraco após retirar o contexto para testar todos os caminhos de descarte; não confundir janela escondida com liberação.
5. Executar o gate nativo completo `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`; corrigir causas com regressão no mesmo diff. Entregar candidato, resultado e limitações a 03, sem instalar, ditar ou consumir a chamada.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Contratos de 01 não compilam com callers reais | High | Medium | Atualizar todos os construtores/callbacks explicitamente; corrigir contrato mínimo e regressões sem defaults silenciosos |
| Risk | Cancelamento vira fallback e ressuscita texto | High | High | Separar cancelar tentativa de invalidar política; testar ausência total de sinks para cancelamento/tentativa obsoleta |
| Risk | NSHostingView/closure conserva transcrição após fechamento | High | High | Capturar UUID/weak self, retirar contexto da view e testar probe fraco com panel/closures vivos |
| Risk | Save deixa glossário legado ativo ou apaga draft em falha | High | Medium | Store separado, conflito explícito e tratamento de recuperação preservado; não remover regra do usuário |
| Risk | Toggle/diagnóstico libera remotamente fala pessoal | High | Medium | Escopo synthetic-only independente da preferência, fixture fixa e fake de transporte capturando zero requests em todas as rotas pessoais |
