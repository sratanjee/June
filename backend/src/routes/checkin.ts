import type { FastifyInstance } from "fastify";
import { GenerateCheckInRequest } from "../schemas.js";
import { generateCheckIn } from "../anthropic.js";

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

    const { today, context } = body.data;

    try {
      const checkin = await generateCheckIn(opts.systemPrompt, today, context);
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
