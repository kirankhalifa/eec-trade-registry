import { z } from "zod";

import { sendDiscordChannelMessage } from "@/lib/discord-delivery";
import {
  getIntegrationWorkerId,
  readDiscordDeliveryEnvironment,
  readGoogleServiceEnvironment,
} from "@/lib/integration-env";
import { createIntegrationSupabaseClient } from "@/lib/integration-supabase";
import { renderNotificationTemplate } from "@/lib/integration-template";
import { getSiteOrigin } from "@/lib/env";
import {
  type SheetColumn,
  writeGoogleSheetSnapshot,
} from "@/lib/google-sheets";

const sheetColumnSchema = z.object({
  key: z.string().regex(/^[a-z][a-z0-9_]{1,79}$/),
  label: z.string().min(1).max(100),
});

const exportClaimSchema = z.object({
  attempt_count: z.number().int().positive(),
  column_contract: z.array(sheetColumnSchema).min(1).max(50),
  definition_code: z.string(),
  destination_configuration: z.record(z.string(), z.unknown()),
  destination_reference: z.string().min(1),
  export_run_id: z.string().uuid(),
  lease_token: z.string().uuid(),
  projection_code: z.enum([
    "public_catalogue",
    "public_dealers",
    "public_licenses",
  ]),
  scheduled_for: z.string(),
  sheet_tab_name: z.string().min(1).max(100),
});

const deliveryClaimSchema = z.object({
  aggregate_id: z.string().uuid(),
  aggregate_type: z.string(),
  attempt_count: z.number().int().positive(),
  delivery_id: z.string().uuid(),
  destination_configuration: z.record(z.string(), z.unknown()),
  destination_reference: z.string().min(1),
  destination_type: z.enum(["discord_channel"]),
  event_type: z.string(),
  lease_token: z.string().uuid(),
  message_template: z.string(),
  payload: z.record(z.string(), z.unknown()),
  payload_version: z.number().int().positive(),
  template_code: z.string(),
  template_version: z.number().int().positive(),
});

type IntegrationClient = ReturnType<typeof createIntegrationSupabaseClient>;
type ExportClaim = z.infer<typeof exportClaimSchema>;
type DeliveryClaim = z.infer<typeof deliveryClaimSchema>;

export interface IntegrationCycleSummary {
  deliveriesDelivered: number;
  deliveriesFailed: number;
  exportsDelivered: number;
  exportsFailed: number;
  exportsQueued: number;
}

class WorkerFailure extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

function safeFailure(error: unknown): string {
  if (error instanceof WorkerFailure) return error.code;
  if (error instanceof Error && /^[a-z0-9_]{3,100}$/.test(error.message)) {
    return error.message;
  }
  return "integration_delivery_failed";
}

function retryAt(attemptCount: number): string {
  const seconds = Math.min(3600, 30 * 2 ** Math.min(attemptCount, 7));
  return new Date(Date.now() + seconds * 1000).toISOString();
}

async function rpcOrThrow<T>(
  client: IntegrationClient,
  name: string,
  parameters?: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client.rpc(name, parameters);
  if (error) throw new WorkerFailure(`supabase_${name}_failed`);
  return data as T;
}

function projectionFunction(projectionCode: ExportClaim["projection_code"]): string {
  switch (projectionCode) {
    case "public_catalogue":
      return "get_public_catalogue_export";
    case "public_dealers":
      return "get_public_dealer_export";
    case "public_licenses":
      return "get_public_license_export";
  }
}

