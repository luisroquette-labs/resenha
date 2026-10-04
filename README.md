# Resenha

**Fale. O Resenha escreve.** Ditado push-to-talk nativo para macOS, gratuito,
local e de código aberto. Requer Apple Silicon e macOS 14 ou posterior.

Windows: MVP em desenvolvimento; download indisponível enquanto as evidências
de execução física, assinatura, scan e distribuição estiverem pendentes.

Segure o atalho, fale e solte. O Resenha grava só enquanto a combinação está
pressionada, transcreve com whisper.cpp no próprio Mac e devolve o texto ao
campo ativo com a permissão de Acessibilidade.

## O que já funciona no macOS

- Ditado em português, inglês e espanhol, com anglicismos e vocabulário pessoal.
- Whisper embarcado, acelerado por Metal em Apple Silicon; nenhuma instalação de Python.
- Áudio transitório, clipboard imediato e últimos 10 textos locais e opcionais.
- HUD compacto com nível real do microfone, sons configuráveis e feedback de erro.
- Atalho livre configurado dentro do app, inclusive Option direita isolada.
- Sem conta, anúncios, analytics, backend ou chave de API.

## Privacidade

O áudio nunca sai do Mac. O modelo de 181 MB é baixado uma vez da distribuição
oficial do whisper.cpp e validado por tamanho e SHA-256. Resenha não coleta
dados e não inclui SDKs de rastreamento. Leia a [política de privacidade](docs/PRIVACY.md).

## Rodar o projeto

Requisitos: macOS 14+, Xcode 26+, XcodeGen, CMake e Mac Apple Silicon.

```sh
git submodule update --init --recursive
./Scripts/build-whisper-framework.sh
xcodegen generate
~/.local/bin/mac-gate xcodebuild \
  -project WhisperKey.xcodeproj \
  -scheme WhisperKey \
  -destination 'platform=macOS' \
  -derivedDataPath build test
open build/Build/Products/Debug/Resenha.app
```

O target `WhisperKey` gera um único app de distribuição direta com bundle ID
`br.com.luisroquette.Resenha`. Contribuidores podem selecionar seu próprio
Development Team localmente sem alterar o código versionado.

## Gerar o DMG oficial

O release usa `Developer ID`, Hardened Runtime e notarização Apple, sem App
Sandbox. O DMG contém o aplicativo e o atalho `Applications`.

```sh
~/.local/bin/mac-gate ./Scripts/build-release-dmg.sh
./Scripts/notarize-release-dmg.sh build/direct/Resenha-1.0.0-arm64.dmg
```

O segundo comando envia o DMG à Apple usando o perfil de Keychain definido em
`RESENHA_NOTARY_PROFILE` (padrão: `notchagent-notary`) e valida o ticket com
Gatekeeper. Cada artefato recebe um arquivo `.sha256` correspondente.

## Arquitetura

```text
Atalho global escolhido no Resenha
  → AVFoundation (PCM mono, 16 kHz)
  → whisper.cpp + Metal
  → pós-processamento determinístico
  → NSPasteboard + Command-V no campo ativo
```

A inserção usa Acessibilidade para devolver o foco ao aplicativo original e
simular `Command + V`. Microfone, Monitoramento de Entrada e Acessibilidade são
explicados e solicitados separadamente.

## Contrato Windows — implementação pendente

Arquitetura aceita: C# 14/WPF, SDK .NET `10.0.401`, Desktop Runtime `10.0.12`
self-contained e whisper.cpp local como CLI; nenhum Windows App SDK, backend,
conta ou API paga. O runtime do instalador dispensa SDK/.NET pré-instalado.

Alvos de compatibilidade: Windows 10 Home/Pro 22H2 `10.0.19045` e Windows 11
Home/Pro 25H2 mínimo `10.0.26200`, x64. Windows 10 é um alvo de QA física,
não uma afirmação de suporte Microsoft/.NET. Requer AVX2, FMA, F16C, SSE4.2,
estado AVX habilitado pelo sistema, 8 GiB RAM e 1 GiB livre além do payload
medido. ARM, x86, Server, S-mode e versões anteriores estão fora da matriz.

O atalho inicial é Left Ctrl + Left Alt + Space, configurável sem usar AltGr.
PT-BR/EN/ES são explícitos; áudio/modelo/inferência ficam no dispositivo.
Windows não cria histórico de transcrições no disco. O texto completo é
copiado antes de uma tentativa de Ctrl+V; foco alterado, campo protegido ou
falha de colagem exigem recuperação manual. Despacho de input não comprova
aceitação pelo editor e não garante inserção automática.

Leia [SPEC-023](docs/specs/23-windows-mvp.md),
[protocolo físico](docs/testing/WINDOWS-MVP-EVIDENCE.md) e
[protocolo de release](docs/testing/WINDOWS-RELEASE-EVIDENCE.md).
Host físico Windows 10/11, certificado confiável e formulário/redirect Windows
dedicados ainda são pré-requisitos pendentes, não recursos comprovados.

```sh
~/.local/bin/mac-gate node --test Scripts/windows-docs.test.mjs
```

Esse comando verifica contratos documentais; não executa Windows nem valida
microfone, instalador, assinatura ou publicação. Os comandos Windows previstos
ficam na spec e devem falhar quando ferramentas/evidências estiverem ausentes.

## Desenvolvimento orientado por especificação

As decisões verificáveis ficam em [`docs/specs`](docs/specs), as tarefas em
[`docs/tasks`](docs/tasks) e as evidências em [`docs/testing`](docs/testing).
Mudanças de comportamento começam pela spec e terminam com testes e validação
física no app.

## Site local

```sh
node Scripts/site.mjs --serve --port 4173 --prefix /
~/.local/bin/mac-gate node --test Scripts/site.test.mjs
```

Abra `http://127.0.0.1:4173/`. O site é estático, sem analytics ou backend.

## Licença

[MIT](LICENSE). Dependências e modelos: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
