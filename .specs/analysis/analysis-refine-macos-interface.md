# Codebase impact — interface nativa do WhisperKey

Data: 2026-10-02. Escopo: item 1 (layout e design dos componentes). Leitura estática completa das oito fontes Swift, nove specs, arquitetura, testes, manifesto, plist e evidência M0. Nenhum código executado ou alterado nesta análise.

## Limites e baseline

O produto atual é uma utilidade de menu bar, sem janela principal: `WhisperKeyApp.body` contém apenas `Settings { EmptyView() }`; `LSUIElement=true` mantém a identidade de agente. O projeto requer macOS 14 e usa AppKit + SwiftUI, sem dependências externas de UI.

`docs/testing/M0-EVIDENCE.md` registra quatro testes e integração automatizada funcionando, mas mantém `CORE-001` como **PENDING FINAL HUMAN-SPOKEN PHRASE CHECK**. Isto é evidência documental anterior, não verificação realizada nesta análise. Planejar refinamento é autorizado; a implementação deve preservar e confirmar o fluxo básico antes de declarar conclusão.

O repositório não tem HEAD resolvível; arquivos do produto estão untracked. Não usar `git diff HEAD` como inventário de trabalho, não resetar, não sobrescrever arquivos existentes. A tarefa draft contém somente o pedido inicial e placeholder de descrição no momento desta leitura.

Fora do item 1: ajustes de reconhecimento, normalização, dicionário, anglicismos, tradução, idioma do modelo, parâmetros de Whisper, novos modelos, pós-processamento e saída textual. Não criar histórico, suíte de ajustes, gravação contínua, atalho configurável, conta ou serviço remoto. A redação dos rótulos da interface pertence ao item 1; não é alteração do idioma de reconhecimento.

## Superfícies existentes

| Superfície | Implementação atual | Consequência para o refinamento |
|---|---|---|
| Ícone de menu bar | `WhisperKeyApp.swift:102`, `NSStatusItem.squareLength`, SF Symbol waveform | Preservar controle nativo, estado acessível e tooltip; atualmente só distingue permissões/ready, não acompanha o ditado |
| Menu | `AppDelegate.configureMenuBar()`: instrução estática, Enable permissions, Check permissions, Quit | Espaço existente para hierarquia, instrução do atalho e recuperação por permissão; não precisa de uma nova janela |
| HUD | `FloatingPanel.swift:47`: `NSPanel`, 280×64, sem borda, não ativante, flutuante, ignora mouse | É feedback passivo; qualquer ação de recuperação deve ficar no menu, não em botão dentro deste painel |
| Conteúdo do HUD | `FloatingStatusView`, ícone/progresso + texto de até duas linhas; fonte 14 semibold, gap 12, inset 18, material regular, raio 18 | Reusar SwiftUI, SF Symbols, cores semânticas e material nativo. Ainda não há preview, token compartilhado ou asset visual |
| Feedback de permissão | Mensagem da primeira permissão ausente em tooltip; botão Check mostra failure | Falta visão das três permissões e ação explícita que abra o painel específico de Ajustes |

O painel fica centralizado em `NSScreen.main ?? NSScreen.screens.first`, 88 pontos acima da borda inferior de `visibleFrame`. Reposiciona a cada `show`, não fixa a tela da sessão e não observa mudanças de tela. `canJoinAllSpaces` e `fullScreenAuxiliary` estão habilitados. As consequências reais em tela cheia, Spaces e monitores precisam de validação local.

## Estados, fluxos e donos

