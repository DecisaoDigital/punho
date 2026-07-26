# Punho v0.0.2 — contas por organização com aprovação manual

Desenho final da funcionalidade. Cobre só o lado Punho; a UI de aprovação vive
no Decisão Digital Control (repo separado).

**Princípio:** ter sessão Supabase não dá acesso a nada. A única prova de acesso
é uma linha activa em `punho_membros`, e essa linha só é criada pelo Control,
à mão, com service role.

---

## 1. Schema

### `punho_pedidos_acesso`

Criada em `20260730_punho_pedidos_acesso.sql`, completada em
`20260731_punho_contas_organizacao.sql`.

| Coluna | Tipo | Nota |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid unique → `auth.users` | um pedido por conta |
| `nome`, `email` | text | copiados dos metadados do registo |
| `empresa_indicada` | text not null | o que a pessoa escreveu, ou o nome da empresa do convite |
| `empresa_id` | uuid → `punho_empresas` | só preenchido em `origem = 'convite'` ou na aprovação |
| `perfil` | text | `gestor` \| `colaborador` |
| `origem` | text | `livre` \| `convite` |
| `convite_id` | uuid → `punho_convites` | delta |
| `estado` | text | `pendente` \| `aprovado` \| `recusado` \| `revogado` |
| `criado_em`, `actualizado_em`, `decidido_em` | timestamptz | `actualizado_em` por trigger |

Índice `(estado, criado_em)` para o Control paginar.

### `punho_convites`

| Coluna | Tipo | Nota |
|---|---|---|
| `id` | uuid PK | |
| `empresa_id` | uuid → `punho_empresas` on delete cascade | a do gestor que convidou |
| `email` | text not null | guardado em minúsculas |
| `perfil` | text | `gestor` \| `colaborador` |
| `codigo` | text unique | 10 hex maiúsculos, `gen_random_bytes(5)` |
| `criado_por` | uuid → `auth.users` | |
| `criado_em`, `expira_em` | timestamptz | `expira_em` = criação + 14 dias |
| `usado`, `usado_por`, `usado_em` | | uso único |

Índice único parcial `(empresa_id, lower(email)) where not usado` — um convite
activo por email e empresa.

### Vocabulário

O repositório já usava **`perfil`** (`punho_membros.perfil`,
`punho_pedidos_acesso.perfil`). A especificação escreve "cargo". Manteve-se
`perfil` em SQL e em Dart para não haver dois nomes para a mesma coisa; só o
rótulo visível na UI diz "Cargo pretendido". A RPC conserva o nome pedido,
`punho_criar_convite`, com parâmetro `p_perfil`.

---

## 2. Fluxo

### Registo

1. A app valida localmente: nome, email, palavra-passe ≥ 8, empresa não vazia.
2. Se há código de convite, chama `punho_validar_convite(codigo)` **antes** do
   signUp, para poder dizer *porquê* quando o código não presta.
3. `auth.signUp` com `data: {app: 'punho', nome, empresa, perfil, convite?}`.
4. O trigger `punho_criar_pedido_ao_registar()` em `auth.users` (após insert,
   `security definer`, `search_path = public`) filtra por `app = 'punho'` e:
   - **com código válido** → marca o convite usado, cria o pedido com
     `origem = 'convite'`, `empresa_id` e `perfil` do convite;
   - **com código imprestável** → `raise exception`, o registo é abortado;
   - **sem código** → cria o pedido com `origem = 'livre'` e sem `empresa_id`.

O pedido nasce no trigger e não numa chamada da app porque com confirmação de
email o utilizador pode só voltar dias depois — o pedido tem de existir na mesma
desde o primeiro momento.

### Entrada

`AcessoGate` (`lib/features/auth/presentation/auth_gate.dart`) consulta
`punho_meu_acesso()` — uma só ida ao servidor — e aplica `decidirAcesso()`:

| Situação | Ecrã |
|---|---|
| `membro_ativo = true` | `AppShell` |
| sem adesão, estado `pendente` ou `aprovado` | Pedido em análise |
| sem adesão, estado `recusado` ou `revogado` | Acesso indisponível |
| erro na consulta | Erro com "Tentar novamente" e "Terminar sessão" |

`decidirAcesso()` é uma função pura sem I/O — é onde a regra está testada.

### Convites

Um gestor com adesão activa abre **Convites** (ícone na AppBar / barra lateral,
escondido para quem não é gestor) e cria um código com
`punho_criar_convite(p_email, p_perfil)`. Não há envio de emails: a UI mostra o
código para copiar e partilhar por fora.

---

## 3. Segurança

### RLS

| Tabela | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `punho_pedidos_acesso` | o próprio; gestor aprovado vê os da sua empresa | — | — | — |
| `punho_convites` | gestor da empresa | — | — | — |

Sem policy é sem acesso: o cliente nunca escreve nestas tabelas. Inserir é
exclusivo do trigger e da RPC (`security definer`); aprovar, recusar e revogar
é exclusivo do Control com service role, que ignora RLS.

**Não há policy `DELETE` em lado nenhum.** Revogar é `estado = 'revogado'` mais
`punho_membros.ativo = false`; nunca apagar.

### Funções

Todas `security definer` com `set search_path = public`, `revoke ... from
public` e `grant execute` só a quem precisa:

| Função | Quem pode | Faz |
|---|---|---|
| `punho_meu_acesso()` | authenticated | adesão activa + perfil + estado do pedido |
| `punho_validar_convite(text)` | anon, authenticated | `valido`/`invalido`/`expirado`/`usado` |
| `punho_criar_convite(text, text)` | authenticated | exige `punho_e_gestor()`; cria para a empresa do caller |
| `punho_criar_pedido_ao_registar()` | trigger | cria o pedido no registo |
| `punho_nome_empresa_atual()` | authenticated | apoio à policy do gestor |

