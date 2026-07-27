# Punho v0.0.6 — sprint 2 (fecho da 0.0.6 + release)

> **Continua na branch `feat/v006-boas-vindas`.** A sprint 1 entregou
> Frente A (Boas-vindas + MaisDados), motor fiscal e Frente D (KPI
> custo real com pessoal). Faltam os follow-ups apanhados no smoke,
> as Frentes C UI e B popup, o doc, e o corte da release v0.0.6.
>
> Sete frentes por ordem obrigatória de execução — os passos 1 e 2
> desbloqueiam o smoke do Cesar, portanto fazem-se primeiro. A F e a
> G só depois de A-E verdes.

## Padrões a manter (regras não negociáveis)

Aplicáveis a tudo o que se escreve nesta sprint.

- `copyWith` com sentinela em vez de `?? this`. Anti-pattern P2-5
  apanhado duas vezes; se um campo pode ficar `null`, o `copyWith`
  recebe sentinela ou objecto `Campo<T>`.
- `TextEditingController.dispose` **depois** de `Navigator.pop`
  retornar, não durante a animação de fecho.
- `DialogoDeFormulario` de `lib/core/layout/` — usar em diálogos com
  mais de 3 campos ou abertos em telemóvel.
- Ficheiros de screenshot com `@Tags(['screenshot'])` para o CI
  excluir (task #202).
- `RegimeFiscal` como parâmetro obrigatório de qualquer função nova
  de estimativa fiscal (Decisão 1).

## Passo 1 · Correcção de orientação (Decisão 13)

**Bug apanhado pelo Cesar:** o passo 4 do onboarding aparece em
landscape. Deveria ser portrait, tal como todo o onboarding e o shell
do colaborador. Landscape só depois de o gestor entrar na app.

**Regra única, sem excepções:**

| Contexto | Orientação |
|---|---|
| Login / registo | Portrait lock |
| Onboarding inteiro (todos os passos + `MaisDados` + `BoasVindas`) | Portrait lock |
| Shell do colaborador | Portrait lock (já estava assim) |
| Shell do gestor (após `completeOnboarding` + tap "Entrar na Punho") | Landscape lock |

**Um só ecrã em toda a app leva landscape — o shell do gestor
autenticado.** Todos os outros são portrait.

**Fix:**

1. Remover do `main.dart` qualquer `SystemChrome.setPreferredOrientations`
   global. A app arranca sem forçar orientação.
2. Novo helper `OrientacaoDoContexto` em `lib/core/orientacao/`:
   ```dart
   class OrientacaoDoContexto {
     static Future<void> forcarPortrait();
     static Future<void> forcarLandscape();
     static Future<void> libertar();
   }
   ```
3. Cada rota chama o apropriado no `initState`:
   - `LoginScreen`, `RegistoScreen`, `OnboardingPage`,
     `MaisDadosScreen`, `BoasVindasScreen`, `CollaboratorShell` →
     `forcarPortrait()` no `initState`.
   - `AppShell` do gestor → `forcarLandscape()` no `initState`.
4. `BoasVindasScreen` reformulado:
   - `initState` chama `forcarPortrait()`.
   - `onPressed` do "Entrar na Punho" chama `forcarLandscape()`
     **antes** de navegar.
   - Reescrever o texto do convite a rodar: em vez de *"roda o
     tablet"*, agora *"a partir daqui a Punho vai passar a modo
     horizontal — o teu tablet vai rodar sozinho"*.
5. Reformular os testes:
   - O teste que confirmava que o `BoasVindasScreen` **não** chamava
     `setPreferredOrientations` **inverte-se** — agora exige que force
     portrait.
   - Novo teste do `AppShell`: força landscape no `initState`.
   - Novo teste do `CollaboratorShell`: força portrait no `initState`.

## Passo 2 · Auditoria transversal do hit target dos botões (task #206)

**Regra:** área que recebe o toque (`InkWell` / `GestureDetector` /
`onPressed`) **coincide exactamente** com a área desenhada colorida
(`Container` com `BoxDecoration`). Sem zonas coloridas que não
clicam, sem hit target menor que o desenho.

Auditar todos os botões primários da app:

- BoasVindasScreen (o "Entrar na Punho")
- MaisDadosScreen
- Passos do onboarding (`Continuar`)
- `DialogoDeFormulario` (Cancelar / Guardar)
- Cards de acção do Dashboard
- Botões de chip do estado da máquina
- Botões "Cobrar" e afins no Slide 1

**Padrão correcto** (usar em todos):

```dart
Material(
  color: laranja,
  borderRadius: raio,
  child: InkWell(
    borderRadius: raio,
    onTap: acao,
    child: Padding(
      padding: paddingInterno,
      child: Text('Continuar'),
    ),
  ),
)
```

O `Material` desenha a cor, o `InkWell` recebe o toque com a mesma
bounding box. `Padding` externo (se houver) fica **fora** do `Material`
— aí sim é espaço não-clicável.

Widget test para os principais: `tester.tap(find.byWidget(botao),
warnIfMissed: false)` no canto de dentro do desenho tem que disparar
`onPressed`. Se falhar, o layout está com camadas trocadas.

## Passo 3 · Follow-up Decisão 12 · `CustosMes.totalCents` sensível ao regime

**Contexto:** a Frente D da sprint 1 entregou o KPI "Custo real com
pessoal" (1.361 € com TSU patronal). Mas o card "Custos sobre a
receita" no mesmo slide continua a somar o pessoal a 1.100 € (bruto
sem TSU) — o agregador `CustosMes.totalCents` não é sensível ao
regime.

