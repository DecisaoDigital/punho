# Fontes das balizas de KPIs — investigação de referências

**Data da investigação:** 5 de Agosto de 2026
**Objectivo:** substituir limiares hoje inventados no código/documentação do Punho por balizas com fonte citável, aplicáveis (na medida do possível) a uma PME portuguesa de aluguer de máquinas/equipamento com 1-10 pessoas.

## Metodologia

Pesquisa web activa (múltiplas queries por indicador, várias fontes), com tentativa sistemática de chegar à fonte primária (relatório original, associação sectorial, norma contabilística, estudo académico) em vez de artigos que citam outros artigos sem origem rastreável. Sempre que possível, os documentos primários foram descarregados e o texto extraído (`pdftotext`) para citação exacta, em vez de confiar em resumos de motores de busca.

Foram **rejeitados** explicitamente: "regras de ouro" repetidas em cadeia por blogues de marketing/SaaS sem metodologia declarada (ex.: regra "72/20/8" de utilização de frota — aparece em dezenas de blogues, nenhum consegue apontar a publicação original; benchmarks de "conversão B2B" de agências de marketing sem amostra nem período declarados).

Foram **aceites com reserva** fontes de fornecedores de software ou agregadores de dados quando declaram metodologia verificável (nº de empresas/transacções, período, fonte dos dados) — sinalizado caso a caso.

Convenção de confiança:
- **Alta** — fonte primária com metodologia declarada, aplicável ao sector ou a sector estruturalmente semelhante.
- **Média** — fonte credível mas de geografia/sector diferente, ou metodologia parcialmente declarada.
- **Baixa** — fonte indirecta, amostra enviesada, ou aplicação por analogia distante.

---

## GRUPO A — indicadores hoje no código

### 1. Taxa de conversão de lead a cliente em aluguer de equipamento B2B

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| 1,9% | conversão (não especifica etapa) | Blog "Financial Models Lab" / "Heavy Equipment Rental KPIs" | financialmodelslab.com | Sem metodologia declarada, sem tamanho de amostra | Baixa |
| 4,9% (Construção & Engenharia); 2,8% (Real Estate) | conversão visita→lead (não lead→cliente) | Ruler Analytics, "Conversion Rate Benchmarks 2026" | ruleranalytics.com/blog/insight/conversion-rate-by-industry | Plataforma de marketing analytics, 110M+ sessões, 5M+ conversões, £33,8M+ spend rastreado, 13 sectores, ano 2026 (UK) | Média (mas mede a **etapa errada** do funil — ver nota) |
| "B2B managers should target 2-5%" lead-to-customer | conversão lead→cliente | Vários blogues de vendas (SPOTIO, Landbase, Tomba) citando-se mutuamente | — | Sem estudo original identificável — números repetidos em cadeia | Baixa/rejeitado |
| ~15-25% (win rate de oportunidades qualificadas) | conversão oportunidade→fecho | Referências informais a dados HubSpot/Salesforce sem link ao relatório original | — | Não foi possível chegar ao relatório-fonte da HubSpot/Salesforce citado | Baixa |

**Nota crítica:** existe uma confusão de funil generalizada nas fontes disponíveis. "Taxa de conversão" nos sites de marketing B2B mede tipicamente **visitante→lead** (ex.: Ruler Analytics), não **lead→cliente fechado** (o que está codificado no Punho). Não foi encontrada nenhuma fonte com metodologia declarada especificamente para "lead→cliente" no sector de aluguer de equipamento B2B. O valor "40% verde / 20% laranja" continua **sem fonte defensável**.

