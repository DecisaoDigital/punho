-- ===========================================================================
-- Fechar as duas pontas soltas da semente de KPIs
-- ===========================================================================
--
-- Corrido contra produção a 13 de Agosto de 2026, a pedido dele: «sim, fecha as
-- pontas da semente». O `semear_historico_kpis.sql` deixou dois buracos que só
-- se viram quando os KPIs novos os foram ler:
--
--   1. **12% das reservas nunca eram pagas.** A semente lança o recebimento em
--      88% dos casos, e o resto ficava por cobrar *para sempre* — 123 reservas,
--      13 019 €, a mais velha com 769 dias. Uma casa a funcionar não deixa dois
--      anos de dívida viva: ou recebe, ou dá por perdido. O «Em atraso» nascia
--      vermelho com um número que não era do negócio, era do gerador.
--
--   2. **Todas as despesas nasciam `paid` no próprio dia.** Logo o DPO era zero,
--      o ciclo de tesouraria ficava meio, e o «Contas a pagar» dizia sempre
--      «Nada por pagar» — um KPI verdadeiro a mostrar um mundo que não existe.
--
-- **Não apaga nada.** Só acrescenta operações ao log, que é de onde a app lê;
-- o gatilho `punho_operacoes_projectar` trata das tabelas projectadas. Tudo o
-- que entra fica marcado com `por_dispositivo = 'semente-fecho'`, e por isso é
-- identificável e reversível sem tocar no que a semente escreveu.
--
--   select * from punho_operacoes where por_dispositivo = 'semente-fecho';
--
-- ---------------------------------------------------------------------------
-- Ponta 1: cobrar o que já ninguém ia cobrar
-- ---------------------------------------------------------------------------
--
-- Corte nos **45 dias**. A semente paga com 3 a 38 dias de atraso; acima de 45
-- já não é atraso, é dívida esquecida — e essa fecha-se. O que fica por receber
-- é o dos últimos 45 dias, que é a fotografia de uma casa a funcionar.
--
-- A data do recibo é o fim do trabalho **mais 21 dias**, que é o atraso mediano
-- desta casa medido nos recibos que já existiam (mediana 21, média 21, máximo
-- 38). Não é um número escolhido: é o costume dela.

with emp as (select id from punho_empresas where nome ilike '%depil%' limit 1),
rec as (select (dados->>'bookingId') b, sum((dados->>'amountCents')::int) pago
        from punho_recebimentos where empresa_id = (select id from emp) group by 1),
divida as (
  select r.id_local res, c.id_local cli, r.fim::date fim,
         coalesce(r.valor_previsto_centimos, 0) - coalesce(rec.pago, 0) falta
  from punho_reservas r
  left join rec on rec.b = r.id_local
  left join punho_clientes c on c.id = r.cliente_id
  where r.empresa_id = (select id from emp) and r.estado <> 'cancelled'
    and coalesce(r.valor_previsto_centimos, 0) > coalesce(rec.pago, 0)
    and r.fim::date < current_date - 45)
insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
select gen_random_uuid(), (select id from emp), 'receipt', 'k-rec-fecho-' || res,
  jsonb_build_object(
    'id', 'k-rec-fecho-' || res,
    'date', to_char(fim + 21, 'YYYY-MM-DD') || 'T12:00:00.000',
    'amountCents', falta,
    'customerId', coalesce(cli, 'k-cli-1'),
    'bookingId', res,
    'method', 'transfer',
    'note', '', 'recordedByCollaboratorId', null, 'archived', false),
  (fim + 21)::timestamptz, 'semente-fecho'
from divida;

-- O `punho_operacoes_carimbar` é um BEFORE INSERT e atira o `feito_em` para
-- `now()`. Devolve-se cada recibo ao dia em que aconteceu — é o UPDATE que o
-- carimbo não intercepta, a mesma manobra da semente.
update punho_operacoes
   set feito_em = (payload->>'date')::timestamptz
 where por_dispositivo = 'semente-fecho' and entidade = 'receipt';

-- ---------------------------------------------------------------------------
-- Ponta 2: dar contas por pagar a uma casa que pagava tudo à cabeça
-- ---------------------------------------------------------------------------
--
-- Quatro facturas de fornecedor por liquidar: limpeza, consumíveis e
-- publicidade do mês corrente, mais a revisão da máquina do mês passado. A
-- renda, os salários, a luz e a água ficam pagas — são débitos e ordenados, e
-- é isso que uma casa destas paga a horas.
--
-- **`feito_em` fica em `now()`, e é de propósito.** Ao contrário dos recibos,
-- isto não é uma coisa que aconteceu no passado: é uma correcção lançada hoje.
-- A `date` da despesa, que é o que os KPIs lêem, continua a original.

with emp as (select id from punho_empresas where nome ilike '%depil%' limit 1)
insert into punho_operacoes (id, empresa_id, entidade, entidade_id, payload, feito_em, por_dispositivo)
select gen_random_uuid(), d.empresa_id, 'expense', d.id_local,
       jsonb_set(d.dados, '{status}', '"unpaid"'), now(), 'semente-fecho'
from punho_despesas d
where d.empresa_id = (select id from emp)
  and d.id_local in ('k-desp-0-4', 'k-desp-0-6', 'k-desp-0-7', 'k-desp-man-1');

-- ---------------------------------------------------------------------------
-- O que ficou (conferido a 13/8/2026, depois de correr)
-- ---------------------------------------------------------------------------
--
--   Em atraso ......... 1 085 € · 8 clientes · a mais velha há 39 dias
--                       (para lá dos 21 dias do costume; 3 165 € é o total por
--                        receber, mas 2 080 € desses ainda estão a horas)
--   Contas a pagar .... 549 € · 4 despesas · a mais velha há 25 dias
--
-- E foi este exercício que mostrou o defeito do próprio KPI: com a fronteira no
-- dia seguinte ao fim do trabalho, o «Em atraso» acusava os 21 dias normais e
-- ficava sempre aceso. A régua passou a ser o costume da casa — ver
-- `lib/core/kpis/dinheiro_por_mexer.dart`.
