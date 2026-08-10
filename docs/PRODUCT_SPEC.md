# EEC Trade Registry — Product Specification

Status: Implementation in progress under the approved operating baseline in ADR 0005
Audience: Product owner, operations leads, designers, engineers, and reviewers  
Authority: This document describes intended product behavior. Supabase PostgreSQL remains the sole authoritative data source at runtime.

## 1. Purpose

The EEC Trade Registry is a configurable platform for administering a trading institution's public catalogue, licenses, authorized dealers, wholesale and consignment distribution, warehouse inventory, scarce goods, and compliance activity.

The platform must feel like one coherent institution to the public, dealers, regional factors, and staff while maintaining a precise, auditable record underneath. It replaces duplicated catalogues and informal spreadsheets with one master catalogue and policy-driven access, pricing, allocation, and custody rules.

Implementation proceeds through the policy-gated vertical slices in `ROADMAP.md`. The documentation remains the governing product boundary rather than a promise that every described domain is already implemented.

## 2. Product principles

1. **One authoritative record.** Supabase PostgreSQL is the only source of truth. Websites, Google Sheets, Discord, certificates, invoices, and other exports are projections.
2. **Rules are enforced centrally.** Inventory, license eligibility, quotas, reservations, price overrides, and transfers are decided by database functions or secure server functions, never independently by a client.
3. **Scarcity is auditable.** Fungible stock is ledger-derived; individually controlled goods have serialized identities and custody histories.
4. **Licenses are living relationships.** A license records authority, endorsements, jurisdiction, dates, conditions, and standing. It is not merely access to a price list.
5. **Policy is configurable.** Domain labels, license classes, endorsements, item categories, control profiles, jurisdictions, price schedules, quotas, number formats, and notification templates must be data or configuration where practical.
6. **Public access is deliberately narrow.** Public catalogue and verification features require no login, but expose only approved projection fields.
7. **Routine work is fast; exceptional work is explicit.** Ordinary transactions should be simple. Restricted or unique goods introduce review, approval, and custody controls in proportion to risk.
8. **History is preserved.** Consequential actions are attributable and corrections use reversing or superseding records instead of destructive edits.

## 3. Users and actors

### 3.1 Public visitor

A person who can browse the public catalogue and verify a public license or dealer record without authenticating.

### 3.2 Dealer representative

A person acting for an authorized dealer or institution. They may receive a secure private link or lightweight credentials to view applicable catalogue terms, submit requisitions, and track their organization's records.

### 3.3 Regional factor

An appointed representative who operates within an assigned region or portfolio. A factor may assist dealers, review or sponsor activity, coordinate transfers, and receive alerts. Exact powers are policy-controlled rather than implied by the title.

### 3.4 Staff member

An authenticated operator with one or more scoped roles, such as catalogue, licensing, order, warehouse, compliance, finance, administration, or audit.

### 3.5 Integration principal

A narrowly scoped service identity used for approved exports, notifications, or lookup commands. It cannot bypass business functions or maintain independent business state.

## 4. Product surfaces

### 4.1 Public portal

No login is required. The portal provides:

- A searchable, filterable catalogue of publicly visible goods
- Public price and availability language approved for disclosure
- Plain-language control and purchasing requirements
- License verification by public reference
- Dealer verification by public reference or approved search fields
- A clear distinction between valid, suspended, revoked, expired, and unrecognized records
- Privacy-safe error responses that do not reveal private records or internal notes

The public portal must not reveal private prices, exact stock unless explicitly allowed, internal risk classifications, private contacts, order history, investigations, staff notes, authentication data, or unpublished goods.

### 4.2 Dealer portal

Dealer access is private but intentionally lightweight. Depending on the final identity policy, access may use Supabase Auth credentials, emailed magic links, or a secure access-grant exchange that creates a short-lived session.

Authorized dealer representatives can:

- View their organization, licenses, endorsements, conditions, and standing
- View catalogue eligibility and applicable quoted or schedule-based prices
- View remaining allocation or quota information when policy permits
- Create and submit wholesale, institutional, or consignment requisitions
- View order, reservation, collection, shipment, and transfer status
- Confirm receipt or collection when required
- Request renewal, an endorsement change, or a special transaction approval
- Download approved documents generated from authoritative records

A dealer cannot edit authoritative eligibility, pricing, stock, quota, license, compliance, or custody state.

