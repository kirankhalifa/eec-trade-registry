import type { Metadata } from "next";
import Link from "next/link";

import { VerificationForm } from "@/components/verification-form";
import {
  LicenseVerificationResult,
  VerificationUnavailable,
} from "@/components/verification-result";
import { getDefaultLocale } from "@/lib/env";
import { verifyPublicLicense } from "@/lib/verification";
import { parseVerificationReference } from "@/lib/verification-query";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Verify license",
  description: "Verify a published license by public reference.",
};

interface LicenseVerificationPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function LicenseVerificationPage({
  searchParams,
}: LicenseVerificationPageProps) {
  const reference = parseVerificationReference(await searchParams);
  const lookup = reference ? await verifyPublicLicense(reference) : null;
  const locale = getDefaultLocale();

  return (
    <main className="verification-main">
      <section className="verification-page-header">
        <Link href="/verify">← All verification options</Link>
        <p className="eyebrow">Public license registry</p>
        <h1>Verify an issued license.</h1>
        <p>
          This lookup confirms only approved public license fields. A valid
          result does not independently confirm dealer standing, item
          eligibility, allocation, stock, or transaction approval.
        </p>
      </section>
      <VerificationForm kind="license" reference={reference} />
      {lookup &&
        (lookup.ok ? (
          <LicenseVerificationResult result={lookup.data} locale={locale} />
        ) : (
          <VerificationUnavailable
            notConfigured={lookup.code === "not_configured"}
          />
        ))}
      {!lookup && (
        <section className="verification-idle" aria-label="Lookup instructions">
          <span aria-hidden="true">LIC</span>
          <div>
            <h2>Enter an exact public license reference.</h2>
            <p>
              A fictional development fixture is available as LIC-DEMO-4Q2M
              after the local database is seeded.
            </p>
          </div>
        </section>
      )}
    </main>
  );
}
