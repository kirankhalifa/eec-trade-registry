import { createClient } from "@supabase/supabase-js";

import { readIntegrationServiceEnvironment } from "@/lib/integration-env";

export function createIntegrationSupabaseClient(
  environment: NodeJS.ProcessEnv = process.env,
) {
  const values = readIntegrationServiceEnvironment(environment);
  return createClient(
    values.NEXT_PUBLIC_SUPABASE_URL,
    values.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
    },
  );
}
