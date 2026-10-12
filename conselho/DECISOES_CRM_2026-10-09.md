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

## Leads quentes (César, 11/10/2026)
Sítio próprio para **leads quentes** = pessoas que nunca foram clientes e querem saber mais. Ficam SEMPRE para o humano (gerente ou administrativa), que as **qualifica e valida**. Cliente existente (E.164 já conhecido) não é lead quente: pode ser tratado pela IA/bot de WhatsApp, por outra via ou à mão (reserva directa). Bot só capta e pré-qualifica; nunca valida nem fecha.
Morada da lead quente (César, 11/10/2026): obrigatória a **zona** (código postal/localidade) e preferencialmente a **morada**; serve ao humano para decidir se chama a pessoa ao escritório para formação ou se vai lá dar a formação, conforme a distância às instalações. Vale para o funil e para o Carlitos.
Lead quente — dados de contacto redundantes (César, 11/10/2026): além do nome da pessoa responsável, o **nome do negócio**; quanto mais dados básicos, melhor a lead (permite reencontrar a empresa se um telefone vier trocado ou mal percebido).
Posição do César sobre o CRM (11/10/2026): adaptar o que existe; melhorar a interface (UI/UX) para gerente, administrativa e operadores lerem e agirem com facilidade; mesma ordem (próxima ação+data, último contacto a um toque, motivo de perda, ficha só de leitura, entrada pelo site, bot no fim); acredita que o bot, bem afinado e educado, pode fechar melhor que um humano — a entrar pelo mesmo sítio como lead quente, com a via marcada (funil ou bot).
Quem valida a lead quente (César, 11/10/2026): a **administrativa** valida e faz a marcação (e fala com o cliente se faltar algo, ou confirma a marcação). O **gerente** supervisiona e pode intervir; se a administrativa faltar, é ele que valida. Qualquer um dos dois, basta um. **Nunca o operador.** Bot: aceites as 3 fases (capta → propõe → fecha em casos de baixo risco, só com números). Desenho HTML do CRM antes de construir: aceite. Nº de leads/mês varia por empresa e pela qualidade da publicidade: não é condição para avançar.

## 11/10/2026 — Endpoint comum de entrada (funil + Carlitos)
- Não é função nova: estendeu-se `receber-lead` (publicada) e a caixa `punho_leads_entrada`. Colunas novas anuláveis: negocio, codigo_postal, localidade, morada, interesse, horario_pedido, via (funil|bot|manual). Migration 20261011100000.
- Mesmo número com a primeira ainda por processar → ATUALIZA (só preenche buracos; interesse/horário pedido mais recente vale). Já processada → retida, como antes.
- horario_pedido validado no servidor (horario.ts): Depilconcept 9–13 e 15–18, fuso Europe/Lisbon; hora de início; fora de horas/passado → lead entra sem horário e a resposta diz `horario:{ok:false,motivo}` para o Carlitos voltar a perguntar. Horário vive numa tabela no código até a empresa o poder definir na app.
- Dia da semana NÃO validado (por decidir). Lead «morna» entra (com contacto consentido); sem contacto, nada.
- Interesse/horário pedido ficam em texto no resumo da lead (sem campo próprio) até a marcação.
- Provado em produção com 2 POST reais (criar + completar); linha de teste apagada.

## 11/10/2026 — Três tipos de pedido (César)
- `tipo`: servico (depilação) | aluguer (máquinas) | venda (máquinas). Todos caem em «Leads quentes», vistos por administrativa e gerente.
- Serviço: horário 9–13 e 15–18 (almoço). Aluguer: horário de ENTREGA 9–18 sem almoço (entrega-se de manhã; recolha no mesmo dia, não pedida). Venda: sem horário, é do gerente.
- Aluguer: guarda-se `periodo_dias`. Se não está na tabela de preços das máquinas (ex. 15 dias) → «fora da tabela», sem horário/escala de entrega, «ver com o gerente» (a app decide, a tabela vive nas máquinas). Quem trata: gerente ou administrativa, mais o gerente; permissões iguais, decidir mais tarde.
- Migration 20261011110000; receber-lead v+1; Lead.tipo/periodoDias/horarioPedido na app.

## 11/10/2026 — O modelo serve qualquer empresa (César)
- O contexto da empresa manda: nome da empresa, nome do assistente (Carlitos é só o nosso nome), tipos que oferece, categorias, horários. Tudo na tabela `punho_atendimento_config` (migrations 20261011130000), nada no código. Empresa nova = uma linha + baliza + env. GET `receber-lead?empresa_id=` devolve o contexto público (sem horários).
- Categoria parecida mas não igual (ex. «máquina de tatuagens» vs «Remoção de tatuagens») → o assistente pergunta «Quer dizer ...?»; resposta com «não» e mais palavras não se decide, repete.
- Push de lead nova: avisa os gestores; falta o perfil «administrativa».
