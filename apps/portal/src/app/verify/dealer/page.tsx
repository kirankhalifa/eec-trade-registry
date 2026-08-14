import { redirect } from "next/navigation";

import { parseVerificationReference } from "@/lib/verification-query";

interface LegacyDealerVerificationProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function LegacyDealerVerification({
  searchParams,
}: LegacyDealerVerificationProps) {
  const reference = parseVerificationReference(await searchParams);
  redirect(reference ? `/verify?reference=${encodeURIComponent(reference)}` : "/verify");
}
