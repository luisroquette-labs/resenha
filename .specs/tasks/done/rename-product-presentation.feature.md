# Feature: identidade pública Resenha no bundle macOS

## Status

Concluído em 02/10/2026.

## Entregue

- Produto e artefato: `Resenha.app`.
- Executável e processo: `Resenha`.
- Nome público, menus e janelas: Resenha.
- Módulo Swift interno preservado como `WhisperKey` para compatibilidade dos testes.
- Bundle identifier preservado como `br.com.luisroquette.WhisperKey` para continuidade das permissões.

## Ajustes técnicos necessários

- Scheme de teste explícito no XcodeGen.
- `TEST_HOST` e `BUNDLE_LOADER` apontando para `Resenha.app/Contents/MacOS/Resenha`.
- `PRODUCT_MODULE_NAME=WhisperKey` separado de `PRODUCT_NAME=Resenha`.

## Evidência

- Gate: 40 testes, 0 falhas.
- `codesign --verify --deep --strict`: sucesso.
- Spotlight: `kMDItemDisplayName=Resenha.app`.
- Info.plist: `CFBundleExecutable=Resenha`, `CFBundleDisplayName=Resenha`.
- Reabertura repetida: um processo `Resenha`.
- Menu: `Resenha — Ready`; permissões preservadas e status `Ready`.
- Computer Use vinculou o app pelo nome `Resenha` e confirmou a janela `Ajustes do Resenha`.

## Histórico da correção

A primeira tentativa de alterar somente `PRODUCT_NAME` expôs três vínculos do XcodeGen: ação de teste, test host e nome do módulo. A migração final separou explicitamente esses contratos e passou integralmente.
