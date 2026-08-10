import { describe, expect, it, vi } from "vitest";

import { getStaffConfigurationWorkspace } from "@/lib/configuration";

describe("configuration workspace", () => {
  it("normalizes numeric database values", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: {
        availability_profiles: [],
        capabilities: {
          can_manage_catalogue: true,
          can_manage_configuration: true,
          can_manage_pricing: true,
          can_manage_publication: true,
          can_manage_supply_policy: true,
          can_post_receipts: true,
        },
        categories: [], control_profiles: [], endorsements: [],
        generated_at: "2026-08-10T12:00:00Z",
        items: [{
          admin_receipt_allowed: true, availability_profile_code: null,
          bulk_minimum: null, category_code: "materials", control_profile_code: null,
          currency_code: "SEP", description: "A material.", display_name: "Material",
          id: "10000000-0000-4000-8000-000000000001", inventory_mode: "fungible",
          item_code: "ITM-1001", order_increment: "1.000", price_amount_minor: "125",
          price_schedule_id: "10000000-0000-4000-8000-000000000002",
          procurement_enabled: false, public_description: null, public_name: null,
          publication_status: null, requirement_summary: null, slug: "material",
          status: "active", supply_mode: "warehouse_stocked", unit_code: "each",
        }],
        license_classes: [], price_schedules: [], units: [], warehouses: [],
      },
      error: null,
    });
    const result = await getStaffConfigurationWorkspace({ rpc } as never);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.items[0].order_increment).toBe(1);
      expect(result.data.items[0].price_amount_minor).toBe(125);
    }
  });

  it("fails closed on permission errors", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: "staff_permission_denied" } });
    await expect(getStaffConfigurationWorkspace({ rpc } as never)).resolves.toEqual({
      ok: false, code: "access_denied",
    });
  });
});