The approved intermediated ordering model also permits a specifically authorized EEC staff agent to enter the same requisition on behalf of a verified licensed business. The licensed business remains the ordering party; the public customer is not converted into an EEC wholesale account. Dealer self-service and staff-assisted entry must share the same authoritative validation and downstream order workflow. ADR 0017 records this decision; the staff-assisted entry command and screen are not yet implemented.

### 4.3 Staff console

Authenticated staff receive a role-appropriate work queue rather than unrestricted table access. The console supports:

- Catalogue, price schedule, control profile, and publication management
- Party, dealer, representative, and factor administration
- Application review and license issuance, renewal, suspension, and revocation
- Endorsement and condition management
- Order review, exceptions, reservations, fulfillment, and cancellation
- Warehouse receipts, adjustments, transfers, reconciliations, and losses
- Consignment issue, return, settlement, and discrepancy processing
- Unique asset registration, custody transfer, and inspection history
- Compliance cases, inspections, violations, actions, and appeals
- Audit review, export monitoring, integration delivery monitoring, and operational reporting

High-risk actions may require a reason, elevated role, or second approval according to policy.

### 4.4 Google Sheets projection

One or more public Google Sheets may present approved catalogue or registry data. Exports are one-way projections from Supabase:

- The export job reads an approved database view or function.
- A stable projection identifier and export timestamp are included.
- Failed exports are retried and recorded.
- Editing a Sheet never changes authoritative data.
- A Sheet must communicate its generated-at time so stale data is recognizable.

### 4.5 Discord integration

Discord supports notifications and privacy-aware lookups, not primary administration. Candidate capabilities include:

- Public catalogue, dealer, and license lookup commands
- Private dealer order or license status lookups after identity binding
- Staff alerts for review queues, low stock, expiring reservations, and compliance events
- Approved public notices for license issuance or changes
- Order, collection, shipment, and transfer notifications

Every response is produced from an authoritative query at request time or from a recorded integration event. Discord messages and reactions never constitute approval or state change unless a secure, authenticated command calls the same authoritative business function as the staff console.

## 5. Functional scope

### 5.1 Master catalogue

The system maintains one item definition per sellable or controlled item type. Catalogue behavior includes:

- Stable item codes and editable display names
- Configurable categories, tags, descriptions, images, and display order
- Publication state independent of stock state
- Price schedules and effective-dated price history
- Public and private presentation rules
- Bulk minimums and order increments
- Required license classes or endorsements
- Configurable control profiles
- Links to fungible inventory or serialized assets

Separate catalogues for each dealer type must not duplicate item records. Eligibility and price are projections of rules applied to the master catalogue.

### 5.2 Parties, dealers, and factors

People and organizations are represented as parties. Dealer authorization is an explicit, effective-dated relationship rather than a free-text flag. The system supports:

- Individual and organization parties
- Representatives acting for an organization
- Dealer status, territory, approved premises, and public verification identity
- Regional factor assignments by jurisdiction, portfolio, or date range
- Contact information with explicit visibility classifications
- Internal standing or risk classifications that are never public by default
- Relationship history so changes in representation or sponsorship remain traceable

### 5.3 Licensing and endorsements

Licenses have a configurable class and may contain zero or more modular endorsements. A license includes:

- Permanent internal identifier and public verification reference
- Holder and, where applicable, licensed organization or premises
- License class, jurisdiction, issue date, effective date, and expiration date
- Status and status history
- Endorsements with their own dates, status, limits, and conditions
- License-wide conditions and restrictions
- Issuing and approving actors
- Public disclosure fields separated from private notes

Applications for new licenses, renewals, endorsement changes, and reinstatement are review records. Pending applications are not licenses. Time-based labels such as "expiring soon" are derived rather than stored as authoritative statuses.

### 5.4 Control profiles

The initial product recognizes three behavioral control patterns, with labels configurable for the deployment:

- **Ordinary:** normal eligibility and stock checks; may be automatically approved within policy.
- **Restricted:** requires specified authorization, quota, staff review, or transfer conditions.
- **Unique:** represents an individually serialized asset and requires transaction-specific approval and custody tracking.

Control behavior must be attached through configuration rather than item-name checks. A policy can also override controls by jurisdiction, license class, endorsement, party, or effective date.

### 5.5 Pricing and commercial terms

The platform supports public prices, wholesale schedules, contract schedules, and explicit overrides. Requirements include:

- Money stored as integer minor units with a configured currency
- Effective-dated price schedules and rules
- A recorded price snapshot and rule provenance on every submitted order line
- Authorized overrides with actor, reason, previous value, new value, and approval where required
- Separate eligibility, licensing, price, and allocation decisions
- No client-side authoritative price calculation

Whether a displayed price is fixed, recommended, inclusive of fees, or subject to negotiation remains a policy decision.

### 5.6 Orders and reservations

An order or requisition records a dealer's requested commercial transaction. It supports multiple lines, requested fulfillment mode, approvals, pricing snapshots, and status history.

Submitting or approving an order must not silently reduce physical stock. An active reservation claims available stock for a defined period. Creating, changing, consuming, releasing, or expiring a reservation is atomic and concurrency-safe.

The platform supports partial approval and fulfillment, back-order or awaiting-stock states, cancellation, denial, expiration, collection, delivery, and transfer confirmation. Exact permitted transitions are defined in `WORKFLOWS.md`.

### 5.7 Warehouse inventory

Inventory is derived from immutable ledger movements, not overwritten balances. The system supports:

- Multiple warehouses and sublocations
- Receipts, issues, transfers, returns, losses, damage, reconciliation adjustments, and reversals
- Separate physical on-hand, active reservations, and calculated available quantities
- In-transit custody for dispatched transfers
- Source documents and responsible actors
- Atomic posting and idempotency protection
- Reconciliation without deleting or rewriting prior movements

Negative availability or negative physical stock is forbidden unless a narrowly defined policy and elevated operation explicitly permit it.

### 5.8 Wholesale and consignment distribution

Wholesale transfers title and custody according to the selected commercial policy. Consignment retains the configured owner while custody moves to the dealer or factor. The platform records:

- Agreement and fulfillment mode
- Shipped, received, sold-through, returned, lost, damaged, and reconciled quantities
- Custodian and owner separately
- Settlement terms and reporting cycles
- Exceptions and discrepancies

Consignment inventory must never be represented as an untracked decrement from EEC stock.

Implementation status: staff can create effective-dated agreements for an active warehouse owner and currently authorized dealer, then issue fungible available stock into a `consigned` custody account while retaining the configured owner. Dealers with current representation can view only their parties' custody positions and submit observations. Reports are non-authoritative claims until staff accept them; acceptance requires exact reconciliation, posts balanced sale/return ledger entries, and closes an issue only at zero outstanding custody. Loss or damage is recorded but ordinary acceptance is blocked pending an approved exception policy. Pricing, settlement amounts, reporting cadence, shrinkage tolerance, and serialized consignment are not inferred.

### 5.9 Unique assets

Individually controlled goods receive stable asset identifiers. Each asset has an immutable event history covering registration, custody, condition, inspection, authorization, transfer, loss, seizure, retirement, or destruction as applicable.

The current custodian, location, and condition are derived from accepted events or maintained as transactionally consistent projections. A unique asset cannot simultaneously have two current custodians or satisfy two active reservations.

### 5.10 Compliance

The compliance module supports inspections, cases, alleged violations, findings, enforcement actions, appeals, and resolution. Internal evidence and risk information are private. Consequential actions can affect a license, endorsement, dealer authorization, quota, order, reservation, or asset only through recorded workflows.

The platform must distinguish allegations from findings and temporary restrictions from final actions. Retention, notice, appeal, and automatic-restoration policies are unresolved.

Implementation status: authorized compliance staff can open and assign private cases, plan and complete inspections, record immutable allegations and restricted evidence metadata, record explicit substantiated/not-substantiated/inconclusive findings, review configured record-only action recommendations, and record appeals and their outcomes. The current seeded taxonomy is deliberately generic and configurable. Action approval and appeal disposition always retain `effect_applied = false`; no command silently changes another domain. Evidence files, public notices, enforcement effects, deadlines, independence requirements, automatic stays/restoration, and retention remain gated.

### 5.11 Audit and history

Every consequential staff or service action records:

- Actor and authentication context
- Action type
- Affected record type and identifier
- Previous and new state, with sensitive-field redaction where required
- Timestamp
- Optional or required reason
- Request or correlation identifier

Audit records are append-only and queryable by authorized auditors. Business history tables and the audit log complement each other: domain events explain the process; audit entries explain who changed what.

## 6. Authoritative calculations and decisions

The following must execute through database functions or secure server functions with transactions, authorization, and audit behavior:

