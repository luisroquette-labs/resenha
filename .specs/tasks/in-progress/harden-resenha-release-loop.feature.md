# Description

Endurecer o Resenha em cinco fases cronológicas e verificáveis, corrigindo todos os
achados P0, P1 e P2 do audit de publicação sem alterar o escopo local-first do produto.

## Acceptance Criteria

**Checklist:**

- CK-1: Atalho/Serviço possuem um único contrato válido, acessível e testado.
- CK-2: Inserção ocorre somente com requisição de Serviço ativa; clipboard é recuperação.
- CK-3: Gravação, Serviço e inferência têm limites e cancelamento cooperativo.
- CK-4: Modelo e histórico mantêm integridade, atomicidade e limpeza completa.
- CK-5: Bundle Release contém licenças e não aceita override de modelo por ambiente.
- CK-6: UI atende contraste, texto ampliado e múltiplos monitores.
- CK-7: Debug/testes são isolados do bundle e container de produção.
- CK-8: Memória Whisper é liberada após ociosidade/pressão de memória.
- CK-9: Histórico é opt-in; sons têm busca/favoritos; mídia e screenshot são orientadas ao fluxo principal.
- CK-10: Site possui SEO/social completos e carregamento de imagem eficiente.
- CK-11: Validador e evidência usam versão, build e SHA reais.
- CK-12: Estado App Store é verificado, mas nenhuma mutação remota ocorre sem aprovação explícita.

**Regular Checks:**

- Projeto gera via XcodeGen sem diff inesperado.
- `mac-gate xcodebuild test` passa com `/Applications/Resenha.app` aberto.
- `xcodebuild analyze` passa.
- Testes do site passam.
- Validador de pacote passa no archive novo.

**Rubric:**

- Correção funcional e ausência de regressões.
- Segurança, privacidade e integridade de dados.
- Acessibilidade e qualidade de produto.
- Testabilidade e fidelidade das evidências.
- Ausência de complexidade ou duplicação sem propósito.

**Rubric Score Definitions:**

- 1: fluxo principal quebrado ou inseguro.
- 2: correções parciais com bloqueios relevantes.
- 3: funcional, com lacunas não críticas.
- 4: completo, validado e pronto para release.
- 5: excepcional, sem desperdício material detectável.

**Test Strategy:**

- Unitários para contrato de atalho, soltura, timeout, hash, instalação e limpeza.
- Integração do `ResenhaServiceProvider` com requestor/pasteboard falsos.
- Testes de configuração Release/Debug e inspeção do archive.
- Testes DOM/SEO e inspeção de mídia do site.
- Roteiro físico versionado para TextEdit, Chromium, Terminal, VoiceOver e macOS 14+.

**Definition of Done:**

- [X] Todas as fases estão [REVIEWED] e seus testes estão verdes.
- [X] Nenhum P0/P1/P2 permanece sem correção ou bloqueio externo explícito.
- [X] O app Debug/testes coexistem com a cópia em `/Applications`.
- [X] O archive Release final passa pelo validador dinâmico e análise estática.
- [X] Site e assets finais passam seus gates automatizados e visuais.
- [ ] Specs e evidências referenciam o SHA e build finais, sem afirmações históricas falsas.
- [ ] Branch contém commits coesos e um único PR para `main`.

## Architecture Overview

O Serviço do macOS é a única fronteira autorizada a devolver texto ao requestor. O
monitor global observa e arma a sessão física, mas não simula inserção. `DictationCoordinator`
orquestra áudio, transcrição, clipboard e estado. Whisper usa cancelamento cooperativo do
próprio `whisper.cpp`. Modelo e histórico ficam atrás de componentes atômicos e testáveis.
Builds Debug/test possuem identidade separada. Site e release tooling permanecem locais.

## Implementation Process

Cada step é executado por um agente independente. Ao fim de cada fase, um revisor único
avalia a fase antes da seguinte.

### Parallelization Overview

`01-p0-service-contract` → `02-runtime-bounds` → `03-local-integrity` → `04-accessibility-qa` → `05-product-release`

| Step | Phase | Model | Agent | Depends on | Parallel with | Sub-Task File |
|------|-------|-------|-------|------------|---------------|---------------|
| `01-p0-service-contract` [DONE] | Phase 1 | opus | developer | None | None | `.specs/sub-tasks/harden-resenha-release-loop/01-p0-service-contract.md` |
| `02-runtime-bounds` [DONE] | Phase 2 | opus | developer | `01-p0-service-contract` | None | `.specs/sub-tasks/harden-resenha-release-loop/02-runtime-bounds.md` |
| `03-local-integrity` [DONE] | Phase 3 | opus | developer | `02-runtime-bounds` | None | `.specs/sub-tasks/harden-resenha-release-loop/03-local-integrity.md` |
| `04-accessibility-qa` [DONE] | Phase 4 | opus | developer | `03-local-integrity` | None | `.specs/sub-tasks/harden-resenha-release-loop/04-accessibility-qa.md` |
| `05-product-release` [DONE] | Phase 5 | opus | developer | `04-accessibility-qa` | None | `.specs/sub-tasks/harden-resenha-release-loop/05-product-release.md` |

### Phase Overview

#### Phase 1: Serviço e P0 [REVIEWED]

Steps: `01-p0-service-contract`
Reviewer model: `opus`
Checklist items: CK-1, CK-2, CK-11, CK-12
Rubrics: correção funcional, testabilidade, fidelidade da release

#### Phase 2: Limites de runtime [REVIEWED]

Steps: `02-runtime-bounds`
Reviewer model: `opus`
Checklist items: CK-3, CK-8
Rubrics: segurança de estado, concorrência, performance

#### Phase 3: Integridade local [REVIEWED]

Steps: `03-local-integrity`
Reviewer model: `opus`
Checklist items: CK-4, CK-5
Rubrics: integridade, privacidade, distribuição

#### Phase 4: Acessibilidade e QA [REVIEWED]

Steps: `04-accessibility-qa`
Reviewer model: `opus`
Checklist items: CK-1, CK-6, CK-7
Rubrics: acessibilidade, UX nativa, isolamento de testes

#### Phase 5: Produto e release [REVIEWED]

Steps: `05-product-release`
Reviewer model: `opus`
Checklist items: CK-9, CK-10, CK-11, CK-12
Rubrics: qualidade de produto, apresentação, release reproducível
