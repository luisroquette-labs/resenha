# SPEC-014 — Sistema visual do produto

## Direção

O Resenha deve parecer um sussurro transformado em interface: verde-névoa, areia, grafite, tipografia editorial e linhas de ressonância. A interface é calma, autoral e não parece um dashboard ou template de componentes.

## Superfícies

1. HUD: reconhecível em menos de 100 ms, compacto, alto contraste e reativo à voz.
2. Ajustes: navegação horizontal numerada sempre visível; nenhuma seção escondida em overflow.
3. Biblioteca de sons: 70 opções agrupadas, seleção e prévia no mesmo gesto.
4. Onboarding: três permissões explicadas por resultado, com estado e ação claros.
5. Menu bar: organização e ícones nativos coerentes com os estados do produto.
6. Sobre: marca, promessa local-first e versão do produto.

## Tokens

- `accent`: verde-eucalipto suave usado em seleção, gravação e foco.
- `ink`: grafite quase preto.
- `paper`: creme quente.
- Cantos: 10, 16 e 24 pt.
- Tipografia: serifada em títulos, SF Pro no corpo e SF Mono em tempo/IDs.
- Movimento: apenas ressonância e progresso; respeita Reduzir Movimento.

## Critérios de aceitação

- Funciona em claro, escuro, alto contraste, transparência reduzida e movimento reduzido.
- Todos os controles mantêm rótulos de acessibilidade e navegação por teclado.
- Ajustes mostram as seis seções simultaneamente em uma janela de 700 × 500.
- HUD preserva os limites de 360 × 104 e nunca rouba foco.
- Nenhum vermelho, roxo, mosaico de cards, visual genérico de dashboard ou dependência web.
