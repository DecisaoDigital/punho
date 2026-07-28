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

## Decisão 2 — Sidebar enxuta e agrupamento de "Empresa"

**Ecrã / momento:** sidebar do gestor.

**Estado hoje:** a sidebar da v0.0.5 tem `Gestão` (dashboard), `Máquinas`,
`Clientes`, `Reservas`, `Finanças`, `Frota` (condicional) e `Tarefas`.
Botão do avatar no fundo abre tela de conta. Nome `Gestão` é vago;
`Frota` é jargão.

**Decisão:** sidebar de **7 destinos sempre fixos**, agrupando
tudo o que é config/administração num único destino `Empresa` com
abas. O botão Tarefas está sempre presente — quando há pendências
ganha um badge (número ou ponto), quando não há aparece só com o
ícone e o rótulo neutros. Nunca aparece/desaparece — sidebar
estável, sem "saltos" para o olho.

**Sidebar final** (aprovada pelo Cesar):

1. **Painel** — dashboard dos 5 slides (ex-`Gestão`).
2. **Máquinas** — inventário do parque.
3. **Reservas** — calendário, uso diário.
4. **Clientes** — base de clientes **+ leads** no mesmo destino
   (funil comercial consultável sistematicamente). Destino próprio,
   não aba de Empresa — o Cesar defendeu que a consulta é frequente
   demais para ficar enterrada.
5. **Colaboradores** — anteriormente `Funcionários`; renomeado para
   consistência com o vocabulário do código.
6. **Empresa** — agregador de config/administração, com abas:
   - **Dados** (nome, forma jurídica, NIF, morada, contactos)
   - **Regime fiscal** (categoria B / IRC, regime IVA, simplificado
     vs contabilidade organizada — condicionador dos motores, ver
     Decisão 1)
   - **Custos fixos** (renda, seguros, comunicações — declaração
     mensal recorrente)
   - **Veículos** (ex-`Frota` / `VehiclesPage`, migrada para dentro)
   - **Finanças** (movimentos — despesas, recebimentos, cobranças)
   - **Estado** (timeline de obrigações fiscais IVA/IRC/TSU/IRS,
     futura Aposta B)
7. **Tarefas** — **sempre visível**. Badge (número/ponto) quando há
   pendências; sem badge quando vazio. Nunca desaparece.

**Perfil** (avatar no canto) é **popup**, não destino. Contém:
identidade da conta (nome + email), chip
`SESSÃO ACTIVA` / `MODO DEMONSTRAÇÃO`, botão `Terminar sessão`.
Dados da empresa e convites WhatsApp vivem em `Empresa`.

**Racional (Cesar):** "quanto menos botões na barra lateral melhor,
há coisas que se configuram uma vez e depois não se mexem tão cedo".
Barra 88 dp com scroll é fricção; enxutar até 6 obriga a distinguir
o que é operacional (Painel, Máquinas, Reservas, Colaboradores) do
que é administrativo (Empresa).

**Debates registados:**

- O Claude defendeu `Finanças` como destino próprio por ser operação
  diária. O Cesar sobrepôs: prefere fricção adicional de uma aba
  extra do que sidebar longa. Trade-off aceite explicitamente.
- Sobre `Clientes`: houve mal-entendido intermédio (o Cesar aparentou
  querer enterrar em Empresa; a versão final aprovada é destino
  próprio na sidebar, com base + leads juntos).

**Consequências operacionais para o Code (quando for sprint):**

1. **Renomear**: `Gestão` → `Painel`; `Frota` → `Veículos`;
   `Funcionários` → `Colaboradores`. Grep global em `app_shell.dart`,
   testes, screenshots, docs, prompts.
2. **Novo destino `Empresa`** com `TabBar` + `TabBarView`. O
   `EmpresaDadosForm` da sprint 1 v0.0.6 vive na tab `Dados`.
3. **Migrar destinos existentes para tabs de Empresa**:
   - `VehiclesPage` → tab `Veículos`
   - Ecrã de finanças (despesas + recebimentos) → tab `Finanças`
   - Bloco de custos fixos (hoje só no onboarding) → tab
     `Custos fixos` (agora editável)
   - Tab `Regime fiscal` — placeholder na sprint 1 v0.0.6, com o
     enum já em uso via Decisão 1
   - Tab `Estado` — placeholder na sprint 1 v0.0.6, implementado
     quando arrancar a Aposta B

   **`ClientsPage` NÃO migra** — mantém-se como destino próprio da
   sidebar. Recebe passe adicional para acomodar leads (se ainda não
   estivessem juntas), mas fica onde está.
4. **`Colaboradores` mantém-se como destino próprio** — apesar do
   componente de config, o gestor edita fichas e vê vendas do mês
   por colaborador com frequência (Frente C+D da sprint 1 v0.0.6).
   Enterrá-lo em Empresa mataria a Frente C.
5. **Perfil vira popup**, não navegação. O que a Frente B da sprint 1
   v0.0.6 estava a preparar como `ContaScreen` (com dados da empresa
   dentro) **precisa de ser refactorizado antes de arrancar**: os
   dados da empresa saem do popup e vão para a tab `Dados` de
   `Empresa`; o convite WhatsApp migra também para dentro de
   `Empresa` (por ser acto administrativo). No popup Perfil só fica
   identidade pessoal + terminar sessão.

**Impacto no plano da sprint 1 v0.0.6:**

- Frente A (Boas-vindas + MaisDados) — sem alterações.
- Frente B (ex-ContaScreen unificada) — **muda de arquitectura**:
  passa a criar o destino `Empresa` com tabs, e o popup Perfil
  minimalista no avatar.
- Frente C (modelo contratual do funcionário) — sem alterações,
  mas o destino da `CollaboratorsPage` continua a chamar-se
  `Colaboradores` na sidebar.
- Frente D (KPI custo real com pessoal) — sem alterações.

**Estado:** decisão fechada. O prompt
`punho_v006_sprint1_boas_vindas.md` tem que ser reescrito na Frente
B antes de ir ao Code.

---

## Decisão 3 — Rótulo da app sempre visível

**Ecrã / momento:** todos os ecrãs da app depois do login.

**Estado hoje (v0.0.4/v0.0.5):** a app não se identifica visualmente
em lado nenhum permanente. O gestor abre e não sabe se é a v0.0.4
ou v0.0.5, nem — num tablet partilhado — que aplicação está a
correr. O nome da empresa também não é reforçado.

**Decisão:** rótulo permanente no **canto inferior esquerdo**, sempre
visível em cima de qualquer conteúdo:

```
Punho v0.0.5 · Nome da Empresa
```

- **Cor**: letras brancas com sombra fina (contraste sobre fundos
  claros ou escuros).
- **Tamanho**: mínimo 11 sp (legível em telemóvel; escala para
  12-13 sp em tablet/PC).
