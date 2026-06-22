import { pool } from "./db.js";

/**
 * Push notification scaffold.
 *
 * For Phase 1 this only loads device tokens and logs the intended payload.
 * APNs/FCM wiring lands once the APNs key is generated and a real provider
 * package (e.g. `@parse/node-apn` for APNs, `firebase-admin` for FCM) is
 * installed. Everything downstream — morning job, /notifications/register —
 * is structured around this signature so the swap is a one-file edit.
 */
export interface DeviceTokenRow {
  id: string;
  platform: "ios" | "android";
  token: string;
}

export async function loadDeviceTokens(userId: string): Promise<DeviceTokenRow[]> {
  const res = await pool.query<DeviceTokenRow>(
    `select id, platform, token from device_tokens where user_id = $1`,
    [userId]
  );
  return res.rows;
}

export async function sendPush(
  userId: string,
  title: string,
  body: string
): Promise<{ delivered: number; tokens: number }> {
  const tokens = await loadDeviceTokens(userId);
  if (tokens.length === 0) {
    // eslint-disable-next-line no-console
    console.log(
      `[push] no device tokens for user=${userId}; would have sent title="${title}" body="${body}"`
    );
    return { delivered: 0, tokens: 0 };
  }

  // Bump last_seen_at so we know which tokens are getting traffic. Mark this
  // a "best effort" — don't fail the morning job if it trips.
  try {
    await pool.query(
      `update device_tokens set last_seen_at = now() where user_id = $1`,
      [userId]
    );
  } catch {
    // ignore
  }

  for (const t of tokens) {
    // eslint-disable-next-line no-console
    console.log(
      `[push] (stub) platform=${t.platform} user=${userId} title="${title}" body="${body}"`
    );
  }

  // `delivered` mirrors `tokens` until the real provider wire-up lands.
  return { delivered: tokens.length, tokens: tokens.length };
}
