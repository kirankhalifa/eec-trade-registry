# ADR 0013: Serialized asset identity and custody-event boundary

Status: Accepted for the initial serialized-asset increment
Date: 2026-08-05

## Decision

An individually controlled good receives one stable asset identity and an append-only event history. Current owner, custodian, warehouse, location, condition, lifecycle status, and inspection due date are maintained only as transactionally consistent projections written by the same database functions that append their evidence. Direct table mutation is denied.

The initial registry supports warehouse registration, a single exclusive 48-hour allocation to one approved serialized order line, explicit release or elapsed expiry, immediately accepted custody handoff, inspection, and controlled loss, recovery, damage, seizure, retirement, and destruction. Ownership does not change during custody transfer. Commands are permission checked, warehouse scoped where an initial physical location is selected, version checked, idempotent, reasoned, audited, and event producing.

## Consequences

- An asset cannot satisfy two active allocations or have two authoritative current custodians.
- Custody, condition, and lifecycle history remain reconstructable without Discord messages, Sheets, or generated documents.
- Retirement and destruction are terminal; an erroneous terminal event requires a future formal correction workflow rather than direct reactivation.
- Allocation records demand but does not move custody, transfer title, or fulfill an order.
- Transaction-specific approval, allocation consumption into unique fulfillment, external recipient acceptance, public disclosure, evidence storage, circulation controls, and formal custody correction remain separate policy-gated increments.
