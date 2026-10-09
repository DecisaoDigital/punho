# Council — CRM dentro do Punho (9/10/2026)

Modo padrão: 5 conselheiros isolados + 5 revisões cruzadas anónimas. Só planeamento; nada foi alterado no código.

## Pergunta e enquadramento
DECISÃO: como deve ser feito o CRM dentro do Punho (app Flutter, pubspec «fist»), uma app de gestão operacional para pequenas empresas (1ª vertical: aluguer de máquinas, poucos funcionários).

CONTEXTO: o OBJECTIVO do produto diz literalmente «Não é ERP. Não é contabilidade. Não é CRM» e exclui «suites de marketing», mas o roadmap prevê «conversa com o cliente registada», orçamento com linhas/validade/motivo de perda, e «euros por canal». Hoje existem clientes (ficha plana), leads (nome+telefone, estados que a UI quase não usa), reservas com estado «proposta enviada», KPIs de pipeline e leads a arrefecer, entrada de leads de fora por edge function com base legal RGPD. Faltam: registo de interacções com data e autor, próxima acção com data e lembrete, ficha de cliente de leitura, origem e motivo de perda, importação, edição de lead. Arquitectura local-first com log append-only (punho_operacoes), projecção para tabelas de leitura, permissões do colaborador por campo no servidor, RGPD (apagamento por redacção, sem exportação, sem base legal nos clientes). 17 princípios (poucos toques; registar por quem viu; falta de dados = null; sem placeholders; o Fist recomenda e o gestor decide; funcionalidade só entra se facilitar a acção diária ou antecipar problema; identidade vem do servidor; histórico obrigatório). Gestor em landscape; colaborador em telemóvel com acções rápidas; o dono é leigo em gestão; os clientes dele vivem hoje no WhatsApp, num caderno e na cabeça.
Bugs/incoerências já achados: formulário de lead fecha sem gravar com campo vazio; conversão marca «convertida» ao criar o cliente (o doc diz 1ª reserva confirmada); expurgo de leads ignora conversão; a landing page pode não alimentar o CRM.

A DECIDIR: (1) âmbito mínimo útil do CRM e o que fica de fora; (2) modelo de dados (interacções, próxima acção, ficha de cliente, estados de lead, origem, motivo de perda) respeitando local-first/log/RGPD e os princípios; (3) UX para o gestor em landscape e o colaborador em telemóvel com poucos toques; (4) ordem de construção em fatias pequenas, começando pelos bugs; (5) riscos (RGPD, conflitos offline, duplicados, notas com dados sensíveis, âmbito a crescer).

NÃO INFORMADO: quantos clientes/leads tem o empresário-piloto; se o funil do site chama receber-lead; RLS directa de punho_clientes/punho_leads; se o piloto quer ligar WhatsApp; orçamento disponível para tempo de desenvolvimento.

## Respostas (anónimas) — mapeamento: A expansionista · B forasteiro · C primeiros-princípios · D contrariante · E executor

## Resposta A
Upside subestimado: o CRM é a peça que fecha a espinha Lead→Customer→Booking→Receipt que o OBJECTIVO já define, hoje partida no 1º elo. O log append-only (punho_operacoes) com autor e data já é um histórico de interacções grátis (princípio 9): uma «interacção» é só mais um tipo de operação. Liberta a lacuna do OBJECTIVO:506 («a família Clientes inteira fica indisponível») e alimenta KPIs hoje «não calculáveis» (CAC, custo por lead, euros por canal, custo de servir). Quem tirar os clientes ao dono da cabeça/caderno fica com ele.
Opções adjacentes: (1) importação (colar lista / contactos do telemóvel): porta de entrada, sem clientes dentro o CRM não arranca; (2) botão tel:/wa.me com mensagem pré-escrita (PLANO_DO_CICLO:72-74) que grava a interacção no mesmo toque, só url_launcher; (3) tarefa «contactar lead» e «lead sem toque há N dias» na função pura de Tarefas.
Desbloqueia: motivo de perda + origem dão «euros por canal»; ficha de cliente com dívida e reservas dá a 1ª família de KPIs por cliente; o colaborador torna-se motor de registo no terreno; 2ª vertical herda o módulo.
Para não fechar portas: origem obrigatória na lead já; modelar a interacção como operação do log com autor do servidor; acrescentar a nova entidade a punho_apagar_titular logo de início; corrigir primeiro os bugs.
Posição: construir o CRM mínimo como ficha do cliente com interacções e próxima acção sobre o log existente, começando pelos bugs e pela importação. Confiança: média (não informado: tamanho da base do piloto, se quer WhatsApp).

