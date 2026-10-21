# 10 — Build e instalação Release endurecidos

**Task File:** `.specs/tasks/in-progress/add-transcription-feedback.feature.md`
**Phase:** Phase 5
**Model:** opus
**Agent:** developer
**Depends on:** `07-hud-lifecycle-performance-hardening`, `08-safe-feedback-learning-and-privacy`, `09-preemptive-whisper-cancellation`
**Parallel with:** None
**Note:** Último passo da fase. Não instalar nada antes de testes via mac-gate, revisão do diff e validações negativas do bundle.

## Goal

Separar definitivamente o host Debug produzido por `xcodebuild test` do candidato instalado para uso cotidiano. Produzir, validar e instalar somente um app Release assinado, sem XCTest, `*.debug.dylib`, `get-task-allow` ou entitlements de `testmanagerd`, mantendo backup recuperável e prova de atribuição ao SHA congelado.

Não notarizar/publicar, não fazer push/merge e não apagar backups. Não instalar de Derived Data `Debug`. Nenhuma etapa pode afrouxar assinatura, Hardened Runtime, gate ou rollback para “fazer passar”.

#### Expected Output

- `Scripts/validate-release-dmg.sh` (ou helper compartilhado mínimo) rejeita explicitamente artefatos/entitlements de teste: `*.debug.dylib`, `__preview.dylib`, `libXCTest*`, `get-task-allow=true`, `testmanagerd` e `coresymbolicationd` de test host.
- Correção CK-15 autorizada após diagnóstico físico: Release usa `Config/Resenha-Release.entitlements` com somente `com.apple.security.device.audio-input=true`; o validador exige exatamente esse conjunto. Não adicionar sandbox, rede ou outros entitlements; Debug conserva sua configuração anterior. Essa exceção mínima substitui, somente para captura de áudio no Release, a proibição anterior de alterar entitlements produtivos.
- Um novo `Scripts/install-local-release.sh` recebe app Release absoluto, SHA de origem e diretório de evidência; valida paths, assinatura, entitlements, hashes e cardinalidade do processo antes de alterar `/Applications/Resenha.app`.
- Instalador copia para staging, preserva a instalação atual em backup timestampado, usa traps de rollback em ERR/INT/TERM, abre o candidato, confirma exatamente um PID/caminho/hash e nunca remove backup/failed candidate automaticamente.
- Um teste shell com bundles-fixture ou funções extraídas prova rejeição dos marcadores proibidos e rollback antes/depois da troca. `zsh -n`/teste de scripts não substitui o gate XCTest.
- Evidência final identifica source SHA, app Release, hashes de executable/resources, assinatura/entitlements, comando do gate, backup, PID e resultado físico. Debug anterior é preservado no backup, não tratado como candidato aprovado.

#### Success Criteria

- [x] CK-15: bundle aprovado não contém nenhum artefato XCTest/Debug proibido e `codesign -d --entitlements` não contém `get-task-allow`/mach lookups de teste.
- [x] CK-15: assinatura profunda, Developer ID/Hardened Runtime, bundle ID, arquitetura e hashes são verificados antes e depois da instalação.
- [x] CK-15: falha injetada restaura o bundle anterior e deixa o candidato falho/backup recuperáveis; nenhum target amplo ou path não resolvido é removido.
- [ ] CK-10/CK-12/CK-14: gate completo da Phase 5 passa via `mac-gate`; prova física usa o Release exato para HUD oculto/pass-through, cancelamento seguro e fluxo básico de ditado.
- [x] Documentação distingue test host, candidato Release, instalação e observação física; nenhum item não executado é marcado como PASS.

#### Correção da revisão de Phase 5, iteração 2 — 21/10/2026

