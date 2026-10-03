# Feature: Ajustes nativos do Resenha

## Status

Concluído em 02/10/2026.

## Entregue

- Geral: iniciar ao login via `SMAppService` e mostrar/ocultar o HUD.
- Atalho: cinco combinações globais seguras, persistentes e aplicadas sem reiniciar.
- Áudio: microfone padrão real e acesso deliberado aos Ajustes de Som.
- Sobre: versão, processamento local e licença open source.
- Menu principal apresentado como Resenha, com Ajustes, configuração, Sobre e encerramento.

## Simplificação deliberada

O M1 usa uma lista curta de atalhos validados. Captura arbitrária entra quando houver detecção confiável de conflitos com atalhos do macOS.

## Evidência

- `mac-gate xcodebuild ... test`: 40 testes, 0 falhas.
- App assinado executado com um processo.
- `Ajustes…` aberto duas vezes: uma janela `Ajustes do Resenha`, sem duplicação.
- Painéis Geral, Atalho, Áudio e Sobre confirmados na árvore de acessibilidade e visualmente.
- Atalho alterado em runtime para `Control + Espaço`; instrução do menu atualizada; padrão `Option direita` restaurado.