## Resposta B
O que percebi: uma app para donos de pequenas empresas de aluguer de máquinas vai ter um «CRM» que diz não ser CRM.
O que não percebi: se «não é CRM» e vai ter fichas, leads, histórico, lembretes e importação, o que é? «Subproduto do trabalho diário»: que trabalho gera o registo sozinho? «Proposta enviada»: quem a envia e por onde? Se for WhatsApp a app nem a vê. «Registar chamadas e mensagens»: à mão? Se for à mão ninguém o fará. Que dados são pessoais e quem decide apagá-los.
Onde desistiria: no «registar chamadas e mensagens com data e autor». O cliente vive no WhatsApp e no caderno; o dono leigo não vai copiar conversas para a app. Desistia no primeiro dia em que o caderno fosse mais rápido.
3 perguntas ingénuas: se já falo com o cliente no WhatsApp porque hei-de escrever tudo outra vez? Quem me avisa que devo ligar amanhã, e como, se o telemóvel estiver sem rede? O que acontece aos dados se um cliente me pedir para os apagar?
Posição: confuso. Promete poucos toques mas lista tudo o que um CRM tem; ninguém decidiu o mínimo. Cortava até ficar só «próxima acção com lembrete» e «último contacto» na ficha. Confiança: média.

## Resposta C
Problema reformulado: o dono leigo perde vendas e dinheiro porque ninguém sabe a quem falou, quando, e quem contactar a seguir; não perde por falta de «CRM».
Factos: OBJECTIVO:23 «Não é CRM»; roadmap pede «conversa com o cliente registada» e «euros por canal»; clientes vivem no WhatsApp/caderno/cabeça; estados contacted/proposal/lost e origem existem no modelo mas a UI nunca os escreve; não há tel:/wa.me para clientes, nem próxima acção, nem lembrete; a reserva já tem «proposta enviada» e Tarefas já calcula cobranças ≥15 dias.
Suposições por verificar: o funil chama receber-lead (provavelmente não); o piloto tem poucas dezenas de contactos; o piloto quer WhatsApp (não informado).
Hábitos (convenção, não necessidade): entidade «Interacção» com tipos, ficha completa, segmentos, importação CSV, kanban.
Objectivo real: que nenhum pedido de orçamento ou cobrança se perca por esquecimento, e que o gestor veja de onde vem o dinheiro.
Solução reconstruída: 1) não construir módulo CRM; corrigir os bugs e dar à lead e à reserva um único campo «próxima acção + data»; 2) esse campo alimenta a função pura de Tarefas (sem tabelas novas), mais «último contacto» e origem obrigatória (um toque) na lead; 3) botão ligar/WhatsApp em lead e cliente que grava «contactei» (1 toque) no log, interacção mínima que substitui o texto livre; 4) motivo de perda só no estado «perdida» (3 opções); ficha de cliente de leitura derivada das reservas; 5) fora: segmentos, etiquetas, campanhas, kanban, importação, notas longas (dado sensível).
A pergunta certa é «que esquecimento custa mais dinheiro a este dono?»: o follow-up de orçamento, que se resolve com data e tarefa, não com um módulo.
Posição: não construir um CRM; acrescentar «próxima acção com data» e «último contacto» ao ciclo Lead→Reserva já existente, ligados a Tarefas, depois de corrigir os bugs. Confiança: média-alta.

## Resposta D
Falha fatal: o CRM só vale se alguém o preencher; o Punho vive de «registar por quem viu» com poucos toques. Os clientes do piloto estão no WhatsApp/caderno/cabeça e a app não tem importação nem wa.me/tel:. Se o registo de interacções for manual e fora do WhatsApp, o dono escreve três notas na 1ª semana e volta ao WhatsApp. Fica uma base com buracos que os KPIs tratam como verdade («leads a arrefecer» a mentir), contra os princípios 4 e 12. Torna-se um segundo caderno, pior.
Outras falhas: âmbito (cada fatia «pequena» puxa a seguinte; sem teste de entrada pelo princípio 14 o âmbito triplica); RGPD (notas e interacções livres terão dados sensíveis; se punho_apagar_titular não for alargada, o apagamento deixa-as intactas; clientes sem base legal); colaborador pode alterar notes e todos os campos da lead, logo reescreveria a história comercial; duplicados offline partem a ficha.
Pior resultado realista: três meses de trabalho, piloto não usa, e bugs de conversão a falsificar KPIs.
O que o decisor se recusa a ver: não sabe quantos clientes tem o piloto (se 40, uma ficha de leitura chega); nem se a landing alimenta o CRM.
Sinais de aviso: <3 interacções/semana em 2 semanas; «onde meto a conversa do WhatsApp?»; pedidos de etiquetas ou campanhas.
Posição: não construir CRM: corrigir os 5 bugs e fazer só a ficha de cliente de leitura + botões tel:/wa.me, e esperar que o piloto prove dor antes de registar interacções. Confiança: média.

