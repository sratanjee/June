import type { FastifyInstance } from "fastify";
import { generateCheckIn } from "../anthropic.js";
import {
  deriveFeeling,
  listAllUserIds,
  loadFinancialContext,
  persistCheckIn,
} from "../db.js";
import { plaidConfigured } from "../plaid.js";
import { syncForUser } from "./plaid.js";
import { sendPush } from "../push.js";

/**
 * Daily morning automation:
 *   1. For every user, sync each of their plaid_items.
 *   2. Build today's context from the freshly-synced DB rows.
 *   3. Generate + persist a check-in.
 *   4. Fire a (currently stubbed) push notification keyed off the feeling.
 *
 * Protected by a shared secret in the `x-job-key` header. Set `JOB_KEY` via
 * Fly secrets (and in backend/.env for local dev).
 */
export async function registerJobRoutes(
  app: FastifyInstance,
  opts: { systemPrompt: string }
) {
  app.post("/jobs/morning-sync-and-checkin", async (req, reply) => {
    const expected = process.env.JOB_KEY?.trim() ?? "";
    if (!expected) {
      // Fail closed: without a configured JOB_KEY we can't authenticate the cron.
      return reply.code(503).send({
        error: "JOB_KEY is not configured on the server",
      });
    }
    const got = req.headers["x-job-key"];
    const provided = Array.isArray(got) ? got[0] : got;
    if (!provided || provided !== expected) {
      return reply.code(401).send({ error: "invalid job key" });
    }

    const today = new Date().toISOString().slice(0, 10);
    const userIds = await listAllUserIds();
    const errors: Array<{ user_id: string; step: string; message: string }> = [];
    let processed = 0;

    for (const userId of userIds) {
      try {
        // 1. Sync Plaid for this user (no-op if they have no plaid_items).
        if (plaidConfigured) {
          try {
            await syncForUser(userId);
          } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            req.log.error({ err, userId }, "morning sync: plaid failed");
            errors.push({ user_id: userId, step: "plaid_sync", message });
            // Continue — even without fresh Plaid data we can still generate a
            // check-in from whatever is already in the DB.
          }
        }

        // 2. Build context from the DB.
        const loaded = await loadFinancialContext(userId);
        if (loaded.accounts.length === 0) {
          // Pre-onboarded user. Skip the check-in for them today.
          req.log.info({ userId }, "morning sync: skipping, no accounts");
          processed++;
          continue;
        }

        const context = {
          accounts: loaded.accounts.map((a) => ({
            name: a.name,
            type: a.type,
            balance_cents: a.balance_cents,
          })),
          cards: loaded.cards.map((c) => ({
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
          paychecks: [],
        };

        // 3. Generate + persist the check-in.
        const checkin = await generateCheckIn(opts.systemPrompt, today, context);
        const feeling = deriveFeeling(checkin.actions);
        try {
          await persistCheckIn(userId, today, checkin, feeling);
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          req.log.error({ err, userId }, "morning sync: persist failed");
          errors.push({ user_id: userId, step: "persist_checkin", message });
        }

        // 4. Fire the push (stubbed for now — logs only until APNs/FCM keys land).
        try {
          const firstAction = checkin.actions?.[0];
          const title = pushTitleFor(feeling);
          const body = firstAction?.title ?? checkin.standing.slice(0, 120);
          await sendPush(userId, title, body);
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          req.log.error({ err, userId }, "morning sync: push failed");
          errors.push({ user_id: userId, step: "push", message });
        }

        processed++;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        req.log.error({ err, userId }, "morning sync: user failed");
        errors.push({ user_id: userId, step: "user", message });
      }
    }

    return reply.send({ users_processed: processed, errors });
  });
}

/**
 * June-voice push titles. Short, warm, status-aware. Real personality work
 * happens once the APNs key lands and we can A/B; this is the scaffold.
 */
function pushTitleFor(feeling: "green" | "attention" | "quiet"): string {
  switch (feeling) {
    case "attention":
      return "One thing worth a look";
    case "quiet":
      return "Quiet morning";
    case "green":
    default:
      return "You're set for the day";
  }
}