| Evento | Dono/chamada | Resultado atual |
|---|---|---|
| Lançamento/ativação | `applicationDidFinishLaunching`/`applicationDidBecomeActive` → `startHotkeyIfReady(showResult: false)` | Cria menu, verifica permissões, inicia hotkey quando possível; ready aparece 2 s somente quando o monitor inicia |
| Clique Enable | `enablePermissions()` → três requests de `PermissionService` | Accessibility e Input Monitoring síncronos, depois microphone assíncrono; inicia monitor se aprovado |
| Clique Check | `checkPermissions()` → `startHotkeyIfReady(showResult: true)` | Ready temporário quando completo; failure persistente quando incompleto |
| Permissões mudam | Timer de 1 s → `refreshPermissionState()` | Inicia ao receber todas; para monitor se perde alguma; mudança parcial enquanto parado não atualiza tooltip |
| Right Option down/up | `HotkeyMonitor.onPress/onRelease` → coordinator | Guarda app frontmost antes do painel; recording/listening → transcribing → inserting; sucesso oculta HUD |

`DictationPhase`: idle → recording → transcribing → inserting → idle; estados ativos aceitam failed → idle. `FloatingStatus`: ready, listening, transcribing, inserting, failure(String). Não há estado idle visual: significa painel oculto. `FloatingStatus.isBusy` cobre transcribing e inserting. `.failure` não distingue erro transitório de bloqueio persistente de configuração.

`DictationCoordinator.fail(_:)` cancela recorder, mostra failure e agenda reset em 2 s. `FloatingPanelController.showTemporarily(_:)` cria outro Task de 2 s sem guardar/cancelar handle. Os dois produtores do HUD são **AppDelegate e DictationCoordinator**; todos os chamadores foram rastreados. Uma apresentação posterior pode ser ocultada pelo timer anterior do ready. Check permissions pode substituir listening por ready enquanto a captura continua. Estas são falhas de arbitragem de apresentação observáveis no código, não propostas de mudança do motor.

## Interfaces e integração

| Símbolo/interface | Contrato atual | Impacto esperado |
|---|---|---|
| `FloatingPanelController.show(_ status: FloatingStatus)`, `showTemporarily(_:)`, `hide()` | MainActor; atualiza modelo e painel sem ativar app | Centralizar propriedade/cancelamento da apresentação temporária; preservar estado ativo contra aviso antigo; manter focus invariant |
| `FloatingPanelModel.status: FloatingStatus` | ObservableObject privado + @Published | Reusar como fonte visual; abrir apenas a visibilidade mínima necessária para teste/preview, sem criar framework de estado |
| `FloatingStatus.title: String`, `isBusy: Bool`; `FloatingStatusView.body` | Mapeamento de texto/ícone/progresso | Definir hierarquia, copy concisa, tamanho adaptável limitado à tela e alternativa sem transparência; erro técnico longo não pode ser o único texto truncado |
| `AppDelegate.startHotkeyIfReady(showResult: Bool = false)` | Checa três permissões; atualiza ícone/tooltip; inicia monitor | Atualizar status de permissões mesmo parcialmente, manter menu verdadeiro e impedir avisos de ready sobre atividade |
| `PermissionService.isAccessibilityGranted`, `.isMicrophoneGranted`, `.isInputMonitoringGranted`, `.missingPermissionMessage` | Consultas booleanas; primeira falta tem prioridade A → M → I | Reusar APIs existentes; expor apresentação por permissão sem confundir denied/notDetermined quando houver ação específica |
| `requestAccessibility()`, `requestInputMonitoring()`, `requestMicrophone() async` | Pedidos disparados pelo menu; microphone só pede se notDetermined | Prompts sempre após ação explícita; recuperação de permissão já negada exige ação em Ajustes, não loop de requests |
| `PermissionGate.shouldStartHotkey(accessibility:microphone:inputMonitoring:hotkeyRunning:) -> Bool` | Todas aprovadas e monitor parado | Preservar e expandir verificação de apresentação/gate somente se necessário; não duplicar lógica em view |
| `DictationCoordinator.init(permissions:panel:)`, `hotkeyPressed()`, `hotkeyReleased()`, `cancel()` | Orquestra estados e é outro produtor do HUD | Integração mínima para prioridade de apresentação e estado do menu; não reestruturar transcrição/injeção |