- **Posição**: canto inferior esquerdo, `SafeArea` respeitada. Em
  landscape com sidebar 88 dp, o rótulo vive **por cima da sidebar**
  no canto — sidebar termina antes do fundo, o rótulo sobrepõe.
- **Zero interação**: não é botão, não abre nada. É identidade.

**Racional (Cesar, testando v0.0.4):** "não tem identificação da app,
gostaria de ter sempre presente no canto inf esq da app, por cima da
barra (letras brancas para visibilidade) tamanho mínimo legível em
telemóvel". Além de branding, protege o gestor num tablet partilhado
e ajuda ao suporte remoto ("qual é a versão que estás a ver?").

**Consequências operacionais:**

1. Novo widget `AppLabelBadge` em `lib/core/branding/` que compõe
   `nome + versão + empresa` a partir de `PackageInfo` +
   `OnboardingData.companyName`.
2. Injectado no `Scaffold` principal (via `Positioned` dentro de um
   `Stack` no root, ou como `bottomNavigationBar` transparente).
3. Widget test: aparece em portrait e landscape sem sobrepor conteúdo
   crítico (verificar em Dashboard, `TarefasPage`, `ClientsPage`).
4. Se `companyName == null` (modo demo antes de onboarding), rótulo
   fica só `Punho v0.0.5 · Modo demonstração`.

**Estado:** decisão fechada. Sprint dedicada de "polimento visual"
ou parte do bug bundle da próxima release.

---

## Decisão 4 — PIN de segurança / biometria no arranque

**Ecrã / momento:** abertura da app quando já existe sessão Supabase
guardada (o caso normal depois do primeiro login).

**Estado hoje:** a sessão é persistida pelo `supabase_flutter` e a app
abre directamente na página principal sem verificar identidade
localmente. **Vulnerabilidade real** num tablet partilhado — qualquer
pessoa que pegue no dispositivo vê dinheiro, cauções, dados fiscais
dos colaboradores.

**Decisão:** implementar cadeado local com **biometria por defeito e
PIN 4-6 dígitos como fallback**. Configurável pelo gestor (opt-in
com nudge forte na primeira sessão pós-onboarding).

**Modelo mental:**

- Após onboarding, ao chegar à app pela primeira vez, o gestor vê
  card no dashboard: *"Este tablet é partilhado? Activa o
  desbloqueio biométrico para proteger o teu negócio."* Botão
  `Activar` abre o setup.
- Setup: escolhe **biometria** (se dispositivo suportar) e cria PIN
  4-6 dígitos como fallback obrigatório (se biometria falhar por
  qualquer razão — sensor sujo, dispositivo sem impressão).
- Se recusar, fica sem cadeado — decisão dele, mas fica com uma
  pequena badge âmbar na Tarefas *"Desbloqueio biométrico não
  activado"* que pode adiar sem limite.

**Comportamento em runtime:**

1. **Ao abrir a app** com sessão guardada: pede biometria (bottom
   sheet nativo Android) OU PIN se falhar/cancelar.
2. **Timeout de inactividade configurável** (defaults: 15 min sem
   toque → bloqueia). Em Definições/Empresa/Regime, gestor pode
   mudar para 5 min, 1 h, ou "nunca".
3. **3 tentativas de PIN falhadas** → bloqueio total do cadeado.
   Não é logout (a sessão continua guardada), mas exige
   **re-autenticação Supabase (email + password)** para destrancar.
   Após re-auth com sucesso: contador de PIN reseta a zero,
   cadeado volta ao normal.
4. **A password no ecrã de re-auth vem do gestor de passwords do
   sistema** (Android Autofill Framework / iOS Keychain / Windows
   Credential Manager), **autorizada por biometria do telemóvel**.
   O `TextField` da password tem `autofillHints: [AutofillHints.password]`
   e `AutofillGroup` no formulário para o SO oferecer o preenchimento.
   O gestor não digita a password — usa a biometria do SO para o
   password manager libertar a credencial. Isto garante que
   **qualquer caminho de desbloqueio requer biometria em algum
   ponto**: uso normal pede biometria da app; se falhar cai no PIN;
   se PIN bloquear cai na password que também exige biometria do SO
   para sair do password manager.
5. **PIN é apenas local**, nunca sai do dispositivo. Guardado com
   hash e salt em `flutter_secure_storage` (Keystore no Android,
   Keychain no iOS/Windows).

**Perfis:**

- **Gestor**: pode activar/desactivar, escolher timeout, mudar PIN.
- **Colaborador**: o gestor decide (no destino Empresa) se o
  desbloqueio é obrigatório para colaboradores no mesmo dispositivo.
  Default: opcional.

**Racional (Cesar):** "a app é muito rápida a entrar logo para a
página principal (...) possivelmente precisamos de um pin de
segurança". O contexto operacional (tablets em balcão, colaboradores
a partilhar, telemóveis pessoais que passam de mão) torna a ausência
de cadeado um risco desproporcional face ao esforço de o
implementar.

**Consequências operacionais para o Code:**

1. Novo package: `local_auth` (Flutter oficial) para biometria +
   `flutter_secure_storage` (já pode existir) para PIN hash.
2. Novo destino oculto (`LockScreen`) que intercepta o `AuthGate` —
   se sessão activa **e** cadeado activo, mostra `LockScreen` antes
   do dashboard.
3. Novo bloco em Empresa → aba `Regime fiscal`? Não — cria sub-secção
   em nova aba `Segurança` ou dentro da tab `Dados`. Decidir na
   sprint dedicada da Decisão 2.
4. Testes: cadeado activado + biometria não disponível → cai no PIN;
   PIN errado 3× → bloqueio, aparece ecrã de re-auth Supabase (não
   logout); re-auth com sucesso → PIN counter reset; timeout expirado
   → bloqueia; ecrã de re-auth tem `AutofillHints.password` +
   `AutofillGroup`.

**Fora do âmbito:**

- Não implementar 2FA por SMS/email — o cadeado local resolve o
  cenário do tablet partilhado; 2FA é outro problema (protecção da
  conta contra login remoto).
- Não implementar "esqueci PIN" com recuperação por email nesta
  primeira versão — o fallback é sempre re-login completo com
  password Supabase, o que já garante recuperação.
- Não implementar padrão gráfico (Android-style dots) — PIN
  numérico é mais universal e não exige teclado personalizado.

**Estado:** decisão fechada. Vai para sprint dedicada na 0.0.6+ ou
0.0.7. Não bloqueia sprint 1 v0.0.6 em curso.

---

## Decisão 5 — Post-mortem de decisões é norte de longo prazo (1.x / 2.x), não sprint próxima

**Contexto:** a `docs/AUDITORIA_FORA_DA_CAIXA.md` propôs três apostas
para o ciclo pós-0.0.6 (Aposta A — post-mortem; B — painel fiscal;
C — clima). O Claude recomendou A por fechar a distância central que
a Auditoria B tinha identificado (loop de aprendizagem inexistente) e
por ser o único diferenciador defensável dos concorrentes.

