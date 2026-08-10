-- Contador para o rate-limit da `registar-terminal`.
--
-- A criação de terminais tem de continuar aberta a quem não tem sessão: o POS
-- não tem uma única conta em `auth.users`, e o Punho regista-se no arranque
-- antes do login. Aberta e sem contador, uma chave `anon` — que é pública —
-- enche `licencas` de linhas de trial a 40 dias, cada uma com
-- `pendente_revisao=true`, até a lista do Control deixar de servir para nada.
--
-- Só se conta o que cria linha nova. A chamada idempotente de cada arranque —
-- o terminal que já existe e volta a dizer olá — não conta, senão o limite
-- gastava-se sozinho num telemóvel que reinicia.
--
-- Escrita e leitura só por service_role, de dentro da própria função. Não há
-- políticas: com RLS ligado e nenhuma política, o RLS nega tudo por omissão, e
-- os GRANT vão embora a seguir.

create table if not exists public.registar_terminal_tentativas (
  id bigserial primary key,
  ip text not null,
  app text not null,
  machine_id text not null,
  criado_em timestamptz not null default now()
);

comment on table public.registar_terminal_tentativas is
  'Rate-limit da Edge Function registar-terminal. Uma linha por terminal criado, '
  'por IP. Limpa-se sozinha: a função apaga o que tem mais de um dia.';

create index if not exists registar_terminal_tentativas_ip_tempo
  on public.registar_terminal_tentativas (ip, criado_em desc);

alter table public.registar_terminal_tentativas enable row level security;

revoke all on public.registar_terminal_tentativas from anon, authenticated;
revoke all on sequence public.registar_terminal_tentativas_id_seq from anon, authenticated;
