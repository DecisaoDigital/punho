-- PIN do cadeado ligado à conta (e não ao aparelho): o mesmo PIN em todos os
-- aparelhos onde a conta entra. Guarda-se só salt + hash (sha256 de 'salt|pin'),
-- nunca o PIN. Cada utilizador vê e mexe apenas na sua linha.
create table if not exists public.fist_pins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  salt text not null,
  hash text not null,
  updated_at timestamptz not null default now()
);

alter table public.fist_pins enable row level security;

drop policy if exists fist_pins_proprio_select on public.fist_pins;
create policy fist_pins_proprio_select on public.fist_pins
  for select to authenticated using (user_id = auth.uid());

drop policy if exists fist_pins_proprio_insert on public.fist_pins;
create policy fist_pins_proprio_insert on public.fist_pins
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists fist_pins_proprio_update on public.fist_pins;
create policy fist_pins_proprio_update on public.fist_pins
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists fist_pins_proprio_delete on public.fist_pins;
create policy fist_pins_proprio_delete on public.fist_pins
  for delete to authenticated using (user_id = auth.uid());
