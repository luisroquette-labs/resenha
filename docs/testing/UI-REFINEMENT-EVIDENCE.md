# Interface refinement — item 1 evidence

## Phase 5 — contraste e timing dos glyphs, Release 2026102106, 21/10/2026

O teste humano do Release 2026102105 mostrou os emojis quase transparentes durante a maior parte da oferta. A causa era a opacidade linear `1 - elapsed/4`: o estado intermediário já chegava a 0,75 em 1 s e 0,5 em 2 s. O refinamento mantém 👍/👎 sem moldura, aumenta o desenho de 26 para 30 pt, usa sombra curta para separação em fundos claros/escuros, mantém opacidade 1 durante os primeiros 3,25 s e concentra o fade nos 0,75 s finais. A subida total passa de 16 para 20 pt; Reduce Motion continua sem deslocamento e preserva o timeout.

Regressões focais: **2 passed, 0 failed** em `Test-WhisperKey-2026.10.21_14-11-22--0300.xcresult`; a primeira execução detectou somente bounds de fixture ainda dimensionados para o glyph antigo, corrigidos para o target 44 pt e repetidos sem falhas. Capturas 0/2/4 s em `/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/ResenhaTests/feedback-glyphs` confirmam por inspeção emoji sólido em 0 e 2 s, ausência de cartão/borda e zero pintura em 4 s. Gate canônico completo via `mac-gate`: **99 passed, 0 failed, 0 skipped**, `Test-WhisperKey-2026.10.21_14-11-44--0300.xcresult`; log `/tmp/resenha-feedback-polish-full-20261021.log`.

Release **1.0.0 (2026102106)** gerado em `build/direct-glyphs-polish-20261021`, validado e instalado. Fonte selada: HEAD `4b04c7c27dd922b453b0b7c794b40adc377ff7ab`, diff produtivo `9d246c6614609c5b39c586f3a7711bf08aff5e00abfc6090b37097a91f654400`. Executável instalado SHA-256 `0795bc33ab7c1b001e4a8bb6178dbe554863653c9a5c8382430a53f27b9b3ceb`, PID inicial `16049`, caminho `/Applications/Resenha.app/Contents/MacOS/Resenha`; entitlement exato `com.apple.security.device.audio-input=true`. Backup recuperável: `/Applications/Resenha-backups/Resenha-20261021T172038Z-4b04c7c27dd9.sD52VluK/previous-Resenha.app`. Evidência e manifestos em `build/direct-glyphs-polish-20261021/evidence`; logs `/tmp/resenha-feedback-polish-{focused-retry,full,release,install}-20261021.log`. Sem notarização/publicação/push.

Aceite humano posterior no Release 2026102106: o usuário ditou **“Teste visual local.”**, observou a oferta e respondeu **“ficou ótimo”**. Isso aprova a aparência/timing dos glyphs nesta versão; não é usado como evidência de VoiceOver, Reduce Motion do sistema, rede ou todos os demais casos físicos.

Após o commit `ea96e5385b4956e358e9970e35d836760b44322f`, o primeiro install do Release 2026102107 encontrou `LaunchServices -600` ao reabrir o bundle recém-trocado. O rollback transacional restaurou e reabriu integralmente o Release 2026102106; candidato falho, backup e staging foram preservados em `/Applications/Resenha-backups/Resenha-20261021T173659Z-ea96e5385b49.LDhnGXWv` e `/Applications/.resenha-stage.wxZa2FvS`. A causa operacional era uma recusa transitória de `open -n` após substituir um app que acabara de encerrar. `start_installed_app` agora faz no máximo três tentativas, aceita processo já iniciado apesar de retorno incerto e continua validando cardinalidade/caminho. Regressão de primeira recusa/segunda abertura e suíte shell completa passaram via `mac-gate`; log `/tmp/resenha-feedback-launchservices-retry-shell-20261021.log`. Uma nova instalação só ocorre após commit/build desse fix.

## Phase 5 — glyphs soltos no Release 2026102105, 21/10/2026

**Refinamento integrado, gate completo verde e novo Release instalado; aparência humana ainda pendente.** Os seis focais do passo 07 foram conferidos por xcresulttool: **4 passed, 0 failed, 0 skipped** em `Test-WhisperKey-2026.10.21_13-52-06--0300.xcresult` e **2 passed, 0 failed, 0 skipped** em `Test-WhisperKey-2026.10.21_13-53-21--0300.xcresult`. O código já validado exibe somente os glyphs 👍/👎, sem cartão/material/borda de feedback nem círculos, com subida total de **16 px** e fade linear durante **4 s**; Reduce Motion conserva posição. Targets top-level `44×44`, timer/token e o entitlement mínimo permanecem. O executor do passo 10 não alterou lógica adicional.

Freeze: HEAD **`4b04c7c27dd922b453b0b7c794b40adc377ff7ab`** + `git diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj` SHA-256 **`2c4fddb21c505b441073eb093a203d644fdc79cc7cce9d6d4d12f9981152d870`**; incluindo `Tests`, **`945bc9d1c82a003a7f7b515079cad9f11ba3298467ffeb408341f0cae8adae28`**. Ambos iguais antes/depois dos gates/build/install; diffs locais anteriores preservados.

Gates: **`~/.local/bin/mac-gate zsh Scripts/release-install.test.sh` PASS**, log `/tmp/resenha-glyph-final-shell-20261021.log`, fixtures em `/private/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/resenha-install-test.ULljZTLG`; **`~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` → 99 passed, 0 failed, 0 skipped**, confirmado em `build/Logs/Test/Test-WhisperKey-2026.10.21_13-56-09--0300.xcresult`. Log `/tmp/resenha-glyph-final-native-20261021.log`. Somente Resenha instalado foi encerrado graciosamente (PID 53705), com trap de reabertura depois (PID 58786). A espera posterior pelo archive respeitou a fila `mac-gate`, sem bypass.

`RESENHA_OUTPUT_DIR=<worktree>/build/direct-glyphs-final-20261021 RESENHA_BUILD_NUMBER=2026102105 ~/.local/bin/mac-gate zsh Scripts/build-release-dmg.sh` produziu archive/export/DMG **Release 1.0.0 (2026102105)** separados; log `/tmp/resenha-glyph-final-release-20261021.log`. App/DMG validados antes de trocar a instalação. Proveniência selada contém a base e diff produtivo acima. Instalador: `zsh Scripts/install-local-release.sh <worktree>/build/direct-glyphs-final-20261021/export/Resenha.app 4b04c7c27dd922b453b0b7c794b40adc377ff7ab <worktree>/build/direct-glyphs-final-20261021/evidence`, log `/tmp/resenha-glyph-final-install-20261021.log`.

Validação antes/no stage/depois: assinatura profunda, Developer ID/team S3YCFYY8SC, Hardened Runtime, arm64/macOS 14, bundle `br.com.luisroquette.Resenha`, manifestos export/instalado idênticos. `codesign -d --entitlements` no instalado contém **exatamente `com.apple.security.device.audio-input=true`**, nenhuma outra chave. Denylist continua rejeitando XCTest/XCT/XCUI/Testing, `*.debug.dylib`, `__preview.dylib`, get-task-allow, testmanagerd e coresymbolicationd; sandbox/rede/qualquer entitlement extra também são rejeitados e o shell repetido comprovou os negativos.

| Artefato atual | SHA-256 |
|---|---|
| Executável exportado/instalado | `453a7aadea4830ea226908024888aca92a73df0d27155aaf48031c2db109a5d7` |
| Assets.car | `9327d3d789b6af3c04177ab2875a5de8da443f6738dc7699b084720ad002ec80` |
| CodeResources | `fe154bc1294a6d9196669c4238c63ecb9fd3003f08f99af0ac84fa74fdd03b46` |
| DMG | `5443b4d62e5cfb409683e9a92a8b94c0fa345a1e5e7ea9722d8d5f399ca90806` |
| Fingerprint agregado export/instalado | `fa7663bc607b06422a2dfc0232c98bb64e021c9696eb3fafe1c77cc79b272f30` |

Instalado às **14:02–14:03 BRT**, PID **76605**, caminho **`/Applications/Resenha.app/Contents/MacOS/Resenha`**, status real **Resenha — Pronto**. Backup recuperável novo **`/Applications/Resenha-backups/Resenha-20261021T170254Z-4b04c7c27dd9.MRJTRwju/previous-Resenha.app`**, contendo Release 2026102104, executável `407f885aa89220622748a7d536a4f364f0bafa3858b649901f971d21ad16ca46` e fingerprint `489e0a038693048056f7cb34261de6be2b33f7e4648f101a6590119399b0bad0`, coincidentes com inventário anterior. Assinatura profunda do backup novamente verificada; anteriores preservados. Staging `/Applications/.resenha-stage.EirlPK3n`; metadados/manifestos/hashes em `build/direct-glyphs-final-20261021/evidence`. Rollback segue coberto pelo shell; não foi acionado na instalação real.

A entrada global foi apenas lida: **AirPods/Bluetooth**, sem alteração. Nenhuma captura/fala foi executada pelo agente e nenhum resultado visual humano do build 2026102105 é afirmado. O teste visual físico, teclado/VoiceOver e outros gaps não executados continuam pendentes; o critério combinado físico do passo 10 continua desmarcado. Chrome/Terminal/sessões preservados, sem commit/push/notarização/publicação/chamada paga. `git diff --check` passou.

Preparação humana: novo documento descartável vazio **Sem Título** no Editor de Texto, foco confirmado por CUA em **First Text View**. Hash do clipboard completo antes/depois da preparação **`5961c19c7bb8032dcab0add971b51611f7379c4bd3e5ed21f1b5fb4861aab8fe`**, conteúdo não registrado e nenhum sentinel escrito. O teste mínimo pendente é uma fala curta e observar os dois glyphs soltos subirem/desvanecerem durante os 4 segundos, sem clicar para interromper a oferta. Essa observação ainda não ocorreu.

## Phase 5 — Release integrado com overlays top-level, 21/10/2026, 13:23–13:29 BRT

**Gates e instalação resolvidos; teste humano do Release final ainda pendente.** O bloqueio do teste WindowServer por `loginwindow` foi encerrado: o focal `build/Logs/Test/Test-WhisperKey-2026.10.21_13-23-51--0300.xcresult` contém **2 passed, 0 failed, 0 skipped**, confirmado por xcresulttool. O fix do passo 07 mantém somente os dois alvos `44×44` como janelas top-level não ativadoras, com fundo alpha `0.01` para hit-test, sem vínculo child/parent. A integração operacional não acrescentou lógica: reuniu esse diff já verde com o entitlement Release mínimo `audio-input=true` do passo 10.

Fonte congelada: HEAD **`4b04c7c27dd922b453b0b7c794b40adc377ff7ab`**, hash de `git diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj` **`a97d0203163ae1a436442e5a3663f84740c37a4407202b94d761f0cb6b7c6556`**; incluindo `Tests`, **`f53235fac2ac98a36bfa8aeb607a7fe8e847a5508d8c723b1ca7169e2f74a9c2`**. Ambos foram conferidos antes/depois de gate/build/install. Nenhum código adicional foi alterado pelo executor do passo 10.

Gates repetidos no diff integrado: **`~/.local/bin/mac-gate zsh Scripts/release-install.test.sh` PASS**, log `/tmp/resenha-final-overlay-shell-20261021.log`, fixtures preservadas em `/private/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/resenha-install-test.DfGn6Lof`; **`~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` → 98 passed, 0 failed, 0 skipped**, confirmado em `build/Logs/Test/Test-WhisperKey-2026.10.21_13-26-45--0300.xcresult`. Log `/tmp/resenha-final-overlay-native-20261021.log`. Somente o instalado PID 95088 foi encerrado graciosamente para o gate; trap o reabriu depois (PID 97922). Chrome/Terminal/sessões foram preservados.

