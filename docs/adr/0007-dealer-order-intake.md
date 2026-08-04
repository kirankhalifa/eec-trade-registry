# ADR 0007: Dealer order intake increment

Status: Accepted
Date: 2026-08-04

## Context

ADR 0005 permits orders without price or stock on hand, partial decisions, awaiting-stock outcomes, and permission-based ordinary, restricted, and unique controls. Exact endorsement prerequisites, price precedence, quotas, payment rules, reservation extensions, and fulfillment operations remain unresolved. The dealer portal previously exposed only a read-only organization overview.

## Decision

Implement commercial-demand intake without implying inventory allocation:

- Give effective-dated dealer representatives separate `order.read`, `order.create`, and `order.cancel` grant scopes.
- Allow one submitted requisition per idempotency request ID for a current represented dealer authorization and optional current license.
- Offer only currently published active items and snapshot item, unit, configurable control flags, requested quantity, and the deployment-configured default currency.
- Preserve missing unit price as SQL `null` with `pricing_status = 'pending'`; never convert it to zero.
- Create all lines in `review_required`. Submission never reads stock and creates no reservation, quota, ledger, custody, or title record.
- Give staff separate private-read, routine-review, ordinary, restricted, unique, price-edit, and cancellation permissions. Select the exact approval permission from stored control flags rather than names or UI choices.
- Support approve, partially approve, deny, and awaiting-stock line outcomes. Derive the header status from all current line outcomes in the same transaction.
- Require optimistic order versions for staff review, price changes, and cancellation. Make commands idempotent by request ID.
- Permit dealer or staff cancellation only before any reservation, ready, or fulfillment progress. Fulfilled quantities require the later return/correction workflow.
- Append order and line events, full audit context including represented party, and one durable outbox event in the same transaction as every accepted command.
- Deny direct table access. Dealer and staff pages use narrow security-definer projections and commands.

## Consequences

- A dealer can submit and track a real requisition even when price and stock are unavailable.
- Unique goods cannot pass through the ordinary approval permission, but serialized-asset allocation remains a separate future transaction.
- An approval records authorized commercial intent; it is not evidence of eligibility checks whose policy is not configured, stock availability, reservation, payment, custody, or title.
- Future price, quota, reservation, and fulfillment slices must extend the authoritative transaction boundary and preserve existing event history rather than reinterpret it.
- External notification delivery remains absent; committed outbox rows are the only integration handoff.
