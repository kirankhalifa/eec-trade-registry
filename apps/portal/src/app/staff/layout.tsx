import type { Metadata } from "next";

import { StaffShell } from "@/components/staff-shell";
import { getInstitutionName } from "@/lib/env";
import { getMyStaffAccessState } from "@/lib/staff-access";
import { createServerSupabaseClient } from "@/lib/supabase-server";

export const metadata: Metadata = {
  title: "Staff console",
  robots: { index: false, follow: false },
};
export const dynamic = "force-dynamic";

export default async function StaffLayout({ children }: { children: React.ReactNode }) {
  const client = await createServerSupabaseClient();
  const { data } = await client.auth.getClaims();
  let accessClass: "owner" | "agent" | null = null;
  let displayName: string | null = null;
  if (typeof data?.claims?.sub === "string") {
    const access = await getMyStaffAccessState(client);
    if (access.ok && access.data.state === "authorized") {
      accessClass = access.data.access_class;
      displayName = access.data.display_name;
    }
  }
  return <StaffShell accessClass={accessClass} displayName={displayName} institutionName={getInstitutionName()}>{children}</StaffShell>;
}
