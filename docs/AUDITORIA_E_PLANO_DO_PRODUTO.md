# Punho — auditoria e plano do produto

> Estado: fundação do produto  
> Nome fixado: **Punho**  
> Assinatura: **Agarra o comando.**

## 1. Decisão de produto

O Punho é uma aplicação autónoma de gestão ativa para pequenos empresários. Não é um painel de contabilidade: ensina o empresário a gerir através do uso diário. Faz perguntas na altura certa, recolhe apenas os dados necessários, explica os números e recomenda a próxima ação prática.

O primeiro caso de uso é uma empresa de aluguer de máquinas com poucos funcionários e, quando aplicável, viaturas de apoio. A estrutura deve poder adaptar-se a outros tipos de negócio sem perder a clareza do primeiro vertical.

O objetivo é substituir gestão por sensação por decisões baseadas em reservas, máquinas, dinheiro recebido, despesas, leads e padrões reais da atividade.

## 2. Identidade e posicionamento

### Marca

- Nome visível: **Punho**.
- Assinatura curta: **Agarra o comando.**
- Explicação longa: **Agarra o comando do teu negócio.**
- A marca deve transmitir firmeza, direção, rigor, ambição e crescimento.
- O logótipo decidido representa uma mão estilizada a agarrar ou elevar a linha de um gráfico económico. Não deve representar um punho fechado ou agressividade.
- O mockup final deve ser colocado na pasta assets/brand/ quando o projeto Flutter for criado.

### Relação com WashControl e WashInvoice

- O cliente final não saberá que o Punho é controlado pelo WashControl.
- O WashInvoice Control será o painel interno que autoriza, suspende, reativa e audita o acesso comercial ao Punho.
- A relação não é visual nem comercial: no Punho o cliente vê apenas Punho, a sua empresa e a sua equipa.
- Nenhum ecrã, nome, loja de aplicações ou comunicação do Punho mostra WashControl ou WashInvoice.
- D:\gestao_fluxo fica onde está, não é alterado e continua disponível para consulta.
- O Punho é autónomo; gestao_fluxo é referência de arquitetura, cálculos e produto, não uma dependência direta.

## 3. Princípios inegociáveis

1. **Primeiro registar, depois analisar.** O utilizador não responde a um questionário longo para registar uma despesa, recebimento ou marcação.
2. **Poucos toques.** A experiência do funcionário é desenhada para Android e tablet, com botões grandes.
3. **Os números nascem da operação.** Reservas, máquinas, leads, recebimentos e despesas alimentam a gestão.
4. **Estimativas são válidas.** O produto distingue dados estimados de confirmados; nunca preenche incógnitas com zero.
5. **A categoria serve a gestão.** Uma fatura de almoço entra em Refeições, sem perguntar para quem foi. O tratamento fiscal é separado.
6. **Dinheiro não é lucro.** O painel separa recebimentos, pagamentos, resultado, previsões e valores por receber.
7. **Histórico obrigatório.** Recebimentos, correções, reservas e estados de máquina deixam rasto auditável.
8. **Punho recomenda; o gestor decide.** O sistema não ativa descontos, campanhas ou alterações financeiras sozinho.
9. **Uma pergunta, uma razão.** Sempre que pedir um dado, explica porque esse dado desbloqueia uma análise ou decisão.

## 4. Perfis e superfícies

### 4.1 Punho Gestor

Aplicação completa para proprietário/gestor, disponível em Windows, Android, iOS e tablet.

No Windows, a navegação é uma barra lateral:

    Gestão
    Funcionários                 (condicional)
    Máquinas
    Veículos                     (condicional)
    Clientes
    Marcações / Reservas

- Funcionários aparece quando a empresa declara ter colaboradores.
- Veículos aparece quando a empresa declara possuir frota, mesmo que seja apenas uma viatura.
- Máquinas, clientes e reservas são centrais neste vertical.
- O registo rápido de despesa e recebimento fica sempre acessível.

### 4.2 Acesso de colaborador

