import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const personalitySpecPath = path.resolve(here, "../../June_Personality_Spec.md");

// Extract §9 verbatim from the personality spec. The file is the source of truth —
// the prompt is version-controlled in markdown, not buried in code.
export async function loadSystemPrompt(): Promise<string> {
  const raw = await readFile(personalitySpecPath, "utf8");
  const start = raw.indexOf("## §9");
  if (start === -1) {
    throw new Error("Could not find §9 in June_Personality_Spec.md");
  }

  // §9 ends at EOF in the current spec. If a later section is added, end at the next "## §".
  const after = raw.slice(start + 5);
  const nextSectionRelative = after.search(/\n## §/);
  const body =
    nextSectionRelative === -1
      ? raw.slice(start)
      : raw.slice(start, start + 5 + nextSectionRelative);

  // Strip the header line and any leading "> " blockquote markers.
  const lines = body.split("\n").slice(1);
  return lines
    .map((line) => line.replace(/^> ?/, ""))
    .join("\n")
    .trim();
}
