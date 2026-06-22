import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";

/**
 * Cascading user-data deletion. Phase 4 prep for the "data subject deletion"
 * surface. We wipe every app-owned row keyed to the authenticated user, but
 * leave the Supabase auth.users row in place — auth account deletion is a
 * separate Supabase Admin call that the client (or a Phase 4 flow) drives.
 */
export async function registerAccountRoutes(app: FastifyInstance) {
  app.post("/account/delete", async (req, reply) => {
    const user = req.user;
    if (!user) {
      return reply.code(401).send({
        standing: "I need a signed-in session to delete your account data.",
      });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // Order matters: clear children before parents to keep FKs happy even
      // when ON DELETE CASCADE isn't set.
      const checkins = await client.query(
        `delete from checkins where user_id = $1`,
        [user.id]
      );
      const budgetTargets = await client.query(
        `delete from budget_targets where user_id = $1`,
        [user.id]
      );
      const transactions = await client.query(
        `delete from transactions where user_id = $1`,
        [user.id]
      );
      // cards have no user_id column; reach them via accounts.
      const cards = await client.query(
        `delete from cards
          where account_id in (select id from accounts where user_id = $1)`,
        [user.id]
      );
      const accounts = await client.query(
        `delete from accounts where user_id = $1`,
        [user.id]
      );
      const goals = await client.query(
        `delete from goals where user_id = $1`,
        [user.id]
      );
      const plaidItems = await client.query(
        `delete from plaid_items where user_id = $1`,
        [user.id]
      );
      const categoryOverrides = await client.query(
        `delete from category_overrides where user_id = $1`,
        [user.id]
      );

      await client.query("COMMIT");

      return reply.send({
        ok: true,
        deleted: {
          checkins: checkins.rowCount ?? 0,
          budget_targets: budgetTargets.rowCount ?? 0,
          transactions: transactions.rowCount ?? 0,
          cards: cards.rowCount ?? 0,
          accounts: accounts.rowCount ?? 0,
          goals: goals.rowCount ?? 0,
          plaid_items: plaidItems.rowCount ?? 0,
          category_overrides: categoryOverrides.rowCount ?? 0,
        },
      });
    } catch (err) {
      try {
        await client.query("ROLLBACK");
      } catch {
        // ignore — connection may already be dead
      }
      req.log.error({ err }, "account deletion failed");
      return reply.code(500).send({
        standing:
          "I couldn't finish deleting your data. Nothing was changed. Try again in a moment.",
      });
    } finally {
      client.release();
    }
  });
}