- Catalogue eligibility for private views
- License and endorsement eligibility
- Price selection and price override authorization
- Quota availability, holds, consumption, release, and reset behavior
- Order submission, approval, denial, cancellation, and line changes after submission
- Reservation creation, extension, consumption, release, and expiration
- Inventory posting, reversal, transfer, receipt, and adjustment
- Unique-asset allocation and custody transfer
- License issuance, renewal, suspension, reinstatement, revocation, and endorsement changes
- Consequential compliance actions

Frontend code may display estimates for usability only when clearly labeled and revalidated authoritatively on submission.

## 7. Experience requirements

- A public visitor can browse without an account.
- A verification lookup returns a clear result without exposing whether a private, unpublished record exists.
- A dealer sees why an item is unavailable or requires review in policy-safe language.
- An ordinary staff order can be processed in approximately one minute once required data is present.
- Work queues identify ownership, age, blocking reason, and next permitted actions.
- The interface never presents raw Booleans, enum codes, or database identifiers when plain language is appropriate.
- Dates, currency labels, organizational titles, and setting-specific vocabulary are configuration-driven.
- Accessibility, mobile behavior, and localization expectations must be defined before interface implementation.

## 8. Security and privacy requirements

- Staff authenticate through Supabase Auth using Discord OAuth and the server-side PKCE callback flow approved in ADR 0009. The staff portal exposes no email/password form.
- Discord authentication never grants staff authority by itself; active actor and permission assignments in PostgreSQL remain mandatory.
- Staff authorization is enforced in PostgreSQL row-level security and secure functions, not only hidden UI controls.
- Dealer sessions are scoped to represented parties and expire or can be revoked.
- Raw private-link tokens are never stored; only strong token digests and metadata are retained.
- Private links are single-use or short-lived and are exchanged for a scoped session where practical.
- Supabase service-role keys, Discord tokens or webhook URLs, Google credentials, and private status tokens remain server-side and are never committed.
- Public data is served from explicit public views or security-definer functions with fixed search paths and minimal grants.
- Sensitive logs and audit snapshots follow a documented redaction and retention policy.
- Rate limiting, abuse monitoring, and non-enumerable verification references are required before public launch.

## 9. Operational requirements

- All schema changes use versioned migrations.
- Business functions are transactional, idempotent where calls may retry, and safe under concurrent requests.
- Integration delivery uses an outbox or equivalent durable event pattern.
- Failed projections do not roll back an already committed business transaction.
- Export and notification delivery state is observable and retryable.
- Backups, point-in-time recovery, migration rollback strategy, and incident procedures are launch prerequisites.
- Staff authority must be administered through audited effective-dated commands; the system must prevent removal of the final active platform administrator.
- Operational health views may identify stale or failed work but must not silently correct or mutate authoritative business state.
- Time is stored in UTC. A configured institutional time zone and calendar presentation determine display and policy cutoffs.
- Generated references are unique and immutable; human-friendly formats are configurable.

## 10. Success measures

Initial measures, subject to product-owner approval:

- No unexplained divergence between ledger-derived stock and counted stock after a completed reconciliation
- No successful order that bypasses required license, endorsement, quota, or unique-asset approval rules
- Every consequential staff action traceable to an actor and request
- Routine order processing median under one minute, excluding policy review or waiting time
- Public and dealer projections display their freshness and do not become independent state
- Integration retries do not create duplicate messages, exports, reservations, ledger entries, or custody events
- Staff can reconstruct the full history of a license, order, stock movement, or unique asset without consulting Discord or Sheets

## 11. Out of scope for the initial platform

- A general-purpose retail point-of-sale system
- Full accounting, banking, payroll, or tax ledgers
- Discord or Google Sheets as an administrative database
- Automatic gameplay enforcement outside supported integrations
- Hard-coded lore, calendar names, currency names, jurisdictions, ranks, or commodity taxonomies
- Automated policy judgments that have not been approved by the product owner
- A marketplace where dealers transact independently of EEC-controlled workflows

## 12. Assumptions

These are working assumptions for design, not final institutional policy:

1. One deployment may serve multiple regions, warehouses, and dealer organizations.
2. Public catalogue visibility does not imply purchase eligibility or current physical availability.
3. Dealer representatives can act for one or more organizations, and authorization is effective-dated.
4. License class, endorsements, conditions, pricing, quotas, and control level are independent concepts.
5. A unique good is represented by a serialized asset with quantity one.
6. Reservations expire unless extended through an authorized operation.
7. Consignment separates ownership from custody and requires periodic reporting or reconciliation.
8. Public Sheets and Discord may lag briefly and will show a generated-at time when feasible.
9. Existing spreadsheet data will be imported only after validation, normalization, and explicit field mapping.
10. Historical corrections use reversals or superseding records rather than destructive edits.

