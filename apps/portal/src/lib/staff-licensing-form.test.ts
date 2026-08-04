import { describe, expect, it } from "vitest";

import {
  readChangeLicenseStatusForm,
  readGrantEndorsementForm,
  readIssueLicenseForm,
  readRevokeEndorsementForm,
} from "./staff-licensing-form";

const licenseId = "11111111-1111-4111-8111-111111111111";
const partyId = "22222222-2222-4222-8222-222222222222";
const endorsementId = "33333333-3333-4333-8333-333333333333";

describe("staff licensing form parsing", () => {
  it("parses an immediate license with optional blank dealer authority", () => {
    const form = new FormData();
    form.set("holder_party_id", partyId);
    form.set("dealer_authorization_id", "");
    form.set("license_class_code", "general-trade");
    form.set("jurisdiction_code", "harbor-district");
    form.set("initial_status_code", "provisional");
    form.append("endorsement_codes", "regulated-goods");
    form.append("endorsement_codes", "consignment");
    form.set("public_disclosure_enabled", "on");
    form.set("public_notes", "Public condition summary.");
    form.set("private_notes", "Internal review note.");
    form.set("reason", "Issue approved configurable authority.");

    const result = readIssueLicenseForm(form);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.dealerAuthorizationId).toBeNull();
      expect(result.data.endorsementCodes).toEqual([
        "regulated-goods",
        "consignment",
      ]);
      expect(result.data.publicDisclosureEnabled).toBe(true);
    }
  });

  it("rejects issuance without an audit reason", () => {
    const form = new FormData();
    form.set("holder_party_id", partyId);
    form.set("license_class_code", "general-trade");
    form.set("jurisdiction_code", "harbor-district");
    form.set("initial_status_code", "active");
    form.set("reason", "");

    expect(readIssueLicenseForm(form).success).toBe(false);
  });

  it("parses a versioned status transition", () => {
    const form = new FormData();
    form.set("license_id", licenseId);
    form.set("expected_version", "4");
    form.set("target_status_code", "suspended");
    form.set("reason", "Temporarily suspend pending recorded review.");

    const result = readChangeLicenseStatusForm(form);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.expectedVersion).toBe(4);
    }
  });

  it("parses grant and revoke endorsement commands", () => {
    const grant = new FormData();
    grant.set("license_id", licenseId);
    grant.set("expected_license_version", "2");
    grant.set("endorsement_code", "serialized-custody");
    grant.set("reason", "Grant the approved modular authority.");

    const revoke = new FormData();
    revoke.set("license_id", licenseId);
    revoke.set("license_endorsement_id", endorsementId);
    revoke.set("expected_license_version", "3");
    revoke.set("reason", "Withdraw this modular authority.");

    expect(readGrantEndorsementForm(grant).success).toBe(true);
    expect(readRevokeEndorsementForm(revoke).success).toBe(true);
  });
});
