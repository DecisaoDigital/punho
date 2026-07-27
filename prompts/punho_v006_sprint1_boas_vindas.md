# Punho v0.0.6 — sprint 1 (Boas-vindas + ecrã de conta + ficha do funcionário + KPI custo real)

> **Contexto do arranque:** a v0.0.5 fechou por completo (393 testes
> verdes, `feat/v005-dashboard-alavancas`, sem push). Ficaram três
> peças transversais para esta sprint aproveitar em vez de reinventar:
>
> 1. **`DialogoDeFormulario` em `lib/core/layout/`** — widget partilhado
>    que resolveu o problema de teclado/scroll nos três diálogos
>    (máquina, veículo, colaborador). O `_collaboratorDialog` desta
>    sprint 1 (Frente C, agora com `SegmentedButton` no topo e coluna
>    condicional) **usa-o directamente**. O mini-diálogo de convite
>    WhatsApp (Frente B) idem. Zero `AlertDialog` novo nesta sprint.
> 2. **Regra do `copyWith` com sentinela**, não `?? this` — anti-pattern
>    P2-5 apanhado pelo Code duas vezes já; se um campo tem de poder
>    ficar `null`, o `copyWith` recebe sentinela ou objecto `Campo<T>`.
>    Aplica-se a todos os modelos novos desta sprint (`EmploymentType`
>    no `Collaborator`, campos fiscais).
> 3. **`TextEditingController` descartados durante animação de fecho**
>    causaram três bugs na 0.0.5. Regra: `dispose` **depois** de
>    `Navigator.pop` retornar, ou usar `StatefulBuilder` que trata do
>    ciclo. Aplica-se ao mini-diálogo de convite da Frente B.


> **Ciclo novo: v0.0.6 ongoing.** Só fecha quando o Cesar disser. Sem
> push, sem bump, sem APK.
>
> **Branch nova a partir de `feat/v005-dashboard-alavancas`, não de
> `main`.** A 0.0.5 ainda não foi merged (o Cesar corta o release quando
> vir o report final da continuação). Sair de `main` deixaria esta
> branch sem os slides do dashboard, sem o novo onboarding, sem a nova
> sidebar — inconsistente e propenso a merges dolorosos depois.
>
> ```
> git checkout feat/v005-dashboard-alavancas
> git pull
> git checkout -b feat/v006-boas-vindas
> ```
>
> Quando a 0.0.5 for merged em `main`, a `feat/v006-boas-vindas` faz
> `git rebase main` (ou merge, à escolha) para ficar em cima da versão
> estável. Isso é depois.

Quatro frentes independentes. Commit por frente.

- **Frente A** — ecrãs `MaisDadosScreen` e `BoasVindasScreen` no fluxo
  de onboarding.
- **Frente B** — ecrã de conta (`ContaScreen`) ligado ao avatar da
  sidebar, com edição dos dados da empresa, convite WhatsApp e
  terminar sessão.
- **Frente C** — modelo contratual do funcionário (recibos verdes vs
  contrato), com os campos que cada modelo exige e estimativa de
  descontos do trabalhador quando aplicável.
- **Frente D** — novo KPI no Dashboard: "Custo real com pessoal"
  (bruto pago + carga social da entidade patronal), para o gestor ver
  o que sai *mesmo* da empresa e não só o vencimento base.

---

---

## Frente A — Boas-vindas + Mais dados

### Contexto

No onboarding actual (`_OnboardingPageState` em
`lib/features/operations/presentation/operational_pages.dart`) o passo 6
tem um switch `wantsFullSetup`:

- `false` → salta os passos 7-12 e chama `completeOnboarding` — o gestor
  cai directamente no dashboard.
- `true` → continua até ao passo 12, e no fim chama `completeOnboarding`
  do mesmo modo.

Nos dois casos o gestor **passa directo do último passo para o
dashboard**, sem transição. É seco e é uma oportunidade perdida: nunca lhe
foi explicado o que a app é nem o que vai encontrar.

### O que muda

Introduzir dois ecrãs de contexto no fluxo:

1. **`MaisDadosScreen`** — só quando o switch `wantsFullSetup == true`.
   Aparece **entre** o passo do switch e o primeiro passo dos dados
   detalhados. Explica ao gestor porque vale a pena preencher mais.
2. **`BoasVindasScreen`** — **sempre** o último ecrã antes de entrar na
   app, nos dois caminhos. Explica a proposta da Punho e prepara a
   transição para landscape.

