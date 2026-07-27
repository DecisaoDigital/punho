# Punho — guião do percurso do primeiro empresário

> Ficheiro vivo. Registo ecrã-a-ecrã da conversa com o Cesar sobre o
> que a app pede/mostra ao empresário no arranque, e como deve ser
> reformulada para que o resultado visual + a coerência com os KPIs
> seja o que se pretende.
>
> Método: o Cesar percorre a app (real ou virtualmente) e pergunta;
> este ficheiro regista a decisão de design (não a implementação).
> Prompts para o Code condensam-se depois numa sprint dedicada quando
> houver massa crítica.

## Regras deste ficheiro

- Cada entrada tem: **Ecrã / momento**, **Estado hoje**, **Decisão**,
  **Racional em 1-2 frases**, **Impacto em KPIs** quando aplicável.
- Nada é implementado directamente a partir deste doc. Vira prompt
  para o Code num segundo momento.
- Se uma decisão contradiz o `DECISOES_E_ROADMAP_VIVO.md`, marcar como
  **substitui**.

---

## Decisão 1 — A pergunta da forma jurídica é a raiz semântica dos KPIs

**Ecrã / momento:** onboarding, ordem das primeiras perguntas.

**Estado hoje:** o onboarding pede primeiro o nome do responsável, o
nome da empresa e o cargo (gestor/colaborador) antes de chegar à forma
jurídica (passo 4 do fluxo gestor actual, combinado com o NIF). A
forma jurídica é tratada como campo de identidade, não como
condicionador de cálculo.

**Decisão:** a forma jurídica é **a primeira pergunta com impacto em
KPIs**, e o desenho do sistema tem que a tratar como raiz. Ela decide
o esqueleto fiscal e contabilístico de todas as métricas financeiras
posteriores.

**Racional (Cesar):** "pode não ser importante agora, mas afecta". O
Claude respondeu inicialmente que a primeira era o nº de
colaboradores — corrigiu-se depois de perceber que estava a olhar
para o estado *actual* da app, não para o desenho *pretendido*.

**Impacto em KPIs** (a implementar quando os motores de cálculo forem
sensíveis à forma jurídica):

- **Custo real com pessoal** (sprint 1 v0.0.6, Slide Custos): TSU
  patronal 23,75% só sobre colaboradores. Se ENI, não se aplica ao
  próprio empresário (desconta como TI, 21,4% sobre rendimento
  relevante). Em Lda, o sócio-gerente pode ser TI ou trabalhador
  dependente — depende.
- **Resultado provisório** (Slide Dinheiro): em Lda é lucro antes de
  dividendos (dinheiro que fica na empresa). Em ENI é rendimento
  pessoal (o empresário leva para casa). Recomendações "guarda X para
  impostos" têm % diferente.
- **IRS vs IRC** (painel fiscal-de-bolso, Aposta B da auditoria fora
  da caixa): ENI paga IRS categoria B (simplificado até 200 k€ ou
  contabilidade organizada); Lda paga IRC (17% até 50 k€ lucro
  tributável, 21% acima). Datas e cálculos distintos.
- **IVA**: ENI abaixo do limiar de isenção (13 500 € em 2026) não
  cobra nem deduz; Lda cobra sempre. O KPI "IVA a pagar" só se aplica
  ao regime normal.
- **"O próprio empresário conta como colaborador?"**: em ENI, não
  (contradição jurídica). Em Lda, sim se receber vencimento formal. O
  contador de colaboradores hoje mistura os dois casos.
- **Regime simplificado vs contabilidade organizada**: em regime
  simplificado, o "custo" é presumido (75% do rendimento para
  prestação de serviços) — não faz sentido pedir despesas detalhadas
  nem calcular margem bruta real. Metade dos KPIs da Auditoria A
  ficam sem aplicação.

**Consequências operacionais para o Code (quando for sprint):**

1. `legalForm` (que já existe em `OnboardingData`) passa a ler-se pelo
   motor de KPIs, não só pela UI dos campos. Introduzir um serviço
   `RegimeFiscal` que devolve à app "sou ENI simplificado", "sou ENI
   organizado", "sou Lda IRC", etc. — e cada KPI consulta este
   serviço para decidir se se aplica e como.
2. **A pergunta da forma jurídica deve subir na ordem do onboarding**
   — proposta: passar a ser a **primeira pergunta a seguir ao nome do
   responsável e ao nome da empresa**, ainda antes do cargo, e desde
   já visualmente enquadrada como "esta escolha vai afinar o resto da
   app à tua realidade fiscal".
3. Cada KPI que hoje calcula igual para todos passa a ter, na
   documentação interna, uma tabela "aplicabilidade por regime". Os
   que não se aplicam ao regime do gestor **ficam ocultos** em vez de
   aparecerem a "0 €" ou "Por apurar" — mostrar KPIs irrelevantes é
   ruído pior que ausência.

**Estado:** decisão fechada. Vai para uma sprint dedicada de "motor
fiscal + reordenação do onboarding" quando o Cesar decidir. Registada
antes do painel fiscal-de-bolso (Aposta B) porque é o pré-requisito
dele.

---

<!-- Próximas decisões abaixo, à medida que forem discutidas. -->