### 2. Taxa de utilização/ocupação de frota de aluguer de máquinas

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| Definições: "time (physical) utilization" e "financial (dollar) utilization" | conceitos, sem valor-baliza fixo | ARA (American Rental Association), "ARA Rental Market Metrics" (2011) | citado em internationalrentalnews.com e forconstructionpros.com; ARA não disponibiliza o PDF original em acesso livre | Norma de definição adoptada pela indústria de aluguer nos EUA | Alta (definição) / Não aplicável (não dá valor numérico) |
| ERA Market Report menciona "utilisation" apenas em texto narrativo por país (ex. Dinamarca, Noruega), sem publicar uma taxa média europeia de utilização física/financeira nos relatórios de acesso público | — | ERA (European Rental Association) x KPMG, "European Rental Market Report" 2023 e 2024 | erarental.org/wp-content/uploads/2024/11/ERA-Market-Report-2023.pdf ; bera-rent.be/.../ERA-x-KPMG_Market-Report-2024_Belgium.pdf (PDFs descarregados e verificados directamente, texto integral pesquisado) | Cobre 16-17 países europeus; relatório completo é pago (€1.200 p/ não-membros) — os excertos públicos não contêm a métrica pedida | Alta (confirma **ausência** do dado nos relatórios públicos) |
| ERA/IRN RentalTracker: "balanço de opinião" de +16% sobre utilização (não é taxa absoluta, é saldo de sentimento: % que reportou subida menos % que reportou descida) | pontos percentuais de saldo de opinião | ERA/IRN RentalTracker (inquérito bianual) | internationalrentalnews.com/news/rentaltracker-survey... | Sondagem de sentimento entre profissionais do sector, Europa, março 2024 | Média (é sentimento, não nível absoluto) |
| Regra "72% em aluguer / 20% em pátio pronto / 8% indisponível" | percentagem da frota | Repetida em dezenas de blogues (Quipli, Hapn, TARGIT, etc.) sem origem rastreável até publicação primária | — | Nenhuma fonte consegue apontar o estudo original | **Rejeitado** — cadeia sem origem |

**Conclusão:** os **conceitos** "physical/financial utilisation" estão bem estabelecidos (ARA nos EUA; a ERA usa terminologia próxima — "time utilisation"/"financial utilisation" — no seu relatório fundador de 2011, PDF descarregado e confirmado linha 511). Mas **não existe uma baliza numérica europeia publicamente citável**: o relatório ERA que teria esse dado é pago, e o "72/20/8" citado por fornecedores de software é uma regra sem origem rastreável. O "≥60% verde / ≥30% laranja" hoje no código **não tem fonte defensável**.

### 3. Tempo de resposta a lead / dias até "arrefecer"

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| Contactar em 5 min → 21× mais provável qualificar lead vs. 30 min; 100× mais provável obter contacto em 5 min vs. 30 min | odds ratio | Oldroyd, J.B., McElheran, K., Elkington, D. — "The Short Life of Online Sales Leads", **Harvard Business Review**, Vol. 89, nº 3, Março 2011 (estudo subjacente MIT/InsideSales.com, ~15.000 leads, ~100.000 tentativas de chamada) | hbr.org/2011/03/the-short-life-of-online-sales-leads (artigo primário confirmado) | Leads B2C/B2B online, EUA, dados pré-2011 | Média — é o estudo mais citado e rastreável até à fonte primária, mas geografia/sector muito distantes (leads online genéricos, não aluguer de equipamento B2B; dados têm 15 anos) |
| Contactar em ≤1h → quase 7× mais provável qualificar vs. esperar >1h | odds ratio | Mesmo estudo HBR 2011, análise de 2,24 milhões de leads | idem | idem | Média |
| Ligar no 1º minuto → +391% conversão | percentagem | Velocify, "The Ultimate Contact Strategy" (~2013, ~3,5M leads) | citado por voiso.com, ainora.lt (não foi encontrado o PDF original da Velocify em acesso livre) | Clientes de plataforma Velocify em sectores mortgage/insurance/education, ~2012 | Baixa — não é o sector, e o PDF fonte não foi verificado directamente |
| "5 dias" para uma lead arrefecer | dias | — | — | — | **SEM FONTE** — não foi encontrado nenhum estudo (nem sequer de metodologia fraca) que fixe especificamente "5 dias" como o ponto de arrefecimento de uma lead. A literatura de "speed to lead" mede minutos/horas na primeira resposta, não um prazo de dias até à lead "morrer". |

