# SPEC-022 — Distribuição direta em DMG

Status: autorizado em 2026-10-03

## Decisão

O único Resenha para macOS será distribuído diretamente em um `.dmg`, como o
Willow Voice no Mac. Não haverá uma variante reduzida para a Mac App Store.

## Contrato do artefato

- `Resenha.app` assinado com `Developer ID Application` e Hardened Runtime.
- Aplicativo arm64, macOS 14 ou posterior, sem App Sandbox.
- DMG contém `Resenha.app` e um atalho `Applications` para `/Applications`.
- DMG é assinado, enviado ao serviço de notarização da Apple e recebe staple.
- Gatekeeper aceita o DMG; assinatura, bundle ID, versão, arquitetura,
  ausência de sandbox e ticket de notarização são validados automaticamente.
- SHA-256 acompanha cada release pública.

## Candidato local e instalação recuperável

`xcodebuild test` produz um host Debug que pode conter XCTest, `Testing.framework`, bibliotecas de debug e permissões de depuração. Mesmo assinado, esse host não é um candidato instalável. O gate nativo continua obrigatório via `~/.local/bin/mac-gate`; depois dele, `Scripts/build-release-dmg.sh` faz archive/export com configuração Release em uma saída nova, sem reutilizar/apagar artefatos anteriores.

`Scripts/validate-release-dmg.sh` concentra a validação usada pelo app (`--app /caminho/Resenha.app [SHA]`), DMG e instalador: bundle ID, macOS 14, arm64, Developer ID/team, assinatura profunda estrita, Hardened Runtime e entitlements vazios. Rejeita explicitamente XCTest/XCT/XCUI/Testing, `*.debug.dylib`, `__preview.dylib`, `get-task-allow=true`, `testmanagerd` e `coresymbolicationd`. O Release inclui `Contents/Resources/ResenhaBuild.plist` selado pela assinatura com SourceSHA, SourceDiffSHA256 e Configuration=Release; mudanças nas fontes durante o build abortam a produção do artefato.

Instalação local autorizada usa três argumentos absolutos/explícitos:

```sh
Scripts/install-local-release.sh /caminho/export/Resenha.app <source-sha-completo> /caminho/evidencia
```

O instalador valida antes da troca, copia para staging no mesmo volume, compara manifestos SHA-256 e encerra graciosamente somente a instância cujo executável corresponde ao destino. Mais de um processo ou um processo de outro bundle bloqueia a troca. A instalação anterior é movida para `/Applications/Resenha-backups/Resenha-<UTC>-<SHA>.<id>/previous-Resenha.app`; o backup nunca é removido automaticamente. O app instalado é validado novamente, aberto e conferido por PID/caminho/hash.

ERR/INT/TERM tentam restaurar o bundle anterior e sua abertura. Um candidato já colocado é preservado como `failed-candidate.app`; o backup e o staging permanecem disponíveis. Se encerramento/restauração falhar, o script reporta o caminho recuperável sem apagar o que restou. `Scripts/release-install.test.sh`, executado via `mac-gate`, usa somente roots temporários injetáveis em modo teste; prova marcadores proibidos, SHA/hash divergentes, múltiplos processos e rollback antes/depois da troca. Fixtures substituem apenas assinatura/processos/abertura; a assinatura e a abertura do Release real têm verificação separada.

Uma instalação local não representa notarização, publicação ou prova física de ditado. Registrar app/hash, gate, backup, PID, permissões e cada observação física em [UI-REFINEMENT-EVIDENCE](../testing/UI-REFINEMENT-EVIDENCE.md). Não conceder TCC automaticamente nem tratar um processo vivo como prova de inserção ou pass-through.

## Publicação

O instalador público fica em uma GitHub Release versionada. O site só ativa o
botão de download para uma URL HTTPS imutável depois da validação do artefato.
