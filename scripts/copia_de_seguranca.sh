#!/usr/bin/env bash
# Cópia de segurança da base do Punho, tirada do i9.
# Uso normal: ./scripts/copia_de_seguranca.sh
#
# Um backup que nunca foi restaurado não é um backup, é uma esperança. Este
# script só tira a cópia; quem a prova é ./scripts/restaurar_prova.sh, e a
# cópia diária corre os dois.
#
# ## O que leva
#
#   public.dump   o esquema `public` inteiro — tabelas, dados, vistas, funções,
#                 gatilhos, políticas RLS e as permissões dos papéis. É aqui que
#                 está tudo o que o Punho é.
#   contas.dump   auth.users e auth.identities. Sem isto restaura-se a empresa
#                 mas ninguém consegue entrar nela.
#   agenda.sql    as tarefas do pg_cron, escritas como comandos para recriar.
#                 O `cron` não sai no dump do public e perdia-se em silêncio.
#   papeis.sql    os papéis a que o public dá permissões (anon, authenticated,
#                 service_role e companhia). Sem eles os GRANT do dump não têm
#                 a quem se agarrar.
#   manifesto.txt contagem de tudo, para se poder afirmar que o restauro trouxe
#                 o mesmo que a base tinha.
#
# ## O que NÃO leva
#
#   Os ficheiros do storage. Hoje o balde `punho-documentos` está vazio e o
#   `releases` só tem APKs que também vivem no GitHub. No dia em que os
#   documentos começarem a existir, isto passa a ser um buraco — está escrito
#   em docs/COPIAS_DE_SEGURANCA.md.
#
# ## Senha
#
# Lê-se de ~/.punho/copia.env, que este script nunca escreve nem mostra:
#
#   PGPASSWORD=a-senha-da-base
#
# A senha está em: Supabase → Project Settings → Database → Database password.

set -Eeuo pipefail

readonly PROJECT_REF="oefqbkhioncakojipqyx"
readonly ANFITRIAO="db.${PROJECT_REF}.supabase.co"
readonly IMAGEM="postgres:17-alpine"
readonly CONFIG="${HOME}/.punho/copia.env"
readonly RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DESTINO="${PUNHO_COPIAS:-${HOME}/copias/punho}"
# Guarda-se um mês de diárias e a primeira de cada mês durante um ano.
readonly DIARIAS_A_GUARDAR=30
readonly MENSAIS_A_GUARDAR_DIAS=365

usage() {
  cat <<'EOF'
Uso:
  ./scripts/copia_de_seguranca.sh [--verificar] [--destino <pasta>]

  --verificar   Só confirma que chega à base e que a senha serve. Não escreve
                nada, não apaga nada.
  --destino     Onde guardar. Por omissão ~/copias/punho (ou $PUNHO_COPIAS).
EOF
}

so_verificar=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verificar) so_verificar=true; shift ;;
    --destino)   DESTINO="${2:?falta a pasta}"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Argumento desconhecido: $1" >&2; usage >&2; exit 2 ;;
  esac
done

erro() { echo "✗ $*" >&2; exit 1; }
passo() { echo "· $*"; }

command -v docker >/dev/null || erro "não há docker — é ele que traz o pg_dump 17"
[[ -f "$CONFIG" ]] || erro "falta $CONFIG com PGPASSWORD=... (chmod 600)"

# shellcheck disable=SC1090
source "$CONFIG"
[[ -n "${PGPASSWORD:-}" ]] || erro "$CONFIG existe mas não tem PGPASSWORD"

docker image inspect "$IMAGEM" >/dev/null 2>&1 || {
  passo "a trazer $IMAGEM"
  docker pull --quiet "$IMAGEM" >/dev/null
}

# A senha não vai na linha de comandos nem em -e: vai num .pgpass de 600 que
# morre com o script. Assim não aparece em `docker inspect` nem no ambiente.
PGPASS_TMP="$(mktemp)"
chmod 600 "$PGPASS_TMP"
printf '%s:5432:*:postgres:%s\n' "$ANFITRIAO" "$PGPASSWORD" > "$PGPASS_TMP"
trap 'rm -f "$PGPASS_TMP"' EXIT

