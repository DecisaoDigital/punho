#!/usr/bin/env bash
# Restaura uma cópia de segurança do Punho e verifica que ela serve.
# Uso normal: ./scripts/restaurar_prova.sh            (usa a cópia mais recente)
#             ./scripts/restaurar_prova.sh <pasta>
#
# É esta a peça que transforma «temos backups» em «temos backups provados». Sem
# a correr, o que existe são ficheiros que ninguém sabe se abrem.
#
# ## Como prova
#
# Levanta um PostgreSQL 17 descartável num contentor, restaura a cópia lá
# dentro, volta a correr o mesmo inventário que se correu na base viva, e
# compara linha a linha. Depois usa a base restaurada a sério — lê uma vista
# que se monta sobre o log, chama uma função — porque restaurar tabelas e não
# conseguir fazer uma pergunta é meio restauro.
#
# No fim o contentor é destruído. Nada disto toca na base de produção: só se lê
# a pasta da cópia, e só se escreve num contentor que morre.
#
# ## O que o contentor precisa e a cópia não traz
#
# A cópia é do esquema `public`. O que a Supabase põe à volta dele — os papéis,
# o esquema `auth` com o auth.uid(), as extensões — é plataforma, não são dados
# do Punho. Recria-se aqui em baixo, como andaime.

set -Eeuo pipefail

readonly IMAGEM="postgres:17-alpine"
readonly CONTENTOR="punho-restauro-prova"
readonly BASE="verificacao"
readonly RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DESTINO="${PUNHO_COPIAS:-${HOME}/copias/punho}"

erro() { echo "✗ $*" >&2; exit 1; }
passo() { echo "· $*"; }

pasta="${1:-}"
if [[ -z "$pasta" ]]; then
  pasta="$(find "$DESTINO" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
  [[ -n "$pasta" ]] || erro "não há nenhuma cópia em $DESTINO"
fi
pasta="$(cd "$pasta" && pwd)"
for f in public.dump contas.dump papeis.sql manifesto.txt impressoes.sha256; do
  [[ -f "$pasta/$f" ]] || erro "falta $f em $pasta — cópia incompleta"
done

echo "Cópia a provar: $pasta"
echo

passo "as impressões batem certo?"
( cd "$pasta" && sha256sum --quiet --check impressoes.sha256 ) \
  || erro "um dos ficheiros mudou desde que a cópia foi feita"

limpar() { docker rm -f "$CONTENTOR" >/dev/null 2>&1 || true; }
trap limpar EXIT
limpar

passo "a levantar um PostgreSQL 17 descartável"
docker run -d --name "$CONTENTOR" \
  -e POSTGRES_PASSWORD=prova \
  -v "$pasta":/copia:ro \
  -v "${RAIZ}/scripts":/sql:ro \
  "$IMAGEM" >/dev/null

for _ in $(seq 1 60); do
  docker exec "$CONTENTOR" pg_isready -U postgres -q 2>/dev/null && break
  sleep 1
done
docker exec "$CONTENTOR" pg_isready -U postgres -q || erro "o contentor não arrancou"

no_contentor() { docker exec -i "$CONTENTOR" "$@"; }
sql() { no_contentor psql -U postgres -d "$BASE" -v ON_ERROR_STOP=1 "$@"; }

no_contentor createdb -U postgres "$BASE"
# O dump traz o `create schema public` lá dentro, e uma base nova já vem com
# um. Sem tirar este primeiro, o pg_restore queixa-se de um erro que não é
# erro nenhum — e um restauro que se queixa é um restauro em que ninguém
# confia, mesmo quando correu bem.
no_contentor psql -U postgres -d "$BASE" -q -c 'drop schema public cascade;'

passo "a montar o andaime que a Supabase dá e a cópia não traz"
no_contentor psql -U postgres -d "$BASE" -q -v ON_ERROR_STOP=1 -f /copia/papeis.sql
sql -q <<'SQL'
create schema if not exists auth;
create schema if not exists extensions;
create extension if not exists pgcrypto  with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

-- As mesmas que a Supabase instala. Sem elas, metade das políticas RLS do
-- Punho não chega sequer a ser criada: são escritas em cima do auth.uid().
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )
$$;
create or replace function auth.email() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )
$$;
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;
SQL

passo "a restaurar as contas"
queixas_contas="$(no_contentor pg_restore -U postgres -d "$BASE" /copia/contas.dump 2>&1 || true)"

passo "a restaurar o public"
queixas="$(no_contentor pg_restore -U postgres -d "$BASE" /copia/public.dump 2>&1 || true)"

