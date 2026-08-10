# Handover — Fase 3 (parcial), um só motor de sincronização

**Data:** 10 de Agosto de 2026
**Branch:** `fase3/um-so-sync` (empurrado)
**Porque é parcial:** a sessão chegou aos 200 K de contexto no fim do passo 1
e meio do passo 2. Fecha-se aqui e continua-se em sessão nova a partir deste
ficheiro — a regra que o `AGENTS.md` ganhou ontem, a servir pela primeira vez.

**Estado dos testes: 4 vermelhos, de propósito.** Todos em
`test/core/sync/painel_pelo_instantaneo_test.dart`. Não fazer merge para `main`
antes do passo 2 estar feito.

---

## O que fez

### `ea3fa21` — lado do servidor: três migrations, **aplicadas em produção a 10 Ago**

| Ficheiro | O quê |
|---|---|
| `20260810150000_punho_painel_tabela_propria.sql` | tabela `punho_painel` (PK `empresa_id`, `dados`, `updated_at`, `revision`, `actualizado_por`), RLS só do gestor, SELECT/INSERT/UPDATE, sem DELETE, sem gatilho; função `punho_painel_gravar(jsonb, timestamptz)` com a guarda de ordem |
| `20260810151000_punho_transicao_entidades_do_instantaneo.sql` | passa ao registo as entidades que só existam no instantâneo; coluna `punho_empresas.entidades_migradas_em`; função `punho_migrar_entidades_do_instantaneo(uuid)`; bloco `do $$` que corre para todas as empresas |
| `20260810152000_punho_instantaneo_deixa_de_projectar_entidades.sql` | cai o gatilho `punho_estado_operacional_projectar` e a `punho_projectar_ficha`; `punho_reprojectar_empresa` passa a reconstruir só do registo |

Mais `20260810153000_punho_transicao_revoke_de_public.sql`, que corrige um erro
da 151000 — ver «o que descobriu».

Todas reversíveis, com o como-desfazer escrito no topo do próprio ficheiro.

**A ordem de aplicação importa:** 150000 → 151000 → 152000 → 153000. A
transição tem de correr antes de o gatilho cair.

**Aplicadas em produção a 10 Ago 2026.** Contagens antes e depois, por empresa:
idênticas em todas as oito entidades e nas operações. A transição criou **zero**
operações (não havia nada só no instantâneo, como o mapa previa) e marcou as
duas empresas em `entidades_migradas_em`. Depois disso:

- gatilho `punho_estado_operacional_projectar`: **não existe**;
- funções `punho_projectar_ficha` e `punho_estado_operacional_projectar`: **não existem**;
- gatilhos que restam em `punho_estado_operacional`: **zero**;
- gatilho `punho_operacoes_projectar`: **de pé**, como tem de estar;
- `punho_painel`: existe, 3 políticas, DELETE revogado, zero linhas.

### `c963c03` — lado da app (WIP)

`lib/data/repositories/operation_repository.dart`:

- `_operationalPayload()` partido em `_payloadLocal()` (disco: tudo) e
  `_payloadDaFicha()` (servidor: só `onboarding` + `historicalMonths`);
- `exportOperationalPayload()` passa a usar `_payloadDaFicha()`;
- `_persist()` usa `_payloadLocal()`;
- `_applyData` ganha `ignorarPainel`, e `importOperationalPayload` passa-lho.

`flutter analyze`: limpo. `flutter test`: **1086 passam, 4 falham.**

---

## O que ficou por fazer

### ~~Passo 2 — o canal do painel~~ **feito**

`lib/core/sync/sincronizacao_do_painel.dart`, ligado em
`operations_controller.dart` (`_sincronizarPainel`, a seguir ao instantâneo e
fora do `if` dele). `savePainel` deixou de chamar `_markDirty()`; o painel
saiu do payload da ficha e o remendo que o repunha na importação desapareceu
com a razão que o fazia existir. Testes em
`test/core/sync/canal_do_painel_test.dart` (21), incluindo o que falha se o
painel voltar ao payload da ficha. **1099 passam, zero vermelhos.**