**Conclusão:** a literatura de "speed to lead" é robusta e a fonte primária (HBR 2011) foi confirmada e lida directamente, mas mede **minutos/horas para o primeiro contacto**, não "dias até a lead arrefecer". O valor "5 dias" hoje no código **não tem fonte defensável** — nem sequer por analogia distante, porque a escala de tempo da literatura (minutos) é ordens de grandeza diferente da escala usada no código (dias).

---

## GRUPO B — balizas de doc interna sem fonte

### 4. Runway / semanas de autonomia de tesouraria

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| Mediana: 27 "cash buffer days" (~4 semanas); quartil superior ≥62 dias (~9 semanas); quartil inferior ≤13 dias (~2 semanas) | dias de reserva de caixa (saldo ÷ saída diária média) | **JPMorgan Chase Institute**, "Cash is King: Flows, Balances, and Buffer Days" (2016) | jpmorganchase.com/content/dam/jpmc/jpmorgan-chase-and-co/institute/pdf/jpmc-institute-small-business-report.pdf | 597.000 pequenas empresas EUA, 470 milhões de transacções bancárias reais (não sondagem) | Média-Alta — metodologia muito robusta (dados transaccionais reais), mas geografia EUA e "buffer days" ≠ exactamente "semanas de runway" (mede reserva actual, não meses de despesas fixas) |
| Imobiliário/serviços com contratos: 47 "buffer days" (o mais alto entre sectores); restauração: 16 dias (o mais baixo) | dias | mesmo estudo JPMorgan Chase Institute | idem | Variação sectorial dentro dos EUA | Média |
| "3 a 6 meses de despesas" como reserva saudável | meses | SCORE (organização americana de mentoria a PME, afiliada à SBA) | citado em vários artigos sem link directo ao documento original do SCORE | Recomendação de aconselhamento, não estudo empírico | Baixa — é uma recomendação de práctica, não uma medição |
| "≥12 semanas confortável, <8 semanas alerta" (valor hoje na doc) | semanas | — | — | — | **SEM FONTE** directa — mas nota: 12 semanas ≈ 84 dias está acima até do quartil superior do estudo JPMorgan (62 dias), e 8 semanas ≈ 56 dias está também acima da mediana (27 dias). Se o JPMorgan Chase Institute for aceite como referência estrutural (mesmo sendo EUA), os limiares actuais do Punho são **claramente mais conservadores/exigentes** que a realidade observada em PME reais — o que pode ser deliberado (baliza de saúde, não de mediana observada) mas deve ser assumido explicitamente como tal. |

### 5. Margem bruta % em empresas de serviços/aluguer de equipamento

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| Gross margin 47,58%; EBITDA margin 13,23%; Net margin 2,32% (TTM, Q1 2026) | percentagem | **CSIMarket**, "Rental & Leasing Industry Profitability Ratios" | csimarket.com/Industry/industry_Profitability_Ratios.php?ind=913 | Metodologia confirmada por fetch directo: agregação de **empresas cotadas em bolsa**, dados de "earnings filings" trimestrais, últimos 5 anos, consolidados (não médias simples), ponderados por capitalização de mercado | Baixa-Média — metodologia declarada e verificável, mas universo são grandes empresas cotadas (ex.: United Rentals, Ryder, Herc Holdings), estrutura de custos muito diferente de uma PME de 1-10 pessoas |
| "60-75% gross margin" para negócios físicos de aluguer | percentagem | Blogues diversos (sharpsheets.io e similares) sem amostra nem fonte primária declarada | — | — | Baixa/rejeitado como número isolado, mas plausível como intervalo geral (o aluguer tem baixo COGS variável por definição contabilística, já que o "custo" principal é depreciação de activo fixo, não input variável) |
| "~60%" (valor hoje na doc) | percentagem | — | — | — | Parcialmente coerente com o intervalo de blogues (60-75%) e estruturalmente plausível (aluguer = baixo custo variável directo), mas **sem fonte primária que isole PME portuguesas do sector**. Ver secção 10 para uma alternativa real: os Quadros do Setor do Banco de Portugal têm rácios de rendibilidade por CAE 773, incluindo uma decomposição de custos, que **permitiria calcular uma margem sectorial real para Portugal** — não foi extraído o valor numérico exacto nesta investigação (dashboard interactivo, ver limitações). |

