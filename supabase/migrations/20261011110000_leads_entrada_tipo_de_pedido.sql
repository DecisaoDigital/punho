-- CRM: o que a pessoa quer. Serviço, aluguer de máquinas ou venda de máquinas
-- têm tratamentos diferentes (horário com almoço, horário de entrega sem almoço,
-- e sem horário), e os dias de aluguer pedidos. Colunas novas anuláveis.
alter table public.punho_leads_entrada
  add column if not exists tipo text,
  add column if not exists periodo_dias integer;

alter table public.punho_leads_entrada
  drop constraint if exists punho_leads_tipo_conhecido,
  drop constraint if exists punho_leads_periodo_positivo;
alter table public.punho_leads_entrada
  add constraint punho_leads_tipo_conhecido
    check (tipo is null or tipo in ('servico', 'aluguer', 'venda')),
  add constraint punho_leads_periodo_positivo
    check (periodo_dias is null or periodo_dias between 1 and 3650);