Após os gates: `RESENHA_OUTPUT_DIR=<worktree>/build/direct-final-overlays-20261021 RESENHA_BUILD_NUMBER=2026102104 ~/.local/bin/mac-gate zsh Scripts/build-release-dmg.sh` gerou archive/export/DMG **Release 1.0.0 (2026102104)**, log `/tmp/resenha-final-overlay-release-20261021.log`. App e DMG passaram validação; proveniência selada contém a base e o diff produtivo acima. Instalado com `zsh Scripts/install-local-release.sh <worktree>/build/direct-final-overlays-20261021/export/Resenha.app 4b04c7c27dd922b453b0b7c794b40adc377ff7ab <worktree>/build/direct-final-overlays-20261021/evidence`, log `/tmp/resenha-final-overlay-install-20261021.log`. Manifestos export/stage/instalado conferem. Developer ID/team S3YCFYY8SC, Hardened Runtime, bundle `br.com.luisroquette.Resenha`, arm64/macOS 14, assinatura profunda válida e exatamente **audio-input=true**, sem sandbox/rede/get-task-allow/XCTest/Debug/testmanagerd/coresymbolicationd.

| Artefato atual | SHA-256 |
|---|---|
| Executável exportado/instalado | `407f885aa89220622748a7d536a4f364f0bafa3858b649901f971d21ad16ca46` |
| Assets.car | `9327d3d789b6af3c04177ab2875a5de8da443f6738dc7699b084720ad002ec80` |
| CodeResources | `7130696057f89f9235d0125e84071d9b1b845e455a437b49091e36ae065d2e98` |
| DMG | `22242545997a575ab13a956cc22053897fb5b9a7176b490939a545e8ea974860` |
| Fingerprint agregado export/instalado | `489e0a038693048056f7cb34261de6be2b33f7e4648f101a6590119399b0bad0` |

PID final **98747**, caminho **`/Applications/Resenha.app/Contents/MacOS/Resenha`**. Novo backup **`/Applications/Resenha-backups/Resenha-20261021T162806Z-4b04c7c27dd9.Q9U6OGxv/previous-Resenha.app`**, contendo Release 2026102103: executável `5c84fdfea1efdc88a5f016b84728cbaab9a2a011ba6afda666fb75e8682fd35f`, fingerprint anterior `3ba714fb2249edb739c8197c9247791fea4b28a20db4c6b03bc2352509838e48`, assinatura profunda verificada. Staging preservado `/Applications/.resenha-stage.e6Mxi2Cc`; todos os backups anteriores permanecem. Manifestos/assinatura/entitlements/hashes persistidos em `build/direct-final-overlays-20261021/evidence`. O rollback transacional continua coberto pelo shell repetido; não foi necessário recuperar a instalação real.

UI real: menu **Resenha — Pronto**, hotkey **Option direita**; CUA confirmou **Microfone Ativada**, **Monitoramento de Entrada Ativada**, **Acessibilidade Ativada**, modelo **Pronto** e **Pronto para usar**, sem nova concessão de permissão. **Começar a usar** foi acionado para fechar onboarding. A entrada padrão continua **AirPods**, sem alteração global pelo executor. A antiga falha CoreAudio 35 e o relato de clique sem editor pertencem ao build 2026102103; não são resultado de uma fala neste candidato novo. Fala, clique 👎, editor e demais checks humanos do Release 2026102104 ainda não foram executados; o critério combinado físico do passo 10 continua desmarcado. Sem commit/push/notarização/publicação/chamada paga; `git diff --check` passou.

Preparação para a fala humana: criado documento descartável vazio **Sem Título** no Editor de Texto, CUA confirmou foco em **First Text View**. Clipboard completo (tipos/dados dos itens) manteve antes/depois da preparação o hash **`256fd450198ee5050a067b12b0ab48558647541e5d9cbe377214e2ec34a2846f`**, sem conteúdo registrado nem sentinel escrito. Isso não antecipa invariância durante o futuro ditado. Próximo teste mínimo: focar esse documento, segurar Option direita, dizer a frase local de teste, soltar e clicar 👎 dentro da janela de 4 segundos; não salvar regra. Ainda não executado.

## Phase 5 — smoke humano inconclusivo e diagnóstico read-only, 21/10/2026, 11:29–11:33 BRT

**Inserção no TextEdit e abertura do editor não foram demonstradas.** O usuário forneceu na conversa a frase de teste “Este é um teste local do Resenha.” e relatou que clicou em 👎 sem abrir o editor. Às **11:30:28**, leitura sem editar conteúdo encontrou o documento descartável **Sem Título vazio (0 caracteres)**, sem a frase, e **zero janelas de Resenha**. PID **89636**, caminho instalado e SHA-256 **`5c84fdfea1efdc88a5f016b84728cbaab9a2a011ba6afda666fb75e8682fd35f`** permaneceram corretos naquele instante. A frase presente na conversa não prova transcrição/inserção pelo app: não foi observado se foi ditada ou digitada ali. O foreground lido como **Terminal após a invocação do executor** não comprova qual app tinha foco durante a fala; portanto não se atribui a falha ao usuário nem ao roteamento sem evidência adicional. A área de texto do TextEdit continuava sendo seu elemento AX focado, mas isso também não demonstra foco global no momento da captura.

O hash dos itens/tipos/dados do clipboard às 11:30:28 era **`a71ed0fe11dde6f28099356de8ceb324b63e7eb32319b9b4b7d166c297f07311`**, diferente da baseline de preparação **`63c84e83ff654dc5aabff033bc7922952bf84b79ff86b2aac7db2670b561370f`**. Não houve inspeção/persistência do conteúdo nem restauração: a origem dessa mudança não está comprovada e poderia ser uma ação externa legítima. **Invariância de clipboard não passou.**

Unified logs do próprio PID registraram pressão/liberação de hotkey em **11:29:48.429698 → 11:29:51.776347** e outra em **11:30:44.802551 → 11:30:58.926029**; o agente não pediu nova fala/pressão. Nos dois intervalos o CoreAudio registrou **`HALC_ProxyIOContext::_StartIO(): Start failed - StartAndWaitForState returned error 35`**, seguido de I/O de entrada abandonado por reconfiguração pendente e **`AQME Default-Input: client stopping after failed start`**, running count 0. Isso comprova falhas de início do I/O de captura nesses momentos, mas não identifica por si só a origem da reconfiguração ou uma correção de dispositivo. Identificadores de hardware foram omitidos da evidência. Não é a antiga negação por entitlement.

Não existem eventos próprios emitidos por esse código para clique de feedback, token oferecido, `openCorrection` ou expiração; a inspeção read-only do fonte confirmou esse limite. As menções genéricas a token/timeout nos logs de frameworks não foram tratadas como feedback. Logo, **não há prova de que o clique chegou ao handler, de que expirou aos 4 segundos ou de um erro do editor**. Nenhum desses resultados pode ser inferido apenas de a janela estar ausente. O relato humano é preservado como relato, sem inventar um evento observado.

Às **11:31:40.575262**, `runningboardd` registrou para o **PID principal 89636** **`termination reported by launchd (0, 0, 0)`**, depois removeu processo/job. O app estava ausente no `pgrep` às 11:31:51. Isso é término com status zero, não prova de crash; o iniciador não foi estabelecido. O helper ThemeWidget PID 90600 recebeu `(2, 9, 9)` depois, o que não é o status do app principal. Busca recursiva por arquivos Resenha/WhisperKey em `~/Library/Logs/DiagnosticReports` e `/Library/Logs/DiagnosticReports` não encontrou crash/spindump/termination report para o evento. O agente não encerrou nem reabriu o app durante essa coleta.

Extrato sanitizado: `build/direct-audio-input-20261021/evidence/smoke-readonly-summary.md`. Nenhum código, TCC, preferência global, conteúdo de documento ou clipboard foi modificado; nenhuma nova fala foi solicitada. `git diff --check` passou. O smoke continua **não aprovado**, e a task permanece aberta.

## Phase 5 / CK-15 — Audio Input no Release, 21/10/2026, 11:05–11:16 BRT

**Causa confirmada e corrigida; as três permissões agora são reconhecidas. Não é prova física de ditado.** O Release anterior usava Hardened Runtime com entitlements `{}` e continha `NSMicrophoneUsageDescription`. O log de `tccd` às 11:04:07 e 11:04:45 atribuiu explicitamente a negação de Microfone ao entitlement ausente `com.apple.security.device.audio-input`, para PID 65343 em `/Applications/Resenha.app/Contents/MacOS/Resenha`. Não foi inferida falha do usuário ou da concessão de Entrada. Log filtrado do bundle e entitlements anteriores preservados em `build/direct-audio-input-20261021/evidence/microphone-denial-before.log` e `installed-entitlements-before.plist`.

Correção mínima: `Config/Resenha-Release.entitlements` contém somente **`com.apple.security.device.audio-input=true`**, exigido pelo [Hardened Runtime da Apple](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input). `project.yml` e o projeto gerado apontam somente Release para esse arquivo; Debug e seu arquivo anterior não mudaram. O validador aceita exatamente esse dicionário e rejeita ausente/falso/string/integer, qualquer chave extra, sandbox/rede/debug e os artefatos XCTest/testmanagerd existentes. Shell regressions incluem o arquivo produtivo real. Nenhum Swift, teste XCTest, provider ou preferência TCC foi alterado nesta correção.

Fonte congelada: HEAD **`4b04c7c27dd922b453b0b7c794b40adc377ff7ab`** + `git diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj` SHA-256 **`c557a3e7526cfd108a6f272526abe9c231591f634aa7930ea5761e264975965c`**, igual antes/depois de gate/build/install; incluir `Tests` produz o mesmo hash. O arquivo novo foi marcado somente intent-to-add para integrar o diff e a proveniência, sem commit. Essa base já contém o código congelado da fase; o delta produtivo é apenas signing/configuração.

Gates: `~/.local/bin/mac-gate zsh Scripts/release-install.test.sh` **PASS**, log `/tmp/resenha-audio-input-shell-20261021.log`, fixtures recuperáveis em `/private/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/resenha-install-test.l1hSFZ36`. O primeiro canônico não iniciou o runner (LaunchServices/IDELaunchErrorDomain 20), sem testes executados; log `/tmp/resenha-audio-input-native-20261021.log`, xcresult `Test-WhisperKey-2026.10.21_11-10-03--0300.xcresult`. Após encerrar graciosamente somente o instalado, o mesmo comando **`~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`** passou: **97 passed, 0 failed, 0 skipped**, confirmado por xcresulttool em `build/Logs/Test/Test-WhisperKey-2026.10.21_11-13-33--0300.xcresult`; log `/tmp/resenha-audio-input-native-retry-20261021.log`. O finally reabriu o instalado anterior (PID 86330). Não foi alterado teste, cache ou TCC para esse retry; o motivo interno da recusa inicial do LaunchServices não foi demonstrado.

