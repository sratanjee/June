import { z } from "zod";

// ---------- Inbound financial context shape ----------

export const AccountSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  type: z.enum(["checking", "savings", "credit_card"]),
  balance_cents: z.number().int(),
});

export const CardSchema = z.object({
  account_id: z.string().uuid(),
  statement_close_date: z.string().nullable(),
  due_date: z.string().nullable(),
  statement_balance_cents: z.number().int(),
  current_balance_cents: z.number().int(),
});

export const TransactionSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  date: z.string(),
  description: z.string(),
  amount_cents: z.number().int(),
  category: z.string().nullable(),
  pending: z.boolean(),
});

export const GoalSchema = z.object({
  id: z.string().uuid(),
  label: z.string(),
  target_amount_cents: z.number().int().nonnegative(),
  target_date: z.string().nullable(),
  kind: z.enum(["savings", "expense", "debt"]),
  priority: z.number().int(),
});

export const BudgetTargetSchema = z.object({
  id: z.string().uuid(),
  category: z.string(),
  monthly_amount_cents: z.number().int().nonnegative(),
});

// ---------- Request / response ----------

// Phase 0: the client sends the financial context inline (no auth/users yet).
// Phase 1+: switch to { user_id, today } and load from DB on the backend.
export const InlineFinancialContext = z.object({
  accounts: z.array(z.object({
    name: z.string(),
    type: z.enum(["checking", "savings", "credit_card"]),
    balance_cents: z.number().int(),
  })),
  cards: z.array(z.object({
    account_name: z.string(),
    statement_close_date: z.string().nullable(),
    due_date: z.string().nullable(),
    statement_balance_cents: z.number().int(),
    current_balance_cents: z.number().int(),
  })).default([]),
  transactions: z.array(z.object({
    date: z.string(),
    description: z.string(),
    amount_cents: z.number().int(),
    category: z.string().nullable(),
    pending: z.boolean(),
  })).default([]),
  goals: z.array(z.object({
    label: z.string(),
    target_amount_cents: z.number().int().nonnegative(),
    target_date: z.string().nullable(),
    kind: z.enum(["savings", "expense", "debt"]),
    priority: z.number().int().default(0),
  })).default([]),
  budget_targets: z.array(z.object({
    category: z.string(),
    monthly_amount_cents: z.number().int().nonnegative(),
  })).default([]),
});

export const GenerateCheckInRequest = z.object({
  today: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  context: InlineFinancialContext,
});

export const CheckInResponse = z.object({
  standing: z.string().min(1),
  balances: z
    .array(
      z.object({
        label: z.string(),
        amount: z.number(),
        subtext: z.string().optional(),
      })
    )
    .min(2)
    .max(5),
  actions: z
    .array(
      z.object({
        title: z.string(),
        detail: z.string(),
        severity: z.enum(["ok", "attention", "info"]),
      })
    )
    .max(2),
  paycheck_plan: z
    .object({
      next_paycheck_date: z.string(),
      amount: z.number(),
      allocations: z.array(
        z.object({
          label: z.string(),
          amount: z.number(),
        })
      ),
    })
    .optional(),
});

export type CheckInResponse = z.infer<typeof CheckInResponse>;
