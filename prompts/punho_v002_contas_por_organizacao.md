# Prompt Claude Code — Punho v0.0.2

## Contas por organização com aprovação manual no Control

**Repo:** `punho` (Flutter Android + Windows)
**Publisher:** Decisão Digital (marca comercial de Cesar Diogo Franco Mendes, NIF 215555449)
**Objectivo:** implementar contas por organização em que a aprovação **manual** acontece depois, no Decisão Digital Control (repo separado — este prompt cobre só o lado Punho).

---

## Estado actual do repo (lê primeiro, faz só o delta)

O trabalho está **parcialmente iniciado**. Antes de escrever uma linha:

1. Lê `supabase/migrations/20260730_punho_pedidos_acesso.sql` — a tabela `punho_pedidos_acesso` pode já existir. Se existir e o schema bater com o que abaixo se descreve, **não crias uma migration duplicada** — cria uma migration nova que faz só o delta (colunas em falta, novos triggers, RLS ajustada, etc.).
2. Confere as migrations anteriores para saber o que já está: `punho_empresas`, `punho_membros`, `empresa_id`, RLS. **Reutiliza** — não crias um segundo modelo de organizações paralelo.
3. Lê `lib/features/auth/presentation/` para veres o registo actual.
4. Se em qualquer ponto o estado actual **contradisser** as regras abaixo, este documento é a fonte — alinha para cá, não o contrário.

Se após a inspecção considerares que a task já está 100% feita, **para e reporta em vez de refazer**.

---

## Regras não-negociáveis

- Não altera a versão oficial `v0.0.2` sem indicação explícita do Cesar.
- Todo o isolamento continua a ser por `empresa_id`. Nenhuma feature nova pode fugir a isto.
- Triggers e RPCs de segurança: `security definer` + `set search_path = public` obrigatório.
- Nenhum utilizador pode: aprovar-se, criar uma empresa automaticamente, ou aderir a uma empresa pelo nome.
- **Não abrir** policies `DELETE` permissivas. Se precisar de "revogar", é update de estado, não delete.
- Marca é **Decisão Digital** (com "ç" e espaço). Identificadores técnicos podem usar `decisao_digital` sem acento.
- Sem envio automático de emails nesta fase. Convites são código para copiar/partilhar.

---

## Fluxo funcional

### 1. Registo (Flutter)

Ecrã de registo pede:
- Nome
- Email
- Palavra-passe
- Nome da empresa / organização
- Cargo pretendido: **gestor** ou **colaborador** (radio ou dropdown)
- Código de convite (opcional)

Validação client-side mínima: email formato válido, password ≥ 8 chars, empresa não vazia, cargo escolhido.

### 2. Criação de conta

- Usar Supabase Auth (`signUp`) com todos os campos acima passados como `data:` (metadados do utilizador), **incluindo `app: 'punho'`** — o trigger do lado Postgres depende disto para distinguir do POS.
- **Nunca** criar `punho_empresas` no cliente.
- **Nunca** inserir em `punho_membros` no cliente.
- O trigger de `auth.users` (ou `auth.identities` se preferires) intercepta o insert quando `raw_user_meta_data->>'app' = 'punho'` e cria a linha em `punho_pedidos_acesso`:
  - `nome`, `email`, `empresa_indicada`, `cargo`, `origem` (`livre` ou `convite`), `estado = 'pendente'`, `criado_em`, `actualizado_em`.
  - Se veio com código de convite válido → `origem = 'convite'` + FK para o convite; se não → `origem = 'livre'`.
- **Racional do trigger:** confirmação de email pode diferir a criação do row. O trigger garante que o pedido é sempre criado, mesmo que o utilizador só confirme o email 3 dias depois.

### 3. Após login

Componente que executa a cada `authStateChanges`:

- Consulta o estado do pedido + adesão do utilizador autenticado.
- **Se pedido `pendente`** → ecrã "Pedido em análise", com botão único: **Terminar sessão**.
- **Se pedido `recusado` ou `revogado`** → ecrã "Acesso indisponível", com botão único: **Terminar sessão**. Não expor motivos internos.
- **Só abrir a `AppShell`** quando existir uma linha activa em `punho_membros` com o `auth.uid()` correspondente.
- Enquanto se aguarda, não pré-carregar dados operacionais (repositórios da empresa devem ficar inertes).

### 4. Convites

- Um gestor **já aprovado** (i.e., com adesão activa em `punho_membros` com cargo gestor) pode criar convite.
- Convite tem: `empresa_id` (a do gestor), `email` (obrigatório, único por empresa em estado activo), `cargo` (gestor ou colaborador), `codigo` (short random), `criado_por` (gestor), `criado_em`, `expira_em = criado_em + 14 dias`, `usado = false`.
- **Uma única utilização.** Quando alguém se regista com esse código, o convite fica `usado = true` e o pedido de acesso associado é criado com `origem = 'convite'` e `empresa_indicada = <empresa do convite>`. A aprovação central é **na mesma** obrigatória.
- **Não enviar emails.** UI mostra o código gerado — o gestor copia e envia por fora.
- Convite expirado ou já usado ⇒ registo rejeita com mensagem clara ("código inválido, expirado ou já utilizado").

### 5. Segurança

Sumário do que a migration deve garantir:

- RLS `enabled` em `punho_pedidos_acesso` e `punho_convites` (nome à tua escolha, sê consistente).
- Policies:
  - `SELECT`: um utilizador só vê o **próprio** pedido; um gestor aprovado vê os pedidos com `empresa_indicada = a sua empresa` (para saber o que vem pelo convite dele). Backoffice (Control) usa service role.
  - `INSERT`: só pelo trigger de auth, não por caller autenticado.
  - `UPDATE`: só service role (o Control aprova/recusa/revoga). Utilizador não muda o próprio estado.
  - `DELETE`: **sem policy** (nenhum caller consegue delete).
- Triggers/RPCs security definer:
  - `_criar_pedido_do_auth_user()` — o trigger de `auth.users`.
  - `punho_criar_convite(email, cargo)` — RPC callable pelo gestor (verifica que o caller é gestor aprovado da empresa).
- Constraint: `punho_pedidos_acesso.estado` só aceita `('pendente','aprovado','recusado','revogado')`.
- Índice em `(estado, criado_em)` para o Control paginar rapidamente.

---

## Ficheiros a criar/alterar

### Supabase

- **Migration nova** `supabase/migrations/YYYYMMDD_punho_contas_organizacao.sql` (data de hoje) — **idempotente** (usa `create table if not exists`, `create policy if not exists` só se disponível, senão embrulha em `do $$ ... $$` com `exception when duplicate_object`). Cobre o delta relativamente ao já existente.
- Se `20260730_punho_pedidos_acesso.sql` estiver *incorrecto* face a estas regras (ex: falta constraint de estado, RLS mal, sem trigger), **não editar a migration antiga** — corrige na migration nova (é imutável o que já foi aplicado em prod).

### Flutter

- `lib/features/auth/presentation/registo_screen.dart` (ou equivalente) — ecrã com os 6 campos.
- `lib/features/auth/presentation/pedido_em_analise_screen.dart` — ecrã de espera.
- `lib/features/auth/presentation/acesso_indisponivel_screen.dart` — ecrã de recusa/revogação.
- `lib/features/auth/` — service/repository para: consultar estado de pedido/adesão, criar convite (RPC), validar código de convite.
- Router / gate de sessão — decidir para onde mandar após `authStateChanges` (usa o padrão que já existe em `lib/core/auth/` ou `lib/core/session/`).
- `lib/features/gestao/` (ou onde faças sentido) — ecrã do gestor para criar convite, listar convites por empresa (com estado e data de expiração).

### Testes

Todos em `test/features/auth/` (ou onde fizer sentido no repo). **TDD onde faz sentido**: escrever teste primeiro para as regras críticas.

- `registo_test.dart` — registo livre cria pedido pendente (mock do trigger via fake do Supabase).
- `registo_convite_test.dart` — registo com código válido usa o convite; com código expirado/inválido rejeita.
- `pedido_pendente_test.dart` — utilizador com pedido pendente não vê AppShell.
- `pedido_recusado_test.dart` — utilizador recusado vê "Acesso indisponível".
- `acesso_revogado_test.dart` — utilizador que era membro e foi revogado perde AppShell.
- `convite_gestor_test.dart` — só gestor aprovado pode criar convite; colaborador não; utilizador de outra empresa não.

Se já existirem alguns destes testes por causa do trabalho anterior, **actualiza-os**, não os duplicas.

---

## Gate de verificação (obrigatório antes de dar como feito)

1. `flutter test` — toda a suite verde, zero regressões.
2. `flutter analyze` — limpo (ok o warning conhecido do `anonKey`).
3. **Verificação SQL manual** — aplica a migration nova num branch Supabase (não em prod), corre 5 cenários (registo livre, registo com convite válido, registo com convite expirado, aprovação, revogação) e confirma:
   - Row em `punho_pedidos_acesso` com estado correcto.
   - `punho_membros` só ganha linha na aprovação.
   - `punho_empresas` só é criada na aprovação de um pedido `origem = 'livre'` (ou pré-existente se convite).
   - `RAISE EXCEPTION` visível quando alguém tenta contornar (ex: tentar UPDATE do próprio estado).
4. Escreve num `docs/design/punho_v002_contas_organizacao.md` o desenho final: qual o schema, qual o fluxo, quais os edge cases considerados. Isto fica no repo para o histórico.

**Regra 3-fix arquitectura:** se após 2 iterações a solução ainda está a lutar contra o modelo `empresa_id + RLS` existente, para e reporta em vez de tentar terceira variação — provavelmente a especificação precisa de discussão.

---

## Entrega esperada

- 1 migration SQL nova (idempotente, com comentário no topo a explicar o delta)
- Alterações Flutter (novos ecrãs, service, router gate, ecrã gestor)
- Testes cobrindo os 6 cenários acima
- `docs/design/punho_v002_contas_organizacao.md` com o desenho final
- **Sem** alteração de versão no `pubspec.yaml` (fica em v0.0.2)
- Commit(s) locais mensuráveis; sem push para remote sem indicação

## Fora do âmbito (para o Control, depois)

O Decisão Digital Control será alterado numa fase posterior para:
- Listar `punho_pedidos_acesso`
- Aprovar / recusar / revogar
- Na aprovação: criar/activar `punho_membros`; para empresa nova, criar `punho_empresas` + subscrição com limite de utilizadores

Não implementar aqui a UI do Control — só garantir que a API/schema deste lado suporta esses fluxos (i.e., service role consegue fazer todas as operações, RLS não estorva).
