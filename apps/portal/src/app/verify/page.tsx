import type { Metadata } from "next";

import { VerificationForm } from "@/components/verification-form";
import {
  DealerVerificationResult,
  LicenseVerificationResult,
  UnsupportedVerificationReference,
  VerificationRateLimited,
  VerificationUnavailable,
} from "@/components/verification-result";
import { getDefaultLocale } from "@/lib/env";
import {
  createPublicVerificationFingerprints,
  verifyPublicDealer,
  verifyPublicLicense,
} from "@/lib/verification";
import {
  inferVerificationKind,
  parseVerificationReference,
} from "@/lib/verification-query";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Public verification",
  description:
    "Verify a published East Empire Company dealer authorization or license by its exact DLR or LIC reference.",
};

interface VerificationPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function VerificationPage({
  searchParams,
}: VerificationPageProps) {
  const reference = parseVerificationReference(await searchParams);
  const kind = reference ? inferVerificationKind(reference) : null;
  const locale = getDefaultLocale();
  const fingerprints = reference
    ? await createPublicVerificationFingerprints(reference)
    : null;
  const dealerLookup =
    reference && kind === "dealer"
      ? await verifyPublicDealer(reference, fingerprints ?? undefined)
      : null;
  const licenseLookup =
    reference && kind === "license"
      ? await verifyPublicLicense(reference, fingerprints ?? undefined)
      : null;

  return (
    <main className="verification-main">
      <section className="verification-hero">
        <p className="eyebrow">Official public registry</p>
        <h1>Verify a dealer or license.</h1>
        <p>
          Enter the exact DLR or LIC reference. The prefix tells the registry
          which record to check; no separate lookup screen is required.
        </p>
      </section>
      <section className="verification-choices verification-lookup-shell">
        <VerificationForm reference={reference} />
        <aside className="verification-privacy-note">
          <strong>Privacy by design</strong>
          <p>
            Unknown, malformed, private, and unpublished references share the
            same “not verifiable” response. Holder-name search is disabled.
          </p>
        </aside>
      </section>
      {reference && !kind && (
        <UnsupportedVerificationReference reference={reference} />
      )}
      {dealerLookup &&
        (!dealerLookup.ok ? (
          dealerLookup.code === "rate_limited" ? (
            <VerificationRateLimited />
          ) : (
            <VerificationUnavailable
              notConfigured={dealerLookup.code === "not_configured"}
            />
          )
        ) : (
          <DealerVerificationResult result={dealerLookup.data} locale={locale} />
        ))}
      {licenseLookup &&
        (!licenseLookup.ok ? (
          licenseLookup.code === "rate_limited" ? (
            <VerificationRateLimited />
          ) : (
            <VerificationUnavailable
              notConfigured={licenseLookup.code === "not_configured"}
            />
          )
        ) : (
          <LicenseVerificationResult result={licenseLookup.data} locale={locale} />
        ))}
    </main>
  );
}
