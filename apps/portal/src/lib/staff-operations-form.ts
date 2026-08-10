import { z } from "zod";

const reason = z.string().trim().min(1).max(500);

function optionalTimestamp(value: FormDataEntryValue | null) {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? value : parsed.toISOString();
}

function scope(value: FormDataEntryValue | null): unknown {
  if (typeof value !== "string" || !value.trim()) return {};
  try {
    const parsed: unknown = JSON.parse(value);
    return parsed;
  } catch {
    return null;
  }
}

const grantSchema = z.object({
  actorId: z.guid(),
  assignmentScope: z.record(z.string(), z.unknown()),
  effectiveUntil: z.string().datetime({ offset: true }).nullable(),
  reason,
  roleId: z.guid(),
});

const revokeSchema = z.object({ assignmentId: z.guid(), reason });

export function readGrantRoleForm(formData: FormData) {
  return grantSchema.safeParse({
    actorId: formData.get("actor_id"),
    assignmentScope: scope(formData.get("assignment_scope")),
    effectiveUntil: optionalTimestamp(formData.get("effective_until")),
    reason: formData.get("reason"),
    roleId: formData.get("role_id"),
  });
}

export function readRevokeRoleForm(formData: FormData) {
  return revokeSchema.safeParse({
    assignmentId: formData.get("assignment_id"),
    reason: formData.get("reason"),
  });
}