Lapidação visual posterior, **Release 2026102106**: teste humano do 2026102105 identificou fade prematuro; timing, escala e sombras dos glyphs foram refinados sem moldura nem novo timer. Focais **2/2 PASS** e canônico via `mac-gate` **99 passed, 0 failed, 0 skipped** (`Test-WhisperKey-2026.10.21_14-11-44--0300.xcresult`). Release validado/instalado, PID inicial **16049**, executável `0795bc33ab7c1b001e4a8bb6178dbe554863653c9a5c8382430a53f27b9b3ceb`, diff produtivo selado `9d246c6614609c5b39c586f3a7711bf08aff5e00abfc6090b37097a91f654400`, entitlement exato audio-input=true e backup recuperável `Resenha-20261021T172038Z-4b04c7c27dd9.sD52VluK/previous-Resenha.app`. O usuário aprovou fisicamente aparência/timing; demais provas físicas continuam explicitamente separadas.

Primeira tentativa de instalar o Release 2026102107 do commit final encontrou `LaunchServices -600` na reabertura; rollback restaurou e reabriu o 2026102106, preservando backup/candidato/staging. O instalador agora trata essa recusa transitória com até três tentativas limitadas, sem afrouxar cardinalidade, path ou hash. A regressão primeira-falha/segunda-abertura e todos os casos negativos/rollback passaram via `mac-gate`; nova instalação depende de commit e rebuild do fix.

Consolidação glyph-only do passo 07, **Release 2026102105**: focais **4/4 + 2/2 PASS**, canônico completo via `mac-gate` **99 passed, 0 failed, 0 skipped** (`Test-WhisperKey-2026.10.21_13-56-09--0300.xcresult`) e shell negativo/rollback PASS. Base HEAD `4b04c7c27dd922b453b0b7c794b40adc377ff7ab` + diff produtivo `2c4fddb21c505b441073eb093a203d644fdc79cc7cce9d6d4d12f9981152d870` (incluindo Tests `945bc9d1c82a003a7f7b515079cad9f11ba3298467ffeb408341f0cae8adae28`), iguais antes/depois. Build/export/DMG e instalado validados, exatamente audio-input=true e denylist mantida. PID **76605**, executável `453a7aadea4830ea226908024888aca92a73df0d27155aaf48031c2db109a5d7`, backup recuperável `Resenha-20261021T170254Z-4b04c7c27dd9.MRJTRwju/previous-Resenha.app`, assinatura/hash verificados; anteriores preservados. Metadados em `build/direct-glyphs-final-20261021/evidence` e comandos/resultados completos no registro 2026102105 de `docs/testing/UI-REFINEMENT-EVIDENCE.md`. Nenhuma lógica adicional, input global, TCC, commit/push ou publicação alterados/acionados pelo executor. Aparência humana e demais gaps físicos deste Release continuam pendentes; quarto critério permanece desmarcado.

Integração final do passo 07 + entitlement, **13:23–13:29 BRT**: bloqueio de `loginwindow` resolvido no focal **2/2 PASS** (`Test-WhisperKey-2026.10.21_13-23-51--0300.xcresult`). Sem lógica adicional, shell via `mac-gate` PASS e canônico completo **98 passed, 0 failed, 0 skipped** (`Test-WhisperKey-2026.10.21_13-26-45--0300.xcresult`). Fonte HEAD `4b04c7c27dd922b453b0b7c794b40adc377ff7ab` + diff produtivo `a97d0203163ae1a436442e5a3663f84740c37a4407202b94d761f0cb6b7c6556` (incluindo Tests `f53235fac2ac98a36bfa8aeb607a7fe8e847a5508d8c723b1ca7169e2f74a9c2`), congelados antes/depois. Release **2026102104** com overlays top-level e exatamente audio-input=true validado/instalado, PID **98747**, executável `407f885aa89220622748a7d536a4f364f0bafa3858b649901f971d21ad16ca46`. Backup recuperável novo `Resenha-20261021T162806Z-4b04c7c27dd9.Q9U6OGxv/previous-Resenha.app`, assinatura/hash verificados e backups anteriores preservados. UI confirma três permissões Ativadas/Pronto, sem grant automatizado. A fala e o clique no Release final ainda estão pendentes; não marcar o quarto critério como PASS. Comandos/logs/hashes em `docs/testing/UI-REFINEMENT-EVIDENCE.md`, registro integrado mais recente; não houve commit/push.

