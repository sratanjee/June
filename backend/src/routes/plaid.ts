import type { FastifyInstance } from "fastify";
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

async function syncForUser(userId: string): Promise<{
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
      const resp = await plaid.linkTokenCreate({
        user: { client_user_id: userId },
        client_name: "June",
        products: toProducts(plaidProducts()),
        country_codes: toCountryCodes(plaidCountryCodes()),
        language: "en",
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

  // POST /plaid/webhook
  app.post("/plaid/webhook", async (req, reply) => {
    // Respond 200 first, do work after — Plaid retries on slow responses.
    reply.code(200).send({ ok: true });

    if (!plaidConfigured) return;

    const parsed = WebhookBody.safeParse(req.body);
    if (!parsed.success) return;

    const { webhook_type, webhook_code, item_id } = parsed.data;

    if (webhook_type === "TRANSACTIONS" && webhook_code === "SYNC_UPDATES_AVAILABLE") {
      if (!item_id) return;
      try {
        const row = await pool.query<{ user_id: string }>(
          `select user_id from plaid_items where plaid_item_id = $1`,
          [item_id]
        );
        if (row.rows[0]) {
          // Fire-and-forget; we already replied 200.
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

    // Any other webhook: just log at debug so we know it arrived.
    req.log.info({ webhook: parsed.data }, "plaid webhook received");
  });
}
