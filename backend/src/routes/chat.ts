import type { FastifyInstance } from "fastify";
import Anthropic from "@anthropic-ai/sdk";
import { ChatRequest } from "../schemas.js";

const MODEL = "claude-opus-4-7";
const MAX_TOKENS = 2048;

export async function registerChatRoutes(
  app: FastifyInstance,
  opts: { systemPrompt: string }
) {
  app.post("/chat", async (req, reply) => {
    // Defensive 503 if Anthropic isn't configured. Returned as plain JSON.
    if (!process.env.ANTHROPIC_API_KEY) {
      return reply.code(503).send({
        standing:
          "Chat isn't set up yet. Add ANTHROPIC_API_KEY to backend/.env and restart.",
      });
    }

    // Validate. 400 is plain JSON per contract.
    const parsed = ChatRequest.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({
        standing: "I couldn't read that request. Check the message shape.",
        issues: parsed.error.format(),
      });
    }

    const { today, context, history, message } = parsed.data;

    // Build the Anthropic messages array.
    // - If history is empty, the new message is the FIRST user turn and carries
    //   the financial context + today.
    // - If history is non-empty, history's first user turn already carried the
    //   context. We just append history then the new user turn.
    const messages: Array<{ role: "user" | "assistant"; content: string }> = [];

    if (history.length === 0) {
      const firstUserContent = [
        `Today is ${today}.`,
        "",
        "Here is the user's current financial context as JSON:",
        "",
        "```json",
        JSON.stringify(context, null, 2),
        "```",
        "",
        message,
      ].join("\n");
      messages.push({ role: "user", content: firstUserContent });
    } else {
      for (const turn of history) {
        messages.push({ role: turn.role, content: turn.text });
      }
      messages.push({ role: "user", content: message });
    }

    // Take over the raw response stream for SSE.
    reply.hijack();
    const raw = reply.raw;
    raw.setHeader("content-type", "text/event-stream");
    raw.setHeader("cache-control", "no-cache");
    raw.setHeader("connection", "keep-alive");
    raw.setHeader("x-accel-buffering", "no");
    raw.statusCode = 200;
    // Flush headers so the client sees the stream open immediately.
    if (typeof raw.flushHeaders === "function") raw.flushHeaders();

    const writeEvent = (payload: unknown) => {
      raw.write(`data: ${JSON.stringify(payload)}\n\n`);
    };

    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    try {
      const stream = client.messages.stream({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: opts.systemPrompt,
        messages,
      });

      stream.on("text", (text: string) => {
        if (text.length === 0) return;
        writeEvent({ type: "delta", text });
      });

      await stream.finalMessage();

      writeEvent({ type: "done" });
      raw.end();
    } catch (err) {
      req.log.error({ err }, "chat stream failed");
      try {
        writeEvent({
          type: "error",
          message:
            "I'm having trouble thinking this through. Try again in a moment.",
        });
      } catch {
        // ignore — socket may already be dead
      }
      try {
        raw.end();
      } catch {
        // ignore
      }
    }
  });
}