# --network host porque o db.*.supabase.co só responde em IPv6 e a rede
# predefinida do docker é só IPv4.
psql_na_base() {
  docker run --rm --network host \
    --user "$(id -u):$(id -g)" \
    -v "$PGPASS_TMP":/tmp/.pgpass:ro \
    -e PGPASSFILE=/tmp/.pgpass \
    "$@"
}

passo "a falar com $ANFITRIAO"
versao="$(psql_na_base "$IMAGEM" \
  psql -h "$ANFITRIAO" -U postgres -d postgres -At \
       -c "select current_setting('server_version')" 2>&1)" \
  || erro "não entrou na base: $versao"
passo "servidor PostgreSQL $versao"

if $so_verificar; then
  echo "✓ a ligação serve. Nada foi escrito."
  exit 0
fi

carimbo="$(date +%Y-%m-%d_%H%M)"
pasta="${DESTINO}/${carimbo}"
mkdir -p "$pasta"

passo "esquema public → public.dump"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  pg_dump -h "$ANFITRIAO" -U postgres -d postgres \
          --format=custom --compress=9 --schema=public \
          --file=/saida/public.dump

passo "contas → contas.dump"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  pg_dump -h "$ANFITRIAO" -U postgres -d postgres \
          --format=custom --compress=9 \
          --table=auth.users --table=auth.identities \
          --file=/saida/contas.dump

passo "tarefas agendadas → agenda.sql"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  psql -h "$ANFITRIAO" -U postgres -d postgres -At -o /saida/agenda.sql \
    -c "select format(
          'select cron.schedule(%L, %L, %L);', jobname, schedule, command)
        from cron.job order by jobid"

passo "papéis → papeis.sql"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  psql -h "$ANFITRIAO" -U postgres -d postgres -At -o /saida/papeis.sql \
    -c "select format(
          'do \$\$ begin if not exists (select 1 from pg_roles where rolname=%L)'
          || ' then create role %I nologin; end if; end \$\$;', rolname, rolname)
        from pg_roles where rolname not like 'pg\_%' order by rolname"

passo "inventário → manifesto.txt"
psql_na_base -v "$pasta":/saida -v "${RAIZ}/scripts":/sql:ro "$IMAGEM" \
  psql -h "$ANFITRIAO" -U postgres -d postgres -At -F '|' \
       -o /saida/manifesto.txt -f /sql/copia_manifesto.sql

( cd "$pasta" && sha256sum ./* > impressoes.sha256 )

# Uma cópia que ninguém consegue ler é pior do que nenhuma: pelo menos esta
# falha aqui, e não no dia em que fizer falta.
passo "a ler o índice do dump (o ficheiro abre?)"
psql_na_base -v "$pasta":/copia:ro "$IMAGEM" \
  pg_restore --list /copia/public.dump > /dev/null \
  || erro "o public.dump não abre — cópia inútil, ficou em $pasta para inspecção"

tamanho="$(du -sh "$pasta" | cut -f1)"
linhas="$(grep '^total de linhas|' "$pasta/manifesto.txt" | cut -d'|' -f2)"
tabelas="$(grep '^total de tabelas|' "$pasta/manifesto.txt" | cut -d'|' -f2)"
contas="$(grep '^contas de utilizador|' "$pasta/manifesto.txt" | cut -d'|' -f2)"

passo "a arrumar cópias velhas"
apagadas=0
if [[ -d "$DESTINO" ]]; then
  mapfile -t todas < <(find "$DESTINO" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
  for i in "${!todas[@]}"; do
    nome="${todas[$i]}"
    (( i < DIARIAS_A_GUARDAR )) && continue
    dia="${nome:8:2}"
    if [[ "$dia" == "01" ]]; then
      idade_dias=$(( ( $(date +%s) - $(date -d "${nome:0:10}" +%s) ) / 86400 ))
      (( idade_dias <= MENSAIS_A_GUARDAR_DIAS )) && continue
    fi
    rm -rf "${DESTINO:?}/${nome}"
    apagadas=$(( apagadas + 1 ))
  done
fi

echo
echo "✓ cópia feita: $pasta ($tamanho)"
echo "  $tabelas tabelas · $linhas linhas · $contas contas"
(( apagadas > 0 )) && echo "  $apagadas cópias antigas removidas"
echo
echo "Isto ainda não é um backup provado. Provar é:"
echo "  ./scripts/restaurar_prova.sh $pasta"
