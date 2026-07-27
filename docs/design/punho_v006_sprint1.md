# Punho v0.0.6 — sprints 1 e 2

**Branch:** `feat/v006-boas-vindas`
**Data:** Julho 2026
**Estado:** sprints 1 e 2 fechadas, 481 testes verdes (450 sem goldens). Release em curso.

---

## O que foi construído

### Frente A · Boas-vindas e MaisDados

Dois ecrãs de **contexto** — não pedem dados nenhuns, explicam. Nenhum deles tem o contador "N de M", porque não são passos.

- **`MaisDadosScreen`** aparece só quando o switch dos dados operacionais está ligado, **entre** o switch e o primeiro passo detalhado. O gestor acabava de dizer "sim, quero preencher" e a app respondia mudando de campo sem dizer nada.
- **`BoasVindasScreen`** é o último ecrã antes de entrar, e é ele que chama o `completeOnboarding`. Até tocar em "Entrar na Punho" **nada é gravado** e o gestor pode voltar atrás a corrigir.

Só o gestor os vê. Ao colaborador não se promete "o painel do teu negócio em cinco vistas" nem se pede uma rotação: o shell dele não tem painel e fica em retrato.

O contador conta passos de dados (7 ou 12), não ecrãs (8 ou 14) — um "12 de 14" cujo contador nunca chega a 14 seria pior do que não o ter.

Commit: `adc9578`

### Motor fiscal · `RegimeFiscal` + `estimarSalarial` + tabelas IRS 2026

Enum `RegimeFiscal` mínimo (`eniSimplificado`, `eniOrganizado`, `ldaIrc`, `outro`) mapeado da `OnboardingData.legalForm`, e `estimarSalarial` a receber o regime **obrigatório**.

O que a estimativa inclui: bruto, TSU do trabalhador (11%), IRS aproximado por escalão, e TSU da entidade patronal (23,75%). **Não inclui subsídios de férias e de Natal** — ficaram deliberadamente fora, porque o acréscimo depende do CCT e do tipo de contrato, e uma estimativa com um erro estrutural de ~16% seria pior do que uma estimativa honestamente parcial. Fica registado em `references/tabelas_irs_2026.md` como fora do modelo.

Regime `outro` devolve `null` — não há cálculo aplicável e não se inventa um genérico. Ausência de estimativa e estimativa conservadora são coisas diferentes: `null` diz a primeira, e a flag `estimativaConservadora` marca a segunda (hoje só o estado civil "Outro", que lê pela coluna mais pesada).

Três coisas que a Decisão 1 obrigou a corrigir no desenho, e que são o erro fácil de repetir:

- **A TSU patronal não é coisa de Lda.** Um ENI com dois empregados paga-a como qualquer entidade.
- **O empresário em nome individual não entra no cálculo.** Não é colaborador de si mesmo — desconta como trabalhador independente.
- **O coeficiente do regime simplificado aplica-se ao rendimento do empresário, nunca ao salário de terceiros.**

O `RegimeFiscal` é parâmetro obrigatório de todas as funções novas de estimativa fiscal — impede que qualquer cálculo futuro assuma um regime por omissão (Decisão 1).

### Frente D · KPI "Custo real com pessoal"

O KPI da equipa mostrava a soma dos brutos declarados. Para quem tem gente com contrato isso subestima o custo em quase um quarto — a TSU patronal não aparece em vencimento nenhum.

`custoRealComPessoalMes` devolve `(bruto, tsuPatronal, total)` para **o mês**, não por colaborador: a desagregação por pessoa vive na lista de colaboradores, na sub-linha com vínculo e custo real. A TSU só incide sobre contratos; em recibos verdes o valor pago é o custo total. Arquivados, inactivos e fichas sem custo declarado ficam de fora.

O título mudou para "Custo real com pessoal" de propósito: o número subiu, e mantê-lo com o nome antigo faria o gestor ler um valor diferente com a mesma etiqueta. Regime não modelado **esconde** o KPI em vez de mostrar 0 € — mostrar KPI irrelevante é ruído pior do que ausência (Decisão 1).

Commit: `6ae551a`

### Follow-up Decisão 12 · `CustosMes.totalCents` sensível ao regime

O sintoma era a app a contradizer-se no mesmo ecrã: o card do pessoal dizia 1.361 € (com carga social) e o card "custos sobre a receita" somava 1.100 € (só o bruto). O `totalCents` não era sensível ao regime — não é que assumisse ENI, é que ignorava a TSU patronal por completo.

