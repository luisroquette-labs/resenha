# M1.2 — Sistema de marca do Resenha

1. [x] Aprovar o V2 com duas vozes, pulso central, wordmark em caixa baixa e ponto final.
2. [x] Substituir `ResenhaMark` e adicionar `ResenhaMenuBar`, `ResenhaLockup` e `AppIcon`.
3. [x] Aplicar a marca no HUD, menu bar, onboarding, Sobre e metadados do aplicativo.
4. [x] Rodar o gate nativo pelo `mac-gate` e validar o app em execução.
5. [x] Fazer símbolo e menu bar ressoarem com o nível real do microfone, respeitando Reduzir Movimento.

## Evidência

- Conceito aprovado: `docs/brand/concepts/resenha-brand-sheet-v2.png`.
- Fontes vetoriais: `resenha-mark-v2.svg` e `resenha-lockup-v2.svg`.
- `mac-gate xcodebuild ... test`: 46 testes, 0 falhas.
- Build local: `Resenha.app` em execução; `AppIcon.icns` e `Assets.car` compilados.
- Fixture: `build/ui-fixtures/hud-listening-light.png` confirma símbolo legível no HUD real.

## Fora

Manual de marca completo e peças da App Store.
