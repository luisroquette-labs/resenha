#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
info="$project_root/Config/ResenhaStore-Info.plist"
release_state="$project_root/AppStore/release-state.json"

fail() { print -u2 "FALHOU: $*"; exit 1; }
pass() { print "PASS: $*"; }

key_equivalent="$(plutil -extract NSServices.0.NSKeyEquivalent.default raw "$info")"
[[ ${#key_equivalent} == 1 ]] || fail "NSKeyEquivalent deve conter um caractere"
[[ "$key_equivalent" == "${key_equivalent:u}" ]] || fail "atalho padrão precisa incluir Shift"
[[ "$key_equivalent" == E ]] || fail "atalho documentado e Info.plist divergiram"
rg -q 'clique em “Concluir”' "$project_root/AppStore/review-notes-pt-BR.md" \
    || fail "notas de revisão não orientam o botão Concluir"
if rg -q 'solte a tecla|mantenha.*pressionad|RegisterEventHotKey' "$project_root/AppStore/review-notes-pt-BR.md"; then
    fail "notas de revisão ainda descrevem o fluxo antigo"
fi
pass "Serviço usa NSKeyEquivalent válido: Command + Shift + E"

submitted_build="$(plutil -extract submitted.build raw "$release_state")"
eligible="$(plutil -extract submitted.eligibleForRelease raw "$release_state")"
minimum_build="$(plutil -extract candidate.minimumBuild raw "$release_state")"
approval_required="$(plutil -extract remoteMutationRequiresOwnerApproval raw "$release_state")"
source_build="$(awk '/CURRENT_PROJECT_VERSION:/{print $2; exit}' "$project_root/project.yml")"
source_version="$(awk '/MARKETING_VERSION:/{print $2; exit}' "$project_root/project.yml")"
candidate_version="$(plutil -extract candidate.version raw "$release_state")"
candidate_commit="$(plutil -extract candidate.sourceCommit raw "$release_state" 2>/dev/null || true)"

[[ "$eligible" == false ]] || fail "build rejeitado $submitted_build não pode estar elegível"
(( source_build >= minimum_build && source_build > submitted_build )) || fail "novo build precisa superar o rejeitado"
[[ "$source_version" == "$candidate_version" ]] || fail "versão fonte e candidato divergiram"
[[ "$candidate_commit" =~ ^[0-9a-f]{40}$ ]] || fail "candidato ainda não possui source commit real"
git -C "$project_root" cat-file -e "$candidate_commit^{commit}" 2>/dev/null \
    || fail "source commit do candidato não existe no repositório"
[[ "$approval_required" == true ]] || fail "mutação remota precisa exigir aprovação"
[[ "$(plutil -extract submitted.releaseModeObserved raw "$release_state")" == MANUAL ]] \
    || fail "submissão precisa permanecer em lançamento manual"
[[ "$(plutil -extract submitted.statusObserved raw "$release_state")" == REJECTED ]] \
    || fail "estado remoto esperado é REJECTED"
[[ "$(plutil -extract previousSubmission.build raw "$release_state")" == 1 ]] \
    || fail "histórico do build 1 ausente"
[[ "$(plutil -extract previousSubmission.statusObserved raw "$release_state")" == REMOVED ]] \
    || fail "build 1 histórico precisa permanecer removido"
rg -q 'Lançamento: manual após aprovação' "$project_root/AppStore/metadata/submission-pt-BR.md" \
    || fail "ficha não exige lançamento manual"
pass "build $submitted_build rejeitado; build 1 removido; novo candidato $source_build; release manual"
