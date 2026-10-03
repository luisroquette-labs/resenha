# SPEC-013 — Biblioteca de sons

## Objetivo

Permitir que cada pessoa escolha um aviso curto e reconhecível para o momento em que o Resenha está pronto para ouvir.

## Requisitos

1. A biblioteca contém exatamente 70 sons, numerados e divididos em 7 categorias com 10 opções cada: Zoeira corporal, Vozes e reações, Objetos e instrumentos, Games e desenhos, Animais e natureza, Abstratos e Angelicais.
2. Todo som começa imediatamente, dura entre 180 e 500 ms e tem volume normalizado.
3. Todos os sons são sintetizados localmente pelo app, sem download, backend ou ativos licenciados.
4. Os Ajustes exibem nome, número, categoria, seleção atual e prévia de cada som.
5. Clicar em uma opção seleciona e reproduz a prévia; a escolha persiste entre execuções.
6. O som selecionado é usado apenas para o aviso de abertura `FALE AGORA`; os sinais de iniciar e terminar gravação continuam distintos.
7. `Sons de funcionamento` silencia abertura, início e fim, mas não impede a prévia explícita nos Ajustes.

## Critérios de aceitação

- IDs 1–70 são únicos e estáveis; cada categoria possui 10 sons.
- Todo WAV começa com `RIFF`, é PCM mono 44,1 kHz/16-bit e não excede 500 ms.
- Os 70 WAVs são diferentes entre si.
- A seleção padrão é `60 — Ressonância do Resenha`.
- Reiniciar o app preserva a escolha e toca exatamente uma vez quando o sistema estiver pronto.

## Fora de escopo

- Upload de sons personalizados.
- Gravações humanas ou conteúdo baixado.
- Loja, sincronização ou compartilhamento de sons.