O que segue está por fazer.

<details><summary>O plano original do passo 2, para memória</summary>

Falta o lado da app. A tabela e a função já existem em `ea3fa21`. É preciso:

1. **`lib/core/sync/sincronizacao_do_painel.dart`** — classe
   `SincronizacaoDoPainel`, com o feitio das outras: `Future<...> sincronizar()`.
   - descer: `select dados, updated_at, revision from punho_painel where empresa_id = ...`
   - subir: `client.rpc('punho_painel_gravar', params: {'p_dados': ..., 'p_updated_at': ...})`
   - a função devolve **a linha como ficou**, que pode ser a que já lá estava
     se a guarda de ordem tiver barrado a escrita. Quem chama tem de olhar
     para o que voltou, não assumir que ganhou.
2. **Ligar ao ciclo** — hoje o painel sobe por `_painelPorSubir` +
   `_markDirty()` no instantâneo (`operation_repository.dart:650-654`). Esse
   caminho tem de passar a chamar o canal novo. Atenção ao
   `operations_controller.dart:1018-1025`, que recarrega o painel do
   repositório depois de sincronizar.
3. **Reescrever `test/core/sync/painel_pelo_instantaneo_test.dart`** — é o
   ficheiro dos 4 vermelhos. Muda de nome também: já não é «pelo instantâneo».
   Os casos a preservar, porque cada um custou um bug: *ausente não é vazio*;
   *esvaziar de propósito continua a chegar*; *a janela entre arrumar e
   sincronizar*; *gravar uma máquina não põe o painel a subir*.
4. **Teste que falhe se o painel voltar ao payload da ficha** — pedido
   explícito do César no passo 2.

</details>

### Passos 3 a 7, por tocar

- **3** — feito no servidor; falta **aplicar** e colar as contagens antes/depois,
  empresa a empresa.
- **4** — a parte da app está feita (`c963c03`); falta aplicar a migration.
- ~~**5 — nomes.**~~ **feito.** `SincronizacaoEntreDispositivos` →
  `SincronizacaoOperacionalPorOperacoes` e `SupabaseOperationalSync` →
  `SincronizacaoFichaEmpresa`, ficheiros incluídos (`git mv`, o histórico
  segue). Mais `exportOperationalPayload`/`importOperationalPayload` →
  `exportarFichaDaEmpresa`/`importarFichaDaEmpresa`: diziam *operational*, que
  é a palavra do outro canal, e devolviam só a ficha. Os doc-comments das duas
  classes foram reescritos — o da ficha prometia «o estado completo exclusivo
  do gestor», que deixou de ser verdade.
- **6 — teste de fronteira.** `test/core/sync/fronteira_dos_canais_test.dart`
  (o nome já está citado no doc-comment de `_payloadDaFicha`). Tem de falhar se
  um fluxo da ficha invocar importação ou substituição de máquinas, reservas ou
  finanças.
- **7 — a perda silenciosa.** `sincronizacao_ficha_empresa.dart`, no ramo em que
  a revisão remota difere: importa e descarta o local sem avisar. O teste
  `o_servidor_manda_test.dart:99-118` consagra isso. Corrigir os dois. No
  mínimo: guardar o payload descartado e dizê-lo ao utilizador — a aba Estado
  da Empresa já é o sítio onde os conflitos de reserva aparecem (Fase C), e é o
  sítio natural para isto.

### A prova final, que é a única que conta

Dois telemóveis, gestor e operador: o operador entrega uma máquina; o gestor
altera os custos fixos; **a reserva não volta atrás**. Screenshots dos dois
lados. Nenhum teste unitário substitui isto — foi assim que a avaria de 4 de
Agosto passou despercebida.

---

## O que descobriu pelo caminho