Depois dos gates, `RESENHA_OUTPUT_DIR=<worktree>/build/direct-audio-input-20261021 RESENHA_BUILD_NUMBER=2026102103 ~/.local/bin/mac-gate zsh Scripts/build-release-dmg.sh` produziu archive/export/DMG **Release 1.0.0 (2026102103)**. Log `/tmp/resenha-audio-input-release-20261021.log`; app e DMG passaram a validação. Proveniência selada contém a base/diff acima. Instalador: `zsh Scripts/install-local-release.sh <worktree>/build/direct-audio-input-20261021/export/Resenha.app 4b04c7c27dd922b453b0b7c794b40adc377ff7ab <worktree>/build/direct-audio-input-20261021/evidence`, log `/tmp/resenha-audio-input-install-20261021.log`. Manifestos export/instalado iguais, assinatura profunda válida, Developer ID/team S3YCFYY8SC, Hardened Runtime, arm64/macOS 14, bundle `br.com.luisroquette.Resenha`, sem XCTest/Debug/get-task-allow/testmanagerd/coresymbolicationd. Entitlements assinados contêm **somente audio-input=true**.

| Artefato atual | SHA-256 |
|---|---|
| Executável exportado/instalado | `5c84fdfea1efdc88a5f016b84728cbaab9a2a011ba6afda666fb75e8682fd35f` |
| Assets.car | `9327d3d789b6af3c04177ab2875a5de8da443f6738dc7699b084720ad002ec80` |
| CodeResources | `20104d9bd44cf413669225a01a2487d28542ef4f62aa6247fcd229ec2006e06f` |
| DMG | `0f161c8144c51b16646f0e031f1c045f869248a2d35def848d2d49e4c8c48292` |
| Fingerprint agregado export/instalado | `3ba714fb2249edb739c8197c9247791fea4b28a20db4c6b03bc2352509838e48` |

Instalado e executando: PID **89636**, exatamente `/Applications/Resenha.app/Contents/MacOS/Resenha`. Novo backup recuperável: `/Applications/Resenha-backups/Resenha-20261021T141500Z-4b04c7c27dd9.50sG2pcQ/previous-Resenha.app`, contendo o Release 2026102102, executável `9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15`, fingerprint `e07318353b39794f9682087f2c58ba23737bd6df956664d5c7d7b4ba2f9276c9`, coincidente com o inventário anterior e assinatura profunda novamente verificada. Os backups anteriores não foram removidos. Staging preservado `/Applications/.resenha-stage.OxQKIQ5S`; manifestos, assinatura, entitlements e hashes em `build/direct-audio-input-20261021/evidence`. Rollback automático continua coberto pelas falhas injetadas antes/depois da troca; recuperar manualmente exige copiar esse backup para staging validado e preservar o novo candidato antes da substituição, nunca apagar o backup.

Observação real às 11:15 BRT: inicialmente Entrada/Acessibilidade estavam **Ativadas** e Microfone pendente. Ao acionar **Ativar permissões** apenas para apresentar o pedido, o app exibiu **Solicitando…**; `tccd` registrou **AUTHREQ_PROMPTING** para PID 89636 em vez de negação por entitlement. Nenhum botão **Permitir** foi acionado por automação. Na leitura seguinte por CUA, a janela **Configurar Resenha** mostrou **Microfone 01 Ativada**, **Monitoramento de Entrada 02 Ativada**, **Acessibilidade 03 Ativada**, **Pronto para usar** e **Começar a usar**. A ação que concluiu a solicitação não foi observada; não se atribui ator ou mecanismo de concessão neste registro. Log filtrado posterior em `microphone-request-after.log`.

Limites: não houve captura, ditado, halo/bolhas/timeout, pass-through, editor/cancelamento, foco/caret/clipboard ou VoiceOver nesta correção. A entrada padrão foi lida como **AirPods**, não o microfone embutido; não foi modificada nem se iniciou gravação. Clipboard não foi alterado; Chrome/Terminal e sessões foram preservados. O smoke completo e a revalidação da entrada embutida continuam pendentes; o quarto critério de sucesso do passo 10 permanece desmarcado. `git diff --check` passou; sem commit/push, notarização, publicação ou chamada paga.

Preparação posterior, antes da única fala humana (11:19 BRT): **Começar a usar** foi acionado, sem concessão adicional. Menu nativo confirmou **Resenha — Pronto**, **Segure Option direita para ditar** e zero janelas de Resenha. Seis amostras de CPU a cada 1 segundo foram `0,6%; 0,0%; 0,0%; 0,0%; 0,0%; 0,0%`, com tempo acumulado estável `0:01.08`; é uma janela limitada de idle, não prova universal de desempenho/pass-through. Criado somente um documento descartável vazio **Sem Título** no Editor de Texto; CUA confirmou foco na área **First Text View**. SHA-256 da serialização de todos os itens/tipos/dados presentes no clipboard, antes/depois dessa preparação, permaneceu **`63c84e83ff654dc5aabff033bc7922952bf84b79ff86b2aac7db2670b561370f`**; conteúdo não foi registrado e nenhum sentinel foi escrito. Entrada padrão continua AirPods, sem alteração. A fala e os checks dependentes dela ainda não ocorreram; task não encerrada.

## Phase 5 — permissões após concessão manual, 21/10/2026, 11:04 BRT

Após o usuário confirmar **Resenha.app ligado** e **Resenha Dev.app desligado** em Monitoração de Entrada, somente o Release instalado foi encerrado graciosamente e reaberto: PID **10719 → 65343**, executável `/Applications/Resenha.app/Contents/MacOS/Resenha`, SHA-256 **`9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15`**. Depois do reinício e de **Verificar permissões**, a janela **Configurar Resenha** foi lida por CUA: **Monitoramento de Entrada Ativada** e **Acessibilidade Ativada**, modelo local **Pronto**, mas **Microfone** ainda com **Abrir Ajustes** e **Configuração pendente**.

**Ativar permissões** foi acionado somente para apresentar o pedido ao usuário; abriu **Ajustes do Sistema > Microfone**, onde a entrada visível **Resenha.app** estava **on**. Não apareceu novo diálogo **Permitir**, e o onboarding continuou vendo Microfone pendente. Essa é uma divergência observada entre as duas interfaces, não prova de causa ou de TCC efetivamente concedido ao processo. Nenhum interruptor foi alterado por automação, nenhum reset/bypass foi executado nesta sessão e nenhuma preferência de áudio foi modificada. O Release correto permanece aberto; a tela Microfone está à frente.

O smoke físico completo permanece bloqueado pela prontidão falsa: não foram tentados hotkey/ditado, halo/bolhas/timeout, click pass-through, dislike/editor/cancelar, foco/caret/clipboard, segundo ditado ou VoiceOver nesta sessão. Sem conteúdo descartável criado, sem clipboard alterado, sem chamadas pagas, sem mudanças em código e sem commit/push. `git diff --check` passou. Próximo passo: diagnosticar a divergência de Microfone; não contar a concessão manual de Entrada como validação do ditado.

## Phase 5 — reabertura e permissões reais, 21/10/2026, 10:30–10:32 BRT

Após o usuário informar que reaplicou Monitoramento de Entrada, o guard do instalador recusou o reinício: a instância aberta era o PID **94919**, executando de `/Applications/Resenha-backups/Resenha-20261021T125818Z-0cf73d5834c8.wK40De9o/previous-Resenha.app/Contents/MacOS/Resenha`. Com autorização específica, somente essa instância foi encerrada graciosamente. O Release atual foi aberto explicitamente em `/Applications/Resenha.app`; PID **95837**, caminho `/Applications/Resenha.app/Contents/MacOS/Resenha`, executável SHA-256 **`9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15`**, novamente confirmados às 10:31 BRT.

O menu real mostrou **`Resenha — Permissões necessárias`**. A janela nativa **Configurar Resenha**, aberta pelo menu e inspecionada por CUA, mostrou **Microfone**, **Monitoramento de Entrada** e **Acessibilidade**, cada um com **Abrir Ajustes**, sem estado **Ativada**; o modelo local estava **Pronto**, com **Configuração pendente**. Isso documenta o estado reconhecido pelo Release atual, não o conteúdo da base TCC nem a causa da divergência com a reaplicação relatada pelo usuário.

Nenhum botão de concessão foi acionado; código, TCC, configuração de microfone, clipboard e outros apps não foram alterados. O Release atual permanece aberto na janela de configuração. O roteiro físico condicionado às três permissões reconhecidas não foi iniciado: hotkey/ditado, HUD/halo/bolhas/timeout, pass-through, editor/cancelamento, foco/caret/clipboard, segundo ditado e VoiceOver continuam sem nova prova nesta sessão. É necessária a concessão/revalidação das três permissões para o bundle instalado antes de repetir esse roteiro. `git diff --check` passou; sem commit/push.

## Phase 5 — candidata da revisão 2, 21/10/2026, 09:56–09:59 BRT

**Gate completo e Release instalado agora correspondem ao diff revisado `b88ef172…`. Prova física continua pendente; não foi tentada nesta correção.** Os registros anteriores de 96 testes e build 2026102101 são históricos.

Fonte congelada: base `0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377` + `git diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj` SHA-256 **`b88ef1723ae82bdc684efabbe2e83d52ff3367a539b1affff9d0f58fe1f7a16c`**. A versão incluindo Sources/Tests/Config/projeto tem hash `f9f35f6ea7278bdd2b80fcb5aadd82c8609e509f9d43971964537b14389d545e`, verificado antes do gate e após a instalação. Runtime, XCTest, scripts e specs funcionais não foram alterados durante esta correção; somente evidência foi atualizada.

