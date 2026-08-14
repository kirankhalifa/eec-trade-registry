import { redirect } from "next/navigation";

import { parseVerificationReference } from "@/lib/verification-query";

interface LegacyLicenseVerificationProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function LegacyLicenseVerification({
  searchParams,
}: LegacyLicenseVerificationProps) {
  const reference = parseVerificationReference(await searchParams);
  redirect(reference ? `/verify?reference=${encodeURIComponent(reference)}` : "/verify");
}
