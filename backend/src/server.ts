import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import { loadSystemPrompt } from "./prompt.js";
import { registerAuth } from "./auth.js";
import { registerCheckInRoutes } from "./routes/checkin.js";
import { registerPlaidRoutes } from "./routes/plaid.js";
import { registerChatRoutes } from "./routes/chat.js";

async function main() {
  const systemPrompt = await loadSystemPrompt();

  const app = Fastify({
    logger: { transport: { target: "pino-pretty", options: { colorize: true } } },
  });

  await app.register(cors, { origin: true });

  await registerAuth(app);

  app.get("/health", async () => ({ ok: true }));

  await registerCheckInRoutes(app, { systemPrompt });
  await registerPlaidRoutes(app, { systemPrompt });
  await registerChatRoutes(app, { systemPrompt });

  const port = Number(process.env.PORT ?? 4000);
  const host = process.env.HOST ?? "0.0.0.0";
  await app.listen({ port, host });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