async function processExportClaim(
  client: IntegrationClient,
  claim: ExportClaim,
  environment: NodeJS.ProcessEnv,
): Promise<void> {
  try {
    const google = readGoogleServiceEnvironment(environment);
    if (!google) throw new WorkerFailure("google_credentials_not_configured");
    const rows = await rpcOrThrow<unknown>(
      client,
      projectionFunction(claim.projection_code),
    );
    if (!Array.isArray(rows) || !rows.every((row) => row && typeof row === "object")) {
      throw new WorkerFailure("export_projection_invalid_response");
    }
    const generatedAt = new Date().toISOString();
    const result = await writeGoogleSheetSnapshot({
      columns: claim.column_contract as SheetColumn[],
      environment: google,
      generatedAt,
      projectionCode: claim.projection_code,
      rows: rows as Array<Record<string, unknown>>,
      siteOrigin: getSiteOrigin(environment),
      spreadsheetId: claim.destination_reference,
      tabName: claim.sheet_tab_name,
    });
    await rpcOrThrow(client, "integration_complete_export_run", {
      p_checksum: result.checksum,
      p_destination_version: result.destinationVersion,
      p_export_run_id: claim.export_run_id,
      p_generated_at: generatedAt,
      p_lease_token: claim.lease_token,
      p_row_count: result.rowCount,
      p_watermark_at: generatedAt,
    });
  } catch (error) {
    await rpcOrThrow(client, "integration_fail_export_run", {
      p_error: safeFailure(error),
      p_export_run_id: claim.export_run_id,
      p_lease_token: claim.lease_token,
      p_retry_at: retryAt(claim.attempt_count),
    });
    throw error;
  }
}

async function processDeliveryClaim(
  client: IntegrationClient,
  claim: DeliveryClaim,
  environment: NodeJS.ProcessEnv,
): Promise<void> {
  try {
    const discord = readDiscordDeliveryEnvironment(environment);
    if (!discord) throw new WorkerFailure("discord_bot_not_configured");
    const content = renderNotificationTemplate(claim.message_template, claim.payload);
    const messageId = await sendDiscordChannelMessage({
      channelId: claim.destination_reference,
      content,
      environment: discord,
    });
    await rpcOrThrow(client, "integration_complete_delivery", {
      p_delivery_id: claim.delivery_id,
      p_external_message_id: messageId,
      p_lease_token: claim.lease_token,
    });
  } catch (error) {
    await rpcOrThrow(client, "integration_fail_delivery", {
      p_delivery_id: claim.delivery_id,
      p_error: safeFailure(error),
      p_lease_token: claim.lease_token,
      p_retry_at: retryAt(claim.attempt_count),
    });
    throw error;
  }
}

export async function runIntegrationCycle(
  environment: NodeJS.ProcessEnv = process.env,
): Promise<IntegrationCycleSummary> {
  const client = createIntegrationSupabaseClient(environment);
  const workerId = getIntegrationWorkerId(environment);
  const queued = await rpcOrThrow<number>(client, "integration_queue_due_exports", {
    p_now: new Date().toISOString(),
  });
  const rawExportClaims = await rpcOrThrow<unknown>(
    client,
    "integration_claim_export_runs",
    { p_batch_size: 10, p_lease_seconds: 300, p_worker_id: workerId },
  );
  const exportClaims = z.array(exportClaimSchema).parse(rawExportClaims ?? []);
  const rawDeliveryClaims = await rpcOrThrow<unknown>(
    client,
    "integration_claim_deliveries",
    { p_batch_size: 10, p_lease_seconds: 120, p_worker_id: workerId },
  );
  const deliveryClaims = z.array(deliveryClaimSchema).parse(rawDeliveryClaims ?? []);

  const summary: IntegrationCycleSummary = {
    deliveriesDelivered: 0,
    deliveriesFailed: 0,
    exportsDelivered: 0,
    exportsFailed: 0,
    exportsQueued: Number(queued ?? 0),
  };

  for (const claim of exportClaims) {
    try {
      await processExportClaim(client, claim, environment);
      summary.exportsDelivered += 1;
    } catch {
      summary.exportsFailed += 1;
    }
  }
  for (const claim of deliveryClaims) {
    try {
      await processDeliveryClaim(client, claim, environment);
      summary.deliveriesDelivered += 1;
    } catch {
      summary.deliveriesFailed += 1;
    }
  }
  return summary;
}
