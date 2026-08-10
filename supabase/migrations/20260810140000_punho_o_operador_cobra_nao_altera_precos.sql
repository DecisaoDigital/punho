-- O operador cobra, não altera preços.
--
-- `punho_colaborador_pode_escrever` autoriza por **entidade**, e uma entidade
-- inteira é grosso demais: `booking → true` quer dizer que o operador pode
-- reescrever o preço, o desconto, o cliente e as datas contratadas da reserva;
-- `machine → true` quer dizer que pode mudar o preço por dia e o valor de
-- compra de qualquer máquina. Ele só precisava de mudar o **estado**.
--
-- O comentário que lá está diz que apertar isto exigiria comparar com o
-- "antes", que o registo não guardava. Já não é verdade: o "antes" é a última
-- operação daquela entidade — exactamente o que as vistas `punho_maquinas`,
-- `punho_clientes` e companhia devolvem desde 9/8, e o que o índice
-- `punho_operacoes_projeccao_idx (entidade, empresa_id, entidade_id, seq desc)`
-- já sabe encontrar numa leitura só.
--
-- A matriz, dita pelo Cesar:
--
--   máquina     estado, notas, fotos          | preço/dia, valor de compra,
--                                             | referência, categoria, nome,
--                                             | arquivar — e criar máquinas
--   reserva     estado, notas, responsável    | preço, cliente, máquinas,
--                                             | datas contratadas
--   cliente     contactos                     | arquivar
--   recebimento criar                         | mexer num já registado
--   lead        tudo                          | —
--   despesa     as dele (ver o carimbo)       | as dos outros
--   viatura,    —                             | tudo (nem chega aqui: a
--   ficha                                     |  política já os recusa)
--
-- **Falha fechada.** Campo que a matriz não conheça — porque uma versão futura
-- da app o inventou — é campo proibido. É o mesmo princípio que
-- `punho_colaborador_pode_escrever` já aplica a entidades desconhecidas.
--
-- A política continua a ser a primeira barreira (a entidade); este gatilho é a
-- segunda (o campo). Nenhuma substitui a outra: sem a política, uma entidade
-- nova nasce aberta; sem o gatilho, uma entidade autorizada abre-se toda.

-- ---------------------------------------------------------------------------
-- O que mudou entre o "antes" e o que chega
-- ---------------------------------------------------------------------------
-- Ausente e `null` são a mesma coisa de propósito. Uma máquina gravada antes de
-- `purchasePriceCents` existir não traz a chave; a app de hoje traz a chave a
-- `null`. Sem esta tolerância, entregar essa máquina era recusado por "alterar
-- o valor de compra" — e a entrega, que é o trabalho dele, ia para a
-- quarentena.
create or replace function public.punho_campos_alterados(
  p_antes  jsonb,
  p_depois jsonb
) returns text[]
language sql
immutable
set search_path = public
as $fn$
  select coalesce(array_agg(chave order by chave), array[]::text[])
  from (
    select k from jsonb_object_keys(coalesce(p_antes,  '{}'::jsonb)) as t(k)
    union
    select k from jsonb_object_keys(coalesce(p_depois, '{}'::jsonb)) as t(k)
  ) as chaves(chave)
  where nullif(p_antes  -> chave, 'null'::jsonb)
        is distinct from
        nullif(p_depois -> chave, 'null'::jsonb)
$fn$;

