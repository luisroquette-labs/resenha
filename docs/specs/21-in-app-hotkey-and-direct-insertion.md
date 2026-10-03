# SPEC-021 — Atalho livre no app e inserção direta

Status: autorizado; implementação em andamento

## Decisão

O Resenha volta a ser distribuído diretamente, fora da Mac App Store. O usuário grava o atalho global dentro do próprio app, inclusive uma tecla modificadora isolada como **Option direita**. Ao soltar o atalho, o texto é colado no campo que estava ativo por meio de um `Command-V` sintético.

## Requisitos

- O painel **Atalho** deve gravar a próxima tecla ou combinação sem abrir os Ajustes do Sistema.
- Combinações comuns e teclas modificadoras esquerda/direita devem ser persistidas e reaplicadas imediatamente.
- **Option direita** volta a ser o padrão para novas instalações e fica disponível como restauração em um clique.
- O monitor global continua somente de escuta; não bloqueia nem altera outros eventos de teclado.
- Microfone, Monitoramento de Entrada e Acessibilidade são obrigatórios e aparecem separadamente na configuração.
- O app captura a aplicação ativa no início do ditado, reativa essa aplicação antes de inserir e confirma que ela voltou ao primeiro plano.
- O texto concluído fica no clipboard como recuperação e só é colado se o clipboard ainda contém a versão preparada.
- Campos seguros ou aplicações que recusam eventos sintéticos podem impedir a inserção; o texto continua recuperável com `Command-V`.

## Segurança e distribuição

- O App Sandbox é removido porque a inserção direta exige Acessibilidade e postagem de eventos.
- O app continua com Hardened Runtime, transcrição local, áudio temporário e sem analytics.
- O Serviço do macOS deixa de ser o caminho primário e não é registrado no bundle direto, evitando dupla inserção.

## Aceite

- O usuário grava **Option direita**, fecha e reabre os ajustes e vê o mesmo atalho.
- Uma combinação arbitrária persiste, dispara uma borda de início e uma de fim e rejeita modificadores extras.
- Sem Acessibilidade, o Resenha não inicia o monitor e mostra o destino correto nos Ajustes do Sistema.
- Com as três permissões, um ditado real em TextEdit insere no cursor e mantém o texto no clipboard.
- Testes automatizados cobrem serialização, correspondência de atalho, permissão e política de destino da inserção.