**Decisão:** **Aposta A confirmada como direcção estratégica**, mas
implementada **só numa 1.x ou 2.x**. É norte, não próximo passo.
Requer maturidade da app (recomendações estáveis, dados suficientes
por gestor, cultura de fecho de loop já explicável ao empresário) que
a v0.0.6/0.0.7 ainda não terão.

**Racional (Cesar):** *"post-mortem está decidido por mim, mas isso
será só la na frente numa 1.x ou 2.x"*.

**Consequência para o roadmap curto:**

- A **v0.0.7 não é A**. Fica em aberto entre as outras Apostas
  restantes (B — painel fiscal-de-bolso; C — correlação clima ×
  ocupação) e o que já está no roadmap de tasks (#199 arquitectura
  sidebar, #200 rótulo permanente, #201 cadeado, Decisão 1 motor
  fiscal).
- Quando post-mortem chegar (1.x/2.x), reler a Aposta A na
  `AUDITORIA_FORA_DA_CAIXA.md` como ponto de partida — o desenho
  proposto lá (`Decisao` como modelo, review semanal/mensal, métrica
  de "post-mortems completados por gestor por mês") mantém-se
  válido até prova em contrário.

**Estado:** decisão fechada. Aposta A sai da lista de "decisões
pendentes"; entra no roadmap de longo prazo do produto.

---

## Decisão 6 — Slide 1 do Dashboard: "Primeiro impulso" (versão do Cesar)

**Ecrã / momento:** Slide 1 do carrossel do Dashboard — o que o gestor
vê ao abrir a app.

**Estado hoje (v0.0.5):** Slide 1 mostra 4 KPIs operacionais do mês:
Recebido este mês (hero, com sparkline + setas ‹ ›), Por receber
(com CTA "Cobrar"), Pago este mês, Recomendação do dia (bordo por
gravidade). Responde a "que dinheiro passou por aqui em Julho?".

**Decisão:** Slide 1 passa a responder à pergunta **"como está a
empresa neste momento, e o que faço?"**. Quatro células com natureza
diferente:

1. **Dinheiros que entraram** — recebimentos do mês. Já é calculado
   hoje.
2. **Taxa média de utilização das máquinas · ocupação vs
   rentabilidade** — KPI composto que junta duas dimensões:
   - Ocupação = % do tempo em que as máquinas foram usadas no mês.
   - Rentabilidade extraída = € gerado por essas máquinas no mesmo
     período.
   Apresentação: duas leituras lado a lado com uma indicação de
   equilíbrio (ex.: "80% ocupação · 1.240 €/máquina — bem
   balanceado" vs "80% ocupação · 320 €/máquina — subpreçado";
   "30% ocupação · 2.100 €/máquina — premium subaproveitada"). A
   forma exacta de visualização é decisão da sprint.
3. **Encontro de contas** — recebimentos − pagamentos do mês
   (essencialmente o "Resultado provisório" do Slide 1 antigo).
   Sinal + ou − destacado.
4. **Recomendação do dia** — card com bordo colorido por gravidade
   (verde = oportunidade, laranja = atenção, vermelho = urgente).
   Motor determinístico de 5 regras já discutido em conversas
   anteriores. Confirmado nesta decisão.

**Racional (Cesar):** *"Acho que a leitura aqui já é boa para avaliar
a empresa num primeiro impulso e ainda ter dicas de tarefas ou
melhoramentos (estando estas dicas envoltas em cor verde ou laranja
ou vermelho consoante a necessidade de urgência em accionar a
alavanca)"*.

**Filosofia:** cobre no primeiro ecrã a linha de topo (entrou),
o motor (máquinas), a linha de fundo (sobra) e a acção (dicas).
Um só slide, quatro perguntas fechadas.

**Relação com propostas anteriores:**

- **Não é** a Opção X que o Claude tinha proposto (Slide 1 actual
  mantido). O "Por receber" e "Pago" separados desaparecem — vivem
  na tab **Finanças** do destino **Empresa** (Decisão 2).
- **Não é** a Opção Y (3 KPIs críticos da Auditoria A: saldo+runway,
  margem bruta, CCC). Esses são a bibliografia de gestão; a versão
  do Cesar é a que faz sentido para o vertical do aluguer, hoje.
- **É o "primeiro dos 3 slides"** que o Cesar tinha antecipado
  ("na realidade o que tu referes são 3 slides do mesmo dashboard").
  Os outros 2 slides estão por definir na próxima ronda desta
  conversa.

**Dados necessários (já existem ou dão para calcular):**

- Recebimentos do mês — já existe.
- Ocupação por máquina no mês — dá para calcular a partir das
  reservas (`Booking` com `machineIds` × `startsAt`/`endsAt`).
- Rentabilidade por máquina no mês — soma de `expectedValueCents`
  (ou recebimento real quando existir) atribuível por máquina via
  reservas.
- Recebimentos − pagamentos — já existe (é o Resultado Provisório).
- Recomendação do dia — motor de 5 regras já definido em conversas
  anteriores; pode ser reutilizado directamente.

**Consequências operacionais para o Code (quando for sprint):**

