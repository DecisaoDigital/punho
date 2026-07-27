# Punho — para onde não estamos a olhar

> Relatório complementar às auditorias
> `AUDITORIA_KPIS_EMPRESA.md` e `AUDITORIA_APP_ENSINO_GESTAO.md`.
>
> As duas primeiras auditorias foram frias sobre o que existe e o que
> falta *dentro do que já foi decidido*. Este relatório força a
> pergunta oposta: **das coisas em que nem estamos a pensar, qual vale
> a pena pensar já?**

## Método

Onze pistas em bruto, listadas cruas. Depois filtradas por três
critérios:

1. **Alinhamento com o propósito declarado** — a app existe para
   *ensinar gestão na prática*, não para automatizar tarefas.
2. **Assimetria de mercado** — algo que ninguém no vertical faz e é
   defensável (mais valor por unidade de esforço).
3. **Reversibilidade** — se experimentarmos e falhar, quanto se perde?

No fim, três apostas concretas para colocar em cima da mesa
independentemente da 0.0.6.

---

## Pistas em bruto

### 1. Estado emocional do gestor como dimensão de UX

Todas as métricas assumem um gestor racional a decidir com calma. Na
prática, quem abre a app às 23:00 depois de um dia mau precisa de
coisa diferente de quem abre às 09:00 com café. O Punho podia detectar
o momento (hora + últimas acções + tempo desde última sessão) e
mostrar um dashboard adaptado: modo "cabeça fria" (números todos) vs
modo "só o urgente" (uma acção, três frases).

**Ninguém no mercado o faz.** Explorável em prompts do dashboard sem
mexer no modelo de dados. Muito barato.

### 2. Benchmark anónimo entre empresas Punho

Hoje cada empresa é ilha: os números só fazem sentido contra a
própria história. Com 20-30 empresas na app, é possível dizer *"a tua
ocupação está no percentil 20 do sector — 60% dos teus pares estão
acima"* sem revelar nenhum dado individual.

Barreira: exige agregação server-side + política de privacidade
explícita + massa crítica (min. 5 empresas por segmento para
anonimizar). Alto valor pedagógico ("não vives numa bolha"), alto
requisito de escala.

### 3. Ensino ao colaborador, não só ao gestor

A app foi desenhada para o gestor. Mas o colaborador passa mais horas
na app: recebe clientes, faz reservas, cobra. O shell colaborador
podia ensinar operacional — como negociar prazos, como reconhecer
pedidos abusivos, como escalar reclamações. Micro-lições contextuais
de 20 segundos.

Alinha com "melhor gestão vem de melhor operação". Baixo custo se
reutilizar a Biblioteca de Alavancas com filtros.

### 4. Portal do cliente final (self-service)

O cliente é hoje um objecto passivo (nome + telefone). Um portal onde
ele se auto-serve — reserva, cauções, histórico, pagamento — reduz
carga administrativa do gestor e cria dependência positiva do
cliente.

Grande mudança de âmbito: mais uma superfície para manter, RGPD
adicional, autenticação de terceiros. Não vale a pena antes de o
gestor estar sólido.

### 5. Tempo do gestor como recurso auditável

A app já sabe quando abrimos, o que vemos, se decidimos. Podia
espelhar isso: *"esta semana viste 4× o Slide de Dinheiro sem
tomar decisões — o que estás à espera?"* — coach de meta-uso. Muito
poderoso pedagogicamente; assusta se for mal executado (paternalista).

Baixo custo técnico. Alto risco de tom.

### 6. Módulo de valorização e saída

Ninguém no software para PME fala em "quero vender a empresa daqui a
3 anos, quanto vale hoje?". Um simulador de valorização (múltiplos
sobre EBITDA/receita) + checklist de "coisas a limpar antes de
vender" seria formador — obriga o gestor a olhar para o negócio como
activo, não como emprego.

Nicho pequeno mas de altíssima receptividade quando chega. Requer
opinião editorial forte (que múltiplos, que ajustes).

### 7. Painel fiscal-de-bolso (IRC, IVA, TSU, retenções)