### 6. Ciclo de conversão de caixa (cash conversion cycle) — sector de aluguer

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---| ---|
| ~30-45 dias (benchmark genérico cross-industry) | dias | Citação a "APQC benchmark research" em blogues de CCC (calcmastery.com, centime.com) — não foi possível confirmar directamente no site da APQC | — | Não verificado na fonte primária | Baixa |
| ~32 dias (empresas públicas não-financeiras dos EUA, estimativa agregada) | dias | citado em blogues sem link à fonte primária | — | — | Baixa |
| **Nenhuma fonte específica para aluguer de equipamento** foi encontrada | — | — | — | — | — |
| "Duração líquida do ciclo de exploração" — conceito equivalente ao CCC, **calculado por CAE pelo Banco de Portugal** nos Quadros do Setor (combina prazo médio de recebimentos + prazo médio de rotação de inventários − prazo médio de pagamentos) | dias | Banco de Portugal, Central de Balanços, Estudo 36 "Quadros do setor e quadros da empresa e do setor", Fevereiro 2019 (Secção "Atividade", Figura I.3.12) | bportugal.pt/publicacao/estudo-da-central-de-balancos-estudo-36-quadros-do-setor-e-quadros-da-empresa-e-do-setor | Nomenclatura portuguesa oficial, disponível por CAE até 5 dígitos (773/7732), universo censitário (IES) | **Alta** — existe uma fonte portuguesa, gratuita, por CAE, que mede exactamente este conceito. O valor numérico específico para CAE 773 não foi extraído nesta investigação (requer consulta interactiva ao dashboard QS, ver limitações), mas a **existência e metodologia da fonte estão confirmadas**. |
| "15-30 dias saudável, >60 dias alerta" (valor hoje na doc) | dias | — | — | — | **SEM FONTE** directa, mas ordem de grandeza plausível face aos benchmarks genéricos cross-industry (30-45 dias). Recomenda-se substituir por consulta real ao QS do Banco de Portugal para CAE 773 (ver Secção 10). |

### 7. Margem de segurança sobre o ponto crítico de vendas (break-even)

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| >20% considerado saudável; <10% considerado perigoso | percentagem | Conceito de contabilidade de gestão (CVP analysis) — citado de forma consistente por Corporate Finance Institute, AccountingVerse, GoCardless, Xero | corporatefinanceinstitute.com/resources/accounting/margin-of-safety-formula | É um **conceito de manual de contabilidade de gestão** (ex.: Garrison/Noreen, "Managerial Accounting"), não um estudo empírico com amostra — os "20%" e "10%" são heurísticas didácticas amplamente repetidas, sem origem empírica rastreável a um estudo com dados reais | Baixa-Média — é uma convenção pedagógica consistente entre múltiplas fontes de contabilidade (não é uma cadeia de blogues aleatórios), mas não é uma medição de sector nenhum |
| "<15% perigoso" (valor hoje na doc) | percentagem | — | — | — | Está **dentro da faixa de heurísticas** encontradas (entre o "perigoso <10%" e o "saudável >20%"), mas não corresponde exactamente a nenhuma fonte — é um ponto intermédio inventado dentro de um intervalo real. Recomenda-se alinhar com a convenção mais citada: <10% perigoso, ≥20% saudável, e tratar 10-20% como zona intermédia. |

