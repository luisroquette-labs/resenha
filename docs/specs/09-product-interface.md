# SPEC-009 — Interface de produto do Resenha

## Status

Implementada no app macOS; empacotamento de distribuição e validações físicas pendem separadamente.

## Problema

O M0 prova o fluxo de ditado, mas ainda não apresenta o Resenha como um produto configurável. Um usuário novo precisa entender o atalho, conceder permissões, escolher suas preferências e reconhecer o estado do app sem depender do Terminal.

## Objetivo

Entregar uma experiência nativa, pequena e demonstrável:

`instalar → configurar → testar → ditar → ajustar`

## Princípios

1. **Invisível durante o trabalho:** menu bar + HUD continuam sendo a experiência diária.
2. **Configuração deliberada:** onboarding e Ajustes aparecem quando o usuário precisa configurar ou recuperar algo.
3. **Real antes de bonito:** controles só parecem ativos quando a função existe e foi validada.
4. **Local visível:** o usuário sempre sabe quando áudio e texto ficam no Mac ou saem para um provedor.
5. **Nativo:** SwiftUI/AppKit, componentes do sistema, SF Symbols, teclado completo, VoiceOver e aparências do macOS.

## Identidade visual

- Nome público: **Resenha**.
- Personalidade: brasileira, direta, calorosa e tecnicamente confiável.
- Base: papel quente no claro, grafite no escuro, títulos editoriais serifados e texto funcional do sistema.
- Acento único: verde-névoa suave, inclusive durante a captura; erro nunca depende de vermelho.
- Forma memorável: vozes espelhadas, anéis de ressonância e waveform horizontal vivo e compacto.
- Sem glassmorphism decorativo excessivo, roxo, gradientes de IA, mosaico de cards ou aparência de dashboard web.

### Marca gráfica

- O símbolo representa duas vozes espelhadas ao redor de um pulso central; a assinatura usa `resenha` em caixa baixa e ponto final.
- `ResenhaMark` precisa continuar legível a 18 pt, em uma cor e nos modos claro/escuro.
- HUD, menu bar, onboarding e Sobre usam a mesma geometria e o mesmo verde-névoa.
- `ResenhaMenuBar` é um template monocromático e preserva o contraste nativo do macOS em qualquer aparência.
- `ResenhaLockup` aparece apenas onde há largura suficiente; superfícies compactas usam somente o símbolo.
- `AppIcon` deriva do símbolo branco sobre uma base grafite, sem gradiente, texto ou detalhe que desapareça em 16 pt.

## Arquitetura de superfícies

### 1. Onboarding

Janela única de 680 × 500 pt, exibida uma vez quando a configuração está incompleta. Ela apresenta a promessa local, Microfone, Monitoramento de Entrada e instalação do modelo local, cada um com motivo, estado real e destino nomeado. O Resenha não pede permissão de Acessibilidade. A recuperação durável permanece no menu.

O onboarding não pede conta, API paga, avaliação ou configuração avançada.

### 2. HUD flutuante

Estados:

| Estado | Conteúdo | Tratamento |
|---|---|---|
| Ouvindo | sinal verde-névoa, marca ressonante, cronômetro, waveform real | cápsula 340 × 72 pt |
| Transcrevendo | spinner, texto | cápsula compacta |
| Inserindo | spinner, texto | cápsula compacta |
| Pronto | confirmação breve | desaparece automaticamente |
| Erro | causa curta + recuperação | largura variável limitada |

Continua passivo, click-through, sem roubar foco e sem exibir transcrição.

### 3. Menu da barra

Ordem:

1. Estado atual e atalho.
2. Ação principal contextual: testar, conferir permissões ou abrir recuperação.
3. “Ajustes…” (`⌘,`) e “Configurar Resenha…”.
4. Diagnóstico somente quando houver erro.
5. Sobre e Encerrar.

Menus usam grupos pequenos, rótulos curtos e ícones uniformes quando presentes.

### 4. Ajustes

Janela nativa redimensionável, com barra lateral semântica e seção preservada enquanto a janela é reutilizada.

| Painel | Conteúdo | Marco |
|---|---|---|
| Geral | iniciar ao login, HUD, sons e histórico local opt-in | entregue |
| Atalho | escolher uma combinação segura e restaurar o padrão | entregue |
| Sons | buscar, favoritar, escolher e ouvir 70 confirmações locais curtas | entregue |
| Áudio | estado do microfone e explicação da captura local | entregue |
| Transcrição | idioma, modelo local e vocabulário pessoal | entregue |
| Sobre | versão, privacidade e links do projeto | entregue |

## Componentes

- `ResenhaLockup` e `ResenhaMark`: assinatura aprovada e símbolo compacto.
- `PermissionRow`: símbolo, nome, explicação, estado e ação.
- Seletor de atalho: presets seguros com descrição explícita.
- `AudioMeter`: waveform real com estado de silêncio e pico.
- `StatusBadge`: Pronto, Requer ação ou Planejado; significado também em texto.
- `Status details`: causa e recuperação sem revelar áudio, stderr ou texto ditado.

## Linguagem

PT-BR primeiro. Frases curtas e orientadas à ação:

- “Segure seu atalho para falar.”
- “Solte para escrever.”
- “Acesso ao Microfone necessário.”
- “A transcrição acontece neste Mac.”

Inglês entra por localização futura, não por mistura arbitrária na mesma tela.

## Acessibilidade

- Controles com alvo mínimo de 44 pt quando apropriado.
- VoiceOver identifica estado e ação sem depender de cor.
- Contraste aumentado e transparência reduzida usam fundos sólidos e borda.
- Movimento reduzido mantém waveform informativo sem animação decorativa.
- Todas as ações de Ajustes são navegáveis por teclado.

## Não objetivos

- Conta, billing, analytics, sincronização e feed remoto de transcrições.
- Interface Windows nesta etapa.
- IA de reescrita, tradução ou correção de output.
- Vídeos sintéticos apresentados como funcionamento real.

## Aceite

1. Um usuário novo conclui permissões e teste sem Terminal.
2. Hotkey, microfone e disponibilidade são compreensíveis em menos de um minuto.
3. HUD e menu nunca roubam o cursor do app de destino.
4. Cada screenshot pública corresponde a uma função real ou traz “conceito” claramente visível.
5. Testes nativos e fixtures de claro/escuro, contraste, transparência e movimento reduzido passam; VoiceOver físico permanece um gate explícito antes da captura de marketing.
6. A marca aparece no HUD real sem reduzir a leitura do cronômetro ou da waveform.
7. Menu bar, app icon, onboarding e Sobre exibem a mesma versão aprovada da marca.
