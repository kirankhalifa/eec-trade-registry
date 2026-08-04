# EEC Trade Registry — Delivery Roadmap

Status: Implementation in progress
Delivery strategy: Small, reviewable vertical slices with policy gates and database-first invariants

The cross-domain operating baseline was approved on 2026-08-04 in ADR 0005. Slice-level lists below now distinguish resolved baseline policy from narrower decisions that still block production depth.

## 1. Roadmap principles

- Build one complete workflow at a time rather than all backend layers followed by all frontends.
- Supabase PostgreSQL is authoritative from the first slice.
- Introduce no Google Sheet, Discord, or generated-document dependency before the underlying workflow works without it.
- Every schema change is a migration; every business rule receives tests.
- Add row-level security and audit behavior with each feature, not as a final hardening pass.
- Treat unresolved policy as a gate. Do not encode an arbitrary answer because implementation has begun.
- Prefer a thin end-to-end slice that can be reviewed over a broad partially working subsystem.
- Keep pull requests focused and reversible.

## 2. Phase 0 — Policy and architecture baseline

### Outcomes

- Approve the product boundary and vocabulary strategy.
- Resolve decisions required for the first two slices.
- Establish repository, development, migration, test, preview, and review conventions.
- Define non-production and production Supabase environment strategy.
- Create decision-record and threat-model templates.

### Decisions required

- Initial public catalogue fields and availability language
- Initial item categories and configurable control-profile behavior
- Locale and reporting cutoff details beyond the approved `SEP`/Septims currency and `America/New_York` time zone
- Staff authentication approach for the first internal surface
- Public reference and item-code formats
- Legacy workbook ownership, import permission, and data-quality process

### Candidate deliverables

- Architecture decision records for Supabase boundary, monorepo layout, auth model, and rules strategy
- Initial threat model and data-classification inventory
- Development environment and migration workflow
- CI checks for formatting, types, migrations, and tests
- Seed-data conventions using fictional, non-sensitive data
- Issue epics and acceptance-criteria template

### Exit criteria

- No implementation-blocking ambiguity remains for the public catalogue slice.
- Engineering rules are accepted.
- Environments and secret ownership are documented.
- A reviewer can explain where authoritative business logic will live and how it will be tested.

## 3. Slice 1 — Public catalogue foundation

### User outcome

Anyone can browse a single, coherent public catalogue without logging in.

### Scope

- Canonical items, categories, tags, units, and publication records
- Public price representation and effective dates
- Configurable public control and availability language
- Public catalogue view/function with strict field allowlist
- Search, filtering, item detail, and generated-at display
- Initial validated import of catalogue data from the legacy workbook
- Public RLS and leakage tests
- Basic catalogue audit for staff-originated publication changes, even if management UI follows later

### Explicitly excluded

- Dealer-specific pricing
- Licenses and endorsements
- Orders and reservations
- Warehouse stock management
- Discord and Sheets publishing

### Exit criteria

- One item appears once in authoritative data, regardless of how many audiences may later see it.
- Anonymous callers can read only the approved projection.
- Money is numeric in storage and formatted in presentation.
- Ambiguous legacy values are reported, not guessed.
- Search and filters work against realistic seed volume.
- Tests prove unpublished and restricted fields cannot leak.

## 4. Slice 2 — Staff catalogue management

Implementation status: The first policy-neutral increment provides Supabase Auth session handling, effective-dated catalogue role assignments, an authorized internal work queue, and audited create/edit/archive commands with optimistic concurrency. Effective-dated publication and price writes remain gated by the unresolved decisions below.

### User outcome

Authorized staff can maintain the master catalogue, prices, publication, and control metadata; public output changes from the same source record.

### Scope

- Staff authentication and minimal role assignment
- Catalogue work queue and create/edit/archive operations
- Effective-dated public price and publication management
- Control-profile and requirement assignment
- Approval path for high-impact changes if policy requires it
- Complete audit entries with previous and new state
- Migration and function tests, including concurrent/effective-date cases

### Remaining decisions

- Catalogue manager approval authority
- Price rule precedence for public pricing
- Backdating and scheduled publication policy
- Archive, rename, and item-code correction policy

### Exit criteria

- Staff UI cannot bypass secure functions for consequential changes.
- Every published change is attributable and historical price state can be reconstructed.
- Public catalogue reflects committed changes without manual duplication.
- Incorrect permissions and cross-scope access are covered by tests.

## 5. Slice 3 — Parties, dealers, and licensing

