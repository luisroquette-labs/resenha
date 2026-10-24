# Política de Privacidade do Resenha

**Vigência:** 24 de outubro de 2026
**Aplicável à versão macOS:** 1.1.1; **Windows:** versão pública 0.1.0 e atualização 0.2.0 em preparação

Resenha é um aplicativo de ditado local para macOS. Não criamos contas, não
operamos um backend do produto e não exibimos anúncios. O áudio permanece no
Mac. A avaliação contextual remota de texto é opcional e começa desligada.

## Processamento local

- O microfone é capturado somente durante um ditado iniciado pelo usuário.
- O áudio temporário é transcrito no Mac com whisper.cpp e apagado ao término.
- A transcrição é colocada no clipboard para recuperação imediata.
- Se “Textos recentes” estiver ativo, até 10 transcrições ficam apenas neste Mac.
- O usuário pode desativar e apagar esse histórico nos Ajustes do Resenha.
- Correções contextuais ficam em arquivo local separado do glossário: idioma,
  forma ouvida, forma canônica, frase confirmada e ocorrência. São no máximo
  100 exemplos, com frases de até 600 caracteres, apagáveis individualmente ou
  em conjunto. O beta local começa desligado.
- A prévia contínua é opcional e começa desligada. Suas hipóteses ficam somente
  na sessão atual e no HUD do Resenha; não entram no clipboard, histórico ou
  aplicativo de destino. O contexto temporário é descartado ao finalizar ou
  cancelar.

## Inteligência contextual contínua opcional

Com consentimento separado e uma chave pessoal do OpenRouter, o Resenha envia
ao OpenRouter/TypeSafe (JEV) somente a frase já transcrita e as alternativas dos
termos localmente elegíveis, enquanto você dita. Nunca envia áudio, logits,
probabilidades, vocabulário completo, histórico, clipboard ou conteúdo do
aplicativo de destino. O envio é limitado a 4096 bytes, no máximo seis tentativas
por ditado, uma avaliação ativa e uma pendente substituível, com intervalo mínimo
de 500 ms. A avaliação expira em 1,2 s durante a fala e em 900 ms na finalização.
Falha, atraso ou indisponibilidade preservam a transcrição local.

Para permitir a verificação pelo próprio usuário, o Resenha mantém neste Mac
até 20 registros técnicos das avaliações pessoais. Eles contêm somente data,
estado, modelo e identificador retornados pelo provedor, decisão, confiança,
latência, tokens, custo informado, resultado local (aplicou, manteve ou
descartou) e categoria de falha. Não contêm áudio,
transcrição, termos candidatos, chave ou conteúdo do aplicativo de destino.
Esses registros ficam em arquivo separado, podem ser apagados nos Ajustes e
não são enviados pelo Resenha a nenhum serviço adicional.

A função começa desligada e exige evidência local concreta do Whisper, glossário
ou exemplo confirmado antes de cada envio. Sua chave
fica em uma conta separada no Keychain e a autorização do diagnóstico sintético
não pode ativá-la. OpenRouter/TypeSafe podem medir tokens, cobrar pelo uso e
reter dados ou metadados conforme suas políticas. O Resenha não estima o custo
total nem promete preço ou retenção zero. Ao
revogar, o app cancela o trabalho pendente, remove a chave pessoal e volta ao
modo local. Revogar a chave na conta OpenRouter é uma ação separada do usuário.

## Diagnóstico sintético opcional

Com consentimento separado, o usuário pode fornecer uma chave descartável e
executar uma única frase sintética identificada pelo app. Só essa fixture é
enviada ao OpenRouter e ao provedor TypeSafe para o modelo
`typesafe/jev-1.14`; áudio, histórico, clipboard, exemplos locais e ditados
pessoais não entram na requisição. A tentativa expira em 900 ms, não repete e
consome um bloqueio local antes do envio. A chave fica no Keychain e pode ser
removida no app, mas a revogação no provedor é uma ação separada do usuário.

O transporte usa sessão efêmera, sem cache, cookies ou armazenamento de
credenciais HTTP. OpenRouter/TypeSafe ainda podem reter metadados técnicos
conforme suas próprias políticas; o Resenha não controla essa retenção. O
diagnóstico mede somente compatibilidade do contrato, não qualidade PT-BR.

## Download do modelo

O arquivo do modelo Whisper é baixado diretamente de
`huggingface.co/ggerganov/whisper.cpp`. Esse servidor pode receber informações
técnicas normais de uma conexão HTTP, como endereço IP e user agent, conforme a
política do próprio provedor. Resenha não envia áudio ou transcrições nessa
conexão e não recebe esses registros.

## Permissões

- **Microfone:** capturar a fala enquanto o ditado estiver ativo.
- **Monitoramento de Entrada:** detectar quando o atalho de ditado é pressionado e solto.
- **Acessibilidade:** devolver o foco ao aplicativo original e enviar um único comando de colar após a transcrição.

O Resenha não lê o conteúdo, a seleção ou a árvore de interface de outros
aplicativos. A Acessibilidade é usada somente para a inserção solicitada pelo
usuário ao concluir um ditado.

## Windows — contrato de privacidade do MVP

O Resenha para Windows 0.1.0 está publicado na Microsoft Store. O candidato
0.2.0 adiciona revisão contextual JEV opcional; o fluxo local continua disponível
sem conta, chave ou conexão depois do download do modelo.

