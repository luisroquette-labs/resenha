# Screenshots da Mac App Store

Os arquivos em `pt-BR/` são gerados por `Scripts/export-app-store-screenshots.sh` a partir dos renders nativos produzidos pelos testes SwiftUI.

- Formato: PNG sem canal alpha
- Dimensão: 2880 × 1800 px (16:10)
- Quantidade: 10 (máximo aceito pela App Store)
- Interface: somente fixtures reais do Resenha; títulos e fundos são composição editorial
- Fonte oficial: [Screenshot specifications — Apple Developer](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)

Regenerar:

```sh
Scripts/export-app-store-screenshots.sh
```
