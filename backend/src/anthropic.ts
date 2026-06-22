import Anthropic from "@anthropic-ai/sdk";
import { CheckInResponse } from "./schemas.js";

if (!process.env.ANTHROPIC_API_KEY) {
  throw new Error("ANTHROPIC_API_KEY is not set. See .env.example.");
}

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const MODEL = "claude-opus-4-7";

export async function generateCheckIn(
  systemPrompt: string,
  today: string,
  financialContext: unknown
) {
  const userMessage = [
    `Today is ${today}.`,
    "",
    "Here is the user's current financial context as JSON:",
    "",
    JSON.stringify(financialContext, null, 2),
  ].join("\n");

  // Prompt caching on the system prompt — the §9 block is ~1k tokens of stable
  // text reused across every call. Anthropic charges 90% less on cache hits and
  // 25% more on the write; net win after the first call of the 5-min TTL window.
  const res = await client.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system: [
      {
        type: "text",
        text: systemPrompt,
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: [{ role: "user", content: userMessage }],
  });

  const textBlock = res.content.find((b) => b.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("Model returned no text content.");
  }

  const parsed = parseJsonResponse(textBlock.text);
  return CheckInResponse.parse(parsed);
}

// June is told to return JSON only, but defend against accidental ```json fences
// or leading/trailing whitespace anyway.
function parseJsonResponse(raw: string): unknown {
  let text = raw.trim();
  if (text.startsWith("```")) {
    text = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "");
  }
  return JSON.parse(text);
}
