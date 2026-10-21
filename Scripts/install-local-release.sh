#!/bin/zsh
set -euo pipefail
installer_root="${${(%):-%N}:A:h:h}"
source "$installer_root/Scripts/validate-release-dmg.sh"

installed_processes() {
  local pid command
  for pid in ${(f)"$(pgrep -x Resenha 2>/dev/null)"}; do
    command="$(ps -p "$pid" -o comm=)" || return 1
    print -r -- "$pid|$command"
  done
}

check_process_cardinality() {
  local target="$1" require_running="${2:-0}" entries
  entries=("${(@f)$(installed_processes)}")
  entries=("${(@)entries:#}")
  (( ${#entries} <= 1 )) || { release_fail "múltiplos processos Resenha; nenhuma instância será encerrada"; return 1; }
  if (( ${#entries} == 1 )); then
    [[ "${entries[1]#*|}" == "$target/Contents/MacOS/Resenha" ]] || { release_fail "Resenha está executando de outro bundle"; return 1; }
  elif (( require_running )); then
    release_fail "nenhum processo instalado encontrado"; return 1
  fi
}

stop_installed_app() {
  local target="$1" attempts
  check_process_cardinality "$target" || return 1
  [[ -n "$(installed_processes)" ]] || return 0
  osascript -e "tell application \"$target\" to quit" || return 1
  for attempts in {1..100}; do
    [[ -z "$(installed_processes)" ]] && return 0
    sleep 0.1
  done
  release_fail "Resenha não encerrou graciosamente; instalação preservada"; return 1
}

start_installed_app() {
  local target="$1" attempts launch_attempt launched=0
  for launch_attempt in {1..3}; do
    if open -n "$target"; then
      launched=1; break
    fi
    if [[ -n "$(installed_processes)" ]]; then
      launched=1; break
    fi
    sleep 0.5
  done
  (( launched )) || { release_fail "LaunchServices recusou iniciar o Release após 3 tentativas"; return 1; }
  for attempts in {1..100}; do
    if [[ -n "$(installed_processes)" ]]; then
      check_process_cardinality "$target" 1; return $?
    fi
    sleep 0.1
  done
  release_fail "Release não iniciou"; return 1
}

install_validation() { validate_release_app "$1" "$2"; }

install_checkpoint() {
  if [[ "${RESENHA_INSTALL_TEST_MODE:-0}" == 1 && "${RESENHA_INSTALL_TEST_FAIL:-}" == "$1" ]]; then
    release_fail "falha injetada: $1"; return 1
  fi
}

rollback_install() {
  local result="$1"
  unfunction TRAPZERR TRAPINT TRAPTERM
  print -u2 "Instalação interrompida ($result); recuperando bundle anterior."
  if (( placed_candidate )); then
    if ! stop_installed_app "$install_target"; then
      print -u2 "ERRO: não foi possível encerrar candidato; rollback manual: $backup_app"; return "$result"
    fi
    if ! mv "$install_target" "$backup_directory/failed-candidate.app"; then
      print -u2 "ERRO: preservar candidato falhou; backup: $backup_app"; return "$result"
    fi
  fi
  if (( moved_original )); then
    if ditto "$backup_app" "$stage_directory/restored.app" &&
       [[ "$(release_fingerprint "$stage_directory/restored.app")" == "$previous_fingerprint" ]] &&
       mv "$stage_directory/restored.app" "$install_target"; then
      print -r -- "rollback=restored" >> "$evidence_directory/install-result.txt"
      if (( was_running )); then
        if ! start_installed_app "$install_target"; then
          print -u2 "ERRO: bundle restaurado; reabertura manual necessária: $install_target"
        fi
      fi
    else
      print -u2 "ERRO: rollback incompleto; backup recuperável: $backup_app"
    fi
  elif (( was_running )) && [[ -d "$install_target" && -z "$(installed_processes)" ]]; then
    if ! start_installed_app "$install_target"; then print -u2 "ERRO: reabra $install_target"; fi
  fi
  print -u2 "Backup/staging preservados: $backup_directory ; $stage_directory"
  return "$result"
}

install_main() {
  [[ $# == 3 ]] || { release_fail "uso: $0 /Release/Resenha.app source-sha /diretorio/evidencia"; return 1; }
  local candidate="$1" source_sha="$2" evidence_input="$3" test_root="${RESENHA_INSTALL_TEST_ROOT:-}"
  [[ "$candidate" == /* && "$candidate" == "${candidate:A}" && "$candidate" == */Resenha.app && -d "$candidate" && ! -L "$candidate" ]] || { release_fail "app deve ser Resenha.app absoluto/resolvido"; return 1; }
  [[ "$source_sha" =~ '^[[:xdigit:]]{40}$' ]] || { release_fail "source SHA deve ter 40 caracteres hex"; return 1; }
  [[ "$evidence_input" == /* && "$evidence_input" != *$'\n'* && "$evidence_input" != / && "$evidence_input" != "$HOME" ]] || { release_fail "diretório de evidência inseguro"; return 1; }
  [[ "$candidate" != *$'\n'* && "$candidate" != *'"'* ]] || { release_fail "path do app inválido"; return 1; }
  typeset -g install_target=/Applications/Resenha.app
  if [[ "${RESENHA_INSTALL_TEST_MODE:-0}" == 1 ]]; then
    [[ "$test_root" == /* && -d "$test_root" && "$test_root" == "${test_root:A}" && "${test_root:t}" == resenha-install-test.* ]] || { release_fail "root de fixture inválido"; return 1; }
    install_target="$test_root/Applications/Resenha.app"
  elif [[ -n "$test_root" || -n "${RESENHA_INSTALL_TEST_FAIL:-}" ]]; then
    release_fail "controles de fixture exigem modo teste"; return 1
  fi
  [[ "$candidate" != "$install_target" && "${candidate:A}" != "${install_target:A}" ]] || { release_fail "candidato e destino são iguais"; return 1; }
  [[ "$evidence_input" != "$install_target"* && "$evidence_input" != "$candidate"* ]] || { release_fail "evidência não pode ficar dentro dos bundles"; return 1; }
  install_validation "$candidate" "$source_sha" || return 1
  check_process_cardinality "$install_target" || return 1
  local source_fingerprint="$(release_fingerprint "$candidate")"
  typeset -g evidence_directory="${evidence_input:A}"
  mkdir -p "$evidence_directory" "${install_target:h}/Resenha-backups"
  typeset -g stage_directory="$(mktemp -d "${install_target:h}/.resenha-stage.XXXXXXXX")"
  typeset -g backup_directory="$(mktemp -d "${install_target:h}/Resenha-backups/Resenha-$(date -u +%Y%m%dT%H%M%SZ)-${source_sha[1,12]}.XXXXXXXX")"
  typeset -g backup_app="$backup_directory/previous-Resenha.app"
  typeset -g moved_original=0 placed_candidate=0 was_running=0 previous_fingerprint=''
  [[ -z "$(installed_processes)" ]] || was_running=1
  if [[ -e "$install_target" ]]; then
    [[ -d "$install_target" && ! -L "$install_target" ]] || { release_fail "instalação atual inválida"; return 1; }
    previous_fingerprint="$(release_fingerprint "$install_target")"
  fi
  print -rl -- "source_sha=$source_sha" "source_fingerprint=$source_fingerprint" "backup=$backup_app" "staging=$stage_directory" "previous_fingerprint=$previous_fingerprint" > "$evidence_directory/install-result.txt"
  release_manifest "$candidate" > "$evidence_directory/source-manifest.sha256"
  TRAPZERR() { local result=$?; rollback_install "$result"; return "$result"; }
  TRAPINT() { rollback_install 130; return 130; }
  TRAPTERM() { rollback_install 143; return 143; }
  ditto "$candidate" "$stage_directory/Resenha.app"
  install_validation "$stage_directory/Resenha.app" "$source_sha"
  [[ "$(release_fingerprint "$stage_directory/Resenha.app")" == "$source_fingerprint" ]] || { release_fail "hash de staging divergente"; return 1; }
  install_checkpoint before-swap
  stop_installed_app "$install_target"
  if [[ -d "$install_target" ]]; then
    mv "$install_target" "$backup_app"
    moved_original=1
    [[ "$(release_fingerprint "$backup_app")" == "$previous_fingerprint" ]] || { release_fail "backup diverge da instalação inventariada"; return 1; }
  fi
  install_checkpoint after-backup
  mv "$stage_directory/Resenha.app" "$install_target"
  placed_candidate=1
  install_checkpoint after-swap
  install_validation "$install_target" "$source_sha"
  [[ "$(release_fingerprint "$install_target")" == "$source_fingerprint" ]] || { release_fail "hash instalado divergente"; return 1; }
  start_installed_app "$install_target"
  check_process_cardinality "$install_target" 1
  [[ "$(release_fingerprint "$install_target")" == "$source_fingerprint" ]] || { release_fail "bundle mudou após abertura"; return 1; }
  release_manifest "$install_target" > "$evidence_directory/installed-manifest.sha256"
  print -rl -- "result=installed" "process=$(installed_processes)" >> "$evidence_directory/install-result.txt"
  unfunction TRAPZERR TRAPINT TRAPTERM
  print "Release instalado e verificado: $install_target"
  print "Backup recuperável: $backup_app"
  print "Evidência: $evidence_directory"
}

if [[ "$ZSH_EVAL_CONTEXT" == toplevel ]]; then install_main "$@"; fi