**Fix:** tornar `CustosMes.totalCents` sensível ao regime. O total
tem que bater com o card de detalhe.

**Consequência aceite:** a recomendação *"custos críticos ≥80%"* passa
a disparar mais cedo. Isso é a **verdade** do negócio (dinheiro que
sai mesmo), não regressão. O guião regista isto como Decisão 12.

**Testes:** adicionar caso fixture onde bruto = 1.100 €, TSU patronal
23,75% aplicada, `totalCents` esperado = 1.361 € (ajustar aos números
já usados nos testes da Frente D).

## Passo 4 · Frente C UI · Ficha fiscal do colaborador

Motor já entregue na sprint 1 (`estimarSalarial`, `RegimeFiscal`,
`Collaborator` com 5 campos novos). Falta a UI:

- `FichaFiscalColaboradorForm` como widget reutilizável em
  `lib/features/workforce/presentation/ficha_fiscal_form.dart`.
  Serve o `_collaboratorDialog` do gestor **e** (na sprint 3
  self-service) o shell do colaborador. Nasce com esse duplo uso em
  mente.
- `SegmentedButton` no topo do `_collaboratorDialog` para
  `EmploymentType.recibosVerdes` vs `contrato`. Campos condicionais
  conforme o tipo (ver spec original em
  `prompts/punho_v006_sprint1_boas_vindas.md` Frente C — a parte de
  campos condicionais mantém-se, só faltava a UI).
- Bloco read-only "Estimativa" com três linhas (Líquido para o
  trabalhador · TSU patronal · **Custo total para a empresa**
  destacado). Aviso obrigatório: *"Estimativa. Confirma com o teu
  contabilista antes de folhas oficiais."*
- Sub-linha condicional na `CollaboratorsPage` conforme tipo
  contratual.
- Chip âmbar `NISS em falta` se contrato sem NISS; `NIF em falta` se
  recibos verdes sem NIF. Ambos entram em Tarefas.

Aplicar sempre a directiva da Decisão 1: o `RegimeFiscal` já é lido
do `OnboardingData.legalForm` pelo motor. Nada de assumir Lda.

Testes: os que estavam previstos no prompt original da sprint 1
Frente C. Screenshots: `funcionario_dialogo_contrato.png`,
`funcionario_dialogo_recibos_verdes.png`,
`funcionarios_lista_dois_tipos.png`, `tarefas_niss_em_falta.png`.

## Passo 5 · Frente B · Popup Perfil minimalista