Para o gestor de PME português, a AT é o maior credor mensal. O
Punho hoje ignora. Um painel de "o Estado leva-me quanto e quando"
com semáforos de datas (IVA trimestral, IRC anual, retenções mensais)
teria adopção imediata.

Alinha com "ensinar gestão na prática". Requer manutenção anual das
tabelas. Complementa naturalmente o KPI de custo real com pessoal da
sprint 1 da 0.0.6.

### 8. Concorrência local visível

O gestor médio não sabe quantos concorrentes tem no raio de 5 km,
que preços praticam, que horários fazem. Dados públicos (Google Maps,
websites, Portal das Finanças) + benchmark anónimo entre Punhos
resolvem parcialmente.

Grande valor pedagógico ("não estás sozinho no mercado, e olha aqui
como te comparas"). Custo médio-alto de research + risco reputacional
se os dados de terceiros estiverem errados.

### 9. Sazonalidade e clima

Aluguer depende do tempo (chuva/sol), estação, feriados. A app
ignora. Uma correlação simples "próxima semana chuva prevista —
ocupação histórica em semanas chuvosas foi −40%" é actionable e
fácil de fazer com API pública (IPMA).

Baixo custo, alto valor de "coisa que ninguém faz". Directamente
alinhado com propósito educativo (mostra ao gestor variáveis fora do
controlo dele).

### 10. Post-mortem de decisões

Quando o gestor toma decisão (baixou preço, recusou lead, arquivou
máquina), a app hoje regista mas nunca revisita. Um post-mortem
mensal — "há 30 dias baixaste 10% no preço da Ana; o resultado foi
X" — é o loop de aprendizagem completo.

Depende de haver acções registadas com intenção declarada, coisa que
o Punho ainda não tem (só tem eventos operacionais). Custo médio,
altíssimo valor pedagógico. Fecha o *loop* que a Auditoria B apontou
como lacuna central.

### 11. Sucessão e continuidade

O gestor único é ponto único de falha para o negócio. E se ele não
estiver? Um "manual de operações vivo" dentro da app — como
funciona, onde estão as chaves, contactos críticos, procedimentos de
emergência — protege o negócio e obriga o gestor a articular.

Baixo custo técnico (é um bloco de conteúdo estruturado), altíssimo
valor pedagógico ("o teu negócio está preparado para durar sem ti?").
Também alinhado com Balanço de Comando que o roadmap já prevê ao fim
de um ano.

---

## Filtragem

| # | Pista | Propósito | Assimetria de mercado | Reversibilidade |
|---|---|---|---|---|
| 1 | Estado emocional / momento do dia | Alto | Alta (ninguém faz) | Total |
| 2 | Benchmark anónimo entre Punhos | Alto | Alta | Alta |
| 3 | Ensino ao colaborador | Alto | Média | Total |
| 4 | Portal do cliente final | Médio | Baixa (padrão do mercado) | Baixa |
| 5 | Tempo do gestor auditável | Alto | Alta | Média (risco tom) |
| 6 | Valorização e saída | Médio | Alta | Total |
| 7 | Painel fiscal-de-bolso | Muito alto | Média (Moloni-adjacente) | Total |
| 8 | Concorrência local | Alto | Alta | Média |
| 9 | Sazonalidade e clima | Alto | Muito alta | Total |
| 10 | Post-mortem de decisões | Muito alto | Muito alta | Alta |
| 11 | Sucessão e continuidade | Alto | Muito alta | Total |

Os três de fundo (propósito × assimetria × reversibilidade) que
saltam à vista: **10 (post-mortem), 7 (fiscal-de-bolso), 9 (clima)**.

Um outsider a considerar: **11 (sucessão)** — muito alinhado com o
Balanço de Comando que já vem no roadmap, custo baixíssimo, e
resposta clara à queixa comum "o meu negócio depende só de mim".

---

## Três apostas para colocar em cima da mesa

### Aposta A — Post-mortem de decisões (fecha o loop de aprendizagem)

**Porquê.** A Auditoria B apontou como *distância principal*: sem
loop de fecho, não há aprendizagem. As recomendações da app têm
"acção" e "medida", mas ninguém volta lá 30 dias depois para ver o
que aconteceu. Isto é o loop completo.

**O que é.** Cada recomendação aceite (ou acção manual do gestor:
mudou preço, arquivou máquina, cortou custo, contratou colaborador)
fica marcada com data + intenção declarada em 1 linha. 30 dias
depois a app abre-lhe *"decidiste isto — o resultado foi este; o que
aprendeste?"*. Um campo livre para a resposta, o histórico fica na
ficha do gestor.

**Investimento.** 1-2 sprints. Modelo `Decisao` novo, filtro de
sinais mensuráveis, tela de revisão semanal/mensal.

**Métrica de sucesso.** Nº de post-mortems completados por gestor
por mês. Valor esperado: dos gestores activos, 60% completam pelo
menos 1 post-mortem no primeiro mês. Se cair para <20% ao terceiro
mês, o formato falhou.

### Aposta B — Painel fiscal-de-bolso (o Estado como credor visível)

**Porquê.** Para o gestor de PME português a AT é o maior credor
mensal e a menos entendida. Nenhuma app faz isto bem no Punho vertical
(Moloni faz para facturação, não para "quanto tenho de pagar quando"
enquanto gestor). Adopção imediata; alinha com "ensinar gestão na
prática" — o gestor médio não sabe articular a diferença entre IRC
provisional e definitivo, entre TSU do trabalhador e da entidade
patronal.

**O que é.** Novo destino "Estado" na sidebar. Timeline anual das
obrigações fiscais (IVA trimestral 10 fev / 10 mai / 10 ago / 10 nov,
IRC pagamentos por conta jul/set/dez, IRS retenções mensais,
Segurança Social 20 do mês seguinte). Semáforo por proximidade.
Estimativa do valor a pagar em cada obrigação com base no que a app
já sabe (recebido, pago, colaboradores).

**Investimento.** 2-3 sprints. Requer tabelas fiscais mantidas
anualmente. Aproveita o motor de estimativas fiscais que a sprint 1
da 0.0.6 já introduz para salários.

**Métrica de sucesso.** Redução de tarefas "não paguei o IVA a
tempo" que os gestores reportam. Também: nº de vezes que o painel é
consultado ≥ 4× nos 10 dias antes de cada obrigação.

### Aposta C — Correlação clima × ocupação

**Porquê.** Ninguém faz e é directamente pedagógico: mostra ao gestor
uma variável fora do controlo dele que explica muito do que ele
atribui a "boa/má sorte". Custo técnico ridículo (API pública IPMA
grátis), efeito de "wow" alto na primeira vez que aparece uma
recomendação nova.

**O que é.** Recomendação nova no Slide 5 quando aplicável: *"nas
próximas 3 semanas está previsto tempo instável. Nas últimas 3
semanas do ano passado com clima parecido, a tua ocupação foi 35%
abaixo da média — considera antecipar promoção para reservas
antecipadas."* Também: card informativo no Slide 3 quando o clima
explica variação anómala ("esta semana −20% na ocupação, mas 4 dias
de chuva vs 1 no ano anterior — normal").

**Investimento.** 1 sprint. Integração com IPMA + histórico
climático + correlação simples com ocupação por semana.

**Métrica de sucesso.** Alertas climáticos que geram acção do gestor
(promoção antecipada, ajuste de preço) dentro de 48 h. Alvo: 30% dos
alertas em correlação forte convertem em acção.

---

## Recomendação

Se pudesse escolher **uma só** para arrancar no ciclo pós-0.0.6:
**Aposta A — Post-mortem de decisões.**

Fecha a lacuna central que a Auditoria B identificou (loop de
aprendizagem ausente). Transforma o Punho de "app que mostra bem" em
"app que ensina a decidir melhor". É o único diferenciador
pedagógico que **nenhum concorrente pode copiar sem repensar o
produto do zero** — as apps operacionais tratam decisões como
eventos, não como hipóteses testáveis.

A Aposta B (fiscal) é a mais defensiva e a mais óbvia comercialmente.
A C (clima) é o *hook* mais fácil de mostrar em vídeos e demos.

Escolhe com o Cesar qual vai à mesa para 0.0.7.
