#!/usr/bin/env bash
#
# Constrói o APK de release do Punho com os `--dart-define` e **confirma** que
# eles lá ficaram.
#
# Porquê: sem os defines a app não estoira nem se queixa — arranca em modo
# local, com o mesmo aspecto e sem servidor nenhum por trás. Já escondeu
# durante duas versões que as builds saíam sem backend, e a 4 de Agosto de 2026
# voltou a enganar durante um teste no telemóvel: um cliente criado na app
# nunca chegou ao Supabase, e o painel continuou a mostrar dados antigos que
# tinham ficado no aparelho de uma instalação anterior.
#
# Uso:
#   scripts/construir_apk.sh                 # arm64, para instalar por adb
#   scripts/construir_apk.sh --universal     # o APK da release (todos os ABIs)
#   scripts/construir_apk.sh --split-per-abi # um APK por arquitectura
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "ERRO: falta o .env com SUPABASE_URL e SUPABASE_ANON_KEY." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${SUPABASE_URL:?SUPABASE_URL vazio no .env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY vazio no .env}"

case "${1:-}" in
  "")               destino=("--target-platform" "android-arm64") ;;
  --universal)      destino=() ;;
  --split-per-abi)  destino=("--split-per-abi") ;;
  *) echo "ERRO: opção desconhecida: $1" >&2; exit 2 ;;
esac

# Apagar o que lá estava antes de construir: senão a verificação lá em baixo
# aprova APKs de builds antigas que ninguém pediu, e um ficheiro velho a passar
# no teste é exactamente a falha que este script existe para apanhar.
rm -f build/app/outputs/flutter-apk/app*-release.apk \
      build/app/outputs/flutter-apk/Punho_v*.apk \
      build/app/outputs/apk/release/Punho_v*.apk

flutter build apk --release "${destino[@]}" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# A verificação é o ponto todo deste script: o build acima passa na mesma sem
# os defines, e é isso que o torna perigoso. O host do URL tem de aparecer no
# binário compilado, senão o que saiu daqui é uma app sem servidor.
host="$(printf '%s' "$SUPABASE_URL" | sed -e 's#^https\?://##' -e 's#/.*##')"
falhou=0
for apk in build/app/outputs/flutter-apk/app*-release.apk; do
  [[ -e "$apk" ]] || continue
  extraido="$(mktemp -d)"
  unzip -o -q "$apk" -d "$extraido" 'lib/*/libapp.so'
  if grep -aqr "$host" "$extraido"; then
    echo "OK   $(basename "$apk") — fala com $host"
  else
    echo "FALHA $(basename "$apk") — compilado SEM Supabase" >&2
    falhou=1
  fi
  rm -rf "$extraido"
done

exit "$falhou"
