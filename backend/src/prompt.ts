import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
// SPEC_PATH env override lets containers / non-standard layouts point at the
// spec without changing code. Default resolves from compiled dist/ → repo root.
const personalitySpecPath = process.env.SPEC_PATH
  ? path.resolve(process.env.SPEC_PATH)
  : path.resolve(here, "../../June_Personality_Spec.md");

let cachedSpec: string | null = null;

async function readSpec(): Promise<string> {
  if (cachedSpec === null) {
    cachedSpec = await readFile(personalitySpecPath, "utf8");
  }
  return cachedSpec;
}

// Extract a "## §N" section's verbatim body (with blockquote markers stripped).
function extractSection(raw: string, marker: string): string {
  const start = raw.indexOf(marker);
  if (start === -1) {
    throw new Error(`Could not find ${marker} in June_Personality_Spec.md`);
  }
  const after = raw.slice(start + marker.length);
  const nextSectionRelative = after.search(/\n## §/);
  const body =
    nextSectionRelative === -1
      ? raw.slice(start)
      : raw.slice(start, start + marker.length + nextSectionRelative);

  const lines = body.split("\n").slice(1);
  return lines
    .map((line) => line.replace(/^> ?/, ""))
    .join("\n")
    .trim();
}

// §9 — check-in flow. Forces structured JSON output.
export async function loadCheckInSystemPrompt(): Promise<string> {
  return extractSection(await readSpec(), "## §9");
}

// §10 — chat flow. Conversational prose only, no JSON.
export async function loadChatSystemPrompt(): Promise<string> {
  return extractSection(await readSpec(), "## §10");
}

// Back-compat shim — old call sites that just say "system prompt" get the
// check-in shape, since that was the only one before §10 existed.
export const loadSystemPrompt = loadCheckInSystemPrompt;