Implementation status: The public-verification increment provides configurable jurisdictions, party and dealer types, public-disclosure controls, dealer and license status definitions, license classes, modular endorsements, public conditions, exact-reference privacy-safe functions, and dealer/license pages. The credential-access increment adds dealer actor identities, configurable representative roles, effective-dated scoped representation, cross-organization isolation, and a private read-only registry overview. The staff lifecycle increment adds a licensing work queue, configurable reference allocation, audited/idempotent issuance, versioned activation/suspension/reinstatement/revocation/surrender commands, modular endorsement grant/revocation, and durable outbox records. Party/dealer administration, secure-link exchange, applications, review, renewal, conditions, factor assignments, scheduled expiration, and production abuse controls remain gated.

### User outcome

Staff can authorize dealers and issue real licenses with modular endorsements; the public can verify approved records.

### Scope

- Parties, organizations, representatives, dealer authorizations, jurisdictions, and factor assignments
- License classes, endorsement definitions, conditions, applications, reviews, issuance, and status history
- Public dealer and license verification functions and pages
- Dealer enrollment foundation and secure representation model
- Staff licensing work queue
- Renewal, suspension, reinstatement, revocation, and surrender at the minimum approved policy depth
- Permission, privacy, and audit tests

### Decisions required

- Exact holder eligibility for the approved initial classes
- Exact prerequisites for the approved modular endorsements
- Dealer and regional factor definitions
- Effective dates, duration, renewal, grace, and provisional authority
- Any future expansion beyond the approved public allowlist and exact-reference lookup
- Action-specific licensing approval limits or dual-control rules, if any

### Exit criteria

- A pending application cannot be mistaken for a valid license.
- Public verification exposes only approved fields and has privacy-safe miss behavior.
- Status changes are effective-dated, authorized, and audited.
- Endorsements are independent of price schedules and item publication.
- Dealer representative access cannot cross organization boundaries.

## 6. Slice 4 — Dealer catalogue and wholesale ordering

Implementation status: Lightweight Supabase credential sessions, effective-dated representative scopes, current dealer-authorization checks, and the private organization registry overview are implemented. The first wholesale increment adds a published-item requisition form, idempotent submission without price or stock, immutable line/control snapshots, dealer tracking and cancellation, a staff queue, control-specific partial/deny/awaiting-stock decisions, editable nullable prices, optimistic concurrency, audit/history, and notification outbox records. Dealer-specific catalogue eligibility, price schedules and provenance, drafts, quotas, override objects, reservations, and fulfillment remain future work.

### User outcome

An authenticated dealer can see applicable terms, submit a requisition, and track review; staff can process it without manually recalculating eligibility or price.

### Scope

- Dealer authentication through the approved lightweight path
- Private catalogue evaluation by dealer, license, endorsement, jurisdiction, and price schedule
- Order drafts; submission, line snapshots, review queue, approvals, denials, cancellations, and status history are implemented at initial intake depth
- Effective-dated price schedules and deterministic selection
- Price override request and approval records
- Quota policy foundation and holds if required by approved timing
- Policy-safe dealer status explanations
- Notification outbox records without external Discord delivery yet

### Remaining decisions

- Price schedule audience and precedence; price values may remain unset and editable
- Dealer order authority and representative verification
- Approval thresholds by control level, value, quantity, and region
- Quota subject, window, timing, reset, carryover, and exception rules
- Substitution and split-shipment details beyond approved partial, cancellation, and awaiting-stock behavior
- Payment, deposit, credit, and debt checks included in v1

### Exit criteria

- Order submission revalidates and snapshots authoritative price and rule provenance.
- Dealer cannot see or act on another party's records.
- Restricted and unique items cannot follow an ordinary auto-approval path.
- Override decisions are separate, reasoned, and audited.
- Retried submissions do not create duplicate orders or quota entries.

## 7. Slice 5 — Reservations and warehouse ledger

Implementation status: the first increment configures the EEC warehouse and locations without inventing opening stock; adds physical/external accounts, balanced immutable fungible receipts, linked reversals, ledger-derived positions, warehouse-scoped staff roles, and atomic 48-hour reservation creation, extension, release, and expiry coupled to order-line/header state. Serialized receipt, reservation consumption, picking, fulfillment, returns, counts, adjustments, reconciliation, scheduled expiry execution, and low-stock projections remain future work.

### User outcome

Staff can receive, reserve, fulfill, transfer, and reconcile stock with a complete ledger trail; dealers see reliable reservation and collection status.

### Scope

- Warehouses, locations, inventory accounts, transaction headers, and immutable ledger entries
- Derived on-hand, reserved, and available positions
- Atomic reservation, extension, release, expiration, and consumption
- Receipts, issues, returns, losses, damage, reversal, and reconciliation adjustment
- Picking, ready-for-collection, collection, and partial fulfillment
- Scheduled reservation expiry
- Inventory work queues and low-stock projections
- Concurrency and idempotency tests

### Remaining decisions

