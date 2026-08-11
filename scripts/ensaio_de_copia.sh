#!/usr/bin/env bash
# Corre a cadeia de cópias de segurança inteira contra uma base que faz de
# produção. Uso: ./scripts/ensaio_de_copia.sh
#
# ## Para que serve
#
# O `copia_de_seguranca.sh` e o `restaurar_prova.sh` só se podem correr a sério
# com a senha da base de produção. Enquanto ela não existir, são trezentas e
# tal linhas de shell que nunca correram — e código que nunca correu não
# funciona, apenas ainda não se sabe onde falha.
#
# Este ensaio levanta um PostgreSQL 17 com a forma da base do Punho — os
# papéis, o esquema `auth`, o log de operações, as vistas com
# `security_invoker`, o RLS, os gatilhos, as funções do RGPD — e manda os dois
# scripts trabalharem contra ele. São os mesmos scripts, sem ramo de teste lá
# dentro: só muda para onde apontam.
#
# O que fica por ensaiar é exactamente uma coisa: a ligação à Supabase. Quando
# a senha aparecer, é a única variável nova.
#
# A base de produção não é tocada em momento nenhum.

set -Eeuo pipefail

readonly RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGEM="postgres:17-alpine"
readonly FALSA="pg-falsa-producao"
readonly PORTA=55432
readonly SENHA="ensaio-sem-segredo"

BANCADA="$(mktemp -d)"
limpar() {
  docker rm -f "$FALSA" >/dev/null 2>&1 || true
  rm -rf "$BANCADA"
}
trap limpar EXIT

erro() { echo "✗ $*" >&2; exit 1; }
passo() { echo "· $*"; }

echo "Ensaio da cadeia de cópias — a produção não é tocada."
echo

passo "a levantar a base que faz de produção (porta $PORTA)"
docker rm -f "$FALSA" >/dev/null 2>&1 || true
docker run -d --name "$FALSA" -e POSTGRES_PASSWORD="$SENHA" \
  -p "$PORTA":5432 "$IMAGEM" >/dev/null
for _ in $(seq 1 60); do
  docker exec "$FALSA" pg_isready -U postgres -q 2>/dev/null && break
  sleep 1
done
docker exec "$FALSA" pg_isready -U postgres -q || erro "a base de ensaio não arrancou"

passo "a dar-lhe a forma da base do Punho"
docker exec -i "$FALSA" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  criado_em timestamptz not null default now());
create table auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fornecedor text not null default 'email');
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

insert into auth.users(email) values ('gestor@ensaio.pt'), ('operador@ensaio.pt');
insert into auth.identities(user_id) select id from auth.users;

-- O log, que é a coisa de que tudo o resto se monta.
create table public.punho_operacoes (
  seq bigserial primary key,
  empresa_id uuid not null,
  entidade text not null,
  entidade_id text not null,
  payload jsonb not null default '{}'::jsonb,
  feito_em timestamptz not null default now());

create table public.punho_reservas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null,
  cliente_nome_snapshot text,
  inicio timestamptz not null default now());

create table public.licencas (
  id uuid primary key default gen_random_uuid(),
  machine_id text not null,
  app text);

create table public.licencas_audit (
  id bigserial primary key,
  licenca_id uuid references public.licencas(id) on delete set null,
  licenca_machine_id text,
  operacao text not null);

create table public.punho_apagamentos (
  id bigserial primary key,
  empresa_id uuid not null,
  entidade text not null,
  feito_em timestamptz not null default now());

create table public.punho_expurgos (
  id bigserial primary key,
  corrido_em timestamptz not null default now(),
  contagens jsonb not null default '{}'::jsonb);

-- A vista lê o log a cada leitura, como as do Punho. `security_invoker` é o
-- que faz o RLS aplicar-se a quem pergunta, e não ao dono da vista.
create view public.punho_clientes with (security_invoker = on) as
  select distinct on (empresa_id, entidade_id)
         empresa_id, entidade_id, payload->>'name' as nome
    from public.punho_operacoes
   where entidade = 'customer'
   order by empresa_id, entidade_id, seq desc;

alter table public.punho_operacoes enable row level security;
create policy "membro le o log da sua empresa" on public.punho_operacoes
  for select to public using (auth.uid() is not null);

create or replace function public.punho_carimba_operacao() returns trigger
language plpgsql as $$
begin
  new.feito_em := coalesce(new.feito_em, now());
  return new;
end $$;
create trigger punho_carimba before insert on public.punho_operacoes
  for each row execute function public.punho_carimba_operacao();

