import crypto from "node:crypto";
import { Configuration, PlaidApi, PlaidEnvironments } from "plaid";

// ---------------- env-driven config ----------------

const clientId = process.env.PLAID_CLIENT_ID?.trim() ?? "";
const secret = process.env.PLAID_SECRET?.trim() ?? "";
const envName = (process.env.PLAID_ENV ?? "sandbox").trim().toLowerCase();

export const plaidConfigured: boolean = clientId.length > 0 && secret.length > 0;

function basePathFor(env: string): string {
  switch (env) {
    case "production":
      return PlaidEnvironments.production;
    case "development":
      // Plaid retains `.development` in older SDKs; some newer SDKs collapse to sandbox/production.
      // Fall back gracefully if the SDK no longer exposes it.
      return (PlaidEnvironments as Record<string, string>).development
        ?? PlaidEnvironments.sandbox;
    case "sandbox":
    default:
      return PlaidEnvironments.sandbox;
  }
}

let cachedClient: PlaidApi | null = null;

export function getPlaidClient(): PlaidApi {
  if (!plaidConfigured) {
    throw new Error(
      "Plaid is not configured. Set PLAID_CLIENT_ID and PLAID_SECRET in backend/.env and restart."
    );
  }
  if (cachedClient) return cachedClient;

  const config = new Configuration({
    basePath: basePathFor(envName),
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": clientId,
        "PLAID-SECRET": secret,
      },
    },
  });
  cachedClient = new PlaidApi(config);
  return cachedClient;
}

// Convenience accessors for route handlers — read fresh each call so .env edits
// during dev are visible without restart of the route layer (but the Plaid client
// itself is cached above).
export function plaidProducts(): string[] {
  return (process.env.PLAID_PRODUCTS ?? "auth,transactions,liabilities")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

export function plaidCountryCodes(): string[] {
  return (process.env.PLAID_COUNTRY_CODES ?? "US")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

// ---------------- AES-256-GCM token encryption ----------------
//
// We never want a raw Plaid access_token to sit in Postgres. Encryption is
// keyed off PLAID_TOKEN_ENC_KEY (32-byte hex). If absent we generate a random
// key once per process and warn — fine for first-run dev, NOT acceptable for
// any environment whose data outlives the process (the key must be durable, or
// existing rows become unreadable).

const KEY_BYTES = 32;
const IV_BYTES = 12; // GCM standard
const TAG_BYTES = 16;

let cachedKey: Buffer | null = null;

function loadKey(): Buffer {
  if (cachedKey) return cachedKey;
  const fromEnv = (process.env.PLAID_TOKEN_ENC_KEY ?? "").trim();
  if (fromEnv.length > 0) {
    let buf: Buffer;
    try {
      buf = Buffer.from(fromEnv, "hex");
    } catch {
      throw new Error("PLAID_TOKEN_ENC_KEY must be hex-encoded.");
    }
    if (buf.length !== KEY_BYTES) {
      throw new Error(
        `PLAID_TOKEN_ENC_KEY must decode to ${KEY_BYTES} bytes (64 hex chars); got ${buf.length}.`
      );
    }
    cachedKey = buf;
    return cachedKey;
  }
  // Ephemeral fallback — data encrypted here cannot be decrypted after restart.
  const ephemeral = crypto.randomBytes(KEY_BYTES);
  // eslint-disable-next-line no-console
  console.warn(
    "[plaid] PLAID_TOKEN_ENC_KEY not set. Using an ephemeral key — stored tokens will be unreadable after restart. " +
      "Set PLAID_TOKEN_ENC_KEY=" +
      ephemeral.toString("hex") +
      " in backend/.env to persist."
  );
  cachedKey = ephemeral;
  return cachedKey;
}

/**
 * Encrypts a plaintext access_token. Returns a Buffer suitable for `bytea`
 * storage with layout: [12-byte iv][16-byte tag][ciphertext].
 */
export function encryptAccessToken(plaintext: string): Buffer {
  const key = loadKey();
  const iv = crypto.randomBytes(IV_BYTES);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, ct]);
}

/** Inverse of `encryptAccessToken`. */
export function decryptAccessToken(blob: Buffer): string {
  if (blob.length < IV_BYTES + TAG_BYTES + 1) {
    throw new Error("Encrypted access_token blob is too short to be valid.");
  }
  const key = loadKey();
  const iv = blob.subarray(0, IV_BYTES);
  const tag = blob.subarray(IV_BYTES, IV_BYTES + TAG_BYTES);
  const ct = blob.subarray(IV_BYTES + TAG_BYTES);
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const pt = Buffer.concat([decipher.update(ct), decipher.final()]);
  return pt.toString("utf8");
}