Correção física posterior CK-15, 11:05–11:16 BRT: `tccd` comprovou que Hardened Runtime negava Microfone por ausência de `com.apple.security.device.audio-input`. Entitlement Release mínimo separado/configuração/allowlist/regressão corrigidos; sem mudança em Swift ou TCC. Shell PASS e canônico via `mac-gate` **97 passed, 0 failed, 0 skipped**, xcresult `Test-WhisperKey-2026.10.21_11-13-33--0300.xcresult`; primeiro lançamento do runner falhou antes de executar testes e está documentado, sem esconder o erro. Nova base `4b04c7c27dd922b453b0b7c794b40adc377ff7ab` + diff produtivo `c557a3e7526cfd108a6f272526abe9c231591f634aa7930ea5761e264975965c`, congelados antes/depois. Release **2026102103** validado e instalado, PID **89636**, executável `5c84fdfea1efdc88a5f016b84728cbaab9a2a011ba6afda666fb75e8682fd35f`. Backup novo `Resenha-20261021T141500Z-4b04c7c27dd9.50sG2pcQ/previous-Resenha.app` verificado; anteriores preservados. Após apresentar o pedido sem concedê-lo por automação, CUA confirmou as três permissões **Ativadas / Pronto para usar**. Não houve ditado/smoke; entrada padrão observada como AirPods e não modificada. O quarto critério permanece desmarcado. Detalhes completos, hashes/logs e limites no registro CK-15 mais recente de `docs/testing/UI-REFINEMENT-EVIDENCE.md`; os dados abaixo são históricos.

- Fontes congeladas revisadas: base `0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377` + diff Sources/Config/projeto `b88ef1723ae82bdc684efabbe2e83d52ff3367a539b1affff9d0f58fe1f7a16c`. Hash incluindo Sources/Tests/Config/projeto: `f9f35f6ea7278bdd2b80fcb5aadd82c8609e509f9d43971964537b14389d545e`, idêntico antes/depois. Nenhum runtime, XCTest ou spec funcional foi alterado nesta correção.
- Gate canônico completo repetido via `mac-gate`: **97 testes, 0 falhas, 0 skips**, `build/Logs/Test/Test-WhisperKey-2026.10.21_09-56-43--0300.xcresult`; log `/tmp/resenha-phase5-review2-native-20261021.log`. Inclui o novo teste real de CK-14. O resultado de 96 testes abaixo é histórico e não é usado como gate desta revisão.
- Novo archive/export Release **1.0.0 (2026102102)** e DMG assinados/validados em `build/direct-phase5-review2-20261021`, depois desse gate. Proveniência selada contém exatamente o diff `b88ef172…`. Instalação validada antes/depois, manifesto igual ao export; PID **51151**, executável SHA-256 `9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15`.
- Novo backup: `/Applications/Resenha-backups/Resenha-20261021T125818Z-0cf73d5834c8.wK40De9o/previous-Resenha.app`, contendo o Release 2026102101 (hash `23f2b1a3…`, fingerprint `a20b488c…`), assinatura íntegra. O backup Debug anterior `Resenha-20261021T124306Z-0cf73d5834c8.Wvn5LToR` também foi preservado e verificado. Logs `/tmp/resenha-phase5-review2-release-20261021.log` e `/tmp/resenha-phase5-review2-install-20261021.log`; manifestos/entitlements/hashes em `build/direct-phase5-review2-20261021/evidence`.
- Pendência permanece explícita: status real do novo Release `Resenha — Permissões necessárias`; nenhum grant/reset/bypass TCC ou smoke físico foi tentado nesta correção. O quarto Success Criterion continua desmarcado por essa parcela física, apesar do gate completo verde. Sem commit/push/notarização/publicação.

#### Evidência da entrega inicial — 21/10/2026 (histórica; candidata anterior)

