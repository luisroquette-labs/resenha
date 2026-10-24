# Resenha 1.1.0 — diagnóstico de prontidão das lojas

Verificado em 24 de outubro de 2026. Este documento avalia a possibilidade de
submissão; não autoriza nem registra uma submissão.

## Veredito

| Canal | JEV permitido? | Estado desta versão | Próximo gate |
| --- | --- | --- | --- |
| Mac App Store | Sim, com consentimento e declaração de compartilhamento com IA | Não pronta: o binário direto usa Acessibilidade e não está no App Sandbox | portar a 1.1.0 para a edição sandboxada baseada em `NSServices`, habilitar `network.client` e validar o archive exato |
| Microsoft Store | Sim, com política de privacidade e opt-in; declarar IA por prudência | Não pronta: a implementação JEV existe somente no app macOS; a versão Windows pública ainda não contém esse fluxo | integrar o mesmo contrato textual no Windows, gerar instalador assinado e passar WACK/certificação |

## Apple

- O Mac App Store exige App Sandbox. A edição direta atual não é submetível
  porque a inserção usa Acessibilidade e eventos para devolver texto ao campo.
- Existe uma edição histórica sandboxada baseada em Serviço do macOS, com
  `com.apple.security.app-sandbox`, `device.audio-input` e `network.client`.
  Ela precisa receber a implementação e os testes da 1.1.0 antes de novo upload.
- A Apple exige revelar claramente o compartilhamento de dados com IA de
  terceiros e obter permissão explícita. O fluxo atual atende a base técnica:
  começa desligado, envia texto e alternativas somente após consentimento,
  nunca envia áudio e permite revogar a chave.
- Antes da submissão, App Store Connect deve declarar **Other User Content**,
  vinculado ao usuário pela conta da chave do provedor, usado para
  **App Functionality** e não para tracking. As notas de revisão devem citar
  OpenRouter, TypeSafe/JEV e fornecer uma chave de revisão válida ou um modo
  demonstrável que permita avaliar o recurso.
- A página pública Apple `id6818779976` retornou HTTP 404 nesta verificação;
  o estado interno do App Store Connect não foi confirmado sem uma sessão
  autenticada.

Fontes oficiais: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/),
[App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) e
[informações para revisão](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/).

## Microsoft

- A listagem pública `9P4M40MZH627` respondeu HTTP 200 e continua disponível.
- A política 10.5 exige política de privacidade, opt-in antes de enviar dados a
  terceiros, explicação do uso/compartilhamento e uma forma de retirar o
  consentimento. O contrato do JEV no macOS já segue esses princípios.
- A política 11.16 trata conteúdo dinâmico criado por IA. O JEV escolhe entre
  opções locais e não gera texto livre, mas a submissão deve declarar o uso de
  IA por prudência. Se a Microsoft enquadrar o resultado como conteúdo
  generativo, será necessário também um canal explícito para reportar saída
  inadequada ao desenvolvedor.
- A conexão HTTPS comum não exige capacidade restrita. O pacote Windows precisa
  declarar apenas as capacidades realmente usadas e continuar funcional sem
  internet, preservando a transcrição local quando o JEV estiver indisponível.

Fontes oficiais: [Microsoft Store Policies 7.20](https://learn.microsoft.com/windows/apps/publish/store-policies-and-code-of-conduct),
[capabilities](https://learn.microsoft.com/windows/apps/package-and-deploy/app-capability-declarations)
e [certificação MSI/EXE](https://learn.microsoft.com/windows/apps/publish/publish-your-app/msi/app-certification-process).

## Claims e marca

O lema **“Tipo o Wispr, mas grátis e com JEV.”** fica no site, acompanhado da
declaração de independência já existente. Para reduzir risco de metadata ou
marca, as fichas das lojas devem descrever os recursos do Resenha sem usar o
nome do concorrente no título, subtítulo, palavras-chave ou screenshots.
