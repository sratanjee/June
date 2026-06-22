import pg from "pg";

const { Pool } = pg;

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is not set. See .env.example.");
}

export const pool = new Pool({ connectionString: process.env.DATABASE_URL });

export async function loadFinancialContext(userId: string) {
  const [accounts, cards, transactions, goals, budgetTargets] = await Promise.all([
    pool.query(
      `select id, name, type, balance_cents
         from accounts where user_id = $1 order by name`,
      [userId]
    ),
    pool.query(
      `select c.account_id,
              to_char(c.statement_close_date, 'YYYY-MM-DD') as statement_close_date,
              to_char(c.due_date, 'YYYY-MM-DD')             as due_date,
              c.statement_balance_cents, c.current_balance_cents
         from cards c
         join accounts a on a.id = c.account_id
        where a.user_id = $1`,
      [userId]
    ),
    pool.query(
      `select id, account_id, to_char(date,'YYYY-MM-DD') as date,
              description, amount_cents, category, pending
         from transactions
        where user_id = $1
          and date >= current_date - interval '60 days'
        order by date desc`,
      [userId]
    ),
    pool.query(
      `select id, label, target_amount_cents,
              to_char(target_date,'YYYY-MM-DD') as target_date,
              kind, priority
         from goals where user_id = $1 order by priority desc`,
      [userId]
    ),
    pool.query(
      `select id, category, monthly_amount_cents
         from budget_targets where user_id = $1 order by category`,
      [userId]
    ),
  ]);

  return {
    accounts: accounts.rows,
    cards: cards.rows,
    transactions: transactions.rows,
    goals: goals.rows,
    budget_targets: budgetTargets.rows,
  };
}

export type Feeling = "green" | "attention" | "quiet";

/**
 * Derive the overall feeling for a check-in from its actions array.
 *  - any action with severity `attention` → 'attention'
 *  - empty actions array → 'quiet'
 *  - otherwise → 'green'
 */
export function deriveFeeling(
  actions: Array<{ severity?: string } | undefined> | undefined
): Feeling {
  if (!actions || actions.length === 0) return "quiet";
  for (const a of actions) {
    if (a && a.severity === "attention") return "attention";
  }
  return "green";
}

export async function persistCheckIn(
  userId: string,
  date: string,
  response: {
    standing: string;
    balances: unknown[];
    actions: unknown[];
    paycheck_plan?: unknown;
  },
  feeling: Feeling
) {
  await pool.query(
    `insert into checkins (user_id, date, standing_text, balances, actions, paycheck_plan, feeling)
     values ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb, $7)`,
    [
      userId,
      date,
      response.standing,
      JSON.stringify(response.balances),
      JSON.stringify(response.actions),
      response.paycheck_plan ? JSON.stringify(response.paycheck_plan) : null,
      feeling,
    ]
  );
}

export interface LatestCheckin {
  date: string;
  feeling: Feeling | null;
  standing: string;
  balances: unknown;
  actions: unknown;
  paycheck_plan: unknown | null;
  generated_at: string;
}

export async function loadLatestCheckin(userId: string): Promise<LatestCheckin | null> {
  const res = await pool.query<{
    date: string;
    feeling: Feeling | null;
    standing_text: string;
    balances: unknown;
    actions: unknown;
    paycheck_plan: unknown | null;
    generated_at: Date;
  }>(
    `select to_char(date, 'YYYY-MM-DD') as date,
            feeling, standing_text, balances, actions, paycheck_plan, generated_at
       from checkins
      where user_id = $1
      order by date desc, generated_at desc
      limit 1`,
    [userId]
  );
  const row = res.rows[0];
  if (!row) return null;
  return {
    date: row.date,
    feeling: row.feeling,
    standing: row.standing_text,
    balances: row.balances,
    actions: row.actions,
    paycheck_plan: row.paycheck_plan,
    generated_at: row.generated_at instanceof Date
      ? row.generated_at.toISOString()
      : new Date(row.generated_at as unknown as string).toISOString(),
  };
}

/** List all user IDs that have at least one plaid_items row (i.e., onboarded). */
export async function listUserIdsWithPlaidItems(): Promise<string[]> {
  const res = await pool.query<{ user_id: string }>(
    `select distinct user_id from plaid_items`
  );
  return res.rows.map((r) => r.user_id);
}

/** List every user_id from the users table. */
export async function listAllUserIds(): Promise<string[]> {
  const res = await pool.query<{ id: string }>(`select id from users`);
  return res.rows.map((r) => r.id);
}
