#!/usr/bin/env bash
# Publicação completa do Punho a partir do home lab.
# Uso normal: ./scripts/release.sh 0.0.10 --yes

set -Eeuo pipefail

readonly REPOSITORY="DecisaoDigital/punho"
readonly PROJECT_REF="oefqbkhioncakojipqyx"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/release.sh <versão> [--yes]

Exemplo:
  ./scripts/release.sh 0.0.10 --yes

O build number é incrementado automaticamente. O comando:
  1. valida main, GitHub, Supabase e a nova versão;
  2. atualiza pubspec.yaml;
  3. executa flutter analyze e os testes;
  4. constrói e verifica o APK, e só então faz commit, tag e push;
  5. cria a GitHub Release e carrega o APK construído no i9;
  6. atualiza e verifica o catálogo Supabase.
EOF
}

die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "comando em falta: $1"
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

version="${1#v}"
assume_yes=false
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--yes" ]] || die "opção desconhecida: $2"
  assume_yes=true
fi

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  die "versão inválida; use o formato 0.0.10"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export PATH="$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

for command in git gh curl jq perl flutter supabase dpkg; do
  require_command "$command"
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
  die "execute este comando dentro do repositório Punho"
cd "$repo_root"

[[ "$(git branch --show-current)" == "main" ]] ||
  die "a branch atual tem de ser main"
[[ -z "$(git status --porcelain)" ]] ||
  die "a working tree tem alterações; faça commit ou guarde-as antes da release"

git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] ||
  die "main local não coincide com origin/main"

remote="$(git remote get-url origin)"
[[ "$remote" == "https://github.com/${REPOSITORY}.git" ||
   "$remote" == "git@github.com:${REPOSITORY}.git" ]] ||
  die "origin inesperado: $remote"

gh auth status >/dev/null 2>&1 || die "GitHub CLI sem autenticação"
supabase projects list --output json |
  jq -e --arg ref "$PROJECT_REF" '.[] | select(.ref == $ref)' >/dev/null ||
  die "sessão Supabase sem acesso ao projeto $PROJECT_REF"

version_line="$(grep -m1 '^version:' pubspec.yaml)"
current_version="$(sed 's/version:[[:space:]]*//; s/+.*//' <<< "$version_line")"
current_build="$(sed 's/.*+//' <<< "$version_line")"
[[ "$current_build" =~ ^[0-9]+$ ]] || die "build atual inválido: $current_build"
dpkg --compare-versions "$version" gt "$current_version" ||
  die "a nova versão ($version) tem de ser superior a $current_version"

new_build=$((current_build + 1))
((new_build < 1000)) ||
  die "build $new_build excede o esquema split-per-abi atual"

tag="v${version}"
if git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null ||
   git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  die "a tag $tag já existe"
fi
if gh release view "$tag" --repo "$REPOSITORY" >/dev/null 2>&1; then
  die "a release $tag já existe"
fi

printf 'Preparado para publicar %s+%s (atual: %s+%s).\n' \
  "$version" "$new_build" "$current_version" "$current_build"
if [[ "$assume_yes" != true ]]; then
  read -r -p "Continuar? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "cancelado"
fi

committed=false
restore_on_error() {
  status=$?
  if [[ $status -ne 0 && "$committed" != true ]]; then
    git restore -- pubspec.yaml pubspec.lock 2>/dev/null || true
  fi
  exit "$status"
}
trap restore_on_error EXIT

perl -0pi -e "s/^version:.*\$/version: ${version}+${new_build}/m" pubspec.yaml
grep -Fx "version: ${version}+${new_build}" pubspec.yaml >/dev/null ||
  die "não foi possível atualizar pubspec.yaml"

flutter pub get
flutter analyze
flutter test --exclude-tags=screenshot
git diff --check

unexpected="$(
  git status --porcelain |
    awk '{print $2}' |
    grep -v -e '^pubspec.yaml$' -e '^pubspec.lock$' || true
)"
[[ -z "$unexpected" ]] ||
  die "os testes alteraram ficheiros inesperados: $unexpected"

# Construir ANTES de empurrar seja o que for. O runbook é explícito: "uma
# execução verde no i9 é condição obrigatória para o código subir ao GitHub".
# Na v0.2.1 este script empurrou o commit e a tag e só depois foi construir —
# o build falhou e ficou uma tag publicada sem release nenhuma por trás.
printf 'A construir o APK universal com os defines...\n'
"$repo_root/scripts/construir_apk.sh" --universal

apk_construido="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$apk_construido" ]] || die "o build não produziu $apk_construido"

# As verificações que o docs/PUBLICAR_RELEASE.md exige antes de publicar. O
# certificado é o definitivo do Punho: uma keystore diferente instala-se como
# outra app e parte o self-update de toda a gente.
readonly CERTIFICADO_SHA256="33386ff0dd95bb57818aaabc32b37e378da9febb1fb905b2388c4b5aa0f70205"
build_tools="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)"

"$build_tools/aapt2" dump badging "$apk_construido" |
  grep -Fq "versionCode='${new_build}' versionName='${version}'" ||
  die "o APK não declara ${version}+${new_build}"
"$build_tools/aapt2" dump badging "$apk_construido" |
  grep -Fq "package: name='com.example.punho'" ||
  die "o APK não é com.example.punho"
"$build_tools/apksigner" verify --print-certs "$apk_construido" |
  grep -Fq "$CERTIFICADO_SHA256" ||
  die "o APK não está assinado com a keystore definitiva do Punho"

git add -- pubspec.yaml
if ! git diff --quiet -- pubspec.lock; then
  git add -- pubspec.lock
fi
git commit -m "chore(release): ${tag}"
committed=true

git push origin main
git tag -a "$tag" -m "Punho ${version}"
git push origin "$tag"

# O GitHub guarda e distribui os ficheiros; não os constrói. O workflow que o
# fazia foi removido a 3 de Agosto de 2026 (commit 65fae4e), e este script
# ficou a esperar por um CI que já não existe.
asset="punho-android-v${version}.apk"
mkdir -p dist
cp "$apk_construido" "dist/${asset}"
gh release create "$tag" \
  --repo "$REPOSITORY" \
  --title "Punho ${version}" \
  --notes "Ver o histórico de commits desde a etiqueta anterior." \
  "dist/${asset}#${asset}"

"$repo_root/scripts/update-release-catalog.sh" "$version" "$new_build"

release_url="$(
  gh release view "$tag" --repo "$REPOSITORY" --json url --jq .url
)"
trap - EXIT

printf '\nPUBLICAÇÃO CONCLUÍDA\n'
printf 'Versão: %s+%s\n' "$version" "$new_build"
printf 'Release: %s\n' "$release_url"
printf 'Supabase: Android activo e verificado.\n'
printf 'Windows: continua por publicar — falta o worker Windows no i9.\n'
