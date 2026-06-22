import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

export const supabaseConfigured =
  !!(url && anonKey && serviceKey);

// Admin client — bypasses RLS. Use for webhook/system operations.
export function getAdminClient(): SupabaseClient {
  if (!supabaseConfigured) throw new Error("Supabase not configured. Set SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.");
  return createClient(url!, serviceKey!, { auth: { autoRefreshToken: false, persistSession: false } });
}

// Per-request client that runs queries AS the authenticated user (RLS applies).
export function getUserClient(jwt: string): SupabaseClient {
  if (!supabaseConfigured) throw new Error("Supabase not configured.");
  return createClient(url!, anonKey!, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