- Exact stock-ready trigger and reservation extension limit beyond the approved 48-hour initial term
- Quantitative exceptional-adjustment and variance thresholds; negative stock is prohibited
- Physical count assignment and recount procedure beyond approved blind entry and variance review
- Stock states and owner/custodian account conventions
- Uncollected-order and partial-fulfillment policy
- Whether quota holds and stock reservations are always coupled

### Exit criteria

- No application path directly overwrites a current-stock value.
- Two concurrent requests cannot reserve the same final quantity.
- A posted movement can be corrected only through a linked reversal/correction.
- Fulfillment consumes reservations, posts inventory, updates quota, writes history/audit, and emits events atomically.
- Staff can reconstruct a calculated balance from ledger entries.

## 8. Slice 6 — Transfers, consignment, and unique assets

### User outcome

The organization can control custody across warehouses, factors, and dealers; serialized goods remain individually traceable.

### Scope

- Transfer request, authorization, dispatch, in-transit, receipt, dispute, and return
- Owner/custodian separation
- Consignment agreements, issue, dealer reports, acceptance, return, and reconciliation
- Serialized asset registration, exclusive reservation, custody event history, condition, and inspection scheduling
- Unique-transaction approvals and custody acceptance
- Missing, damaged, seized, retired, destroyed, and recovered lifecycle events at approved depth
- Dealer and staff custody views

### Remaining decisions

- Proof details for the approved wholesale title-transfer point
- Consignment settlement, reporting, shrinkage, return, and loss policy beyond retained EEC ownership until accepted sale or settlement
- Transfer acceptance and discrepancy procedure
- Unique-asset approval authority, circulation rules, and inspection cadence
- Serialized-asset public disclosure
- Custody correction and emergency-seizure controls

### Exit criteria

- Dispatched stock is represented in transit and cannot disappear between locations.
- Consigned stock retains configured ownership while custody changes.
- A unique asset cannot have two active reservations or current custodians.
- Post-dispatch cancellation is impossible; exceptions use recorded return or dispute paths.
- Asset lifecycle is reconstructable without using messages or documents as evidence of current state.

## 9. Slice 7 — Projection integrations

### User outcome

Approved public data reaches Google Sheets and users receive timely Discord lookups and notifications without creating secondary business state.

### Scope

- Transactional outbox worker and delivery monitoring
- Public Google Sheet export definitions, full/versioned export, freshness markers, checksums, and retries
- Discord public lookup commands against public functions
- Discord private lookup after identity binding
- Versioned notification templates and destination policies
- Staff monitoring and safe replay controls
- Generated license/order documents if prioritized and policy-approved

### Remaining decisions

- Sheet destinations, columns, public ownership, and stale-data language beyond the approved 15-minute cadence
- Discord server/channel mapping, identity binding, and retention beyond the approved read-only commands and private staff alerts
- Which events are public, dealer-private, staff-only, or silent
- Generated document authority, signature/seal, template ownership, and retention

### Exit criteria

- Sheet edits cannot change authoritative data.
- Discord messages cannot approve or fulfill a transaction outside secure business functions.
- Duplicate event delivery does not create duplicate messages or exports beyond defined replacement behavior.
- Staff can see failures, retry safely, and identify the source business record.
- Public outputs expose only approved projection fields.

## 10. Slice 8 — Compliance, appeals, and operational hardening

### User outcome

Staff can investigate and resolve compliance matters with due process, while operators can run and recover the platform safely.

### Scope

- Compliance case, inspection, allegation, finding, evidence, action, and appeal workflows
- Atomic effects on licenses, endorsements, quotas, orders, reservations, custody, or standing
- Role independence and dual approval where required
- Operational dashboards for stuck work, stale projections, reconciliation variance, and integration failures
- Backup, recovery, incident, secret rotation, data retention, and privacy procedures
- Performance, accessibility, abuse, rate-limit, and disaster-recovery validation
- Audit export and independent review

### Decisions required

- Violation taxonomy, evidence standard, notice, action, and appeal policy
- Emergency authority and after-the-fact review
- Data retention, privacy, redaction, and deletion policy
- Availability and recovery objectives
- Production support ownership and escalation

### Exit criteria

- Allegations and findings are distinguishable in data and permissions.
- An enforcement effect and its domain state changes commit atomically.
- Appeal outcomes are authorized, historical, and reproducible.
- Restore and secret-rotation procedures are exercised successfully.
- Launch threat model and permission review have no unaccepted critical findings.

## 11. Cross-cutting work in every slice

Each slice includes:

- Product-owner decision review
- Data classification and threat-model update
- Migration with rollback/forward-fix notes
- RLS and secure-function review
- Business-rule, permission, concurrency, and idempotency tests proportional to risk
- Audit and outbox behavior
- Observability and safe error contracts
- Accessibility and responsive behavior for affected UI
- Documentation updates
- Seed fixtures with no real credentials or sensitive user data