Gate canônico, repetido pelo `mac-gate`: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` → **97 passed, 0 failed, 0 skipped**. Resultado `build/Logs/Test/Test-WhisperKey-2026.10.21_09-56-43--0300.xcresult`, confirmado por xcresulttool; log `/tmp/resenha-phase5-review2-native-20261021.log`. Inclui o novo teste real de CK-14. O resultado antigo de 96 casos não foi reutilizado para aprovar o diff atual.

Depois do gate, `RESENHA_OUTPUT_DIR=<worktree>/build/direct-phase5-review2-20261021 RESENHA_BUILD_NUMBER=2026102102 ~/.local/bin/mac-gate zsh Scripts/build-release-dmg.sh` gerou um archive/export **Release 1.0.0 (2026102102)** separado e um novo DMG assinado. Ambos passaram a validação compartilhada. `Contents/Resources/ResenhaBuild.plist`, selado pela assinatura, contém `Configuration=Release`, a base Git acima e **SourceDiffSHA256=b88ef172…**. Log `/tmp/resenha-phase5-review2-release-20261021.log`; sem notarização/publicação.

| Artefato atual | SHA-256 |
|---|---|
| Executável exportado/instalado `Contents/MacOS/Resenha` | `9617c803912e803a9f94279eea4ce5d90ba3680a4a212a9c3661a6d7266d6c15` |
| `Contents/Resources/Assets.car` | `9327d3d789b6af3c04177ab2875a5de8da443f6738dc7699b084720ad002ec80` |
| `Contents/_CodeSignature/CodeResources` | `639808d08153c0edb9710aea0a9b1accadde2113c8206dd63dcb4a9f90dd7437` |
| DMG em `build/direct-phase5-review2-20261021` | `2543c2feeba4cf7412816c889711a0085eee75eb43f7c2f898dc4d58007e2b4a` |
| Fingerprint agregado do bundle exportado/instalado | `e07318353b39794f9682087f2c58ba23737bd6df956664d5c7d7b4ba2f9276c9` |

Instalação: `zsh Scripts/install-local-release.sh <worktree>/build/direct-phase5-review2-20261021/export/Resenha.app 0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377 <worktree>/build/direct-phase5-review2-20261021/evidence`. Log `/tmp/resenha-phase5-review2-install-20261021.log`; único PID **51151**, executável exatamente `/Applications/Resenha.app/Contents/MacOS/Resenha`. Validações profundas antes/no stage/depois passaram: bundle ID `br.com.luisroquette.Resenha`, arm64/macOS 14, Developer ID/team S3YCFYY8SC, Hardened Runtime, entitlements **dict vazio**, sem XCTest/Testing/debug dylibs/get-task-allow/testmanagerd/coresymbolicationd. Manifestos source/installed comparados byte a byte, iguais. Staging preservado `/Applications/.resenha-stage.LTp0FYUe`; metadados, hashes, assinatura e entitlements persistidos em `build/direct-phase5-review2-20261021/evidence`.

Novo backup recuperável: `/Applications/Resenha-backups/Resenha-20261021T125818Z-0cf73d5834c8.wK40De9o/previous-Resenha.app`. Contém o Release 2026102101, executável `23f2b1a3ab40485997b28358febca0efe45509d0992e8da885a83d8a8d793b66` e fingerprint agregado `a20b488c045b6ee8c71abd6bb7d4214bec6160ca6aa1ad1835d929e5954c5154`, coincidente com o inventário anterior à troca. Assinatura profunda válida. O backup anterior de Debug em `Resenha-20261021T124306Z-0cf73d5834c8.Wvn5LToR/previous-Resenha.app` continua presente, hash `457fc29f…`, e sua assinatura também foi verificada. Nenhum backup foi apagado; os testes de rollback da entrega inicial permanecem evidência dos mesmos scripts, cujos hashes não mudaram nesta correção.

Pendência exata reobservada após instalar: menu nativo **`Resenha — Permissões necessárias`**. A entrega anterior identificou Microfone, Monitoramento de Entrada e Acessibilidade pendentes; nesta correção foi lido o status agregado, sem inferir que cada permissão individual continuou no mesmo estado. Não houve grant/reset/bypass TCC, ajuste de microfone, transcrição, clique de pass-through, cancelamento físico ou VoiceOver. Nenhum desses casos é contado como PASS. Chrome/Terminal/sessões foram preservados. `git diff --check` passou; sem commit/push.

## Phase 5 — Release endurecido instalado, 21/10/2026, 09:37–09:46 BRT

**Release instalado/validado; smoke de ditado/pass-through/cancelamento bloqueado por permissões.** Este registro substitui o uso de test host Debug como candidato cotidiano. Não afirma que as pendências físicas históricas foram encerradas.

### Fonte, gates e artefatos

Base Git `0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377` com código 07/08/09 congelado. SHA-256 de `git diff --binary HEAD -- Sources Config project.yml WhisperKey.xcodeproj`: `5d43ee570b99824c938092d1598ea18ecb063afb3c1e83b8fba7320716b38fce`. O bundle contém esses valores e `Configuration=Release` em `Contents/Resources/ResenhaBuild.plist`, selado pela assinatura. A atribuição é **base + diff**, não um claim de checkout limpo; Step 10 não fez commit/push e não alterou Sources/XCTest.

1. Gate nativo: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test` → **96 passed, 0 failures, 0 skipped**, `build/Logs/Test/Test-WhisperKey-2026.10.21_09-40-35--0300.xcresult`; log `/tmp/resenha-phase5-step10-native-gate-final-20261021.log`. Primeira execução teve duas assertions do mesmo caso em Tests.swift:1371 (collectionBehavior 321 vs 257); owner 07 moveu a atribuição da política para depois de addChildWindow, sem afrouxar a assertion. O gate integral posterior passou.
2. Shell gate: `~/.local/bin/mac-gate zsh Scripts/release-install.test.sh` → **PASS**; log `/tmp/resenha-step10-shell-tests-installed-final-20261021.log`, fixtures `/private/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/resenha-install-test.L2xRu8c1`. Fixtures exercitam rejeição de cada marcador/entitlement, SHA/hash divergentes, múltiplos PIDs, instalação e falha antes da troca/depois do backup/depois da troca. Copy/hash/move/rollback são reais no root temporário; assinatura/processo/abertura têm seams de fixture. Backup e candidatos falhos ficam preservados. O Debug real também foi rejeitado (`Contents/Frameworks/Testing.framework`).
3. Build separado: `RESENHA_OUTPUT_DIR=<worktree>/build/direct-phase5-20261021 RESENHA_BUILD_NUMBER=2026102101 ~/.local/bin/mac-gate zsh Scripts/build-release-dmg.sh` → archive/export Release e DMG assinados/validados, versão **1.0.0 (2026102101)**; log `/tmp/resenha-step10-release-build-20261021.log`. Nenhuma notarização, publicação, API paga ou integração foi executada. Site workflow cobre somente Scripts/site.mjs, Scripts/site.test.mjs e site/**, todos inalterados; não foi acionado.

| Artefato | SHA-256 |
|---|---|
| Export e instalado `Contents/MacOS/Resenha` | `23f2b1a3ab40485997b28358febca0efe45509d0992e8da885a83d8a8d793b66` |
| Export e instalado `Contents/Resources/Assets.car` | `9327d3d789b6af3c04177ab2875a5de8da443f6738dc7699b084720ad002ec80` |
| Export e instalado `Contents/_CodeSignature/CodeResources` | `3cea1192f98aae7dfd88be8d47a71856458cba5f0e0c0c8ece65620e3795b30f` |
| `Resenha-1.0.0-arm64.dmg` | `299a2bb721e5766de479d6569ea4fcee0c41537f5b731a9f297c03cdce5ac07c` |
| Fingerprint agregado do manifesto do bundle export/instalado | `a20b488c045b6ee8c71abd6bb7d4214bec6160ca6aa1ad1835d929e5954c5154` |

O validador compartilhado em `Scripts/validate-release-dmg.sh` aceita `--app /abs/Resenha.app [SourceSHA]` e o mesmo contrato é usado no DMG e pelo instalador. Release aprovado: bundle ID `br.com.luisroquette.Resenha`, arm64, mínimo macOS 14, Developer ID Application/team S3YCFYY8SC, Hardened Runtime, assinatura profunda estrita e entitlements XML com **dict vazio**. Não há XCTest/XCT/XCUI/Testing, `*.debug.dylib`, `__preview.dylib`, get-task-allow, testmanagerd ou coresymbolicationd. `otool -L` do executável mostra somente bibliotecas/frameworks Apple de produção; nenhum link de teste. Assinatura e ausência de marcadores foram verificadas antes do stage, no stage e na instalação; os manifestos source/installed são idênticos.

### Instalação, backup e recuperação

Comando: `zsh Scripts/install-local-release.sh <worktree>/build/direct-phase5-20261021/export/Resenha.app 0cf73d5834c8c4d0a3a9a8538d75d04a69fc5377 <worktree>/build/direct-phase5-20261021/evidence`. Log `/tmp/resenha-step10-install-20261021.log`. Exatamente um processo foi confirmado em `/Applications/Resenha.app/Contents/MacOS/Resenha`: **PID 25162**. Staging preservado: `/Applications/.resenha-stage.1czw3ehr`.

Backup: `/Applications/Resenha-backups/Resenha-20261021T124306Z-0cf73d5834c8.Wvn5LToR/previous-Resenha.app`. Executável anterior `457fc29f25d00cade3507bf22a61e60ba2affcf323045ab0786120902a36e3fd`; fingerprint completo `8881c6477a9ed90c72e34561db2f6d8f882f0a3d97cdad60f4c4c21a3fc59947`, igual ao inventariado antes da troca. `codesign --verify --deep --strict` passou no backup. O anterior é o **Debug Apple Development preservado**, não um Release aprovado. Nenhum backup, candidato falho ou diretório amplo foi apagado.

ERR/INT/TERM do instalador preservam o candidato já colocado como `failed-candidate.app`, copiam/verificam o backup antes de recolocar o destino e tentam reabrir a instalação anterior. Os testes injetaram falhas somente em fixtures; nenhuma falha artificial foi provocada em `/Applications`. Para recuperação manual, fechar apenas Resenha, preservar o Release atual em outro nome no mesmo diretório de backup, copiar o `previous-Resenha.app` para staging e recolocar `/Applications/Resenha.app` somente após conferir o fingerprint acima. Não executar o instalador Release para validar o backup Debug; ele deve rejeitá-lo por desenho.

Manifestos individuais, hashes, assinatura, entitlements, metadados de instalação e amostras estão em `build/direct-phase5-20261021/evidence/`. O resultado gerado inicialmente usava separadores `\\n` literais; somente sua formatação foi normalizada, mantendo valores e log original, e o instalador passou a escrever um campo por linha. O teste shell foi repetido após essa correção.

### Observação física e bloqueio concreto

System Events confirmou `Resenha — Permissões necessárias`. A janela nativa “Configurar Resenha” do **Release instalado** mostrou Microfone, Monitoramento de Entrada e Acessibilidade pendentes, modelo local **Pronto** e “Configuração pendente”. Nenhum botão de grant foi acionado, nenhuma entrada TCC foi alterada/resetada e nenhuma proteção foi reduzida. CUA inicialmente retornou timeout sem janela; após abrir “Configurar Resenha…” pelo menu, a janela real foi lida. Onboarding foi fechado com “Agora não”.

Com zero janelas acessíveis visíveis, seis amostras de `ps` a cada 2 segundos reportaram 0,0% CPU; acumulado 0:00.93 → 0:00.94 (**+0,01 s** no intervalo). Isso é somente uma observação limitada em idle, sem gravação/feedback disponível; não demonstra taxa de render, pass-through, multi-Space, VoiceOver nem cancelamento do modelo real. As respectivas regressões de lifecycle/cancelamento/WAV passaram no XCTest de 96 casos, mas não substituem o smoke físico.

Ditado básico, clique dentro/fora dos dois alvos e cancelamento físico no Release: **NOT RUN / bloqueados pelas três permissões**. A entrada padrão observada era AirPods Pro de Eu #2 - Find My; Step 10 não alterou microfone/volume nem produziu transcrição. Chrome, Terminal e sessões existentes foram preservados. A próxima intervenção necessária é autorizar as três permissões para este Release e repetir o smoke no mesmo hash; não é necessário reinstalar Debug nem afrouxar assinatura.

## Animated halo and feedback bubbles Debug candidate — 20/10/2026, 19:45–19:46 BRT

Step `06-animated-halo-feedback-bubbles`, installed source revision: `1a1a882365c87ea03204b4109138ba5126efb9f9`. This is a locally signed **Debug candidate**, not a release/store build and not physical acceptance evidence.

| Installed/backup identity | Verified value |
|---|---|
| Installed bundle | `/Applications/Resenha.app` |
| Version / build / identifier | `1.0.0` / `1` / `br.com.luisroquette.Resenha` |
| Installed executable SHA-256 | `457fc29f25d00cade3507bf22a61e60ba2affcf323045ab0786120902a36e3fd` |
| Installed implementation dylib SHA-256 | `f47f8c6160bce9bc39b423c30f0628aa3873cb06f8a6b7064d127e5048d77e63` |
| Signing identity | `Apple Development: luis roquette (K74FG72F9W)` |
| Team ID | `S3YCFYY8SC` |
| Recoverable previous bundle | `/Users/luisroquette/Projects/.worktrees/resenha-transcription-feedback/build/install-backups/20261020-194623-before-1a1a882/Resenha.app` |

The installed bundle passed `codesign --verify --deep --strict` and launched as PID **47892** after replacement. The previous bundle was archived before installation; no TCC reset or new permission grant was performed.

Canonical native gate for the exact installed source revision **PASS: 83 tests, 0 failures**. Command: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Result: `build/Logs/Test/Test-WhisperKey-2026.10.20_19-45-12--0300.xcresult`.

Deterministic **PASS**: the restored 44-point angular-gradient orb uses the existing finite/clamped meter helpers, including stationary Reduce Motion values. Feedback motion is separately calculable and bounded: 36-point visual circles remain inside 44 × 44 targets, use a 70 ms entry stagger, rest without panel movement, then rise/fade before the controller's unchanged four-second deadline. Reduce Motion keeps offset zero and scale one, retaining only opacity changes. Existing deadline/token/editor regressions remained green; no controller, timer, persistence, network, dependency or project configuration changed.

Fixtures regenerated at 19:39 under `/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/ResenhaTests/ui-fixtures`. `hud-feedback-{light,dark}.png` and `hud-listening-light.png` were inspected: both bubbles are centered, distinct, unclipped and retain highlights/outlines on the 280 × 64 material; the listening fixture shows the orb/halo within the unchanged 340 × 72 capsule beside readable status/timer/waveform. The feedback matrix also generated increased-contrast, reduced-transparency and reduced-motion fixtures at a deterministic one-second resting state. Still images do **not** prove the rise/stagger/fade sequence, live meter response, keyboard focus or VoiceOver.

**Installed, but physical validation is NOT RUN.** Live silence/speech halo response, bubble animation/timing, clicking during the fade, actual OS Reduce Motion/Increase Contrast, keyboard focus, VoiceOver speech, TextEdit continuity and clipboard behavior remain **NOT RUN** for this exact Debug candidate. Installation, signature, launch and automated evidence do not convert any of those checks into PASS. No Chrome/Terminal process, personal data, permission or accessibility setting was changed.

## Final compact candidate installed — 20/10/2026, 14:45–14:49 BRT

**Installed revision: `68ddb7c1c89c71d8f4eded078d94c5967749cb21`.** Phase 3 review passed with score 4.53 before replacement. The clean committed candidate passed the canonical gate through `mac-gate`: **82 tests, 0 failures**, finished 14:45:33 BRT. Log `/tmp/resenha-step05-final-sha-gate.log`; result `build/Logs/Test/Test-WhisperKey-2026.10.20_14-45-14--0300.xcresult`. The lock enclosed graceful Resenha quit/reopen for the singleton restriction; no other application was terminated.

The installer first copied the built candidate to a staging directory and verified it with `codesign --verify --deep --strict` and a recursive comparison against the build bundle. It then gracefully quit Resenha, moved the old installed bundle to the recoverable backup below, moved the staged candidate into `/Applications/Resenha.app`, and repeated signature/comparison verification. Its failure trap would move a failed candidate aside and restore the backup; no rollback was needed.

| Installed/backup identity | Verified value |
|---|---|
| Running installed executable / PID | `/Applications/Resenha.app/Contents/MacOS/Resenha` / **96641** |
| Version / build / identifier | `1.0.0` / `1` / `br.com.luisroquette.Resenha` |
| Installed executable SHA-256 | `c5a4af326d644d2afc7b5d13faa5000004185a9e881ce34b3c80cc164676339a` |
| Installed implementation dylib SHA-256 | `ac41b4528cc71d15cb0305eb6602f4e914430909c4cad5e3196ece1986acf99e` |
| Recoverable original bundle | `/Users/luisroquette/Projects/.worktrees/resenha-transcription-feedback/build/install-backups/20261020-68ddb7c/Resenha.app` |
| Original/backup executable SHA-256 | `2aae6550bbe8a309c8dc0ff5feb4c20212a2aaf9890563f65958b2ded70a695e` |

Candidate and original have identical designated requirements, with identifier `br.com.luisroquette.Resenha` and Apple Development identity `luis roquette (K74FG72F9W)`. Both installed candidate and backup passed strict deep verification. No TCC reset or new permission grant occurred. Read-only native menu inspection found **“Resenha — Pronto”**, **“Segure Option direita para ditar”** and **“Idioma — PT-BR”**; the current menu contract reaches Pronto only with microphone, input monitoring and accessibility ready and hotkey available. System audio inspection confirmed **Microfone (MacBook Pro)** as default input before and after. Existing local `ggml-large-v3-turbo-q5_0.bin` and `ggml-small-q5_1.bin` are present under `~/Library/Application Support/WhisperKey/models`; actual model loading was not exercised by this blocked attempt.

**Physical timing/editor proof: BLOCKED, not PASS.** The specifically authorized local JXA/CoreGraphics/TTS diagnostic was attempted with incremental logging and cleanup. Its first startup exposed the prior helper's real `NSNull count` cause: JavaScript `null` was passed to `NSFileManager.createFile` attributes; an empty `NSDictionary` fixed this before any key or clipboard mutation. The corrected run identified installed PID 96641 and saved the one-item clipboard, but TextEdit did not become/stay frontmost within four seconds. The observed foreground was Chrome before and after; user activity versus executor-driven focus interference was not resolved. The script stopped **before any synthetic key or TTS**, with no dictation, glossary write or feedback action. Log: `/tmp/resenha-physical-68ddb7c-events.jsonl`.

CUA then exposed TextEdit's Open dialog; its New Document action created one blank disposable document. After the interference stop, that exact unmodified, empty `Sem Título` document was closed without saving; no TextEdit document remained. The helper restored its clipboard snapshot, no synthetic key had been held, VoiceOver remained off and system accessibility settings were untouched. Chrome and Terminal were not closed/restarted. The verified requested installation remains running; only transient test state was cleaned up. Live 280 × 64 continuity, approximately-four-second expiration, editor survival, actual VoiceOver/Reduce Motion, insertion and clipboard/focus behavior remain **NOT OBSERVED** on this installed revision; deterministic/fixture results remain separately valid.

## Compact feedback candidate — 20/10/2026, 14:40 BRT

Step `05-compact-timed-feedback`, pre-review candidate: HEAD `780ef8a6cc14d972c606dd5648f13423488a96d1` plus the source fingerprints below. This is an uncommitted candidate, not a claim that the base SHA already contains this change.

Canonical native gate **PASS: 82 tests, 0 failures**, finished 14:40:47 BRT. Command: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. The lock enclosed a shell wrapper that gracefully quit only Resenha for its singleton restriction and reopened `/Applications/Resenha.app` on exit. Log: `/tmp/resenha-step05-mac-gate-final.log`; result: `build/Logs/Test/Test-WhisperKey-2026.10.20_14-40-25--0300.xcresult`. An earlier build caught two dictionary-cast precedence errors in the new tests; parentheses corrected both before the complete passing rerun.

| Artifact | SHA-256 |
|---|---|
| `Sources/WhisperKey/FloatingPanel.swift` | `8b005f2ed92243e7d9eb186e9754b7d7fdd1590eeb5da98dfbee180bd45dbad3` |
| `Sources/WhisperKey/FloatingStatusView.swift` | `56488e638989ca131bfba46d55991284e21458ce97cfb078942c354be01fd121` |
| `Tests/WhisperKeyTests/WhisperKeyTests.swift` | `30d6d8f98a4b43ee465d6cb3738ee574b27ff18e3efb214cca41902e6b917356` |
| Candidate `Contents/MacOS/Resenha` | `aff0c06af31ed85cffa4b2893a008f530463c0696d0ba9e011efc440f8f877a8` |
| Candidate `Contents/MacOS/Resenha.debug.dylib` | `3cdd5b50240f9a962099ee30d48981365bcc7690baaef87374e1ae0f3f3c2a4e` |

Candidate bundle: `build/Build/Products/Debug/Resenha.app`, version `1.0.0` / build `1`, identifier `br.com.luisroquette.Resenha`. `codesign --verify --deep --strict` passed; designated requirement names the existing Apple Development identity `luis roquette (K74FG72F9W)`.

Deterministic **PASS**: processing/feedback frame equality at 280 × 64; deadline exactly `now + 4`; offer/menu/token present immediately before deadline and absent at deadline; no defaults/glossary writes; old A timer cannot close B or its deadline; opening correction clears the timer and retains invalid draft/error/window after arbitrary clock advance; replacement recording/notice and hidden HUD reject stale callbacks. Existing like, menu, hotkey, HUD-off, recovery and glossary checks remain passing.

Fixtures regenerated by this same gate under `/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/ResenhaTests/ui-fixtures`. Inspected all five `hud-feedback-{light,dark,increased-contrast,reduced-transparency,reduced-motion}.png`, plus `hud-transcribing-light.png` and `hud-inserting-dark.png`: identical 280 × 64 logical footprint/material shell, two visible icons in native button regions, no visible heading or clipped control. Icons use 16-point medium symbols, 36 × 32 content frames plus native button padding. Source supplies distinct Portuguese accessibility labels/hints and requests one availability announcement. Reduce Motion disables the 0.12-second opacity transition; timer logic is independent of the view environment.

**Pending after Phase 3 review:** final committed SHA/build attribution, recoverable installed-app replacement, then TextEdit continuity/approximately-four-second expiration/dislike persistence, actual VoiceOver speech, OS Reduce Motion, focus and clipboard observations on that exact installed candidate. Fixtures/labels do not prove these physical cases. The previous installation was reopened as PID **86240** after the gate; it was not replaced. No Chrome/Terminal process, personal data, permission or system accessibility setting was changed.

## PR candidate follow-up — 20/10/2026, 12:22–12:27 BRT

Revision `217379848f127b82b7451efde6793aaf894a8e97`, executable SHA-256 `b81d0b049f3f1b5271c06593689e898cb97a444fdd22e1b508ca924aa39bdbb5`. Implementation dylib remains `bf38398ffce7c9dba59fe1853041663efe5496adfed94947330036e140ccadb7` and preview dylib `a15324d5f43139613df59eefdaaffef3230042182541ece52281be352b065cc5`, matching the prior candidate. The latest native gate `Test-WhisperKey-2026.10.20_12-10-25--0300.xcresult` reports 80 passed, 0 failed, 0 skipped.

A guarded attempt confirmed the actual candidate at PID 13091 and TextEdit frontmost, then aborted before sending a new dictation because the next invocation saw Terminal frontmost. This does not establish user interference: executor/session activation between calls is also plausible. No further focus assertion was counted as passed. The user-authorized alternative was one continuous local diagnostic script with in-process focus polling and a finally restoring the complete clipboard, VoiceOver state and installed app.

That continuous attempt ended with a diagnostic error: the final installed-process `pgrep` returned exit 1, masking the script's accumulated JSON report. No intermediate event log was persisted, so none of the intended Return/Escape/hotkey/Save/VoiceOver/network cases from that attempt is credited. The process-network CSV was empty, not proof of silence. The clipboard restore executed before that failing final check; a subsequent process inventory found no running candidate or VoiceOver. The installed app was then reopened explicitly via native control as PID **21875**, with original executable hash `2aae6550bbe8a309c8dc0ff5feb4c20212a2aaf9890563f65958b2ded70a695e`, three enabled permissions and local model ready. Default input remained `Microfone (MacBook Pro)`. The unsandboxed glossary key was still absent; no Save was confirmed or alias added.

This follow-up is **INCONCLUSIVE**, not an app failure or a completion pass. CK-8–CK-10 retain the physical gaps listed below. No product code was changed; the helper remained outside the repository, no commit/push occurred and the documentation diff check passed.

One authorized diagnostic-only retry added incremental logging and protected the final process check. It aborted during clipboard initialization, before activating TextEdit, launching the candidate or changing clipboard: `-[NSNull count]: unrecognized selector` when `NSPasteboard.pasteboardItems` did not supply an array. No event log was created and no functional step ran, so this retry adds no acceptance evidence. Subsequent inventory confirmed the original installed PID21875, built-in default input and no VoiceOver process. No further retry was performed; the helper's assumed non-null clipboard collection remains the identified diagnostic limitation.

## Final committed candidate follow-up — 20/10/2026, 12:02–12:07 BRT

Candidate revision: `a8dd373e612c30a070b6ba0636de81b086434a74`, product/test sources unchanged during these observations. Executable SHA-256 `a488b8545dd72c4eef0a611736d454e4319ef12bda607f4d5def23af2f756d58`; implementation `Resenha.debug.dylib` SHA-256 `bf38398ffce7c9dba59fe1853041663efe5496adfed94947330036e140ccadb7`; `__preview.dylib` SHA-256 `a15324d5f43139613df59eefdaaffef3230042182541ece52281be352b065cc5`. Strict bundle signature verification passed. Exact committed gate is the 80/80 result at `build/Logs/Test/Test-WhisperKey-2026.10.20_12-00-17--0300.xcresult`, recorded in the [DoD report](../../.specs/reports/transcription-feedback-dod-verification.md).

Two bounded follow-ups opened the candidate as PIDs 67574 and 71474. Before any Save, the unsandboxed preference domain had no `resenha.transcriptionGlossary` key: its effective source fallback contains 15 lines, 173 Swift/ASCII characters, SHA-256 `120a7ae898e08dccc6fc2bebcf55ba6d24068cdf15512f3f2733ee79a55eb4d6`, no exact `Coisa Energia = COESA Energia` pair and no conflicting `Coisa Energia` source. The key was still absent at the final check. The agent performed no Save, no overwrite and no glossary cleanup; no other personal glossary content was printed or recorded.

The user separately supplied these literal manual outputs during the follow-up: `A COIS Energia chegou para o teste local.` and then `A COESA Energia chegou para o teste local.`. The latter is observed user evidence of canonical text on a following output. The former illustrates the exact-match limit: a `Coisa Energia` rule does not cover `COIS Energia`; no extra alias was created. No specific Save, before/after state or causal link from that Save to the canonical output was independently observed by the agent. The user's report therefore supplements the deterministic correction proof without proving physical persisted-rule/relaunch causality.

For a bounded network observation, `nettop -P -p 67574 -L 90 -s 1 -J bytes_in,bytes_out` completed with 90 sampling headers and no process connection records. This is a limited no-record observation for that PID/window, not packet interception or proof across like/dislike/cancel/Save: those four agent actions were not reached. No global network setting was changed; the optional process sandbox/offline repeat was not launched.

The clipboard test saved every existing NSPasteboard item/type as retained NSData in a separate local process, temporarily installed the literal sentinel `RESENHA-FEEDBACK-SENTINEL-20261020`, and restored all saved types in `finally` at each stop. Sentinel SHA-256 was `4852519f5f56afd1164e3230cb31ad1f802aceadc1044631a456c09b2fbb3b6e`; a dictation changed it in the first follow-up. The test could not attribute both inserted text and caret/clipboard continuously to one controlled target, so clipboard/focus acceptance remains pending. No original clipboard content was logged or written to a file.

The last attempted controlled window lost exclusivity: after explicitly activating TextEdit and issuing Cmd-N before local TTS, the immediate frontmost read returned Google Chrome, which the test had not activated. All further feedback/VoiceOver/focus actions stopped. This is an observed focus change consistent with concurrent desktop use, not a diagnosed Resenha focus defect. Return/Escape, Save/relaunch, editor hotkey/Alt-Tab, VoiceOver captions, history/HUD-off and offline repeat were not completed in this window. VoiceOver was not enabled or left running.

Restoration: both candidate runs exited gracefully; the original `/Applications/Resenha.app` was reopened after each stop, finally PID **71768**. Its executable stayed `2aae6550bbe8a309c8dc0ff5feb4c20212a2aaf9890563f65958b2ded70a695e`; UI showed `Pronto para usar`, all three permissions enabled and model ready. Final `system_profiler` again confirmed default input `Microfone (MacBook Pro)`. No Chrome/Terminal session was closed, no TCC grant/reset occurred, and no product code, commit or push was made. Physical gaps remain explicit rather than being inferred from the user's canonical output.

## Local transcription feedback candidate — 20/10/2026, 11:41–11:49 BRT

Status: **automated gate passed; physical evidence partial**. The historical sections below describe earlier revisions. This section does not mark the complete feedback acceptance/VoiceOver gate passed.

### Provenance and environment

Apple M5, arm64, 16 GB; macOS 26.1 (25B78). Branch `feat/transcription-feedback`; HEAD `7ce408579b260b30a932b47b4f3cbaa7c9e88904` plus the Step 03 uncommitted diff in `DictationCoordinator.swift`, `FloatingPanel.swift`, `NativeMenuController.swift`, `WhisperKeyApp.swift` and `WhisperKeyTests.swift`. SHA-256 of `git diff --binary --` restricted to those five files: `f694858b9f050298e56fcfa429289fc72c0e9b8def36949f53a66535b09f342e`. Step 04 changed only the three specs and this evidence document; product/test diff remained unchanged.

| Artifact | SHA-256 / identity |
|---|---|
| Candidate `build/Build/Products/Debug/Resenha.app/Contents/MacOS/Resenha` | `b092604d77495b79ed59ed6573ee30dfc58bec401233ad423e07980722702146` |
| Candidate `Resenha.debug.dylib` (implementation) | `04a09691f18a9eefee04195702a56e56e49485cdede7c005a57190dda13b9523` |
| Candidate `__preview.dylib` | `a9e7615b19344b185e33893551c579ebdaa3e3a85fef75d4e94c92faabdafd64` |
| Installed `/Applications/Resenha.app/Contents/MacOS/Resenha`, before and after | `2aae6550bbe8a309c8dc0ff5feb4c20212a2aaf9890563f65958b2ded70a695e` |

The installed app was not overwritten, copied or re-signed. Its original PID 33938 was quit gracefully; the candidate ran from its explicit worktree build path as PID 38900. Both bundles have identifier `br.com.luisroquette.Resenha`, Team `S3YCFYY8SC`, the same Apple Development identity and identical designated requirement. Candidate `codesign --verify --deep --strict` succeeded. No TCC database/reset or grant was performed. The candidate displayed ready status and the existing `Option direita` shortcut; the restored installed app explicitly displayed all three permissions as enabled and local model ready.

Initial system/UI inventory found AirPods selected as default input, rather than the requested built-in microphone. The reversible Sound → Input selection was restored to `Microfone (MacBook Pro)` before the test. UI selection and final `system_profiler SPAudioDataType` both confirmed the built-in input; no input-volume setting was edited. TTS used `say -a 79` to select built-in speakers for that one signal, without changing the default output. Local `ggml-large-v3-turbo-q5_0.bin` and `ggml-small-q5_1.bin` were already present in the unsandboxed model directory; successful recognition proves a local model loaded, but the exact loaded file was not independently captured for this run.

Native gate supplied by Step 03 and independently read from its xcresult: **80 passed, 0 failed, 0 skipped**, `Test-WhisperKey-2026.10.20_11-40-18--0300.xcresult`, finished 11:40:41 BRT. Canonical invocation: `~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test`. Log: `/tmp/resenha-feedback-step03-final-20261020.log`. No new code was changed during Step 04, so this unchanged passing gate was reused. `git diff --check` passed. Site/scripts were unaffected; no site/npm/Vercel build was run.

### Observations, expected behavior and limits

| Case / CK | Action → expected | Observed / result |
|---|---|---|
| Candidate identity / CK-10 | Launch exact candidate → one process at build path | **PASS, process/UI**: PID 38900 matched the worktree bundle; ready HUD and settings were accessible. Installed binary hash stayed unchanged. |
| F1 / CK-1/10 | New disposable TextEdit document; hold/release configured shortcut around “A Coisa Energia chegou para o teste local.” → local capture, insertion, then feedback | **PASS for this synthesized-speech path**: explicitly authorized local JXA/CoreGraphics right-Option down/up, `say -a 79 -r 145` through built-in speakers and built-in microphone. TextEdit AX value became `A COISA Energia chegou para o teste local.`. System Events then exposed `Como foi a transcrição?` and two buttons in the actual candidate window. This is not human-speech or exact `COESA` correction proof. |
| F1 negative states / CK-1 | Silence/error/processing → no actionable rating | **NOT RUN physically**. `testFeedbackCompletionRequiresCurrentSuccessfulInsertionAfterCleanup` covers eligible completion and stale/cancelled attempt guards deterministically. No failure was manufactured. |
| F2–F4 / CK-2–6/9 | Like; editor invalid/Return/Escape; Save and relaunch → local-only correct state | **NOT RUN by the agent** after concurrent interaction. User separately reported manually trying the thumbs and correct/incorrect flow successfully; this is supplementary user evidence, without an observed phrase, validated Save, glossary comparison, focus sequence or relaunch proof. It does not establish those unobserved details. |
| F5–F7 / CK-7/10 | Ignore offer/new dictation, editor hotkey, app switch, destination ended, refresh, history/HUD off → preserved target and retired actions | **NOT RUN physically**. A later independent dictation superseded the offer while another app was frontmost, so agent interactions stopped to avoid racing the user's session. Lifecycle/hotkey/menu/permission/recovery XCTest cover the listed contracts; simultaneous user activity is not a controlled continuity pass. |
| Clipboard/focus / CK-10 | Compare staged clipboard and original target before/after each action | **PARTIAL**: TextEdit actually received the synthesized transcript. No clean clipboard baseline or continuous frontmost/caret observation was obtained; offer-only focus preservation, Return/Escape restoration and second-output correction remain **NOT RUN**. |
| F2/F8 / CK-9 | Control-F8 entry and actual VoiceOver speech → named actions/errors/success | **NOT RUN**: Control-F8 through CUA left TextEdit's reported focus unchanged; SystemUIServer binding timed out. CUA retained an obsolete listening-window snapshot after insertion; fresh System Events contents exposed the feedback instead. VoiceOver was not enabled; no VoiceOver process was present in final inventory. AX text/fixtures are not spoken-announcement proof. |
| F8 / CK-8 | Observe network throughout like/dislike/cancel/Save and offline repeat → no feedback transmission | **NOT RUN**: one process socket listing had no connection result, but no bounded observation over all four actions or offline repeat was completed. Source review found no network/analytics/dependency addition in feedback paths; that cannot substitute for the missing traffic observation. |
| Cleanup / CK-10 | Quit candidate and reopen exact installed app → original usable installation/input | **PASS, process/UI**: candidate exited gracefully; installed app reopened as PID 51337 at `/Applications/Resenha.app/Contents/MacOS/Resenha`, showing `Pronto para usar`, three enabled permissions and local model ready. Final input was built-in `Microfone (MacBook Pro)`. Chrome, Terminal and pre-existing documents were not closed. |

The disposable TextEdit document was created separately from the existing document and received only the test phrase. TextEdit auto-named it `Sem Título 2.rtf`; it was left available rather than deleting a document during concurrent use. History was enabled at observation time, so the ordinary existing history mechanism could retain the synthetic test transcript. No personal history/glossary was cleared, no draft was saved by the agent, and no claim is made that user-driven changes during the session were absent.

### Deterministic and fixture evidence

The 80-test result covers `testCorrectionCandidate*` boundaries/escaping/conflicts, `testCorrectionSave*` persistence/rollback, `testCorrectionRollbackFailureBlocksDirectSaveUntilVerifiedReloadWithoutWrites`, `testRollbackRecoveryCancelReloadAndRetiredTokens`, `testFeedback*` completion/lifecycle/menu/routing and `testRecoveryDraftIsErasedOnNewDictationHUDOffAndTermination`. The isolated Save → reconstructed preferences → real postprocessor scenario proves “Coisa Energia” → “COESA Energia” deterministically, with prior rules retained and whole-term boundaries. It does not prove a rule physically persisted/reapplied in this session. Rollback failures were test-only; no real storage corruption was induced.

Current generated fixtures are under `/var/folders/7k/8wtpdcvn5f95c8s36d91t8k40000gn/T/ResenhaTests/ui-fixtures`, with feedback/editor files dated 20/10/2026 11:40. Step 04 inspected `hud-feedback-dark.png`, `correction-empty-light.png`, `correction-long-error-{light,dark,increased-contrast}.png` and `correction-small-error-dark.png`: controls/fields remain visible and normal-size error wraps. In the small fixture, long field values and the lower part of the long guidance exceed the initial viewport; source provides a ScrollView above the fixed action row, but physical scrolling/reading of that remainder was not tested. These are NSHostingView fixtures, not live screenshots or VoiceOver proof. An older similarly named container fixture folder dated 02/10 was not treated as candidate evidence.

Remote PR head inventory was read only: #9 `0a6c7bcbee5a3da86b2378e71cc3466d3377947d`; #13 `758f9b13f272ed64d80981794c80dd15afe1440d`. Neither was integrated. Installed binary origin cannot be assigned to either PR from a build number/signing identity alone; its distinct hash is the observed identity.

Remaining physical gates: controlled like/cancel/Save/defaults comparison; exact saved `Coisa Energia = COESA Energia` after relaunch and next dictation; keyboard entry/Return/Escape and VoiceOver speech; editor/hotkey/app-switch/ended-destination, HUD/history-off cases; clipboard/focus and bounded network/offline observation. The script is in [SPEC-008](../specs/08-testing.md). No pending case above is counted as a pass.

## Marca Resenha no produto — 02/10/2026

- Símbolo original: balão de conversa com waveform em espaço negativo, gerado com fundo transparente.
- Asset catalog fornece variantes 1x/2x e renderização template monocromática.
- HUD `Ouvindo`: marca coral de 28 pt antes do cronômetro; onboarding e Sobre reutilizam a mesma identidade.
- Fixtures clara e escura inspecionadas: marca, estado, `00:07` e waveform permanecem legíveis.
- Gate canônico: 44 testes, 0 falhas; asset catalog compilado sem warnings.

## Feedback, recuperação e idioma — 02/10/2026

- Sons nativos distintos de início/fim, volume 35%, reprodução limitada a 250 ms e ajuste para silenciar.
- Transcrição concluída é colocada no clipboard antes da inserção e não restaura o conteúdo anterior.
- `Textos recentes` preserva localmente até 10 transcrições, com copiar e limpar mediante confirmação; áudio continua efêmero.
- Menu e painel Transcrição oferecem `PT-BR`, `EN` e `ES`; a escolha persistente vira `-l pt|en|es` no próximo ditado.
- Gate canônico final: 44 testes, 0 falhas; inclui clipboard persistente, limite/deduplicação do histórico, sons e idiomas.
- Menu real: `Idioma — PT-BR`, `Textos recentes`; submenus `PT-BR / EN / ES` e estado vazio confirmados via Accessibility. A troca ao vivo exibiu `Idioma — EN`, persistiu `en` e foi restaurada para `PT-BR`/`pt`.
- Bridge nativo voltou a retornar timeout; som ouvido e recuperação após ditado físico permanecem NOT RUN.

## Fluxo físico do produto — 02/10/2026

- TextEdit permaneceu como destino e recebeu a transcrição no cursor após hotkey, gravação e processamento local.
- Frase pretendida: `Testando o Resenha no meu Mac.`
- Texto inserido: `Testando o resenho no meu Mac.`
- Fluxo funcional: PASS. Fidelidade do nome `Resenha`: FAIL, registrada como OQ-001 na SPEC-011.
- Latência, restauração do clipboard, limpeza pós-sessão e Chromium continuam NOT RUN.

## Localização PT-BR do produto — 02/10/2026

- Menu real: `Resenha — Pronto`, instrução com o atalho configurado, Ajustes, configuração, permissões, Sobre e encerramento em PT-BR.
- HUD: `Ouvindo`, `Transcrevendo`, `Inserindo` e mensagens de recuperação em PT-BR.
- Permissões: nomes, finalidade, estado e recuperação em PT-BR.
- Fixture `hud-listening-light.png` regenerada e inspecionada; cronômetro e waveform continuam legíveis.
- Gate: 40 testes, 0 falhas.
- App relançado como um processo PID 81548, com status `Pronto`.

## Identidade pública Resenha — 02/10/2026

- Artefato `Resenha.app`, executável/processo `Resenha` e nome público Resenha.
- Módulo Swift interno `WhisperKey` e bundle ID `br.com.luisroquette.WhisperKey` preservados deliberadamente.
- Scheme, test host e module name foram separados explicitamente em `project.yml`.
- Gate: 40 testes, 0 falhas; assinatura estrita válida.
- Reabertura repetida manteve um processo PID 76169.
- Spotlight, Info.plist, menu nativo e Computer Use confirmaram a identidade Resenha.

## Ajustes nativos do produto — 02/10/2026

- Gate final: 40 testes, 0 falhas, via `mac-gate`.
- Uma janela nativa `Ajustes do Resenha` com Geral, Atalho, Áudio e Sobre.
- Reabertura repetida manteve uma janela e um processo.
- O microfone padrão real foi identificado como `Microfone (MacBook Pro)`.
- Troca de atalho para `Control + Espaço` atualizou imediatamente o menu; `Option direita` foi restaurado após a prova.
- Nenhum login item, permissão ou Ajuste do Sistema foi alterado durante a inspeção.

## Onboarding nativo de permissões — 02/10/2026

- Build testada: `build/Build/Products/Debug/WhisperKey.app`.
- Gate: 37 testes, 0 falhas, executados via `mac-gate`.
- Runtime: um único processo do app e uma única janela `Configurar Resenha`.
- Interface real: título `Fale. O Resenha escreve.`, estados reais das três permissões, indicação `Pronto para usar` e CTA `Começar a usar`.
- Recuperação: item nativo `Configurar Resenha…` confirmado no menu.

Date: 2026-10-02, observations 13:06–13:18 BRT (-0300).
Status: **IMPLEMENTED; PHYSICAL TEXTEDIT FLOW PASSED WITH ONE QUALITY REGRESSION**. Output quality is specified in SPEC-011.

Recording refinement reopened 2026-10-02: SPEC-006 and Step 03/05 acceptance were updated before code. The revised metering HUD is implemented; the new 35-test gate and 40 fixtures are recorded below. The original 31-test fingerprints/gate/24-fixture record is historical baseline evidence. Actual physical microphone/caret acceptance remains pending. Item 2 remains unstarted.

## Current recording-HUD revision — 13:53–13:56 BRT

The existing recorder's 16 kHz mono WAV settings are unchanged. Only AVAudioRecorder metering was enabled; a common-mode main-run-loop timer reads averagePower(channel: 0) at 20 Hz and passes finite normalized scalar values to the panel. `RecordingMeter` retains 48 readings, applies bounded 0.65 attack / 0.18 decay and formats injected monotonic elapsed time. No randomized input, waveform animation task, per-frame accessible label, extra permission, output-quality change or stored level history was introduced.

Canonical mac-gate **PASS: 35 tests, 0 failures**, 2026-10-02 13:53:46 BRT. Log: `build/recording-hud-mac-gate-rerun.log`. Result: `build/Logs/Test/Test-WhisperKey-2026.10.02_13-53-40--0300.xcresult`. Four new checks cover power normalization/attack/decay, fixed ordered history/reset, injected-clock rollover and stopped-state rejection, and stationary Reduce Motion/stable accessible status. The first attempt compiled but could not launch the test host (LaunchServices Code 20) while the old single-instance baseline process PID 11547 was running. Only that exact app process was terminated; the full gate passed on retry without TCC/reset/check bypass.

The same stable signed bundle passed `codesign --verify --deep --strict` and was relaunched once. Repeated open retained one process **PID 44816**. Bundle/signing identifiers and project.yml remain unchanged. All production Swift files are at most 198 lines. No repository HEAD exists; these changed-source/project/binary fingerprints, together with unchanged baseline entries below, identify the current tested revision:

| Changed artifact | SHA-256 |
|---|---|
| AudioRecorder.swift | 5938eefb6df1edf972876466155610847b21eafc31450398a24aa1ee74aa7f08 |
| DictationCoordinator.swift | 14e724dab54a14c2dfbdfbb478520a17dfb5838821e955793fdd1af7c5250336 |
| FloatingPanel.swift | 2855c23c08e336b2fc0a27ce7adfcd43c3a01bd0a8cf97d38aa22cfd4aed46bb |
| FloatingStatusView.swift | 6250c2aa944e80a247e699bd41500c141cea1614d0ae5ad5fe5effa7d327bbb9 |
| PanelPlacement.swift | 863228a59effd52df7b68daa3ebffc0dfca422fa4b587af1cd9bac7a15162cae |
| RecordingWaveformView.swift | 76e3a858083639629b9b18a5eae22184ad1995b12631444795dda2fcbd5c75ef |
| Tests/WhisperKeyTests/WhisperKeyTests.swift | 0ca75f63591555127f0939ea56cccaacafd1e2242cbaa61528fb1df808adc379 |
| WhisperKey.xcodeproj/project.pbxproj | 14f5249dd9faff25c0246edf59c5c7a7c4ed795790678227d6b676b235fe0f1c |
| Stable app executable | 6682d9f405982e5172bed5edae260637938311e0c3c5ecccc4647dfb42c75c1d |
| Stable app WhisperKey.debug.dylib | dae94aa7598ed89a8a8b8a06ba09f88e89dafa1cb07557f17c2826bd31d93587 |

Current fixture manifest: `build/ui-fixtures/hud-{state}-{appearance}.png`, eight states (ready, listening, listening-silence, listening-decay, transcribing, inserting, failure, long-failure) × five profiles (light, dark, increased-contrast, reduced-transparency, reduced-motion), **40 files**. Listening uses known injected dB values, a fixed 00:07 clock and the production renderer. Silence and decay are injected fixtures, not audio captures. Reduced Motion uses a stationary current-level array; contrast/transparency/motion fixtures use internal overrides rather than changing system settings. Six representatives inspected: listening-light, listening-dark, listening-silence-light, listening-decay-dark, listening-reduced-motion and listening-reduced-transparency. Labels/timer and dense rounded bars are readable; still images do not prove time progression or live microphone sampling. Recording footprint is now 340 × 72; ready/processing and error sizing/placement remain unchanged.

Fixtures are regenerated build outputs: names shared with the historical baseline now contain the current revision. Historical inspection notes describe the prior result; those earlier PNG versions were not separately archived.

Current native attempt: `cua.getApp` with the exact stable bundle path again returned **-10005 timeoutReached**. No native state or recording interaction was obtained. Real microphone responsiveness, physical hotkey/timer behavior, caret/click-through, VoiceOver, actual accessibility-setting changes, target-v-pointer/multiple displays and Spaces/full-screen remain **NOT RUN** on this revision. Hardware remains three online displays; presence is not a placement pass. Minimum macOS 14 and human CORE-001 remain pending.

Required manual check (60 seconds): in TextEdit, hold Right Option for 5–10 seconds; alternate silence and speech and confirm the bars follow the microphone, the timer increments and stops/resets on release, and the caret stays active. Then speak “Testando o nosso sistema de voz” for CORE-001 and record actual insertion/timing, clipboard preservation and owned-file cleanup. No pass is inferred from injected levels.

## Historical baseline — before the recording refinement

## Environment and tested revision

macOS 26.1 (25B78), Apple M5 arm64; Xcode 26.3 (17C529), Swift 6.2.4, Swift 5 project language mode; minimum deployment macOS 14. whisper.cpp 1.9.2 from Homebrew, local `ggml-small-q5_1.bin` (190085487 bytes). Current hardware: built-in 3024 × 1964 display plus two online LG 2560 × 1080 ultrawides (60/75 Hz), non-mirrored. Their presence does **not** prove target-screen placement. macOS 14 execution is NOT RUN.

There is no HEAD/commit in this newly initialized, untracked repository. Exact source/binary fingerprints identify the tested working tree; no historical diff against a commit is claimed. All production/test/project file mtimes predate the final 13:01:47 gate. Step 05 changed documentation only and reused that exact unchanged passing revision.

| Artifact | SHA-256 |
|---|---|
| AudioRecorder.swift | 5382e24c3850c8417c542d5061138d6109d81c7797fce5aa534cd037eaa86bc8 |
| DictationCoordinator.swift | eaf2f508eb9eddd68a6c1c7590aed9b8bda70bb9b51f04339afffaf27bbd59a0 |
| DictationInteraction.swift | a96fd9bf311df2333f25b4dff20c1465edb72426ffb952460a35e7e47559c9c6 |
| FloatingPanel.swift | 688729b5f7f05b0b8294f15e2ab4aad75e4e6e6cae662fa26bcf644c843324b9 |
| FloatingStatusView.swift | b791d2451281ac3c8e963724b03f6a507babee9cafdb6d99bb243f9bca79faea |
| HotkeyMonitor.swift | 0c6dbc6bcaefdee2d698fa66e70e32905a7a3570c5d52aa0fb34ed463c7c011b |
| MenuPresentation.swift | 365babd75132df28e9434a31aa288c3864abf200cae65e93d6991cf422297552 |
| NativeMenuController.swift | 7b6ab6d8d9763e5141e00a3995736320fbaa28a086d3a58b0cd4d1e852fbed1a |
| PanelPlacement.swift | ad8e060c1bab7879bbd55f2081d88fb387849639655a0843915ec241b431be50 |
| PermissionService.swift | 3f38949347bc7bf58c149a4283595eedcccfcccc3388a8b641974023669f31c9 |
| TextInjector.swift | ed02b9ec060d30bdaf399d7fb73da75e1609c95bc8b8084f282cb0b59d244c61 |
| WhisperKeyApp.swift | 3bc0a5abfc338cb8adf42214791b71c704dbf13b827b4dfc942f8b73534e6d41 |
| WhisperTranscriber.swift | 27510d86ab479dd7f706d1018c9a2f9f25c918b905ebee71b1ca992d40e2bc5a |
| Tests/WhisperKeyTests/WhisperKeyTests.swift | 05377cd165f56c510d57d761329aa669fdeb2ec931dc8a4946395e7f9dd26c29 |
| project.yml | e0cf53e10999d7cffeb1edb0de6500283f4448fd404e56132174ea75ef2403e9 |
| WhisperKey.xcodeproj/project.pbxproj | 53de33f4fb134bce23366e5f03e0c107376813bd6fcd1571589aee1d5a0a991b |
| Config/WhisperKey-Info.plist | 2047be71145c600bec1b3d7dcf4cfc34fe575376db599778ba2794282273061f |
| Stable app executable | 584f28b2cc68741c1cb1b367121b87bf3132c2148d25bb952c49fdb9c362657b |
| Stable app WhisperKey.debug.dylib (implementation) | a935ed04602e4e71fc6c5ba2a5c3ec84fe5f230efaaf002858facf5c1e02292f |
| Stable app __preview.dylib | 0a18d0739d98d6f82e77b58ab582d7a90b0ba27fe09fab14ef410bf9e1d34697 |

Production basenames above are under `Sources/WhisperKey`. Stable bundle: `build/Build/Products/Debug/WhisperKey.app`; identifier `br.com.luisroquette.WhisperKey`. Earlier pre-refactor fingerprints/logs remain historical and are not substituted for this revision.

## Automated gate and local launch

Command:

```sh
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

**PASS: 31 tests, 0 failures, 0 skipped**, completed 2026-10-02 13:01:55 BRT.
Log: `build/phase2-refactor-integrated-mac-gate.log`.
Result: `build/Logs/Test/Test-WhisperKey-2026.10.02_13-01-47--0300.xcresult`.
No standalone lint/remote workflow exists in this baseline. Prose-only integration did not rerun the unchanged gate.

`codesign --verify --deep --strict` returned success for the same bundle. Designated requirement is the existing Apple Development identity; identifier remains unchanged. `LSMultipleInstancesProhibited=true` and `LSUIElement=true`. LaunchServices inventory shows one registered WhisperKey app at the stable path. Repeated `open build/Build/Products/Debug/WhisperKey.app` returned success and retained one PID **11547**, observed again at 13:18. This proves launch/process identity, not visible menu/HUD/caret behavior. This Debug test bundle contains Xcode's Apple test-support frameworks/plugin; they are not third-party application dependencies or a distributed release.

Lifecycle log for that PID reports `Hotkey monitoring active` at 13:02:38. This is start/readiness evidence, not a physical hotkey/voice acceptance. Idle inspection found no owned WAV files in the app temp subdirectory or `WhisperKey-*.txt` output files; it does not prove post-dictation cleanup on this revision.

## Capture manifest — fixtures only

All files below are `build/ui-fixtures/hud-{state}-{appearance}.png`, generated by `testHUDNativeFixturesForEveryStateAndAppearance` during the exact gate. They host the production SwiftUI view in NSHostingView, not a live dictation window. Light/dark override colorScheme/native appearance; contrast/transparency use internal fixture overrides. The reduced-transparency set combines dark, increased contrast and opaque background. It is not an independent OS-setting toggle test.

| State | Light | Dark | Increased contrast | Reduced transparency |
|---|---|---|---|---|
| ready | hud-ready-light.png | hud-ready-dark.png | hud-ready-increased-contrast.png | hud-ready-reduced-transparency.png |
| listening | hud-listening-light.png | hud-listening-dark.png | hud-listening-increased-contrast.png | hud-listening-reduced-transparency.png |
| transcribing | hud-transcribing-light.png | hud-transcribing-dark.png | hud-transcribing-increased-contrast.png | hud-transcribing-reduced-transparency.png |
| inserting | hud-inserting-light.png | hud-inserting-dark.png | hud-inserting-increased-contrast.png | hud-inserting-reduced-transparency.png |
| failure | hud-failure-light.png | hud-failure-dark.png | hud-failure-increased-contrast.png | hud-failure-reduced-transparency.png |
| long-failure | hud-long-failure-light.png | hud-long-failure-dark.png | hud-long-failure-increased-contrast.png | hud-long-failure-reduced-transparency.png |

Step 05 visually inspected ready-light, listening-dark, transcribing-increased-contrast, inserting-reduced-transparency, failure-light, and long-failure in dark/increased-contrast/reduced-transparency. These eight representative fixtures are legible, with stable alignment and a two-line long cause/recovery. The remaining files exist and were generated successfully; no full real-screen background/contrast coverage is claimed. Ordinary footprint is 280 × 64 points; failure is bounded to 360 × 104. Idle has no screenshot because the HUD is hidden. No native menu screenshots were obtained.

## Verification matrix

PASS means only the named evidence type passed. NOT RUN is not a failure diagnosis and is not covered by another row.

| Scenario | Type / result | Observation or limit |
|---|---|---|
| All six visibility/status conditions, copy/symbol/progress mapping | Unit / PASS | State mapping and idle-hide tests; fixtures for five visible states plus long failure |
| Ready/failure dismissal; obsolete timeout survives listening/processing | Unit / PASS | Current generation/deadline, cancellation/callback and repeated automatic failure cases |
| Live approximately-two-second timeout and ready → real recording overlap | Native / NOT RUN | CUA could not bind the app window; no physical input |
| Focus/caret, click-through and one physical panel | Unit/source / PASS; native / NOT RUN | Passive flags and panel replacement exercised; TextEdit/Chromium behavior not observed |
| Menu-open-mid-recording release, rejected held press, request/self guards | Unit / PASS; native / NOT RUN | Actual AppDelegate routing exercised with controlled phases; no live recording/request |
| Partial permissions, all combinations, recording-only loss cleanup | Unit / PASS; native / NOT RUN | Snapshot/control-flow checks; real revocation and microphone cleanup not performed |
| Named Settings action success/failure/manual guidance | Unit / PASS; native / NOT RUN | Destinations and Boolean handling verified; actual Settings panes/TCC not visited |
| No-speech, capture and insertion failure titles/details | Unit / PASS; native / NOT RUN | Typed errors map to concise safe causes; hardware/model-error simulation not performed |
| Long diagnostic paths and safe recovery | Unit / PASS; native / NOT RUN | Wrapping rows, bounded width, complete safe paths tested; native scrolling/assistive reading pending |
| Appearance/status readability | Fixture / PASS (eight inspected); OS settings / NOT RUN | Production view rendering only; busy backgrounds/actual settings not observed |
| Keyboard menu actions, Quit/relaunch, VoiceOver reading order/discovery | Native / NOT RUN | No reliable native app binding; no forced announcements or permission resets |
| Negative geometry, target-v-pointer selection, fallbacks/disconnection | Unit / PASS; native / NOT RUN | Three screens present, but real moved target/pointer/Dock/disconnection behavior pending |
| Another Space/full-screen | Native / NOT RUN | No reliable native UI access; no level increase used to manufacture coverage |
| Physically spoken TextEdit CORE-001 | Human / NOT RUN — PENDING | Required phrase not spoken/observed for this revision |
| Chromium voice insertion, clipboard restoration and session cleanup | Human/native / NOT RUN | Baseline plumbing evidence retained separately; no new compatibility pass inferred |
| Minimum supported macOS 14 | Hardware/OS / NOT RUN | Current machine is macOS 26.1 |
| Local/native/ephemeral/item-1 boundary | Source/review / PASS within inspected revision | Apple frameworks; no new dependency/network/logged transcript/history/output algorithm changes |

## Native automation limits

Step 05 tried `cua.getApp("WhisperKey")` and the full stable bundle path: both returned server `-10005: timeoutReached`. Inventory succeeded; `cua.getApp("com.apple.TextEdit")` returned `-10005: cgWindowNotFound`. No native app state/capture or test action was obtained. Existing Step 04 observations record the same WhisperKey timeout. Real TCC was not reset, models/runtime were not renamed, and no other input technology was used to bypass the native bridge. These are environment/tool limits; they do not establish an app defect or successful behavior.

## Remaining completion gate

**The task remains in-progress.** Human TextEdit acceptance and native behavior cannot be closed from fixtures or historical microphone plumbing. Item 2 must stay unstarted.

Indispensable next action (60 seconds): in a new TextEdit document, physically hold Right Option, say **“Testando o nosso sistema de voz”**, release, then report the actual inserted text, approximate release-to-insertion seconds and whether TextEdit/caret stayed active. Record the observed result against the executable fingerprint above. Clipboard preservation and owned temporary-file cleanup must also be observed before CORE-001 is marked passed; repeat in an editable Chromium field for compatibility. Remaining keyboard/assistive, recovery and display/Spaces observations require a working native bridge or direct operator access and stay NOT RUN until performed.
