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

## Exportação de distribuição

Após a aceitação do acordo Apple, o Xcode exportou `Resenha.pkg` com sucesso:

- SHA-256: `228fc7771f5838903f5e8cf17506922b962b6412d2c20d72d901c887f3ac9c5d`
- App: `Cloud Managed Apple Distribution`
- Installer: `3rd Party Mac Developer Installer`
- Profile: `Mac Team Store Provisioning Profile: br.com.luisroquette.Resenha`
- Assinatura e conteúdo do package: verificados pelo `pkgutil`

## Gate externo atual

O upload autenticou no App Store Connect e recebeu HTTP 200, mas retornou
`IDEDistribution.DistributionAppRecordProviderError.missingApp`. A consulta exata
por `br.com.luisroquette.Resenha` encontrou zero registros. É necessário criar
o app record no App Store Connect antes de repetir o mesmo upload.
