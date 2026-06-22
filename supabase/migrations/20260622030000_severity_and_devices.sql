-- The overall "feeling" derived from a check-in's actions. NULL until generated.
alter table checkins add column feeling text
  check (feeling in ('green', 'attention', 'quiet'));

-- Device tokens for push notifications.
create table device_tokens (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  platform        text not null check (platform in ('ios', 'android')),
  token           text not null,
  registered_at   timestamptz not null default now(),
  last_seen_at    timestamptz not null default now(),
  unique (user_id, token)
);
create index on device_tokens (user_id);

-- RLS policies same pattern as the rest.
alter table device_tokens enable row level security;
create policy "device_tokens_select_own" on device_tokens
  for select using (user_id = auth.uid());
create policy "device_tokens_insert_own" on device_tokens
  for insert with check (user_id = auth.uid());
create policy "device_tokens_delete_own" on device_tokens
  for delete using (user_id = auth.uid());
