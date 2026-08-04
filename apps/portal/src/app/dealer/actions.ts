"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import { createServerSupabaseClient } from "@/lib/supabase-server";

const loginSchema = z.object({
  email: z.string().trim().email().max(320),
  password: z.string().min(1).max(1024),
});

function loginErrorDestination(): string {
  return `/dealer/login?${new URLSearchParams({
    error: "invalid_credentials",
  }).toString()}`;
}

export async function signInDealerAction(formData: FormData) {
  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!parsed.success) {
    redirect(loginErrorDestination());
  }

  const client = await createServerSupabaseClient();
  const { error } = await client.auth.signInWithPassword(parsed.data);
  if (error) {
    redirect(loginErrorDestination());
  }
  redirect("/dealer");
}

export async function signOutDealerAction() {
  const client = await createServerSupabaseClient();
  await client.auth.signOut();
  redirect("/dealer/login");
}
