# Configuração Supabase

Copie `.env.example` apenas como referência. Inicie com `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

Execute a migration em `supabase/migrations/20260725_punho_core.sql` e siga `supabase/RLS_VERIFICATION.md`. A configuração não deve conter `service_role`.

Nesta entrega os repositórios Flutter ainda não sincronizam com Supabase; a configuração não deve ser usada em produção.
