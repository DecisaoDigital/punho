-- CRM: a ficha que o funil e o Carlitos entregam à caixa de entrada.
--
-- Só colunas novas, todas anuláveis: apps e funções antigas continuam a escrever
-- e a ler sem dar por nada (cuidado com o 42501 das apps antigas — aqui não há
-- policy nova).
--
-- `via` diz quem captou: o formulário do site ou o assistente. A lead quente do
-- Fist é a mesma nos dois casos; o que muda é só a etiqueta que a administrativa
-- vê. Nenhuma destas colunas valida nada: quem valida é sempre uma pessoa.

alter table public.punho_leads_entrada
  add column if not exists negocio text,
  add column if not exists codigo_postal text,
  add column if not exists localidade text,
  add column if not exists morada text,
  -- O que a pessoa quer (texto livre curto, sem dados de saúde).
  add column if not exists interesse text,
  -- O dia e a hora que a pessoa pediu, já validados contra o horário da empresa.
  add column if not exists horario_pedido timestamptz,
  add column if not exists via text;

alter table public.punho_leads_entrada
  drop constraint if exists punho_leads_via_conhecida;
alter table public.punho_leads_entrada
  add constraint punho_leads_via_conhecida
  check (via is null or via in ('funil', 'bot', 'manual'));
