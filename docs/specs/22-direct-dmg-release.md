# SPEC-022 — Distribuição direta em DMG

Status: autorizado em 2026-10-03

## Decisão

O Resenha será distribuído diretamente em um `.dmg`, como o Willow Voice no
Mac, sem reduzir o canal da Mac App Store. Os dois artefatos saem da mesma fonte,
com fronteiras de permissão e inserção específicas de cada canal.

## Contrato do artefato

- `Resenha.app` assinado com `Developer ID Application` e Hardened Runtime.
- Aplicativo arm64, macOS 14 ou posterior, sem App Sandbox.
- DMG contém `Resenha.app` e um atalho `Applications` para `/Applications`.
- DMG é assinado, enviado ao serviço de notarização da Apple e recebe staple.
- Gatekeeper aceita o DMG; assinatura, bundle ID, versão, arquitetura,
  ausência de sandbox e ticket de notarização são validados automaticamente.
- SHA-256 acompanha cada release pública.

## Publicação

O instalador público fica em uma GitHub Release versionada. O site só ativa o
botão de download para uma URL HTTPS imutável depois da validação do artefato.
