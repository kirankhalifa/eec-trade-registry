import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

import { readPublicSupabaseEnvironment } from "@/lib/env";
import { updateSupabaseSession } from "@/lib/supabase-proxy";

export async function proxy(request: NextRequest) {
  const segments = request.nextUrl.pathname.split("/").filter(Boolean);
  if (segments.length === 2 && segments[0] === "catalogue") {
    const environment = readPublicSupabaseEnvironment();
    if (environment) {
      try {
        const response = await fetch(
          `${environment.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/get_public_catalogue_entry_state`,
          {
            body: JSON.stringify({ p_slug: segments[1] }),
            headers: {
              apikey: environment.NEXT_PUBLIC_SUPABASE_ANON_KEY,
              "Content-Type": "application/json",
            },
            method: "POST",
            next: { revalidate: 60 },
          },
        );
        if (response.ok && (await response.json()) === "withdrawn") {
          const destination = request.nextUrl.clone();
          destination.pathname = "/catalogue/withdrawn";
          destination.search = new URLSearchParams({ slug: segments[1] }).toString();
          return NextResponse.rewrite(destination, { status: 410 });
        }
      } catch {
        // The detail page owns the authoritative unavailable state.
      }
    }
    return NextResponse.next({ request });
  }
  return updateSupabaseSession(request);
}

export const config = {
  matcher: ["/staff/:path*", "/dealer/:path*", "/catalogue/:path*"],
};