1. Slide 1 do `DashboardPage` reformulado com estes 4 cards.
2. Novo KPI puro `utilizacaoVsRentabilidadeMaquinasMes({now,
   bookings, machines, recebimentos})` que devolve estrutura com
   ocupação % média, rentabilidade média/mediana por máquina, e uma
   leitura sintética ("balanceado" / "subpreçado" / "premium
   subaproveitado" / "por apurar").
3. Setas ‹ › mês do hero antigo aplicam-se ao card 1 ("Dinheiros que
   entraram") — mantém a navegação temporal do que já existia.
4. O motor da "Recomendação do dia" (5 regras) migra do estado
   actual (que estava na Frente 1 sprint 2 v0.0.5 como Slide 5) para
   ser primary no Slide 1 — pode continuar a aparecer também no
   Slide 5 se fizer sentido no contexto semanal, ou consolidar-se
   só aqui.

**Estado:** decisão fechada quanto ao Slide 1. Slides 2 e 3 (dos
"3 slides" prometidos) por definir na próxima ronda desta conversa.

---

## Decisão 7 — Cada slide seguinte ao primeiro é uma Alavanca (materializar a Biblioteca dentro da app)

**Estado hoje (v0.0.5):** Dashboard com 5 slides organizados por
categorias operacionais arbitrárias: **Dinheiro, Pipeline, Máquinas,
Custos, Semana**. As "5 alavancas do Punho" da
`docs/BIBLIOTECA_DE_ALAVANCAS.md` (Procura e vendas · Tesouraria ·
Margem · Utilização da frota · Equipa e processo) existem em texto e
alimentam recomendações determinísticas, mas **não têm reflexo
directo na arquitectura do Dashboard**. A Auditoria B
(`docs/AUDITORIA_APP_ENSINO_GESTAO.md`) identificou isto como
**"a distância principal"** — a Biblioteca vive em Markdown, não
dentro da app.

**Decisão:** Reorganizar o Dashboard em **1 slide de síntese +
5 slides-alavanca**, um por alavanca da Biblioteca. Cada slide-alavanca
é ao mesmo tempo *painel* (KPIs que medem o estado da alavanca) e
*controlo* (recomendações e CTAs que a movem).

**Nova arquitectura do Dashboard:**

| # | Slide | Papel | Cobertura no código actual |
|---|---|---|---|
| 1 | **Primeiro impulso** | Síntese multi-alavanca (Decisão 6) | Reformulação do Slide 1 actual |
| 2 | **Alavanca · Procura e vendas** | Leads, conversão, ROI publicidade, campanhas de dias fracos | Slide 2 actual (Pipeline) refeito à luz da alavanca |
| 3 | **Alavanca · Tesouraria** | Por receber, por pagar, previsão de curto prazo, compromissos | Novo; peças hoje em Slide 1 (Recebido/Pago) + Slide 4 (custos) |
| 4 | **Alavanca · Margem** | Custos vs receita, margem por linha, peso do estado | Slide 4 actual (Custos) refeito |
| 5 | **Alavanca · Utilização da frota** | Ocupação, retorno por activo, máquinas paradas, manutenção | Slide 3 actual (Máquinas) refeito |
| 6 | **Alavanca · Equipa e processo** | Responsabilidades, custo real com pessoal, qualidade de registos | Novo; peças hoje dispersas em Custos e Funcionários |

**"A minha semana" (Slide 5 actual)** deixa de ser slide próprio —
migra para uma faixa persistente no topo/base do Dashboard (recomendação
da semana + tarefas em curso), acessível de qualquer slide-alavanca.

**Racional (Cesar):** *"não têm que ser só três. o terceiro ou 4º deve
ser sobre publicidade e leads e talvez aqui tenha mais indicadores.
o que me leva a raciocinar que temos de olhar para alavancas e que
cada slide seguinte ao primeiro deva ser uma alavanca (ou o control
desta)"*.

**Filosofia — cada slide-alavanca segue a mesma estrutura editorial:**

1. **Cabeçalho** com nome da alavanca + pergunta que responde
   (ex.: "Procura e vendas — estás a atrair o suficiente?").
2. **3-4 KPIs** que medem o estado da alavanca (número + tendência +
   sinal de alerta se aplicável).
3. **Sub-linha** com a evidência de contexto (ex.: "conversão a
   30 dias abaixo do mês anterior").
4. **Recomendação canónica** (Alavanca / Evidência / Leitura /
   Acção / Resultado a acompanhar) no formato da Biblioteca — só
   aparece quando o sinal pede.
5. **CTA para o destino operacional relevante** (ex.: "Ver todos os
   leads →" na alavanca Procura; "Ver todas as máquinas →" na
   Utilização).

**Consequências operacionais:**

- **Fecha a distância central da Auditoria B**: a Biblioteca passa a
  ser experimentada pelo gestor, não apenas lida por quem lê Markdown.
  Cada vez que abre um slide-alavanca, o gestor vê a alavanca *em
  cima dos dados dele*.
- **Escala organicamente**: se aparecer uma 6ª alavanca no futuro
  (ex.: "Aprendizagem/Balanço de Comando" que o roadmap já prevê),
  é um slide novo — o padrão está definido.
- **Alinha com o formato canónico de recomendação** já em uso: cada
  alavanca é o "container" natural das suas próprias recomendações.
- **Torna o dashboard curriculum vivo**: à medida que o gestor
  passa pelos 6 slides, aprende as 5 dimensões pelas quais uma
  empresa se gere.

**Consequências técnicas para o Code (quando for sprint):**

1. Renomear os slides no código de categorias operacionais para
   alavancas (`dinheiro_slide.dart` → `sintese_slide.dart`, novos
   `procura_slide.dart`, `tesouraria_slide.dart`, `margem_slide.dart`,
   `frota_slide.dart`, `equipa_slide.dart`).
2. Cada slide consome KPIs puros existentes ou novos, e um método
   novo do controller `recomendacaoParaAlavanca(Alavanca a)` que
   devolve `Recomendacao?`.
3. Um novo widget partilhado `SlideAlavanca` que impõe a estrutura
   editorial (cabeçalho / KPIs / sub-linha / recomendação / CTA)
   para consistência.
4. Faixa persistente "A minha semana" no topo ou base do Dashboard —
   substitui o Slide 5 actual.
5. Migrar KPIs entre slides conforme a tabela acima; alguns cards
   mudam de slide sem deixar de existir.

**Relação com decisões anteriores:**

- **Decisão 6 (Slide 1 · Primeiro impulso)** continua válida — só
  agora fica explícito que é *síntese multi-alavanca*, não uma
  alavanca própria.
- **Decisão 1 (forma jurídica raiz dos KPIs)** aplica-se a todos os
  slides-alavanca: alguns KPIs só se aplicam a alguns regimes
  fiscais (ex.: alguns KPIs da alavanca Margem não fazem sentido em
  regime simplificado).
- **Decisão 5 (post-mortem para 1.x/2.x)** encaixa naturalmente
  aqui: quando chegar, será *"a alavanca aprendeu"*, o fecho do loop
  aplicado ao slide-alavanca que gerou a decisão.

**Estado:** decisão fechada. Vai para sprint dedicada da 0.0.6 ou
0.0.7 — grande, envolve refactor do Dashboard todo. Não bloqueia
sprint 1 v0.0.6 em curso.

---

## Decisão 8 — Slide Operacional entre o Primeiro impulso e as Alavancas

**Contexto:** a Decisão 7 desenhou o Dashboard como *1 síntese + 5
alavancas*. O Cesar acrescentou que falta um slide de **indicadores
operacionais** — o gestor abre a app também para saber o *pulso do
dia*, coisa que não cabe em nenhuma alavanca isolada porque atravessa
várias (reservas em curso, devoluções, cobranças a vencer, entregas
de hoje).

**Decisão:** adicionar **Slide 2 · Operacional** entre o Slide 1
(Primeiro impulso, síntese) e os slides-alavanca. O Dashboard passa a
ter **7 slides no total**:

| # | Slide | Papel |
|---|---|---|
| 1 | **Primeiro impulso** | Síntese multi-alavanca (Decisão 6) |
| 2 | **Operacional** | **Pulso do dia/semana — o que está a acontecer AGORA** |
| 3 | Alavanca · Procura e vendas | Gestão de aquisição |
| 4 | Alavanca · Tesouraria | Gestão de fluxos |
| 5 | Alavanca · Margem | Gestão de rentabilidade |
| 6 | Alavanca · Utilização da frota | Gestão do parque |
| 7 | Alavanca · Equipa e processo | Gestão das pessoas |

**Diferença conceptual:**

- **Alavancas** (slides 3-7) = perguntas de gestão *"posso mover o
  quê?"* — reflectem médio prazo, decisões estratégicas.
- **Operacional** (slide 2) = ordens do dia *"o que tenho de fazer
  hoje?"* — reflectem curto prazo, execução.
- **Primeiro impulso** (slide 1) = síntese *"como está a empresa e o
  que faço a seguir?"* — 30 segundos.

**Conteúdo proposto do Slide 2 · Operacional** (para confirmares ou
ajustares):

- **Reservas activas** — nº e valor total do que está alugado agora,
  com CTA "Ver todas →" para Reservas.
- **Entregas / levantamentos hoje** — nº de máquinas a sair hoje e
  clientes.
- **Devoluções hoje / próximas 48 h** — máquinas a voltar, com
  destaque para as que ultrapassaram o prazo.
- **Cobranças a vencer nos próximos 7 dias** — nº e valor.
- **Alertas operacionais** — sinais que exigem acção *hoje*:
  máquinas em manutenção que passaram do prazo, clientes que não
  entregaram uma máquina cujo período já acabou, reservas
  confirmadas sem cliente atribuído, colaboradores com carga anómala.

**"A minha semana" (Slide 5 antigo) é absorvida por este slide** —
a Decisão 7 previa migrar para faixa persistente, mas com o Slide
Operacional dedicado a essa camada de curto prazo, a faixa deixa de
ser necessária. Menos elementos flutuantes, mais consistência com
o padrão de swipe.

**Racional (Cesar):** *"acho que devemos acrescentar mais um slide
para indicadores operacionais, estou a pensar colocá-lo na 2ª
posição"*.

**Emenda à Decisão 7:**

- Dashboard passa de 6 para 7 slides.
- A faixa persistente "A minha semana" **deixa de existir** — o
  conteúdo migra para o Slide Operacional.
- Cada slide-alavanca continua com estrutura editorial fixa (Decisão 7);
  o Slide Operacional segue outra estrutura porque é natureza diferente
  (mais listas accionáveis do que KPIs com tendência).

**Consequências técnicas para o Code (quando for sprint):**

- Um novo `operacional_slide.dart` entre o síntese e o primeiro
  slide-alavanca.
- Novos KPIs puros: `entregasHoje`, `devolucoesHoje`,
  `devolucoesEmAtraso`, `cobrancasNaProximaSemana`,
  `alertasOperacionais(now, ...)`.
- A faixa persistente que estava planeada não chega a nascer.
- Todos os KPIs deste slide são "tempo-sensíveis" — precisam de `now`
  injectado e devem refrescar quando o gestor volta à app (não
  cachar mais que alguns minutos).

**Estado:** decisão fechada, sujeita a confirmação do conteúdo
proposto acima. Vai para a mesma sprint dedicada da Decisão 7
(task #203) — não vale a pena separar refactors do Dashboard.

---

## Decisão 9 — Slide final "Objectivos" (trajectória a médio e longo prazo)

**Contexto:** as Decisões 6, 7 e 8 desenharam o Dashboard como
*síntese + operacional + 5 alavancas*. Faltava a dimensão do
**onde queres chegar**. A Biblioteca de Alavancas já prevê o
"Balanço de Comando" ao fim de ~1 ano de utilização, e a Auditoria B
apontou que o dashboard tem hoje "Objetivo da Semana" mas nada de
médio/longo prazo — nunca fecha o loop *"estás no caminho do que
te propuseste este ano?"*.

**Decisão:** adicionar **Slide 8 · Objectivos** no fim do carrossel.
Trajectória a médio e longo prazo: metas anuais/trimestrais/mensais
definidas pelo gestor, progresso real vs planeado, alerta quando o
ritmo não bate certo.

**Dashboard final (8 slides):**

| # | Slide | Papel | Horizonte |
|---|---|---|---|
| 1 | Primeiro impulso | Síntese multi-alavanca | Hoje |
| 2 | Operacional | Pulso do dia/semana | Curto prazo |
| 3 | Alavanca · Procura e vendas | Gestão de aquisição | Contínuo |
| 4 | Alavanca · Tesouraria | Gestão de fluxos | Contínuo |
| 5 | Alavanca · Margem | Gestão de rentabilidade | Contínuo |
| 6 | Alavanca · Utilização da frota | Gestão do parque | Contínuo |
| 7 | Alavanca · Equipa e processo | Gestão das pessoas | Contínuo |
| **8** | **Objectivos** | **Trajectória vs meta** | **Médio e longo prazo** |

O percurso mental do gestor ao fazer swipe: *estou vivo hoje?* →
*o que faço agora?* → *que alavancas posso puxar?* → *estou no caminho
do que quero ser?* — quatro tempos verbais, quatro horizontes.

**Conteúdo proposto do Slide 8 · Objectivos** (para confirmares ou
ajustares):

- **Objectivo principal do ano** (definido pelo gestor no
  onboarding ou em Empresa → Objectivos) — número grande destacado,
  com valor actual em barra de progresso e sub-linha "estás a X%,
  faltam Y meses para o fim do ano".
- **Ritmo real vs ritmo planeado** — sinal claro: no ritmo (verde) /
  desviado (laranja) / muito abaixo (vermelho). O sinal usa o mesmo
  código de cores das recomendações da Decisão 6.
- **2-3 metas secundárias** com o mesmo padrão (ex.: nº clientes
  novos no ano · margem média · ocupação média das máquinas).
- **Recomendação contextual** — quando o ritmo pisca, o Punho aponta
  qual alavanca puxar. Ex.: *"estás 12% abaixo do ritmo de facturação;
  a alavanca de Procura e vendas tem 40 leads sem contactar — abrir
  →"*. Isto liga este slide de volta aos slides-alavanca 3–7.
- **CTA "Definir/rever objectivos"** — abre um destino em Empresa
  onde o gestor edita.

**Onde vivem os objectivos:**

- Modelo novo `ObjetivoAnual` com campos: `metrica` (enum: facturação
  · margem % · nº clientes · ocupação média · outro), `valorAlvo`,
  `ano`, `notas`.
- Persistidos no `OperationalRepository` (mesmo padrão dos restantes
  modelos operacionais).
- Tab nova em **Empresa** → "Objectivos" para o gestor definir/rever.

**Racional (Cesar):** *"o último slide é de Objectivos traçados a
médio e longo prazo, para ver se estamos em linha com o objectivo"*.

**Relação com decisões anteriores:**

- **Decisão 7 (Biblioteca de Alavancas nos slides)**: cada
  recomendação do Slide 8 aponta para uma alavanca concreta (slide
  3-7). Fecha o loop pedagógico — o gestor vê o rumo, vê onde
  desviou, vê que alavanca mexer.
- **Decisão 5 (Post-mortem para 1.x/2.x)**: quando chegar, o
  post-mortem terá base natural aqui — cada decisão pode ser
  contrastada com o objectivo que se propunha atingir.
- **Biblioteca de Alavancas / Balanço de Comando**: este slide é o
  cerne do Balanço de Comando que a Biblioteca antecipa ao fim de
  ~1 ano de utilização.

**Consequências técnicas para o Code (task #203):**

- Um novo `objetivos_slide.dart` no fim do carrossel.
- Modelo novo `ObjetivoAnual` + persistência no repositório.
- Nova tab em Empresa → "Objectivos" (soma-se à lista da Decisão 2:
  Dados · Regime fiscal · Custos fixos · Veículos · Finanças ·
  Estado · **Objectivos**).
- KPIs puros novos: `progressoObjetivo(o, now, operacional)`,
  `ritmoNecessarioParaAlvo(o, now, operacional)`,
  `alavancaMaisRelevanteParaObjetivo(o, operacional)`.

**Estado:** decisão fechada, sujeita a confirmação do conteúdo
proposto. Vai para a mesma sprint dedicada da Decisão 7 (task #203).

---

## Decisão 10 — Slide "Previsibilidade Simulada" (laboratório de cenários)

**Contexto:** as Decisões 6–9 desenharam o Dashboard como
*síntese → operacional → alavancas → objectivos*. O Cesar acrescentou
uma camada nova: um slide onde o gestor pode **mexer nas variáveis e
ver o impacto no resultado** sem executar nada no negócio real.
Exemplos dele: *"se aumentar o preço da máquina em 5 €, o que
acontece ao lucro? se reduzir a renda em 100 €/mês, o que acontece
ao lucro final?"*.

**Decisão:** adicionar **Slide 9 · Previsibilidade Simulada** no fim
do carrossel. Laboratório de cenários: sliders/inputs para variáveis
económicas chave, resultados actuais vs simulados lado a lado, com
delta destacado.

**Dashboard final (9 slides):**

| # | Slide | Papel | Horizonte / natureza |
|---|---|---|---|
| 1 | Primeiro impulso | Síntese multi-alavanca | Hoje |
| 2 | Operacional | Pulso do dia/semana | Curto prazo |
| 3-7 | 5 Alavancas | Gestão contínua | Contínuo |
| 8 | Objectivos | Trajectória vs meta | Médio/longo prazo |
| **9** | **Previsibilidade Simulada** | **Laboratório de cenários** | **Hipotético** |

Percurso mental completo do gestor: *estou vivo hoje?* → *o que
faço agora?* → *que alavancas puxo?* → *estou no caminho?* → **"e
se mudasse X?"** — cinco perguntas, cinco tempos, cinco horizontes.

**Campos editáveis directamente no slide (in-line, sem popup):**

O gestor mexe *no próprio dashboard* — o slide é campo de trabalho,
não janela modal. Sliders/inputs numéricos in-line que recalculam
os resultados imediatamente. Sem passos intermédios, sem "abrir
formulário", sem "gravar" — a mudança sente-se na hora e desfaz-se
com a mesma facilidade.

Variáveis editáveis:

- **Preço médio por manhã de aluguer** (por tipo de máquina)
- **Ocupação % das máquinas** (nº médio de reservas/mês)
- **Taxa de conversão de leads**
- **Custos fixos mensais** (renda, água/luz, seguros — cada um com
  o seu campo)
- **Nº de colaboradores** e **salário médio**
- **Publicidade mensal**

Cada campo tem à esquerda o valor **actual** (só leitura, cinza) e
à direita o valor **simulado** (editável, laranja). Um botão
"Repor" em cada linha volta o simulado ao actual.

**Resultados observáveis (por cenário):**

- **Resultado provisório mensal** — actual vs simulado
- **Resultado anual projectado** — actual vs simulado
- **Margem %** — actual vs simulado
- **Cash conversion cycle / runway em semanas** — actual vs simulado
- **Alavanca mais afectada pela mudança** — o Punho aponta qual
  slide-alavanca faria mais sentido consultar em consequência

**Cenários guardados:**

- O gestor pode dar nome a um cenário e guardar (ex.: *"subir preço
  5 €"*, *"cortar renda 100 €"*, *"contratar +1 colaborador"*).
- Cenários guardados aparecem como chips no topo do slide para
  comparação lado a lado.
- Máximo 5 cenários simultâneos para não sobrecarregar (o resto
  arquiva-se com CTA "Ver todos os cenários guardados").

**Filosofia:**

- **Zero risco**: nada do que se mexe no simulador toca no negócio
  real. É camada visual pura sobre um motor de cálculo.
- **Ensina sensitivity analysis sem jargão**: o gestor descobre por
  si que 5 € a mais por manhã × 200 manhãs = 12.000 €/ano de
  impacto — sem ninguém lho ensinar como fórmula.
- **Fecha a distância entre decisão e consequência**: o gestor sente
  o impacto antes de decidir, não depois de arrepender-se.
- **Encoraja experimentação segura**: um gestor que testa 10
  cenários por mês é um gestor que aprende a gerir.

**Racional (Cesar):** *"novo slide no dashboard, previsibilidade
simulada, quer isto dizer que se eu aumentar a máquina em 5 € e
mantiver os mesmos indicadores o que acontece ao meu lucro? se eu
reduzir o valor da renda em 100 € mensais o que acontece ao meu
lucro final."*

**Relação com decisões anteriores:**

- **Decisão 5 (post-mortem para 1.x/2.x)**: o simulador é o
  *pré-decisão*; o post-mortem será o *pós-decisão*. Juntos fecham
  o loop completo — experimenta antes, avalia depois.
- **Decisão 7 (Biblioteca de Alavancas)**: cada variável simulável
  pertence a uma alavanca. Quando o gestor mexe numa variável, o
  simulador pode sugerir *"esta mudança move a alavanca X — vais ao
  slide correspondente para ver o que já sabemos sobre ela?"*
- **Decisão 9 (Objectivos)**: o simulador é a ferramenta para
  descobrir *como* atingir um objectivo. Ex.: "para atingir
  150 k€ este ano, precisas de subir preço 8 € OU angariar +12
  clientes OU melhorar ocupação 15% — escolhe qual".

**Consequências técnicas para o Code (soma-se à task #203):**

- Novo `previsibilidade_slide.dart`.
- Motor puro `Simulador` em `lib/core/simulador/` que recebe estado
  base + overrides e devolve estado simulado, reusando os KPIs puros
  já existentes.
- Modelo `Cenario` com `id`, `nome`, `overrides`, `criadoEm` —
  persistido no repositório operacional.
- Widget `CenarioComparativo` que mostra actual vs N cenários lado a
  lado com delta.
- Testes unitários pesados sobre o motor `Simulador` — é o coração
  matemático deste slide.

**Estado:** decisão fechada. Vai para a mesma sprint dedicada da
Decisão 7 (task #203) — o Dashboard é refeito de uma vez.

---

## Decisão 11 — Tarefas como backlog priorizado de perguntas por responder

**Contexto:** com o Dashboard fechado em 9 slides (Decisões 6-10),
sabemos exactamente que respostas o Punho quer poder dar ao
empresário. E se sabemos as respostas, sabemos as perguntas que
precisamos de lhe fazer. O onboarding actual tenta recolher tudo à
cabeça — cansa o empresário e cria abandono. Ao mesmo tempo, o
destino **Tarefas** existe hoje como lista pouco estruturada de
"dados por completar" apanhados aqui e ali.

**Decisão:** **Tarefas passa a ser o backlog priorizado de todas as
perguntas por responder** que a app precisa para calcular KPIs
completos. As perguntas não feitas ou não respondidas no primeiro
contacto com a app vivem lá, ordenadas por prioridade calculada.

**Princípio (emendado após conversa com o Cesar):**

- **Onboarding mantém-se como está.** Não encolhe. O que já pergunta
  hoje (nome, empresa, forma jurídica, NIF, contactos, cargo,
  colaboradores, veículos, máquinas, receitas dos últimos anos,
  manutenção, custos fixos mensais) continua a ser pedido no primeiro
  contacto.
- **Tarefas ganha camada nova**: **perguntas adicionais** que a app
  considere importantes para completar KPIs mas que hoje o onboarding
  não faz (ex.: saldo em banco actual, salários detalhados por
  colaborador, prazos médios de pagamento, objectivos anuais,
  manutenção detalhada). Estas perguntas **só aparecem depois de as
  do onboarding estarem preenchidas** — não competem por atenção.
- O gestor **completa à medida que a app pede** — as perguntas
  adicionais surgem em Tarefas por ordem de prioridade calculada.
- **Nunca abandona uma pergunta** — se um KPI aparece "Por apurar",
  há uma tarefa correspondente que o destrança.

**Racional do Cesar (correcção):** *"muda a filosofia? porquê?
podemos colocar perguntas que consideres importantes, depois de todas
essas estarem preenchidas."* — leitura correcta: preservar o
onboarding, acrescentar a camada de perguntas complementares em
Tarefas.

**Interpretação errada anterior (mantida para memória):** o Claude
inicialmente propôs encolher o onboarding drasticamente e migrar
tudo para Tarefas. Isso mudava a filosofia sem necessidade. A
directiva do Cesar era só *"o que não cabe no onboarding e é
importante, vai para Tarefas priorizado"* — a filosofia mantém-se.

**Ordenação por prioridade (algoritmo emendado):**

O Cesar acrescentou o critério mestre: prioridade é dada às perguntas
que fazem a app ser **eficiente e verdadeira com o negócio**. Estes
são dois vectores distintos, e **a verdade vem primeiro**:

**Nível 1 · Verdade** (ordem mais alta, boost forte)

Perguntas cuja ausência faz a app **mentir** ao gestor — mostrar
defaults como se fossem reais, apresentar estimativas como
certezas, ou usar médias sem base. Ex.: sem responder "qual o
regime fiscal?", o KPI Custo real com pessoal está sistematicamente
errado (assume Lda por default). Sem responder "qual o saldo em
banco?", o KPI Runway não existe.

Estas perguntas ganham **selo vermelho**: *"Corrige valores"*.

Aliena-se com o princípio da Biblioteca: *"Medir antes de corrigir"*
(Taylor) — a app não deve fingir que sabe o que não sabe.

**Nível 2 · Eficiência**

Perguntas que destrancam muitos KPIs de uma vez, mesmo que a
ausência não faça a app mentir (o card fica "Por apurar" — o gestor
sabe que não sabemos, não somos enganados).

Estas perguntas ganham **selo verde**: *"Destranca N KPIs"*.

**Nível 3 · Urgência temporal**

Perguntas ligadas a eventos com prazo (obrigação fiscal iminente,
fecho de ano, data de renovação de contrato).

Estas perguntas ganham **selo âmbar**: *"Prazo: dd/mm"*.

**Nível 4 · Antiguidade no backlog**

Perguntas que existem há muito tempo sobem gradualmente para não
serem eternamente empurradas.

**Fórmula do score:**

```
score = (peso_veracidade × é_veracidade)
      + (n_kpis × peso_slide)
      + boost_temporal
      + inflação_estágio
```

`peso_veracidade` é grande (~100 pontos) para que qualquer pergunta
de veracidade tenha prioridade sobre qualquer pergunta de eficiência
pura. Peso dos slides decrescente do 1 ao 9. Recalculado a cada
abertura da app.

**Estrutura de cada linha de Tarefa:**

- **Título** da pergunta (ex.: *"Qual o saldo em banco hoje?"*).
- **Preview do impacto** — o que se destranca ao responder:
  *"Destrancas: KPI Runway, KPI Cash Cycle, recomendação de tesouraria"*.
- **Botão `Responder`** abre form contextual dedicado (não um
  formulário longo, só a pergunta em causa).
- **Botão `Adiar 7 dias`** oculta temporariamente sem apagar.
- Respondidas somem imediatamente da lista (não ficam com check).

**Estatística no topo do destino Tarefas:**

- *"12 perguntas por responder"* + barra de progresso
  *"57% dos KPIs completos, 43% por apurar"*.
- Botão *"Ver KPIs por apurar →"* que abre lista dos KPIs que ainda
  não têm resposta e permite navegar até à pergunta em falta.

**Filosofia (fecha o círculo com a Auditoria B):**

- A app deixa de fingir que sabe tudo desde o dia zero.
- O gestor aprende à medida que responde — cada pergunta é uma micro-lição.
- O "por apurar" deixa de ser resignação e passa a ser **acção clara**.
- Alinha-se com "coach silencioso" (a app pergunta no momento em que
  a resposta é útil, não à cabeça).
- Fecha o círculo com a Biblioteca de Alavancas: cada pergunta em
  Tarefas está associada a uma alavanca — o gestor aprende que
  alavancas precisam de que dados.

**Racional (Cesar):** *"as perguntas que não forem feitas ou
respondidas no primeiro contacto com a app, devem ser colocadas por
ordem de prioridade no 'Tarefas'"*.

**Consequências operacionais para o Code:**

1. Novo modelo `Pergunta` (id, título, campo(s) que preenche,
   KPIs que destranca, alavanca associada, urgência temporal,
   estágio de adiamento).
2. Novo motor `PriorizadorDePerguntas` puro que devolve lista
   ordenada de perguntas pendentes.
3. Refactor da `TarefasPage` para consumir esta lista em vez da
   colecção actual de fontes ad-hoc — a lista actual (dados por
   completar, cobranças com atraso, máquinas por identificar) passa
   a ser expressa como `Pergunta`s.
4. Onboarding **não encolhe** — mantém-se como está. As perguntas
   complementares nascem em Tarefas com prioridade calculada, **e só
   aparecem depois das do onboarding estarem preenchidas**.
5. Sub-secção nova no destino Tarefas: **"Progresso do teu Punho"**
   com a barra de completude dos KPIs.

**Relação com decisões anteriores:**

- **Decisão 2 (sidebar)**: `Tarefas` mantém-se como destino próprio
  (7º da sidebar), agora com peso muito maior.
- **Decisão 6-10 (Dashboard 9 slides)**: cada KPI de cada slide
  aponta para a pergunta que o destrança. Se o KPI é "por apurar",
  o card mostra CTA *"Responder em Tarefas →"*.
- **Decisão 1 (forma jurídica raiz)**: perguntas específicas do
  regime fiscal são condicionais — só aparecem em Tarefas se o
  regime as exige.

**Estado:** decisão fechada. Vai para sprint dedicada da 0.0.7 (a
seguir à sprint dos 9 slides da task #203) — o refactor de Tarefas
depende da nova estrutura de KPIs por slide estar em vigor.

---

## Decisão 12 — Agregados de custos são sensíveis ao regime (o total tem de bater com o detalhe)

**Contexto:** o Code fechou a Frente D da sprint 1 v0.0.6 (custo real
com pessoal, com TSU patronal 23,75% já a somar quando aplicável).
Ao capturar o slide de Custos, apanhou uma contradição visual: o card
"Custo real com pessoal" mostrava 1.361 € (com TSU patronal), mas
o card "Custos sobre a receita" somava o pessoal a 1.100 € (bruto
sem TSU) — porque `CustosMes.totalCents` (o agregador) não passou a
ser sensível ao regime.

**Decisão:** `CustosMes.totalCents` **passa a ser sensível ao
regime**. O total tem de bater com o card de detalhe. A TSU patronal
é dinheiro que sai da empresa; **tem de contar como custo real** em
qualquer agregação de custos, não só no card dedicado.

**Racional (aplicação directa das Decisões 7 e 11):**

- **Coerência interna** — a app não pode contradizer-se de um card
  para o outro no mesmo ecrã. Se diz 1.361 € num sítio e 1.100 €
  noutro, o gestor não confia nem no primeiro nem no segundo.
- **Verdade > estabilidade** — a recomendação *"custos críticos
  ≥80%"* passa a disparar mais cedo. Isso é a **verdade** do
  negócio (o dinheiro sai mesmo), não um artefacto. Antes estava a
  mascarar.
- **Alinhado com Taylor (Biblioteca)**: *"Medir antes de corrigir"*
  — se estamos a medir custos, medimos os reais.

**Consequência secundária aceite:** o comportamento visível do painel
muda. Recomendações contextuais ligadas ao peso dos custos passam a
disparar com valores mais próximos da realidade. Não é regressão, é
correcção.

**Estado:** decisão fechada. O commit que introduziu a contradição
fica à espera de um follow-up que torne `CustosMes.totalCents`
sensível ao regime.

---

## Decisão 13 — Orientação de ecrã por contexto (regra única)

**Contexto:** o Cesar apanhou em teste que o ecrã "Como te chamas?"
(passo 1 do onboarding) apareceu em landscape, quando deveria ser
portrait. A causa provável é `SystemChrome.setPreferredOrientations`
a ser chamado demasiado cedo no arranque (ou o *convite* a rodar
do `BoasVindasScreen` a produzir efeitos indesejados no fluxo).

**Decisão:** regra única e explícita sobre orientação, por
contexto:

| Ecrã / contexto | Orientação | Notas |
|---|---|---|
| Login / registo | **Portrait lock** | Antes de qualquer sessão |
| Onboarding inteiro (todos os passos, incluindo `MaisDados` e `BoasVindas`) | **Portrait lock** | Sem excepções, sem "convite a rodar" |
| Shell do colaborador (após entrar) | **Portrait lock** | Já era assim; mantém-se |
| Shell do gestor (após `completeOnboarding` + tap em "Entrar na Punho") | **Landscape lock** | Só aqui a app roda |

**Racional (Cesar):** *"o 'como te chamas' não é para ser landscape,
o app do colaborador também não é landscape. Estas perguntas estavam
bem no vertical. Só se muda para landscape se for o admin e após o
ecrã de boas-vindas."*

**Filosofia:** um só ecrã em toda a app leva landscape — o shell do
gestor autenticado. Todos os outros contextos são portrait. Sem
zonas cinzentas, sem "preferido sem lock", sem convites a rodar
prematuros.

**Correcções ao entregue na Frente A da sprint 1 v0.0.6:**

- **Retirar** de `main.dart` qualquer `SystemChrome.setPreferredOrientations`
  chamado no arranque. A app arranca sem forçar orientação.
- **Cada shell/rota decide a sua orientação** com um `didChangeDependencies`
  (ou pattern equivalente) que chama `setPreferredOrientations`
  com o que corresponde ao contexto actual.
- **`BoasVindasScreen` passa a portrait lock**. O botão "Entrar na
  Punho" continua a mudar para landscape *depois* do tap — nunca
  antes. O texto que sugeria rodar antes de entrar deixa de fazer
  sentido: pode ser reformulado para *"a partir daqui a Punho vai
  passar a modo horizontal — o teu tablet vai rodar sozinho"*.
- **O teste que confirma que `BoasVindasScreen` não chama
  `setPreferredOrientations`** passa a inverter-se: agora exige que
  o ecrã force portrait, tal como o resto do onboarding.

**Consequências operacionais para o Code (follow-up da sprint 1
v0.0.6, junto com o follow-up da Decisão 12):**

1. Novo helper `OrientacaoDoContexto` em `lib/core/orientacao/` que
   expõe `forcarPortrait()`, `forcarLandscape()` e `libertar()`.
2. Cada `Widget` de rota chama o helper apropriado no
   `initState`/`didChangeDependencies`.
3. `main.dart` limpo — sem forçar orientação global.
4. `BoasVindasScreen` chama `forcarPortrait()` no `initState` e
   `forcarLandscape()` **apenas** dentro do `onPressed` do botão
   "Entrar na Punho", **antes** de navegar.
5. Testes reformulados para cada contexto.

**Estado:** decisão fechada. Fica como follow-up pequeno da sprint 1
v0.0.6, junto com a Decisão 12 (`CustosMes.totalCents` sensível ao
regime) e antes de arrancar a Frente C UI e a Frente B.

---

<!-- Próximas decisões abaixo, à medida que forem discutidas. -->
