# SPEC-021 — Release hardening em feedback loop

## Status

Implementada localmente; gates físicos e mutações da App Store permanecem pendentes.
Esta especificação complementa e, quando houver conflito,
torna mais estritas as SPEC-001, SPEC-002, SPEC-008, SPEC-016, SPEC-017, SPEC-018,
SPEC-019 e SPEC-020.

## Objetivo

Transformar o build atual do Resenha em uma release distribuível e verificável: o
atalho inicia e encerra somente a sessão correta, a transcrição local termina dentro de
limites definidos, o texto entra no campo solicitante, dados locais permanecem íntegros,
e o binário submetido é exatamente o binário validado.

## Método obrigatório

Cada fase segue Planejamento → Revisão → Execução → Teste. Uma fase só avança após:

1. critérios funcionais da fase aprovados;
2. testes automatizados verdes;
3. revisão independente da implementação;
4. evidência atual substituir qualquer evidência histórica incompatível.

Falha em qualquer gate reinicia a fase a partir do planejamento da correção.

## Invariantes de publicação

- Nenhum build obsoleto pode ser liberado automaticamente.
- O identificador do build validado deve coincidir com o build anexado à versão.
- O atalho padrão não pode conflitar com o modificador VO do VoiceOver.
- A personalização deve preservar um único contrato entre UI, monitor e Serviço.
- O caminho principal de inserção é o Serviço do macOS; clipboard é recuperação e
  sempre contém a transcrição mais recente.
- O app nunca pode gravar indefinidamente nem deixar inferência sem limite observável.
- Release ignora overrides de ambiente para modelo; Debug pode aceitá-los para testes.
- Modelo, histórico, licenças e dados temporários obedecem instalação e limpeza atômicas.
- Testes usam identidade e container separados do app distribuído.

## Fases e gates

### Fase 1 — Publicação e fluxo principal

Define um `NSKeyEquivalent` válido, elimina o caminho que promete inserção sem uma
requisição de Serviço, sincroniza o contrato de atalho e testa Serviço real com
requisição e pasteboard. O estado remoto da App Store é somente lido; retirar ou
substituir uma submissão exige confirmação explícita do dono.

### Fase 2 — Limites de execução

Limita gravação e Serviço, associa soltura à tecla/modificadores armados, interrompe
Whisper por callback cooperativo e descarrega o contexto após ocioso/pressão de memória.

### Fase 3 — Integridade local e distribuição

Revalida SHA-256 antes de declarar o modelo pronto, instala por substituição atômica,
permite cancelar/retomar download, apaga resíduos e quarentenas, e inclui todos os
avisos/licenças no bundle.

### Fase 4 — Acessibilidade, layout e isolamento de QA

Entrega contraste WCAG AA, tipografia semântica e janela redimensionável, posiciona o
HUD no monitor da janela alvo com fallback determinístico, e separa bundle/container de
Debug e testes. VoiceOver permanece gate físico explícito, nunca inferido por unidade.

### Fase 5 — Produto, site e release final

Histórico inicia desligado; biblioteca de sons oferece busca e favoritos; mídia mostra
interação real; site recebe metadados sociais/SEO e imagens lazy; assets da loja evitam
humor como mensagem principal; validador deriva versão/build do archive. Specs e
evidências são consolidadas para o SHA final.

Implementação: histórico opt-in em instalação limpa; busca/favoritos locais; demos
geradas quadro a quadro a partir de fixtures SwiftUI, com cursor, tecla, HUD responsivo
e inserção progressiva; screenshot 05 dedicada a clipboard/histórico opcional; metadados
SEO/social/schema e lazy loading; validação cruzada de fonte, archive e estado de release.
O archive carrega `ResenhaSourceCommit`: deve ser um commit Git real de 40 caracteres,
igual ao manifesto do candidato, no HEAD, e sem divergências nas fontes relevantes.
Builds `DEVELOPMENT`, árvores sujas, commits inexistentes e archives antigos são rejeitados.
Quando a preferência legada de histórico estiver ausente, uma migração única apaga o
arquivo canônico e quarentenas antes de marcar conclusão; falhas são repetidas no próximo launch.

## Critérios de aceitação

- SERVICE-001–003 passam no host de teste e há roteiro físico para TextEdit, Chromium,
  Terminal e VoiceOver.
- Uma soltura estranha não encerra a sessão; a soltura armada encerra exatamente uma vez.
- Gravação e inferência possuem deadlines testados e produzem erro recuperável.
- O modelo adulterado nunca entra em estado pronto; atualização falha preserva o modelo
  anterior verificado.
- `Limpar textos` remove histórico canônico e quarentenas.
- Archive Release não contém `WHISPER_MODEL_PATH` nem omite licenças obrigatórias.
- Debug/testes coexistem com `/Applications/Resenha.app` sem colisão de instância ou
  escrita no container de produção.
- Texto essencial alcança contraste mínimo 4,5:1 e controles continuam utilizáveis com
  texto ampliado.
- O site expõe canonical, Open Graph, Twitter Card e `SoftwareApplication`.
- O gate final valida o archive exato, seus assets e o número real de build.

## Não objetivos

- IA de reescrita, backend, login, billing ou telemetria.
- Publicar automaticamente ou alterar a submissão remota sem confirmação explícita.
- Windows nesta release macOS.