### 8. Concentração de receita — limiar de risco por cliente único

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| 10% ou mais de um único cliente → obrigação de divulgação em relatórios financeiros | percentagem (limiar regulatório, não "risco" per se) | **FASB ASC 280-10-50-42** ("Segment Reporting" — major customer disclosure), EUA | dart.deloitte.com/USDART (Deloitte Accounting Research Tool, referência à norma) | Norma contabilística obrigatória para empresas cotadas nos EUA que reportam sob US GAAP — não é uma norma portuguesa nem um "limiar de risco de negócio", é um limiar de **materialidade para divulgação** | Média — é uma fonte primária real (norma contabilística), mas mede divulgação obrigatória, não risco de concentração propriamente dito, e não é a norma aplicável em Portugal (que segue SNC, não US GAAP) |
| Zona de cautela 10-20%; zona de alto risco >20%; recusa de compra >30% (M&A/valuation) | percentagem | Blogues de M&A/valuation (Beancount.io, Website Closers, Projectworks) sem estudo académico citado, mas consistentes entre si em ordem de grandeza | — | Contexto de **venda de empresa** (valuation em M&A), não de gestão operacional do dia-a-dia | Baixa — consistência entre fontes não substitui metodologia declarada; é "sabedoria de mercado" de consultores de M&A |
| "25%" (valor hoje na doc) | percentagem | — | — | — | Está dentro da "zona de alto risco" mencionada pelos blogues de M&A (>20%), mas não tem fonte primária. A referência mais defensável estruturalmente é o limiar de 10% da ASC 280 (ainda que seja um limiar de divulgação, não de risco), que sugere que 25% já seria considerado alto por qualquer padrão encontrado. |

### 9. Peso dos custos de estrutura (overhead/SG&A) sobre a receita

| Valor | Unidade | Fonte | URL | Amostra/Contexto | Confiança |
|---|---|---|---|---|---|
| Serviços: 38,98% mediana; Transporte/Comunicações/Utilities: 15,20%; Construção: 10,79% (nota: não há linha específica "aluguer") | percentagem SG&A/vendas | SAI Books, "SG&A Benchmarks" — fonte primária declarada como agregação de dados de **IRS Corporate Sourcebook / Risk Management Association**, mas não foi possível confirmar directamente (produto pago, não acedido o relatório completo) | saibooks.com/product-category/sga-2020 | EUA, empresas de vários portes agregadas por sector | Baixa — não foi possível verificar a fonte primária declarada (RMA/IRS) por estar atrás de paywall; e o conceito de "SG&A" separado de COGS **não existe da mesma forma na contabilidade portuguesa (SNC)** — ver nota abaixo |
| Nenhuma mediana sectorial portuguesa específica de "overhead/SG&A %" foi encontrada | — | — | — | — | **SEM FONTE directa**, mas ver nota metodológica: |

**Nota metodológica importante:** a contabilidade portuguesa (SNC — Sistema de Normalização Contabilística) não separa "SG&A" de "COGS" da forma como o US GAAP o faz. O Banco de Portugal, nos Quadros do Setor, usa antes "Fornecimentos e Serviços Externos (FSE)" e "Gastos com o Pessoal" como rubricas na "Repartição dos rendimentos" (ver Secção 10) — que juntas se aproximam do conceito de overhead, mas incluem também custos directos de exploração (ex.: combustível de máquinas alugadas, manutenção) que nos EUA cairiam em COGS. Uma comparação directa com benchmarks americanos de "SG&A %" arriscaria comparar categorias contabilísticas diferentes. **Recomenda-se não importar o número americano** e, se necessário um valor, derivá-lo da decomposição real do Banco de Portugal por CAE 773 (rubrica "Repartição dos rendimentos", Figura I.3.10 do Estudo 36).

---

## GRUPO C — Ponto 10: existe fonte portuguesa por CAE?

### **Resposta directa: SIM — Banco de Portugal, Central de Balanços, "Quadros do Setor" (QS) e "Quadros da Empresa e do Setor" (QES)**

Esta é, de longe, a fonte mais decisiva encontrada em toda a investigação. Foi confirmada por leitura directa do documento metodológico primário (PDF descarregado e processado, 48 páginas úteis):

> **Banco de Portugal**, *Estudos da Central de Balanços n.º 36 — "Quadros do setor e quadros da empresa e do setor"*, Fevereiro 2019.
> https://www.bportugal.pt/publicacao/estudo-da-central-de-balancos-estudo-36-quadros-do-setor-e-quadros-da-empresa-e-do-setor
> Acesso interactivo: https://www.bportugal.pt/page/quadros-da-empresa-e-do-setor (nota: apresentou HTTP 403 a acesso automatizado nesta investigação — provável protecção anti-bot, não paywall; o documento metodológico confirma acesso gratuito)

