# Política de Privacidade do Resenha

**Vigência:** 22 de outubro de 2026
**Aplicável à versão:** 1.0.0

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
exemplos locais pertinentes, enquanto você dita. Nunca envia áudio, histórico, clipboard ou
conteúdo do aplicativo de destino. O envio é limitado a 4096 bytes, uma
avaliação ativa e uma pendente substituível, com intervalo mínimo de 500 ms.
Falha, atraso ou indisponibilidade preservam a transcrição local.

Para permitir a verificação pelo próprio usuário, o Resenha mantém neste Mac
até 20 registros técnicos das avaliações pessoais. Eles contêm somente data,
estado, modelo e identificador retornados pelo provedor, decisão, confiança,
latência, tokens, custo informado, resultado local (aplicou, manteve ou
descartou) e categoria de falha. Não contêm áudio,
transcrição, termos candidatos, chave ou conteúdo do aplicativo de destino.
Esses registros ficam em arquivo separado, podem ser apagados nos Ajustes e
não são enviados pelo Resenha a nenhum serviço adicional.

A função começa desligada e exige ao menos um exemplo local elegível. Sua chave
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

## Contato

Questões de privacidade e segurança podem ser abertas publicamente em
https://github.com/luisroquette/resenha/issues. Não inclua transcrições ou
informações pessoais em uma issue pública.
