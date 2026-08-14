import { createHash } from "node:crypto";

import { headers } from "next/headers";
import { z } from "zod";

import { createIntegrationSupabaseClient } from "@/lib/integration-supabase";

const verificationResultCodeSchema = z.enum([
  "valid",
  "provisional",
  "suspended",
  "revoked",
  "expired",
  "not_verifiable",
]);

const dealerLicenseSummarySchema = z.object({
  is_currently_authorized: z.boolean(),
  license_class_label: z.string(),
  public_reference: z.string(),
  result_code: verificationResultCodeSchema,
});

const dealerVerificationSchema = z.object({
  dealer_type_label: z.string().nullable(),
  effective_from: z.string().nullable(),
  effective_until: z.string().nullable(),
  is_currently_authorized: z.boolean(),
  jurisdiction_label: z.string().nullable(),
  license_summaries: z.array(dealerLicenseSummarySchema),
  premises_label: z.string().nullable(),
  public_name: z.string().nullable(),
  public_notice: z.string().nullable(),
  public_reference: z.string().nullable(),
  result_code: verificationResultCodeSchema,
  status_label: z.string().nullable(),
  verified_at: z.string(),
});

const licenseVerificationSchema = z.object({
  effective_from: z.string().nullable(),
  endorsements: z.array(z.string()),
  expires_at: z.string().nullable(),
  holder_name: z.string().nullable(),
  is_currently_authorized: z.boolean(),
  jurisdiction_label: z.string().nullable(),
  license_class_label: z.string().nullable(),
  public_conditions: z.array(z.string()),
  public_notice: z.string().nullable(),
  public_reference: z.string().nullable(),
  result_code: verificationResultCodeSchema,
  status_label: z.string().nullable(),
  verified_at: z.string(),
});

export type VerificationResultCode = z.infer<typeof verificationResultCodeSchema>;
export type DealerLicenseSummary = z.infer<typeof dealerLicenseSummarySchema>;
export type DealerVerification = z.infer<typeof dealerVerificationSchema>;
export type LicenseVerification = z.infer<typeof licenseVerificationSchema>;

export type VerificationResult<T> =
  | { ok: true; data: T }
  | {
      ok: false;
      code:
        | "not_configured"
        | "query_failed"
        | "invalid_response"
        | "rate_limited";
    };

export interface PublicVerificationFingerprints {
  ip: string;
  reference: string;
}

function digest(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export async function createPublicVerificationFingerprints(
  reference: string,
): Promise<PublicVerificationFingerprints> {
  const requestHeaders = await headers();
  const forwarded =
    requestHeaders.get("x-vercel-forwarded-for") ??
    requestHeaders.get("x-forwarded-for") ??
    requestHeaders.get("x-real-ip") ??
    "unresolved-client";
  const ip = forwarded.split(",")[0]?.trim() || "unresolved-client";
  return {
    ip: digest(`verification-ip:${ip}`),
    reference: digest(`verification-reference:${ip}:${reference}`),
  };
}

function reportVerificationFailure(operation: string, message: string): void {
  console.error(`[verification:${operation}] ${message}`);
}

async function runVerification<T>(
  operation: "dealer" | "license",
  reference: string,
  schema: z.ZodType<T>,
  fingerprints?: PublicVerificationFingerprints,
): Promise<VerificationResult<T>> {
  try {
    const client = createIntegrationSupabaseClient();
    if (fingerprints) {
      const { data: permitted, error: limitError } = await client.rpc(
        "consume_public_verification_rate_limit",
        {
          p_ip_fingerprint: fingerprints.ip,
          p_reference_fingerprint: fingerprints.reference,
        },
      );
      if (limitError) {
        reportVerificationFailure(operation, limitError.message);
        return { ok: false, code: "query_failed" };
      }
      if (permitted !== true) return { ok: false, code: "rate_limited" };
    }
    const functionName =
      operation === "dealer"
        ? "public_dealer_verification"
        : "public_license_verification";
    const { data, error } = await client.rpc(functionName, {
      p_reference: reference,
    });

    if (error) {
      reportVerificationFailure(operation, error.message);
      return { ok: false, code: "query_failed" };
    }

    const candidate = Array.isArray(data) ? data[0] : null;
    const parsed = schema.safeParse(candidate);
    if (!parsed.success) {
      reportVerificationFailure(
        operation,
        "Supabase returned an unexpected response shape.",
      );
      return { ok: false, code: "invalid_response" };
    }

    return { ok: true, data: parsed.data };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { ok: false, code: "not_configured" };
    }
    reportVerificationFailure(operation, "The registry query failed unexpectedly.");
    return { ok: false, code: "query_failed" };
  }
}

export function verifyPublicDealer(
  reference: string,
  fingerprints?: PublicVerificationFingerprints,
): Promise<VerificationResult<DealerVerification>> {
  return runVerification(
    "dealer",
    reference,
    dealerVerificationSchema,
    fingerprints,
  );
}

export function verifyPublicLicense(
  reference: string,
  fingerprints?: PublicVerificationFingerprints,
): Promise<VerificationResult<LicenseVerification>> {
  return runVerification(
    "license",
    reference,
    licenseVerificationSchema,
    fingerprints,
  );
}