É a área de funcionário, no mesmo código-base, mas com permissões e interface diferentes. É desenhada primeiro para telemóvel e tablet Android. Não é um produto ou licença autónoma: cada colaborador ocupa uma vaga da capacidade contratada pela empresa.

O funcionário não vê custos salariais, lucro/prejuízo, valores globais ou informação privada que não seja necessária ao seu trabalho.

Ecrã inicial:

    [ Nova marcação ]
    [ Registar recebimento ]
    [ As minhas marcações ]
    [ Folha de ponto ]           (só se o gestor ativar)

Cada ação fica ligada ao funcionário, data/hora, empresa e sessão/dispositivo.

## 5. Modelo operacional: aluguer de máquinas

O núcleo é a reserva. A cadeia de dados é:

    Lead válida → Cliente → Marcação/Proposta → Reserva confirmada
    → Máquina → Entrega/uso/devolução → Recebimento → Gestão

### 5.1 Leads e funil comercial

Uma lead é um potencial cliente com informação suficiente para ser tratada: contacto, necessidade e data provável ou janela temporal.

Estados mínimos:

    nova → contactada → proposta/marcação → convertida em reserva
                                      ↘ perdida

Indicadores a construir quando existir histórico:

- leads válidas por período, origem e funcionário;
- taxa de conversão lead para reserva;
- reservas e receita por funcionário angariador;
- leads necessárias para atingir uma meta de reservas;
- custo de publicidade/campanha por lead, reserva e receita atribuída.

Exemplo de orientação:

> “A tua conversão recente é de 1 reserva por cada 3 leads válidas. Para conseguires mais 3 reservas nas próximas duas semanas, procura cerca de 9 leads válidas.”

### 5.2 Clientes

Dados mínimos:

- nome/designação e contactos;
- histórico de leads, marcações, reservas e pagamentos;
- valores em aberto;
- origem da lead quando conhecida;
- notas operacionais necessárias.

**Regra de propriedade e partilha:** o cliente pertence sempre à empresa, nunca a um colaborador. Todos os colaboradores ativos da mesma empresa consultam a mesma base de clientes, de acordo com as permissões do seu perfil. O colaborador pode ser associado à lead angariada, à reserva criada ou ao recebimento registado, mas não passa a ser dono do cliente.

### 5.3 Máquinas

Cada máquina possui código interno curto, por exemplo M-014, e pode ter número de série. O código interno é usado no dia a dia; o número de série é o identificador técnico/legal.

Estados mínimos:

    disponível | reservada | alugada | em transporte | em manutenção | indisponível

Regras:

- uma máquina não pode ter duas reservas confirmadas com períodos sobrepostos;
- manutenção bloqueia disponibilidade;
- toda a alteração de estado fica no histórico;
- o calendário mostra estado passado e futuro;
- cada máquina pode ter QR code para entregas, recolhas, manutenção e inventário.

### 5.4 Marcações, reservas e pagamentos

Uma marcação pode existir antes de estar confirmada. Uma reserva confirmada bloqueia a máquina para um período.

Cada reserva guarda as referências do cliente e do colaborador responsável/angariador. Nas listas do gestor, a linha de reserva mostra ambos de forma legível: **Cliente: [nome] · Colaborador: [nome]**. A referência persistida é sempre o identificador, não apenas o nome, para preservar histórico mesmo quando um nome é alterado.

Dados mínimos:

- cliente;
- máquina ou máquinas;
- data/hora de início e fim;
- preço acordado;
- desconto/campanha, quando aplicável;
- funcionário que angariou ou registou;
- estado;
- valor total, recebido e pendente;
- método de pagamento;
- entrega e devolução, quando aplicável.

Um recebimento pode ser parcial. O funcionário não apaga recebimentos; erros são corrigidos pelo gestor através de correção ou reversão auditável.

### 5.5 Funcionários

O gestor regista:

