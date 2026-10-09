# Decisões do César sobre o CRM do Punho (9/10/2026)
Origem: council `council-2026-10-09-crm-no-punho.md` + conversa. Planeamento: `PLANO_FATIAS_1_E_2.md`. Nada foi implementado.

## Visão
O que se faz agora é PREPARAÇÃO de um CRM maior: funil do site, apoio ao cliente e bot de WhatsApp que qualifica e fecha. Fatias pequenas agora; 2.º council sobre a camada de canais quando chegar a hora (bot a fechar choca com o princípio 10; RGPD das conversas; API da Meta; projecto `~/agente-whatsapp`).

## Modelo de trabalho
- Lead nova trazida pelo próprio operador: ele regista os dados completos e fica dele.
- Lead nova de fora (site, bot): chega SEM DONO; o gestor ou a «menina do escritório» (app do gestor limitada, futura) atribui o operador pela logística da rota. Caixa «por atribuir» + tarefa «leads por atribuir».
- Cliente antigo (qualquer canal) NÃO é lead: é uma reserva com data de entrega e recolha; responsável = operador responsável do cliente (campo novo na ficha); aparece no calendário de entregas desse operador.
- Percurso da lead: nova → contactada → QUALIFICADA (estado novo) → contacto extra (reunião com alarme) → fecho → convertida / perdida (com motivo). Origem nova: «prospecção própria».
- FECHO = o operador cria a reserva (entrega no calendário), que NASCE CONFIRMADA e converte a lead. Conversão não se marca à mão nem ao criar a ficha do cliente.
- Máquina: quem regista indica a CATEGORIA; o sistema escolhe uma máquina livre da categoria (rec.: «a primeira livre»; César disse «aleatória»); regra partilhada no servidor (o bot usa-a).
- Preço: fixo, o da tabela da máquina; só o gestor o altera, para descontos. Começa como regra da app; garantia no servidor (recusar preço ≠ tabela a operadores) fica para depois, com migration.

## Visibilidade
Operador: todos os clientes, máquinas disponíveis, e só as leads atribuídas a si (abertas e fechadas). Gestor: tudo. Administrativa: o que o gestor permitir. Hoje o servidor deixa o colaborador ler todas as leads: NÃO está aplicado; precisa de «atribuído a» e política de leitura no log e em punho_leads (migration, ok do César, ramo primeiro). Aviso de entrada: «já é cliente: nome» sim; «já tratada por X» não.

## Lembretes
Reunião = reserva do tipo «reunião» (cliente, dia/hora, sem máquina). Alarme local com antecedência escolhida; toca só em quem marcou, em todos os aparelhos dessa conta depois de sincronizarem. Operadores não têm Tarefas: precisam de lista «Para contactar hoje» + alarme. Risco: MIUI mata alarmes → protótipo de 1 h no Redmi antes de construir.

## Por decidir (ver o ok do César)
1. Texto da emenda ao «Não é CRM»: «Não é um CRM: não tem campanhas, funis nem segmentos. Regista o último contacto e a próxima acção de cada lead e cliente, porque é isso que evita perder vendas.»
2. Migration do expurgo de leads (respeitar conversão); só depois de testada num ramo e com ok no momento.
3. Prazo do aviso «lead sem operador».
4. Operador lê o valor de compra das máquinas: restringir?
5. Gestor em tablet Android ou PC Windows (sem alarme no Windows)?
