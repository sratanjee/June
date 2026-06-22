import crypto from "node:crypto";
import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import {
  CountryCode,
  Products,
  type AccountBase,
  type LiabilitiesObject,
  type Transaction as PlaidTransaction,
  type TransactionsSyncRequest,
} from "plaid";

import { pool } from "../db.js";
import {
  decryptAccessToken,
  encryptAccessToken,
  getPlaidClient,
  plaidConfigured,
  plaidCountryCodes,
  plaidProducts,
} from "../plaid.js";

// ---------- request schemas ----------

// user_id is now optional on the body — preferred source is req.user.id from
// the JWT. Kept for backward compatibility this pass; remove in Phase 4.
const UserIdBody = z.object({ user_id: z.string().uuid().optional() });
const ExchangeBody = z.object({
  user_id: z.string().uuid().optional(),
  public_token: z.string().min(1),
});

// Plaid webhook bodies are large/loose; only the routing fields matter here.
const WebhookBody = z.object({
  webhook_type: z.string(),
  webhook_code: z.string(),
  item_id: z.string().optional(),
}).passthrough();

// ---------- shared guard ----------

function guard(reply: import("fastify").FastifyReply): boolean {
  if (!plaidConfigured) {
    reply.code(503).send({
      standing:
        "Bank linking isn't set up yet. Add Plaid keys to backend/.env and restart.",
    });
    return false;
  }
  return true;
}

// ---------- helpers ----------

function toProducts(values: string[]): Products[] {
  // Cast carefully: Products is a string enum so the runtime string equals the value.
  return values.filter((v) => v.length > 0) as Products[];
}

function toCountryCodes(values: string[]): CountryCode[] {
  return values.filter((v) => v.length > 0) as CountryCode[];
}

function mapAccountType(plaidType: string, plaidSubtype: string | null): "checking" | "savings" | "credit_card" {
  if (plaidType === "credit") return "credit_card";
  if (plaidType === "depository") {
    if (plaidSubtype === "savings") return "savings";
    return "checking";
  }
  // Loans, investment, etc. — collapse to checking for now; Phase 2 can refine.
  return "checking";
}

function dollarsToCents(value: number | null | undefined): number {
  if (value == null || Number.isNaN(value)) return 0;
  return Math.round(value * 100);
}

function dateOrNull(value: string | null | undefined): string | null {
  if (!value) return null;
  // Plaid returns YYYY-MM-DD already; defensive trim.
  return value.length >= 10 ? value.slice(0, 10) : null;
}

// ---------- core sync (used by /plaid/sync AND the webhook) ----------