- nome e função;
- custo semanal ou mensal;
- horário/horas contratadas para cálculo interno;
- data de validade de cada alteração de custo ou horário;
- permissões;
- marcações angariadas;
- dinheiro recolhido;
- folha de ponto, quando ativada.

O horário não aparece ao funcionário por defeito. Serve para calcular custo por hora e capacidade.

Indicador inicial de contributo:

    reservas e recebimentos associados ao funcionário
    versus
    custo do funcionário no período

Quando existirem horas reais suficientes, acrescentar receita por hora, custo por hora e produtividade. O resultado deve ser identificado como resultado atribuível, não como lucro contabilístico definitivo.

### 5.6 Veículos

O módulo é condicional. Cada viatura pode guardar:

- matrícula/identificação;
- tipo: própria, financiada, leasing ou alugada;
- prestação;
- combustível;
- seguro;
- IUC e manutenção;
- despesas e, futuramente, tarefas de entrega/recolha.

### 5.7 Despesas e faturas

Fluxo de registo:

    Fotografar fatura → ler QR quando disponível → extrair texto/OCR
    → sugerir fornecedor, valor, data e categoria → confirmar/editar → guardar

O sistema aprende regras por fornecedor depois de confirmação. Nunca classifica silenciosamente. Entrada manual rápida é obrigatória quando QR/OCR falhar.

Categorias iniciais:

- refeições;
- combustível;
- manutenção e reparação;
- publicidade;
- seguros;
- renda e instalações;
- eletricidade, água, comunicações e software;
- salários/pessoal;
- prestações e financiamentos;
- impostos/obrigações;
- outros.

A associação de despesa a máquina/viatura é aprofundamento opcional e não bloqueia o registo.

## 6. Gestão ensinada pela aplicação

### 6.1 Mapa inicial do negócio

O primeiro objetivo é construir o mapa real do negócio. Perguntas progressivas:

- ENI, empresário em nome individual, unipessoal ou Lda;
- obrigações/regime relevantes;
- escritório, armazém ou parque;
- custos fixos do espaço;
- existência de viaturas;
- máquinas próprias, financiadas, leasing ou alugadas;
- número de funcionários e custo aproximado;
- manutenção anual estimada;
- condições de pagamento dos clientes.

O utilizador pode indicar valores redondos e marcar “não sei ainda”. O Punho cria uma tarefa para confirmar o dado mais tarde.

### 6.2 Painel Gestão

Cada cartão responde a uma pergunta e contém resultado, causa/comparação e próxima ação.

Dados prioritários:

- dinheiro recebido hoje, semana e mês;
- dinheiro gasto hoje, semana e mês por categoria;
- reservas futuras e receita prevista;
- máquinas disponíveis, alugadas, paradas e em manutenção;
- clientes com valores em atraso;
- leads válidas e conversão;
- resultado operacional estimado/completo;
- custo e contributo por funcionário;
- custos por categoria e comparação temporal;
- campanhas e promoções com resultado.

### 6.3 Recomendações acionáveis

**Recebimentos abaixo do previsto**

> “Recebeste menos dinheiro do que o previsto. Tens 3 clientes em atraso, num total de 1.250 €. Cobra-os e cria novas leads válidas para reforçar as reservas das próximas duas semanas.”

**Baixa procura recorrente por dia da semana**

> “Nas últimas 3 quartas-feiras tiveste apenas 2 reservas. Tens 6 máquinas disponíveis para a próxima quarta. Cria uma campanha Quarta Forte com desconto de 35% em novas reservas desse dia.”

A recomendação só aparece quando existe capacidade ociosa e padrão recorrente. O gestor confirma, ajusta ou ignora o desconto.

**Peso de despesas**

> “O resultado foi positivo, mas baixo. Refeições somaram 5.000 € este mês. Se baixarem 20%, o resultado melhora 1.000 €.”

O sistema analisa o impacto agregado e não questiona o contexto de cada fatura.

**Máquina parada**

> “A M-014 está parada há 10 dias. Confirma se está disponível, em manutenção ou sem procura.”