#### Onde vive cada um

- Caminho curto (`wantsFullSetup == false`):
  `... → passo do switch → BoasVindasScreen → app`
- Caminho longo (`wantsFullSetup == true`):
  `... → passo do switch → MaisDadosScreen → passos 7-12 → BoasVindasScreen → app`

O `completeOnboarding` só é chamado depois do `BoasVindasScreen` (ao
tocar "Entrar na Punho"). Antes disso o utilizador pode voltar atrás com
o botão de voltar do `_PageFrame`.

### Textos (podes ajustar de forma suave, mas o tom fica)

#### `MaisDadosScreen`
```
Título: Óptimo. Vamos afinar isto.
Corpo:
Vais indicar mais alguns dados: colaboradores, veículos, máquinas e as
receitas do último ano.

Quanto mais completo, mais afinadas ficam as sugestões da tua semana —
onde estás a perder dinheiro, o que está parado, o que já podes cobrar.

Podes sempre voltar e editar em Definições da Empresa.

Botão: Continuar →
```

#### `BoasVindasScreen`
```
Título: Bem-vindo à Punho.
Corpo:
A Punho é o painel do teu negócio. Mostra o que entrou, o que saiu, o que
está por cobrar e o que fazer esta semana — em cinco vistas.

Não te preocupes se algum número aparecer como "por apurar": à medida que
usas a app, ela vai aprendendo o teu ritmo e melhorando as sugestões.

Ready?

Rodapé destacado (com ícone `Icons.screen_rotation`):
A partir daqui a Punho passa a modo horizontal — roda o tablet ou o
telemóvel para melhor aproveitamento.

Botão: Entrar na Punho →
```

### Regras de implementação

1. **Vertical até ao fim do onboarding.** O `SystemChrome.setPreferredOrientations`
   com landscape só é chamado depois do `completeOnboarding` (é onde a
   Frente da 0.0.5 já mete o lock). O `BoasVindasScreen` continua em
   portrait — a mensagem "roda o teu dispositivo" é o *cue* para o
   utilizador rodar antes de tocar em "Entrar na Punho".
2. **Não bloquear rotação no `BoasVindasScreen`.** Se o utilizador rodar
   antes de tocar no botão, o ecrã acompanha (fica landscape com o mesmo
   conteúdo). Isto valida ao gestor que a app já suporta o formato — dá
   confiança. Depois de tocar em "Entrar" é que o lock landscape entra.
3. **Botão "Voltar" continua a funcionar** no `_PageFrame` — o gestor
   pode desistir e corrigir dados até ao momento em que carrega em
   "Entrar na Punho".
4. **`completeOnboarding` só é chamado uma vez**, ao clicar "Entrar na
   Punho" no `BoasVindasScreen`. Se o gestor voltar atrás e voltar a
   avançar, não duplica.
5. **Copy em português-PT.** Sem emojis (ícones Material só).
6. **Não introduzir sinal "primeira sessão"** persistente — não faz
   parte desta sprint. O `BoasVindasScreen` é o que é: last-step do
   onboarding, não overlay recorrente.

### Alterações no código

#### Novos ficheiros
- `lib/features/operations/presentation/boas_vindas_screen.dart`
- `lib/features/operations/presentation/mais_dados_screen.dart`

Se preferires viver dentro do `operational_pages.dart` para reaproveitar
`_PageFrame`, tudo bem — o critério é: cada ecrã testável em isolamento
por widget test.

#### Alterações
- `_OnboardingPageState`: o cálculo de `titles`/`helps` e o `switch (index)`
  do build passa a considerar os dois novos ecrãs:
  - Caminho curto: 7 ecrãs (6 originais + `BoasVindasScreen`).
  - Caminho longo: 14 ecrãs (6 + `MaisDadosScreen` + 6 dados detalhados
    + `BoasVindasScreen`).
- O indicador "N de M" no cabeçalho reflecte o total do caminho actual
  (7 ou 14 conforme o switch).
- `_PageFrame`: os dois ecrãs novos **não têm** o cabeçalho "N de M" —
  são ecrãs de contexto, não passos de dados. Título grande + corpo +
  botão único. `Icon` grande no topo (uma mão para `BoasVindas`, um
  ícone de "adicionar dados" para `MaisDados`).

#### Testes

- Widget test `mais_dados_screen_test.dart`:
  - Botão "Continuar →" aparece.
  - Corpo contém "colaboradores, veículos, máquinas e as receitas".