### Buraco fechado

`punho_criar_empresa_inicial(text)` (de `20260728`) estava com `grant execute to
authenticated`: **qualquer conta autenticada criava uma empresa e nomeava-se
gestora dela**, saltando por cima de toda a aprovação manual. A migration nova
revoga-a de `public`, `anon` e `authenticated`. Criar empresa passa a ser
exclusivo do Control, na aprovação de um pedido `origem = 'livre'`.

Na mesma migration fecham-se `punho_empresa_atual()`, `punho_e_gestor()` e
`punho_membro_ativo()`, que tinham ficado com o `execute to public` por omissão.

---

## 4. O que o Control tem de fazer (fase seguinte)

Com service role, portanto sem RLS pelo meio:

- **Aprovar `origem = 'convite'`**: `punho_membros` ganha a linha com o
  `empresa_id` e o `perfil` do pedido; `estado = 'aprovado'`.
- **Aprovar `origem = 'livre'`**: cria `punho_empresas` (e a subscrição com
  limite de utilizadores), preenche `empresa_id` no pedido, cria a adesão.
- **Recusar**: só `estado = 'recusado'`. Nada mais muda.
- **Revogar**: `estado = 'revogado'` **e** `punho_membros.ativo = false`.

⚠️ **`punho_membros` tem um índice único em `user_id` sozinho**
(`20260728_punho_auth_and_rls_hardening.sql:7-8`): um utilizador só pode ter uma
linha, mesmo inactiva. Reaprovar tem de ser `update ... set empresa_id = ...,
ativo = true`, **nunca** um segundo `insert` — rebentaria.

---

## 5. Casos de fronteira considerados

| Caso | Decisão |
|---|---|
| Contas anteriores a este modelo, sem pedido nenhum | A adesão activa manda. `punho_meu_acesso()` devolve `membro_ativo = true` e a app abre — não ficam trancadas de fora. |
| Pedido `aprovado` mas adesão ainda por criar | Fica em "Pedido em análise". A prova de acesso é `punho_membros`, não o estado do pedido. |
| Registo com código de outra pessoa | O trigger exige `lower(email) = lower(new.email)`: o convite é do email a que foi dirigido. |
| Código válido usado duas vezes | `usado = true` no primeiro registo, dentro da mesma transacção do `select ... for update`. |
| Convite expirado | Validado no `punho_validar_convite` (mensagem legível) e outra vez no trigger (rede de segurança para quem chame o signUp por fora). |
| Segundo convite para o mesmo email | A RPC marca o anterior por usar como consumido antes de inserir — o índice único parcial só admite um activo. |
| Convite para email já registado | O registo falha no signUp (email existe) e o convite fica intacto. |
| Expiração no índice único | `now()` não é imutável, não pode entrar no predicado. O índice cobre `not usado`; a expiração é validada em runtime. |
| Erro de rede na consulta de acesso | Ecrã de erro com "Tentar novamente" **e** "Terminar sessão" — não se fica preso. |
| Mensagens de recusa | "Acesso indisponível", sem distinguir recusado de revogado e sem motivos. Isso é informação do Control. |

---

## 6. Ficheiros

**SQL** — `supabase/migrations/20260731_punho_contas_organizacao.sql`
(idempotente; delta sobre `20260730`).

**Dart**

| Ficheiro | Papel |
|---|---|
| `lib/features/auth/domain/estado_acesso.dart` | `EstadoAcesso`, `DecisaoAcesso`, `decidirAcesso()` — regra pura |
| `lib/features/auth/data/acesso_service.dart` | interface `AcessoService` + `SupabaseAcessoService`, `Convite`, `ValidacaoConvite` |
| `lib/features/auth/acesso_providers.dart` | `acessoServiceProvider`, `estadoAcessoProvider`, `convitesProvider` |
| `lib/features/auth/presentation/registo_screen.dart` | registo com os 6 campos |
| `lib/features/auth/presentation/pedido_em_analise_screen.dart` | espera |
| `lib/features/auth/presentation/acesso_indisponivel_screen.dart` | recusa/revogação |
| `lib/features/auth/presentation/auth_gate.dart` | login + `AcessoGate` |
| `lib/features/gestao/presentation/convites_screen.dart` | criar e listar convites |
| `lib/features/shell/presentation/app_shell.dart` | atalho para Convites, só a gestores |

`AcessoService` é uma interface fina de propósito: o repositório não tem package
de mocking (decisão registada em `lib/core/licenca/licenca_service.dart`) e
`SupabaseClient` é uma classe concreta com API encadeada, impossível de fakear a
sério. Os testes implementam a interface à mão.

**Testes** — `test/features/auth/`: `registo_test.dart`,
`registo_convite_test.dart`, `pedido_pendente_test.dart`,
`pedido_recusado_test.dart`, `acesso_revogado_test.dart`,
`convite_gestor_test.dart`, mais `fake_acesso_service.dart`,
`registo_helpers.dart` e `gate_helpers.dart`.

---

## 7. Por fechar

- **Verificação SQL num branch Supabase** — os 5 cenários (registo livre,
  convite válido, convite expirado, aprovação, revogação) ainda não foram
  corridos contra uma base real. Nada foi aplicado a nenhum projecto Supabase.
- **`AppShell` ignora o perfil** (`app_shell.dart:27-29`): com Supabase activo,
  um `punho_membros.perfil = 'colaborador'` recebe a shell completa de gestor —
  o `CollaboratorShell` só é alcançável com Supabase desligado. É um defeito de
  autorização anterior a esta funcionalidade e fora do âmbito dela, mas fica
  registado: enquanto não for corrigido, aprovar alguém como colaborador dá-lhe
  na prática a vista de gestor.
