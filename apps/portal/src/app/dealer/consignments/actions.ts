"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { readDealerConsignmentReportForm } from "@/lib/consignment-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const path = "/dealer/consignments";
function destination(key: "error" | "notice", value: string) {
  return `${path}?${new URLSearchParams({ [key]: value }).toString()}`;
}
function errorPath(error: { code?: string; message: string }) {
  console.error(`[dealer-consignments:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "42501" || error.code === "28000" || error.message.includes("scope_denied")) return destination("error", "access_denied");
  if (error.code === "P0002") return destination("error", "not_found");
  if (error.code === "23505" || error.message.includes("already_pending")) return destination("error", "duplicate_report");
  if (error.code === "22023" || error.code === "23514") return destination("error", "invalid_input");
  return destination("error", "save_failed");
}

export async function submitConsignmentReportAction(formData: FormData) {
  const parsed = readDealerConsignmentReportForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await createServerSupabaseClient();
  const { data: claims, error: claimsError } = await client.auth.getClaims();
  if (claimsError || typeof claims?.claims?.sub !== "string") redirect("/dealer/login");
  const input = parsed.data;
  const { error } = await client.rpc("dealer_submit_consignment_report", {
    p_consignment_issue_id: input.consignmentIssueId,
    p_observed_on_hand: input.observedOnHand,
    p_quantity_damaged: input.quantityDamaged,
    p_quantity_lost: input.quantityLost,
    p_quantity_returned: input.quantityReturned,
    p_quantity_sold: input.quantitySold,
    p_reason: input.reason,
    p_report_notes: input.reportNotes,
    p_request_id: crypto.randomUUID(),
  });
  if (error) redirect(errorPath(error));
  revalidatePath(path); revalidatePath("/staff/consignments");
  redirect(destination("notice", "report_submitted"));
}