- Widget test `boas_vindas_screen_test.dart`:
  - Botão "Entrar na Punho →" aparece.
  - Rodapé contém "modo horizontal".
  - Ao rodar o `MediaQuery` para landscape, o ecrã continua a compor
    (não crash, não overflow).
- Widget test do fluxo `_OnboardingPageState`:
  - Caminho `wantsFullSetup == false`: depois do switch, o próximo ecrã
    é `BoasVindasScreen` e não o passo 7 antigo.
  - Caminho `wantsFullSetup == true`: depois do switch, o próximo ecrã
    é `MaisDadosScreen`; depois dele, o passo 7 antigo; depois do 12,
    `BoasVindasScreen`.
  - `completeOnboarding` **não é chamado** enquanto o `BoasVindasScreen`
    não tiver o "Entrar na Punho" tocado.

#### Screenshots

- `docs/design/screenshots/v006/onboarding_mais_dados.png` (portrait)
- `docs/design/screenshots/v006/onboarding_boas_vindas.png` (portrait)
- `docs/design/screenshots/v006/onboarding_boas_vindas_landscape.png`
  (o mesmo ecrã depois de o utilizador rodar o dispositivo, para provar
  que compõe nos dois modos)

---

## Frente B — Ecrã de conta (`ContaScreen`) e terminar sessão

### Contexto

Hoje o avatar no fundo da sidebar (`app_shell.dart`) tem só um tooltip
("Sessão activa" ou "Demonstração local") e nada acontece ao tocar. Não
há forma de o gestor:

- ver quem está autenticado (email, nome, cargo, empresa),
- saber se está em sessão Supabase ou em modo demonstração local,
- terminar sessão para trocar de conta.

Buraco básico. Especialmente crítico quando o Cesar convidar o primeiro
não-admin: sem `logout` o dispositivo fica preso à conta antiga.

### O que muda

1. **Tocar no avatar da sidebar** abre `ContaScreen` — página dedicada,
   não popup (é conteúdo estruturado). Landscape, mesmo pattern das
   outras páginas do shell.
2. Novo ficheiro `lib/features/conta/presentation/conta_screen.dart`.
3. **Não** adicionar destino "Conta" na sidebar — o avatar é o ponto
   de entrada. Um só caminho.

### Conteúdo do `ContaScreen`

Três blocos, dispostos em duas colunas landscape (uma em portrait):

**Coluna esquerda · Cartão de identidade + acções**

- Avatar grande (círculo com iniciais do `ownerName` ou ícone
  `person_outline` em fallback).
