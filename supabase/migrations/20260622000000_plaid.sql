-- June Phase 1 — Plaid integration tables.

create table plaid_items (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid not null references users(id) on delete cascade,
  plaid_item_id               text not null unique,
  access_token_encrypted      bytea not null,
  institution_name            text,
  next_cursor                 text,
  last_synced_at              timestamptz,
  created_at                  timestamptz not null default now()
);
create index on plaid_items (user_id);

-- Map Plaid transaction_ids to internal transaction rows for idempotent upsert.
alter table transactions add column plaid_transaction_id text unique;

-- accounts.plaid_account_id needs to be unique so the sync upsert can target it.
alter table accounts add constraint accounts_plaid_account_id_key unique (plaid_account_id);

-- User-overridable category mapping for Plaid → June budget categories.
create table category_overrides (
  user_id           uuid not null references users(id) on delete cascade,
  plaid_category    text not null,
  june_category     text not null,
  primary key (user_id, plaid_category)
);

alter table plaid_items         enable row level security;
alter table category_overrides  enable row level security;
-- Phase 1: backend uses service_role and bypasses RLS. Phase 3 will add policies.

-- Phase 1 demo user: stable UUID the mobile app uses until real auth lands.
insert into users (id, email, password_hash)
values ('00000000-0000-0000-0000-000000000001', 'demo@june.app', '')
on conflict (id) do nothing;
