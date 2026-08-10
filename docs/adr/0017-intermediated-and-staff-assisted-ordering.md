# ADR 0017: Intermediated and staff-assisted ordering

Status: Approved  
Date: 2026-08-10

## Context

The EEC operates primarily through authorized in-character agents and licensed businesses rather than accepting wholesale orders directly from ordinary members of the public.

The intended roleplay chain is:

```text
public customer -> licensed business -> authorized EEC agent -> EEC order and warehouse workflow
```

For example, a public customer who wants a configured catalogue item approaches a business that holds current EEC dealer authorization and the relevant license. The business presents the request to an EEC agent. The agent verifies the business and its representative, then may enter and process the order on behalf of that business.

The current production increment supports dealer-representative submission followed by staff review. It does not yet expose a staff-assisted order-entry command or screen. The operating model must be recorded before that feature is implemented so it does not conflate the public customer, licensed business, authenticated actor, and EEC ordering party.

## Decision

1. An ordinary public customer is not the EEC wholesale ordering party.
2. The EEC wholesale ordering party is the currently authorized and appropriately licensed business or institution.
3. A verified representative may submit through the dealer portal.
4. An EEC staff actor with a future explicit assisted-order permission may create the same class of requisition on behalf of the verified business after confirming representative authority through an approved interaction.
5. Dealer self-service and staff-assisted entry converge on the same authoritative order model, validations, reference allocation, snapshots, history, audit, and later warehouse workflow.
6. Staff-assisted entry records the staff actor as the command actor, the licensed business as the ordering party, the verified business representative or approved communication context, an on-behalf-of reason, and a staff-assisted source surface.
7. Staff never authenticate as the dealer, borrow dealer credentials, or make the public customer the wholesale party merely to enter an assisted order.
8. The final customer's identity is not required EEC order data unless a later approved policy introduces final-customer reporting for a defined purpose and visibility class.
9. Order entry, whether dealer-submitted or staff-assisted, does not reserve stock, move inventory, transfer title or custody, consume quota, or guarantee a settled price.
10. Orders may be recorded without stock on hand and may proceed to an explicit awaiting-stock state.

## Required implementation properties

A future staff-assisted command must:

- Require an active staff actor and an explicit permission separate from ordinary dealer submission
- Re-resolve the selected business, current dealer authorization, relevant license, representative authority, jurisdiction, published item, quantity, and configured control profile
- Reject caller-supplied actor or authority claims that do not match current database records
- Allocate the normal immutable EEC order reference
- Preserve nullable price and control snapshots at the same boundary as dealer submission
- Accept an idempotency key and prevent duplicate assisted orders
- Write order and line history, a complete audit entry, and a durable outbox event in the same transaction
- Identify the staff actor, ordering business, verified request context, source surface, and reason
- Produce an order that uses the same staff review, reservation, fulfillment, cancellation, and projection rules as a dealer-submitted order

The staff UI must select the business from an authorized staff projection rather than accepting an arbitrary party identifier. It should make clear that the EEC transaction is with the licensed business, not the final customer.

## Consequences

- The roleplay workflow can be conducted through an EEC agent without requiring every business interaction to begin as self-service portal entry.
- The business remains commercially and authoritatively distinct from its customer.
- Audit history accurately distinguishes who entered an order from which party placed it.
- Dealer credentials remain private and are never shared with EEC staff.
- A staff agent cannot bypass dealer, license, item-control, or later warehouse rules simply because the order was entered through the staff surface.
- Final-customer retail terms remain outside the initial EEC wholesale registry.

## Current implementation gap

Until the assisted command and `/staff/orders/new` surface are implemented, the safe production flow remains:

```text
verified business representative submits in dealer portal
  -> EEC agent reviews in staff order desk
  -> warehouse reserves and fulfills
```

Staff must not work around the missing assisted-entry surface by sharing credentials, manually inserting database rows, or treating Discord messages as orders.

## Alternatives rejected

### Let the public customer order directly

Rejected because it bypasses the licensed-business intermediary and confuses a retail request with the EEC wholesale relationship.

### Let EEC staff use the dealer's account

Rejected because it destroys actor attribution, violates credential separation, and makes the audit record false.

### Treat a Discord message as the authoritative order

Rejected because Discord is not an authoritative data store and cannot provide the required transaction, permission, idempotency, history, or warehouse guarantees.

### Record the final customer as the ordering party

Rejected for the initial model because the business, not its customer, holds the EEC authority and receives the wholesale fulfillment. Final-customer reporting remains a separate policy question.