O total passou de 1.730 € para 1.991 €. O campo `colaboradoresCents` foi **renomeado** para `custoRealPessoalCents` de propósito: o significado mudou, e manter o nome deixaria leitores a interpretar bruto onde passou a estar custo real. O compilador apanhou os quatro leitores que havia.

Consequência assumida, e é o ponto: a recomendação "custos críticos" (≥80% da receita) dispara mais cedo. Dois testes marcam a fronteira — 700 € de bruto sobre 1.000 € de receita liam-se como 70% e ficavam calados; com carga social são 87% e a regra dispara. Era falso negativo, não é falso positivo.

Commit: `babb2b5`

### Follow-up Decisão 13 · `OrientacaoDoContexto` (portrait/landscape por contexto)

O bug: o passo 4 do onboarding aparecia deitado num tablet, com o gestor a preencher campos de lado.

A causa não estava no onboarding. O `main.dart` bloqueava landscape **no arranque**, antes de se saber quem ia usar a app. O `PhoneOrientationLock` tentava corrigir por dentro, mas só actuava em telemóveis (`shortestSide < 600`) — num tablet o bloqueio global ganhava.

`OrientacaoDoContexto` **não é um wrapper**: é um helper estático que cada rota chama no `initState`. O wrapper era precisamente o `PhoneOrientationLock`, e foi **apagado** em vez de ficar sem uso — dois mecanismos a decidir orientação é como este bug reaparece.

| Contexto | Orientação |
|---|---|
| Login, registo, onboarding inteiro, shell do colaborador | portrait |
| Shell do gestor autenticado | landscape |

Um só ecrã em toda a app leva landscape. O `BoasVindasScreen` pede portrait ao abrir e landscape no botão, **antes** de entrar, para o painel nascer já na forma certa; o texto deixou de pedir ao gestor para rodar e passa a avisar que o ecrã roda sozinho.

Commit: `ffe917d`

### Frente C UI · `FichaFiscalColaboradorForm`

Formulário parametrizado por conjunto de campos (`CampoDaFichaFiscal`), condicionais por vínculo. **Há dois vínculos, não três:** `recibosVerdes` e `contrato` — não existe "estágio" no modelo.

A regra é: só se pede o que muda alguma coisa. Em recibos verdes pede-se NIF (para a empresa lançar a despesa) e **não** se pede NISS, estado civil nem dependentes, porque os descontos são do prestador. E ao gravar só se guarda o que o vínculo usa: passar a recibos verdes **limpa** o NISS de facto — é para isso que o `copyWith` tem sentinela.

`SegmentedButton` do Material no topo, com duas colunas em paisagem. Bloco de estimativa a recalcular a cada tecla, com o custo total da empresa em destaque e o aviso do contabilista. Os avisos de NISS/NIF usam `helperText` âmbar e não `errorText`: um número a meio de ser escrito não é um erro, e nunca bloqueiam a gravação.

Chips âmbar na lista e uma linha nas Tarefas **por pessoa**, com o nome — um agregado "3 fichas incompletas" não diz de quem se trata a quem tem de agir.

O widget nasceu com o superset de campos em mente (IBAN, morada pessoal, data de nascimento previstos para sprint 2 do colaborador — acrescentam-se à lista de campos sem refactor estrutural).

Commits: `ee248b4`, `2bb3535`

### Passo 5 · Popup Perfil (Frente B minimalista)

O avatar no fundo da barra lateral era decorativo: `Container` com tooltip e sem `onTap`. Não havia forma de ver quem estava autenticado nem de terminar sessão sem procurar o ícone certo entre os outros — e num dispositivo partilhado isso deixa a conta anterior lá presa.

Popup e não página: identidade e sair são duas linhas e um botão. Avatar com iniciais, nome, empresa, chip `SESSÃO ACTIVA` / `MODO DEMONSTRAÇÃO`, email e perfil quando existem, versão da app no rodapé.

O `_SignOutButton` solto **saiu** da barra lateral e passou para dentro do popup, com confirmação. Estava ao lado dos convites, sem aviso e sem contexto. Depois do `signOut` quem redirecciona é o `AuthGate` — não se chama `Navigator` à mão — e o `invalidate` evita que o gate decida com a adesão antiga em cache.

