#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
prompt_root="$project_root/AppStore/media/prompts"
output_root="$project_root/AppStore/media/generated"
model="veo-3.1-generate-preview"
keychain_service="br.com.luisroquette.Resenha.google-veo"
base_url="https://generativelanguage.googleapis.com/v1beta"
approved_total="9.60"

execute=false
if [[ "${1:-}" == "--execute" ]]; then
  execute=true
elif [[ -n "${1:-}" && "${1:-}" != "--dry-run" ]]; then
  print -u2 "Uso: ${0:t} [--dry-run|--execute]"
  exit 64
fi

prompts=(A-thought B-anywhere C-local)
for name in $prompts; do
  test -s "$prompt_root/$name.txt" || { print -u2 "Prompt ausente: $name"; exit 1; }
done

print "Modelo: $model"
print "Entrega: 3 plates × 8s × 1080p × 16:9"
print "Teto autorizado exigido: US$ $approved_total"

if ! $execute; then
  print "DRY RUN: nenhuma chamada de rede ou cobrança foi executada."
  exit 0
fi

[[ "${RESENHA_VEO_APPROVED_USD:-}" == "$approved_total" ]] || {
  print -u2 "Bloqueado: defina RESENHA_VEO_APPROVED_USD=$approved_total somente após aprovação explícita do dono."
  exit 77
}

for tool in curl jq security; do
  command -v "$tool" >/dev/null || { print -u2 "$tool não encontrado"; exit 1; }
done

api_key="$(security find-generic-password -a "$USER" -s "$keychain_service" -w 2>/dev/null || true)"
[[ -n "$api_key" ]] || {
  print -u2 "Chave ausente no Keychain: $keychain_service"
  exit 78
}

mkdir -p "$output_root"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/resenha-veo.XXXXXX")"
header_file="$work_root/headers"
chmod 700 "$work_root"
print -r -- "x-goog-api-key: $api_key" > "$header_file"
chmod 600 "$header_file"
unset api_key
cleanup() {
  [[ -n "${work_root:-}" && "$work_root" == "${TMPDIR:-/tmp}/resenha-veo."* ]] || return 0
  rm -rf -- "$work_root"
}
trap cleanup EXIT

for name in $prompts; do
  destination="$output_root/$name.mp4"
  [[ ! -e "$destination" ]] || { print -u2 "Destino já existe; sem sobrescrever: $destination"; exit 73; }

  payload="$work_root/$name-request.json"
  response="$output_root/$name-operation.json"
  jq -n --rawfile prompt "$prompt_root/$name.txt" '{
    instances: [{ prompt: $prompt }],
    parameters: {
      aspectRatio: "16:9",
      durationSeconds: "8",
      resolution: "1080p",
      personGeneration: "allow_all",
      sampleCount: 1
    }
  }' > "$payload"

  print "Gerando $name (uma tentativa; sem retry automático)…"
  curl --fail-with-body --silent --show-error \
    -H "@$header_file" -H 'Content-Type: application/json' \
    -X POST --data-binary "@$payload" \
    "$base_url/models/$model:predictLongRunning" > "$response"

  operation_name="$(jq -er '.name' "$response")"
  for attempt in {1..36}; do
    status_file="$work_root/$name-status.json"
    curl --fail-with-body --silent --show-error -H "@$header_file" \
      "$base_url/$operation_name" > "$status_file"
    if [[ "$(jq -r '.done // false' "$status_file")" == true ]]; then
      if jq -e '.error' "$status_file" >/dev/null; then
        jq '.error' "$status_file" > "$output_root/$name-error.json"
        print -u2 "Veo recusou $name; nenhum retry foi executado."
        exit 1
      fi
      video_uri="$(jq -er '.response.generateVideoResponse.generatedSamples[0].video.uri' "$status_file")"
      curl --fail-with-body --silent --show-error --location -H "@$header_file" \
        --output "$destination" "$video_uri"
      cp "$status_file" "$output_root/$name-complete.json"
      print "Salvo: $destination"
      break
    fi
    (( attempt < 36 )) || { print -u2 "Timeout aguardando $name; operação preservada em $response"; exit 75; }
    sleep 10
  done
done

print "Três plates concluídos dentro do teto máximo de US$ $approved_total."
