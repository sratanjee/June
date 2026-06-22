# June — Architecture & Roadmap

*Living document. Source of truth for stack, data model, request flow, and security posture. Updated as phases land. Sister docs: `June_Build_Spec_for_Claude_Code.md` (phase plan), `June_Personality_Spec.md` (voice).*

---

## Repo layout

```
~/June
├── June_Build_Spec_for_Claude_Code.md   # phased build plan
├── June_Personality_Spec.md             # voice + §9 system prompt
├── Budget_Assistant_Architecture.md     # this doc
├── README.md                            # setup + run instructions
├── supabase/                            # local Supabase project
│   ├── config.toml
│   └── migrations/0001_init.sql
├── backend/                             # Fastify + TS service
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── src/
│       ├── server.ts
│       ├── db.ts
│       ├── anthropic.ts
│       ├── prompt.ts                    # loads + injects §9 system prompt
│       └── routes/checkin.ts
└── mobile/                              # Flutter app
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── theme.dart                   # design tokens
        ├── api/june_client.dart
        ├── models/                      # hand-written Dart models
        └── screens/
            ├── entry_screen.dart
            └── checkin_screen.dart
```

---

## Stack

| Layer    | Tech | Why |
|----------|------|-----|
| Mobile   | Flutter | One Dart codebase, iOS + Android, matches existing tooling. |
| Backend  | Fastify + TS + Zod | TS-native, schema validation built in, ~3× Express throughput. |
| Database | Postgres via Supabase | Migrations + auth + storage in one tool. Local CLI in dev, cloud in prod. |
| AI       | Anthropic SDK (`@anthropic-ai/sdk`) | `claude-opus-4-7` for daily reasoning, `claude-haiku-4-5-20251001` for transaction categorization (Phase 1+). |
| Bank     | Plaid | Sandbox (Phase 1) → Development (Phase 2) → Production (Phase 4). |
| Auth     | Email + password, MFA-ready (Phase 3) | Supabase Auth when we lean further into the platform. |

---

## Data model (Phase 0)

All tables live in `supabase/migrations/0001_init.sql`. IDs are UUIDs; timestamps are `timestamptz`; money is stored as `bigint` cents to avoid floating-point.

| Table | Key fields |
|-------|------------|
| `users` | `id`, `email`, `password_hash`, `created_at` |
| `goals` | `id`, `user_id`, `label`, `target_amount_cents`, `target_date`, `kind` (`savings`/`expense`/`debt`), `priority` |
| `accounts` | `id`, `user_id`, `name`, `type` (`checking`/`savings`/`credit_card`), `balance_cents`, `plaid_account_id` (nullable), `plaid_access_token_encrypted` (nullable) |
| `cards` | `account_id` (PK + FK to `accounts`), `statement_close_date`, `due_date`, `statement_balance_cents`, `current_balance_cents` |
| `transactions` | `id`, `user_id`, `account_id`, `date`, `description`, `amount_cents`, `category`, `pending` |
| `budget_targets` | `id`, `user_id`, `category`, `monthly_amount_cents` |
| `checkins` | `id`, `user_id`, `date`, `standing_text`, `actions` (jsonb), `paycheck_plan` (jsonb, nullable), `generated_at` |

Per-user isolation is enforced via the `user_id` column on every table. RLS is enabled but lax in Phase 0 (anon role); tightened in Phase 3.

---

## Request flow — `POST /checkin/generate`

```
Flutter client
   │  POST /checkin/generate  { userId, today }
   ▼
Fastify route
   │  validate body (Zod)
   ▼
DB read
   │  load accounts + cards + transactions (last 60d) + goals + budget_targets
   ▼
Build user message
   │  JSON object of the financial context
   ▼
Anthropic call
   │  system: §9 from June_Personality_Spec.md
   │  user:   "Today is {today}. Here is the context: {json}"
   │  model:  claude-opus-4-7
   ▼
Parse response
   │  strip optional ```json fences, JSON.parse, validate with CheckInSchema (Zod)
   │  on parse failure → return 502 with calm-error JSON in June's voice
   ▼
Persist
   │  INSERT into checkins
   ▼
Return JSON to client
```

The system prompt is loaded **at server start** from `June_Personality_Spec.md` (a small loader extracts §9 verbatim). The prompt is therefore version-controlled — the file is the source of truth, not a string literal in code.

---

## Schemas (single source of truth)

Defined in `backend/src/schemas.ts` using Zod. The route validates both the request body and the model's JSON response against these schemas. Dart models in `mobile/lib/models/` are hand-written to match the same shape.

```ts
const CheckInResponse = z.object({
  standing: z.string(),
  balances: z.array(z.object({
    label: z.string(),
    amount: z.number(),
    subtext: z.string().optional(),
  })).min(2).max(5),
  actions: z.array(z.object({
    title: z.string(),
    detail: z.string(),
    severity: z.enum(["ok", "attention", "info"]),
  })).max(2),
  paycheck_plan: z.object({
    next_paycheck_date: z.string(),
    amount: z.number(),
    allocations: z.array(z.object({
      label: z.string(),
      amount: z.number(),
    })),
  }).optional(),
});
```

---

## Design tokens (mobile)

From the spec's design language, exposed in `mobile/lib/theme.dart`:

| Token | Hex | Use |
|-------|------|-----|
| `inkNavy` | `#10182B` | Headlines, primary text on light bg |
| `sage` | `#3B6D5E` | "All clear" severity |
| `amber` | `#BA7517` | "Attention" severity |
| `paper` | `#FBF8F2` | App background |
| `neutralMuted` | `#6B6760` | Secondary text, "info" severity |

Display face: a serif (default `Lora` / system serif fallback). UI face: clean sans (default `Inter` / system sans fallback). All copy is sentence case.

---

## Security posture by phase

| Phase | Required posture |
|-------|------------------|
| 0 | Secrets in `.env` (git-ignored). Local-only DB. Manual data — no Plaid tokens to protect yet. |
| 1 | Plaid Sandbox keys in env. Plaid access tokens encrypted at rest (Supabase Vault or `pgcrypto`). HTTPS for backend. |
| 2 | Same as Phase 1, but the founder's real institution tokens — treat as production-sensitive. Backups encrypted. |
| 3 | RLS enforced per-user; backend uses scoped service tokens. MFA-ready auth. Audit log on every read of another user's data (should never happen, log to detect). |
| 4 | SOC 2 process underway. AES-256 at rest. Tokens in managed KMS. Data subject deletion/export. Plaid Production review complete. |

---

## Phase roadmap (one-line summaries)

- **Phase 0 (now):** Manual data → daily check-in. Proves the intelligence layer.
- **Phase 1:** Plaid Sandbox → automatic accounts + balances + transactions.
- **Phase 2:** Plaid Development → founder's real accounts. Daily scheduled sync + pre-generated morning check-in.
- **Phase 3:** Multi-user. Onboarding, accounts screen, June chat, push notifications, strict RLS.
- **Phase 4:** Compliance + Plaid Production. SOC 2, KMS, MFA, legal.

---

## Open questions (revisit before Phase 1)

- Auth provider for Phase 3: Supabase Auth vs. roll-our-own. Leaning Supabase given existing patterns.
- Dart codegen for API contract: hand-written Phase 0; revisit `quicktype` from a Zod-derived JSON Schema when surface grows past ~5 endpoints.
- Push notification provider: APNs/FCM direct vs. OneSignal vs. Expo's notification service (no longer applicable post-Flutter switch).
- Where the backend deploys in Phase 2+: Fly.io / Render / Railway — pick when we have a real domain.