export async function syncForUser(userId: string): Promise<{
  accounts: number;
  transactions: { added: number; modified: number; removed: number };
  cards: number;
}> {
  const plaid = getPlaidClient();

  const itemsRes = await pool.query<{
    id: string;
    plaid_item_id: string;
    access_token_encrypted: Buffer;
    next_cursor: string | null;
  }>(
    `select id, plaid_item_id, access_token_encrypted, next_cursor
       from plaid_items where user_id = $1`,
    [userId]
  );

  let accountsTotal = 0;
  let added = 0;
  let modified = 0;
  let removed = 0;
  let cardsTotal = 0;

  for (const item of itemsRes.rows) {
    const accessToken = decryptAccessToken(item.access_token_encrypted);

    // ---- accounts ----
    const accountsResp = await plaid.accountsGet({ access_token: accessToken });
    const plaidAccounts: AccountBase[] = accountsResp.data.accounts;

    // Map plaid_account_id -> internal account id so transactions can FK correctly.
    const accountIdByPlaidId = new Map<string, string>();

    for (const acct of plaidAccounts) {
      const internalType = mapAccountType(acct.type, acct.subtype ?? null);
      const balanceDollars =
        acct.balances.current ?? acct.balances.available ?? 0;
      // Credit cards: Plaid reports `current` as the debt; we want a negative balance.
      const signedDollars =
        internalType === "credit_card" ? -Math.abs(balanceDollars) : balanceDollars;
      const balanceCents = dollarsToCents(signedDollars);

      const upsert = await pool.query<{ id: string }>(
        `insert into accounts (user_id, name, type, balance_cents, plaid_account_id, plaid_access_token_encrypted)
         values ($1, $2, $3, $4, $5, $6)
         on conflict (plaid_account_id) do update
           set name = excluded.name,
               type = excluded.type,
               balance_cents = excluded.balance_cents,
               plaid_access_token_encrypted = excluded.plaid_access_token_encrypted
         returning id`,
        [
          userId,
          acct.name ?? acct.official_name ?? "Account",
          internalType,
          balanceCents,
          acct.account_id,
          item.access_token_encrypted,
        ]
      );
      accountIdByPlaidId.set(acct.account_id, upsert.rows[0].id);
      accountsTotal++;
    }

    // ---- transactions via /transactions/sync ----
    let cursor: string | null = item.next_cursor;
    let hasMore = true;

    while (hasMore) {
      const req: TransactionsSyncRequest = {
        access_token: accessToken,
        cursor: cursor ?? undefined,
        count: 250,
      };
      const resp = await plaid.transactionsSync(req);
      const { added: addedTxs, modified: modTxs, removed: rmTxs, has_more, next_cursor } = resp.data;

      for (const tx of addedTxs) {
        await upsertTransaction(userId, tx, accountIdByPlaidId);
        added++;
      }
      for (const tx of modTxs) {
        await upsertTransaction(userId, tx, accountIdByPlaidId);
        modified++;
      }
      for (const rm of rmTxs) {
        if (rm.transaction_id) {
          await pool.query(
            `delete from transactions where plaid_transaction_id = $1`,
            [rm.transaction_id]
          );
          removed++;
        }
      }

      cursor = next_cursor;
      hasMore = has_more;
    }

    await pool.query(
      `update plaid_items set next_cursor = $1, last_synced_at = now() where id = $2`,
      [cursor, item.id]
    );

    // ---- liabilities (credit-card details) ----
    try {
      const liabResp = await plaid.liabilitiesGet({ access_token: accessToken });
      const liab: LiabilitiesObject | undefined = liabResp.data.liabilities;
      if (liab?.credit) {
        for (const cc of liab.credit) {
          if (!cc.account_id) continue;
          const internalId = accountIdByPlaidId.get(cc.account_id);
          if (!internalId) continue;
          await pool.query(
            `insert into cards (account_id, statement_close_date, due_date,
                                statement_balance_cents, current_balance_cents)
             values ($1, $2, $3, $4, $5)
             on conflict (account_id) do update
               set statement_close_date    = excluded.statement_close_date,
                   due_date                = excluded.due_date,
                   statement_balance_cents = excluded.statement_balance_cents,
                   current_balance_cents   = excluded.current_balance_cents`,
            [
              internalId,
              dateOrNull(cc.last_statement_issue_date),
              dateOrNull(cc.next_payment_due_date),
              dollarsToCents(cc.last_statement_balance),
              dollarsToCents(
                // current balance lives on the AccountBase, not on the credit object.
                plaidAccounts.find((a) => a.account_id === cc.account_id)?.balances.current ?? 0
              ),
            ]
          );
          cardsTotal++;
        }
      }
    } catch (err) {
      // Liabilities isn't available for every item. Don't fail the whole sync.
      // eslint-disable-next-line no-console
      console.warn("[plaid] liabilitiesGet failed (non-fatal):", err);
    }
  }

  return {
    accounts: accountsTotal,
    transactions: { added, modified, removed },
    cards: cardsTotal,
  };
}

async function upsertTransaction(
  userId: string,
  tx: PlaidTransaction,
  accountIdByPlaidId: Map<string, string>
) {
  const internalAccountId = accountIdByPlaidId.get(tx.account_id);
  if (!internalAccountId) return; // tx for an account we didn't ingest

  // Plaid `amount`: positive = outflow (money leaving). June stores signed where negative = outflow.
  const amountCents = dollarsToCents(-tx.amount);
  const category =
    tx.personal_finance_category?.primary ??
    (tx.category && tx.category.length > 0 ? tx.category[0] : null);

  await pool.query(
    `insert into transactions (user_id, account_id, date, description, amount_cents,
                                category, pending, plaid_transaction_id)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     on conflict (plaid_transaction_id) do update
       set account_id   = excluded.account_id,
           date         = excluded.date,
           description  = excluded.description,
           amount_cents = excluded.amount_cents,
           category     = excluded.category,
           pending      = excluded.pending`,
    [
      userId,
      internalAccountId,
      tx.date,
      tx.name ?? tx.merchant_name ?? "Transaction",
      amountCents,
      category,
      tx.pending ?? false,
      tx.transaction_id,
    ]
  );
}