## 12. Suggested GitHub epics

- `EPIC: Platform policy and architecture`
- `EPIC: Catalogue foundation`
- `EPIC: Staff catalogue management`
- `EPIC: Parties, dealers, and regional factors`
- `EPIC: Licensing and endorsements`
- `EPIC: Dealer wholesale ordering`
- `EPIC: Inventory ledger and reservations`
- `EPIC: Transfers and consignment`
- `EPIC: Restricted and unique asset registry`
- `EPIC: Discord integration`
- `EPIC: Google Sheets exports`
- `EPIC: Compliance and appeals`
- `EPIC: Security and operational readiness`

Every implementation issue should identify:

- User outcome and non-goals
- Policy decisions it depends on
- Authoritative function and transaction boundary
- Tables/views/functions and migration impact
- Permission and data-exposure impact
- Audit and integration events
- Acceptance tests
- Rollout or data-migration risk

## 13. Release gates

### Before any public beta

- Public projection reviewed for privacy and enumeration risk
- Rate limiting and abuse monitoring in place
- No direct anonymous table access
- Catalogue import exceptions resolved or explicitly excluded
- Backup and restore confirmed for the environment

### Before dealer beta

- Representative enrollment and revocation tested
- Cross-dealer isolation tests passing
- Secure-link/token handling reviewed
- Order and price snapshots reproducible
- Support and account-recovery path defined

### Before warehouse use

- Concurrency and idempotency tests passing
- Reversal and reconciliation procedure rehearsed
- No direct stock-overwrite path
- Warehouse scopes and high-risk adjustment approvals confirmed
- Migration and restore tested with representative ledger volume

### Before integrations become public

- Outbox retries and deduplication proven
- Destination and field allowlists approved
- Stale data and generated-at behavior visible
- Secret rotation and channel/Sheet ownership documented
- Integration principal cannot access unrelated tables or functions

### Before production launch

- Permission matrix approved
- Threat model and privacy review complete
- Critical policy decisions resolved
- Incident, backup, restore, and secret-rotation exercises complete
- Audit retention and compliance evidence policy approved
- No open critical or high-severity security defects without explicit owner acceptance

## 14. Deferred capabilities

These may be useful later but are not assumed in the core roadmap:

- Full accounting or payment processing
- Auctions, competitive bids, and political allocation rounds
- Advanced analytics and forecasting
- Multiple languages or non-standard calendars
- External game-server enforcement
- Public application intake for unauthenticated applicants
- Offline warehouse operation
- Native mobile applications
- Federation with other organizations' registries

Each deferred capability must preserve Supabase authority and existing audit invariants if added.

## 15. Key risks and mitigations

| Risk | Early mitigation |
|---|---|
| Policy encoded before it is agreed | Maintain a decision register and gate dependent issues |
| Duplicated catalogues return through exports | One canonical item model; projections only |
| Overselling under concurrency | Atomic reservation functions and race tests |
| Staff receive overly broad access | Composable scoped roles, RLS, negative permission tests |
| Unique goods lose traceability | Serialized assets and custody events before unique fulfillment |
| Spreadsheet becomes de facto source | One-way exports, visible timestamps, no import path |
| Discord becomes approval system | Secure function boundary and purpose-limited bot scopes |
| Historical corrections destroy evidence | Append-only ledger/events and linked reversals |
| Configurable rules become unsafe code | Constrained rule model, versioning, deterministic precedence |
| Empty or ambiguous legacy values become policy | Staging, exception reports, owner decisions |
| Large initial scope delays useful release | Vertical slices with explicit exclusions and exit criteria |

## 16. Assumptions

- The first usable release is the public catalogue, not a complete enterprise platform.
- One repository is sufficient for the portal, staff console, Discord service, shared packages, and Supabase assets initially.
- The product owner is available to resolve policy gates between slices.
- Legacy workbook data is useful input but not an architectural specification.
- Integrations can wait until the core workflows are stable.

## 17. Unresolved delivery decisions

- Target hosting and frontend framework
- Monorepo tooling and package manager
- Supabase local-development and environment-promotion process
- CI provider requirements beyond GitHub Actions defaults
- Beta participants, production launch criteria, and operational owner
- Whether catalogue import precedes or follows staff management UI
- Which compliance and finance capabilities are required for first production use
- Accessibility target and supported browser/device matrix
- Expected data volume, peak concurrency, and performance objectives
- Recovery point, recovery time, availability, and maintenance-window objectives

The roadmap should be revised after each approved policy decision and completed slice; it is not a fixed feature promise.

