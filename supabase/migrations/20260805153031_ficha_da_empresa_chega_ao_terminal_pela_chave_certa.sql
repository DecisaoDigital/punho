-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260805153031). Estava em
-- produção sem ficheiro no repo. O número no nome é a ordem em que
-- correu nesse dia — por ordem alfabética ficaria trocada com a que
-- lhe acrescenta a coluna que usa.

-- A ficha da empresa passa a chegar às licenças dos **terminais dela**.
--
-- Estava a ligar pelo NIF:
--
--   update licencas set nome = ... where app='punho' and nif = v_nif;
--
-- e nunca casava com nada. O terminal regista-se pelo `registar-terminal` com
-- o NIF de marcador `000000000`, e ninguém lhe escrevia o verdadeiro — logo a
-- condição `nif = <nif real>` dava sempre zero linhas. O nome nunca chegava à
-- licença, a cascata de `ContextoInstalacoes.nomeDe` caía para o modelo do
-- aparelho, e o Control mostrava `M2101K6G` para sempre, muito depois de já
-- haver nome verdadeiro.
--
-- Passa a ligar por `(machine_id, app)` — a identidade canónica de um terminal,
-- a mesma chave do WashInvoice. Os terminais de uma empresa são os dos pedidos
-- **aprovados** dela: é a adesão que prova a que empresa pertence um aparelho,
-- e é do servidor, não do que o cliente diga.
--
-- Escreve também o NIF verdadeiro por cima do marcador. Sem isso o terminal
-- ficava para sempre com `000000000`, que é o valor que `nomeDe` já trata como
-- "não identifica ninguém".
--
-- O POS não é tocado: o filtro `app = 'punho'` mantém-se.
create or replace function public.punho_sync_licenca_from_empresa()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_nif            text := NEW.dados->>'nif';
  v_nome_comercial text := NEW.dados->>'nome_comercial';
begin
  if v_nif is null or length(v_nif) < 9 then
    return NEW;
  end if;

  update public.licencas l
     set nome           = coalesce(v_nome_comercial, NEW.nome),
         nome_comercial = v_nome_comercial,
         -- Só por cima do marcador: um NIF já verdadeiro não se mexe daqui.
         nif            = case when coalesce(btrim(l.nif), '') in ('', '000000000')
                               then v_nif else l.nif end
   where l.app = 'punho'
     and l.machine_id in (
       select p.machine_id
         from public.punho_pedidos_acesso p
         join public.punho_membros m
           on m.user_id = p.user_id and m.ativo
        where m.empresa_id = NEW.id
          and p.estado = 'aprovado'
          and p.machine_id is not null
     );

  return NEW;
end;
$function$;
