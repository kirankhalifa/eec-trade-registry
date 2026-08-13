"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readAccessReviewForm } from "@/lib/staff-access-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const base = "/staff/access";
function destination(key: "error" | "notice", value: string) {
  return `${base}?${new URLSearchParams({ [key]: value })}`;
}

export async function reviewStaffAccessAction(formData: FormData) {
  const parsed = readAccessReviewForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));

  const client = await createServerSupabaseClient();
  const claims = await client.auth.getClaims();
  if (claims.error || typeof claims.data?.claims?.sub !== "string") redirect("/staff/login");

  const input = parsed.data;
  const { error } = await client.rpc("owner_review_staff_access_request", {
    p_access_request_id: input.accessRequestId,
    p_decision: input.decision,
    p_expected_version: input.expectedVersion,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    console.error(`[staff-access:review] ${error.code ?? "unknown"}`);
    if (error.code === "40001") redirect(destination("error", "conflict"));
    if (error.code === "42501") redirect(destination("error", "access_denied"));
    if (error.code === "55000") redirect(destination("error", "owner_protected"));
    if (error.code === "P0002") redirect(destination("error", "not_found"));
    redirect(destination("error", "save_failed"));
  }

  revalidatePath(base);
  revalidatePath("/staff/dashboard");
  redirect(destination("notice", input.decision === "approve" ? "access_approved" : input.decision === "deny" ? "access_denied_recorded" : "access_blocked"));
}
