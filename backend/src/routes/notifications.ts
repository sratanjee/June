import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { pool } from "../db.js";

const RegisterBody = z.object({
  platform: z.enum(["ios", "android"]),
  token: z.string().min(1).max(4096),
});

export async function registerNotificationRoutes(app: FastifyInstance) {
  // POST /notifications/register — auth required. Upserts a device token.
  app.post("/notifications/register", async (req, reply) => {
    const user = req.user;
    if (!user) {
      return reply.code(401).send({
        standing: "I need a signed-in session to register your device.",
      });
    }

    const parsed = RegisterBody.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({
        standing: "I couldn't read that request.",
        issues: parsed.error.format(),
      });
    }

    try {
      // Upsert keyed on (user_id, token). If the device token already exists,
      // bump last_seen_at so we know it's still active.
      await pool.query(
        `insert into device_tokens (user_id, platform, token)
         values ($1, $2, $3)
         on conflict (user_id, token) do update
           set platform = excluded.platform,
               last_seen_at = now()`,
        [user.id, parsed.data.platform, parsed.data.token]
      );
      return reply.send({ ok: true });
    } catch (err) {
      req.log.error({ err }, "notifications/register failed");
      return reply.code(500).send({
        standing: "I couldn't save that device just now. Try again in a moment.",
      });
    }
  });
}