-- ---------------------------------------------------------------------------
-- A matriz, em dados
-- ---------------------------------------------------------------------------
-- Uma função só, com a lista de campos que o operador pode mexer em cada
-- entidade. `'*'` é o único curinga e quer dizer "sem restrição de campo" —
-- está em `lead` (não há lá nada que doa) e em `expense` (a despesa é dele; o
-- gatilho do carimbo é que garante que não toca nas dos outros).
--
-- Array vazio quer dizer o contrário: existe, mas não se altera nada. É o caso
-- do recebimento — regista-se uma vez e fica.
create or replace function public.punho_colaborador_campos_livres(
  p_entidade text
) returns text[]
language sql
immutable
set search_path = public
as $fn$
  select case p_entidade
    -- Entregar, recolher, pôr em manutenção. E o que se escreve na obra.
    when 'machine' then array['status', 'notes', 'photoPaths']

    -- Confirmar, entregar, recolher, fechar. Quem ficou responsável pelo
    -- trabalho é ele a assumi-lo, não é dinheiro.
    when 'booking' then array[
      'status', 'notes',
      'collaboratorResponsibleId', 'collaboratorNameSnapshot'
    ]

    -- Corrigir contactos, sim. Arquivar, não.
    when 'customer' then array[
      'name', 'phone', 'taxId', 'email',
      'address', 'postalCode', 'locality', 'notes', 'companyId'
    ]

    -- Um recebimento já registado não se emenda.
    when 'receipt' then array[]::text[]

    when 'lead'    then array['*']
    when 'expense' then array['*']

    else array[]::text[]  -- falha fechada
  end
$fn$;

-- Se aquela alteração cabe na matriz.
create or replace function public.punho_colaborador_pode_alterar(
  p_entidade  text,
  p_alterados text[]
) returns boolean
language sql
immutable
set search_path = public
as $fn$
  select case
    -- Reenviar a mesma coisa não é alterar nada. Acontece a cada carga inicial
    -- de um aparelho que já tinha recebido tudo.
    when coalesce(cardinality(p_alterados), 0) = 0 then true
    when '*' = any(public.punho_colaborador_campos_livres(p_entidade)) then true
    else not exists (
      select 1
      from unnest(p_alterados) as c
      where not (c = any(public.punho_colaborador_campos_livres(p_entidade)))
    )
  end
$fn$;

-- Entidade que ainda não existe: aplica-se a regra de criação, não a de campos.
--
-- Máquinas de fora: o inventário é do gestor. Isto trava também a carga inicial
-- de um operador que tenha andado a brincar com a app antes de entrar na
-- empresa — as máquinas dele não entram no inventário de ninguém.
create or replace function public.punho_colaborador_pode_criar(
  p_entidade text
) returns boolean
language sql
immutable
set search_path = public
as $fn$
  select p_entidade in ('customer', 'lead', 'booking', 'receipt', 'expense')
$fn$;

-- ---------------------------------------------------------------------------
-- Dizê-lo em português
-- ---------------------------------------------------------------------------
-- «Não podes alterar dailyRateCents» não é uma frase para quem está na obra.
create or replace function public.punho_rotulo_do_campo(p_campo text)
returns text
language sql
immutable
set search_path = public
as $fn$
  select case p_campo
    when 'dailyRateCents'      then 'o preço por dia'
    when 'purchasePriceCents'  then 'o valor de compra'
    when 'expectedValueCents'  then 'o valor combinado'
    when 'amountCents'         then 'o valor'
    when 'reference'           then 'a referência'
    when 'category'            then 'a categoria'
    when 'name'                then 'o nome'
    when 'archived'            then 'o arquivo'
    when 'acquiredOn'          then 'a data de aquisição'
    when 'customerId'          then 'o cliente'
    when 'machineIds'          then 'as máquinas'
    when 'startsAt'            then 'a data de início'
    when 'endsAt'              then 'a data de fim'
    when 'method'              then 'o método de pagamento'
    when 'date'                then 'a data'
    when 'photoPaths'          then 'as fotografias'
    else '«' || p_campo || '»'
  end
$fn$;

-- Duas formas da mesma palavra, porque as duas frases pedem cada uma a sua:
-- «Criar máquinas é do gestor» e «não podes alterar o preço por dia da
-- máquina». Uma só dava «Criar a máquina» ou «Em a máquina».
create or replace function public.punho_entidade_no_plural(p_entidade text)
returns text
language sql
immutable
set search_path = public
as $fn$
  select case p_entidade
    when 'machine'      then 'máquinas'
    when 'booking'      then 'trabalhos'
    when 'customer'     then 'clientes'
    when 'receipt'      then 'recebimentos'
    when 'lead'         then 'pedidos'
    when 'expense'      then 'despesas'
    when 'vehicle'      then 'viaturas'
    when 'collaborator' then 'fichas de pessoal'
    else 'isso'
  end
