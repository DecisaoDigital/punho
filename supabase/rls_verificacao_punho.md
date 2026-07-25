# Verificação RLS Punho

1. Criar duas empresas e três utilizadores: gestor A, colaborador A e gestor B.
2. Inserir membros ativos com os perfis respetivos.
3. Com o JWT do gestor A, criar cliente e reserva da empresa A.
4. Com o JWT do colaborador A, confirmar leitura do cliente A e recusa de `punho_despesas`, `punho_subscricoes` e auditoria.
5. Com o JWT do gestor B, confirmar que nenhum registo da empresa A é visível ou alterável.
6. Tentar duas reservas confirmadas sobrepostas para a mesma máquina e confirmar erro `23P01`.

Executar sempre com JWT de utilizador; `service_role` ignora RLS e não valida políticas.
