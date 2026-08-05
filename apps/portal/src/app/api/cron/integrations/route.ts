import { hasValidBearerSecret } from "@/lib/integration-auth";
import { readCronSecret } from "@/lib/integration-env";
import { runIntegrationCycle } from "@/lib/integration-worker";

export const maxDuration = 300;

export async function GET(request: Request) {
  const secret = readCronSecret();
  if (!secret) {
    return Response.json({ code: "cron_not_configured" }, { status: 503 });
  }
  if (!hasValidBearerSecret(request.headers.get("authorization"), secret)) {
    return Response.json({ code: "unauthorized" }, { status: 401 });
  }
  try {
    const summary = await runIntegrationCycle();
    return Response.json({ ok: true, summary });
  } catch {
    return Response.json({ code: "integration_cycle_failed" }, { status: 500 });
  }
}
