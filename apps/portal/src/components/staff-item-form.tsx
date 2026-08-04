import {
  createCatalogueItemAction,
  updateCatalogueItemAction,
} from "@/app/staff/actions";
import type {
  StaffCatalogueItem,
  StaffCatalogueReferenceData,
} from "@/lib/staff-catalogue";

interface StaffItemFormProps {
  item?: StaffCatalogueItem;
  references: StaffCatalogueReferenceData;
}

export function StaffItemForm({ item, references }: StaffItemFormProps) {
  const editing = Boolean(item);

  return (
    <form
      action={editing ? updateCatalogueItemAction : createCatalogueItemAction}
      className="staff-form"
    >
      {item && (
        <>
          <input name="item_id" type="hidden" value={item.id} />
          <input
            name="expected_version"
            type="hidden"
            value={item.version}
          />
          <section className="staff-readonly-grid" aria-label="Stable identifiers">
            <div>
              <span>Item code</span>
              <strong>{item.item_code}</strong>
            </div>
            <div>
              <span>Public slug</span>
              <strong>{item.slug}</strong>
            </div>
            <div>
              <span>Record version</span>
              <strong>{item.version}</strong>
            </div>
          </section>
        </>
      )}

      {!editing && (
        <fieldset className="staff-fieldset">
          <legend>Stable identifiers</legend>
          <div className="staff-form-grid">
            <label className="field">
              <span>Item code</span>
              <input
                autoComplete="off"
                maxLength={32}
                name="item_code"
                pattern="[A-Z0-9][A-Z0-9_-]{1,31}"
                placeholder="EQ-ITEM-001"
                required
              />
            </label>
            <label className="field">
              <span>Public slug</span>
              <input
                autoComplete="off"
                maxLength={80}
                name="slug"
                pattern="[a-z0-9][a-z0-9-]{1,79}"
                placeholder="descriptive-item-name"
                required
              />
            </label>
          </div>
          <p className="field-help">
            These identifiers cannot be edited in this slice because the
            correction policy is unresolved.
          </p>
        </fieldset>
      )}

      <fieldset className="staff-fieldset">
        <legend>Canonical record</legend>
        <div className="staff-form-grid">
          <label className="field staff-field-wide">
            <span>Internal display name</span>
            <input
              defaultValue={item?.display_name}
              maxLength={160}
              name="display_name"
              required
            />
          </label>
          <label className="field staff-field-wide">
            <span>Internal description</span>
            <textarea
              defaultValue={item?.description}
              maxLength={4000}
              name="description"
              rows={5}
            />
          </label>
          <label className="field">
            <span>Category</span>
            <select
              defaultValue={item?.category_code ?? references.categories[0]?.code}
              name="category_code"
              required
            >
              {references.categories.map((category) => (
                <option key={category.code} value={category.code}>
                  {category.display_name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Unit of measure</span>
            <select
              defaultValue={item?.unit_code ?? references.units[0]?.code}
              name="unit_code"
              required
            >
              {references.units.map((unit) => (
                <option key={unit.code} value={unit.code}>
                  {unit.display_name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Inventory mode</span>
            <select
              defaultValue={item?.inventory_mode ?? "fungible"}
              name="inventory_mode"
              required
            >
              <option value="fungible">Fungible quantity</option>
              <option value="serialized">Individually serialized</option>
            </select>
          </label>
          <label className="field staff-field-wide">
            <span>Internal notes</span>
            <textarea
              defaultValue={item?.internal_notes}
              maxLength={4000}
              name="internal_notes"
              rows={4}
            />
          </label>
        </div>
      </fieldset>

      <fieldset className="staff-fieldset staff-audit-fieldset">
        <legend>Audit reason</legend>
        <label className="field">
          <span>Why is this change required?</span>
          <textarea maxLength={500} minLength={3} name="reason" required rows={3} />
        </label>
        <p className="field-help">
          The reason, actor, permission, previous state, new state, request ID,
          and timestamp are recorded together.
        </p>
      </fieldset>

      <div className="staff-button-row">
        <button className="button button-primary" type="submit">
          {editing ? "Save canonical record" : "Create unpublished item"}
        </button>
      </div>
    </form>
  );
}