create or replace function public.punho_apagar_titular(
  p_entidade text, p_entidade_id text, p_motivo text default null)
returns jsonb language sql security definer set search_path to 'public'
as $$ select jsonb_build_object('ok', true) $$;

create or replace function public.punho_expurgar_dados()
returns jsonb language sql security definer set search_path to 'public'
as $$ select jsonb_build_object('ok', true) $$;

grant select, insert on all tables in schema public to authenticated;

insert into public.punho_operacoes(empresa_id, entidade, entidade_id, payload)
select '11111111-2222-3333-4444-555555555555',
       'customer', 'cli-'||g,
       jsonb_build_object('name', 'Cliente '||g, 'phone', '9130000'||g)
  from generate_series(1, 40) g;
insert into public.punho_reservas(empresa_id, cliente_nome_snapshot)
select '11111111-2222-3333-4444-555555555555', 'Cliente '||g
  from generate_series(1, 12) g;
insert into public.licencas(machine_id, app) values ('maq-ensaio-1', 'punho');
insert into public.licencas_audit(licenca_id, licenca_machine_id, operacao)
select id, machine_id, 'INSERT' from public.licencas;
SQL

passo "a apontar os scripts para ela"
cat > "$BANCADA/copia.env" <<EOF
PGPASSWORD=$SENHA
EOF
chmod 600 "$BANCADA/copia.env"

export PUNHO_COPIA_CONFIG="$BANCADA/copia.env"
export PUNHO_DB_ANFITRIAO=localhost
export PUNHO_DB_PORTA="$PORTA"
export PUNHO_COPIAS="$BANCADA/copias"

echo
echo "════════ 1. tirar a cópia ════════"
"$RAIZ/scripts/copia_de_seguranca.sh" || erro "o copia_de_seguranca.sh falhou"

pasta="$(find "$PUNHO_COPIAS" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
[[ -n "$pasta" ]] || erro "não ficou nenhuma pasta de cópia"

echo
echo "════════ 2. o que a cópia levou ════════"
for f in public.dump contas.dump papeis.sql agenda.sql manifesto.txt impressoes.sha256; do
  [[ -s "$pasta/$f" ]] || erro "$f não existe ou está vazio"
  printf '   %-20s %s\n' "$f" "$(du -h "$pasta/$f" | cut -f1)"
done
echo "   agenda.sql diz: $(head -1 "$pasta/agenda.sql")"

echo
echo "════════ 3. provar o restauro ════════"
"$RAIZ/scripts/restaurar_prova.sh" "$pasta" || erro "o restaurar_prova.sh não deu a cópia por provada"

echo
echo "════════ 4. e a prova sabe dizer que não? ════════"
# Uma prova que só sabe dizer que sim não prova nada. Estragam-se cópias de
# duas maneiras diferentes e exige-se que ela dê por ambas.

# (a) Ficheiro mexido: quem tem de dar o alarme são as impressões.
cp -r "$pasta" "$BANCADA/rasurada"
printf 'lixo' >> "$BANCADA/rasurada/public.dump"
if "$RAIZ/scripts/restaurar_prova.sh" "$BANCADA/rasurada" >/dev/null 2>&1; then
  erro "o public.dump foi rasurado e o restaurar_prova.sh deu a cópia por boa"
fi
echo "   ✓ ficheiro rasurado — recusado pelas impressões"

# (b) Cópia inteira e assinada, mas a dizer que tem mais do que tem. É o caso
# que interessa: as impressões batem certo, e o que tem de dar o alarme é a
# comparação do inventário. Sem isto, o teste de cima só provava o sha256.
cp -r "$pasta" "$BANCADA/mentirosa"
sed -i 's/^tabela punho_operacoes|40$/tabela punho_operacoes|41/' \
  "$BANCADA/mentirosa/manifesto.txt"
grep -q '^tabela punho_operacoes|41$' "$BANCADA/mentirosa/manifesto.txt" \
  || erro "o ensaio não conseguiu falsificar o manifesto — o formato mudou?"
( cd "$BANCADA/mentirosa" && rm -f impressoes.sha256 && sha256sum ./* > impressoes.sha256 )
if "$RAIZ/scripts/restaurar_prova.sh" "$BANCADA/mentirosa" >/dev/null 2>&1; then
  erro "faltava uma linha e o restaurar_prova.sh deu a cópia por boa"
fi
echo "   ✓ contagem que não bate — recusada pela comparação"

echo
echo "✓ ensaio completo. A cadeia funciona ponta a ponta."
echo "  O que falta provar contra a produção é só a ligação à Supabase."
