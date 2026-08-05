# ADR 0011: Fungible fulfillment consumes one reservation atomically

Status: Accepted
Date: 2026-08-05

## Context

The warehouse ledger and reservation slice could record demand and stock claims but could not complete an approved handoff. Completion must never be assembled from separate frontend writes because a partial failure could move stock without advancing the order, or mark demand fulfilled without inventory evidence.

## Decision

- One fulfillment command consumes one active, unexpired fungible reservation in its assigned warehouse.
- The database locks the inventory account, reservation, order line, and order before revalidating authority, stock, item identity, and approved remaining quantity.
- The same transaction marks the reservation consumed, posts a balanced physical-to-external issue, records `order_fulfillments`, advances fulfilled quantity and derived statuses, appends history/audit, and emits an outbox event.
- A fulfillment reversal is a separate controller permission. It adds a linked inverse ledger transaction and reopens demand.
- Reversal never reactivates the consumed reservation. A new claim is required before another completion attempt.
- Serialized goods do not use this command; they remain gated on the asset and custody registry.

## Consequences

The database retains a reconstructable chain from dealer order through reservation and stock issue. Retry keys make completion and reversal idempotent. The external ledger account balances fungible movement but does not claim to model recipient custody; party-specific custody belongs in the transfer and consignment slice.
