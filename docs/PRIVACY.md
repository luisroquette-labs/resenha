# Política de Privacidade do Resenha

**Vigência:** 2 de outubro de 2026  
**Aplicável à versão macOS:** 1.0.0; contrato Windows em desenvolvimento

Resenha é um aplicativo de ditado local para macOS. Não criamos contas, não
operamos um backend do produto, não exibimos anúncios e não coletamos dados
pessoais, áudio, transcrições, diagnósticos ou métricas de uso.

## Processamento local

- O microfone é capturado somente durante um ditado iniciado pelo usuário.
- O áudio temporário é transcrito no Mac com whisper.cpp e apagado ao término.
- A transcrição é colocada no clipboard para recuperação imediata.
- Se “Textos recentes” estiver ativo, até 10 transcrições ficam apenas neste Mac.
- O usuário pode desativar e apagar esse histórico nos Ajustes do Resenha.

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

Status Windows: implementação e verificação física pendentes; download
indisponível. Esta seção define o comportamento exigido por
[SPEC-023](specs/23-windows-mvp.md), não afirma uma versão Windows publicada.

O microfone selecionado usa WASAPI local somente no intervalo em que o atalho
está pressionado. Soltar, cancelar, bloquear/suspender ou perder o dispositivo
encerra a tentativa. O whisper.cpp e o modelo executam no computador; áudio e
transcrições não são enviados ao site, ao formulário ou a APIs. Não há conta,
backend do aplicativo, telemetria, analytics, logs de áudio/texto ou histórico
de transcrições no disco. O histórico opcional do macOS não se aplica ao Windows.

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
| Preferências | `%LOCALAPPDATA%\Resenha\settings.json`: versão de schema, atalho, endpoint de microfone e idioma; sem texto ditado |
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
https://github.com/luisroquette/resenha/issues. Não inclua transcrições ou
informações pessoais em uma issue pública.
