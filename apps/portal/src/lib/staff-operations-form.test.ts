import { describe, expect, it } from "vitest";

import { readGrantRoleForm, readRevokeRoleForm } from "./staff-operations-form";

const actorId = "10000000-0000-4000-8000-000000000001";
const roleId = "10000000-0000-4000-8000-000000000002";

describe("staff operations forms", () => {
  it("parses a global role grant", () => {
    const form = new FormData();
    form.set("actor_id", actorId);
    form.set("role_id", roleId);
    form.set("effective_until", "");
    form.set("assignment_scope", "");
    form.set("reason", "Grant approved authority");
    const result = readGrantRoleForm(form);
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.assignmentScope).toEqual({});
  });

  it("accepts a JSON warehouse scope", () => {
    const form = new FormData();
    form.set("actor_id", actorId);
    form.set("role_id", roleId);
    form.set("assignment_scope", JSON.stringify({ warehouse_ids: [actorId] }));
    form.set("reason", "Limit warehouse authority");
    expect(readGrantRoleForm(form).success).toBe(true);
  });

  it("rejects array scope and invalid JSON", () => {
    for (const value of ["[]", "not-json"]) {
      const form = new FormData();
      form.set("actor_id", actorId);
      form.set("role_id", roleId);
      form.set("assignment_scope", value);
      form.set("reason", "Invalid scope");
      expect(readGrantRoleForm(form).success).toBe(false);
    }
  });

  it("requires an audit reason for revocation", () => {
    const form = new FormData();
    form.set("assignment_id", actorId);
    form.set("reason", "");
    expect(readRevokeRoleForm(form).success).toBe(false);
  });
});
