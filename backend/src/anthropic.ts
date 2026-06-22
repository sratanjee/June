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

  const res = await client.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system: systemPrompt,
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