`TextInjector.insert(_:into:)` ativa o app previamente capturado antes do paste; isso não autoriza o HUD a ativar WhisperKey. O teste de foco deve verificar frontmost/caret durante recording e processing e a chegada ao app original ao inserir. O painel não deve introduzir `NSApp.activate`, janela key ou interação de mouse.

## Arquivos afetados previstos

Envelope de implementação recomendado: **10 arquivos: 9 modificações, 1 criação, 0 remoções**, sujeito às decisões finais da arquitetura. Estes são caminhos concretos de impacto, não alterações executadas por esta análise.

| Operação | Caminho | Alteração delimitada |
|---|---|---|
| Modificar | `Sources/WhisperKey/FloatingPanel.swift` | Componentes/estados visuais, layout resiliente, acessibilidade, timer e posicionamento do HUD |
| Modificar | `Sources/WhisperKey/WhisperKeyApp.swift` | Hierarquia do menu, rótulos/status, entradas de recuperação e convivência com atividade |
| Modificar | `Sources/WhisperKey/PermissionService.swift` | Estado/apresentação por permissão e abertura explícita de Ajustes quando necessária |
| Modificar | `Sources/WhisperKey/DictationCoordinator.swift` | Ligação mínima entre atividade e apresentação/menu; preservar fluxo e contratos do motor |
| Modificar | `Tests/WhisperKeyTests/WhisperKeyTests.swift` | Checks dos estados visuais, temporização e gates de apresentação/permissão |
| Modificar | `docs/specs/06-floating-ui.md` | Contrato final de layout, acessibilidade e arbitragem/ocultação |
| Modificar | `docs/specs/07-permissions.md` | Menu e recuperação correspondentes à implementação |
| Modificar | `docs/specs/08-testing.md` | Matriz visual/foco, casos de timer e evidência necessária |
| Modificar | `docs/architecture.md` | Responsabilidade de apresentação entre app/coordinator/painel |
| Criar | `docs/testing/UI-REFINEMENT-EVIDENCE.md` | Capturas antes/depois, ambiente, matriz com PASS/FAIL/NOT RUN |

`HotkeyMonitor.swift`, `AudioRecorder.swift`, `WhisperTranscriber.swift` e `TextInjector.swift` são integrações lidas, sem mudança planejada de algoritmo. `project.yml`, plist e xcodeproj devem ficar iguais salvo necessidade demonstrada de incluir arquivo/teste; não é preciso novo target de UI nem snapshot dependency. A identidade de assinatura, bundle ID e diretório build são invariantes.

Se a arquitetura mantiver todo feedback da atividade apenas no HUD, pode reduzir a alteração do coordinator; deve ainda resolver colisão entre seus eventos e os do AppDelegate. A criação de arquivo Swift adicional não é requisito: as quatro fontes existentes comportam o refinamento.

## Riscos específicos e mitigação

