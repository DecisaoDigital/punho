-- Sequela imediata da migração anterior, e a parte que a torna verdadeira.
--
-- Registar o consentimento numa coluna não vale nada se quem lê a tabela puder
-- escrever essa coluna. E podia: o `authenticated` tinha `arwdDxtm` — a tabela
-- inteira, incluindo DELETE e TRUNCATE — e a política de UPDATE não diz que
-- colunas cobre, portanto cobre todas. Um gestor com a app na mão podia carimbar
-- «consentimento» numa lead que nunca consentiu, e a prova ficava indistinguível
-- de uma verdadeira. Isso é pior do que não ter coluna nenhuma: um registo falso
-- passa numa auditoria que um registo em falta não passaria.
--
-- (Já não era possível **inserir** nem **apagar**, porque a tabela só tem
-- políticas de SELECT e UPDATE e o RLS nega por omissão o que não tem política.
-- Mas a permissão estava lá à mesma. Duas fechaduras: se um dia alguém
-- acrescentar uma política de DELETE a pensar noutra coisa, esta continua a
-- valer.)
--
-- Fica exactamente o que a app faz, e nada mais. `LeadsEntradaService` lê a
-- caixa de entrada e escreve dois campos ao marcar como processada — o carimbo e
-- a ligação à lead local. É esse o contrato.

revoke all on table public.punho_leads_entrada from authenticated;

grant select on table public.punho_leads_entrada to authenticated;
grant update (processada_em, lead_local_id)
  on table public.punho_leads_entrada to authenticated;

comment on table public.punho_leads_entrada is
  'Caixa de entrada de leads externas. A app lê tudo e só escreve '
  '`processada_em` e `lead_local_id`; quem preenche o resto é a Edge Function '
  '`receber-lead`, com a chave de serviço. A base legal e a prova de '
  'consentimento não são reescrevíveis pelo cliente de propósito.';
