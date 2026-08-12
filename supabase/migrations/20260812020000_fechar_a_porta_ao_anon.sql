-- Achado 3.5 da auditoria de 11/8/2026 — fechar a porta ao `anon`.
--
-- ## O nó que estava atado
--
-- Cinco funções `SECURITY DEFINER` eram executáveis pelo `anon`. Revogá-las
-- parecia óbvio, e partia tudo: 26 políticas estavam declaradas `to public`, e
-- `public` inclui o `anon`. Como são as políticas que chamam
-- `punho_empresa_atual()` e companhia, revogar o EXECUTE trocava «zero linhas»
-- por `permission denied` — a app deixava de arrancar.
--
-- Desata-se pela outra ponta. Primeiro as políticas passam a `to authenticated`
-- (o `anon` deixa de as avaliar), e só depois se revoga o EXECUTE.
--
-- ## O que isto muda no comportamento: nada
--
-- Das 26 políticas, 24 exigem `punho_empresa_atual()`, `punho_e_gestor()` ou
-- `auth.uid()`, que para o `anon` são sempre nulos — a regra já dava falso.
-- Passar a `to authenticated` diz explicitamente o que já era verdade, e é isso
-- que permite fechar o resto.
--
-- As duas que **não** são disso são INSERT com regra `true`
-- (`aceites_termos` e `pings`): essas o `anon` precisa mesmo. Ficam declaradas
-- `to anon, authenticated`, que é mais preciso do que `public` — `public` também
-- abrangia o `postgres` e o `service_role`, que não têm nada que estar aí.
--
-- ## O que fica de fora, e porquê
--
-- `punho_validar_convite` continua executável pelo `anon`: é chamada no registo,
-- antes de haver sessão. Não se fecha — trava-se. Ver o fim do ficheiro.

-- ── 1. as políticas que só fazem sentido com sessão ───────────────────────────

alter policy "empresa_membros" on public.punho_campanhas to authenticated;
alter policy "autor ou gestor apaga documento" on public.punho_documentos to authenticated;
alter policy "membro cria proprio documento" on public.punho_documentos to authenticated;
alter policy "autor ou gestor le documentos" on public.punho_documentos to authenticated;
alter policy "autor ou gestor altera documento" on public.punho_documentos to authenticated;
alter policy "empresa_gestor" on public.punho_eventos_auditoria to authenticated;
alter policy "empresa_membros" on public.punho_instalacoes to authenticated;
alter policy "punho_leads_entrada_membro_le" on public.punho_leads_entrada to authenticated;
alter policy "punho_leads_entrada_membro_actualiza" on public.punho_leads_entrada to authenticated;
alter policy "punho_operacoes_membro_le" on public.punho_operacoes to authenticated;
alter policy "gestor cria o painel da sua empresa" on public.punho_painel to authenticated;
alter policy "gestor le o painel da sua empresa" on public.punho_painel to authenticated;
alter policy "gestor altera o painel da sua empresa" on public.punho_painel to authenticated;
alter policy "empresa le a sua posicao" on public.punho_projeccao_posicao to authenticated;
alter policy "empresa le" on public.punho_reserva_maquinas to authenticated;
alter policy "empresa le" on public.punho_reservas to authenticated;
alter policy "gestor le subscricao" on public.punho_subscricoes to authenticated;

-- As sete tabelas `*_copia_2026_08_09` estão vazias e à espera de decisão sobre
-- se se apagam. Enquanto existirem, as políticas delas acompanham as outras —
-- deixar sete `to public` para trás era ficar com a porta entreaberta por
-- distracção.
alter policy "empresa le" on public.punho_clientes_copia_2026_08_09 to authenticated;
alter policy "gestor le" on public.punho_colaboradores_copia_2026_08_09 to authenticated;
alter policy "gestor le" on public.punho_despesas_copia_2026_08_09 to authenticated;
alter policy "empresa le" on public.punho_leads_copia_2026_08_09 to authenticated;
alter policy "empresa le" on public.punho_maquinas_copia_2026_08_09 to authenticated;
alter policy "empresa le" on public.punho_recebimentos_copia_2026_08_09 to authenticated;
alter policy "gestor le" on public.punho_veiculos_copia_2026_08_09 to authenticated;

-- ── 2. as duas que o `anon` precisa mesmo, ditas com precisão ────────────────

alter policy "insert_termos" on public.aceites_termos to anon, authenticated;
alter policy "insert_pings" on public.pings to anon, authenticated;