#### Características exactas confirmadas no documento (não inferidas):

| Característica | Detalhe confirmado |
|---|---|
| **O que cobre** | 9 famílias de rácios: (1) Estrutura do activo, (2) Fontes de financiamento (inclui autonomia financeira = capital próprio / activo total), (3) Composição dos financiamentos obtidos, (4) Repartição dos rendimentos (fornecedores/pessoal/bancos/Estado/autofinanciamento — proxy de estrutura de custos), (5) Liquidez geral e reduzida, (6) **Actividade** — prazo médio de recebimentos, prazo médio de pagamentos, prazo médio de rotação de inventários, e **duração líquida do ciclo de exploração (= cash conversion cycle)**, (7) Financiamento (capacidade de EBITDA para cobrir gastos de financiamento), (8) **Rendibilidade** (inclui decomposição da rendibilidade dos capitais próprios), (9) Indicadores de risco: % empresas com EBITDA negativo, % com gastos de financiamento > EBITDA, % com capital próprio negativo, % com resultado líquido negativo |
| **Granularidade CAE** | Até **subclasse (5 dígitos)** da CAE-Rev.3 sempre que o nº de empresas o permita; sobe automaticamente para classe (4 díg.) → grupo (3 díg.) → divisão (2 díg.) → secção (1 letra) quando os critérios de confidencialidade não são cumpridos. **CAE 77320** (aluguer de máquinas para construção) e **CAE 773** (aluguer de outras máquinas e equipamentos) são combinações válidas no sistema. |
| **Critério de confidencialidade** | Um agregado só é divulgado se tiver **≥3 empresas** a reportar. Quartis completos exigem **≥11 empresas**; entre 6-10 empresas só é dada a mediana (Q2); <6 empresas não têm informação de quartis. Isto significa que para CAE muito específicos (ex.: 77320 numa região pequena) pode ser necessário subir para o grupo 773 ou a divisão 77. |
| **Classe de dimensão** | Cruza com 6 classes: Grandes, Médias, Pequenas, Micro, "Micro+Pequenas+Médias" e "Todas". Classificação segue a Recomendação CE 2003/361/CE — uma empresa Punho típica (1-10 pessoas) cai em **Microempresa** (<10 pessoas, <2M€ de volume de negócios/balanço). |
| **Desfasamento temporal** | Anual. Dados de 2017 foram publicados em finais de Novembro de 2018 (~11 meses de atraso). O sistema está activo e actualizado — pesquisa confirmou dados de rendibilidade nacional (EBITDA/activo = 9,4%) e autonomia financeira (45,1%) já referentes ao **3º trimestre de 2024**, o que sugere também alguma publicação trimestral agregada (via GEE/ITENF) complementar à anual mais granular por CAE. |
| **Fonte dos dados** | **IES — Informação Empresarial Simplificada**, reporte obrigatório desde 2007 (DL 8/2007), partilhado entre Ministério das Finanças, Ministério da Justiça, INE e Banco de Portugal. **Cobertura censitária** (não amostra) de todas as sociedades não financeiras — mas **exclui ENI (empresários em nome individual)**, que representam ~2/3 das empresas portuguesas em número mas só ~5% do volume de negócios. Se uma PME de aluguer for constituída como Lda/Unipessoal, está incluída; se for ENI puro, não está. |
| **Acesso e custo** | **Gratuito.** QS (Quadros do Setor) — consulta pública geral, sem necessidade de autenticação, disponível desde 2006. QES (Quadros da Empresa e do Setor) — gratuito para as próprias empresas, com autenticação (credenciais Portal das Finanças), permite comparar a empresa concreta com o agregado do seu sector/dimensão; disponível desde 2010. |
| **Formato** | Dashboards interactivos exportáveis para Excel, mais um relatório descarregável com o conjunto alargado de indicadores. Mais de 5.000 combinações sector×dimensão disponíveis por ano. |

