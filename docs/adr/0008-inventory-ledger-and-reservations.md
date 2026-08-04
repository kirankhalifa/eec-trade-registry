# ADR 0008: Inventory ledger and reservation increment

Status: Accepted
Date: 2026-08-04

## Context

ADR 0005 prohibits negative stock, approves order submission without stock, establishes a 48-hour initial reservation term, requires reasoned corrections, and separates reservations from physical inventory. Exact adjustment thresholds, count procedure, serialized custody, reservation extension limits, fulfillment proof, and transfer discrepancy policy remain unresolved.

## Decision

Implement a fungible-stock and reservation foundation without implying fulfillment:

- Configure East Empire Company as the operating party for a primary warehouse and receiving, available, and quarantine locations. Seed no opening quantity.
- Represent each stock position as a physical inventory account and represent inbound provenance through an explicit external-source account. Accounts store dimensions, never current quantity.
- Post a fungible receipt as one immutable transaction with equal negative external and positive physical ledger entries.
- Require every transaction to balance to zero. Constraint triggers prohibit negative physical balance and prohibit any ledger change that would reduce on-hand below effective reservations.
- Reject serialized items from the fungible receipt and reservation commands until individual asset registration and custody history exist.
- Correct a receipt only through one linked reversal. Preserve the original transaction and entries permanently.
- Derive on-hand from ledger entries, reserved from active non-elapsed reservations, and available as their difference.
- Lock the physical account and order line when creating a reservation. Revalidate current ledger balance, all effective claims, item identity, order state, and approved unfulfilled quantity.
- Give every new reservation the approved 48-hour initial term. Permit a sufficiently scoped actor to extend a current claim with a reason; do not invent a maximum extension while policy is unresolved.
- Release unconsumed claims or explicitly finalize elapsed claims. Couple reservation changes to line state, derived order state, audit, append-only events, and durable outbox records.
- Scope inventory functions through active staff assignments. `assignment_scope.warehouse_ids` is an allowlist when present and global when absent.
- Deny direct browser access to inventory and reservation tables. The staff page uses secured projections and commands only.

## Consequences

- Staff can establish real stock and reserve approved demand without an editable balance field or spreadsheet authority.
- An approved or reserved order is not fulfilled. No issue entry, custody event, title transfer, quota consumption, payment result, or collection proof is created in this increment.
- Elapsed reservations cease reducing derived availability by time even before a scheduled worker records their terminal state; the UI exposes them for explicit finalization.
- A replacement after reversal is a new receipt with its own request ID, source reference, actor, reason, and audit trail.
- Reconciliation adjustments, blind counts, transfers, serialized assets, consignment custody, and fulfillment require later policy-bounded increments.