## Resposta E
Primeiro passo (segunda, ~2h): corrigir o bug do formulário de lead que fecha sem gravar (operational_pages.dart:2488-2499). Prova: teste de widget com campo vazio mostra erro e não fecha; flutter test verde.
Próximos 7 dias: 1) seg: bug 1 + bug 2 (conversão só na 1ª reserva confirmada, ou alinhar o doc com o código; o Cesar decide) · 2) ter: migration do expurgo a respeitar a conversão (DB viva só com ok do Cesar) · 3) ter: confirmar se o funil do site chama receber-lead · 4) qua-qui: edição de lead (nome, telefone, origem, estado) e origem pedida na UI, sem migration (colaborador já pode alterar a lead) · 5) sex: ficha de cliente só de leitura (reservas, recebimentos, dívida, notas) derivada de dados existentes · 6) sáb-dom: botões tel:/wa.me/mailto com url_launcher, prova com toque real no Redmi.
Caminho crítico: bugs → edição de lead → ficha de leitura. Em paralelo: perguntar ao piloto (10 min).
Fica para depois, só com pedido do piloto: interacções com data e autor e próxima acção (entidade nova, permissão por campo no servidor, extensão do punho_apagar_titular; >1 semana e risco RGPD).
Bloqueios: não informado: nº de clientes/leads do piloto e se quer WhatsApp; migration mexe na DB viva (ok do Cesar); publicar só a pedido; orçamento de tempo não informado.
Posição: viável com condições: nesta semana só bugs, edição de lead, ficha de leitura e atalhos de contacto; adiar interacções e lembretes até o piloto os pedir. Confiança: média.

## Revisão cruzada
Os 5 revisores ordenaram igual: **C > E > D > A > B**. Pontos cegos: B (sem modelo, ordem nem bugs) e A (optimista, ignora risco de preenchimento e RGPD). Falharam TODAS: conflitos offline/duplicados sem mitigação; lembrete sem rede; RGPD de clientes sem base legal; desenho concreto dos dados; critério mensurável para passar de ficha de leitura a interacções; ninguém pôs o piloto como pergunta de 10 min; a contradição «Não é CRM» do OBJECTIVO fica por decidir pelo César.

## Contexto completo verificado
Ver CONTEXTO_CRM_PUNHO.md (copiado ao lado).

## Veredicto do presidente
**Recomendação:** não construir um módulo CRM. Fechar o ciclo Lead→Reserva que já existe: corrigir os bugs; dar à lead e à reserva «próxima acção + data» e «último contacto», alimentando a função pura de Tarefas (sem tabelas novas); botão ligar/WhatsApp que grava «contactei» em 1 toque; origem obrigatória; motivo de perda (3 opções) só em «perdida»; ficha de cliente de leitura derivada das reservas. Fora até o piloto pedir: interacções de texto livre, importação, etiquetas, kanban, segmentos.
**Terceira via:** «CRM sem módulo» — o CRM é um campo de data no ciclo que já existe.
**Primeiro passo:** corrigir o formulário de lead que fecha sem gravar (operational_pages.dart:2488-2499), com teste de widget; em paralelo, 10 minutos com o piloto.
**Decisões do César:** (1) conversão da lead: ao criar cliente (código) ou à 1ª reserva confirmada (doc); (2) emendar ou não o «Não é CRM» do OBJECTIVO; (3) ok à migration do expurgo (DB viva).
**Lacunas de todos (nota do presidente):** lembrete sem rede = notificação local agendada no aparelho (proposta minha, não debatida); conflitos offline e duplicados; base legal nos clientes.
Council de 5 agentes Claude isolados, com lentes distintas.