**Limitação desta investigação:** não foi possível extrair nesta sessão o **valor numérico exacto actual** dos rácios para CAE 773/77320 (ex.: qual é a mediana real do ciclo de conversão de caixa ou da margem EBITDA para "aluguer de outras máquinas e equipamentos" em Portugal hoje) — o acesso ao dashboard interactivo `bportugal.pt/page/quadros-da-empresa-e-do-setor` devolveu HTTP 403 a acesso automatizado (`WebFetch`), o que é consistente com protecção anti-bot de um site institucional, não com uma barreira de pagamento (o documento metodológico primário confirma acesso público gratuito). **Próximo passo recomendado:** consultar manualmente o dashboard (browser normal) para CAE 77320/773, classe "Microempresas", e extrair os valores reais de rendibilidade, ciclo de exploração e autonomia financeira — isto substituiria de facto os números hoje inventados por números nacionais reais, por sector e por dimensão de empresa.

#### Outras fontes portuguesas verificadas (secundárias face ao Banco de Portugal):

| Fonte | O que oferece | Granularidade CAE | Gratuito? | Confiança/nota |
|---|---|---|---|---|
| **INE — Sistema de Contas Integradas das Empresas (SCIE)** | Rácios económico-financeiros (produção, VN, pessoal, VAB, resultado líquido, activo corrente, solvência, autonomia financeira) | Até subclasse (5 díg.) segundo pesquisa, mas estrutura de publicação histórica referenciada usa 23 sectores CAE-Rev.2.1 (mais agregado) | Sim | Média — usa a **mesma fonte primária** (IES) que o Banco de Portugal, mas o produto público self-service é menos desenvolvido/interactivo do que o do BdP para comparação empresa-a-empresa; não foi confirmado se está tão actualizado quanto o QS/QES |
| **GEE / DGE (agora Direção-Geral da Economia, `estatistica.dgeconomia.gov.pt`)** | Dashboard "Estatísticas Setoriais" — nota: **o domínio antigo `gee.gov.pt` foi descontinuado/redireccionado**, confirmado por esta investigação (HTTP 404 na estrutura antiga de URLs, redirecionamento activo para `estatistica.dgeconomia.gov.pt`) | Apenas **Divisão CAE Rev.3 (2 dígitos)** desde 2021 — portanto CAE 77 inteiro, sem descer a 773/77320 | Sim | Baixa para o caso específico do Punho — granularidade insuficiente (2 dígitos mistura aluguer de veículos, de equipamento informático e de máquinas todos juntos) |
| **Informa D&B** — Barómetro e "Estudos Setores Portugal" | Estudos sectoriais anuais (~56/ano), dados de dinâmica empresarial (constituições/dissoluções), rácios financeiros e principais empresas por sector | Não confirmado a que nível de CAE (produto comercial) | **Não** — produto pago, PDF de exemplo (construção) confirma existência mas não o conteúdo dos rácios | Baixa/não verificado — não foi possível confirmar conteúdo exacto sem acesso pago |
| **IAPMEI — PME Líder / PME Excelência** | Indicadores de rendibilidade (ROE 23,8%, EBITDA/Activo 21,2% para cohort 2022) | Não é por CAE, é por empresas certificadas | Dados agregados divulgados gratuitamente em notícias, ferramenta de qualificação paga/condicionada | Baixa — amostra **enviesada por construção**: só entram empresas que já cumprem critérios de solidez financeira para a certificação, não é representativa da média do sector |

**Conclusão do Ponto 10:** a resposta é inequivocamente **sim, existe fonte portuguesa fiável por CAE** — os **Quadros do Setor e Quadros da Empresa e do Setor do Banco de Portugal** são gratuitos, censitários (não amostra), vão até 5 dígitos de CAE quando o nº de empresas permite, cobrem exactamente os rácios que o Punho precisa (rendibilidade, autonomia financeira, ciclo de conversão de caixa via "duração líquida do ciclo de exploração", liquidez, risco), e têm um desfasamento temporal de cerca de 1 ano para os dados anuais mais granulares por CAE. Isto muda de facto a estratégia do produto: em vez de balizas "emprestadas" de sectores/países diferentes, o Punho pode oferecer comparação com a mediana e quartis reais do sector CAE 773/77320 em Portugal — a única limitação prática é que a extracção dos valores numéricos actuais exige consulta manual ao dashboard (não foi possível via scraping automatizado nesta sessão, por bloqueio anti-bot, não por ser pago).

