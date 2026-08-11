-- Achado 2.3 da auditoria de 11/8: colunas `*_id` sem chave estrangeira. Aqui
-- fecham-se as quatro que podem ser fechadas.
--
-- `punho_alteracoes_contabilista` é o registo de quem mexeu no que, no portal
-- do contabilista. Aponta para a empresa, para o convite e para a resposta que
-- foi alterada — e nenhuma dessas setas tinha rede. Hoje há 19 linhas e zero
-- órfãs; a rede é para as que vierem.
--
-- Os apagamentos escolhem-se um a um, e não por hábito:
--
--   empresa_id  → cascade. A linha é da empresa. Sem a empresa, não é história
--                 de nada; é lixo com data.
--   convite_id  → set null. O convite expira e é apagado, a alteração
--                 aconteceu na mesma. Perder o rasto todo porque o convite
--                 caducou é a mesma lição do `licencas_audit`.
--   resposta_id → set null. Pelo mesmo motivo, e este é o mais claro de todos:
--                 é precisamente quando a resposta desaparece que o registo de
--                 a ter havido passa a valer alguma coisa.
--
-- ## O que fica de fora, e não é esquecimento
--
-- A auditoria falava também de `punho_conflitos_pendentes.entidade_a_id`,
-- `.entidade_b_id` e `.fica_com_entidade_id`. Não levam chave estrangeira
-- nenhuma: são `text`, e guardam ids locais do terminal — o mesmo id que o
-- `punho_id_estavel()` traduz para uuid. Não apontam para uma linha de uma
-- tabela, apontam para uma entidade que vive no log. Aquele achado estava
-- errado e fica corrigido aqui.

alter table public.punho_alteracoes_contabilista
  drop constraint if exists punho_alteracoes_contabilista_empresa_id_fkey,
  add  constraint punho_alteracoes_contabilista_empresa_id_fkey
       foreign key (empresa_id) references public.punho_empresas (id)
       on delete cascade;

alter table public.punho_alteracoes_contabilista
  drop constraint if exists punho_alteracoes_contabilista_convite_id_fkey,
  add  constraint punho_alteracoes_contabilista_convite_id_fkey
       foreign key (convite_id) references public.punho_convites_contabilista (id)
       on delete set null;

alter table public.punho_alteracoes_contabilista
  drop constraint if exists punho_alteracoes_contabilista_resposta_id_fkey,
  add  constraint punho_alteracoes_contabilista_resposta_id_fkey
       foreign key (resposta_id) references public.punho_respostas_contabilista (id)
       on delete set null;

alter table public.punho_conflitos_pendentes
  drop constraint if exists punho_conflitos_pendentes_empresa_id_fkey,
  add  constraint punho_conflitos_pendentes_empresa_id_fkey
       foreign key (empresa_id) references public.punho_empresas (id)
       on delete cascade;

-- Uma chave estrangeira sem índice do lado que aponta faz o apagamento da
-- empresa ler a tabela inteira. São poucas linhas hoje; o índice é barato.
create index if not exists punho_alteracoes_contabilista_empresa_idx
  on public.punho_alteracoes_contabilista (empresa_id, alterado_em desc);
create index if not exists punho_alteracoes_contabilista_convite_idx
  on public.punho_alteracoes_contabilista (convite_id);
create index if not exists punho_alteracoes_contabilista_resposta_idx
  on public.punho_alteracoes_contabilista (resposta_id);
create index if not exists punho_conflitos_pendentes_empresa_idx
  on public.punho_conflitos_pendentes (empresa_id, criado_em desc);
