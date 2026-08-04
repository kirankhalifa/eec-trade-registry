# ADR 0005: Approved operating policy baseline

Status: Accepted  
Date: 2026-08-04  
Decision owner: Product owner

## Context

The catalogue, public verification, staff catalogue, and credential-based dealer-access foundations deliberately stopped at policy boundaries. The product owner has now approved a baseline that unlocks licensing, orders, inventory, transfers, consignment, and projection-integration foundations.

Configuration records remain the implementation mechanism for deployment vocabulary. The decisions below approve initial East Empire Company configuration; they do not authorize item-name checks or setting-specific branches in business logic.

## Decisions

1. The public institution name is **East Empire Company**. Instants are stored in UTC and displayed in the institution's configured Eastern Time zone, using the IANA identifier `America/New_York`. The initial currency is `SEP`, displayed as **Septims**, with zero fractional minor units.
2. The recommended configurable licensing baseline is approved: three initial classes (general trade, commercial dealer, and institutional trade) with modular endorsements. Initial endorsement configuration may cover regulated goods, consignment, and serialized-asset custody. Classes and endorsements do not imply pricing or inventory authority.
3. A consequential staff action may be completed by any active actor holding the required permission and scope. There is no universal two-person approval requirement. Reasons, audit records, state checks, and action-specific elevated permissions remain mandatory where specified; the policy model may add dual control later without changing stored business history.
4. Dealer access initially uses individual email/password credentials through Supabase Auth. Authentication alone grants no dealer authority; an active representative grant remains required.
5. Price configuration must be editable, but initial price values may be blank. A missing price is represented as unavailable or pending pricing, never as zero. An order may be submitted without an authoritative price and must expose that review requirement.
6. The initial configurable control behaviors are ordinary, restricted, and unique. Ordinary lines may follow routine validation, restricted lines require staff review, and unique lines require transaction-specific approval plus serialized custody controls.
7. Partial approval and partial fulfillment are allowed. Unfulfilled quantities retain an explicit remaining state. Cancellation releases unconsumed claims; fulfilled quantities require a return or correction workflow rather than cancellation.
8. Orders may be created and submitted without inventory on hand. Lack of stock produces an explicit awaiting-stock or back-order state and never creates negative stock. Stock reservations are created only through an authorized inventory operation. Once created, the default reservation term is 48 hours and may be extended by a sufficiently permitted actor with a reason.
9. Posted inventory may not go negative. Corrections and reconciliation adjustments require reasons; exceptional adjustments require elevated inventory permission. Physical counts support blind entry and variance review before ledger posting.
10. Wholesale title transfers at confirmed collection or destination receipt, depending on fulfillment mode. Dispatch alone transfers custody into an in-transit state, not title.
11. East Empire Company retains ownership of consigned goods until an accepted sale or other approved settlement event. Custody and ownership remain separate throughout the consignment lifecycle.
12. Public dealer and license verification remains exact-reference-only and uses the currently documented field allowlists. Name-based public search is not approved.
13. Public Google Sheet projections use a target refresh cadence of 15 minutes, include generated-at/freshness metadata, and remain one-way exports. Destination identifiers and ownership are environment configuration.
14. Discord initially supports public `/catalogue`, `/dealer`, and `/license` lookups plus private staff alerts. Discord does not approve, fulfill, or otherwise mutate business state. Server, channel, identity-binding, and retention configuration remain deployment inputs.

## Consequences

- Licensing, order intake, editable pricing, ledger, reservation, transfer, consignment, and projection-outbox schemas may now be implemented against this baseline.
- Order submission and stock allocation remain separate transactions. Awaiting stock is a valid operational outcome.
- Null price and zero price have different meanings and must remain distinguishable in schema, functions, UI, and exports.
- Permission checks replace title checks. Any actor with the required current grant can perform an action; the UI must not infer authority from a job label.
- Integration delivery cannot be activated until destination identifiers and secrets are supplied through managed environment configuration.

## Remaining decisions

The following are not implied by this ADR:

- License duration, renewal/grace windows, exact holder eligibility, and endorsement prerequisites
- Final-customer reporting, quotas, payment, deposits, credit, fees, refunds, and tax behavior
- Per-action approval limits, emergency powers, sanctions, appeals, and retention periods
- Reservation extension limits and uncollected-order consequences beyond explicit release
- Consignment reporting cadence, commission/settlement amounts, shrinkage, and loss allocation
- Specific Sheet IDs, Discord guild/channel IDs, production domains, email provider, hosting projects, secrets, and operational owners
- Accessibility target, supported client matrix, service objectives, recovery objectives, and production support procedures

Dependent implementations must continue to stop at these narrower boundaries.
