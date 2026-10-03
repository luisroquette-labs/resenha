# Evidência de submissão — Resenha 1.0

Data: 2 de outubro de 2026

## Binário candidato

- Archive: `build/archive/Resenha-1.0.0-b1-r2.xcarchive`
- Bundle: `br.com.luisroquette.Resenha`
- Versão/build: `1.0.0 (1)`
- Arquitetura: arm64
- macOS mínimo: 14.0
- Assinatura atual: Apple Development, válida para validação local
- Sandbox: app sandbox, entrada de áudio e cliente de rede; nenhuma outra entitlement de distribuição
- `PrivacyInfo.xcprivacy`: presente
- `ITSAppUsesNonExemptEncryption`: `false`

## Gates concluídos

- `mac-gate xcodebuild … test`: 59 testes, zero falhas
- Inferência real: whisper.cpp embarcado, Metal e modelo oficial local
- `Scripts/validate-app-store-package.sh`: pacote aprovado
- Screenshots: 10/10 em 2880 × 1800, PNG, sem alpha
- Credenciais: nenhuma chave privada ou prefixo conhecido nos ativos da loja

## Gate externo atual

`xcodebuild -exportArchive` chegou à Apple e retornou três bloqueios ligados à conta:

1. `PLA Update available` — o titular precisa aceitar o acordo atualizado da Apple.
2. Certificado `Mac Installer Distribution` ausente.
3. Provisioning profile de `br.com.luisroquette.Resenha` ausente.

Depois do acordo, Xcode pode criar os dois itens de assinatura com a conta do titular. O archive deve então ser refeito, exportado, validado e enviado antes de vincular o build à versão.
