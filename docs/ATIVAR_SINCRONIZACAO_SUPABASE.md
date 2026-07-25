# Ativar a sincronizacao Supabase

## O que ja esta implementado

- A app guarda sempre uma copia local no dispositivo.
- O gestor pode sincronizar o estado operacional completo da sua empresa.
- A sincronizacao deteta uma versao remota diferente e recusa sobrescrever dados silenciosamente.
- O colaborador nao pode aceder a este estado completo porque contem custos e financas.

## Passos de ativacao

1. Criar o projeto Supabase do Punho.
2. Executar todas as migrations em `supabase/migrations/` por ordem, incluindo:
   - `20260727_punho_onboarding_rpc.sql`
   - `20260728_punho_auth_and_rls_hardening.sql`
   - `20260729_punho_operational_state_sync.sql`
3. No Supabase Auth, ativar email/password. Para um teste simples pode desativar temporariamente a confirmacao de email; em producao deve ficar ativa.
4. Iniciar a app com a URL e a chave anon/publica do projeto. Nunca usar a `service_role` na app:

```powershell
flutter run -d windows --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_PUBLICA
```

5. Criar a conta, criar a empresa no ecran inicial e concluir o onboarding.
6. No painel Gestao, usar o botao `Sincronizar`.

## Comportamento seguro

- Sem internet, os dados continuam guardados localmente.
- Se outro dispositivo tiver uma revisao remota que este dispositivo ainda nao recebeu, a app pede revisao em vez de substituir essa informacao.
- Nesta versao, a sincronizacao remota completa e apenas do gestor. A sincronizacao granular de leads, reservas e recebimentos do colaborador requer tabelas e politicas por perfil antes de ser ativada.
