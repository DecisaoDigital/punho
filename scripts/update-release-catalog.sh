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

# O instalador automático do Punho (descarregarAgora) só corre com um sha256
# publicado — sem ele o botão "Atualizar" cai sempre para o browser. Calcula-se
# aqui, uma única vez, a partir do próprio asset da release.
android_apk_tmp="$(mktemp)"
trap 'rm -f "$android_apk_tmp"' EXIT
gh release download "$tag" \
  --repo "$REPOSITORY" \
  --pattern "$android_asset" \
  --output "$android_apk_tmp" \
  --clobber
android_sha256="$(sha256sum "$android_apk_tmp" | cut -d' ' -f1)"

upsert_version() {
  local platform="$1"
  local download_url="$2"
  local notes="$3"
  local sha="$4"
  local payload
  payload="$(
    jq -nc \
      --arg platform "$platform" \
      --arg version "$version" \
      --argjson build "$build" \
      --arg url "$download_url" \
      --arg notes "$notes" \
      --arg sha "$sha" \
      '{
        app: "punho",
        plataforma: $platform,
        versao: $version,
        build_number: $build,
        url_download: $url,
        obrigatoria: false,
        notas_lancamento: $notes,
        activa: true,
        sha256: $sha
      }'
  )"

  # Um upsert simples não serve aqui, e a promessa de "pode ser repetido" no
  # topo deste ficheiro era falsa por causa disso.
  #
  # O gatilho `trg_versoes_apps_release_integrity` exige, no INSERT, que o
  # build_number seja maior que o máximo já catalogado. Em Postgres o BEFORE
  # INSERT dispara *antes* de o ON CONFLICT ser resolvido, por isso a linha
  # rebenta com "build_number tem que ser > max existente" em vez de cair no
  # UPDATE. Resultado: repetir este comando para um build já catalogado morria
  # — exactamente na altura em que se repete, que é a seguir a uma falha.
  #
  # Daí a bifurcação: se a linha já existe, actualizam-se só os campos que o
  # gatilho deixa mexer (app, plataforma, versao e build_number são imutáveis).
  ja_existe="$(
    curl --fail-with-body --silent --show-error \
      "${api}?app=eq.punho&plataforma=eq.${platform}&build_number=eq.${build}&select=id" \
      -H "apikey: ${admin_key}" \
      -H "Authorization: Bearer ${admin_key}" | jq 'length'
  )"

  if [[ "$ja_existe" -gt 0 ]]; then
    printf 'A linha %s+%s (%s) já existia; a actualizar o que é mutável.\n' \
      "$version" "$build" "$platform"
    curl --fail-with-body --silent --show-error \
      -X PATCH \
      "${api}?app=eq.punho&plataforma=eq.${platform}&build_number=eq.${build}" \
      -H "apikey: ${admin_key}" \
      -H "Authorization: Bearer ${admin_key}" \
      -H "Content-Type: application/json" \
      --data "$(jq 'del(.app, .plataforma, .versao, .build_number)' <<< "$payload")"
  else
    # Primeiro activa a versão nova; só depois desactiva as antigas. Se a
    # segunda chamada falhar, a function escolhe na mesma o build mais alto e
    # a repetição deste comando conclui a limpeza.
    curl --fail-with-body --silent --show-error \
      -X POST "$api" \
      -H "apikey: ${admin_key}" \
      -H "Authorization: Bearer ${admin_key}" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=minimal" \
      --data "$payload"
  fi

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
  "Nova versão Android do Punho." \
  "$android_sha256"

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
