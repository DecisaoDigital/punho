# Backend Punho

Execute as migrations com a CLI Supabase. O cliente Flutter recebe apenas `SUPABASE_URL` e `SUPABASE_ANON_KEY` via `--dart-define`; nunca use `service_role` no cliente.

Exemplo local: `flutter run -d windows --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
Sem estas variáveis a aplicação fica no modo demo local.

Antes de produção, execute `supabase/migrations/20260725_punho_core.sql` e valide as políticas com dois gestores de empresas diferentes e um colaborador.

Consulte `RLS_VERIFICATION.md` para o protocolo manual. A migration é a fundação de schema/RLS; a ligação de autenticação, sincronização/outbox e migração de dados demo ainda requer implementação no Flutter antes de ativar Supabase num ambiente de clientes.
