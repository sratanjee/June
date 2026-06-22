-- June Phase 0 initial schema.
-- Money is stored as bigint cents to avoid floating-point drift.
-- Times are timestamptz. IDs are UUIDs.

create extension if not exists pgcrypto;

create table users (
  id              uuid primary key default gen_random_uuid(),
  email           text not null unique,
  password_hash   text not null,
  created_at      timestamptz not null default now()
);

create table goals (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  label           text not null,
  target_amount_cents bigint not null check (target_amount_cents >= 0),
  target_date     date,
  kind            text not null check (kind in ('savings','expense','debt')),
  priority        int  not null default 0,
  created_at      timestamptz not null default now()
);
create index on goals (user_id);

create table accounts (
  id                            uuid primary key default gen_random_uuid(),
  user_id                       uuid not null references users(id) on delete cascade,
  name                          text not null,
  type                          text not null check (type in ('checking','savings','credit_card')),
  balance_cents                 bigint not null default 0,
  plaid_account_id              text,
  plaid_access_token_encrypted  bytea,
  created_at                    timestamptz not null default now()
);
create index on accounts (user_id);

-- Cards extend accounts (1:1, only for type = 'credit_card').
create table cards (
  account_id              uuid primary key references accounts(id) on delete cascade,
  statement_close_date    date,
  due_date                date,
  statement_balance_cents bigint not null default 0,
  current_balance_cents   bigint not null default 0
);

create table transactions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  account_id      uuid not null references accounts(id) on delete cascade,
  date            date not null,
  description     text not null,
  amount_cents    bigint not null,  -- signed: negative = outflow
  category        text,
  pending         boolean not null default false,
  created_at      timestamptz not null default now()
);
create index on transactions (user_id, date desc);
create index on transactions (account_id, date desc);

create table budget_targets (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  category            text not null,
  monthly_amount_cents bigint not null check (monthly_amount_cents >= 0),
  unique (user_id, category)
);

create table checkins (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  date            date not null,
  standing_text   text not null,
  balances        jsonb not null default '[]'::jsonb,
  actions         jsonb not null default '[]'::jsonb,
  paycheck_plan   jsonb,
  generated_at    timestamptz not null default now()
);
create index on checkins (user_id, date desc);

-- RLS enabled but permissive for Phase 0. Tightened in Phase 3.
alter table users           enable row level security;
alter table goals           enable row level security;
alter table accounts        enable row level security;
alter table cards           enable row level security;
alter table transactions    enable row level security;
alter table budget_targets  enable row level security;
alter table checkins        enable row level security;

-- Phase 0: backend connects with service_role and bypasses RLS.
-- Phase 3 will add per-user policies keyed on auth.uid().