---

## SEM FONTE — resumo dos indicadores sem base defensável

| # | Indicador | O que foi tentado | Estado |
|---|---|---|---|
| 1 | Taxa de conversão lead→cliente aluguer B2B, "≥40%/≥20%" | Múltiplas pesquisas sobre conversão B2B, equipamento pesado, aluguer; encontrados números de 1,9% a "2-5%" sem consenso nem metodologia aplicável à etapa exacta (lead→cliente, não visita→lead) | **SEM FONTE** |
| 2 | Utilização de frota "≥60%/≥30%" (valor numérico, não o conceito) | ERA Market Report 2023 e 2024 descarregados e pesquisados por texto integral — não contêm a métrica; relatório completo com esse dado é pago (€1.200); regra "72/20/8" sem origem rastreável | **SEM FONTE** (conceito tem fonte — ver Secção 2 — o valor numérico não) |
| 3 | "5 dias" até lead arrefecer | Literatura de speed-to-lead (HBR 2011, Velocify) mede minutos/horas de primeira resposta, não dias até "morrer" a lead; nenhuma fonte usa essa escala de tempo | **SEM FONTE** |
| 4 | "≥12 semanas confortável / <8 alerta" runway | JPMorgan Chase Institute dá dados reais mas em ordem de grandeza distinta (mediana 27 dias ≈ 4 semanas); SCORE dá "3-6 meses" sem estudo empírico ligado | **SEM FONTE** directa (existem referências estruturais mas nenhuma bate certo com os valores exactos hoje no código) |
| 6 (parcial) | "15-30 dias saudável / >60 alerta" CCC específico de aluguer | Nenhum benchmark de CCC específico para aluguer de equipamento encontrado (só cross-industry genérico ~30-45 dias) | **SEM FONTE** específica de sector (mas ver Ponto 10 — fonte portuguesa por CAE existe para calcular isto de raiz) |
| 7 | "<15% perigoso" margem de segurança | É um valor intermédio dentro do intervalo pedagógico 10-20% encontrado em manuais de contabilidade de gestão, mas não corresponde a nenhuma fonte específica | **SEM FONTE** exacta (mas dentro de intervalo plausível) |
| 8 | "25%" concentração de receita | Blogues de M&A convergem em torno de 20-30% como zona de risco, mas sem estudo académico; a única norma real (ASC 280, 10%) é de outro país e mede divulgação, não risco | **SEM FONTE** primária (mas ordem de grandeza tem suporte indirecto) |
| 9 | Peso de overhead/SG&A % sobre receita — mediana sectorial | Fonte encontrada (SAI Books/RMA) está atrás de paywall e não é directamente comparável à contabilidade portuguesa (SNC não separa SG&A de COGS da mesma forma) | **SEM FONTE** aplicável directamente — recomenda-se derivar do Banco de Portugal (Ponto 10) em vez de importar número americano |

---

## Fontes primárias descarregadas e verificadas nesta investigação

Para memória futura (evita repetir trabalho):
- `Estudo 36 — Quadros do Setor` (Banco de Portugal, 2019) — PDF de 48 páginas, texto extraído e lido integralmente.
- `ERA Market Report 2023` (ERA x KPMG) — PDF de 48 páginas, pesquisado por texto integral.
- `ERA x KPMG Market Report 2024 (edição Bélgica)` — PDF de 21 páginas, pesquisado por texto integral.
- `The European Equipment Rental Industry 2011` (ERA) — PDF fundador com definições de "time utilisation"/"financial utilisation", texto extraído.
- `hbr.org/2011/03/the-short-life-of-online-sales-leads` — artigo primário confirmado (Oldroyd, McElheran, Elkington, HBR Março 2011).
- Confirmado: `gee.gov.pt` está descontinuado, redirecciona para `estatistica.dgeconomia.gov.pt` (Direção-Geral da Economia) — útil para futuras pesquisas, evita perder tempo no domínio antigo.