Versão minimalista já explicada em
`prompts/punho_v006_sprint1_boas_vindas.md` (secção "Frente B — Popup
Perfil (versão minimalista desta sprint)"). Reler antes de arrancar
para não construir a `ContaScreen` unificada por inércia. Resumo:

- Tocar no avatar da sidebar abre `showDialog` pequeno (não página
  nova).
- Conteúdo: avatar + nome + email + chip `SESSÃO ACTIVA` /
  `MODO DEMONSTRAÇÃO` + botão `Terminar sessão` com confirmação
  (só em modo Supabase) + rodapé com versão da app.
- Sem edição de dados da empresa (isso é Empresa → Dados na sprint
  dedicada da Decisão 2, task #199).
- Sem convite WhatsApp (idem).
- Redirecção pós-logout: deixar `AuthGate` fazer o trabalho —
  `ref.invalidate(acessoProvider)` no fim do `signOut` se necessário.
- Testes: os previstos no prompt original.

## Passo 6 · Doc `docs/design/punho_v006_sprint1.md`

Racional das 4 frentes entregues na sprint 1 e das 5 desta sprint 2.
Screenshots. Notas das decisões que afinaram durante a implementação
(Decisões 12 e 13 aplicadas, orientação, hit target).

## Passo 7 · Release v0.0.6 (Frente E)

Só arrancar depois de 1-6 verdes.

### 7.1 · Commitar tudo o que está por commitar

`git status` completo — reporta a lista antes de tocar. Autorização
geral do Cesar: **commita tudo o pendente**, agrupado por tema.
Se aparecer chave/token/backup, pára e reporta.

### 7.2 · Bump

`pubspec.yaml`: bump para `0.0.6+6`. Commit:
`chore(release): bump 0.0.6+6`.

### 7.3 · Merge em main

- `git checkout main`
- `git merge --no-ff feat/v006-boas-vindas`
- Mensagem: `release: v0.0.6 — motor fiscal + custo real + boas-vindas + follow-ups`.

### 7.4 · Tag

`git tag -a v0.0.6 -m "Punho v0.0.6 — motor fiscal, custo real com
pessoal, ecrãs de contexto no onboarding, orientação certa por
contexto"`.

### 7.5 · Push (pede autorização ao Cesar antes)

- `git push origin feat/v006-boas-vindas`
- `git push origin main`
- `git push origin v0.0.6`

### 7.6 · APK

O workflow `Release Punho` do GitHub Actions falha hoje por causa
dos testes de screenshot no CI (task #202). Duas opções:

- **A** — resolver a #202 antes de correr o workflow: `@Tags(['screenshot'])`
  nos ficheiros de screenshot + `flutter test --exclude-tags=screenshot`
  no `.github/workflows/release.yml`. O workflow passa e publica
  sozinho.
- **B** — publicar à mão (como na v0.0.5): `flutter build apk
  --release` + `gh release create v0.0.6 …` com notas.

Faz **A**. É trabalho pequeno (10 min) e desatasca o workflow para
todas as próximas releases. Se por algum motivo ficar difícil, cai
para B — a v0.0.5 saiu assim, sabemos que funciona.

### 7.7 · Notas de release

`docs/release_notes/v006.md`:

### 7.8 · Catalogar versão no Control (auto-update)

**Sem este passo, a v0.0.5 nunca sabe que existe v0.0.6.** O
`PunhoUpdateBannerWrapper` está bem ligado à raiz da app, mas a Edge
Function `versao-mais-recente` só devolve `actualizacao_disponivel:
true` se houver linha em `versoes_apps` (projecto Supabase
`oefqbkhioncakojipqyx`, mesmo do Control).

Historicamente as v0.0.3/0.0.4/0.0.5 nunca foram catalogadas — daí
ninguém ter recebido banner. Aproveitar esta release para reatar o hábito.

**Executar via MCP Supabase (Cowork faz isto em paralelo depois do 7.6):**

Ficheiro template: `prompts/punho_v006_7_8_catalogar_versao.sql`. Substituir
`<URL_APK>` e `<NOTAS>` e correr. Não é preciso desactivar linhas antigas
(o `order by build_number desc limit 1` da EF trata disso).

**Verificação:** a mesma query que a EF corre está no fim do template.
Deve devolver `versao='0.0.6'`, `build_number=6`.

**Nota para a 0.0.7:** este passo devia estar no próprio workflow de
GitHub Actions (INSERT automático depois do release publicado, com secret
service-role do Control). Ficou como task no backlog para não voltar a
depender do bom instinto de quem publica.

- Motor fiscal com `RegimeFiscal` — tabelas IRS 2026 dimensão × regime.
- KPI "Custo real com pessoal" no Dashboard (com TSU patronal a somar
  correctamente).
- Modelo contratual do colaborador (recibos verdes vs contrato) com
  ficha fiscal (NISS, estado civil, dependentes, NIF).
- Ecrãs `MaisDados` e `BoasVindas` no onboarding.
- Popup Perfil no avatar (identidade + terminar sessão).
- Orientação certa por contexto (portrait no onboarding e colaborador,
  landscape só no gestor autenticado).
- Higiene: hit target = área colorida em todos os botões,
  `CustosMes.totalCents` sensível ao regime.

## Não fazer nesta sprint

- Nada de novos destinos na sidebar. A arquitectura da Decisão 2
  (destino Empresa com tabs) fica para sprint dedicada (task #199).
- Nada de refactor do Dashboard em 9 slides (task #203).
- Nada de Tarefas como backlog priorizado (task #204).
- Nada de cadeado biometria (task #201).

## Gate

1. `flutter test` verde. Reportar contagem antes/depois.
2. `flutter analyze` limpo.
3. Screenshots renovados para C.
4. Doc `punho_v006_sprint1.md` escrito.
5. Passo 7: APK no GitHub Release, sha256 verificado, main com o tag.

## Entrega

Continua em `feat/v006-boas-vindas` até ao passo 7. Report frente a
frente (1 → 7). Push só com autorização explícita do Cesar (7.5).
