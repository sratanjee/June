import type { FastifyInstance, FastifyRequest } from "fastify";
import { getAdminClient, supabaseConfigured } from "./supabase.js";

declare module "fastify" {
  interface FastifyRequest {
    user: { id: string; email: string | null } | null;
  }
}

export async function registerAuth(app: FastifyInstance) {
  app.decorateRequest("user", null);

  app.addHook("onRequest", async (req) => {
    if (!supabaseConfigured) return;
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith("Bearer ")) return;
    const jwt = auth.slice(7).trim();
    if (!jwt) return;

    try {
      const { data, error } = await getAdminClient().auth.getUser(jwt);
      if (error || !data.user) return;
      req.user = { id: data.user.id, email: data.user.email ?? null };
    } catch {
      // Silent — caller can decide to require auth
    }
  });
}

export function requireUser(req: FastifyRequest): { id: string; email: string | null } {
  if (!req.user) {
    throw Object.assign(new Error("auth required"), { statusCode: 401 });
  }
  return req.user;
}
