import type { Metadata } from "next";
import Link from "next/link";

import { VerificationForm } from "@/components/verification-form";
import {
  DealerVerificationResult,
  VerificationUnavailable,
} from "@/components/verification-result";
import { getDefaultLocale } from "@/lib/env";
import { verifyPublicDealer } from "@/lib/verification";
import { parseVerificationReference } from "@/lib/verification-query";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Verify dealer",
  description: "Verify a published dealer authorization by public reference.",
};

interface DealerVerificationPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function DealerVerificationPage({
  searchParams,
}: DealerVerificationPageProps) {
  const reference = parseVerificationReference(await searchParams);
  const lookup = reference ? await verifyPublicDealer(reference) : null;
  const locale = getDefaultLocale();

  return (
    <main className="verification-main">
      <section className="verification-page-header">
        <Link href="/verify">← All verification options</Link>
        <p className="eyebrow">Public dealer registry</p>
        <h1>Verify a dealer authorization.</h1>
        <p>
          This lookup confirms only approved public authorization fields. A
          valid dealer result does not independently confirm item eligibility,
          stock, pricing, or transaction approval.
        </p>
      </section>
      <VerificationForm kind="dealer" reference={reference} />
      {lookup &&
        (lookup.ok ? (
          <DealerVerificationResult result={lookup.data} locale={locale} />
        ) : (
          <VerificationUnavailable
            notConfigured={lookup.code === "not_configured"}
          />
        ))}
      {!lookup && (
        <section className="verification-idle" aria-label="Lookup instructions">
          <span aria-hidden="true">DLR</span>
          <div>
            <h2>Enter an exact public dealer reference.</h2>
            <p>
              A fictional development fixture is available as DLR-DEMO-A7K9
              after the local database is seeded.
            </p>
          </div>
        </section>
      )}
    </main>
  );
}