### 6.4 Campanhas

Uma campanha contém:

- nome;
- período e regra de elegibilidade;
- desconto proposto/aprovado;
- máquinas/categorias abrangidas;
- objetivo de leads e reservas;
- origem/canal;
- custo de publicidade;
- leads, reservas, receita e resultado atribuídos.

Princípio: **100% de zero é zero**. Uma máquina que estaria parada pode justificar promoção controlada para gerar entrada de dinheiro e novos clientes. O desconto nunca é aplicado automaticamente.

## 7. Auditoria de D:\gestao_fluxo

### 7.1 Base existente

D:\gestao_fluxo é um monorepo Flutter/Dart para o apêndice WashInvoice Gestão:

- gestao_core: modelos, contratos, motor de KPIs e regras de trabalho;
- washinvoice_gestao: interface Flutter com Riverpod e Drift/SQLite;
- gestao_demo: demonstração Windows;
- testes para KPIs, ordens de trabalho e persistência.

### 7.2 Referências a aproveitar

Princípios e elementos reutilizáveis por adaptação:

- valores monetários em cêntimos;
- qualidade indisponível, estimado, completo e desatualizado;
- não mostrar KPI sem dados mínimos;
- cartões em linguagem simples;
- recomendação priorizada para pedir próximo dado;
- contratos de dados separados da interface;
- custo/hora válido à data de trabalho;
- persistência local Drift/SQLite;
- integração por adaptador, sem acesso direto à base de dados do anfitrião;
- cálculos de faturação, custos, resultado, fluxo de caixa, valores por receber e contributo de funcionário.

### 7.3 Lacunas face ao Punho

gestao_fluxo foi desenhado para lavandaria e como módulo da WashInvoice. Não contém:

- leads, campanhas, clientes, máquinas e reservas de aluguer;
- regras contra dupla reserva;
- modo funcionário em Android/tablet;
- sincronização multiutilizador;
- recebimentos auditáveis;
- foto de fatura, QR ou OCR;
- motor de procura por dia da semana;
- identidade Punho.

Conclusão: consultar e aproveitar princípios ou código isolado quando for útil; não tentar transformar gestao_fluxo no Punho e não mover os seus ficheiros.

## 8. Arquitetura proposta

### 8.1 Base técnica

- Flutter/Dart para Windows, Android e iOS.
- Uma base de código com perfil Principal/Gestor e perfil Colaborador.
- Interface responsiva para desktop, tablet e telemóvel.
- Persistência local-first para trabalho em campo com rede fraca.
- Repositórios e casos de uso separados da interface.
- Camada de sincronização abstrata, sem referência pública a WashControl.
- Supabase como infraestrutura interna comum, com tabelas, funções e políticas exclusivas do domínio Punho.

### 8.2 Autorização pelo WashInvoice Control

Foi confirmada a integração real entre o WashInvoice POS e o WashInvoice Control: ambos usam o mesmo projeto Supabase, mas não partilham dados operacionais. O Control autentica o administrador; o POS pede ao servidor um estado de licença sanitizado. O Punho deve seguir este padrão, melhorando-o para uma aplicação multiutilizador.

Fluxo definido para o Punho:

    Punho (gestor/equipa)
      -> autenticação própria por utilizador
      -> função Punho de sessão e licença
      -> dados isolados pela empresa e pelo perfil
      -> eventos operacionais sincronizados

    WashInvoice Control (interno)
      -> administrador autenticado
      -> cria/ativa/suspende/renova a licença da empresa Punho
      -> altera plano e capacidades por função de servidor
      -> consulta instalações, última sincronização e auditoria

Regras obrigatórias:

- A decisão de acesso comercial vem sempre do servidor. Uma licença suspensa ou expirada no Control bloqueia as áreas protegidas do Punho assim que houver ligação.
- O Punho pode manter uma cache local curta, cifrada e com prazo de tolerância para permitir trabalho de campo sem rede; nunca uma licença assinada com segredo dentro da aplicação.
- A primeira abertura cria uma instalação ou pedido de ativação idempotente. O Control vê-o como pendente, associa-o à empresa e escolhe plano, validade e capacidades.
- O identificador de instalação serve diagnóstico e auditoria, não é a identidade da empresa. A identidade principal é a empresa/tenant e os seus utilizadores autenticados.
- O colaborador inicia sessão com a sua conta; não recebe nem conhece a licença comercial. O seu perfil limita dados e ações, dentro da empresa já autorizada.
- A licença da empresa tem uma conta Principal e uma capacidade máxima de colaboradores ativos. O servidor recusa convites, reativações ou sessões de novos colaboradores acima desse limite.
- Só Edge Functions com verificação de JWT e autorização de administrador podem mudar licença, plano ou capacidades. Toda a alteração regista quem a fez, quando e qual era o estado anterior.
- Tabelas Punho usam RLS por empresa e perfil. A chave anónima pode existir no cliente; chaves de serviço e segredos ficam exclusivamente no servidor.
- A infraestrutura pode ser comum ao Control, mas as tabelas devem ter prefixo próprio (por exemplo, punho_) e não misturar reservas, despesas ou colaboradores com tabelas fiscais/licenças do WashInvoice.

O que se reutiliza do padrão atual: Control autenticado, funções de servidor para mutações sensíveis, histórico de ações e catálogo de versões. O que não se copia: HMAC embutido no cliente, autorização baseada apenas em machine_id, leituras diretas anónimas de tabelas e a mistura entre licença de terminal e identidade de utilizador.

#### 8.2.1 Estado implementado — provisório, DIVERGE do alvo acima

> Esta secção descreve o que existe hoje no código (sprint de licenciamento,
> Julho 2026). **Não substitui o alvo definido em 8.2** — regista uma solução
> intermédia, deliberadamente mais simples, para permitir pôr terminais no
> terreno antes de existir o domínio `punho_*`. Detalhe técnico em
> [LICENCIAMENTO.md](LICENCIAMENTO.md).

O que ficou feito:

- auto-onboarding no arranque, antes do login, idempotente e não bloqueante;
- trial de **40 dias** atribuído automaticamente (não é versão gratuita);
- validação no arranque e de 6 em 6 horas;
- banner de aviso em todos os ecrãs, com contacto directo para o Cesar.

Divergências conscientes face às regras de 8.2 e 8.4, por resolver:

| Regra definida | O que está implementado | Porquê |
|---|---|---|
| "nunca reutilizar diretamente a tabela `licencas`" (8.4) | Reutiliza `licencas`, com coluna `app='punho'` | As EFs multi-app já existiam e estavam testadas para o POS |
| Domínio próprio `punho_empresas`, `punho_instalacoes`, … (8.4) | Não existe | Depende do sprint de multi-app no Control |
| "não se copia autorização baseada apenas em machine_id" (8.2) | A licença **é** indexada por `machine_id` | Solução do POS, reaproveitada tal e qual |
| "licença expirada bloqueia as áreas protegidas" (8.2) | **Não bloqueia nada** — só mostra banner | Sem cliente pagante, bloquear só cria risco de falhar uma demonstração |
| "o preço é por empresa, não por instalação/dispositivo" (8.3) | Uma linha de licença **por dispositivo** | Consequência directa de usar `machine_id` |

A última linha é a mais relevante comercialmente: um gestor com o Punho no PC
e no telemóvel gera **duas** linhas em `licencas`, o que colide com o modelo de
preço por empresa definido em 8.3. Enquanto o faturamento for manual pelo
Cesar, não faz mal. Deixa de servir assim que houver cobrança automática.

### 8.3 Modelo comercial de colaboradores

A subscrição é composta por uma licença **Main** da empresa e por capacidade adicional de colaboradores. A primeira oferta definida é:

- 1 conta Main/Gestor, cobrada mensalmente;
- 0 ou mais pacotes mensais de colaboradores;
- cada pacote adiciona capacidade para até 3 colaboradores ativos;
- o preço é Main + X por cada pacote de 3 colaboradores, e não por instalação/dispositivo.

O Control define `limite_colaboradores_ativos` para cada empresa. Assim pode atribuir, aumentar ou retirar capacidade comercial sem alterar a app nem as permissões internas manualmente. Ao baixar o limite abaixo das contas ativas, o Control não desativa pessoas em silêncio: exige escolher quais as contas a desativar, ou deixa a empresa em estado "regularizar vagas" e bloqueia novos convites até ficar dentro do limite.

### 8.4 Capacidades controladas pelo Control

- plano Base/Pro ou equivalente;
- limite de colaboradores ativos e número de pacotes contratados;
- OCR de documentos e limite de utilização;
- número de empresas/unidades, se vier a existir;
- funcionalidades futuras sem alterar nem reinstalar a app.

Alterações necessárias no WashInvoice Control antes de ligar o Punho:

- criar um domínio próprio no Supabase: `punho_empresas`, `punho_membros`, `punho_subscricoes`, `punho_instalacoes` e `punho_auditoria_acessos`;
- acrescentar ao Control uma área Punho, separada das licenças fiscais do POS, para rever pedidos, associar empresa, definir validade/capacidades e consultar auditoria;
- criar funções próprias para ativação e validação do Punho; nunca reutilizar diretamente a tabela `licencas`, porque esta contém regras fiscais e licenças por terminal do POS;
- alargar o catálogo de versões, hoje limitado a `pos` e `control`, para aceitar `punho` e publicar as atualizações por app;
- manter a função administrativa com JWT, verificação de administrador e registo explícito do ator em cada mutação.

### 8.5 Contrato de sincronização

O projeto começa com uma interface, não com dependência rígida de fornecedor:

    PunhoSyncGateway
      ├─ sessão de utilizador e contexto de empresa
      ├─ estado de autorização e capacidades da empresa
      ├─ puxar alterações permitidas
      ├─ enviar eventos locais
      └─ resolver conflito por versão/evento

O adaptador real usa a infraestrutura interna já controlada pelo WashInvoice Control. O detalhe de schema e as funções serão definidos antes da implementação do backend, mas a separação de domínios, autorização no servidor e isolamento por empresa deixam de estar em aberto.

### 8.6 Segurança e auditoria

- permissões por empresa e perfil;
- funcionário vê apenas dados necessários;
- gestor controla custos, resultados, clientes e correções;
- reservas, recebimentos e estados de máquina geram eventos auditáveis;
- fotos de faturas, danos e comprovativos têm acesso restrito;
- não implementar GPS/monitorização permanente sem decisão explícita, base legal e configuração visível.

## 9. Limites da primeira versão

O Punho não será inicialmente:

- software de contabilidade certificada;
- processador salarial;
- e-commerce completo;
- portal público de cliente completo;
- telemática/GPS de frota;
- ERP multi-armazém complexo;
- sistema de descontos automáticos;
- substituto do contabilista.

## 10. Plano de execução em 10 fases

1. Fundação e auditoria: estrutura, este plano e decisões sem fornecedor externo.
2. Marca e shell: Punho, mockup aprovado, tema e navegação responsiva.
3. Identidade e permissões: empresa, Gestor/Funcionário, auditoria e contratos de sincronização.
4. Máquinas, clientes, leads e reservas: ciclo comercial e disponibilidade.
5. Funcionários e veículos: custos, horários internos, contributo e frota condicional.
6. Acesso de colaborador Android/tablet: marcação, recebimento, marcações próprias, ponto opcional e validação de vagas contratadas.
7. Despesas e documentos: fotografia, QR, OCR por adaptador, categorias e confirmação.
8. Gestão e ensino: KPIs, qualidade de dados, recomendações, leads e campanhas.
9. Sincronização real: backend autorizado, offline, conflitos, auditoria e segurança.
10. Qualidade e distribuição: testes, Windows/Android e validação com empresário piloto.

