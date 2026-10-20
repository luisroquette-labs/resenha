# 01 — Save local validado com rollback

**Task File:** `.specs/tasks/draft/add-transcription-feedback.feature.md` (usar localização atual se promovida).
**Phase:** 1
**Model:** opus
**Agent:** developer
**Depends on:** None
**Parallel with:** 02
**Note:** Opus por integridade de dados. Own `Sources/WhisperKey/WhisperTranscriber.swift`, `Sources/WhisperKey/ProductPreferences.swift` e região de testes imediatamente antes de `testPersonalGlossaryCanonicalizesObservedPhysicalTranscripts` em `Tests/WhisperKeyTests/WhisperKeyTests.swift`. Step 02 possui regiões HUD distantes; não reformatar arquivo inteiro nem executar gates durante escrita paralela. Não escrever UI/panel/app. O contrato P3 de Implementation Process prevalece sobre a omissão da arquitetura.
**Goal:** Persistir somente um par confirmado representável, com resultado verificável e restauração do valor anterior se houver erro excepcional.

Ler arquitetura Persistence/Failure e todos os usos de `ProductPreferences.transcriptionGlossary`, `TranscriptionGlossary.init(text:)`, `.prompt`, `.replacements` e `TranscriptPostprocessor.process(_:glossary:)`. No arquivo do glossário, definir o helper puro `TranscriptionGlossary.correctionCandidate(heard:canonical:existingText:)`, com resultado adicionado/já existente/erro de validação; no arquivo de preferências, `ProductPreferences.saveTranscriptionCorrection(heard:canonical:)` oferece esses resultados mais erro de armazenamento. Expor também `ProductPreferences.reloadTranscriptionGlossaryForCorrection()` e estado somente de leitura `canSaveTranscriptionCorrection` para reconciliar falha de rollback. Nomes internos auxiliares podem seguir o estilo existente; manter estas entradas e comunicar tipos/resultados ao passo 03. Sem novo arquivo Swift, protocolo de storage ou framework de mocks.

#### Expected Output

Helper e Save utilizáveis em testes sem UI; preferências atuais continuam funcionando. Save lê o texto atual no MainActor, conserva os bytes anteriores e a chave `resenha.transcriptionGlossary`, valida antes de escrever e só confirma depois de verificar armazenamento real e parser. Não altera reconhecimento, regex, substituição sequencial nem setter legado de Ajustes fora do necessário para a operação segura.

#### Success Criteria

- CK-4/CK-5: trim, vazio, igualdade exata, quebras de linha e `=` nos dois campos são tratados; correção apenas de caixa é permitida. Conflitos case-insensitive, inclusive além da janela de 200, são rejeitados com destino existente; duplicata só é no-op se já efetiva e sem conflito.
- Limites exatos 160/161 da linha serializada, 200/201 entradas aceitas antes da deduplicação, 20.000/20.001 texto e 8.000/8.001 prompt completo antes de truncamento são testados. Não reordenar/remover entradas para abrir espaço; preservar substituições previamente efetivas.
- Caminho normal atribui uma vez, inválido/no-op zero vezes. Falha de write/read-back restaura valor publicado e estado original da chave, verifica rollback e retorna erro; nunca anuncia sucesso. Erro permite que o chamador mantenha o draft. Falha de rollback marca baseline sem verificação e faz `canSaveTranscriptionCorrection` false; Save direto também rejeita sem escrita até uma recarga explícita bem-sucedida.
- `reloadTranscriptionGlossaryForCorrection()` relê armazenamento real e verifica representação/baseline e parser; atualiza a preferência em memória sem persistir, sem `synchronize()` e sem sobrescrever com snapshot antigo. Só então desbloqueia Save. Baseline pode conter a regra da escrita que não foi revertida; o próximo Save trata duplicata/conflito pelas mesmas regras e exige nova confirmação. Recarga falha mantém bloqueio e não cria sucesso; cancelar a UI nunca desbloqueia o serviço.
- CK-6/CK-8: preferências reconstruídas e pós-processador real convertem “A Coisa Energia chegou.” sem substituir palavra maior; somente chave do glossário muda. Edição de Ajustes após abrir draft permanece no Save atual.

#### Subtasks

1. Inspecionar callers do glossário/setter e extrair a construção de candidato junto a `TranscriptionGlossary`, reutilizando constantes e sem mudar o parser legado. Inspecionar conflitos em todas as linhas e confirmar regra pelo parser efetivo.
2. Implementar `ProductPreferences.saveTranscriptionCorrection(heard:canonical:)` síncrono, snapshot anterior, verificação real da chave e parser, e rollback excepcional de P3. Preservar ausência da chave original; não usar `synchronize()` nem criar chave extra. Implementar `canSaveTranscriptionCorrection` e `reloadTranscriptionGlossaryForCorrection()` para bloqueio e reconciliação explícita sem escrita; setter de persistência não deve disparar na atualização somente em memória. Entregar esse contrato ao owner UI de 03.
3. Escrever testes próprios na região atribuída: todos os limites acima, última linha sem newline, duplicatas efetivas/inefetivas/conflitantes, fonte canônica implícita, igualdade/caixa, espaços, Unicode, `$`, barra invertida, pontuação e cascata existente. Usar suites UserDefaults únicas e limpar somente essas suites.
4. Escrever regressão P3/J4-1 com `UserDefaults` de teste que permite escrita mas diverge em uma leitura pós-write: verificar erro, valor anterior restaurado e reconstrução correta após retirar fault. Cobrir chave originalmente ausente, rollback que falha, Save direto bloqueado sem escrita, recarga falha mantendo bloqueio e recarga verificada reabilitando Save sem mutação. Testar baseline que ainda contém candidato anterior e nova confirmação idempotente. Não adicionar injeção a recorder/transcriber/injector.
5. Provar integração Save → reconstruir preferências → `TranscriptionGlossary` → `TranscriptPostprocessor.process`, incluindo glossário editado entre abertura e Save. Entregar API/resultados a 03; após fim de 02, executar uma vez o gate de fase `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` e registrar comando/resultado para revisão opus.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Setter legado trunca regra e devolve sucesso falso | High | High | Candidato completo pré-validado; conferir defaults relido e parser, rollback em divergência |
| Risk | Glossário tem conflito oculto fora das primeiras 200 entradas | High | Medium | Inspecionar texto integral, comparar pela semântica case-insensitive do motor; rejeitar sem escrita |
| Risk | Save usa snapshot antigo e apaga mudança em Ajustes | High | Medium | Ler e gravar síncrono no MainActor no instante do Save; teste de edição intercalada |
| Risk | Recuperação também falha e induz nova confirmação ambígua | High | Low | Retorno específico e Save bloqueado inclusive direto; recarga explícita sem escrita reabilita apenas após baseline persistida verificada; draft mantido por 03 |
| Blocker | Edição concorrente no XCTest ou dependência de framework local ausente | Medium | Medium | Regiões distintas/patch estreito; gate após 02; seguir README para framework, não contornar gate |
