# June

A daily financial companion. Sign up, set goals, link bank accounts, and each morning June tells you where you stand and the one thing worth doing today. Calm over data.

This repo is built phase by phase. Phase 0 is the brain on manual data; later phases add Plaid, multi-user, push notifications, and compliance. The full plan lives in `June_Build_Spec_for_Claude_Code.md`.

## Repo layout

```
~/June
├── June_Build_Spec_for_Claude_Code.md   # phased build plan (source of truth)
├── June_Personality_Spec.md             # voice + §9 system prompt
├── Budget_Assistant_Architecture.md     # architecture + roadmap
├── README.md                            # you are here
├── supabase/                            # local Supabase + migrations
├── backend/                             # Fastify + TS service
└── mobile/                              # Flutter app
```

## Prerequisites

- Node 22+, npm 10+
- Flutter 3.35+ (`flutter doctor`)
- Supabase CLI 2.75+
- An Anthropic API key (https://console.anthropic.com)

## Setup (Phase 0)

### 1 — Database (local Supabase)

```bash
cd supabase
supabase start    # boots Postgres + Studio in Docker
supabase db reset # applies migrations/20260621000000_init.sql
```

`supabase start` prints a `DB URL` line — copy it; that's `DATABASE_URL` for the backend.

### 2 — Backend (Fastify + TS)

```bash
cd backend
cp .env.example .env
# Fill in ANTHROPIC_API_KEY and DATABASE_URL in .env
npm install
npm run dev
```

The server boots at `http://127.0.0.1:4000`. Health: `GET /health`. The check-in endpoint is `POST /checkin/generate`.

### 3 — Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

Defaults: iOS simulator points at `http://127.0.0.1:4000`. Android emulator uses `http://10.0.2.2:4000`. For a real device, run with `--dart-define=JUNE_API_BASE=http://<your-mac-ip>:4000`.

## Phase 0 acceptance

1. Add a couple of accounts and a goal on the entry screen.
2. Tap **Generate today's check-in**.
3. See a June-voiced standing + 2–5 balance lines + 0–2 actions, rendered with sage / amber / neutral severity tints.

Per personality spec §6: a paycheck-imminent timing dip should *not* generate an `attention` action.

## Environments

| Environment | Where | Used in |
|-------------|-------|---------|
| Local Postgres | `supabase start` (Docker) | Phase 0 dev |
| Supabase cloud | https://aejmtjgikqqqflhtynip.supabase.co | Phase 1+ deploy target |

To push migrations to the cloud project later: `supabase link --project-ref aejmtjgikqqqflhtynip && supabase db push`.

## Secrets

All secrets go in `.env` files, never in source. `.env` is git-ignored across the repo. See `backend/.env.example` for the keys.