passo "a recriar as tarefas agendadas (sem pg_cron, só se lê o ficheiro)"
# `grep -c` devolve 0 e sai com erro quando não encontra nada. Com `|| echo 0`
# a variável ficava com dois zeros e a linha saía partida a meio.
tarefas_no_ficheiro="$(grep -c 'cron.schedule' "$pasta/agenda.sql" 2>/dev/null || true)"

echo
echo "── o restauro trouxe o mesmo que a base tinha? ──────────────────────"
no_contentor psql -U postgres -d "$BASE" -At -F '|' -f /sql/copia_manifesto.sql \
  > /tmp/manifesto_restaurado.txt

# A única diferença esperada é o pg_cron: não carrega num contentor descartável
# (precisa de shared_preload_libraries) e por isso a agenda viaja no agenda.sql.
filtrar() { grep -v '^tarefas agendadas|' "$1" | sort; }

if diff <(filtrar "$pasta/manifesto.txt") <(filtrar /tmp/manifesto_restaurado.txt) > /tmp/diferencas.txt; then
  echo "✓ inventário idêntico, linha a linha"
  echo "   $(grep '^total de tabelas|' "$pasta/manifesto.txt" | cut -d'|' -f2) tabelas ·" \
       "$(grep '^total de linhas|'  "$pasta/manifesto.txt" | cut -d'|' -f2) linhas ·" \
       "$(grep '^politicas rls|'    "$pasta/manifesto.txt" | cut -d'|' -f2) políticas RLS ·" \
       "$(grep '^funcoes|'          "$pasta/manifesto.txt" | cut -d'|' -f2) funções ·" \
       "$(grep '^contas de utilizador|' "$pasta/manifesto.txt" | cut -d'|' -f2) contas"
  igual=true
else
  echo "✗ o restauro não deu o mesmo. Diferenças (< base viva, > restaurada):"
  sed 's/^/   /' /tmp/diferencas.txt
  igual=false
fi
echo "   tarefas agendadas: $tarefas_no_ficheiro guardadas em agenda.sql" \
     "(o pg_cron não corre no contentor)"

echo
echo "── e a base restaurada responde a perguntas? ────────────────────────"
# Restaurar tabelas não prova nada se depois não se conseguir usar a base. As
# vistas do Punho montam-se em cima do log a cada leitura; se o log veio mal,
# é aqui que se vê.
usavel=true
prova_de_uso="$(
  sql -At -F '|' 2>&1 <<'SQL'
select 'clientes que a vista monta a partir do log', count(*)::text from punho_clientes
union all
select 'operações no log', count(*)::text from punho_operacoes
union all
select 'reservas projectadas', count(*)::text from punho_reservas
union all
select 'a função de apagamento RGPD existe',
       case when to_regprocedure('public.punho_apagar_titular(text,text,text)') is null
            then 'NÃO' else 'sim' end
union all
select 'a função de expurgo existe',
       case when to_regprocedure('public.punho_expurgar_dados()') is null
            then 'NÃO' else 'sim' end
union all
select 'linhas de auditoria a apontar para o vazio',
       count(*)::text from licencas_audit a
       where a.licenca_id is not null
         and not exists (select 1 from licencas l where l.id = a.licenca_id);
SQL
)" || usavel=false

if $usavel; then
  echo "$prova_de_uso" | awk -F'|' '{ printf "   %-46s %s\n", $1, $2 }'
else
  # Sem isto, uma consulta que rebenta deixava a saída vazia — e vazia não tem
  # a palavra NÃO lá dentro, portanto a prova dava-se por boa. Era o pior
  # defeito possível numa prova: passar por não ter conseguido perguntar.
  echo "✗ a base restaurada não respondeu:"
  echo "$prova_de_uso" | sed 's/^/   /' | head -10
fi

if [[ -n "$queixas" || -n "$queixas_contas" ]]; then
  echo
  echo "── o pg_restore queixou-se ──────────────────────────────────────────"
  printf '%s\n%s\n' "$queixas_contas" "$queixas" | grep -v '^$' | sed 's/^/   /' | head -30
fi

echo
if $igual && $usavel && ! grep -q 'NÃO' <<<"$prova_de_uso"; then
  echo "✓ cópia provada: restaurou inteira e a base restaurada funciona."
  echo "  Contentor destruído. A produção não foi tocada."
  exit 0
fi
echo "✗ esta cópia NÃO está provada. Ver acima."
exit 1
