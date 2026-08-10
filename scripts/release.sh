#!/usr/bin/env bash
# Publicação completa do Punho a partir do home lab.
# Uso normal: ./scripts/release.sh 0.0.10 --yes

set -Eeuo pipefail

readonly REPOSITORY="DecisaoDigital/punho"
readonly PROJECT_REF="oefqbkhioncakojipqyx"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/release.sh <versão> [--yes] [--ensaio]

Exemplo:
  ./scripts/release.sh 0.0.10 --yes

O build number é incrementado automaticamente. O comando:
  1. valida main, GitHub, Supabase e a nova versão;
  2. atualiza pubspec.yaml;
  3. executa flutter analyze e os testes;
  4. constrói e verifica o APK, e só então faz commit, tag e push;
  5. cria a GitHub Release e carrega o APK construído no i9.

E PÁRA AÍ. Publicar o APK e anunciá-lo aos telemóveis são duas decisões
diferentes, e no meio delas está o smoke no aparelho. Quem anuncia é:

  ./scripts/update-release-catalog.sh <versão> <build>

  --ensaio  Corre tudo até à verificação do APK e pára antes do commit: sem
            commit, sem tag, sem push, sem release. O pubspec.yaml é reposto no
            fim. Serve para ver a publicação toda falhar (ou passar) sem deixar
            rasto nenhum.

  --versao-menor
            Deixa passar uma versão que o `dpkg` lê como inferior à actual.
            Existe por causa dos remendos de um dígito a mais: a 0.3.61 foi
            uma correcção da 0.3.6, e para o dpkg 0.3.7 é *menor* do que ela
            (7 < 61). Não afrouxa nada do que interessa — o build number
            continua a subir sozinho, e é ele, não o nome, que decide o
            auto-update nos telemóveis. Tem de ser escrito à mão, de propósito.
EOF
}

die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "comando em falta: $1"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

version="${1#v}"
shift
assume_yes=false
ensaio=false
versao_menor=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) assume_yes=true ;;
    --ensaio) ensaio=true ;;
    --versao-menor) versao_menor=true ;;
    *) die "opção desconhecida: $1" ;;
  esac
  shift
done

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
if ! dpkg --compare-versions "$version" gt "$current_version"; then
  [[ "$versao_menor" == true ]] ||
    die "a nova versão ($version) tem de ser superior a $current_version" \
        "(se for de propósito, --versao-menor)"
  [[ "$version" != "$current_version" ]] ||
    die "a nova versão é igual à actual ($version)"
  printf 'AVISO: %s é inferior a %s para o dpkg. A subir na mesma (--versao-menor).\n' \
    "$version" "$current_version"
fi

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

if [[ "$ensaio" == true ]]; then
  printf 'ENSAIO de %s+%s (atual: %s+%s) — não sai nada daqui.\n' \
    "$version" "$new_build" "$current_version" "$current_build"
else
  printf 'Preparado para publicar %s+%s (atual: %s+%s).\n' \
    "$version" "$new_build" "$current_version" "$current_build"
  if [[ "$assume_yes" != true ]]; then
    read -r -p "Continuar? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "cancelado"
  fi
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

# Recolher a saída para variáveis ANTES de a filtrar. Ligar estes comandos a
# um `grep -q` por um cano é uma corrida perdida à espera de acontecer: o grep
# sai no primeiro acerto — que aqui é a primeira linha —, o produtor fica a
# escrever para um cano fechado, apanha SIGPIPE, e o `pipefail` lá em cima
# transforma uma verificação bem-sucedida numa falha da release. Aconteceu a
# publicar a 0.3.3: o APK declarava 0.3.3+38 e o script disse que não.
badging="$("$build_tools/aapt2" dump badging "$apk_construido")"
certificados="$("$build_tools/apksigner" verify --print-certs "$apk_construido")"

grep -Fq "versionCode='${new_build}' versionName='${version}'" <<< "$badging" ||
  die "o APK não declara ${version}+${new_build}"
grep -Fq "package: name='pt.decisaodigital.punho'" <<< "$badging" ||
  die "o APK não é pt.decisaodigital.punho"
grep -Fq "$CERTIFICADO_SHA256" <<< "$certificados" ||
  die "o APK não está assinado com a keystore definitiva do Punho"

# Fim do ensaio. Tudo o que vem a seguir deixa rasto: commit, tag, push e
# release. O ensaio corre de propósito **até aqui** e não menos — o que costuma
# falhar não são os passos de git, são os testes e a verificação do APK, e um
# ensaio que parasse antes disso não valia o tempo que demora.
if [[ "$ensaio" == true ]]; then
  git restore -- pubspec.yaml pubspec.lock 2>/dev/null || true
  trap - EXIT
  printf '\n%s\n' '────────────────────────────────────────────────────────'
  printf 'ENSAIO CONCLUÍDO — nada foi commitado, empurrado nem publicado.\n'
  printf '%s\n\n' '────────────────────────────────────────────────────────'
  printf 'Passou: main, GitHub, Supabase, analyze, testes, build e as três\n'
  printf 'verificações do APK (versão, pacote e certificado).\n'
  printf 'O pubspec.yaml foi reposto como estava.\n'
  printf 'O APK do ensaio ficou em %s\n' "$apk_construido"
  exit 0
fi

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

release_url="$(
  gh release view "$tag" --repo "$REPOSITORY" --json url --jq .url
)"
trap - EXIT

# É aqui que este script acaba, e é de propósito.
#
# Até esta linha nada chegou a ninguém: o APK está no GitHub à espera de quem o
# vá buscar de propósito. A linha seguinte — o catálogo — é que acende a
# auto-actualização e empurra a versão para todos os telemóveis. Estavam
# coladas, sem nada pelo meio, e por isso um APK que compila, está assinado e
# tem os defines mas rebenta ao arrancar ia parar a toda a gente sem ninguém o
# ter aberto uma vez. O rollback disso é SQL à mão, com o cliente já parado.
#
# O runbook sempre exigiu smoke manual antes de anunciar. O script é que não o
# impunha, e um passo que só o documento exige é um passo que se salta num dia
# cheio.
printf '\n%s\n' '════════════════════════════════════════════════════════════'
printf 'APK PUBLICADO — E AINDA NÃO ANUNCIADO A NINGUÉM\n'
printf '%s\n\n' '════════════════════════════════════════════════════════════'
printf 'Versão: %s+%s\n' "$version" "$new_build"
printf 'Release: %s\n' "$release_url"
printf 'APK local: %s\n\n' "dist/${asset}"
printf 'Nenhum telemóvel vai ver esta versão até correres o catálogo.\n'
printf 'Falta, por esta ordem:\n\n'
printf '  1. Instalar o APK no aparelho:\n'
printf '     adb install -r dist/%s\n\n' "$asset"
printf '  2. Correr o smoke — os fluxos estão em docs/SMOKE.md.\n\n'
printf '  3. Só depois, anunciar a quem já tem a app instalada:\n'
printf '     ./scripts/update-release-catalog.sh %s %s\n\n' "$version" "$new_build"
printf 'Se o smoke correr mal, não há nada para desfazer: basta não correr o\n'
printf 'passo 3. A release fica no GitHub sem ninguém a receber.\n\n'
printf 'Windows: continua por publicar — falta o worker Windows no i9.\n'
