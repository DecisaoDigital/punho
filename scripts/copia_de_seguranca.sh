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
# Esse ficheiro **não se escreve à mão**: isto é um `source`, e uma senha com
# `$`, espaço ou aspas chega truncada ou vazia — e depois parece senha errada.
# A forma segura, que também não deixa a senha no histórico nem no ecrã:
#
#   (umask 077; read -rsp 'senha: ' p
#    printf 'PGPASSWORD=%q\n' "$p" > ~/.punho/copia.env; unset p; echo)
#
# É a senha do utilizador `postgres`, escolhida quando o projecto foi criado e
# mostrada **uma vez**. O painel não a volta a mostrar — só repõe (Project
# Settings → Database → Reset database password). Repor é seguro: nada liga
# directamente ao Postgres. As apps falam por PostgREST com a chave anónima, as
# edge functions usam o service_role, o CLI usa o login dele. Esta cópia é a
# primeira coisa a precisar dela.
#
# ## Rede
#
# O `db.<ref>.supabase.co` só existe em IPv6 (sem registo A, a menos que se
# pague o add-on de IPv4). O i9 tem saída v6 e chega lá — confirmado a 11/8 com
# uma senha errada de propósito: o servidor respondeu `password authentication
# failed`, o que só se diz depois de haver ligação. Numa máquina sem v6 o
# caminho é o Session pooler; ver diagnostico_de_ligacao() mais abaixo.

set -Eeuo pipefail

readonly PROJECT_REF="oefqbkhioncakojipqyx"
readonly IMAGEM="postgres:17-alpine"
readonly CONFIG="${PUNHO_COPIA_CONFIG:-${HOME}/.punho/copia.env}"
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
                nada, não apaga nada. Se falhar, diz qual das duas falhou —
                rede ou senha —, que é a diferença entre repor a senha e
                perder a tarde a repor uma que já estava boa.
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

# Por omissão fala com a produção. O `ensaio_de_copia.sh` aponta isto a um
# PostgreSQL local para poder correr a cadeia inteira — esta mesma, sem ramo
# especial — sem tocar na base de ninguém.
ANFITRIAO="${PUNHO_DB_ANFITRIAO:-db.${PROJECT_REF}.supabase.co}"
PORTA="${PUNHO_DB_PORTA:-5432}"
# Só muda se a ligação directa não servir e for preciso ir pelo Session pooler,
# onde o utilizador é `postgres.<ref>` e não `postgres`. Ver
# diagnostico_de_ligacao().
UTILIZADOR="${PUNHO_DB_UTILIZADOR:-postgres}"

docker image inspect "$IMAGEM" >/dev/null 2>&1 || {
  passo "a trazer $IMAGEM"
  docker pull --quiet "$IMAGEM" >/dev/null
}

# A senha não vai na linha de comandos nem em -e: vai num .pgpass de 600 que
# morre com o script. Assim não aparece em `docker inspect` nem no ambiente.
PGPASS_TMP="$(mktemp)"
chmod 600 "$PGPASS_TMP"
printf '%s:%s:*:%s:%s\n' "$ANFITRIAO" "$PORTA" "$UTILIZADOR" "$PGPASSWORD" > "$PGPASS_TMP"
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

# Duas falhas com a mesma cara e causas opostas.
#
# O `db.<ref>.supabase.co` **só existe em IPv6** — não tem registo A, a não ser
# com o add-on de IPv4 pago. Numa rede sem saída v6 a ligação morre a resolver o
# endereço, e a primeira coisa em que se pensa é «a senha está errada». Perde-se
# a tarde a repor senhas que já estavam boas.
#
# A distinção é de graça: se o Postgres se queixou da **senha**, a rede está
# provada — ele só diz isso depois de haver TCP, TLS e handshake. Quem responde
# está lá.
diagnostico_de_ligacao() {
  local saida="$1"
  if grep -qiE 'password authentication failed|autentica.* falhou' <<<"$saida"; then
    cat <<TXT
a rede está boa: o servidor respondeu, logo chegou-se lá. O que não serve é a
senha em $CONFIG.
Repõe-a no painel (Project Settings → Database → Reset database password) e
volta a escrevê-la lá. Repor não parte nada: as apps usam a chave anónima, as
edge functions o service_role, e nada mais liga directamente ao Postgres.
TXT
  elif grep -qiE 'could not translate host name|Name or service not known|Network is unreachable|No route to host|Cannot assign requested address|Connection timed out|timeout expired' <<<"$saida"; then
    cat <<TXT
não se chegou ao servidor — isto **não** é a senha, nem vale a pena repô-la.
$ANFITRIAO só existe em IPv6. Confirma a saída v6 desta máquina:
  curl -6 -s -o /dev/null -w '%{http_code}\n' https://ifconfig.co
Se não houver, o caminho é o Session pooler (Project Settings → Database →
Connection string → Session pooler), onde o utilizador é postgres.$PROJECT_REF
e não postgres:
  PUNHO_DB_ANFITRIAO=<anfitriao-do-pooler> PUNHO_DB_UTILIZADOR=postgres.$PROJECT_REF \\
    $0 --verificar
(Session e não Transaction: o pg_dump precisa de sessão, o modo de transacção
parte-o a meio.)
TXT
  else
    printf 'não entrou na base:\n%s\n' "$saida"
  fi
}

passo "a falar com $ANFITRIAO como $UTILIZADOR"
versao="$(psql_na_base -e PGCONNECT_TIMEOUT=20 "$IMAGEM" \
  psql -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres -At \
       -c "select current_setting('server_version')" 2>&1)" \
  || erro "$(diagnostico_de_ligacao "$versao")"
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
  pg_dump -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres \
          --format=custom --compress=9 --schema=public \
          --file=/saida/public.dump

passo "contas → contas.dump"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  pg_dump -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres \
          --format=custom --compress=9 \
          --table=auth.users --table=auth.identities \
          --file=/saida/contas.dump

passo "tarefas agendadas → agenda.sql"
psql_na_base -v "$pasta":/saida -v "${RAIZ}/scripts":/sql:ro "$IMAGEM" \
  psql -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres -Atq \
       -o /saida/agenda.sql -f /sql/copia_agenda.sql

passo "papéis → papeis.sql"
psql_na_base -v "$pasta":/saida "$IMAGEM" \
  psql -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres -At -o /saida/papeis.sql \
    -c "select format(
          'do \$\$ begin if not exists (select 1 from pg_roles where rolname=%L)'
          || ' then create role %I nologin; end if; end \$\$;', rolname, rolname)
        from pg_roles where rolname not like 'pg\_%' order by rolname"

passo "inventário → manifesto.txt"
psql_na_base -v "$pasta":/saida -v "${RAIZ}/scripts":/sql:ro "$IMAGEM" \
  psql -h "$ANFITRIAO" -p "$PORTA" -U "$UTILIZADOR" -d postgres -At -F '|' \
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
# Marca de «correu bem», e só aqui — a pasta existir não chega, porque ela é
# criada no início e uma falha a meio deixava-a lá a fingir que houve cópia.
# É isto que a vigia lê para saber se ainda há chão. Ver vigia_de_copias.sh.
printf '%s\n%s\n' "$(date +%s)" "$pasta" > "${DESTINO}/.ultima_copia"

echo "✓ cópia feita: $pasta ($tamanho)"
echo "  $tabelas tabelas · $linhas linhas · $contas contas"
(( apagadas > 0 )) && echo "  $apagadas cópias antigas removidas"
echo
echo "Isto ainda não é um backup provado. Provar é:"
echo "  ./scripts/restaurar_prova.sh $pasta"
