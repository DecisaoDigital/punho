-- Achado 3.4 — `punho_leads_entrada` guardava dados de terceiros sem registo
-- da base legal que autoriza guardá-los.
--
-- O expurgo aos 6 meses já lá estava. O que faltava era o outro lado do artigo
-- 7.º/1: «o responsável deve poder demonstrar que o titular deu o seu
-- consentimento». Demonstrar quer dizer ter o texto que a pessoa aceitou e o
-- momento em que o aceitou — não uma caixinha marcada num formulário que já
-- ninguém consegue reconstituir.
--
-- Nem todas as leads vivem de consentimento, e fingir que sim seria pior do que
-- não registar nada. Quem telefona a pedir orçamento não está a consentir em
-- marketing: está a dar início a uma diligência pré-contratual a seu pedido
-- (art. 6.º/1/b), que é uma base legal por direito próprio e não precisa de
-- consentimento nenhum. São coisas diferentes e a tabela passa a saber
-- distingui-las.
--
-- O terceiro valor — `nao_registada` — é o que torna isto honesto. Uma lead que
-- chegue de um formulário público sem prova de consentimento **não é
-- reclassificada para parecer legal**: fica marcada como não registada, e é
-- essa marca que a impede de entrar sozinha no pipeline.
--
-- A tabela está vazia em produção (verificado antes de escrever isto), portanto
-- o `default` não está a mentir sobre linhas antigas: não há linhas antigas.

alter table public.punho_leads_entrada
  add column base_legal text not null default 'nao_registada',
  add column consentimento_texto text,
  add column consentimento_versao text,
  add column consentimento_em timestamptz,
  add column consentimento_url text;

alter table public.punho_leads_entrada
  add constraint punho_leads_base_legal_conhecida
    check (base_legal in (
      'consentimento',              -- formulário público, com prova
      'diligencia_pre_contratual',  -- a pessoa contactou o negócio
      'nao_registada'               -- não sabemos, e diz-se
    ));

-- Ou há prova a sério, ou não se chama consentimento. E ao contrário: nenhuma
-- linha pode carregar meia prova sem se declarar — meia prova em silêncio é o
-- que faz uma auditoria futura acreditar que existe consentimento onde não há.
alter table public.punho_leads_entrada
  add constraint punho_leads_consentimento_com_prova
    check (
      case base_legal
        when 'consentimento' then
          consentimento_texto is not null and consentimento_em is not null
        else
          consentimento_texto is null and consentimento_versao is null
          and consentimento_em is null and consentimento_url is null
      end
    );

comment on column public.punho_leads_entrada.base_legal is
  'O que autoriza guardar estes dados. Escrito pelo servidor na recepção; '
  'o cliente não tem UPDATE nesta coluna de propósito.';
comment on column public.punho_leads_entrada.consentimento_em is
  'Quando o consentimento **nos chegou**, carimbado pelo servidor. Não é o '
  'instante que o formulário diz ter acontecido: esse é do lado de lá e '
  'forjável, e a diferença entre os dois são segundos.';

-- As permissões desta tabela são por coluna (Fase 2 do endurecimento), e
-- colunas novas não herdam nada. Sem isto, o `select *` da app passava a
-- responder 42501 e a caixa de entrada deixava de abrir.
--
-- Ler sim, escrever não: quem decide a base legal é o servidor, no momento em
-- que recebe. Se a app pudesse escrevê-la, a prova valia o mesmo que a
-- afirmação de quem submeteu o formulário — ou seja, nada.
grant select (base_legal, consentimento_texto, consentimento_versao,
              consentimento_em, consentimento_url)
  on public.punho_leads_entrada to authenticated;

grant select (base_legal, consentimento_texto, consentimento_versao,
              consentimento_em, consentimento_url),
      insert (base_legal, consentimento_texto, consentimento_versao,
              consentimento_em, consentimento_url),
      update (base_legal, consentimento_texto, consentimento_versao,
              consentimento_em, consentimento_url)
  on public.punho_leads_entrada to service_role;