O microfone selecionado usa WASAPI local somente no intervalo em que o atalho
está pressionado. Soltar, cancelar, bloquear/suspender ou perder o dispositivo
encerra a tentativa. O whisper.cpp e o modelo executam no computador; áudio e
transcrições não são enviados ao site nem ao formulário. Não há conta,
backend do aplicativo, telemetria, analytics, logs de áudio/texto ou histórico
de transcrições no disco. O histórico opcional do macOS não se aplica ao Windows.

Quando o usuário ativa o JEV e fornece sua própria chave OpenRouter, o Windows
envia ao endpoint fixo do OpenRouter somente a frase final já transcrita e até
três alternativas derivadas do vocabulário pessoal. Nunca envia áudio,
clipboard, conteúdo do aplicativo de destino, histórico ou o vocabulário
completo. A resposta deve chegar em até 900 ms e superar os limites de confiança;
erro, atraso ou ambiguidade preservam a transcrição local. A chave fica no
Gerenciador de Credenciais do Windows e não entra em `settings.json`. O usuário
pode removê-la nos Ajustes. OpenRouter/TypeSafe podem medir, cobrar e reter dados
conforme suas políticas; o Resenha não recebe nem subsidia o valor.

### Modelo e dados locais

Download do modelo só após a ação explícita Baixar modelo por HTTPS, ou
importação explícita de arquivo. O provedor pode receber IP/user agent da conexão;
nenhum áudio/transcrição é enviado. O tamanho e SHA-256 são verificados antes
da promoção e novamente antes da inferência. Arquivos incompletos são removidos;
uma substituição falha preserva o modelo válido anterior. Não há download de
código executável em runtime. Depois da aquisição, o ditado deve funcionar offline.

| Dados Windows | Local e duração exigidos |
| --- | --- |
| Aplicativo | `%LOCALAPPDATA%\Programs\Resenha\`, instalação por usuário |
| Preferências | `%LOCALAPPDATA%\Resenha\settings.json`: versão de schema, atalho, endpoint de microfone, idioma, ativação do JEV e vocabulário pessoal; sem texto ditado nem chave |
| Modelo | `%LOCALAPPDATA%\Resenha\models\ggml-small-q5_1.bin`, persistente e validado |
| Áudio e saída transitória | `%LOCALAPPDATA%\Resenha\sessions\<attempt-guid>\input.wav` e `result.txt`, apagados em sucesso, erro, cancelamento, saída e limpeza de sessões abandonadas no próximo início |
| Texto de recuperação | Último texto completo somente em RAM até substituição, limpeza explícita ou saída; pode permanecer no clipboard do Windows |

Pastas devem ser restritas ao usuário; operações validam caminhos canônicos e
propriedade e rejeitam travessia por reparse points. Falha de remoção é visível
e bloqueia prontidão, nunca retenção silenciosa. Não prometemos apagamento
forense seguro; Windows, ferramentas de backup ou outros aplicativos podem ter
suas próprias políticas de clipboard/armazenamento. O aplicativo não ativa
sincronização nem histórico de clipboard do sistema.

### Clipboard, foco e recuperação em RAM

O texto completo é copiado e lido de volta antes de uma única tentativa de
Ctrl+V. Clipboard ocupado mantém o texto em RAM com Copiar novamente, sem
colagem. Essa ação explícita só copia: não repete a inferência nem dispara uma
colagem atrasada. Texto novo colocado no clipboard pelo usuário não é
sobrescrito automaticamente. Não restauramos conteúdo antigo por temporizador.
Campos que rejeitam input, mudança de foco e destinos protegidos/elevados usam
recuperação manual sem pedir administrador. Despacho de input não garante que
o editor aceitou texto, e validação de foco/colagem não é uma operação atômica.

Windows consulta somente identidade/metadados de foco, permissões de edição,
proteção e, quando disponível, identidade de seleção/caret via broker UIA local.
Não coleta conteúdo dos campos. O observador de teclado usa apenas estado do
atalho/invalidação da tentativa; o observador de mouse não guarda coordenadas
ou histórico de cliques. Nenhum desses metadados vira histórico de digitação.

### Remoção de dados próprios

O desinstalador encerra o aplicativo e seus filhos, remove arquivos instalados
e sessões próprias e oferece Remover modelo e configurações, selecionado por
padrão. O usuário pode escolher reter modelo/configurações e deve ver os
caminhos retidos. A remoção nunca apaga arquivo original importado, documentos,
dados alheios ou conteúdo do clipboard. Validar propriedade/caminho precede
qualquer remoção. A [verificação física](testing/WINDOWS-MVP-EVIDENCE.md) deve
provar ambas as escolhas, inclusive caminhos com espaços e caracteres não ASCII.

### Formulário do site

O download pelo site exige nome, email e WhatsApp no formulário CF Gauss; esse
fluxo de leads é separado do aplicativo sem conta. O formulário Windows e seu
redirect dedicado permanecem pendentes até provisionamento/verificação real.
Não enviamos áudio/transcrições ou esses dados pessoais a analytics. URLs
públicas de release significam que o formulário é uma etapa do site, não um
controle de acesso a todos os downloads possíveis. A disponibilidade depende
das [evidências de release](testing/WINDOWS-RELEASE-EVIDENCE.md).

## Contato

Questões de privacidade e segurança podem ser abertas publicamente em
https://github.com/luisroquette-labs/resenha/issues. Não inclua transcrições ou
informações pessoais em uma issue pública.
