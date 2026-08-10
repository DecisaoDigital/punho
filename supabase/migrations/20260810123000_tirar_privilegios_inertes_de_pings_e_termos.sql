-- Resíduo da migration anterior, apanhado a verificar o resultado.
--
-- `pings` e `aceites_termos` ficaram com UPDATE e DELETE para `authenticated`.
-- Hoje não fazem nada: não existe política para esses comandos, e sem política
-- o RLS nega por omissão. Mas o privilégio fica lá à espera de que alguém, um
-- dia, escreva uma política de UPDATE a pensar noutra coisa — e nessa altura o
-- caminho já está aberto e ninguém repara.
--
-- Estas duas tabelas são um registo append-only: um terminal diz que está vivo,
-- um cliente aceita termos. Nada disso se altera nem se apaga depois.
--
-- O INSERT continua a chegar a `anon` (POS) e a `authenticated` (Punho com
-- sessão iniciada) pela política `insert_pings`/`insert_termos`, que é `to
-- public` — não se toca.

revoke update, delete on public.pings from authenticated;
revoke update, delete on public.aceites_termos from authenticated;