$fn$;

create or replace function public.punho_entidade_com_de(p_entidade text)
returns text
language sql
immutable
set search_path = public
as $fn$
  select case p_entidade
    when 'machine'      then 'da máquina'
    when 'booking'      then 'do trabalho'
    when 'customer'     then 'do cliente'
    when 'receipt'      then 'do recebimento'
    when 'lead'         then 'do pedido'
    when 'expense'      then 'da despesa'
    when 'vehicle'      then 'da viatura'
    when 'collaborator' then 'da ficha'
    else ''
  end
$fn$;

-- ---------------------------------------------------------------------------
-- O gatilho
-- ---------------------------------------------------------------------------
-- `security definer` para ler o "antes" sem passar pela política de leitura do
-- próprio registo: o colaborador não vê `collaborator` nem `vehicle`, e mesmo o
-- que vê seria uma leitura a mais dentro de cada escrita.
--
-- Sai logo por dois caminhos: sem sessão (é uma edge function com a chave de
-- serviço, ou o projector) e perfil que não seja colaborador. O gestor não
-- passa por aqui.
create or replace function public.punho_operacoes_campos_do_colaborador()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_antes     jsonb;
  v_alterados text[];
  v_proibidos text[];
  v_lista     text;
begin
  if auth.uid() is null then
    return new;
  end if;

  if punho_perfil_na_empresa(new.empresa_id) is distinct from 'colaborador' then
    return new;
  end if;

  select o.payload
    into v_antes
    from punho_operacoes o
   where o.entidade   = new.entidade
     and o.empresa_id = new.empresa_id
     and o.entidade_id = new.entidade_id
   order by o.seq desc
   limit 1;

  -- Nasce agora.
  if v_antes is null then
    if not punho_colaborador_pode_criar(new.entidade) then
      raise exception 'Criar % é do gestor.',
        punho_entidade_no_plural(new.entidade)
        using errcode = '42501';
    end if;
    return new;
  end if;

  v_alterados := punho_campos_alterados(v_antes, new.payload);

  if punho_colaborador_pode_alterar(new.entidade, v_alterados) then
    return new;
  end if;

  select array_agg(punho_rotulo_do_campo(c) order by c)
    into v_proibidos
    from unnest(v_alterados) as c
   where not (c = any(punho_colaborador_campos_livres(new.entidade)));

  -- O recebimento não tem campos livres nenhuns: enumerá-los seria dizer
  -- «não podes alterar o valor, a data, o método» quando o que se quer dizer é
  -- que ele não se altera de todo.
  if new.entidade = 'receipt' then
    raise exception
      'Um recebimento já registado não se altera. Fala com o gestor.'
      using errcode = '42501';
  end if;

  v_lista := array_to_string(v_proibidos, ', ');

  raise exception 'Não podes alterar % %. Isso é do gestor.',
    v_lista, punho_entidade_com_de(new.entidade)
    using errcode = '42501';
end;
$fn$;

-- Nada disto é para ser chamado de fora: quem chama é o gatilho, que corre como
-- dono. `punho_colaborador_pode_escrever` continua a precisar do `execute` de
-- `authenticated` porque vive dentro de uma política — estas não.
revoke all on function public.punho_campos_alterados(jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.punho_colaborador_campos_livres(text)
  from public, anon, authenticated;
revoke all on function public.punho_colaborador_pode_alterar(text, text[])
  from public, anon, authenticated;
revoke all on function public.punho_colaborador_pode_criar(text)
  from public, anon, authenticated;
revoke all on function public.punho_rotulo_do_campo(text)
  from public, anon, authenticated;
revoke all on function public.punho_entidade_no_plural(text)
  from public, anon, authenticated;
revoke all on function public.punho_entidade_com_de(text)
  from public, anon, authenticated;
revoke all on function public.punho_operacoes_campos_do_colaborador()
  from public, anon, authenticated;

drop trigger if exists punho_operacoes_campos_do_colaborador
  on public.punho_operacoes;

create trigger punho_operacoes_campos_do_colaborador
  before insert on public.punho_operacoes
  for each row execute function public.punho_operacoes_campos_do_colaborador();
