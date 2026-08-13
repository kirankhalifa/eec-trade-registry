# ADR 0022: Object-centered operations

- Status: accepted
- Date: 2026-08-13

## Context

Order review, reservation, and fulfillment are separate authoritative transactions, but exposing each transaction as a separate staff destination forced agents to reopen or copy the same order reference repeatedly. The dashboard also repeated navigation already present in the sidebar, while routine projection-worker audit rows displaced meaningful human decisions. Forms exposed every schema field even when the registry could derive a safe default.

## Decision

- Queues remain specialist lists, but an order detail page is the canonical place to progress one order from review through reservation and handoff.
- The page loads permission-filtered order, inventory, reservation, and fulfillment projections. It shows only the next valid action returned by those projections. Each action continues to call its existing secure database function and commit independently.
- Safe single choices are derived and displayed read-only. Multiple valid choices remain explicit. Rare fields and prefilled audit notes live under an advanced disclosure.
- A global keyboard/search launcher replaces duplicate workspace cards and provides plain-language actions such as **Create an order**, **Add a catalogue item**, and **Review applications**.
- Dashboard audit activity includes actor-initiated authoritative changes. Projection-worker activity remains on system health.
- Public demonstration goods and invented prices are archived/withdrawn through a recoverable data migration and are no longer treated as public policy.
- A root route-level loading boundary does not replace meaningful server-rendered public headings. Catalogue and application routes provide descriptive metadata.

## Consequences

- Database transactions, ledger rules, optimistic versions, warehouse scopes, and permission checks do not change.
- An agent no longer carries an order reference between desks for normal processing.
- The normal path asks only for facts that cannot be derived, while exceptional cases remain available.
- Specialist inventory and fulfillment pages remain available for queue-wide work, reversals, and exception management.
- The interface may summarize workflow progress, but it never calculates authoritative balances, eligibility, or state transitions in the browser.
