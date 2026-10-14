# SPEC-010 — Capturas e demonstrações do Resenha

## Objetivo

Produzir material autêntico para a futura página de vendas depois da interface de produto estar funcional e validada.

## Pacote mínimo

1. Hero: vídeo de 8–12 s com cursor, hotkey, HUD responsivo, processamento e inserção.
2. Onboarding: três screenshots reais — boas-vindas, permissões e teste.
3. Ajustes: screenshots de Atalho, Áudio e Privacidade apenas quando funcionais.
4. Estados: HUD ouvindo, transcrevendo e erro em claro e escuro.
5. Compatibilidade: uma gravação real em navegador, rotulada com o app e versão testados.

## Regras

- Capturas que aleguem compatibilidade física usam ScreenCaptureKit ou ferramenta nativa,
  em uma conta/desktop limpo. Demonstrações de fluxo podem combinar renders nativos
  automatizados em uma superfície editorial quando forem identificadas como demonstração.
- Ocultar notificações, nomes pessoais, chaves, texto sensível e outros aplicativos.
- Não simular latência, precisão, compatibilidade ou menus inexistentes. Uma demonstração
  composta não pode ser chamada de gravação real nem provar microfone ou inserção física.
- Vídeo generativo pode criar transições ou fundos, mas não representar o app funcionando.
- OpenRouter ou outro serviço pago exige aprovação de custo imediatamente antes da chamada.

## Saídas

- PNG em 1× e 2×, sem compressão destrutiva.
- Vídeo mestre HEVC/H.264 e versão web MP4 otimizada.
- Legenda curta em PT-BR e transcrição acessível.
- Manifesto com versão do app, macOS, hardware, modelo e cenário capturado.

## Gate para retornar ao site

O redesenho da página só recomeça quando houver:

- onboarding funcional;
- Ajustes funcionais de Atalho e Áudio;
- HUD final;
- demonstrações web sem quadros congelados, com origem e limites declarados;
- pelo menos um ditado físico de ponta a ponta antes do preview da App Store;
- nenhuma afirmação de marketing sem evidência correspondente.