// ---------- webhook JWT verification ----------
//
// Per Plaid docs (https://plaid.com/docs/api/webhooks/webhook-verification/):
//  1. Decode `Plaid-Verification` header (a JWS, ES256, with `kid`).
//  2. Fetch the JWK for that `kid` via /webhook_verification_key/get. Cache it.
//  3. Verify signature using ES256 (P-256 ECDSA).
//  4. Confirm `iat` is recent (< 5 minutes old).
//  5. Confirm SHA-256 of the raw request body equals payload `request_body_sha256`.

interface CachedKey {
  key: crypto.KeyObject;
  expiresAt: number; // ms epoch; 0 = no expiry yet (refresh on next miss)
}
const jwkCache = new Map<string, CachedKey>();

function base64UrlDecode(input: string): Buffer {
  const pad = input.length % 4 === 0 ? "" : "=".repeat(4 - (input.length % 4));
  return Buffer.from(input.replace(/-/g, "+").replace(/_/g, "/") + pad, "base64");
}

function decodeJwtHeader(token: string): { alg: string; kid: string; typ?: string } {
  const seg = token.split(".");
  if (seg.length !== 3) throw new Error("malformed jwt");
  const headerJson = base64UrlDecode(seg[0]).toString("utf8");
  return JSON.parse(headerJson);
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  const seg = token.split(".");
  if (seg.length !== 3) throw new Error("malformed jwt");
  const payloadJson = base64UrlDecode(seg[1]).toString("utf8");
  return JSON.parse(payloadJson);
}

async function getVerificationKey(kid: string): Promise<crypto.KeyObject> {
  const cached = jwkCache.get(kid);
  if (cached && (cached.expiresAt === 0 || cached.expiresAt > Date.now())) {
    return cached.key;
  }

  const plaid = getPlaidClient();
  const resp = await plaid.webhookVerificationKeyGet({ key_id: kid });
  const jwk = resp.data.key;
  if (!jwk || jwk.kty !== "EC" || jwk.crv !== "P-256") {
    throw new Error(`unexpected JWK shape for kid=${kid}`);
  }

  // crypto.createPublicKey accepts a JWK directly (Node 18+).
  const key = crypto.createPublicKey({
    key: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y } as crypto.JsonWebKey,
    format: "jwk",
  });

  // expired_at (Unix seconds) → ms. Null = currently active; re-pull occasionally
  // via the 24-hour TTL we set ourselves so rotated keys don't stale forever.
  const exp = jwk.expired_at != null ? jwk.expired_at * 1000 : Date.now() + 24 * 60 * 60 * 1000;
  jwkCache.set(kid, { key, expiresAt: exp });
  return key;
}

/**
 * Verifies the Plaid-Verification JWT for a webhook request.
 * Throws on any failure; returns void on success.
 */
async function verifyPlaidWebhook(
  jwt: string,
  rawBody: Buffer | string
): Promise<void> {
  const header = decodeJwtHeader(jwt);
  if (header.alg !== "ES256") {
    throw new Error(`unexpected alg: ${header.alg}`);
  }
  if (!header.kid) throw new Error("missing kid");

  const key = await getVerificationKey(header.kid);

  const [headerSeg, payloadSeg, sigSeg] = jwt.split(".");
  const signingInput = Buffer.from(`${headerSeg}.${payloadSeg}`, "utf8");
  const sigRaw = base64UrlDecode(sigSeg); // r || s, 64 bytes for P-256

  // Node's verify wants DER for ECDSA by default — pass `dsaEncoding: "ieee-p1363"`
  // so we can hand it the JOSE 64-byte concatenated form directly.
  const verifier = crypto.createVerify("SHA256");
  verifier.update(signingInput);
  verifier.end();
  const ok = verifier.verify(
    { key, dsaEncoding: "ieee-p1363" },
    sigRaw
  );
  if (!ok) throw new Error("signature verification failed");

  const payload = decodeJwtPayload(jwt);

  // iat must be within the last 5 minutes.
  const iat = typeof payload.iat === "number" ? payload.iat : NaN;
  if (!Number.isFinite(iat)) throw new Error("missing iat");
  const ageSec = Math.floor(Date.now() / 1000) - iat;
  if (ageSec > 5 * 60 || ageSec < -60) {
    throw new Error(`iat outside acceptable window (age=${ageSec}s)`);
  }

  // Confirm the body SHA-256 matches.
  const claimedHash = payload.request_body_sha256;
  if (typeof claimedHash !== "string") throw new Error("missing request_body_sha256");
  const bodyBuf = typeof rawBody === "string" ? Buffer.from(rawBody, "utf8") : rawBody;
  const actualHash = crypto.createHash("sha256").update(bodyBuf).digest("hex");
  if (actualHash !== claimedHash) {
    throw new Error("request body hash mismatch");
  }
}

