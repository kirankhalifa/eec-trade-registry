import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase-server";

export async function requireDealerSession() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  const subject = data?.claims?.sub;

  if (error || typeof subject !== "string" || subject.length === 0) {
    redirect("/dealer/login");
  }

  return { client, subject };
}

export async function hasAuthenticatedDealerSession(): Promise<boolean> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string";
}
