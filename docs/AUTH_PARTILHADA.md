# Password partilhada entre Punho e Control — investigação (4 Ago 2026)

Investigação read-only. Nenhuma escrita feita em BD, ficheiros de app ou configuração — só este documento.

## 1. Que projecto Supabase usa cada app

| App | Ficheiro | `SUPABASE_URL` |
|---|---|---|
| Punho | `/home/cesar/punho/.env:1` → `SUPABASE_URL=https://oefqbkhioncakojipqyx.supabase.co` | `oefqbkhioncakojipqyx` |
| Punho (build) | `/home/cesar/punho/scripts/update-release-catalog.sh:8-9` → `PROJECT_REF="oefqbkhioncakojipqyx"` | `oefqbkhioncakojipqyx` |
| Control | `/home/cesar/washinvoice-control/lib/core/supabase_config.dart:2` → `static const url = 'https://oefqbkhioncakojipqyx.supabase.co';` | `oefqbkhioncakojipqyx` |

`mcp__claude_ai_Supabase__list_projects` devolve **exactamente um projecto** na conta/organização:

```json
{"id":"oefqbkhioncakojipqyx","ref":"oefqbkhioncakojipqyx","name":"WashInvoice","region":"eu-central-1","status":"ACTIVE_HEALTHY","created_at":"2026-06-29T20:05:56Z"}
```

**Conclusão: é o mesmo projecto Supabase, único na conta, chamado "WashInvoice".** Não há um segundo projecto — não é preciso sequer comparar refs, só existe um.

Não foi encontrado, em `/home/cesar`, um repositório separado da app WashInvoice (facturação/POS) — só `punho/` e `washinvoice-control/` têm `pubspec.yaml`. A app POS deve existir noutro sítio (fora desta máquina) e é presumivelmente a dona natural do projecto Supabase chamado "WashInvoice" e do esquema `washinvoice://`.

## 2. Confirmação de `auth.users` partilhado

```sql
select count(*) from auth.users;  -- 4
```

4 utilizadores no total, partilhados por Punho e Control. Tabelas que ligam `user_id` a `auth.users.id` (via `list_tables` verbose + `pg_proc`):

- `public.admins(user_id)` — lista de administradores do **Control**. Função `is_admin()`:
  ```sql
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
  ```
- `public.punho_membros(id, empresa_id, user_id, perfil, ativo, ...)` — adesão de um utilizador a uma empresa no **Punho**.
- `public.punho_pedidos_acesso(user_id, ...)`, `public.pedidos_acesso(user_id, ...)` — pedidos de acesso pendentes (Punho e Control, respectivamente).
- `public.admin_dispositivos(user_id, fcm_token, ...)` — tokens push do Control, por utilizador.

`cesarmendes78@gmail.com` = `auth.users.id = 9e1bfae1-b932-430d-ad41-055cf894ff7f` (criado 2026-07-06). Está registado em **ambas**:

```json
[{"tbl":"admins","user_id":"9e1bfae1-...","criado_em":"2026-07-18 20:05:34"},
 {"tbl":"punho_membros","user_id":"9e1bfae1-...","ativo":"true"}]
```

Ou seja, para este email específico, é o mesmo `auth.users` que abre as duas apps — não há dúvida.

## 3. Como cada app distingue quem pode entrar

Ambas têm um portão pós-login (autenticar em `auth.users` **não** basta):

- **Punho** — `lib/features/auth/presentation/auth_gate.dart`: `AcessoGate` só mostra `AppShell`/`CollaboratorShell` se existir adesão activa em `punho_membros` (comentário no código: *"Só a existência de uma adesão activa em `punho_membros` abre a AppShell; até lá nada da empresa é carregado."*). RLS reforça: `punho_membros` só permite `SELECT` da própria linha (`user_id = auth.uid()`).
- **Control** — `lib/main.dart:48-52,204-233`: `estadoAcessoProvider` chama um RPC (`acessosRepoProvider.meuEstado()`) que devolve `aprovado/pendente/recusado/revogado`; só `aprovado` mostra `HomeShell`. Tabelas `organizacoes` e `pedidos_acesso` (RLS `is_admin()` / `user_id = auth.uid()`) sustentam esse RPC.

**Resposta directa:** sim, um utilizador registado no Punho consegue autenticar-se (login Supabase Auth OK) na app Control com as mesmas credenciais — é o mesmo `auth.users`. O que o impede de ver dados de administração é a camada seguinte, em duas linhas de defesa:
1. Client-side: `estadoAcessoProvider` no Control só deixa passar quem tem um pedido de acesso **aprovado** (tabela separada de `admins`/`pedidos_acesso`) — um utilizador só-Punho fica preso em `AcessoPendenteScreen`, nunca vê o `HomeShell`.
2. RLS: mesmo que o gate de UI falhasse, `licencas`, `organizacoes` e `admin_dispositivos` só devolvem linhas a quem está em `public.admins` (`is_admin()`) ou é dono da própria linha.

Não há aqui falha grave de autorização — as duas apps gatekeep correctamente por tabela própria, não pela mera existência de sessão.

## 4. `referer: washinvoice://auth/callback` em pedidos do Punho

- **Control nunca define `redirectTo`**: `lib/features/auth/login_screen.dart:137` → `resetPasswordForEmail(email)` sem segundo argumento. Usa sempre o Site URL por omissão do projecto.
- **Punho define explicitamente `punho://auth/callback`**, desde o commit `a9c3c57` (1 Ago 2026): `lib/features/auth/presentation/login_screen.dart:271-275`, com comentário próprio a admitir o problema:
  > `// 'punho://' e não o esquema por omissão: o default é o do POS ('washinvoice://'), e o link do email caía numa página em branco.`