- Nome do gestor (de `OnboardingData.ownerName`; fallback ao email).
- Empresa (de `OnboardingData.companyName`).
- Cargo (`gestor` / `colaborador` — do `EstadoAcesso.perfil`, ou "gestor
  (modo demonstração)" quando não há sessão).
- Email da conta (do `Supabase.instance.client.auth.currentUser?.email`;
  esconder linha em modo demonstração).
- Chip pequeno no topo direito do cartão: `SESSÃO ACTIVA` (verde) ou
  `MODO DEMONSTRAÇÃO` (cinza).
- **Botão principal: `Convidar por WhatsApp`** (`FilledButton.icon` com
  `Icons.chat_outlined`) — só se `eGestor` **e**
  `SupabaseConfig.enabled` (sem Supabase não há convites reais). Ver
  secção "Convite WhatsApp" abaixo.
- **Botão secundário: `Terminar sessão`** (`OutlinedButton` sobre
  `colorScheme.error`) — só se `SupabaseConfig.enabled &&
  auth.currentUser != null`. Em modo demonstração fica escondido, com
  uma linha explicativa: *"Estás em modo demonstração local — não há
  sessão para terminar."*
- Rodapé fino: versão da app (do `PackageInfo`), pequena e discreta.

**Coluna direita · Dados da empresa (editáveis inline)**

Todos os campos que hoje vivem em `CompanySettingsPage` aparecem aqui,
editáveis inline, num único `Form` scrollável — o gestor não precisa
de sair da conta para corrigir NIF ou morada.

Campos (ver `OnboardingData`):

- Nome comercial (`companyName`)
- Forma jurídica (`legalForm`)
- NIF (`companyTaxId`)
- Morada + código-postal + localidade (três campos)
- Telemóvel + email da empresa
- Nº de colaboradores + nº de veículos + nº de máquinas declaradas
- Receita ano anterior + receita ano actual + manutenção ano anterior +
  custos fixos mensais (todos `int? cents`)

Botões no fim do bloco:

- **`Guardar alterações`** — chama `updateCompanySettings` no
  controller (já existe). Snackbar `'Dados actualizados.'` em sucesso.
- **`Cancelar`** — restaura estado inicial dos controllers.
- Não-gestor: bloco fica em modo leitura, sem botões.

**Reutilizar código, não duplicar.** Extrair um widget
`EmpresaDadosForm` (novo, em
`lib/features/company/presentation/empresa_dados_form.dart`) que a
`CompanySettingsPage` **e** o `ContaScreen` consomem. Sem
`Copy&Paste`. Se o Cesar mais tarde quiser matar a
`CompanySettingsPage` (redundante), é uma linha.

### Convite WhatsApp

O `convites_screen.dart` já tem `mensagemConvite()` estático e
`_partilharWhatsApp()`. Reaproveitar — o novo botão do `ContaScreen`
faz o seguinte:

1. Toca no `Convidar por WhatsApp` → abre um mini-diálogo:
   ```
   Título: Convidar
   Campos:
     - Email da pessoa convidada (obrigatório)
     - Perfil: Gestor | Colaborador (dropdown, default Colaborador)
   Acções: [Cancelar] [Gerar e partilhar]
   ```
2. Ao "Gerar e partilhar":
   - Chama `AcessoService.criarConvite(email, perfil)` — já existe.
   - Compõe a mensagem com `mensagemConvite(codigo, empresa)` — já
     existe.
   - Abre o WhatsApp via `_partilharWhatsApp(mensagem)` — o link é
     `https://wa.me/?text={mensagem_url_encoded}`, o utilizador escolhe
     o contacto no app WhatsApp.
   - Se `criarConvite` falhar (rede, permissão), snackbar
     `'Não foi possível gerar o convite. Tenta outra vez.'`
   - Se `_partilharWhatsApp` falhar (WhatsApp não instalado), snackbar
     com o código copiado para o clipboard: `'Código {XYZ123} copiado.
     Partilha à mão.'`
3. Fecha o diálogo automaticamente depois do share.

Nada mais nesta sprint sobre convites — a lista completa continua a
viver na `ConvitesScreen` (para quando o gestor quiser ver todos os
que já emitiu).

### Terminar sessão — regras

1. Ao tocar, abre `AlertDialog` de confirmação:
   ```
   Título: Terminar sessão?
   Corpo:  Vais voltar ao ecrã de entrada. Os dados guardados neste
           dispositivo mantêm-se e podes voltar a entrar quando
           quiseres.
   Acções: [Cancelar] [Terminar sessão]
   ```
   `barrierDismissible: false`. Botão destrutivo com `colorScheme.error`.
2. Ao confirmar: chamar `ref.read(acessoServiceProvider).terminarSessao()`
   (já existe em `SupabaseAcessoService`).
3. **Depois de terminar**, o `AuthGate` já observa o estado da sessão e
   deve redireccionar para o `LoginScreen` sozinho — não invocar
   `Navigator` à mão daqui. Se por algum motivo isso não acontecer
   (o `AuthGate` só reage a `authStateChanges`), forçar o rebuild com
   `ref.invalidate(acessoProvider)` (ou provider análogo — usar o que
   já lá está).
4. `try/catch` à volta do `signOut`: se falhar, `SnackBar` com
   `'Não foi possível terminar sessão. Tenta outra vez.'` — não deixar
   o utilizador preso num diálogo estático.

### Testes

- Widget test do `ContaScreen`:
  - Modo Supabase (fixture com `EstadoAcesso.membroAtivo == true` e
    `auth.currentUser` mocked): mostra chip `SESSÃO ACTIVA`, linha de
    email, botões `Convidar por WhatsApp` e `Terminar sessão`.
  - Modo demonstração (sem Supabase): mostra chip
    `MODO DEMONSTRAÇÃO`, sem linha de email, sem botões de
    convite/terminar, com a linha explicativa.
  - Não-gestor: botão `Convidar por WhatsApp` não aparece;
    `EmpresaDadosForm` em modo leitura (sem `Guardar`/`Cancelar`).
- Widget test do `EmpresaDadosForm`:
  - Editar `companyTaxId`, tocar `Guardar` chama
    `updateCompanySettings` com o novo valor via `Campo`.
  - Tocar `Cancelar` restaura o valor inicial no controller.
- Widget test da acção terminar sessão:
  - Confirmação abre `AlertDialog` com título "Terminar sessão?".
  - Cancelar não chama `terminarSessao`.
  - Confirmar chama `terminarSessao` exactamente uma vez.
  - Erro no `terminarSessao` mostra o `SnackBar`.
- Widget test do convite:
  - Mini-diálogo abre com campo email vazio + perfil `Colaborador`.
  - Tocar `Gerar e partilhar` sem email → erro inline "Indica o email".
  - Com email preenchido → chama `criarConvite` e depois
    `_partilharWhatsApp` (mock do `url_launcher`).
  - `criarConvite` falha → snackbar de erro; diálogo continua aberto.
- Widget test da sidebar:
  - Tocar no avatar navega para `ContaScreen`.

### Screenshots

- `docs/design/screenshots/v006/conta_sessao_activa.png` (landscape,
  duas colunas — identidade + acções à esquerda, `EmpresaDadosForm` à
  direita)
- `docs/design/screenshots/v006/conta_modo_demonstracao.png` (landscape)
- `docs/design/screenshots/v006/conta_convidar_whatsapp.png` (mini-diálogo
  aberto com email preenchido)
- `docs/design/screenshots/v006/conta_terminar_sessao_confirmar.png`

### Fora do âmbito

- Não implementar mudança de foto de avatar — usa iniciais/ícone.
- Não implementar troca de password nem "esqueci-me da password" — é
  fluxo próprio, fica para outra sprint.
- Não implementar apagar conta (soft/hard delete) — fica para outra
  sprint com o devido cuidado legal (RGPD).
- Não tocar no `AuthGate` para além do que for necessário para a
  redirecção após logout funcionar.
- Não migrar / apagar `CompanySettingsPage` — fica no lugar, ambos os
  ecrãs partilham o `EmpresaDadosForm`. Consolidar num só destino é
  decisão de outra sprint depois do Cesar ver como se usam.
- Não replicar a `ConvitesScreen` inline no `ContaScreen` — o botão
  cria + partilha, ponto. Gestão da lista de convites fica no destino
  próprio.

---

## Frente C — Ficha do funcionário: modelo contratual + escalão de descontos

### Contexto

Hoje o `Collaborator` guarda nome, telefone, cargo, custo, horário. Só
isso. Para o gestor poder gerir a mão-de-obra de forma útil — e para a
Punho poder ajudar com números — a modelação precisa de reflectir o
que existe na realidade portuguesa: **dois tipos contratuais** com
custos e obrigações diferentes.

### Dois modelos contratuais

1. **Recibos verdes / prestador de serviços** (`recibosVerdes`).
   - O que a empresa paga é **bruto = custo total** (não há carga
     social da entidade patronal a somar; a retenção IRS na fonte é
     opcional consoante o rendimento do prestador, e mesmo essa é
     retenção, não custo adicional).
   - Do lado da app, os campos fiscais **do trabalhador**
     (NISS/estado civil/dependentes) **não são pedidos** — não afectam
     o custo da empresa.
   - Campos úteis: NIF do prestador (para a empresa emitir despesa),
     IBAN (para pagamento).

2. **Contrato de trabalho** (`contrato`).
   - Ao bruto acresce a **TSU da entidade patronal ≈ 23,75%**, que é
     o "custo carregado" que muitos gestores esquecem.
   - O trabalhador desconta IRS (por escalão) + TSU trabalhador 11%.
   - Campos pedidos: NISS, estado civil, dependentes (afectam a
     estimativa de líquido do trabalhador); IBAN, morada.

Também abre porta a passar dos "custos estimados" para uma leitura mais
próxima do que sai à empresa por cada funcionário, mês a mês.

> **Nota de arquitectura importante:** os campos que a Frente C
> introduz vão ser, na sprint 2 da 0.0.6, **preenchidos pelo próprio
> colaborador** no telemóvel dele (via o fluxo de convite + shell
> colaborador). O gestor deixa de escrever NISS/estado civil/filhos —
> só confirma no fim. Ver
> `punho_v006_sprint2_colaborador_selfservice.md` para o plano.
>
> Desenhar os widgets desta Frente C de forma **reutilizável**: o form
> tem de servir tanto no `_collaboratorDialog` (gestor edita alguém)
> como, na sprint 2, no shell do colaborador (colaborador edita a
> própria ficha). Extrair, portanto, um widget
> `FichaFiscalColaboradorForm` no primeiro commit e usá-lo nos dois
> sítios já a partir desta sprint (o do gestor).

### Novos campos em `Collaborator`
(`lib/domain/models/workforce.dart`)

- `EmploymentType employmentType` — enum novo com dois valores:
  `recibosVerdes`, `contrato`. Default `contrato` (mais comum).
  Labels PT: "Recibos verdes", "Contrato de trabalho".
- `String? socialSecurityNumber` — NISS. 11 dígitos em Portugal;
  guardar como texto para tolerar formatos (com/sem espaços). Validar
  no diálogo com regex simples `^[12]\d{10}$` e mostrar aviso não
  bloqueante se falhar ("NISS parece incompleto") — não impedir gravar.
  **Só pedido se `employmentType == contrato`.**
- `String? taxId` — NIF (só usado no caso `recibosVerdes`, para a
  empresa poder emitir a despesa correcta; validar 9 dígitos com
  aviso não bloqueante).
- `MaritalStatus maritalStatus` — enum novo:
  `unmarried`, `married1Holder`, `married2Holders`, `other`. Default
  `unmarried`. Labels PT: "Solteiro", "Casado — 1 titular",
  "Casado — 2 titulares", "Outro". **Só relevante se
  `employmentType == contrato`.**
- `int dependents` — nº de dependentes fiscais. Default `0`. Idem
  (só relevante se `contrato`).

Migração ao carregar (repositórios): campos ausentes ficam com o
default. `Collaborator` antigos ficam `employmentType == contrato`
para preservar a intenção original.

### `_collaboratorDialog` — campos condicionais pelo tipo

Absorver os campos no diálogo (já largo pela continuação da 0.0.5,
Frente diálogos). Layout em landscape passa a **duas colunas**:

- **Coluna esquerda (sempre)**: Nome, Telemóvel, Função, Custo,
  Periodicidade, Horas semanais + **`SegmentedButton` no topo** para
  escolher `Recibos verdes` / `Contrato de trabalho`.
- **Coluna direita (condicional pelo tipo)**:
  - Se `recibosVerdes`: NIF, IBAN, morada; bloco read-only "Custo
    total para a empresa = bruto × 1 (sem TSU patronal)".
  - Se `contrato`: NISS, Estado civil
    (`DropdownButtonFormField`), Nº dependentes (`TextField` numérico),
    IBAN, morada; bloco read-only "Estimativa de descontos e custo
    real" (ver secção seguinte).

Portrait mantém coluna única (segmented button no topo, seguido dos
campos que se aplicam).

**Widget reutilizável** `FichaFiscalColaboradorForm` (para a sprint 2
do colaborador auto-preencher) recebe `EmploymentType` e mostra só os
campos apropriados. Sprint 1 usa-o pelo lado do gestor; sprint 2
reusa pelo lado do colaborador sem mudar nada.

### Estimativa de descontos e custo real (read-only) — só para `contrato`

Novo bloco no diálogo (e na sub-linha da lista de colaboradores),
alimentado por uma função pura em `lib/core/finance/retencao_irs.dart`:

```dart
class EstimativaSalarial {
  final int brutoCents;
  final int tsuTrabalhadorCents;      // 11% do bruto
  final int? irsRetencaoCents;        // se sabemos o escalão
  final int liquidoTrabalhadorCents;  // bruto − TSU − IRS
  final int tsuEntidadePatronalCents; // 23,75% do bruto
  final int custoEmpresaCents;        // bruto + TSU patronal
  final String descricao;             // ex: "Casado 1 titular · 2 dependentes"
  final bool estimativaConservadora;
}

EstimativaSalarial? estimarSalarial({
  required EmploymentType tipo,
  required MaritalStatus estado,
  required int dependentes,
  int? brutoMensalCents,
});
```

Regras:

1. **Se `tipo == recibosVerdes`** → devolve estrutura simplificada:
   `custoEmpresaCents = brutoCents`, os campos de descontos e TSU
   patronal ficam `0`. O bloco na UI diz *"Recibos verdes: o valor
   pago é o custo total para a empresa. O prestador é responsável
   pelos próprios descontos."* Sem estimativas.
2. **Se `tipo == contrato`**:
   - **TSU trabalhador** = 11% do bruto.
   - **TSU entidade patronal** = 23,75% do bruto (constante em
     Portugal para a Segurança Social; excepção mais comum é a
     redução para pensionistas activos e regimes especiais — ficam
     fora, o gestor edita à mão se for o caso).
   - **IRS** estimado a partir de uma tabela **aproximada** por
     escalão em `references/tabelas_irs_2026.md` (Code cria com as
     tabelas do ano actual, marcadas como "aproximação, actualizar
     por ano"). Se bruto ausente, devolve estrutura com `irsRetencaoCents`
     e `liquidoTrabalhadorCents` a `null`, mas `custoEmpresaCents` já
     é calculável.
3. **Bloco na UI mostra três linhas**:
   - `Líquido para o trabalhador ~ X,XX €` (só se `contrato` + bruto)
   - `TSU entidade patronal (23,75%): +Y,YY €`
   - **`Custo total para a empresa: Z,ZZ €`** (destacado, o gestor
     precisa deste)
4. **Aviso obrigatório** por baixo do bloco: *"Estimativa. Confirma
   com o teu contabilista antes de usar para folhas de pagamento
   oficiais."*
5. **Nunca** guardar o valor calculado — recalcular no build. Se o
   Cesar quiser um override manual, é campo separado numa sprint
   futura.

### `CollaboratorsPage` — mostrar tipo, estado civil e custo total

Sub-linha do `ListTile` (que agora já tem vendas do mês da 4-D e
custo bruto) ganha uma segunda linha compacta, condicional pelo tipo:

- `contrato`: `Contrato · Casado 1T · 2 dep. · Custo real 1.485 €/mês`
- `recibosVerdes`: `Recibos verdes · Custo 800 €/mês`

Sinais visuais:
- Se `contrato && NISS == null`: chip pequeno âmbar "NISS em falta"
  à direita do nome, como sinal de dados incompletos.
- `NISS em falta` (só para `contrato`) entra em Tarefas — adicionar
  uma linha por colaborador sem NISS.
- Se `recibosVerdes && taxId == null`: chip âmbar "NIF em falta".

### Testes

- Unit test `estimarSalarial`:
  - Tipo `recibosVerdes`: `custoEmpresa == bruto`, sem TSU patronal,
    sem IRS. Bloco descritivo devolvido.
  - Tipo `contrato` com bruto 1.200 €: `tsuTrabalhador = 132 €`,
    `tsuPatronal = 285 €`, `custoEmpresa = 1.485 €`, IRS conforme
    escalão para cada `MaritalStatus` × dependentes.
  - Tipo `contrato` sem bruto: `custoEmpresa` null, `liquido` null.
- Widget test do `_collaboratorDialog`:
  - Alternar `SegmentedButton` esconde/mostra os campos apropriados
    sem perder estado no que fica visível.
  - Em `recibosVerdes`, NISS/estado civil/dependentes **não** existem
    na árvore; NIF existe.
  - Em `contrato`, o bloco de estimativa mostra três linhas com o
    "Custo total para a empresa" em destaque.
  - Introduzir NISS inválido (10 dígitos) → aviso amarelo mas permite
    gravar.
- Widget test da `CollaboratorsPage`:
  - Sub-linha condicional por tipo (contrato vs recibos verdes).
  - Chip âmbar "NIF em falta" em `recibosVerdes` sem NIF.
- Widget test da `TarefasPage`:
  - Fixture com dois colaboradores `contrato` sem NISS + um
    `recibosVerdes` sem NIF → três linhas em "Dados por completar".

### Screenshots

- `docs/design/screenshots/v006/funcionario_dialogo_contrato.png`
  (landscape, duas colunas, bloco de estimativa com custo total
  destacado)
- `docs/design/screenshots/v006/funcionario_dialogo_recibos_verdes.png`
  (mesmo diálogo com `SegmentedButton` em Recibos verdes; coluna
  direita mostra NIF+IBAN+morada e o bloco simplificado)
- `docs/design/screenshots/v006/funcionarios_lista_dois_tipos.png`
  (linha com contrato + linha com recibos verdes, cada uma com a sua
  sub-linha própria)
- `docs/design/screenshots/v006/tarefas_niss_em_falta.png`

### Fora do âmbito

- **Não calcular retenções oficiais** nem gerar recibos de vencimento
  — isso é folha de pagamento, é módulo próprio e requer
  responsabilidade legal.
- **Não integrar com SS/AT** (envio de descontos, comunicação de
  rendimentos) — ficamos em modo "estimativa privada".
- **Não modelar regimes especiais** (pensionistas activos com TSU
  reduzida, jovem trabalhador com isenção IRS, etc.) — usar `23,75%` e
  tabela IRS geral. Regimes especiais editam-se à mão no futuro.
- **Não guardar** valores estimados — sempre recalculados.
- **Não bloquear** a gravação de colaborador sem NISS/NIF — a app tem
  de aceitar dados parciais e sinalizar como pendente.

---

## Frente D — KPI "Custo real com pessoal" no Dashboard

### Contexto

Depois da Frente C, o `Collaborator` sabe o tipo contratual e cada
`contrato` sabe o `custoEmpresa` (bruto + TSU patronal 23,75%). Isto
transforma o "custo mensal" que o gestor vê hoje — que é só o bruto —
no que **sai mesmo da empresa**. É essa diferença que tem valor no
Dashboard.

### O que muda no Dashboard (`custos_slide.dart`)

- KPI actual "Custo colaboradores mês" passa a mostrar **duas linhas**:
  - Número grande: `Custo real com pessoal` = soma de
    `custoEmpresaCents` de todos os `contrato` + soma de bruto de
    todos os `recibosVerdes` (em recibos verdes, custo = bruto).
  - Sub-linha: `Bruto pago: X · TSU patronal: Y`, com o Y a mostrar
    quanto a Segurança Social leva à cabeça.
- Tendência vs mês anterior mantém-se (comparação com o mesmo cálculo
  no mês passado).
- Sparkline diária: só se justificar depois de o Cesar ver, esta
  sprint mantém o formato actual do KPI.

### Novos KPIs puros

- `custoRealComPessoalMes({required DateTime now, required
  List<Collaborator> colaboradores})` — devolve
  `({int bruto, int tsuPatronal, int total})`.
- `TodasMetricasPage` ganha três linhas novas na secção "Custos":
  `Bruto pago`, `TSU patronal (contratados)`, `Custo real com pessoal`.

### Testes

- Unit test do KPI:
  - Fixture com 2 contratados (bruto 1.000 € cada) + 1 recibos verdes
    (bruto 500 €) → `bruto = 2.500 €`, `tsuPatronal = 475 €`,
    `total = 2.975 €`.
  - Colaborador arquivado → não conta.
- Widget test do slide Custos:
  - Card mostra "Custo real com pessoal" com o valor `total`.
  - Sub-linha inclui "Bruto pago" e "TSU patronal".
- Widget test da `TodasMetricasPage`:
  - Três novas linhas na secção Custos com os valores esperados.

### Screenshot

- `docs/design/screenshots/v006/dashboard_custo_real_pessoal.png`
  (Slide 4 do dashboard, KPI actualizado)

### Fora do âmbito

- Não calcular custo real com pessoal **por trimestre / ano** — só o
  mês actual. Anual fica para depois.
- Não desagregar por colaborador no Dashboard — a lista detalhada é
  na `CollaboratorsPage`.
- Não incluir subsídios (férias, Natal) na estimativa — é aumento de
  ~16,7% médio sobre o bruto, mas depende do CCT e do tipo de
  contrato. Fica para sprint dedicada.

---

## Fora do âmbito global (as quatro frentes)

- Não tornar o ecrã de boas-vindas recorrente (overlay "primeira
  sessão do dia" etc.).
- Não colocar tutorial ou coach marks nos slides do dashboard — fica
  para outra sprint se decidirmos.
- Não mudar o texto do próprio switch nem os passos anteriores — só o
  que vem depois.
- Sem alterações a `completeOnboarding` do controller. Só o timing da
  chamada muda.

## Gate

1. `flutter test` verde. Reportar contagem antes/depois (esperado +24
   a +34 testes ao total das quatro frentes).
2. `flutter analyze` limpo.
3. Screenshots gerados (3 da Frente A + 4 da Frente B + 4 da Frente C +
   1 da Frente D).
4. Doc novo: `docs/design/punho_v006_sprint1.md` com racional das
   quatro frentes, fluxos e screenshots.

## Entrega

Branch nova `feat/v006-boas-vindas`, quatro grupos de commits:

- **Frente A**: 3 commits (um por widget + wire do fluxo).
- **Frente B**: 2 commits (widget `ContaScreen` + wire do avatar da
  sidebar). O `EmpresaDadosForm` reutilizável entra num terceiro
  commit próprio se ficar grande.
- **Frente C**: 3–4 commits (modelo + tabela IRS + `estimarSalarial` +
  `_collaboratorDialog` com `SegmentedButton`, ou split equivalente
  se ficar mais limpo).
- **Frente D**: 1–2 commits (KPI puro + wire no slide Custos +
  `TodasMetricasPage`).

Sem push, sem bump, sem APK. Report frente-a-frente no fim.
