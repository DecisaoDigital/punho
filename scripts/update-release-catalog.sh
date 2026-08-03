#!/usr/bin/env bash
# Atualiza de forma idempotente o catálogo Supabase depois de os assets da
# release já existirem. Pode ser repetido isoladamente após uma falha.

set -Eeuo pipefail

readonly REPOSITORY="DecisaoDigital/punho"
readonly PROJECT_REF="oefqbkhioncakojipqyx"
readonly SUPABASE_URL="https://${PROJECT_REF}.supabase.co"

die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 2 ]]; then
  printf 'Uso: %s <versão> <build_number>\n' "$0" >&2
  exit 2
fi

version="${1#v}"
build="$2"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  die "versão inválida: $version"
[[ "$build" =~ ^[0-9]+$ ]] || die "build inválido: $build"
((build > 0 && build < 1000)) ||
  die "build fora do intervalo suportado: $build"

for command in gh curl jq supabase; do
  command -v "$command" >/dev/null 2>&1 ||
    die "comando em falta: $command"
done

tag="v${version}"
android_asset="punho-android-v${version}.apk"
release_json="$(
  gh release view "$tag" \
    --repo "$REPOSITORY" \
    --json isDraft,isPrerelease,url,assets
)"
jq -e \
  --arg android "$android_asset" \
  '(.isDraft == false) and
   (.isPrerelease == false) and
   ([.assets[].name] | index($android) != null)' \
  <<< "$release_json" >/dev/null ||
  die "release sem o asset Android ($android_asset)"

keys_json="$(
  supabase projects api-keys \
    --project-ref "$PROJECT_REF" \
    --reveal \
    --output json
)"
admin_key="$(
  jq -r '.[] | select(.id == "service_role") | .api_key' <<< "$keys_json"
)"
anon_key="$(
  jq -r '.[] | select(.id == "anon") | .api_key' <<< "$keys_json"
)"
[[ "$admin_key" == eyJ* ]] || die "service_role não disponível"
[[ "$anon_key" == eyJ* ]] || die "anon key não disponível"

api="${SUPABASE_URL}/rest/v1/versoes_apps"
android_url="https://github.com/${REPOSITORY}/releases/download/${tag}/${android_asset}"

upsert_version() {
  local platform="$1"
  local download_url="$2"
  local notes="$3"
  local payload
  payload="$(
    jq -nc \
      --arg platform "$platform" \
      --arg version "$version" \
      --argjson build "$build" \
      --arg url "$download_url" \
      --arg notes "$notes" \
      '{
        app: "punho",
        plataforma: $platform,
        versao: $version,
        build_number: $build,
        url_download: $url,
        obrigatoria: false,
        notas_lancamento: $notes,
        activa: true
      }'
  )"

  # Primeiro ativa a versão nova; só depois desativa as antigas. Se a segunda
  # chamada falhar, a função escolhe na mesma o build mais alto e a repetição
  # deste comando conclui a limpeza.
  curl --fail-with-body --silent --show-error \
    -X POST "${api}?on_conflict=app%2Cplataforma%2Cbuild_number" \
    -H "apikey: ${admin_key}" \
    -H "Authorization: Bearer ${admin_key}" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=merge-duplicates,return=minimal" \
    --data "$payload"

  curl --fail-with-body --silent --show-error \
    -X PATCH \
    "${api}?app=eq.punho&plataforma=eq.${platform}&build_number=neq.${build}" \
    -H "apikey: ${admin_key}" \
    -H "Authorization: Bearer ${admin_key}" \
    -H "Content-Type: application/json" \
    --data '{"activa":false}'
}

upsert_version \
  "android" \
  "$android_url" \
  "Nova versão Android do Punho."

check_update() {
  local platform="$1"
  local local_build="$2"
  local expected="$3"
  local expected_url="$4"
  local response
  response="$(
    curl --fail-with-body --silent --show-error \
      "${SUPABASE_URL}/functions/v1/versao-mais-recente" \
      -H "Authorization: Bearer ${anon_key}" \
      -H "apikey: ${anon_key}" \
      -H "Content-Type: application/json" \
      --data "{
        \"app\":\"punho\",
        \"plataforma\":\"${platform}\",
        \"build_number_local\":${local_build}
      }"
  )"

  if [[ "$expected" == true ]]; then
    jq -e \
      --arg version "$version" \
      --arg url "$expected_url" \
      --argjson build "$build" \
      '.actualizacao_disponivel == true and
       .versao_actual == $version and
       .build_number == $build and
       .url_download == $url' \
      <<< "$response" >/dev/null
  else
    jq -e '.actualizacao_disponivel == false' \
      <<< "$response" >/dev/null
  fi
}

previous_build=$((build - 1))
for abi_prefix in 1 2 4; do
  check_update \
    "android" \
    "$((abi_prefix * 1000 + previous_build))" \
    true \
    "$android_url"
  check_update \
    "android" \
    "$((abi_prefix * 1000 + build))" \
    false \
    "$android_url"
done

unset admin_key anon_key keys_json
printf 'Catálogo Supabase atualizado e verificado para %s+%s.\n' \
  "$version" "$build"
