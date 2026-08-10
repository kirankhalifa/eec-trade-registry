# ADR 0019: Rapid configuration and inventory entry

- Status: accepted
- Date: 2026-08-10

## Context

The product owner requires routine administration to be materially faster than maintaining a large Google Sheet. Creating a material previously required an unpublished catalogue record followed by separate supply configuration, publication, pricing, and inventory steps. The inventory receipt form also required staff to supply routine provenance wording manually on every entry.

Speed cannot be achieved by introducing an editable current-stock value, skipping provenance, moving authority into browser state, or granting Discord roles database authority. The platform still needs one canonical item, effective-dated public terms, exact permission checks, an immutable inventory ledger, audit evidence, and safe retries.

## Decision

- Add an authenticated **Configuration and quick operations** workspace intended to complete ordinary item onboarding and ordinary inventory receipts in under 30 seconds once required policy choices exist.
- A quick-created item is one atomic command. It creates the canonical item and supply policy together, and may also create its initial public presentation, explicit scheduled price, and a permitted balanced opening receipt.
- Codes, slugs, generic audit wording, and receipt references may be generated when staff leave them blank. Stable codes remain immutable after creation under the existing correction policy.
- Supply presets are interpreted by the database, not the browser:
  - `warehouse_stocked` permits ordinary balanced receipts.
  - `player_sourced_reserve` requires procurement delivery provenance and blocks generic receipts.
  - `made_to_order` and `limited_release` are fungible policy modes with no invented stock.
  - `serialized_unique` requires the serialized asset registry and blocks generic quantity receipts.
- Quick ordinary inventory entry accepts item code, quantity, and location. Optional source and reason fields receive traceable generated defaults when omitted.
- Public presentation replacement closes the prior effective interval and inserts a new current record. Price replacement or clearing does the same for the explicitly selected schedule. Previous terms remain reconstructable.
- Platform administrators receive configuration-reference read/manage permissions. Catalogue managers receive configuration read plus public-presentation and explicit-schedule price management. Cross-domain quick item creation still requires the caller to hold every underlying permission used by the selected options.
- Categories, units, license classes, endorsement definitions, availability profiles, and control profiles remain configuration records and can be created without code changes.
- Staff commands store idempotency receipts so a retry cannot duplicate a complete onboarding or terms change.

## Consequences

- Common work is shorter without weakening the ledger, permissions, or audit model.
- A platform administrator does not receive warehouse, procurement, catalogue-write, or pricing authority merely from the administrator title. The quick workflow fails atomically when the current actor lacks one of the selected operation's permissions.
- Player-sourced reserves remain intentionally slower than an ordinary administrative receipt because the supplier, current offer, inspected delivery, and payment evidence are part of their economic purpose.
- The under-30-second target is an experience requirement for prepared routine work, not permission to bypass exceptional review, serialized custody, or player-source provenance.

## Rejected alternatives

- An editable stock balance was rejected because it would erase receipt and correction provenance.
- A Google Sheet import-on-edit path was rejected because it would create a second source of business state.
- Automatically granting every domain permission to platform administrators was rejected because authentication and administration are not commercial or warehouse authority.
- Inferring control or supply behavior from item names or category labels was rejected because those labels are configurable.
