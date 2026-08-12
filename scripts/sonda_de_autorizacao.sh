#!/usr/bin/env bash
# Sonda de autorização: o que o anónimo consegue, e o que cada perfil continua
# a conseguir.
#
# Corre-se **antes e depois** de mexer em políticas ou permissões, e comparam-se
# as duas saídas. Responde à única pergunta que interessa numa migração destas:
# fechei a porta ao anónimo sem fechar a porta ao cliente?
#
# ## Duas camadas, de propósito
#
# O lado anónimo vai por **HTTP a sério**, com a chave anónima, porque é assim
# que um estranho chega à base — e porque o REST tem uma camada que o SQL não
# tem: os GRANT de tabela, que devolvem 401 antes de a RLS chegar a ser
# avaliada.
#
# O lado autenticado vai por **dentro da base**, assumindo o papel e os claims
# como o PostgREST faz (`set local role authenticated` +
# `request.jwt.claims`). A primeira versão desta sonda entrava com email e
# senha das contas de ensaio, e não durou uma noite: o teste de recuperação de
# palavra-passe de 9/8 mudou a senha no servidor e o
# `~/.punho/contas_teste.env` ficou para trás. Uma sonda que depende de
# credenciais é uma sonda que deixa de responder no dia em que é precisa.
#
# Só faz leituras. Não escreve nada, não muda senhas, não cria contas.

set -Eeuo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGEM="postgres:17-alpine"
readonly ANFITRIAO="db.oefqbkhioncakojipqyx.supabase.co"

# shellcheck disable=SC1091
source "${RAIZ}/.env"
# shellcheck disable=SC1091
source "${HOME}/.punho/copia.env"

URL="${SUPABASE_URL%/}"
ANON="$SUPABASE_ANON_KEY"

# As tabelas que interessam: as que a app lê a toda a hora e as que guardam o
# que não pode escapar.
readonly TABELAS=(
  punho_operacoes punho_reservas punho_documentos punho_painel
  punho_empresas punho_membros punho_leads_entrada punho_instalacoes
  punho_campanhas punho_subscricoes punho_eventos_auditoria
  punho_convites licencas chaves_mestre
)

readonly FUNCOES=(punho_empresa_atual punho_e_gestor punho_membro_ativo)

resultado() { printf '  %-34s %s\n' "$1" "$2"; }

echo "═══ o ANÓNIMO, por HTTP ═══"

resultado "rpc punho_validar_convite" \
  "$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "$URL/rest/v1/rpc/punho_validar_convite" \
      -H "apikey: $ANON" -H "Content-Type: application/json" \
      -d '{"p_codigo":"CODIGO-QUE-NAO-EXISTE"}')  ← tem de continuar a abrir"

for f in "${FUNCOES[@]}"; do
  resultado "rpc $f" \
    "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/rest/v1/rpc/$f" \
        -H "apikey: $ANON" -H "Content-Type: application/json" -d '{}')"
done

for t in "${TABELAS[@]}"; do
  corpo="$(curl -s "$URL/rest/v1/$t?select=*&limit=1" -H "apikey: $ANON")"
  codigo="$(curl -s -o /dev/null -w '%{http_code}' \
             "$URL/rest/v1/$t?select=*&limit=1" -H "apikey: $ANON")"
  extra=""
  [[ "$corpo" == "[]" ]] && extra=" (lista vazia)"
  [[ "$corpo" != "[]" && "$codigo" == "200" ]] && extra="  ⚠ DEVOLVEU DADOS"
  resultado "select $t" "${codigo}${extra}"
done

