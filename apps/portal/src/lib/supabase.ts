import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { readPublicSupabaseEnvironment } from "@/lib/env";

export class CatalogueConfigurationError extends Error {
  constructor() {
    super("The public Supabase environment is not configured.");
    this.name = "CatalogueConfigurationError";
  }
}

let publicClient: SupabaseClient | null = null;

export function getPublicSupabaseClient(): SupabaseClient {
  if (publicClient) {
    return publicClient;
  }

  const environment = readPublicSupabaseEnvironment();
  if (!environment) {
    throw new CatalogueConfigurationError();
  }

  publicClient = createClient(
    environment.NEXT_PUBLIC_SUPABASE_URL,
    environment.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    {
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
    },
  );

  return publicClient;
}