## 12.1 Approved operating baseline

The product owner approved the following initial deployment policy on 2026-08-04. ADR 0005 is the durable decision record.

- East Empire Company is the configured public institution name. Timestamps are stored in UTC and displayed in `America/New_York`; the zero-decimal `SEP` currency is displayed as Septims.
- The initial license catalogue uses three configurable classes—general trade, commercial dealer, and institutional trade—and modular configurable endorsements.
- Authorization follows active permissions and scope. There is no universal second-approver requirement.
- Dealer authentication begins with individual password credentials through Supabase Auth.
- Staff authentication begins with individual Discord OAuth identities through Supabase Auth. Provider identity and database business authorization remain separate.
- Prices are editable but may be unset. An unset price is pending/unavailable, not zero.
- Ordinary, restricted, and unique are the initial configurable control behaviors; restricted and unique paths require stronger review in line with ADR 0005.
- Partial approval and fulfillment are supported. Orders may be submitted without stock and may wait for stock.
- Public customers normally obtain goods through a currently authorized and appropriately licensed business. A verified business representative may submit, or an explicitly authorized EEC agent may enter the requisition on behalf of that business. The business remains the EEC ordering party and staff never impersonate it. ADR 0017 defines the assisted-entry boundary.
- Stock cannot be posted below zero. Reservations default to 48 hours once created and may be extended by an authorized actor with a reason.
- Wholesale title transfers at confirmed collection or receipt. Consigned stock remains EEC-owned until an accepted sale or settlement event.
- Public verification remains exact-reference-only with the existing field allowlists.
- Public Sheets target a 15-minute one-way refresh. Discord begins with public catalogue/dealer/license lookups and private staff alerts; neither integration mutates business state.

## 13. Unresolved policy decisions

The product owner must resolve these before the affected feature is implemented:

### Licensing and identity

- Exact holder eligibility, class-specific authority, and whether additional classes are required
- Exact endorsement prerequisites, inheritance, exclusivity, and jurisdiction-specific behavior beyond the approved modular baseline
- Required identity assurance for public applicants, dealers, representatives, and factors
- License duration, renewal windows, grace periods, provisional authority, and expiration behavior
- Whether any future public search should extend beyond the approved exact-reference-only behavior
- Any future changes to the approved public verification field allowlists

### Goods and allocation

- Which goods require a license, endorsement, quota, special approval, or serialized tracking
- Whether exact stock, coarse availability, or no availability is public
- Quota subject, measurement period, reset boundary, carryover, reservation treatment, and exception authority
- Circulation ceilings and whether they count stock, custody, reservations, sales, losses, or all of the above
- Allocation priority when demand exceeds supply

### Commercial rules

- Price schedule audience/precedence and whether configured prices are fixed, recommended, or negotiable
- Fees, taxes, deposits, credit limits, and exceptional rounding behavior beyond the approved zero-decimal currency
- Consignment settlement, reporting, commission, loss, and return terms beyond the approved ownership rule
- Whether final-customer reporting is required for any dealer sale
- Refunds, uncollected-order consequences, and reservation-extension limits beyond the approved partial/cancellation baseline

### Authority and compliance

- Final staff role bundles, regional factor powers, approval limits, and any action-specific segregation-of-duties requirements
- Which actions require an emergency override or action-specific second approval
- Inspection authority, violation taxonomy, evidence standard, sanctions, automatic effects, and appeal process
- Retention and public-disclosure rules for expired, revoked, appealed, or corrected records
- Emergency suspension, seizure, reconciliation adjustment, and negative-stock policy

### Operations and integrations

- Locale, calendar presentation, and reporting cutoff rules beyond the approved time zone
- Public Sheet contents, destinations, ownership, and stale-data wording beyond the approved cadence
- Discord server, channels, identity binding, notification templates, and retention beyond the approved initial commands/alerts
- Document formats, seals, signatures, numbering schemes, and which generated documents have official effect
- Availability, recovery, audit-retention, privacy, and incident-response targets

Until these decisions are recorded, implementations must preserve configurability and must not silently promote an assumption into policy.

