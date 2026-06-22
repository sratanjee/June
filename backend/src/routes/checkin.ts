import type { FastifyInstance } from "fastify";
import { GenerateCheckInRequest } from "../schemas.js";
import { generateCheckIn } from "../anthropic.js";
import { loadFinancialContext, persistCheckIn } from "../db.js";

export async function registerCheckInRoutes(
  app: FastifyInstance,
  opts: { systemPrompt: string }
) {
  app.post("/checkin/generate", async (req, reply) => {
    const body = GenerateCheckInRequest.safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({
        standing: "I couldn't read that request. Check the date and context shape.",
        issues: body.error.format(),
      });
    }

    const { today } = body.data;
    let context = body.data.context;

    // Auth-aware: prefer req.user.id when present, else fall back to legacy
    // body.user_id (demo-user path).
    const authedUserId = req.user?.id ?? null;

    if (body.data.user_id && authedUserId) {
      req.log.warn("deprecated: body.user_id passed alongside JWT; using JWT");
    }

    // If context is missing or has no accounts, load it from the DB —
    // but only if we have an authenticated user. Demo-user callers MUST pass
    // context inline.
    const contextEmpty = !context || context.accounts.length === 0;
    if (contextEmpty) {
      if (!authedUserId) {
        return reply.code(400).send({
          standing:
            "I need either a signed-in session or a context block to read from. Sign in or include your context inline.",
        });
      }

      const loaded = await loadFinancialContext(authedUserId);
      context = {
        accounts: loaded.accounts.map((a) => ({
          name: a.name,
          type: a.type,
          balance_cents: a.balance_cents,
        })),
        cards: loaded.cards.map((c) => ({
          // The DB row exposes account_id; the inline schema uses account_name.
          // We don't have the join wired here, so fall back to the id as a label.
          // Anthropic only uses this to reason; the shape is what matters.
          account_name: c.account_id,
          statement_close_date: c.statement_close_date,
          due_date: c.due_date,
          statement_balance_cents: c.statement_balance_cents,
          current_balance_cents: c.current_balance_cents,
        })),
        transactions: loaded.transactions.map((t) => ({
          date: t.date,
          description: t.description,
          amount_cents: t.amount_cents,
          category: t.category,
          pending: t.pending,
        })),
        goals: loaded.goals.map((g) => ({
          label: g.label,
          target_amount_cents: g.target_amount_cents,
          target_date: g.target_date,
          kind: g.kind,
          priority: g.priority,
        })),
        budget_targets: loaded.budget_targets.map((b) => ({
          category: b.category,
          monthly_amount_cents: b.monthly_amount_cents,
        })),
        // Paychecks aren't yet persisted in Phase 0 schema; pass empty for now.
        paychecks: [],
      };
    }

    try {
      const checkin = await generateCheckIn(opts.systemPrompt, today, context);

      // Persist only for authenticated users. Demo-user calls stay ephemeral.
      if (authedUserId) {
        try {
          await persistCheckIn(authedUserId, today, checkin);
        } catch (err) {
          // Don't fail the response if persistence trips — clients still
          // want the generated check-in.
          req.log.error({ err }, "checkin persistence failed");
        }
      }

      return reply.send(checkin);
    } catch (err) {
      req.log.error({ err }, "checkin generation failed");
      return reply.code(502).send({
        standing: "I'm having trouble thinking this through. Try again in a moment.",
        balances: [],
        actions: [],
      });
    }
  });
}