| Risco | Impacto/probabilidade | Evidência e mitigação |
|---|---|---|
| HUD rouba foco após redesign | Alto/média | `.nonactivatingPanel` e `ignoresMouseEvents=true` são garantias existentes; manter. Testar frontmost/caret em TextEdit e Chromium, tela cheia e outra Space |
| Timer antigo oculta gravação | Alto/alta | `showTemporarily` nunca cancela Task. Dono único da ocultação temporária com cancelamento e guard contra tarefa obsoleta; regressão ready → listening antes de 2 s |
| Ready/Check encobre estado real | Alto/média | AppDelegate e coordinator escrevem no mesmo painel sem prioridade. Check durante recording/transcribing deve manter atividade visível; estado de configuração permanece no menu |
| Revogação durante captura deixa sessão incoerente | Alto/média | `refreshPermissionState` para hotkey, mas não cancela coordinator; release pode deixar de chegar. Expor como risco de integração existente; testar. Não chamar cancel durante transcrição sem tratar worker detached, que hoje pode completar depois de reset |
| Permissão negada sem caminho de recuperação | Médio/alta | Menu só Enable/Check; não há abertura explícita de Ajustes por permissão. Reusar menu e APIs nativas após clique; sem novos direitos ou prompts automáticos |
| Tooltip fica obsoleto quando falta muda | Médio/alta | Timer só entra ao iniciar/parar monitor. Comparar estado de permissões e atualizar menu/tooltip em mudanças parciais, sem refresh visual ruidoso a cada segundo |
| Erro longo ilegível | Médio/alta | Mensagens de paths/stderr caem em 280×64 e duas linhas. Definir título conciso e recuperação legível no menu; teste sintético com caminho comprido, sem executar Whisper |
| Acessibilidade apenas visual | Médio/média | Há accessibilityDescription no ícone, mas nenhuma rotulagem explícita de status/progresso ou adaptação de reduce transparency/motion. Verificar VoiceOver/Accessibility Inspector; informar estados sem forçar foco nem anunciar repetidamente por polling |
| Tela errada ou conteúdo fora da área útil | Médio/média | `NSScreen.main` é recalculado por show e tamanho fixo. Fixar critério da tela e limitar geometria por visibleFrame; testar monitor secundário, scaling e Dock lateral |
| Quebra da identidade TCC | Alto/baixa | Incidente anterior de bundles duplicados documentado. Sempre `-derivedDataPath build`, identidade existente; nenhum reset TCC ou novo bundle para captura visual |

A revogação de permissão e o worker detached têm implicação além da estética. Registrar resultado e tratar somente o necessário para não mentir na apresentação; se exigir redesenhar cancelamento do motor, separar como problema do fluxo básico e não introduzir silenciosamente no plano visual. A interface não pode declarar idle enquanto gravação continua.

## Validação possível sem nova infraestrutura

| Tipo | Casos e evidência | Limite |
|---|---|---|
| XCTest existente | Tabela de títulos/ícones/busy e acessibilidade dos cinco estados; dimensões/conteúdo com erro longo | Ainda não existe teste de UI; estes casos serão adicionados ao target atual |
| Regressão de apresentação | ready temporário → listening antes de timeout; aviso velho não oculta novo; hide explícito limpa tarefa; Check durante busy não substitui atividade | Testar pequeno contrato de apresentação/controller, sem microfone ou inferência; preservar testes existentes |
| Snapshot local nativo | Hospedar view com estados sintéticos em `NSHostingView`/preview de debug e capturar Light/Dark; no mínimo ready, listening, transcribing, inserting, failure longo | Screenshot prova layout; não prova foco/permissão. Nenhum pacote de snapshot é necessário |
| App rodando | TextEdit e Chromium com caret; transições, menu via teclado, Escape/Quit; Spaces/tela cheia/segundo monitor; VoiceOver, aumentar contraste, reduzir transparência/movimento | Usar app assinado existente e dados sintéticos para estados; não resetar permissões reais do usuário para criar screenshot |
| Evidência funcional | Fluxo real Right Option e clipboard restaurado + tempo/ambiente/capturas e pendências honestas | Não declarar CORE-001 finalizado com mock ou evidência antiga; frase humana ainda pendente no documento M0 |

Porta local descoberta no README e SPEC-008:

```sh
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
```

`xcodegen generate` só se manifesto/projeto exigir regeneração. Não há workflow CI, npm, Vercel ou Codespace neste aplicativo nativo inspecionado. Nenhum gate executado nesta fase de planejamento. Para UI-only, não baixar modelo nem chamar API de IA paga.

## Decisões que a síntese deve fechar

1. Manter menu nativo + HUD passivo como superfícies; escolher copy e hierarquia concretas, sem introduzir nova janela por hipótese.
2. Definir estados visuais e precedência entre atividade, ready e permissões; escolher um único dono do timeout com regressão executável.
3. Definir tamanho/posição adaptáveis e tratamento de mensagens extensas; testar a tela de referência e alternativas acessíveis.
4. Definir recuperação por permissão no menu e como status se atualiza sem substituir ditado em curso.
5. Definir capturas/checagens e critério de aprovação visual; implementação de output permanece fora deste plano.