**Sem edição de dados da empresa**, com um teste a garanti-lo: isso é o destino Empresa com abas, na v0.0.7. Era o deslize fácil para a `ContaScreen` unificada que ficou explicitamente de fora.

`podeTerminarSessao` é função pura porque `SupabaseConfig.enabled` é constante de compilação e em testes é sempre `false` — sem ela o caminho "com sessão" ficava por cobrir. Mesmo padrão do `podeEliminarMaquinas`.

Commit: `f23ee02`

### Passo 2 · Auditoria de hit target (#206)

A regra: a área que recebe o toque coincide com a área desenhada colorida.

O resultado honesto: **seis dos sete grupos já cumpriam**, e não por acaso — usam botões do próprio Material (`FilledButton`, `TextButton`, `PopupMenuButton`, `SegmentedButton`), onde é o framework que garante `Material` + `InkWell` com a mesma bounding box. O único que não cumpria era o avatar do Perfil: área colorida sem alvo nenhum, o caso extremo do defeito, resolvido no Passo 5.

O método é o que dá valor aos testes: tocam a **2 dp do bordo de dentro**, não no centro. Um toque no centro acerta mesmo num alvo mal dimensionado.

**Alvos maiores do que o desenho não se corrigem.** Os pontos do carrossel têm 8 dp desenhados e 16 dp de alvo, de propósito — a regra existe para impedir alvos *menores*, e um ponto de 8 dp com alvo de 8 dp era impossível de acertar num tablet. Há um teste a fixar essa diferença, para ninguém a "corrigir" por zelo.

Commit: `60ed6f2`

---

## Testes

Cobertura de testes adicionada para:

- `FichaFiscalColaboradorForm`: alternar vínculo, campos condicionais, chips, linha nas Tarefas.
- Goldens de screenshot com `@Tags(['screenshot'])` excluídos do gate de CI (`--exclude-tags screenshot`) — política, não workaround: os goldens dependem das fontes do Windows e falhariam no Ubuntu do workflow.

Task #202 resolvida.

---

## Notas técnicas

**`SegmentedButton` do Material não foi hand-rolled.** O widget do Material garante que a área tocável é a desenhada. Fichado como referência para a auditoria de hit target (Passo 2 da sprint 2): o problema a perseguir é o padrão `Container colorido + InkWell menor por dentro`, que é o oposto.

**`copyWith` com sentinela** mantido em todos os modelos novos — `?? this` não foi introduzido.

**`TextEditingController.dispose`** chamado depois de `Navigator.pop` retornar, não durante a animação de fecho. Nos três diálogos isso resolveu-se pondo os controladores num `StatefulWidget` que é dono deles — quem os descarta é o `dispose` dele, não a função que abriu o diálogo.

**Teste que mede, em vez de teste que não estoura.** Dois testes do hit target nasceram a verificar que tocar "não lançava excepção" — o que um toque falhado também não lança. Foram substituídos por comparação de geometrias. A regra que ficou: se a assertion não mede o que o utilizador vê, apaga-se e reescreve-se.

**Uma nota sobre a exactidão deste documento.** A primeira versão descrevia cinco coisas que não correspondiam ao código: subsídios de férias e Natal na `estimarSalarial` (estão fora do modelo, deliberadamente); o `totalCents` a "assumir ENI" (ignorava a TSU, que é outra coisa); o `OrientacaoDoContexto` como wrapper (é helper estático — o wrapper era o `PhoneOrientationLock`, que foi apagado); um terceiro vínculo "estágio" (há dois); e o `MaisDados` a recolher campos (não recolhe nada, explica). Ficam corrigidas acima. Um doc de desenho errado é pior do que doc nenhum, porque é citado com confiança.

---

## O que falta para fechar a v0.0.6

Ver `docs/CHECKLIST_v006_ATE_FIM.md` — Prioridade 1:

- ~~Passo 2 · Auditoria hit target~~ — feito (`60ed6f2`)
- ~~Passo 5 · Popup Perfil minimalista~~ — feito (`f23ee02`)
- Passo 7 · Release: bump, merge main, tag v0.0.6, APK, catalogar em `versoes_apps`

---

## Próximo

Sprint 2 do colaborador (self-service da ficha fiscal): `prompts/punho_v006_sprint2_colaborador_selfservice.md`

Arquitectura da sidebar (Decisão 2): `prompts/punho_v007_A.md` → `B.md` → `C.md`
