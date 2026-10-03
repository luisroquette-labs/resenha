# Feature: onboarding nativo de permissões do Resenha

## Status

Concluído em 02/10/2026. Este contrato sucede apenas a decisão de UI menu-only da SPEC-007; consentimento explícito e ausência de loops permanecem obrigatórios.

## Entregue

- Uma única janela nativa, em PT-BR, para Microfone, Acessibilidade e Monitoramento de Entrada.
- Abertura automática apenas uma vez quando houver permissão faltante.
- Reabertura explícita pelo menu `Configurar Resenha…`.
- Estado real, finalidade e atalho para o painel correspondente de cada permissão.
- CTA explícito para solicitar permissões; nenhuma solicitação automática ou repetitiva.
- Atualização pelo snapshot periódico já usado pelo app.

## Fora de escopo preservado

- Target, bundle identifier e artefato assinado ainda usam `WhisperKey`.
- Settings completo, escolha de modelo, login, histórico e backend não foram adicionados.
- Hotkey, áudio, Whisper e injeção de texto não foram alterados.

## Evidência

- Política de primeira apresentação e identidade única da janela cobertas por testes.
- `mac-gate xcodebuild ... test`: 37 testes, 0 falhas.
- App assinado executado localmente: um processo e uma janela `Configurar Resenha`.
- Inspeção visual e árvore de acessibilidade confirmaram as três permissões, estados e CTA.
