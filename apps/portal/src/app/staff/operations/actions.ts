"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readGrantRoleForm, readRevokeRoleForm } from "@/lib/staff-operations-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const workspacePath = "/staff/operations";

function destination(key: "error" | "notice", value: string): string {
  return `${workspacePath}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function mutationFailure(error: { code?: string; message: string }): never {
  console.error(`[staff-operations:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "23P01" || error.message.includes("staff_assignment_conflict")) {
    redirect(destination("error", "conflict"));
  }
  if (error.code === "42501" || error.message.includes("staff_permission_denied")) {
    redirect(destination("error", "access_denied"));
  }
  if (error.code === "P0002") redirect(destination("error", "not_found"));
  if (error.code === "55000" || error.message.includes("last_platform_administrator")) {
    redirect(destination("error", "last_administrator"));
  }
  if (error.code === "22023" || error.code === "23514") {
    redirect(destination("error", "invalid_input"));
  }
  redirect(destination("error", "save_failed"));
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  if (error || typeof data?.claims?.sub !== "string") return null;
  return client;
}

async function finish(error: { code?: string; message: string } | null, notice: string) {
  if (error) mutationFailure(error);
  revalidatePath(workspacePath);
  redirect(destination("notice", notice));
}

export async function grantRoleAction(formData: FormData) {
  const parsed = readGrantRoleForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_grant_role_assignment", {
    p_actor_id: input.actorId,
    p_assignment_scope: input.assignmentScope,
    p_effective_from: new Date().toISOString(),
    p_effective_until: input.effectiveUntil,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_staff_role_id: input.roleId,
  });
  await finish(error, "role_granted");
}

export async function revokeRoleAction(formData: FormData) {
  const parsed = readRevokeRoleForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const { error } = await client.rpc("staff_revoke_role_assignment", {
    p_reason: parsed.data.reason,
    p_request_id: crypto.randomUUID(),
    p_staff_assignment_id: parsed.data.assignmentId,
  });
  await finish(error, "role_revoked");
}
