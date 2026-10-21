#!/bin/zsh
set -euo pipefail
root="${0:A:h:h}"
source "$root/Scripts/validate-release-dmg.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-install-test.XXXXXXXX")"
fixture_root="${fixture_root:A}"
mkdir -p "$fixture_root/artifacts/Resenha.app/Contents/MacOS"
candidate="$fixture_root/artifacts/Resenha.app"
print -r -- candidate > "$candidate/Contents/MacOS/Resenha"
source_sha=0123456789abcdef0123456789abcdef01234567
empty_entitlements='<?xml version="1.0"?><plist version="1.0"><dict/></plist>'
assert() { [[ "$1" == "$2" ]] || { print -u2 "FAIL: $3 ($1 != $2)"; exit 1; }; }
expect_rejected() { if "$@" >/dev/null 2>&1; then print -u2 "FAIL: aceitou $*"; exit 1; fi; }

reject_test_artifacts "$candidate"
validate_release_entitlements "$empty_entitlements"
for marker in Resenha.debug.dylib __preview.dylib libXCTestBundleInject.dylib XCTest.framework XCTAutomationSupport.framework XCUIAutomation.framework Testing.framework testmanagerd coresymbolicationd; do
  variant="$fixture_root/markers/$marker/Resenha.app"
  mkdir -p "$variant/Contents/Frameworks"
  print -r -- fixture > "$variant/Contents/Frameworks/$marker"
  expect_rejected reject_test_artifacts "$variant"
done
for key in com.apple.security.get-task-allow get-task-allow; do
  expect_rejected validate_release_entitlements "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>$key</key><true/></dict></plist>"
done
for service in com.apple.testmanagerd.control com.apple.dt.testmanagerd.runner com.apple.coresymbolicationd; do
  expect_rejected validate_release_entitlements "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>com.apple.security.temporary-exception.mach-lookup.global-name</key><array><string>$service</string></array></dict></plist>"
done

# Fixtures override only OS interactions; all copying, hashing, swaps and traps are real.
run_install() {
  local scenario="$1" fail_at="$2" case_root
  case_root="$fixture_root/resenha-install-test.$scenario"
  mkdir -p "$case_root/Applications/Resenha.app/Contents/MacOS" "$case_root/evidence"
  print -r -- previous > "$case_root/Applications/Resenha.app/Contents/MacOS/Resenha"
  RESENHA_INSTALL_TEST_MODE=1 RESENHA_INSTALL_TEST_ROOT="$case_root" RESENHA_INSTALL_TEST_FAIL="$fail_at" \
  zsh -c '
    source "$1/Scripts/install-local-release.sh"
    install_validation() { [[ "$2" == 0123456789abcdef0123456789abcdef01234567 ]]; }
    installed_processes() { if [[ "${SCENARIO:-}" == multiple ]]; then print "1|unexpected\n2|unexpected"; else print "1|$install_target/Contents/MacOS/Resenha"; fi; }
    stop_installed_app() { return 0; }
    start_installed_app() { return 0; }
    install_main "$2" "$3" "$4"
  ' fixture "$root" "$candidate" "$source_sha" "$case_root/evidence"
}
run_install success ''
assert "$(<"$fixture_root/resenha-install-test.success/Applications/Resenha.app/Contents/MacOS/Resenha")" candidate install
for point in before-swap after-backup after-swap; do
  if run_install "$point" "$point"; then print -u2 "FAIL: falha $point não propagou"; exit 1; fi
  assert "$(<"$fixture_root/resenha-install-test.$point/Applications/Resenha.app/Contents/MacOS/Resenha")" previous "rollback $point"
  backups=("$fixture_root/resenha-install-test.$point"/Applications/Resenha-backups/**/previous-Resenha.app/Contents/MacOS/Resenha(N))
  if [[ "$point" != before-swap ]]; then
    assert "${#backups}" 1 "backup preservado $point"
    assert "$(<"${backups[1]}")" previous "conteúdo do backup $point"
  fi
  [[ -n "$(find "$fixture_root/resenha-install-test.$point" -path '*Resenha.app/Contents/MacOS/Resenha' -o -path '*failed-candidate.app/Contents/MacOS/Resenha')" ]]
done
if SCENARIO=multiple run_install multiple ''; then print -u2 'FAIL: múltiplos PIDs aceitos'; exit 1; fi
source_sha=ffffffffffffffffffffffffffffffffffffffff
if run_install wrong-sha ''; then print -u2 'FAIL: SHA divergente aceito'; exit 1; fi
source_sha=0123456789abcdef0123456789abcdef01234567

# Divergent stage hash must fail before the existing bundle moves.
if RESENHA_INSTALL_TEST_MODE=1 RESENHA_INSTALL_TEST_ROOT="$fixture_root/resenha-install-test.success" zsh -c '
  source "$1/Scripts/install-local-release.sh"
  install_validation() { return 0; }; installed_processes() { return 0; }; check_process_cardinality() { return 0; }
  ditto() { command ditto "$@"; print tampered >> "$2/Contents/MacOS/Resenha"; }
  install_main "$2" "$3" "$4"
' fixture "$root" "$candidate" "$source_sha" "$fixture_root/hash-evidence"; then print -u2 'FAIL: hash divergente aceito'; exit 1; fi
assert "$(<"$fixture_root/resenha-install-test.success/Applications/Resenha.app/Contents/MacOS/Resenha")" candidate 'hash não alterou instalado'
if [[ -d "$root/build/Build/Products/Debug/Resenha.app" ]]; then
  expect_rejected validate_release_app "$root/build/Build/Products/Debug/Resenha.app"
fi
print "PASS: marcadores/entitlements, instalação, hash/PIDs e rollback antes/depois da troca. Fixtures preservadas: $fixture_root"
