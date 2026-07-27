# Punho v0.0.7 — sprint 1 (arquitectura da sidebar · Decisão 2)

> **Ciclo novo: v0.0.7 ongoing.** Só fecha quando o Cesar disser.
> Sem push, sem bump, sem APK nesta sprint.
>
> **Branch nova a partir de `main`** (que agora tem a v0.0.6 estável):
>
> ```
> git checkout main
> git pull
> git checkout -b feat/v007-sidebar-empresa
> ```

## Porquê esta sprint em primeiro lugar

A **Decisão 2** do `docs/GUIAO_DE_PERCURSO_PRIMEIRO_EMPRESARIO.md`
define a arquitectura da sidebar como pré-requisito de tudo o que vem
a seguir: o refactor do Dashboard em 9 slides (task #203) depende de
os destinos operacionais estarem no sítio certo para os CTAs dos
slides-alavanca apontarem para eles; a `TarefasPage` priorizada
(task #204) precisa do destino `Tarefas` já estabilizado.

Materializar a sidebar primeiro tira do caminho todo o refactor
estrutural. Depois disto, os passos seguintes tocam em conteúdo, não
em navegação.

## Padrões a manter (regras não negociáveis)

Como na sprint 2 v0.0.6.

- `copyWith` com sentinela em vez de `?? this`.
- `TextEditingController.dispose` depois de `Navigator.pop` retornar.
- `DialogoDeFormulario` para diálogos com >3 campos.
- Ficheiros de screenshot com `@Tags(['screenshot'])`.
- `RegimeFiscal` como parâmetro obrigatório de estimativas fiscais.
- **Orientação por contexto** (Decisão 13): `AppShell` do gestor
  em landscape lock, tudo o resto em portrait lock.

## Sidebar final (Decisão 2)

**7 destinos sempre fixos:**

1. **Painel** (ex-`Gestão`)
2. **Máquinas**
3. **Reservas**
4. **Clientes** (contém: base + leads)
5. **Colaboradores** (ex-`Funcionários`)
6. **Empresa** (destino NOVO, agregador com abas)
7. **Tarefas** — sempre visível, com badge quando há pendências

**Perfil** no avatar como **popup** — já preparado pela sprint 1
v0.0.6 (Frente B minimalista, task #199 no sentido antigo já
absorvida pela sprint de release da 0.0.6). Confirmar que continua a
funcionar após a reorganização.

## Passo 1 · Renomeação global (nomes visíveis + nomes de código)

Renomear ao mesmo tempo em UI, código, testes, screenshots e docs.
Fazer com refactor tool do IDE **e** grep manual — o refactor
apanha símbolos, o grep apanha strings.

| Antes | Depois |
|---|---|
| `Gestão` | `Painel` |
| `Frota` | `Veículos` |
| `Funcionários` | `Colaboradores` |

Aplicar nos ficheiros esperáveis:

- `lib/features/shell/presentation/app_shell.dart` — rótulos da
  sidebar.
- `lib/core/navigation/app_destination.dart` (ou equivalente) — os
  enums / IDs de destino.
- `lib/features/dashboard/**` — cabeçalhos e títulos.
- `test/**` — strings de assertions.
- `docs/design/screenshots/v005/*.png` e `v006/*.png` — regenerar
  após a mudança.
- `docs/**` — grep pelos termos antigos e actualizar.

**Nota importante**: não renomear a `CollaboratorsPage` do código
(Dart class name); só o rótulo visível. Renomear a class implicava
migração de imports em cadeia sem valor pedagógico proporcional.

## Passo 2 · Novo destino `Empresa` com abas

**Novo widget** `lib/features/empresa/presentation/empresa_page.dart`
com `TabBar` + `TabBarView` para 6 abas iniciais:

1. **Dados** — nome, forma jurídica, NIF, morada, contactos.
   Consome o `EmpresaDadosForm` (extrair da `CompanySettingsPage`
   actual se ainda não foi; senão, reusar).
2. **Regime fiscal** — mostra o `RegimeFiscal` actual da empresa
   (obtido via `OnboardingData.legalForm` + eventual override
   manual). Botão "Alterar regime" que abre um selector com aviso
   sobre impacto nos KPIs (Decisão 1). Placeholder aceitável para
   já: apenas leitura + botão "Editar em Dados →" que salta para
   a aba Dados. O motor de mudança de regime é sprint separada.
3. **Custos fixos** — editor de gastos recorrentes mensais (Renda,
   Água+luz, Comunicações, Seguros, outros). Cada linha com
   descrição + valor. Total no fim. Persistido via
   `updateCompanySettings` estendido com `Campo<int>` para cada
   sub-categoria (não apenas o `fixedMonthlyCostsCents` agregado
   actual — a granularidade tem que ficar para alimentar o Slide de
   Margem / Slide de Tesouraria mais tarde).
4. **Veículos** — migração da `VehiclesPage` actual para dentro
   desta aba. O widget existente pode ser reusado quase
   directamente; só muda o ponto de entrada.
5. **Finanças** — migração do ecrã actual de despesas/recebimentos
   para dentro desta aba. Idem.
6. **Estado** — placeholder para futuras obrigações fiscais
   (IVA/IRC/TSU/IRS). Nesta sprint apenas título e uma linha
   *"Timeline de obrigações fiscais — em preparação para v0.0.8."*.

**Estrutura visual do `EmpresaPage`:**

```
AppBar
  Título: "Empresa"
TabBar (materializar visualmente as 6 abas em ícones + labels curtos)
  Dados | Regime | Custos fixos | Veículos | Finanças | Estado
TabBarView (Expanded, ocupa o resto)
```

## Passo 3 · Sidebar refeita

- Actualizar `app_shell.dart` para a ordem final:
  `Painel · Máquinas · Reservas · Clientes · Colaboradores · Empresa · Tarefas`.
- **Retirar** os destinos que migram para dentro de `Empresa`:
  `Veículos` (ex-`Frota`) e `Finanças` deixam de ser destinos da
  sidebar.
- Larguras e ícones seguem os padrões do 88 dp já estabelecidos na
  v0.0.5.
- Badge no `Tarefas` mantém-se.

## Passo 4 · Rotas e navegação

- Adicionar rota `Empresa`.
- **Rotas antigas** para `VehiclesPage` e ecrã de Finanças continuam
  a existir mas passam a navegar para `Empresa` com a aba pré-
  seleccionada (deep-link compatível). Preserva compatibilidade com
  code existente e permite CTAs futuros dos slides-alavanca apontarem
  directamente para `Empresa/Veículos` ou `Empresa/Finanças`.

## Passo 5 · Testes

- Widget test do `AppShell`: sidebar mostra 7 destinos, na ordem
  certa, com os novos rótulos.
- Widget test do `EmpresaPage`: 6 abas presentes; seleccionar cada
  uma mostra o widget certo.
- Widget test de deep-link: navegar directamente para
  `Empresa?tab=veiculos` abre a aba Veículos.
- Testes das páginas migradas mantêm-se a passar — apenas o ponto de
  entrada muda.

## Passo 6 · Screenshots

Regenerar screenshots afectados. Novos:

- `docs/design/screenshots/v007/sidebar_final.png` (7 destinos + rótulos novos).
- `docs/design/screenshots/v007/empresa_aba_dados.png`
- `docs/design/screenshots/v007/empresa_aba_regime_fiscal.png`
- `docs/design/screenshots/v007/empresa_aba_custos_fixos.png`
- `docs/design/screenshots/v007/empresa_aba_veiculos.png`
- `docs/design/screenshots/v007/empresa_aba_financas.png`
- `docs/design/screenshots/v007/empresa_aba_estado_placeholder.png`

Ficheiros com `@Tags(['screenshot'])` (task #202 já resolvida na
0.0.6).

## Passo 7 · Doc

`docs/design/punho_v007_sprint1_sidebar.md`:

- Racional da Decisão 2 já registada no guião.
- Antes/depois com screenshots.
- Notas técnicas (deep-links, refactor global de rótulos).
- Referência a `CHECKLIST_v006_ATE_FIM.md` para o que vem a seguir.

## Não fazer nesta sprint

- **Não** refactorizar o Dashboard em 9 slides — é sprint separada
  (task #203).
- **Não** implementar o motor fiscal completo (`RegimeFiscal` com
  todos os cálculos) — o placeholder da aba `Regime fiscal` chega
  para agora.
- **Não** implementar o cadeado biometria (task #201) — sprint
  separada da 0.0.7.
- **Não** implementar Tarefas priorizado (task #204) — sprint
  separada da 0.0.7.
- **Não** bump nem push nem APK — a 0.0.7 fica ongoing enquanto o
  Cesar não decidir cortar.

## Gate

1. `flutter test` verde. Reportar contagem antes/depois.
2. `flutter analyze` limpo.
3. Screenshots todos regenerados.
4. Doc escrito.
5. **Auto-teste manual (Code)**: percorrer a sidebar clicando em
   cada destino e cada aba de `Empresa` — reportar se algum link
   está partido ou navega mal.

## Entrega

Branch `feat/v007-sidebar-empresa`. Vários commits atómicos:

1. `refactor: renomear Gestão→Painel, Frota→Veículos, Funcionários→Colaboradores`
2. `feat: novo destino Empresa com estrutura de abas`
3. `feat: aba Empresa/Dados via EmpresaDadosForm`
4. `feat: aba Empresa/Custos fixos com granularidade`
5. `refactor: VehiclesPage migra para Empresa/Veículos`
6. `refactor: ecrã de Finanças migra para Empresa/Finanças`
7. `feat: placeholders para Regime fiscal e Estado`
8. `test/doc: cobertura + screenshots + doc de sprint`

Sem push, sem bump, sem APK. Report frente a frente no fim.