echo
echo "═══ o ANÓNIMO a escrever (as cinco que tem de conseguir) ═══"
# Manda-se um corpo vazio de propósito. Se a autorização passar, o Postgres
# queixa-se do conteúdo (400/409) — e é isso que se quer ver. Um 401 aqui quer
# dizer que se fechou uma porta que tinha de ficar aberta. Nenhuma linha é
# escrita: o pedido morre na validação.
for t in pings punho_erros aceites_termos sugestoes pedidos_ajuda; do
  c="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/rest/v1/$t" \
        -H "apikey: $ANON" -H "Content-Type: application/json" -d '{}')"
  aviso=""
  [[ "$c" == "401" || "$c" == "403" ]] && aviso="  ⚠ FECHADO DE MAIS"
  resultado "insert $t" "${c}${aviso}"
done

echo
echo "═══ os perfis, por dentro da base ═══"

PGPASS_TMP="$(mktemp)"; chmod 600 "$PGPASS_TMP"
printf '%s:5432:*:postgres:%s\n' "$ANFITRIAO" "$PGPASSWORD" > "$PGPASS_TMP"
trap 'rm -f "$PGPASS_TMP"' EXIT

# `-i` é obrigatório: sem ele o docker não encaminha o stdin e o psql recebe um
# script vazio — corre, sai com 0, e não diz nada. Uma sonda muda a ficar em
# silêncio é pior do que não a ter.
na_base() {
  docker run --rm -i --network host --user "$(id -u):$(id -g)" \
    -v "$PGPASS_TMP":/tmp/.pgpass:ro -e PGPASSFILE=/tmp/.pgpass \
    "$IMAGEM" psql -h "$ANFITRIAO" -U postgres -d postgres -q -At "$@"
}

# Quem é quem sai da base, não daqui: um id de utilizador escrito à mão neste
# ficheiro apodrece na primeira vez que se semeia o ambiente de ensaio outra vez.
perfis="$(na_base -F '|' -c "
  select m.perfil, u.id::text, e.nome
    from auth.users u
    join punho_membros m on m.user_id = u.id
    join punho_empresas e on e.id = m.empresa_id
   where u.email like '%nocturno%' and m.ativo
   order by m.perfil;")"

if [[ -z "$perfis" ]]; then
  echo "  ✗ não há contas de ensaio activas — semeia o ambiente primeiro"
  exit 1
fi

# Lê-se tudo para um vector antes do ciclo: o psql lá dentro também lê do stdin,
# e um ciclo alimentado por stdin perde as linhas que o comando de dentro comer.
mapfile -t linhas <<<"$perfis"

for linha in "${linhas[@]}"; do
  IFS='|' read -r perfil uid empresa <<<"$linha"
  [[ -z "$perfil" ]] && continue
  echo "  ── $perfil ($empresa)"
  # `set local role` + claims é exactamente o que o PostgREST faz a cada
  # pedido. Dentro de uma transacção que acaba em rollback, portanto nada disto
  # deixa rasto.
  na_base -v uid="$uid" <<'SQL' 2>&1 | sed 's/^NOTICE:  /    /' | grep -vE '^\{"sub"|^$'
begin;
select set_config('request.jwt.claims',
       json_build_object('sub', :'uid', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
declare t text; n bigint;
begin
  foreach t in array array['punho_operacoes','punho_reservas','punho_documentos',
                           'punho_painel','punho_empresas','punho_membros',
                           'punho_leads_entrada','punho_instalacoes',
                           'punho_campanhas','punho_subscricoes',
                           'punho_eventos_auditoria','licencas','chaves_mestre']
  loop
    begin
      execute format('select count(*) from public.%I', t) into n;
      raise notice '% % linhas', rpad(t, 26), n;
    exception when others then
      raise notice '% RECUSADO (%)', rpad(t, 26), sqlerrm;
    end;
  end loop;
  foreach t in array array['punho_empresa_atual','punho_e_gestor','punho_membro_ativo']
  loop
    begin
      execute format('select 1 from (select public.%I()) x', t);
      raise notice '% corre', rpad(t, 26);
    exception when others then
      raise notice '% RECUSADO (%)', rpad(t, 26), sqlerrm;
    end;
  end loop;
end $$;
rollback;
SQL
done

echo
echo "200 = deixa · 401/403 = recusa · lista vazia = a RLS filtrou"
