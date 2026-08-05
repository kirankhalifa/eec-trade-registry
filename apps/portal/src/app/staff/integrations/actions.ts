"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  readConfigureDestinationForm,
  readQueueExportForm,
  readReplayDeliveryForm,
  readReplayExportForm,
  readSetDefinitionStatusForm,
} from "@/lib/staff-integration-form";
import { createServerSupabaseClient } from "@/lib/supabase-server";

const workspacePath = "/staff/integrations";

function destination(key: "error" | "notice", value: string): string {
  return `${workspacePath}?${new URLSearchParams({ [key]: value }).toString()}`;
}

function mutationFailure(error: { code?: string; message: string }): never {
  console.error(`[staff-integrations:mutation] ${error.code ?? "unknown"}`);
  if (error.code === "40001" || error.message.includes("version_conflict")) {
    redirect(destination("error", "conflict"));
  }
  if (
    error.code === "42501" ||
    error.code === "28000" ||
    error.message.includes("staff_permission_denied")
  ) {
    redirect(destination("error", "access_denied"));
  }
  if (error.code === "P0002") redirect(destination("error", "not_found"));
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

export async function configureIntegrationDestinationAction(formData: FormData) {
  const parsed = readConfigureDestinationForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_configure_integration_destination", {
    p_active: input.active,
    p_destination_id: input.destinationId,
    p_expected_version: input.expectedVersion,
    p_external_reference: input.externalReference,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  await finish(error, "integration_destination_saved");
}

export async function setExportDefinitionStatusAction(formData: FormData) {
  const parsed = readSetDefinitionStatusForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const input = parsed.data;
  const { error } = await client.rpc("staff_set_export_definition_status", {
    p_active: input.active,
    p_expected_version: input.expectedVersion,
    p_export_definition_id: input.definitionId,
    p_reason: input.reason,
    p_request_id: crypto.randomUUID(),
  });
  await finish(error, "export_schedule_saved");
}

export async function queueExportRunAction(formData: FormData) {
  const parsed = readQueueExportForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const { error } = await client.rpc("staff_queue_export_run", {
    p_export_definition_id: parsed.data.definitionId,
    p_reason: parsed.data.reason,
    p_request_id: crypto.randomUUID(),
  });
  await finish(error, "export_queued");
}

export async function replayExportRunAction(formData: FormData) {
  const parsed = readReplayExportForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const { error } = await client.rpc("staff_replay_export_run", {
    p_export_run_id: parsed.data.exportRunId,
    p_reason: parsed.data.reason,
    p_request_id: crypto.randomUUID(),
  });
  await finish(error, "export_requeued");
}

export async function replayIntegrationDeliveryAction(formData: FormData) {
  const parsed = readReplayDeliveryForm(formData);
  if (!parsed.success) redirect(destination("error", "invalid_input"));
  const client = await verifiedClient();
  if (!client) redirect("/staff/login");
  const { error } = await client.rpc("staff_replay_integration_delivery", {
    p_delivery_id: parsed.data.deliveryId,
    p_reason: parsed.data.reason,
    p_request_id: crypto.randomUUID(),
  });
  await finish(error, "delivery_requeued");
}
