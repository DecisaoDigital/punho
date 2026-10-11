/// **O que cada cartão ensina.** Ao abrir um KPI, o gestor vê:
///
///  1. como se chega ao número e o que ele quer dizer, numa frase ou duas;
///  2. conforme a cor do cartão, o que fazer para o resultado ficar mais
///     positivo (laranja ou vermelho), ou um bom trabalho e um incentivo para ir
///     um pouco mais longe (verde).
///
/// Regra do César (11 Out 2026): a app existe também para ensinar a gerir uma
/// empresa a quem não sabe, e por isso nenhum cartão aparece sem explicação.
/// Os textos usam as regras que o próprio KPI usa: se a conta mudar, o texto
/// muda com ela.
class ExplicacaoDoKpi {
  const ExplicacaoDoKpi({
    required this.comoSeChega,
    required this.paraMelhorar,
    required this.parabens,
  });

  /// Como se calcula e o que significa.
  final String comoSeChega;

  /// Uma ou duas coisas concretas a fazer quando o cartão está laranja ou
  /// vermelho.
  final List<String> paraMelhorar;

  /// Quando está verde: o reconhecimento e o passo seguinte.
  final String parabens;
}

ExplicacaoDoKpi? explicacaoDe(String id) => _explicacoes[id];

const _explicacoes = <String, ExplicacaoDoKpi>{
  'break-even-mes': ExplicacaoDoKpi(
    comoSeChega:
        'Lucro bruto é o dinheiro que entrou este mês menos o que o mês tem de cobrir. O que o mês tem de cobrir é a maior de três contas: a despesa já lançada, a média dos três meses anteriores, e os custos fixos, equipa e frota que declaraste. Enquanto o número é negativo, o mês ainda não se pagou; quando chega a zero é o break even, o dia em que as despesas ficam cobertas. Daí em diante, cada euro que entra é lucro bruto.',
    paraMelhorar: [
      'Cobra as reservas já feitas e por pagar, e pede sinal nas que estão por marcar: dinheiro à frente aproxima o zero.',
      'Confirma os pedidos e propostas pendentes na agenda.',
      'Se o alvo parece alto, revê as despesas do mês: há alguma que se possa adiar ou renegociar?',
    ],
    parabens:
        'O mês já se pagou: o que entra daqui para a frente é lucro. A equipa está de parabéns! Agora o desafio é encher o resto do mês e passar o do ano passado.',
  ),
  'tendencia-mes': ExplicacaoDoKpi(
    comoSeChega:
        'A meta a que o histórico aponta para este mês: o mesmo mês do ano passado vezes (1 + o crescimento médio da empresa + o que este mês costuma ficar acima ou abaixo dessa média). Só olha para meses fechados, por isso o valor não muda enquanto o mês decorre. No fim vês quanto acertou, e quanto mais anos houver, mais afinada fica.',
    paraMelhorar: [
      'Estás abaixo do ritmo previsto: contacta os clientes habituais e propõe datas para as próximas semanas.',
      'Vê se há reservas em «pedido» ou «proposta enviada» por confirmar.',
    ],
    parabens:
        'O mês está a andar ao ritmo que o histórico prevê, ou melhor. Bom trabalho! Tenta ficar acima da previsão: é assim que a empresa cresce mais depressa do que a média.',
  ),
  'meta-mes': ExplicacaoDoKpi(
    comoSeChega:
        'A meta que tu fixaste: o mesmo mês do ano passado vezes (1 + o crescimento que previste para este trimestre). A cor compara o que já entrou com o ponto em que o mês devia estar. O dinheiro chega aos solavancos, porque se paga à recolha, por isso só alarma quando está muito atrás.',
    paraMelhorar: [
      'Estás atrás da meta que fixaste: contacta clientes antigos e preenche os dias livres da agenda.',
      'Cobra o que já foi feito e ainda não foi pago, para o dinheiro contar já.',
    ],
    parabens:
        'Estás a cumprir a meta que fixaste, e isso é gestão a sério. A equipa está de parabéns! Quando a ultrapassares, vale a pena subir a fasquia no próximo trimestre.',
  ),
  'entradas-mes': ExplicacaoDoKpi(
    comoSeChega:
        'Todo o dinheiro que entrou este mês, venha de reservas deste mês ou de meses anteriores. Conta no dia em que o pagamento é registado, não no dia em que o serviço acaba. É o que se pode contar com ele.',
    paraMelhorar: [
      'Há reservas concluídas por cobrar? Cobra-as esta semana.',
      'Pede um sinal nas marcações futuras: o dinheiro chega mais cedo.',
    ],
    parabens:
        'Está a entrar dinheiro ao bom ritmo. Parabéns à equipa! Mantém o hábito de cobrar à recolha, que é o que dá folga à caixa.',
  ),
  'vendas-mes': ExplicacaoDoKpi(
    comoSeChega:
        'O valor das reservas que terminam este mês, estejam ou não pagas. As canceladas não contam. Diz o trabalho que a empresa fez; o dinheiro que já entrou está em «Dinheiros que entraram».',
    paraMelhorar: [
      'Preenche os dias vazios da agenda: contacta clientes antigos e propõe-lhes datas.',
      'Revê o preço das máquinas mais procuradas: pode haver margem para subir.',
    ],
    parabens:
        'O trabalho do mês está ao nível do que a empresa costuma fazer, ou acima. Bom trabalho! Agora é garantir que se transforma em dinheiro recebido.',
  ),
  'lucro-mes': ExplicacaoDoKpi(
    comoSeChega:
        'As vendas do mês menos tudo o que o mês custou, com despesas pagas e por pagar. A meio do mês costuma estar em baixo: a estrutura entra toda logo ao início e as vendas ainda vão a meio. Os dois cartões abaixo mostram qual dos lados se mexeu.',
    paraMelhorar: [
      'Vê nos cartões abaixo qual dos lados se mexeu: as vendas ou a estrutura.',
      'Se foi a estrutura, procura a despesa que subiu; se foram as vendas, enche a agenda.',
    ],
    parabens:
        'O mês está a deixar lucro. A equipa está de parabéns! Guarda uma parte para os meses mais fracos e mantém o ritmo.',
  ),
  'estrutura-mes': ExplicacaoDoKpi(
    comoSeChega:
        'Quanto custa ter a casa aberta este mês, seja qual for o trabalho que entre: renda, equipa, frota e restantes custos. Se o lucro cai sem as vendas caírem, é aqui que está a razão.',
    paraMelhorar: [
      'Compara com o ano passado e procura a despesa que subiu.',
      'Renegoceia o que se repete todos os meses: seguros, comunicações, rendas.',
    ],
    parabens:
        'A casa está a custar o que é normal, ou menos. Parabéns pelo controlo! Cada euro poupado aqui é lucro que não depende de vender mais.',
  ),
  'caixa': ExplicacaoDoKpi(
    comoSeChega:
        'O que entrou menos o que saiu, do dia 1 até hoje. É o saldo real do mês, sem contar o que ainda não foi pago nem recebido. A cor compara-o com o costume da própria empresa.',
    paraMelhorar: [
      'Antecipa cobranças e adia os pagamentos que não são urgentes.',
      'Evita despesas novas até a caixa recuperar.',
    ],
    parabens:
        'A caixa está saudável. Boa gestão da equipa! Com folga, pode compensar pagar a pronto alguma despesa para negociar desconto.',
  ),
  'lucro-mes-anterior': ExplicacaoDoKpi(
    comoSeChega:
        'O lucro do último mês inteiro: as vendas menos tudo o que o mês custou. Como o mês já fechou, é o único que se compara sem ressalvas, e serve de régua para ler o mês que está a decorrer.',
    paraMelhorar: [
      'Compara com o mês anterior a esse e vê se caíram as vendas ou subiu a estrutura.',
      'Usa-o como alvo para este mês: se a meio do mês ainda estás longe, enche a agenda e corta o que não for essencial.',
    ],
    parabens:
        'O último mês fechou com lucro. A equipa está de parabéns! Agora o desafio é repetir ou superar este resultado no mês que está a decorrer.',
  ),
  'utilizacao-rentabilidade': ExplicacaoDoKpi(
    comoSeChega:
        'A percentagem é a ocupação das máquinas na semana em curso: os dias com trabalho marcado sobre os dias disponíveis. Por baixo vês quanto do dinheiro investido nas máquinas já voltou, contando o que elas facturaram. Verde a partir de 60% de ocupação, laranja a partir de 30%.',
    paraMelhorar: [
      'Propõe datas aos clientes habituais para os dias vazios desta semana e das seguintes.',
      'Se uma máquina quase não sai, revê-lhe o preço por dia ou oferece-a como alternativa nas reservas.',
    ],
    parabens:
        'As máquinas estão bem ocupadas e a render. Parabéns à equipa! Vê agora quais as que ainda não recuperaram o que custaram e dá-lhes prioridade nas marcações.',
  ),
  'maquina-parada': ExplicacaoDoKpi(
    comoSeChega:
        'Mostra a máquina há mais tempo sem sair e quantos dias leva parada. Fica laranja a partir de 14 dias e vermelho quando já é muito tempo. Uma máquina parada é dinheiro já pago a não render.',
    paraMelhorar: [
      'Liga a clientes que já alugaram esta máquina e propõe-lhes uma data.',
      'Se ninguém a pede, revê o preço ou inclui-a como extra em reservas de outras máquinas.',
    ],
    parabens:
        'Nenhuma máquina está parada demais. Boa gestão da agenda! Continua a rodar a frota e a avisar os clientes das máquinas menos pedidas.',
  ),
  'encontro-contas': ExplicacaoDoKpi(
    comoSeChega:
        'O que entrou este mês menos o que saiu, venha de onde vier. Positivo quer dizer que o mês está a deixar dinheiro em caixa; negativo, que está a gastar mais do que recebe.',
    paraMelhorar: [
      'Cobra já o que está feito e por receber.',
      'Adia as despesas que não são urgentes até o saldo voltar ao positivo.',
    ],
    parabens:
        'Entra mais do que sai. A equipa está de parabéns! Guarda parte da folga para os meses mais fracos.',
  ),
  'recomendacao-dia': ExplicacaoDoKpi(
    comoSeChega:
        'Não é uma medida, é um conselho: a app olha para os sinais da empresa (cobranças, recolhas, agenda, leads) e escolhe o que mais merece a tua atenção hoje. Vermelho é urgente, laranja pede atenção e verde é uma oportunidade.',
    paraMelhorar: [
      'Faz primeiro o que o cartão sugere: costuma ser o que mais custa se ficar para amanhã.',
      'Quando o tiveres feito, volta cá: o cartão muda consoante o que a empresa precisa a seguir.',
    ],
    parabens:
        'Não há nada urgente a assinalar, ou só oportunidades. Bom trabalho! Aproveita para contactar clientes antigos ou adiantar tarefas.',
  ),
  'reservas-activas': ExplicacaoDoKpi(
    comoSeChega:
        'Quantas reservas estão em curso neste momento, e quantas terminam nas próximas 48 horas. É o pulso do dia: com zero reservas em curso as máquinas estão paradas e não há dinheiro a entrar.',
    paraMelhorar: [
      'Contacta clientes habituais e propõe novas datas.',
      'Se muitas terminam já, marca as próximas reservas antes de as máquinas voltarem.',
    ],
    parabens:
        'Há trabalho em curso e a empresa está a mexer. A equipa está de parabéns! Prepara já as próximas marcações para não haver buracos.',
  ),
  'entregas-hoje': ExplicacaoDoKpi(
    comoSeChega:
        'Quantas máquinas estão marcadas para sair hoje. Fica laranja enquanto houver entregas por fazer e verde quando todas já saíram ou não há nenhuma.',
    paraMelhorar: [
      'Confirma com o cliente a hora e o local e prepara a máquina com antecedência.',
      'Se alguma está atrasada, avisa o cliente antes que ele ligue.',
    ],
    parabens:
        'Todas as entregas de hoje estão feitas. Parabéns à equipa! Uma entrega pontual é a melhor publicidade para o cliente voltar.',
  ),
  'recolhas-fazer': ExplicacaoDoKpi(
    comoSeChega:
        'Quantas máquinas têm de ser recolhidas hoje e nas próximas 48 horas. Laranja quando há recolhas hoje e vermelho quando alguma já passou o dia: a máquina continua fora e não pode ser alugada a outro.',
    paraMelhorar: [
      'Liga já ao cliente das recolhas em atraso e combina uma hora.',
      'Planeia o percurso do dia para juntar recolhas e entregas na mesma volta.',
    ],
    parabens:
        'Nenhuma máquina por recuperar em atraso. A equipa está de parabéns! Máquinas de volta a tempo são máquinas prontas para a próxima reserva.',
  ),
  'cobrancas-7d': ExplicacaoDoKpi(
    comoSeChega:
        'O dinheiro por receber das reservas que vencem nos próximos 7 dias, e a quantos clientes. Fica laranja se há algo a cobrar e vermelho se há valores a vencer hoje.',
    paraMelhorar: [
      'Lembra ao cliente, um ou dois dias antes, quanto e como deve pagar.',
      'Cobra à recolha ou à entrega, em vez de deixar para depois.',
    ],
    parabens:
        'Não há nada por cobrar nos próximos dias. Bom trabalho! Continua a cobrar à recolha e a pedir sinal nas reservas novas.',
  ),
  'cobrancas-em-atraso': ExplicacaoDoKpi(
    comoSeChega:
        'O dinheiro que já devia ter entrado e não entrou, e de quantos clientes. A régua é o prazo em que os clientes desta casa costumam pagar; sem recibos que cheguem para o medir, conta a partir do dia seguinte ao fim do trabalho. Fica vermelho quando a dívida mais antiga passa de 30 dias.',
    paraMelhorar: [
      'Telefona esta semana ao cliente da dívida mais antiga: é o telefonema que mais rende.',
      'Para os novos clientes, pede sinal ou pagamento à recolha.',
    ],
    parabens:
        'Ninguém te deve dinheiro vencido. A equipa está de parabéns! Mantém o hábito de cobrar logo e a caixa agradece.',
  ),
  'clientes-novos-30d': ExplicacaoDoKpi(
    comoSeChega:
        'Quantos clientes foram registados nos últimos 30 dias e, destes, quantos já têm reserva. Laranja quando não entrou ninguém novo. Uma empresa que não angaria clientes vive só dos que já tem.',
    paraMelhorar: [
      'Pede a cada cliente satisfeito que indique um conhecido.',
      'Responde depressa aos pedidos que chegam e transforma-os em reserva.',
    ],
    parabens:
        'Estão a chegar clientes novos. Parabéns à equipa! Garante agora que cada um faz a primeira reserva, e que volta.',
  ),
  'leads-pipeline': ExplicacaoDoKpi(
    comoSeChega:
        'Quantas leads (pessoas que perguntaram por um serviço) ainda ninguém contactou. No texto de baixo vês quantas estão em aberto no total. Laranja se há leads por contactar e vermelho se alguma espera há mais de 5 dias.',
    paraMelhorar: [
      'Contacta hoje as leads que esperam há mais tempo: quem pergunta e não tem resposta vai à concorrência.',
      'Regista cada contacto na ficha da lead, para a app saber que ela já foi tratada.',
    ],
    parabens:
        'Todas as leads foram contactadas a tempo. A equipa está de parabéns! Agora é acompanhar as propostas até fechar.',
  ),
  'ticket-medio-mes': ExplicacaoDoKpi(
    comoSeChega:
        'O valor previsto das reservas do mês dividido pelo número de clientes diferentes. Diz quanto vale, em média, cada cliente este mês. Por baixo vês quantas vezes, em média, cada um repetiu a compra. É um número para acompanhar e não tem cor de alarme.',
    paraMelhorar: [
      'Para subir o valor por cliente, propõe mais dias ou uma segunda máquina na mesma reserva.',
      'Para aumentar as recompras, contacta o cliente pouco depois de a reserva terminar.',
    ],
    parabens:
        'Cada cliente vale um bom valor este mês. Bom trabalho! Tenta agora que mais clientes repitam a compra: é o que faz o número crescer sem gastar em publicidade.',
  ),
  'conversao-lead-cliente': ExplicacaoDoKpi(
    comoSeChega:
        'De cada 100 pessoas que perguntaram por um serviço nos últimos 30 dias, quantas acabaram por ser clientes. Vês também a diferença para os 30 dias anteriores. Verde a partir de 40%, laranja a partir de 20%.',
    paraMelhorar: [
      'Responde às leads no próprio dia e envia a proposta com preço claro.',
      'Pergunta às que não fecharam porque não fecharam: descobres o que te faz perder negócio.',
    ],
    parabens:
        'Estás a fechar bem os pedidos que chegam. A equipa está de parabéns! Quanto mais leads tiveres, mais clientes isto dá: investe em trazer mais.',
  ),
  'saldo-e-autonomia': ExplicacaoDoKpi(
    comoSeChega:
        'As semanas que o dinheiro em caixa dá para pagar as despesas, se não entrar mais nada. É o saldo (o que entrou menos o que se pagou desde o primeiro registo) a dividir pelo gasto semanal: custos fixos mais a média das despesas variáveis dos três meses anteriores. É aproximado, porque a app não vê o banco. Vermelho abaixo de 6 semanas, laranja abaixo de 12.',
    paraMelhorar: [
      'Cobra o que está em atraso e adia as despesas que não são urgentes.',
      'Corta o gasto semanal: renegoceia os custos fixos e evita compras novas até teres mais folga.',
    ],
    parabens:
        'Tens mais de 12 semanas de folga. Parabéns à equipa! Com esta almofada podes investir com calma, mas sem esquecer o ritmo a que gastas.',
  ),
  'margem-bruta': ExplicacaoDoKpi(
    comoSeChega:
        'Do dinheiro que entrou este mês, a parte que sobra depois de pagar o que custou servir os clientes: manutenção de máquinas e da frota, combustível e consumíveis. Vês também a diferença para o mês passado. Verde a partir de 60%, laranja a partir de 35%.',
    paraMelhorar: [
      'Procura as despesas directas que mais pesam e vê se há fornecedor mais barato.',
      'Revê o preço de aluguer: se o custo subiu e o preço ficou, a margem encolhe.',
    ],
    parabens:
        'Sobra uma boa parte de cada euro que entra. A equipa está de parabéns! Mantém a manutenção em dia, que é o que protege esta margem.',
  ),
  'ciclo-de-tesouraria': ExplicacaoDoKpi(
    comoSeChega:
        'Quantos dias o teu dinheiro passa fora do bolso nos últimos 90 dias: os dias que demoras a cobrar, mais os dias em que as máquinas estão paradas, menos os dias que demoras a pagar aos fornecedores. Verde até 30 dias, laranja até 60.',
    paraMelhorar: [
      'Cobra mais cedo: pede sinal e cobra à recolha.',
      'Enche os dias parados da frota, ou negoceia prazo de pagamento com os fornecedores.',
    ],
    parabens:
        'O dinheiro volta depressa ao bolso. Bom trabalho! Cada dia que encurtas liberta dinheiro para investir.',
  ),
  'contas-a-pagar': ExplicacaoDoKpi(
    comoSeChega:
        'Tudo o que está lançado como despesa por pagar, de qualquer mês, e a mais antiga em dias. Uma factura de há dois meses continua a ter de sair da conta. Fica vermelho quando a mais velha tem 30 dias ou mais.',
    paraMelhorar: [
      'Paga primeiro a mais antiga, ou combina um prazo com o fornecedor.',
      'Marca como paga cada despesa assim que a pagares, para o número ser verdadeiro.',
    ],
    parabens:
        'Não há contas por pagar, ou nenhuma está esquecida. A equipa está de parabéns! Pagar a tempo dá boa relação com os fornecedores e poder para negociar.',
  ),
  'fluxo-de-caixa-livre': ExplicacaoDoKpi(
    comoSeChega:
        'O que sobra este mês depois de pagar tudo e de comprar máquinas: o que entrou menos o que saiu, menos o preço das máquinas adquiridas no mês. Um mês pode ter saldo positivo e fluxo livre negativo por se ter investido.',
    paraMelhorar: [
      'Se foi uma compra de máquina, confirma que ela vai render o suficiente para se pagar.',
      'Se não foi, trata o que limita o saldo: cobranças em atraso e despesas altas.',
    ],
    parabens:
        'Sobrou dinheiro depois de tudo pago. A equipa está de parabéns! Isso é o que permite crescer: pensa onde o investir.',
  ),
  'custo-de-aquisicao': ExplicacaoDoKpi(
    comoSeChega:
        'O que gastaste em publicidade nos últimos 90 dias a dividir pelos clientes novos desse período. É um piso: só conta a categoria publicidade, não o tempo gasto nem comissões. Fica vermelho quando se gastou e não entrou ninguém.',
    paraMelhorar: [
      'Corta o canal que não trouxe clientes e reforça o que trouxe.',
      'Pergunta a cada cliente novo como te encontrou, para saberes onde gastar.',
    ],
    parabens:
        'A publicidade está a trazer clientes. Bom trabalho! Compara este custo com o que cada cliente deixa na empresa: se compensa, vale a pena investir mais.',
  ),
  'receita-recorrente': ExplicacaoDoKpi(
    comoSeChega:
        'Do dinheiro que entrou este mês, a parte que veio de clientes que já tinham reservado antes deste mês. Mostra se os clientes voltam. Verde a partir de 50%, laranja a partir de 25%.',
    paraMelhorar: [
      'Contacta os clientes que alugaram há mais de um mês e propõe-lhes nova data.',
      'Trata bem a primeira reserva: é a que decide se voltam.',
    ],
    parabens:
        'Muitos clientes estão a voltar, e isso é confiança. A equipa está de parabéns! Mantém o contacto depois de cada reserva e vai mais longe.',
  ),
  'satisfacao-cliente': ExplicacaoDoKpi(
    comoSeChega:
        'Ainda não há como medir: a app não tem um inquérito ao cliente no fim da recolha. Por agora este cartão só assinala essa falta e não muda de cor.',
    paraMelhorar: [
      'Enquanto não houver inquérito, pergunta a cada cliente, no fim da recolha, como correu.',
      'Anota as queixas e os elogios: são o melhor guia do que mudar.',
    ],
    parabens:
        'Quem pergunta aos clientes o que acharam já está à frente de muitos. Bom trabalho! Continua a ouvi-los.',
  ),
  'leads-frias': ExplicacaoDoKpi(
    comoSeChega:
        'Quantas leads continuam em aberto e foram registadas há mais de 14 dias. A app guarda a data em que a lead entrou, e não a do último contacto. Laranja quando há alguma.',
    paraMelhorar: [
      'Liga hoje às mais antigas, antes que esfriem de vez.',
      'Dá a cada lead um fim: fecha-a como cliente ou como perdida, para o funil mostrar só o que está vivo.',
    ],
    parabens:
        'Nenhuma lead está a arrefecer. A equipa está de parabéns! Continua a acompanhar os pedidos até terem resposta.',
  ),
  'alertas-operacionais': ExplicacaoDoKpi(
    comoSeChega:
        'Junta o que exige acção hoje na operação: entregas, recolhas e cobranças em atraso, pela ordem em que mais custam. Vermelho se há recolhas em atraso, laranja nos restantes avisos.',
    paraMelhorar: [
      'Resolve primeiro as recolhas em atraso: há máquinas paradas fora de casa.',
      'Depois trata as entregas e as cobranças que o cartão lista.',
    ],
    parabens:
        'Entregas, recolhas e cobranças estão em dia. Parabéns à equipa! A operação a andar sem atrasos é a base de tudo o resto.',
  ),
  'gastos-previstos-mes': ExplicacaoDoKpi(
    comoSeChega:
        'Quanto a empresa deve gastar até ao fim do mês: os custos fixos que declaraste mais a média das despesas variáveis dos meses de referência com registo. Sem custos fixos declarados a previsão fica curta. É uma previsão e não muda de cor.',
    paraMelhorar: [
      'Se o número te assusta, vê que custos fixos se podem renegociar.',
      'Garante que os custos fixos estão todos declarados: sem eles a previsão engana.',
    ],
    parabens:
        'Sabes quanto vais gastar este mês, e é isso que permite decidir com calma. Bom trabalho! Compara-o com as entradas previstas para teres a certeza de que o mês fecha bem.',
  ),
  'saldo-previsto-mes': ExplicacaoDoKpi(
    comoSeChega:
        'Como o mês deve fechar: o que já entrou mais o que falta receber das reservas do mês, menos os gastos previstos. Verde se for positivo e vermelho se a previsão for de prejuízo. Sem custos fixos declarados não se calcula.',
    paraMelhorar: [
      'Cobra o que falta receber e confirma as reservas pendentes.',
      'Adia ou corta despesas que não sejam essenciais antes do fecho do mês.',
    ],
    parabens:
        'O mês deve fechar com saldo positivo. A equipa está de parabéns! Continua a cobrar à recolha para a previsão virar realidade.',
  ),
};
