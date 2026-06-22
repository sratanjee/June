# Build Spec — June (Finance Companion App)

*A prescriptive build document for Claude Code. Feed it ONE phase at a time, not all at once. Each phase ends in something runnable. Two companion docs inform this build: the architecture/roadmap doc and June's personality spec — keep both in the repo and reference them where noted.*

---

## How to use this with Claude Code

- Work **phase by phase**. Start a Claude Code session per phase; don't ask it to build everything in one prompt.
- After each phase, run the app and verify the acceptance criteria before moving on.
- Keep `June_Personality_Spec.md` and `Budget_Assistant_Architecture.md` in the repo root so Claude Code can read them.
- **Secrets:** Plaid keys and the Anthropic API key go in environment variables (`.env`, git-ignored). Never hardcode. State this in every phase that touches them.

---

## Product summary (context for Claude Code)

June is a daily financial companion. A user signs up, sets goals, links bank/card accounts via Plaid, and each day receives an AI-generated "standing + one thing to do" check-in plus a chat interface to ask questions. The AI layer is the Claude API using June's personality spec as its system prompt. The product's thesis is calm-over-data: convert anxiety into clear, ordered guidance.

Design language (already prototyped): deep ink navy (#10182B), sage green (#3B6D5E) for "all clear," soft amber (#BA7517) for "attention," warm paper (#FBF8F2) background. Serif display face for headline/standing moments; clean sans for UI and data. Calm, never alarmist.

---

## Stack (commit to these unless you have a strong reason)

- **Mobile client:** Flutter — cross-platform iOS/Android from one Dart codebase.
- **Backend:** Node + TypeScript with Fastify.
- **Database:** Postgres via Supabase (local CLI in dev, Supabase cloud in prod). Encrypt sensitive fields at rest; store Plaid `access_token`s encrypted via a managed key (Supabase Vault or equivalent), never plaintext.
- **Aggregator:** Plaid (Transactions, Auth/Balance, Liabilities, Webhooks). Start in Sandbox. Uses `plaid_flutter` on mobile + the Node SDK on the backend.
- **AI layer:** Anthropic API. Use model `claude-opus-4-7` for the reasoning/advice generation (highest-capability Opus tier; strong long-horizon reasoning), and `claude-haiku-4-5-20251001` for cheap routine classification (e.g. categorizing transactions) to control cost. Verify current model IDs at https://docs.claude.com/en/docs/about-claude/models/overview before shipping.
- **Auth:** email + password to start, with MFA-ready design. Add OAuth later.

---

## Phase 0 — The brain on manual data (no Plaid yet)

**Goal:** prove the intelligence layer. A minimal app where the user enters balances + goals and June returns the structured check-in. This is the fastest path to a working thing and de-risks everything else.

**Build:**
1. Scaffold the Flutter app and the Fastify backend. The API contract is defined once in the backend via Zod schemas; Dart models on the mobile side are hand-written to match (revisit codegen if the API surface grows).
2. Data model (TypeScript types + Postgres tables):
   - `User` — id, email, password hash, created_at.
   - `Goal` — id, user_id, label, target_amount, target_date, kind (savings | expense | debt), priority.
   - `Account` — id, user_id, name, type (checking | savings | credit_card), balance, plaid fields nullable for now.
   - `Card` — extends account: statement_close_date, due_date, statement_balance, current_balance.
   - `Transaction` — id, user_id, account_id, date, description, amount, category, pending (bool).
   - `BudgetTarget` — id, user_id, category, monthly_amount.
   - `CheckIn` — id, user_id, date, standing_text, actions (json), generated_at.
3. Backend endpoint `POST /checkin/generate`: takes the user's accounts, cards, transactions, goals, budget targets; calls the Anthropic API with June's system prompt (from `June_Personality_Spec.md` §9) and the financial context; returns structured JSON: `{ standing: string, balances: [...], actions: [{title, detail, severity}], paycheck_plan?: {...} }`.
   - Prompt the model to return ONLY valid JSON (no prose, no markdown fences); parse defensively; strip fences if present.
   - Severity is `ok | attention | info` — maps to sage / amber / neutral in the UI.
4. Screens (use the prototype's visual language): a manual entry form for accounts/goals, and the daily check-in screen rendering the structured response.

**Acceptance:** user enters their real numbers, taps generate, and sees a June-voiced standing + balances + one-to-three actions that correctly distinguish a timing balance from real overspend (see personality spec §6).

---

## Phase 1 — Plaid Sandbox integration

**Goal:** replace manual entry with automatic data from Plaid's fake institutions (free, no real banks).

**Build:**
1. Create a Plaid developer account; use Sandbox keys via env vars.
2. Backend:
   - `POST /plaid/link-token` — create a link token for the client.
   - `POST /plaid/exchange` — exchange public token for access token; store encrypted, linked to user.
   - `POST /plaid/sync` — pull accounts (Auth/Balance), transactions (Transactions), and card details (Liabilities); upsert into the DB.
   - `POST /plaid/webhook` — handle `SYNC_UPDATES_AVAILABLE` and transaction webhooks; trigger sync on change rather than polling.
3. Client: Plaid Link flow via `plaid_flutter` inside the "Link accounts" screen from the prototype. Show read-only / "we never see your login" messaging.
4. Map Plaid categories to the app's budget categories; allow user override (store corrections).

**Acceptance:** linking a Plaid Sandbox institution populates accounts, balances, card statement/due dates, and transactions automatically, and the Phase 0 check-in now runs off that synced data.

---

## Phase 2 — Single-user live (your own accounts)

**Goal:** connect real accounts via Plaid Development; end manual entry for the founder.

**Build:**
1. Move to Plaid Development environment (limited live institutions).
2. Tune the category mapping and the check-in logic against real transaction data.
3. Add a daily scheduled job that syncs and pre-generates the morning check-in.

**Acceptance:** real balances flow in; the morning check-in is accurate against the founder's actual financial picture without any manual input.

---

## Phase 3 — Productize (multi-user + full surfaces)

**Goal:** the full product as prototyped, ready for more than one user.

**Build:**
1. Onboarding + goal-setting flow (prototype screens).
2. Accounts screen with sync status and "link a new account."
3. June chat: `POST /chat` — sends conversation history + the user's live financial context + June's system prompt to the Anthropic API; streams the reply. Quick-reply chips as prototyped.
4. Notifications: morning check-in push; statement-close and due-date reminders. June's notification voice per personality spec (calm, one thing, never manufactured urgency).
5. Strict per-user data isolation (row-level security or equivalent). Never let one user's context reach another's model call.

**Acceptance:** a second test user can sign up, link accounts, get their own check-ins and chat, with zero data bleed between users.

---

## Phase 4 — Compliance + Plaid Production

**Goal:** the gate to real third-party users. Begin reading in parallel with earlier phases.

**Build / process:**
1. Encryption everywhere: TLS in transit, AES-256 at rest, tokens in a managed secrets store.
2. Auth hardening: MFA, least-privilege internal access, full audit logging.
3. Privacy: data subject deletion/export, consent records, retention limits, data minimization.
4. Begin SOC 2 process; complete Plaid's security review to obtain Production access.
5. ToS + privacy policy; engage a fintech attorney for entity/liability structure.

**Acceptance:** Plaid Production access granted; security and privacy posture documented; legal in place before any non-founder real bank data is handled.

---

## Cross-cutting requirements (all phases)

- **June's voice is non-negotiable.** Every user-facing AI string must come from the Claude API call seeded with the personality spec — no hardcoded "chatbot" copy. UI chrome copy follows the same calm, plain, sentence-case tone.
- **The core judgment (personality spec §6) is a feature, not a nicety.** Timing-vs-debt and pay-vs-wait logic must be explicit in the prompt and verifiable in output. A false alarm is a product failure.
- **Round every displayed number.** No floating-point artifacts in balances or plans.
- **Fail calm.** Errors and empty states use June's voice: explain what happened and the next step, never alarm or apologize vaguely.
- **Never store bank credentials.** Only Plaid access tokens, encrypted.
- **Cost control:** route cheap, high-volume work (transaction categorization) to Haiku; reserve Opus for the daily reasoning/advice. Cache the user's stable context where possible.

---

## First prompt to give Claude Code

> Read `Budget_Assistant_Architecture.md` and `June_Personality_Spec.md` in the repo root. Then implement Phase 0 of `June_Build_Spec_for_Claude_Code.md`: scaffold a Flutter mobile app and a Node + TypeScript Fastify backend, set up the Postgres data model described in Phase 0 using Supabase migrations, and build the `POST /checkin/generate` endpoint that calls the Anthropic API (model `claude-opus-4-7`) using June's personality spec section 9 as the system prompt and returns structured JSON. Wire up a manual account/goal entry screen and a daily check-in screen using the design language in the spec. Put all API keys in environment variables — never hardcode them. Stop after Phase 0 so I can run and verify it.
