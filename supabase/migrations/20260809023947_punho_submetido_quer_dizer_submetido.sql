-- «Submetido» tem de querer dizer que está feito e que não mudou desde então.
--
-- ## O que se fez, com o token de um contabilista a sério
--
--   02:38:01  POST accao=submeter        → {"ok":true}   … com 0 respostas
--   02:38:25  POST accao=guardar ×6      → aceitas todas
--
-- Ou seja: o portal deixou submeter um formulário **vazio**, e deixou mudar os
-- números **depois** de o declarar submetido. O gestor abre a app, lê
-- «submetido», e o que lá está pode ser outra coisa — ou coisa nenhuma.
--
-- ## Duas regras, e nenhuma tira capacidade a ninguém
--
-- 1. Submeter nada não é submeter. Recusa-se, com uma frase que diz o que
--    falta.
--
-- 2. Uma resposta nova **desfaz** a submissão. Não se bloqueia a correcção — um
--    contabilista que se enganou tem de poder corrigir, e obrigá-lo a pedir ao
--    gestor que reabra era transformar uma gralha num telefonema. O que muda é
--    que `submetido_em` volta a nulo e ele carrega em «submeter» outra vez.
--    Assim a palavra passa a ser verdade: submetido = está tudo e nada mexeu.
--
-- ## Porque é que isto vai na base e não na Edge Function
--
-- Porque a função escreve com `service_role` e passa por cima de tudo o que
-- seja política. Uma regra que vive na função protege só o caminho que a função
-- usa hoje. E, mais prosaicamente: há funções cujo ficheiro no repositório está
-- atrasado em relação ao que está em produção, e um deploy a partir do
-- ficheiro reverte produção sem dizer nada. A regra fica onde a escrita
-- aterra.

-- ---------------------------------------------------------------------------
-- Submeter nada não é submeter
-- ---------------------------------------------------------------------------
create or replace function public.punho_contabilista_so_submete_com_respostas()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.submetido_em is null or old.submetido_em is not null then
    return new;  -- não é uma submissão nova
  end if;

  if not exists (
    select 1 from public.punho_respostas_contabilista r
     where r.convite_id = new.id
  ) then
    raise exception
      'Não há nada preenchido para submeter. Escreva ao menos um valor primeiro.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$fn$;

revoke all on function public.punho_contabilista_so_submete_com_respostas()
  from public, anon, authenticated;

drop trigger if exists punho_contabilista_submissao_com_conteudo
  on public.punho_convites_contabilista;
create trigger punho_contabilista_submissao_com_conteudo
  before update of submetido_em on public.punho_convites_contabilista
  for each row execute function public.punho_contabilista_so_submete_com_respostas();

-- ---------------------------------------------------------------------------
-- Mexer nos números reabre o formulário
-- ---------------------------------------------------------------------------
create or replace function public.punho_contabilista_resposta_reabre()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.convite_id is null then
    return new;  -- resposta do gestor, não do contabilista
  end if;

  update public.punho_convites_contabilista
     set submetido_em = null
   where id = new.convite_id
     and submetido_em is not null;

  return new;
end;
$fn$;

revoke all on function public.punho_contabilista_resposta_reabre()
  from public, anon, authenticated;

drop trigger if exists punho_contabilista_resposta_reabre
  on public.punho_respostas_contabilista;
create trigger punho_contabilista_resposta_reabre
  after insert or update on public.punho_respostas_contabilista
  for each row execute function public.punho_contabilista_resposta_reabre();