## 11. Critérios de sucesso do piloto

O empresário deve conseguir:

- criar máquina, cliente, lead e reserva;
- saber se uma máquina está disponível;
- registar despesas e recebimentos no próprio dia;
- dar acesso simples a funcionários;
- saber quem angariou marcações e recolheu dinheiro;
- ver dívidas, máquinas paradas e reservas futuras;
- perceber as causas de resultado baixo;
- receber uma ação concreta para gerar procura ou controlar custos.

## 12. Decisões ainda abertas

- login, convite de funcionários e recuperação de conta;
- infraestrutura de sincronização controlada internamente;
- regras fiscais/documentos aplicáveis ao mercado alvo;
- fornecedor e custo de OCR;
- meios de pagamento e validação de dinheiro recolhido;
- cópias de segurança, retenção e exportação;
- ficheiro final do mockup na pasta assets/brand/.

## 13. Atualização de implementação — julho de 2026

### O que está implementado localmente

- aplicação Flutter para Windows, Android e iOS, com navegação responsiva;
- domínio operacional de máquinas, clientes, leads, reservas, recebimentos,
  despesas, colaboradores, veículos, campanhas e recomendações;
- separação entre máquinas declaradas e máquinas identificadas;
- valores monetários em cêntimos no domínio;
- regras locais de conflito de reserva, valores pendentes e limite de
  colaboradores;
- modo de demonstração explícito quando não existe configuração Supabase;
- abstrações locais para QR/OCR e documentos: o utilizador confirma sempre os
  dados antes de criar uma despesa;
- motor determinístico de recomendações, sem alterações automáticas.

### Base multiempresa já preparada

O projeto inclui `supabase_flutter`, configuração pública por `--dart-define`,
`.env.example`, migrations e documentação de validação RLS. As migrations
presentes criam o domínio `punho_`, RLS, políticas iniciais, validação de
referências entre empresa/cliente/máquina/reserva, prevenção de conflitos de
reservas e a RPC atómica `punho_criar_empresa_inicial`.

Quando Supabase está configurado, a aplicação apresenta criação de conta,
login, restauro de sessão e criação inicial de empresa. A criação inicial gera
empresa, membro gestor, subscrição de desenvolvimento e instalação de forma
atómica.

### Decisões consolidadas dos brainstorms

- clientes pertencem à empresa, nunca ao colaborador;
- reservas preservam IDs relacionais e snapshots de cliente/colaborador;
- dinheiro recebido não é lucro; o produto usa “resultado operacional simples”;
- colaboradores registam trabalho, leads, pedidos e recebimentos, sem acesso a
custos ou indicadores globais;
- OCR/QR sugere e nunca confirma ou lança despesas automaticamente;
- promoções e campanhas são sugestões/riscunhos, nunca descontos automáticos;
- documentos deverão permanecer privados e usar URL assinada quando o upload
remoto estiver ligado;
- não há ligação administrativa externa nesta fase.

### Lacunas que impedem declarar o produto pronto para produção

- a interface operacional ainda usa repositórios locais como fonte de verdade;
- repositórios Supabase, outbox persistente, sincronização em rede e resolução
de conflitos ainda não estão ligados aos fluxos de interface;
- convites reais de colaboradores, recuperação de palavra-passe e permissões
de rota baseadas em membro Supabase ainda precisam de conclusão;
- upload privado de documentos, OCR local real e câmara Android não estão
integrados;
- a RLS deve ser aplicada e verificada num projeto Supabase real antes de usar
dados de clientes.

### Ordem recomendada a partir daqui

1. Ligar repositórios remotos de clientes, leads, máquinas e reservas à sessão.
2. Persistir outbox local e sincronizar operações com revisão/conflito.
3. Substituir perfis de demonstração por contexto de `punho_membros`.
4. Implementar armazenamento privado de documentos e convites reais.
5. Validar RLS com duas empresas e um colaborador antes de qualquer piloto.