- O APK instalado hoje (`/home/cesar/punho/dist/punho-android-v0.2.1.apk`, compilado às 07:23 de 4 Ago, **antes** do pedido de recuperação das 08:17) já contém este código.
- Mesmo assim, o log de `/recover` das 08:17:33 mostra `"referer":"washinvoice://auth/callback"` — não `punho://auth/callback`. O `redirectTo` do Punho não teve efeito no que o GoTrue registou.
- **Nenhuma das duas apps regista o esquema que está a aparecer.** `AndroidManifest.xml` do Punho (`android/app/src/main/AndroidManifest.xml`) não tem `<intent-filter>` com `<data android:scheme=...>` nenhum — só o `MAIN/LAUNCHER`. O do Control também não regista `washinvoice://`. E o Punho não usa `uni_links`/`app_links` (não está no `pubspec.yaml`, não há `getInitialLink`/`handleDeepLink` no código) — nem o `pubspec.yaml`, nem o manifest, sabem lidar com `punho://auth/callback` mesmo que o link chegasse.
- Todos os pedidos de auth do projecto — de qualquer app, de qualquer utilizador, ao longo de vários dias (`/token`, `/recover`, `/verify`, `/user`) — mostram sempre o mesmo `referer: washinvoice://auth/callback`, independentemente de quem originou o pedido. Isto não é consistente com um cabeçalho HTTP `Referer` enviado pelo cliente (apps nativas Flutter não enviam esse cabeçalho); é consistente com o **Site URL do projecto GoTrue**, que é uma configuração única e partilhada por todo o projecto — logo por todas as apps que nele batem.

**Conclusão do ponto 4:** o Punho está de facto a mandar o pedido de recuperação para um esquema (`punho://`) que a própria app não sabe abrir — isso é, em si, um defeito à parte (deep link "morto", sem handler nem registo no manifesto). Mas a causa do sintoma reportado (referer sempre `washinvoice://`) não é esse defeito: é o Site URL/allowlist de redirect do projecto Supabase (config GoTrue, não visível por SQL, só no painel/API de Auth), que devolve sempre o mesmo default porque `punho://auth/callback` não está na lista permitida — e esse default pertence, a avaliar pelo nome do esquema e do próprio projecto ("WashInvoice"), à app POS/facturação que não está neste repositório.

## 5. Veredicto

**Sim — é o comportamento normal e inevitável do Supabase quando duas apps partilham projecto.** Confirmado, não suposto:

- 1 projecto Supabase na conta (`oefqbkhioncakojipqyx`, "WashInvoice") — Punho e Control usam ambos essa URL.
- 1 `auth.users` com 4 linhas, partilhado — `cesarmendes78@gmail.com` é a mesma linha (`9e1bfae1-...`) nas duas apps, com registo próprio em `admins` (Control) *e* em `punho_membros` (Punho).
- Trocar a password em qualquer uma das duas apps troca-a para as duas, porque é a mesma credencial no mesmo servidor de auth. O que separa "quem vê o quê" depois do login são as tabelas de autorização por app (`admins`, `punho_membros`) e o gate client-side — não a password.

Opções reais para separar, com custo:

1. **Projecto Supabase próprio por app** (Punho ↔ Control ↔ POS). Isola `auth.users`, elimina a partilha de password. Custo: 2 migrações completas de esquema/dados/RLS, gerir 2-3 pares de chaves, sem partilha fácil de tabelas hoje comuns (`versoes_apps`, `licencas`, `admin_dispositivos`, o próprio `punho_*` que o Control lê para gerir pedidos). É o mais correcto a prazo se as apps forem para públicos diferentes, mas é trabalho grande.
2. **Manter partilhado, aceitar credencial única por email** — é o estado actual. Custo zero, mas qualquer pessoa com conta nas duas apps (hoje só o César) tem sempre uma password só, e trocar numa mexe nas outras. Aceitável se só o César (ou poucos "super-utilizadores") tiver dupla conta.
3. **Emails distintos por app** (ex.: `cesarmendes78+control@gmail.com`) — zero trabalho de infra, mas exige o utilizador gerir 2+ credenciais e o `+control` já lá está de facto para o utilizador de teste do Punho (`cesarmendes78+punhoteste@gmail.com`, também confirmado nos logs). É a opção mais barata já hoje disponível.

Independentemente da opção escolhida: o `redirectTo: 'punho://auth/callback'` no Punho está morto (sem manifest, sem handler) e vale a pena corrigir ou remover — hoje não faz nada mesmo quando o GoTrue o respeitasse.

## 6. Decisão (4 Ago 2026)

**Fica a opção 2: projecto partilhado, credencial única por email.** Decisão do
César, no dia, com o problema já compreendido — a opção 1 obrigava a sair do
plano gratuito do Supabase para o pago, e não compensa hoje. A migração fica
adiada, sem data.

O que isto quer dizer na prática, para quem ler isto mais tarde:

- Trocar a palavra-passe no Control **troca-a no Punho**, e vice-versa. Não é
  avaria, não abrir bug por causa disso.
- Não criar projectos Supabase novos nem propor a separação sem ele pedir.
- Quem precisar de contas independentes usa emails distintos (opção 3), que
  não custa nada e já é o que se faz nos utilizadores de teste.

Continua por corrigir, e é independente desta decisão: o `redirectTo` morto do
ponto 4. Quem carregar em "Esqueci a palavra-passe" no telemóvel recebe o email
e não tem por onde voltar à app.