declare module "fastify" {
  interface FastifyRequest {
    /** Raw request body bytes, captured by the Plaid webhook content-type parser. */
    rawBody?: string;
  }
}

function rawBodyFromRequest(req: FastifyRequest): string {
  // Webhook route registers a custom content-type parser that pins the raw
  // string to req.rawBody. Fall back to a re-serialization if absent (other
  // routes don't capture raw bytes), but that path should never run for the
  // signed webhook handler.
  if (typeof req.rawBody === "string") return req.rawBody;
  return JSON.stringify(req.body ?? {});
}

// ---------- routes ----------

export async function registerPlaidRoutes(
  app: FastifyInstance,
  _opts: { systemPrompt?: string } = {}
) {
  // POST /plaid/link-token
  app.post("/plaid/link-token", async (req, reply) => {
    if (!guard(reply)) return;

    const body = UserIdBody.safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({
        standing: "I couldn't read that request.",
        issues: body.error.format(),
      });
    }

    const userId = req.user?.id ?? body.data.user_id;
    if (!userId) {
      return reply.code(401).send({
        standing: "I need a signed-in session to link a bank account.",
      });
    }
    if (!req.user?.id && body.data.user_id) {
      req.log.warn("deprecated: body.user_id passed without JWT; pass JWT instead");
    }

    try {
      const plaid = getPlaidClient();
      const webhookUrl = process.env.PLAID_WEBHOOK_URL?.trim() || undefined;
      const resp = await plaid.linkTokenCreate({
        user: { client_user_id: userId },
        client_name: "June",
        products: toProducts(plaidProducts()),
        country_codes: toCountryCodes(plaidCountryCodes()),
        language: "en",
        ...(webhookUrl ? { webhook: webhookUrl } : {}),
      });
      return reply.send({
        link_token: resp.data.link_token,
        expiration: resp.data.expiration,
      });
    } catch (err) {
      req.log.error({ err }, "plaid link-token failed");
      return reply.code(502).send({
        standing: "I couldn't reach Plaid just now. Try again in a moment.",
      });
    }
  });

  // POST /plaid/exchange
  app.post("/plaid/exchange", async (req, reply) => {
    if (!guard(reply)) return;

    const body = ExchangeBody.safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({
        standing: "I need a public_token to exchange.",
        issues: body.error.format(),
      });
    }

    const userId = req.user?.id ?? body.data.user_id;
    if (!userId) {
      return reply.code(401).send({
        standing: "I need a signed-in session to finish linking that account.",
      });
    }
    if (!req.user?.id && body.data.user_id) {
      req.log.warn("deprecated: body.user_id passed without JWT; pass JWT instead");
    }

    try {
      const plaid = getPlaidClient();
      const exch = await plaid.itemPublicTokenExchange({
        public_token: body.data.public_token,
      });
      const accessToken = exch.data.access_token;
      const itemId = exch.data.item_id;

      // Try to capture institution name (best-effort).
      let institutionName: string | null = null;
      try {
        const item = await plaid.itemGet({ access_token: accessToken });
        const instId = item.data.item.institution_id;
        if (instId) {
          const inst = await plaid.institutionsGetById({
            institution_id: instId,
            country_codes: toCountryCodes(plaidCountryCodes()),
          });
          institutionName = inst.data.institution.name ?? null;
        }
      } catch {
        // non-fatal
      }

      const encrypted = encryptAccessToken(accessToken);

      await pool.query(
        `insert into plaid_items (user_id, plaid_item_id, access_token_encrypted, institution_name)
         values ($1, $2, $3, $4)
         on conflict (plaid_item_id) do update
           set access_token_encrypted = excluded.access_token_encrypted,
               institution_name       = excluded.institution_name`,
        [userId, itemId, encrypted, institutionName]
      );

      return reply.send({ ok: true, item_id: itemId });
    } catch (err) {
      req.log.error({ err }, "plaid exchange failed");
      return reply.code(502).send({
        standing: "I couldn't finish linking that account. Try again in a moment.",
      });
    }
  });

  // POST /plaid/sync
  app.post("/plaid/sync", async (req, reply) => {
    if (!guard(reply)) return;

    const body = UserIdBody.safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({
        standing: "I couldn't read that request.",
        issues: body.error.format(),
      });
    }

    const userId = req.user?.id ?? body.data.user_id;
    if (!userId) {
      return reply.code(401).send({
        standing: "I need a signed-in session to sync.",
      });
    }
    if (!req.user?.id && body.data.user_id) {
      req.log.warn("deprecated: body.user_id passed without JWT; pass JWT instead");
    }

    try {
      const result = await syncForUser(userId);
      return reply.send(result);
    } catch (err) {
      req.log.error({ err }, "plaid sync failed");
      return reply.code(502).send({
        standing: "I couldn't pull fresh data from Plaid. Try again in a moment.",
      });
    }
  });

  // Capture raw body bytes for the webhook route so we can hash them for
  // signature verification. Scoped to application/json so it doesn't disturb
  // other routes. Uses a route-level config flag (`config.rawBody = true`) to
  // gate the behavior.
  app.addContentTypeParser(
    "application/json",
    { parseAs: "string" },
    (req, body: string, done) => {
      try {
        const cfg = req.routeOptions?.config as { rawBody?: boolean } | undefined;
        if (cfg?.rawBody) {
          req.rawBody = body;
        }
        const json = body.length > 0 ? JSON.parse(body) : {};
        done(null, json);
      } catch (err) {
        done(err as Error, undefined);
      }
    }
  );

  // POST /plaid/webhook — verified via JWT before any side effects.
  app.post(
    "/plaid/webhook",
    { config: { rawBody: true } },
    async (req, reply) => {
      if (!plaidConfigured) {
        // Without Plaid creds we can't verify the JWK; refuse silently.
        return reply.code(503).send({ ok: false });
      }

      const verificationHeader = req.headers["plaid-verification"];
      const jwt = Array.isArray(verificationHeader)
        ? verificationHeader[0]
        : verificationHeader;
      if (!jwt) {
        req.log.warn("plaid webhook missing Plaid-Verification header");
        return reply.code(401).send({ ok: false });
      }

      try {
        await verifyPlaidWebhook(jwt, rawBodyFromRequest(req));
      } catch (err) {
        req.log.warn({ err }, "plaid webhook verification failed");
        return reply.code(401).send({ ok: false });
      }

      // Respond 200 now; Plaid retries on slow responses. Do real work after.
      reply.code(200).send({ ok: true });

      const parsed = WebhookBody.safeParse(req.body);
      if (!parsed.success) return;

      const { webhook_type, webhook_code, item_id } = parsed.data;

      // Both SYNC_UPDATES_AVAILABLE and INITIAL_UPDATE want an immediate sync
      // for the affected item.
      if (
        webhook_type === "TRANSACTIONS" &&
        (webhook_code === "SYNC_UPDATES_AVAILABLE" ||
          webhook_code === "INITIAL_UPDATE" ||
          webhook_code === "HISTORICAL_UPDATE" ||
          webhook_code === "DEFAULT_UPDATE")
      ) {
        if (!item_id) return;
        try {
          const row = await pool.query<{ user_id: string }>(
            `select user_id from plaid_items where plaid_item_id = $1`,
            [item_id]
          );
          if (row.rows[0]) {
            await syncForUser(row.rows[0].user_id);
          }
        } catch (err) {
          req.log.error({ err, item_id }, "plaid webhook sync failed");
        }
        return;
      }

      if (webhook_type === "ITEM" && webhook_code === "ERROR") {
        req.log.warn({ webhook: parsed.data }, "plaid item error webhook");
        return;
      }

      // Any other webhook: just log so we know it arrived.
      req.log.info({ webhook: parsed.data }, "plaid webhook received");
    }
  );
}
