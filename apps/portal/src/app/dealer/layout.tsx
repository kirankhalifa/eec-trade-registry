import type { Metadata } from "next";

import { DealerShell } from "@/components/dealer-shell";
import { getInstitutionName } from "@/lib/env";

export const metadata: Metadata = {
  title: "Dealer portal",
  robots: { index: false, follow: false },
};

export default function DealerLayout({ children }: { children: React.ReactNode }) {
  return <DealerShell institutionName={getInstitutionName()}>{children}</DealerShell>;
}
