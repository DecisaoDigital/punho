-- CRM: a categoria do que a pessoa quer (depilação a laser, remoção de
-- tatuagens, emagrecimento). Texto livre na base; quem o valida é a função
-- `receber-lead`, contra a lista da empresa. Coluna nova, anulável.
alter table public.punho_leads_entrada
  add column if not exists categoria text;
