"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { decisionSchema, parse } from "@/lib/launch-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const base = "/staff/applications";
function destination(key: "error" | "notice", value: string) {
  return `${base}?${new URLSearchParams({ [key]: value })}`;
}

export async function reviewLicenseApplicationAction(formData: FormData) {
  const parsed = parse(decisionSchema, formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));

  const client = await createServerSupabaseClient();
  const claims = await client.auth.getClaims();
  if (claims.error || typeof claims.data?.claims?.sub !== "string") redirect("/staff/login");

  const input = parsed.data;
  const { error } = await client.rpc("staff_decide_license_application", {
    p_application_id: input.application_id,
    p_decision: input.decision,
    p_effective_from: input.effective_from,
    p_expected_version: input.expected_version,
    p_expires_at: input.expires_at,
    p_holder_party_id: input.holder_party_id,
    p_initial_status_code: input.initial_status_code,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    console.error(`[license-applications:review] ${error.code ?? "unknown"}`);
    if (error.code === "40001") redirect(destination("error", "conflict"));
    if (error.code === "42501") redirect(destination("error", "access_denied"));
    if (error.code === "P0002") redirect(destination("error", "not_found"));
    if (error.code === "22023") redirect(destination("error", "invalid_input"));
    redirect(destination("error", "save_failed"));
  }

  revalidatePath(base);
  revalidatePath("/staff/dashboard");
  revalidatePath("/staff/licensing");
  revalidatePath("/staff/launch");
  redirect(destination("notice", "application_decided"));
}
