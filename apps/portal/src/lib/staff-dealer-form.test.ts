import { describe, expect, it } from "vitest";

import {
  readChangeDealerStatusForm,
  readCreateDealerForm,
  readUpdateDealerForm,
} from "./staff-dealer-form";

const dealerId = "11111111-1111-4111-8111-111111111111";

function validCreateForm() {
  const form = new FormData();
  form.set("party_type_code", "organization");
  form.set("legal_name", "North Harbor Supply LLC");
  form.set("display_name", "North Harbor Supply");
  form.set("public_display_name", "North Harbor Supply");
  form.set("dealer_type_code", "wholesale-counterparty");
  form.set("jurisdiction_code", "harbor-district");
  form.set("initial_status_code", "internal-review");
  form.set("approved_premises_public", "North Harbor trade counter");
  form.set("public_notes", "Authorization details are published when active.");
  form.set("private_notes", "Identity evidence reviewed.");
  form.set("public_disclosure_enabled", "on");
  form.set("reason", "Onboard the approved wholesale counterparty.");
  return form;
}

describe("staff dealer form parsing", () => {
  it("parses an auditable dealer onboarding command", () => {
    const result = readCreateDealerForm(validCreateForm());
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.initialStatusCode).toBe("internal-review");
      expect(result.data.publicDisclosureEnabled).toBe(true);
    }
  });

  it("requires a public name when disclosure is enabled", () => {
    const form = validCreateForm();
    form.set("public_display_name", "");
    expect(readCreateDealerForm(form).success).toBe(false);
  });

  it("parses versioned detail and status commands", () => {
    const update = validCreateForm();
    update.set("dealer_authorization_id", dealerId);
    update.set("expected_version", "3");

    const status = new FormData();
    status.set("dealer_authorization_id", dealerId);
    status.set("expected_version", "4");
    status.set("target_status_code", "suspended");
    status.set("reason", "Suspend authority pending recorded review.");

    expect(readUpdateDealerForm(update).success).toBe(true);
    expect(readChangeDealerStatusForm(status).success).toBe(true);
  });
});
