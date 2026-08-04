"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import {
  readChangeLicenseStatusForm,
  readGrantEndorsementForm,
  readIssueLicenseForm,
  readRevokeEndorsementForm,
} from "@/lib/staff-licensing-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

function destination(path: string, key: "error" | "notice", value: string) {
  const query = new URLSearchParams({ [key]: value });
  return `${path}?${query.toString()}`;
}

function licensePath(candidate: FormDataEntryValue | null): string {
  return typeof candidate === "string" && z.guid().safeParse(candidate).success
    ? `/staff/licensing/${candidate}`
    : "/staff/licensing";
}

function mutationErrorPath(
  path: string,
  error: { code?: string; message: string },
): string {
  console.error(`[staff-licensing:mutation] ${error.code ?? "unknown"}`);

  if (error.code === "40001" || error.message.includes("version_conflict")) {
    return destination(path, "error", "conflict");
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("staff_permission_denied")
  ) {
    return destination(path, "error", "access_denied");
  }
  if (error.code === "P0002") {
    return destination(path, "error", "not_found");
  }
  if (error.code === "22023" || error.code === "23P01") {
    return destination(path, "error", "invalid_input");
  }
  return destination(path, "error", "save_failed");
}

async function verifiedClient() {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.auth.getClaims();
  if (error || typeof data?.claims?.sub !== "string") {
    return null;
  }
  return client;
}

export async function issueLicenseAction(formData: FormData) {
  const parsed = readIssueLicenseForm(formData);
  if (!parsed.success) {
    redirect(destination("/staff/licensing/new", "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { data, error } = await client.rpc("staff_issue_license", {
    p_dealer_authorization_id: input.dealerAuthorizationId,
    p_effective_from: null,
    p_endorsement_codes: input.endorsementCodes,
    p_expires_at: null,
    p_holder_party_id: input.holderPartyId,
    p_initial_status_code: input.initialStatusCode,
    p_jurisdiction_code: input.jurisdictionCode,
    p_license_class_code: input.licenseClassCode,
    p_private_notes: input.privateNotes,
    p_public_disclosure_enabled: input.publicDisclosureEnabled,
    p_public_notes: input.publicNotes,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath("/staff/licensing/new", error));
  }

  const licenseId = Array.isArray(data) ? data[0]?.id : null;
  revalidatePath("/staff/licensing");
  revalidatePath("/verify/license");
  if (typeof licenseId === "string") {
    redirect(
      destination(`/staff/licensing/${licenseId}`, "notice", "license_issued"),
    );
  }
  redirect(destination("/staff/licensing", "notice", "license_issued"));
}

export async function changeLicenseStatusAction(formData: FormData) {
  const path = licensePath(formData.get("license_id"));
  const parsed = readChangeLicenseStatusForm(formData);
  if (!parsed.success) {
    redirect(destination(path, "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { error } = await client.rpc("staff_change_license_status", {
    p_expected_version: input.expectedVersion,
    p_license_id: input.licenseId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
    p_target_status_code: input.targetStatusCode,
  });
  if (error) {
    redirect(mutationErrorPath(path, error));
  }

  revalidatePath("/staff/licensing");
  revalidatePath(path);
  revalidatePath("/verify/license");
  redirect(destination(path, "notice", "license_status_changed"));
}

export async function grantLicenseEndorsementAction(formData: FormData) {
  const path = licensePath(formData.get("license_id"));
  const parsed = readGrantEndorsementForm(formData);
  if (!parsed.success) {
    redirect(destination(path, "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { error } = await client.rpc("staff_grant_license_endorsement", {
    p_effective_from: null,
    p_endorsement_code: input.endorsementCode,
    p_expected_license_version: input.expectedLicenseVersion,
    p_expires_at: null,
    p_license_id: input.licenseId,
    p_public_disclosure_enabled: input.publicDisclosureEnabled,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath(path, error));
  }

  revalidatePath("/staff/licensing");
  revalidatePath(path);
  revalidatePath("/verify/license");
  redirect(destination(path, "notice", "endorsement_granted"));
}

export async function revokeLicenseEndorsementAction(formData: FormData) {
  const path = licensePath(formData.get("license_id"));
  const parsed = readRevokeEndorsementForm(formData);
  if (!parsed.success) {
    redirect(destination(path, "error", "invalid_input"));
  }

  const client = await verifiedClient();
  if (!client) {
    redirect("/staff/login");
  }
  const input = parsed.data;
  const { error } = await client.rpc("staff_revoke_license_endorsement", {
    p_expected_license_version: input.expectedLicenseVersion,
    p_license_endorsement_id: input.licenseEndorsementId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  if (error) {
    redirect(mutationErrorPath(path, error));
  }

  revalidatePath("/staff/licensing");
  revalidatePath(path);
  revalidatePath("/verify/license");
  redirect(destination(path, "notice", "endorsement_revoked"));
}
