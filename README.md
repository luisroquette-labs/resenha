# Resenha

**Fale. O Resenha escreve.** Ditado push-to-talk nativo para macOS, gratuito,
local e de código aberto. Requer Apple Silicon e macOS 14 ou posterior.

Segure o atalho, fale e solte. O Resenha grava só enquanto a combinação está
pressionada, transcreve com whisper.cpp no próprio Mac e devolve o texto ao
campo ativo com a permissão de Acessibilidade.

## O que já funciona

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