-- ── 3. e agora sim, a chave ──────────────────────────────────────────────────

revoke execute on function public.punho_empresa_atual() from anon;
revoke execute on function public.punho_e_gestor() from anon;
revoke execute on function public.punho_membro_ativo() from anon;
revoke execute on function public.punho_perfil_na_empresa(uuid) from anon;

-- ── 4. o travão do `punho_validar_convite` ───────────────────────────────────
--
-- Esta fica aberta ao `anon` por necessidade: é chamada no ecrã de registo,
-- antes de haver sessão. O problema é que responde `valido`/`invalido` a
-- qualquer código, e isso é uma máquina de adivinhar códigos de convite — e um
-- convite aceite dá entrada numa empresa.
--
-- Conta-se por origem do pedido, não por código: quem adivinha muda o código a
-- cada tentativa, a origem é que não muda.

create table if not exists public.punho_tentativas_convite (
  id      bigserial primary key,
  chave   text        not null,
  quando  timestamptz not null default now()
);

create index if not exists punho_tentativas_convite_chave_quando
  on public.punho_tentativas_convite (chave, quando desc);

-- Ninguém lê nem escreve isto de fora. Quem escreve é a função, que corre como
-- dona. RLS ligada e zero políticas é o que diz «esta tabela não é da API».
alter table public.punho_tentativas_convite enable row level security;
revoke all on table public.punho_tentativas_convite from anon, authenticated;

create or replace function public.punho_validar_convite(p_codigo text)
returns text
language plpgsql
-- VOLATILE e já não STABLE: contar tentativas obriga a escrever. O cliente
-- chama isto por POST, portanto a mudança não lhe toca.
volatile security definer
set search_path to 'public'
as $function$
declare
  v        public.punho_convites%rowtype;
  v_chave  text;
  v_falhas int;
begin
  -- De onde veio o pedido. O PostgREST põe os cabeçalhos em `request.headers`;
  -- fora dele (psql, um teste) não há nenhum, e aí tudo cai no mesmo balde em
  -- vez de passar sem conta. O `begin/exception` é porque um cabeçalho
  -- malformado não pode ser motivo para o registo deixar de funcionar.
  begin
    v_chave := split_part(
      nullif(current_setting('request.headers', true), '')::json ->> 'x-forwarded-for',
      ',', 1);
  exception when others then
    v_chave := null;
  end;
  v_chave := coalesce(nullif(trim(coalesce(v_chave, '')), ''), 'sem-origem');

  -- Os endereços não ficam: apagam-se à hora. O travão precisa de 15 minutos de
  -- memória, não de um histórico de quem tentou entrar.
  delete from public.punho_tentativas_convite where quando < now() - interval '1 hour';

  select count(*) into v_falhas
    from public.punho_tentativas_convite
   where chave = v_chave
     and quando > now() - interval '15 minutes';

  -- 60 em 15 minutos, e o número tem conta por trás.
  --
  -- O código é `gen_random_bytes(5)` em hex: 10 caracteres, 1,1 biliões de
  -- combinações. Com uma dezena de convites válidos ao mesmo tempo, a hipótese
  -- por tentativa é de ~9 em 10^12 — a força bruta já era impossível pelo
  -- tamanho do código, não por causa deste travão. O que o travão faz é parar
  -- martelagem automática: um script a tentar 10 por segundo bate no tecto em
  -- seis segundos.
  --
  -- Do outro lado está um risco a sério: numa lavandaria os empregados
  -- partilham o mesmo IP. Um limite apertado transformava «quatro pessoas a
  -- registarem-se na mesma manhã, com enganos pelo meio» num bloqueio — e isso
  -- é o onboarding partido para pagar uma segurança que o código já dava.
  if v_falhas >= 60 then
    return 'bloqueado';
  end if;

  if nullif(trim(coalesce(p_codigo, '')), '') is null then
    return 'invalido';
  end if;

  select * into v from public.punho_convites
   where upper(codigo) = upper(trim(p_codigo));

  if not found then
    -- Só o código que não existe conta para o travão. Um convite já usado ou
    -- expirado é quase sempre alguém legítimo a insistir, e esse não se castiga.
    insert into public.punho_tentativas_convite(chave) values (v_chave);
    return 'invalido';
  end if;

  if v.usado then return 'usado'; end if;
  if v.expira_em <= now() then return 'expirado'; end if;
  return 'valido';
end;
$function$;