1. **O diagnóstico de partida estava certo na causa e desactualizado no
   sítio.** As linhas são `730-766`, não 703-706. E, mais importante: **a app
   já não importa entidades do instantâneo** — `importOperationalPayload` passa
   `apenasDadosDaEmpresa: true` e o corte está em `_applyData`. A correcção de
   4 de Agosto está feita na descida. O buraco era só na **subida**: as
   entidades subiam à boleia do payload e o gatilho projectava-as.

2. **As entidades subiam sem ninguém as ter posto a subir.** Estavam no payload
   por causa do disco — `_persist()` e `exportOperationalPayload()` partilhavam
   o mesmo método. Ninguém decidiu enviá-las; ninguém as lia de volta. É o
   género de acidente que um nome partilhado produz sozinho, e é por isso que o
   passo 5 não é cosmético.

3. **Não há nada para migrar.** Verificado na produção por id, não por
   contagem: nenhuma entidade existe só no instantâneo, nas duas empresas, em
   nenhuma das oito listas; as comuns têm `dados` idêntico. A chave `painel`
   não existe em nenhum instantâneo de produção — a Fase C ainda não chegou aos
   telemóveis, e a tabela nova nasce vazia.

4. **O risco é prospectivo, não retrospectivo.** A avaria ainda não aconteceu
   em produção. Mas o instantâneo do Aluguer Nogueira tem **2 reservas contra 8
   nas tabelas**, e é de 9 de Agosto: a primeira gravação de custos fixos com a
   cópia local atrasada faz aquelas duas voltar atrás.

5. **`punho_projectar_ficha` nunca projectou ficha nenhuma** — projectava
   entidades a partir da ficha. O nome enganou-me na primeira leitura e é
   provável que tenha enganado quem lá mexeu antes.

6. **`revoke ... from authenticated, anon` não revoga nada.** O Postgres dá
   `EXECUTE` a **PUBLIC** em cada `create function`, e revogar dos dois papéis
   nominais deixa o de PUBLIC de pé — `authenticated` continua a poder executar
   por ser membro de PUBLIC. No ACL vê-se como `=X/postgres`: um `=X` sem papel
   à esquerda é PUBLIC. A `punho_migrar_entidades_do_instantaneo` é `security
   definer` e recebe `p_empresa` como argumento, portanto qualquer sessão
   autenticada podia mandá-la correr sobre a empresa de outra pessoa. Corrigido
   em `20260810153000`. **Correr `get_advisors` a seguir a cada migration que
   crie funções** — foi o que apanhou isto, minutos depois de aplicar.

7. **A projecção não tem guarda de ordem em lado nenhum**, nem no canal das
   operações. Ali é menos grave porque o carimbo é `feito_em` (o momento do
   facto) e não `now()`, mas uma operação que chegue muito atrasada continua a
   poder reescrever uma entidade mais recente. Fora do âmbito desta fase —
   fica assinalado.

---

## Como continuar

```bash
cd ~/punho
git checkout fase3/um-so-sync
git log --oneline main..HEAD          # ea3fa21, c963c03 e este ficheiro
flutter test 2>&1 | tail -3           # tem de dar 1086 +4 falhas, nada mais
```

Próximo passo concreto: `lib/core/sync/sincronizacao_do_painel.dart`, contra a
tabela e a função que já estão em `ea3fa21`.

**Estado da produção** (projecto Supabase `oefqbkhioncakojipqyx`), para não ter
de o redescobrir:

| Empresa | revisão | instantâneo | reservas snap/tabela | operações |
|---|---|---|---|---|
| Aluguer Nogueira | 2 | 9 Ago | **2 / 8** | 29 |
| Lavandaria Nocturna (teste) | 1 | 10 Ago | 0 / 6 | 56 |

A query que prova que não há nada só no instantâneo está no cabeçalho de
`20260810151000_punho_transicao_entidades_do_instantaneo.sql`.

**As duas migrations pendentes da Linha A** (`20260810140000` e
`20260810_punho_ficha_por_id_local_e_reabrir_acesso`) continuam por aplicar —
herdadas da Fase C e ainda por decidir.
