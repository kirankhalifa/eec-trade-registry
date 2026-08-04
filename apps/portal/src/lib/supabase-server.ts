import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import {
  readPublicSupabaseEnvironment,
  type PublicSupabaseEnvironment,
} from "@/lib/env";
import { CatalogueConfigurationError } from "@/lib/supabase";

function requireSupabaseEnvironment(): PublicSupabaseEnvironment {
  const environment = readPublicSupabaseEnvironment();
  if (!environment) {
    throw new CatalogueConfigurationError();
  }
  return environment;
}

export async function createServerSupabaseClient() {
  const environment = requireSupabaseEnvironment();
  const cookieStore = await cookies();

  return createServerClient(
    environment.NEXT_PUBLIC_SUPABASE_URL,
    environment.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            // Server Components cannot write cookies. The request proxy refreshes
            // the session before rendering and applies response cookies there.
          }
        },
      },
    },
  );
}
