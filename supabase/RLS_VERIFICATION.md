# Verificação manual de RLS

Crie três utilizadores Auth: `gestor-a`, `colaborador-a` e `gestor-b`.

1. Crie duas empresas e associe `gestor-a`/`colaborador-a` à primeira e `gestor-b` à segunda em `punho_membros`.
2. Com a sessão de `gestor-a`, crie um cliente na empresa A.
3. Com `colaborador-a`, confirme que o cliente da empresa A é legível e que `punho_despesas` e `punho_subscricoes` não devolvem linhas.
4. Com `gestor-b`, confirme que o cliente da empresa A não é legível nem alterável.
5. Crie uma reserva confirmada para uma máquina e tente criar outra reserva sobreposta para a mesma máquina. O trigger deve rejeitar a associação com `23P01`.

O teste deve ser repetido após qualquer alteração nas policies. Nunca execute estes testes com `service_role`, que ignora RLS.
