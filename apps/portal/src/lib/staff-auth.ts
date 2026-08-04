import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase-server";

export async function requireStaffSession() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  const subject = data?.claims?.sub;

  if (error || typeof subject !== "string" || subject.length === 0) {
    redirect("/staff/login");
  }

  return { client, subject };
}

export async function hasStaffSession(): Promise<boolean> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  return !error && typeof data?.claims?.sub === "string";
}
