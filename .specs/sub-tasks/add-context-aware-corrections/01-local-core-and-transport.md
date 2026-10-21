# 01 — Fundamentos locais e transporte isolado

**Task File:** `.specs/tasks/draft/add-context-aware-corrections.feature.md` (usar localização atual se promovida).
**Phase:** 1
**Model:** opus
**Agent:** developer
**Depends on:** Feedback visual/Phase 4 da task dependente integrado na `main`; worktree limpo e branch própria criados dessa `main`. O antigo Step 07 Jev não é dependência.
**Parallel with:** None
**Note:** Integridade de persistência, segredo, contrato remoto e deadline justificam opus. Ler a task inteira, `.specs/analysis/analysis-context-aware-corrections.md` e `.claude/skills/context-aware-transcription-corrections/SKILL.md`; os limites da task prevalecem sobre propostas antigas. Nenhuma chave real, chamada, instalação ou habilitação do ditado remoto neste passo.
**Goal:** Disponibilizar o núcleo contextual mínimo, testável sem rede, sem alterar o fluxo de produção existente.

Concentrar tipos internos, store, seleção/validação e cliente dedicado em `ContextualCorrections.swift`, usando Foundation/Security. Reusar padrões existentes sem SDK, provider genérico ou extração de helpers por conveniência. Antes de editar, verificar callers de `TranscriptPostprocessor.process`, `TranscriptionGlossary`, `TranscriptHistory` e `ProductPreferences.saveTranscriptionCorrection`; esses caminhos legados permanecem intactos.

**Arquivos permitidos:** criar `Sources/WhisperKey/ContextualCorrections.swift` e `Tests/Fixtures/contextual-corrections.json`; alterar `Tests/WhisperKeyTests/WhisperKeyTests.swift`, `project.yml` e `WhisperKey.xcodeproj/project.pbxproj`. Todo outro código é somente leitura. Declarar a fixture explicitamente em `targets.WhisperKey.sources` com `buildPhase: resources`, mantendo também seu uso no target de testes, e regenerar por XcodeGen para incluí-la em Copy Bundle Resources do app; não adicionar framework/dependência além de Security se o linker efetivamente exigir.

#### Expected Output

Store versionado, matcher/decisão conservadores, transporte efêmero, adaptador Keychain e autorização única disponíveis internamente com dependências mínimas injetáveis para testes. App continua compilável com comportamento atual. Corpus sintético versionado tem 100 casos nas cinco categorias da arquitetura, pelo menos cinco pares e famílias distintas de aprendizado/calibração/avaliação; nenhum conteúdo pessoal.

#### Success Criteria

- CK-1, CK-2, CK-9: registro válido contém UUID/idioma/par/frase/ordinal; 100 itens, 600 `String.count`, teto de leitura 2 MiB; escrita/leitura de confirmação, recuperação, permissões 0700/0600, duplicata, conflito e exclusão não alteram glossário/histórico. Estado corrompido/versão desconhecida bloqueia mutação, preservando arquivos e snapshot confiável.
- CK-3, CK-4, CK-10: termo inteiro, ordinal/span, Unicode e aplicação literal reversa passam; confiança e probabilidade vencedora ambas >= 0,90, empate/inconsistência rejeitados. Caso misto mantém primeiro rosto e troca apenas o segundo para Hostel; fake é identificado como prova de contrato, nunca qualidade Jev.
- CK-5, CK-6: zero/quatro ocorrências, múltiplas frases, conflito, prazo total de 900 ms, erro e incerteza retornam a entrada integral; uma a três ocorrências na mesma frase permitem decisões válidas independentes. Transporte tardio não retarda a conclusão nem produz outro resultado.
- CK-7, CK-8, HR-1, HR-2: allowlist sintética fixa, limite 600 caracteres/64 KiB de resposta, HTTPS/host fixos, redirect recusado, sem cache/cookie/retry; header é a única posição da credencial. Guard consumido antes do despacho sobrevive a concorrência/reinício e falha fechada. Todos os testes usam doubles; sem acesso ao Keychain pessoal ou rede.
- CK-8, CK-12, HR-1, HR-3: XCTest relevante passa via `mac-gate`; `testDiagnosticFixtureLoadsFromCandidateAppBundle` carrega e valida o recurso do bundle app candidato, não do checkout/bundle de testes. O diff gerado inclui a fixture sintética sem segredos/dados reais em Copy Bundle Resources do app. Nenhuma nova dependência ou alteração de gate/CI.

#### Subtasks

1. Implementar o store separado em `ContextualCorrections.swift` no caminho `Application Support/Resenha/ContextualCorrections/v1.json`, incluindo validação integral, escrita atômica/rollback confirmado, modo indisponível e exclusão dos arquivos contextuais próprios. Não reaproveitar a retenção de `TranscriptHistory` nem criar migração/FIFO.
2. Implementar seleção por idioma/par e ocorrência inteira, segmentação Foundation, limite integral de candidatos e resolvedor com snapshot imutável, deadline monotônico e resultado único. Validar conjunto exato de questões, labels/probabilidades/confidence; `keep_original` de uma ocorrência não impede substituição válida em outra. Preservar literais `$` e `\`.
3. Implementar cliente Decisions em sessão efêmera limitada, adaptador `SecItem` com service/account fixos e todos os OSStatus tratados, e guard de diagnóstico consumível uma vez sem reset automático. Política de ditado pessoal nunca pode habilitar esse transporte. Persistir apenas o estado não sensível da autorização no mesmo diretório restrito; apagar exemplos/chave não o rearma.
4. Escrever os testes próprios de store, parser, payload, credencial falsa, concorrência, timeout e corpus em `WhisperKeyTests.swift`, com recursos sintéticos declarados em `project.yml`. Incluir 99/100/101 registros, 599/600/601 caracteres NFC/NFD, read-back/rollback falhos, desconhecimento de schema, mixed keep/replace, PII sintética, 401/429/5xx, redirect, resposta grande e autorização consumida após timeout/reinício. Adicionar `testDiagnosticFixtureLoadsFromCandidateAppBundle`: no host app, usar a mesma carga do diagnóstico via `Bundle.main`, conferir bundle ID/caminho em `Contents/Resources`, schema e ID allowlisted esperado; nenhum fallback para checkout ou bundle de testes. Ausência/invalidez do recurso bloqueia o diagnóstico antes de consumir a chamada.
5. Regenerar com `xcodegen generate`, revisar só o diff esperado e executar os XCTest deste núcleo via `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` com filtros `-only-testing` dos testes criados se útil. Entregar contratos e resultados a 02; a revisão formal única fica ao final da fase 1.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Blocker | Dependência não integrada ou worktree ainda visual/sujo | High | Medium | Registrar SHA de main com feedback; criar branch própria sem copiar/stash/reset do WIP; não iniciar código antes disso |
| Risk | Falha no disco gera falso Save ou exclusão incompleta | High | Medium | Validar antes/depois da troca, preservar anterior, bloquear mutações sem recuperação; testes de cada falha |
| Risk | Faixa Unicode ou substituição regex altera outra ocorrência | High | Medium | Ranges locais imutáveis, ordinal e termo inteiro, substituição literal do fim para o início; mixed case/Unicode |
| Risk | Guard reinicia ou Keychain/redirect expõe credencial | High | Medium | Estado consumido durável e fail-closed, escopo SecItem fixo, header limitado a host fixo, zero segredos reais em testes |
| Risk | Transporte não cooperativo ultrapassa deadline | High | Medium | Encerramento único com relógio e callbacks descartáveis; teste de resposta tardia sem esperar filho indefinidamente |
