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

export async function persistCheckIn(
  userId: string,
  date: string,
  response: {
    standing: string;
    balances: unknown[];
    actions: unknown[];
    paycheck_plan?: unknown;
  }
) {
  await pool.query(
    `insert into checkins (user_id, date, standing_text, balances, actions, paycheck_plan)
     values ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb)`,
    [
      userId,
      date,
      response.standing,
      JSON.stringify(response.balances),
      JSON.stringify(response.actions),
      response.paycheck_plan ? JSON.stringify(response.paycheck_plan) : null,
    ]
  );
}