- Gate canônico via `mac-gate`: 96 testes, 0 falhas, 0 skips; `build/Logs/Test/Test-WhisperKey-2026.10.21_09-40-35--0300.xcresult`. O primeiro gate encontrou duas assertions no mesmo teste de collectionBehavior; owner 07 corrigiu a ordem após addChildWindow, preservando a assertion, e o gate integral passou novamente.
- Shell gate via `mac-gate zsh Scripts/release-install.test.sh`: PASS; fixtures preservadas em `/private/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/resenha-install-test.L2xRu8c1`. Assinatura/processos são seams de fixture; copying/hash/swap/rollback reais. O Debug real também é rejeitado. Nenhum teste escreveu em `/Applications`.
- Release 1.0.0 (2026102101), archive/export/DMG assinados em `build/direct-phase5-20261021`; fonte `0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377` + hash do diff Sources/Config/projeto `5d43ee570b99824c938092d1598ea18ecb063afb3c1e83b8fba7320716b38fce`, ambos selados no bundle. Sem notarização/publicação/commit/push.
- Instalado em `/Applications/Resenha.app`, PID 25162, executável SHA-256 `23f2b1a3ab40485997b28358febca0efe45509d0992e8da885a83d8a8d793b66`. Manifestos export/instalado idênticos. Backup recuperável em `/Applications/Resenha-backups/Resenha-20261021T124306Z-0cf73d5834c8.Wvn5LToR/previous-Resenha.app`, assinatura profunda íntegra e fingerprint original verificado.
- Pendência concreta do quarto critério: UI real do Release mostra Microfone, Monitoramento de Entrada e Acessibilidade pendentes. Nenhum grant/reset TCC foi feito. Modelo local pronto. Com zero janelas visíveis após fechar onboarding, seis amostras de CPU ficaram em 0,0%, com acumulado 0:00.93 → 0:00.94; esse intervalo limitado não prova pass-through/ditado/cancelamento. Esses testes físicos permanecem NOT RUN até autorização manual das permissões. Detalhes, logs e rollback em `docs/testing/UI-REFINEMENT-EVIDENCE.md`.

#### Subtasks

1. Extrair/estender validação de bundle usada por `build-release-dmg.sh` e `validate-release-dmg.sh`. Falhar com mensagens específicas para cada artefato/entitlement proibido e confirmar o conjunto permitido do Release.
2. Criar `Scripts/install-local-release.sh` com três argumentos explícitos, paths absolutos/resolvidos, staging por `mktemp`, backup versionado, encerramento gracioso somente do executable exato e rollback por trap. Proibir globs destrutivos, `~`, `$HOME` como target e deleção automática.
3. Criar teste shell determinístico para validador/installer: bundle Release mínimo válido, fixtures com cada marcador proibido, hash divergente, múltiplos PIDs e falha após mover original. Teste não toca `/Applications`; operações reais exigem argumento/ambiente separado.
4. Depois de 07–09 estabilizados, rodar o gate canônico pelo `mac-gate`. Em seguida gerar archive/export `Release` pelo script existente, validar app/DMG e congelar hashes/SHA. Não usar o app Debug do resultado do teste.
5. Instalar somente o Release validado, preservar backup e registrar prova em `docs/testing/UI-REFINEMENT-EVIDENCE.md` e specs aplicáveis. Fazer smoke físico curto, sem transcrição pessoal, e registrar honestamente qualquer caso não executado. Não notarizar, publicar, pushar ou integrar nesta etapa.

#### Blockers & Risks

| Kind | Issue | Impact | Likelihood | Resolution / mitigation |
| --- | --- | --- | --- | --- |
| Risk | Test host assinado passa `codesign --verify` e é aceito de novo | Critical | High | Allowlist/denylist estrutural de contents + entitlements, testada com o bundle Debug real como caso negativo |
| Risk | Instalador perde app atual se falhar no meio | Critical | Medium | Stage completo, move atômico, trap rollback e backup nunca apagado; falha injetada antes/depois da troca |
| Risk | Evidência aponta SHA diferente do binário executado | High | Medium | Hash fonte/stage/instalado e PID executable exato no mesmo registro; divergência bloqueia abertura/aceite |
| Risk | Script de teste toca `/Applications` | Critical | Low | Root de instalação injetável apenas em modo teste; produção exige literal `/Applications/Resenha.app` e validação explícita |
| Blocker | Certificado Developer ID/Keychain indisponível | High | Medium | Concluir código/testes do pipeline, manter instalação atual e reportar credencial exclusiva; nunca cair para Debug |
