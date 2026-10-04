# Evidência de submissão — Resenha 1.0

Data: 2 de outubro de 2026

## Build 1 submetido — obsoleto

- Archive: `build/archive/Resenha-1.0.0-b1-r2.xcarchive`
- Bundle: `br.com.luisroquette.Resenha`
- Versão/build: `1.0.0 (1)`
- Arquitetura: arm64
- macOS mínimo: 14.0
- Assinatura atual: Apple Development, válida para validação local
- Sandbox: app sandbox, entrada de áudio e cliente de rede; nenhuma outra entitlement de distribuição
- `PrivacyInfo.xcprivacy`: presente
- `ITSAppUsesNonExemptEncryption`: `false`

Este archive antecede a correção do contrato de Serviço e **não é candidato a
release**. Em 3 de outubro de 2026, o App Store Connect indicava
`WAITING_FOR_REVIEW` com publicação `AFTER_APPROVAL`; essa combinação permitiria
publicar um binário obsoleto. Nenhuma retirada, troca de build ou mudança do modo
de publicação foi executada sem aprovação explícita do proprietário.

O próximo candidato deve ser `1.0.0 (2)` ou superior, usar lançamento manual e
passar os gates automatizados e físicos no binário exato. A trava legível por
ferramentas está em `AppStore/release-state.json`.

## Gates históricos do build 1

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

## Registro histórico anterior

O upload inicial autenticou no App Store Connect e recebeu HTTP 200, mas retornou
`IDEDistribution.DistributionAppRecordProviderError.missingApp`. Esse estado foi
superado pela submissão posterior do build 1 e não descreve o gate atual.
