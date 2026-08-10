# EEC Trade Registry — Workflows and State Transitions

Status: Governing workflows with the operating baseline in ADR 0005 approved
Purpose: Define user journeys, authoritative transitions, failure behavior, and audit expectations without prescribing an application implementation.

## 1. Workflow rules

All consequential workflows follow these rules:

1. The client requests an action; it does not write the authoritative result directly.
2. A database function or secure server function authenticates the actor, resolves scope, revalidates current state, and applies policy.
3. Coupled changes commit atomically. License, quota, reservation, inventory, custody, history, audit, and outbox records must not partially succeed.
4. Each retriable command accepts an idempotency key or otherwise prevents duplicate execution.
5. A state transition requires an allowed source state, permitted actor, required inputs, and any prerequisite approvals.
6. Terminal or posted history is corrected through explicit reversal, reopening, or supersession—not direct rewriting.
7. Notifications and exports occur after commit through durable outbox processing. Delivery failure does not roll back business state.
8. Display labels may be configured, but stable machine states and their transition semantics must remain testable.

## 2. Public catalogue browsing

### Goal

Let any visitor discover publicly offered goods without authentication while preventing disclosure of private stock, prices, eligibility, or internal records.

### Flow

1. Visitor opens the catalogue.
2. Portal queries an explicit public catalogue view or public function.
3. Visitor filters by configured category, tags, public control label, price range, or availability language.
4. Portal displays public item details, public price if any, purchasing requirements, and generated-at time where applicable.
5. If the visitor follows a purchase path, the portal explains whether dealer access, a license, an endorsement, or special review may be required.

### Rules

- Public visibility is effective-dated and independent of physical stock.
- Public price is not a substitute for an order price snapshot.
- Availability language is a configured projection such as available, limited, by request, or unavailable. Exact stock is withheld unless policy allows it.
- Unpublished and internal-only items must be indistinguishable from nonexistent items to unauthorized users.
- The portal must not calculate private eligibility or price without an authenticated context.

### Failure behavior

- A projection failure shows a safe temporary-unavailability response; it does not fall back to Google Sheets.
- A stale projection displays its age and must not claim current stock.

## 2.1 Staff canonical catalogue management

### Goal

Let specifically assigned catalogue staff maintain canonical item source records without granting table access or inventing unresolved publication and pricing policy.

### Flow

1. Staff selects **Continue with Discord**. Supabase Auth initiates Discord OAuth and returns the browser to the portal's fixed allowlisted callback.
2. The server exchanges the one-time PKCE authorization code for a cookie session. The portal accepts no caller-controlled post-login destination.
3. Each database request independently validates the Supabase session and resolves an active actor profile, effective-dated role assignment, and required permission. A Discord-authenticated user without assignments receives no staff data or business authority.
4. The internal work queue is returned by a secured projection and includes staff-only catalogue fields needed for this task.
5. Creating an item calls a secure command that creates one unpublished canonical record. It does not create publication, price, eligibility, inventory, or asset state.
6. Editing an item supplies the expected record version. The command locks and rechecks the row so stale work cannot overwrite a concurrent change.
7. Item code and public slug remain immutable after creation until a correction policy is approved.
8. Archive and restore are explicit status commands with a mandatory reason. Archiving removes the item from current public projections without deleting publication, price, or audit history.
9. Every accepted write records actor, authentication identity, permission and assignment, request/correlation ID, reason, previous state, new state, source surface, and timestamp.

### Failure behavior

- Authentication without an active catalogue assignment fails closed.
- Direct authenticated table reads and writes remain denied.
- Invalid references, missing reasons, duplicate stable identifiers, and stale record versions reject the whole transaction.
- The client displays stable safe errors and never retries a stale write with a new version automatically.
- If Supabase is unavailable or unconfigured, the staff surface has no Sheets, browser-storage, or static-data fallback.

### Deliberate exclusions

- Backdated or scheduled publication; effective-now public creation, replacement, and withdrawal are implemented in Quick operations
- Specialized private/dealer price precedence and approval; explicit active-schedule public price set/clear is implemented
- Item-code or slug corrections
- Existing reference-record rename/archive and role administration; new category, unit, availability, license-class, endorsement, and control-profile creation is implemented
- Recovery, MFA, and step-up policy beyond the approved Discord OAuth provider

## 2.2 Rapid item onboarding and ordinary receipt

### Quick item flow

1. Authorized staff opens **Quick operations** and enters an item name, category, unit, and supply workflow.
2. The server validates the form but does not calculate business authority.
3. One database command re-resolves catalogue and supply-policy permissions, creates a stable code and slug when omitted, and creates the canonical item plus supply policy.
4. If selected, the same transaction re-resolves publication permission and creates the current public presentation.
5. If a price is supplied, the command re-resolves pricing permission and stores it only on the explicitly selected configured schedule. Blank remains unset, never zero.
6. If permitted opening quantity is supplied, the command re-resolves warehouse scope and posts the same balanced receipt used by the detailed Inventory desk.
7. Audit, idempotency receipt, and outbox event commit with the item. Any failure rolls back every selected effect.

### Three-field receipt flow

1. Staff searches by stable item code or display name, enters a positive quantity, and selects a receiving location.
2. Optional source and audit text may be omitted; traceable request-based defaults are generated.
3. Supabase resolves the item by code and rejects archived, serialized, player-sourced-only, or generic-receipt-disabled items.
4. The existing warehouse-scoped receipt function creates the external-source and physical entries atomically.
5. Retrying the request UUID returns the existing transaction rather than adding stock twice.

The approximately 30-second target applies to prepared ordinary work. Player-sourced delivery, restricted review, unique custody, reversals, and reconciliation retain their additional evidence and permission steps.

## 3. Public license and dealer verification

### Goal

Let a public visitor confirm whether a supplied public reference identifies an authorized license or dealer, while preserving privacy.

### Flow

1. Visitor enters a license or dealer public reference.
2. Portal normalizes case and whitespace without imposing a deployment-specific numbering format. The deployment edge must apply approved rate limiting before production use.
3. A public verification function returns one fixed response contract.
4. The result shows only approved fields: reference, public holder or organization name, class/type, public endorsements, jurisdiction, validity, expiration where allowed, and public conditions or notices.
5. The result includes verification time and a non-authoritative explanation of status.

### Result categories

- `valid`
- `provisional` if publicly recognized
- `suspended`
- `revoked`
- `expired`
- `not_verifiable`

`not_verifiable` covers nonexistent, private, malformed, or non-public records when policy requires non-enumeration.

Implementation note: the initial function always returns one row. A miss contains the result code and verification time but no stored reference or record fields. Public labels and status-to-result mappings are configuration records. An elapsed authorization or license term cannot report current authority even if its stored status has not yet been advanced by a scheduled process.

### Rules

- Search by holder name or organization is disabled unless explicitly approved.
- Internal notes, application answers, risk standing, orders, investigations, private contacts, and staff identities are never public.
- Verification does not create or change license state.
- Public references are not login secrets.

## 4. Dealer access

### Goal

Provide low-friction access scoped to the correct dealer organization and representative.

### Credential path

1. Staff or an approved enrollment function creates a representative relationship.
2. Dealer representative enrolls with a lightweight Supabase Auth credential or approved identity provider.
3. Successful authentication creates a session.
4. Each request resolves active representative grants and allowed scopes.

Implementation note: the initial credential path uses Supabase Auth email/password sessions and recognizes only the policy-neutral `portal.read` scope. The private overview is read-only, requires a current representative grant and a currently authority-conferring dealer authorization, and returns only organizations linked to the authenticated dealer actor. Enrollment and credential recovery are not public portal operations.

### Secure-link path

1. Authorized staff or workflow creates a short-lived access grant containing a strong random token.
2. Only the token digest, intended party, scope, expiration, issuer, and usage metadata are stored.
3. The token is delivered through an approved channel.
4. The representative opens the link; the server validates digest, expiration, revocation, and usage policy.
5. The token is exchanged for a short-lived scoped session and marked used when single-use policy applies.
6. The browser removes the raw token from the visible URL and history where practical.

### Rules

- A link never encodes a party identifier as its only proof of access.
- A representative switching organizations must select an active represented party; permissions are recalculated.
- Expired, revoked, or out-of-scope grants fail closed.
- Sensitive actions may require credential reauthentication even if catalogue viewing was allowed by link.

## 5. License application and issuance

### Application states

```text
draft -> submitted -> under_review -> awaiting_information -> under_review
                              \-> approved -> issued
                              \-> denied
submitted / under_review / awaiting_information -> withdrawn
```

`approved` is a decision state. `issued` means the license record and all approved endorsements were created successfully. A license is never inferred from an approved application alone.

### Applicant flow

1. Applicant or staff starts an application of a configured type.
2. Form questions are rendered from a versioned definition appropriate to license class, jurisdiction, and request type.
3. Applicant saves a draft.
4. On submit, an authoritative function validates required answers, representative authority, duplicates, and policy prerequisites.
5. The application becomes `submitted`, receives a public reference, and enters the staff queue.
6. Applicant may supply requested information or withdraw while policy permits.

### Staff review flow

1. A licensing officer claims or is assigned the application.
2. The officer reviews submitted answers, dealer authorization, existing licenses, standing, debts if relevant, prior actions, and requested endorsements.
3. The officer may request information, record an interview, add a recommendation, approve with conditions, deny, or escalate.
4. Required secondary approvals are collected according to the approval policy.
5. The decision function validates actor authority and current application state.

### Issuance transaction

One authoritative issuance command:

1. Locks the approved application.
2. Revalidates approval, applicant, dealer, dates, policy version, and non-duplication rules.
3. Allocates an immutable public license reference.
4. Creates the license, endorsements, and structured conditions.
5. Creates initial license status events.
6. Marks the application `issued`.
7. Writes audit entries.
8. Writes outbox events for documents and notifications.
9. Commits or rolls back as a unit.

Implementation note: the first staff lifecycle increment implements direct staff issuance to an existing active party, transactional reference allocation, initial endorsements, status history, audit, and outbox work. The UI leaves the term open because duration policy is unresolved. Application approval and issuance-from-application remain distinct future work and cannot be inferred from this direct staff path.

### License states

```text
provisional -> active -> suspended -> active
     |           |          |          |
     |           |          +-------> revoked
     |           +------------------> revoked
     |           +------------------> surrendered
     +------------------------------> revoked / expired
active / suspended / provisional ---> expired (time policy or scheduled transition)
```

Exact allowed paths, grace behavior, and whether expiration is stored by a scheduled transition or derived are policy decisions. `expiring soon` is always derived.

### Renewal

1. Authorized party opens a renewal application tied to the existing license.
2. The system snapshots current endorsements and conditions as renewal inputs.
3. Review considers compliance, standing, outstanding obligations, and updated policy.
4. Approval either extends/supersedes the license term or issues a successor record, according to the chosen historical model.
5. Changes in class, endorsements, or conditions are explicit and auditable.

### Suspension, reinstatement, revocation, and surrender

- Suspension and revocation require authority, reason, effective time, and any required compliance action.
- The transaction invalidates or blocks affected new orders and evaluates existing reservations according to policy.
- It does not silently delete orders, reservations, or custody history.
- Reinstatement is an explicit transition with its own authority and reason.
- Surrender is holder-initiated only if policy permits and may be blocked by outstanding custody or compliance obligations.

Implementation note: authorized staff can now activate a provisional license, suspend, reinstate, revoke, or record surrender through version-checked secure functions. Revoked and surrendered states are terminal. Every command requires its own permission and reason; there is no universal second-approver requirement.

## 6. Endorsement change

### Flow

1. Holder requests an endorsement through an application, or authorized staff initiates a policy action.
2. Review validates the containing license, prerequisites, exclusivity, jurisdiction, dates, and conditions.
3. Approval grants an effective-dated `license_endorsement` record.
4. Suspension, expiration, or removal creates a status event or closes the effective interval.
5. Existing orders and reservations are re-evaluated only according to explicit policy; no client may assume they remain valid.

### Invariants

- An endorsement cannot outlive or exceed the authority of the containing license unless policy explicitly defines a transition window.
- Removing an endorsement does not erase its history.
- Prose conditions that affect ordering must map to enforceable rule fields.

## 7. Dealer catalogue and price evaluation

### Flow

1. Dealer representative opens the private catalogue under a selected organization context.
2. A secure function resolves active representation, dealer authorization, licenses, endorsements, jurisdiction, standing, current rule versions, and catalogue publication.
3. For each item, it returns policy-safe eligibility, review requirement, price or price-unavailable reason, quota presentation, and availability language.
4. When an item is added to an order, the server re-evaluates the item.
5. On order submission, the server evaluates again and records authoritative snapshots.

### Rules

- Catalogue display is advisory until submission.
- Price, eligibility, quota, and stock are separate outputs with separate explanations.
- The frontend may not infer eligibility by hiding or showing categories.
- A staff override requires an explicit request, authorization, reason, and potentially a second approval.

## 8. Order creation and review

### Order header states

```text
draft -> submitted -> under_review -> approved -> processing -> fulfilled
                   |       |             |            |
                   |       +-> awaiting_information   +-> partially_fulfilled
                   |       +-> awaiting_stock          +-> cancelled/expired by policy
                   |       +-> denied
                   +-> cancelled
```

Header state may be derived from line states when mixed outcomes are supported. Implementation must avoid contradictory header and line states.

### Order line states

```text
draft -> submitted -> review_required -> approved -> reserved -> ready -> fulfilled
                   \-> awaiting_stock ----^          |
                   \-> denied                         +-> partially_fulfilled
submitted / approved / reserved -> cancelled or expired, subject to release rules
```

Final machine state names will be fixed before migrations. User-facing wording remains configurable.

### Dealer submission flow

1. Dealer creates a draft for a represented organization.
2. Dealer adds items and quantities. The UI displays current estimates.
3. Dealer selects fulfillment mode, destination or collection preference, and supplies required justification.
4. The mature submission command revalidates representative scope, dealer and license standing, item publication, control requirements, price, order increments, quota, circulation ceiling, and policy.
5. The function records price and rule snapshots, determines each line's review path, creates quota holds if policy requires, writes history/audit, and commits.
6. Notifications are queued after commit.

Submission does not create physical inventory movement or a stock reservation. Orders may be submitted when stock is unavailable; the authoritative workflow records an explicit awaiting-stock outcome instead of rejecting the commercial request or posting negative stock.

Implementation note: `dealer_submit_order` currently validates active scoped representation, current dealer authorization, an optional current license, published items, positive quantities, and configured control snapshots. It creates every line as `review_required`, keeps the configured currency and price as a nullable snapshot, allocates an `EEC-ORD` reference from sequence data, and writes audit/history/outbox records atomically. Exact endorsement prerequisites, dealer-specific price schedules, increments, quotas, and circulation rules remain unresolved and therefore are not represented as passed checks.

### Staff-assisted business order flow

1. A public customer asks a licensed business to source an EEC item. The public customer does not become the EEC wholesale ordering party.
2. A verified representative of the business presents the item, quantity, fulfillment preference, and relevant context to an authorized EEC agent through an approved channel.
3. The agent selects the business from a secured staff projection and the command revalidates representative authority, current dealer authorization, relevant license, item publication, control requirements, and current policy.
4. The agent records an on-behalf-of reason and approved request context. The staff actor is the command actor and the licensed business is the ordering party.
5. The command creates the same order, line snapshots, history, audit, and outbox work as dealer submission and enters the normal staff-review queue.
6. No entry action creates a reservation, inventory movement, title transfer, quota consumption, or guaranteed settled price.

Implementation note: ADR 0017 approves this operating model, but the authoritative assisted-entry command and `/staff/orders/new` surface are not yet implemented. Until then, the representative must use the dealer submission flow. Staff must not impersonate the business, borrow dealer credentials, insert rows directly, or treat a Discord message as an order.

### Staff review flow

1. Order queue shows age, dealer, requested mode, blocking reasons, stock position, licensing result, quota result, and required approval level.
2. Authorized staff may approve a quantity, approve with conditions, request information, place in awaiting-stock, deny, or escalate.
3. An override is a distinct object and never hidden inside an edited field.
4. Approval revalidates the current state and rule requirements.
5. Approval may leave the line awaiting stock. A later authorized inventory operation creates a reservation atomically after stock is available.

Implementation note: the current staff command selects the required ordinary, restricted, or unique approval permission from snapshotted control flags. It supports full or partial approval, denial, and awaiting-stock decisions with optimistic order versions. Price may be set or remain explicitly pending. Header status is derived transactionally from all line outcomes; no browser code decides it.

### Cancellation and denial

- Cancelling or denying a line releases active stock reservations and quota holds in the same transaction.
- A fulfilled quantity is never cancelled retroactively; use return, reversal, or dispute workflows.
- Staff and dealer cancellation permissions may differ by state.
- Cancellation and denial reasons follow visibility rules so private compliance information is not exposed.

Implementation note: dealers with `order.cancel` scope and staff with `order.cancel` permission can cancel before reservation, ready, or fulfillment progress. The command is idempotent, versions the order, cancels every eligible line, and appends audit/history/outbox records. Once inventory claims exist, their release must be added to this same transaction before those states become cancellable.

## 9. Stock reservation

### Create reservation

1. Caller supplies order line, requested quantity, stock scope, and idempotency key.
2. Function authenticates authority and locks the relevant item/location availability scope.
3. Function calculates posted on-hand, existing active reservations, applicable quarantine or hold exclusions, and requested quantity.
4. Function verifies order line state, approved quantity, quota/circulation policy, and serialized-asset exclusivity where applicable.
5. Function creates reservation and coupled quota hold records.
6. Function advances the line state, writes history/audit, and emits outbox events.
7. Transaction commits.

### Extend reservation

Requires an authorized actor, reason, and permitted state. The initial term is 48 hours. Extension updates the reservation's expiration with an audit record; maximum cumulative duration remains a configurable policy gate.

Implementation note: `staff_create_reservation` locks the physical inventory account and order line, re-derives ledger on-hand and non-elapsed active claims, enforces approved remaining quantity, and creates a 48-hour claim atomically. Full claims move a line to `reserved`; partial claims remain explicitly `partially_awaiting_stock`. Extension is version-checked and cannot revive an elapsed claim.

### Consume reservation

Consumption occurs only as part of fulfillment, dispatch, or collection. It posts the relevant inventory or custody movement and converts quota hold to consumption in the same transaction.

### Release or expire reservation

1. Function locks the active reservation.
2. Function verifies caller or scheduler authority and current state.
3. Reservation becomes released or expired.
4. Coupled quota hold is released.
5. Order line returns to approved/awaiting-stock or becomes cancelled/expired according to policy.
6. Audit and notification events are recorded.

Implementation note: staff can explicitly release a current claim or finalize an elapsed claim as expired. Either operation updates reservation, line, derived order state, audit, append-only domain history, and outbox records in one transaction. Elapsed active claims no longer reduce availability even before the explicit finalization worker is implemented.

### Concurrency tests required later

- Two orders racing for the final unit
- Retry after ambiguous network timeout
- Expiration racing with fulfillment
- Staff extension racing with scheduled expiration
- Partial consumption followed by cancellation
- Same unique asset requested by two orders

## 10. Warehouse receipt and adjustment

### Receive stock

1. Warehouse operator starts a receipt against a shipment or approved source record.
2. Operator records item, quantity, condition, location, owner, custodian, and source.
3. For serialized goods, each asset is registered or matched individually.
4. A second check is required if policy or control profile demands it.
5. `post_inventory_transaction` creates balanced ledger entries, asset events, history, audit, and outbox events atomically.
6. Available stock projection updates from committed records.

Implementation note: the first receipt command supports fungible items only and posts at the current time into an assigned configured location. It creates or reuses physical and external-source accounts, locks the account scope, writes a balanced two-entry transaction, and emits audit/outbox records. Serialized goods are rejected until the asset registry can record their identities and custody events.

### Correct a receipt

- Unposted drafts may be edited.
- A posted receipt is immutable.
- Correction posts a reversal, then a corrected transaction, both linked to the original and reasoned.

Implementation note: an inventory controller can now post one idempotent linked reversal of a receipt. The command locks the original and affected accounts and is rejected if the reversal would make physical stock negative or consume quantities claimed by effective reservations. A corrected replacement receipt remains a separate command with its own provenance.

### Reconciliation

1. Authorized staff opens a stock count for frozen or defined scope.
2. Counters record observations without seeing expected quantities when blind-count policy applies.
3. The system calculates variance against the ledger as of a cutoff.
4. Staff investigates and classifies discrepancies.
5. Authorized approval posts a reconciliation adjustment; the system never overwrites stock.
6. Restricted or unique discrepancies may automatically open a compliance case.

Negative adjustments, large variances, or unique-asset discrepancies may require second approval.

## 11. Wholesale fulfillment and collection

### Ready for collection

1. All required approvals and active reservations exist.
2. Warehouse staff picks and validates quantities or serialized asset identities.
3. The order is marked ready through an authoritative function.
4. Dealer receives a notification with expiry and collection instructions.

### Collection

1. Staff validates collecting representative authority and any required identity proof.
2. Staff confirms actual quantities/assets, payment or finance prerequisite if applicable, and condition.
3. Dealer or staff records acceptance where required.
4. Fulfillment transaction consumes reservations, posts ledger or asset custody movements, consumes quota, advances line/order status, creates documents, audit entries, and notifications.
5. Partial collection leaves explicit remaining state and adjusted reservations. Wholesale title passes only for the quantity confirmed collected or received.

Implementation note: the fungible completion increment accepts one active, unexpired reservation at a time. A warehouse-scoped command locks the physical account, reservation, order line, and order; marks the reservation consumed; posts a balanced physical-to-external issue; increments fulfilled quantity; derives statuses; appends audit/history; and emits `fulfillment.completed` atomically. An inventory controller may add a linked reversal that restores stock and reopens demand. The consumed reservation remains historical and a replacement claim must be created before another completion.

### Uncollected order

At reservation expiry, the system releases stock and quota holds. The unfulfilled quantity remains explicit and may return to awaiting stock; fees, standing effects, or automatic cancellation remain unresolved policy.

## 12. Transfer between custodians or locations

### Transfer states

```text
draft -> requested -> authorized -> dispatched -> received
                    \-> denied       \-> disputed -> resolved/received/returned
draft/requested/authorized -> cancelled
```

Cancellation after dispatch is not permitted; use return or dispute handling.

### Dispatch

1. Operator verifies transfer authorization, source custody, stock reservation if applicable, destination, and asset/quantity identity.
2. Dispatch function posts movement from source to in-transit custody, records custody events for serialized assets, and advances transfer state.
3. Audit and notifications are queued.

### Receipt

1. Authorized recipient reviews shipment and records quantities, assets, condition, and discrepancies.
2. Receipt function moves accepted stock from in-transit to destination custody.
3. Missing, damaged, or disputed lines remain explicitly in transit or disputed and may open a compliance case.
4. Transfer completes only when all lines have terminal receipt, return, loss, or resolution outcomes.

Implementation note: the initial fungible transfer command supports one item and full quantity per transfer. A warehouse operator requests across two authorized warehouses; an inventory controller explicitly authorizes; dispatch posts source-to-transit ledger entries; and destination receipt posts transit-to-physical entries. Discrepancy recording changes workflow state without fabricating a balance change. Cancellation is limited to requested or authorized state. Every retry is idempotent, every state change is version checked, and all actions append audit/history evidence.

### Unique asset transfer

- Transaction-specific approval is validated at dispatch and receipt.
- The exact asset code is scanned or selected.
- Required custody acceptance is recorded.
- The asset cannot be dispatched from a custodian or location inconsistent with its derived current state.

Implementation note: the initial asset-custody command records a single accepted handoff immediately, with the acting staff member as the recorded acceptor. It preserves ownership, revalidates the current version and absence of an active allocation, validates warehouse-location custody consistency, updates the current projection, appends an immutable event and audit entry, and emits notification work in one transaction. Multi-step dispatch/receipt, external recipient acceptance, transaction-specific approval, and custody correction remain gated rather than inferred.

## 13. Consignment

### Issue consignment

1. Staff selects an active consignment agreement and eligible dealer.
2. Items, quantities/assets, settlement terms, and reporting date are validated.
3. Required stock is reserved and approved.
4. Dispatch transfers custody to the consignee or in-transit account while retaining East Empire Company ownership.
5. Consignment position is derived from ledger and asset events.

Implementation note: the current issue path supports fungible goods from an available physical account. It revalidates the effective agreement, current dealer authorization, retained owner, warehouse scope, and stock remaining after active reservations, then posts a balanced physical-to-consigned custody movement. Serialized consignment, advance reservations, in-transit dealer dispatch, finance, and scheduled reporting are not implied.

### Dealer report

1. Dealer submits sold-through, returned, damaged, lost, and observed-on-hand information.
2. Submission creates a report claim; it does not directly alter inventory.
3. Staff or an automated policy validates the report against previous position and supporting evidence.
4. Acceptance posts authoritative ledger/custody changes and settlement obligations.
5. Variances open an exception and possibly a compliance case.

Implementation note: current dealer submissions require a live scoped representation and permit only one submitted report per issue. Staff ordinary acceptance requires observed-on-hand to equal the prior outstanding balance minus reported sold and returned quantities. Accepted sales move custody to an external account; accepted returns move it to an authorized matching warehouse account. Loss or damage cannot be accepted through this routine path, because the exception and compliance policy is unresolved. Rejection preserves the report and changes no inventory.

### Return or closeout

1. Dealer requests return or agreement closeout.
2. Physical transfer returns remaining stock.
3. Staff reconciles accepted sales, returns, losses, and settlement.
4. Agreement closes only when inventory, custody, disputes, and financial obligations meet policy.

Implementation note: the current agreement command permits suspension, reactivation, and close with optimistic concurrency. Close is blocked while ledger-backed custody is outstanding. Because settlement obligations and disputes are not yet modeled, operators must not treat closure as proof of financial settlement.

## 14. Unique asset lifecycle

### Registration

1. Authorized operator selects the canonical item with serialized inventory mode.
2. System allocates an immutable asset code.
3. Operator records provenance, markings, condition, initial owner, custodian, and location.
4. Required witness or approval is captured.
5. Registration and initial custody event commit atomically.

### Allocation and fulfillment

1. Approved order line requests a specific asset or authorizes staff selection.
2. Function verifies control profile, license, endorsement, quota/circulation, transaction approval, current custody, and active reservations.
3. Exclusive asset reservation is created.
4. Dispatch or collection consumes that reservation and posts custody event.

### Inspection

1. System schedules or staff initiates inspection under configured policy.
2. Inspector records custodian confirmation, condition, location, evidence, and findings.
3. Significant discrepancy opens a case and can trigger an authorized temporary action.
4. Next inspection due date is derived or scheduled.

### Loss, seizure, destruction, or recovery

- Each is a controlled lifecycle event with evidence, authority, and reason.
- A missing asset is not deleted.
- Recovery references the prior loss event.
- Destruction or retirement is terminal unless a formally approved correction reverses an erroneous event.

Implementation note: authorized staff can now register a serialized asset, create one exclusive 48-hour allocation for one approved unique order line, finalize release or elapsed expiry, record accepted custody and inspections, and append missing, recovery, damage, seizure, retirement, and destruction transitions. Terminal assets cannot be reactivated. An allocation never moves custody, and the current increment deliberately does not consume an allocation into order fulfillment until transaction-specific approval and title-transfer policy are approved.

## 15. Compliance case and appeal

### Case states

```text
open -> triage -> investigating -> awaiting_response -> deciding -> resolved -> closed
                  \-> no_action ------------------------------^
closed -> reopened (authorized, reason required)
```

### Flow

1. Staff, workflow, inspection, inventory discrepancy, or validated report opens a case.
2. Triage classifies scope, confidentiality, subjects, urgency, and assignment.
3. Investigator records allegations, evidence, interviews, and observations.
4. Decision-maker records findings separately from allegations.
5. Authorized enforcement actions are approved and applied atomically to affected domains.
6. Required notices are generated from authoritative data.
7. Case is resolved and later closed under retention policy.

### Appeal

1. Eligible party files within the configured window.
2. System validates standing, timeliness, and appealable action.
3. Reviewer must satisfy independence requirements.
4. Appeal may affirm, vary, remand, stay, or reverse an action according to policy.
5. Resulting domain state changes and notices commit atomically.

The system must never equate opening a case with guilt or finding.

Implementation note: the current staff console implements the case graph through secure, version-checked functions. Allegations, evidence metadata, and findings are separate immutable records. The generic taxonomy is configuration, not lore or law. A written resolution is required before `resolved` or `no_action`; a closed case can be reopened only through a reasoned transition that clears the current resolution projection while preserving its prior event.

Staff can record one filed appeal per approved record-only action and record an affirmed, varied, remanded, reversed, or withdrawn disposition. The disposition appends history but deliberately applies no domain change or stay. Filing windows, standing, independence, automatic stays, notices, and restoration remain policy gates.

## 16. Google Sheets export

### Flow

1. Scheduler or authorized staff requests an export definition.
2. Worker claims an outbox event or scheduled job using an idempotent run key.
3. Worker queries the approved Supabase projection at a recorded watermark.
4. Worker writes a full replacement or versioned snapshot to the configured Sheet.
5. Worker records row count, checksum, generated-at time, destination version, and delivery result.
6. Retry uses the same run identity and cannot duplicate business data.

### Rules

- Sheet formulas or edits are not imported as business state.
- Public export columns require a privacy review.
- A failed export is visible to staff and does not change the last successful business watermark.
- Public output includes source attribution and freshness information.

Implementation note: Supabase Cron invokes the protected Vercel worker route every 15 minutes through `pg_net`, with the worker URL and matching bearer secret read from Supabase Vault. This avoids making Vercel's plan-specific scheduler an architectural dependency. The worker queues due active definitions, claims work with database leases, calls a service-role-only allowlisted projection, creates a missing tab if required, clears the prior tab, and writes a complete `RAW` snapshot. The first rows identify the portal source, projection code, and generation time. Operators configure only the spreadsheet ID in `/staff/integrations`; the Sheet must already exist and be shared with the configured service account. The worker cannot create business records or import cell edits.

## 17. Discord lookup and notification

### Public lookup

1. User invokes an approved command with a public reference or catalogue query.
2. Bot rate-limits and validates input.
3. Bot queries an explicit public function.
4. Bot returns the same public disclosure class as the website.

### Private lookup

1. Discord identity must be bound to an actor or party through an approved verification flow.
2. Bot resolves current representative or staff scope at request time.
3. Response is ephemeral or sent to an approved private channel when sensitive.
4. No private status is inferred from public command failure.

### Notification

1. Business transaction writes an outbox event.
2. Worker applies a versioned template and destination policy.
3. Worker posts the message.
4. Delivery metadata and external message ID are recorded.
5. Retry uses deduplication controls.

Discord emoji, message edits, and manual deletion do not modify authoritative state. Interactive approval commands, if ever allowed, must authenticate the actor and invoke the same secure business function used by the staff console.

Implementation note: Discord verifies the deployed interaction endpoint through an Ed25519-signed request. The portal also rejects stale signed requests. The initial `/catalogue`, `/dealer`, and `/license` commands call the same narrow public functions as the website and disable mentions. Private staff alerts are generated only from allowlisted outbox event types and posted to a configured numeric channel ID with a bot token held in the server environment. `/staff/integrations` shows attempts and safe error codes and permits reasoned replay. Discord OAuth for staff sessions remains separate under ADR 0009; Discord roles and command access never grant database authority.

## 18. Staff audit review

1. Authorized auditor chooses subject, actor, time range, request ID, or action type.
2. System returns domain history and audit entries, with sensitivity redaction appropriate to the auditor.
3. Auditor can trace an order from submission through approval, reservation, fulfillment, inventory movement, quota consumption, and notifications.
4. Export of audit data is itself audited.
5. Audit records cannot be edited or deleted through the application.

## 19. Operational recovery

### Failed business command

The transaction rolls back. Caller receives a stable error code, safe message, and request ID. The client may retry only when the command supports idempotency.

### Ambiguous client timeout

Caller retries with the same idempotency key or queries command status. It must not submit a new logical operation blindly.

### Failed notification or export

Business state remains committed. Delivery retries from outbox metadata. Staff can inspect and replay within policy.

### Incorrect posted ledger or custody event

Authorized staff posts a linked reversal or corrective event. Original evidence remains visible.

### Compromised dealer link

Staff revokes the access grant and active sessions as policy allows, reviews access logs, and issues a replacement. Business records are not migrated to a new identity.

### Suspected credential or integration-secret compromise

Rotate the secret, revoke affected sessions or principal, inspect audit/delivery activity, and follow the incident procedure. Secrets are never placed in tickets, documents, or logs.

## 20. Assumptions

- Ordinary goods may follow a simplified approval path, but still receive authoritative validation.
- Dealer submission and staff processing are asynchronous; notifications supplement rather than replace work queues.
- Reservation duration and renewal are configuration-driven.
- Warehouse dispatch and destination receipt may occur at different times, requiring an in-transit state.
- Consignment reports require acceptance before authoritative inventory or settlement effects.
- Unique assets require explicit identity at reservation and transfer.

## 21. Unresolved workflow decisions

- Final state names and which header states are derived from line states
- Exact warehouse-processing point at which an approved or awaiting-stock order becomes reserved
- Whether quotas are held at submission and when they become consumed
- Automatic approval thresholds and when staff review is mandatory
- Action-specific second approvals, if any; there is no universal two-person requirement
- Reservation extension limits, uncollected-order consequences, and waiting-list priority
- Substitution and split-shipment rules beyond approved partial approval, fulfillment, and back-order handling
- Payment, deposit, credit, and settlement gates in the order workflow
- Dealer receipt proof beyond confirmation by an authorized actor
- Consignment reporting frequency, acceptance, settlement amounts, shrinkage, and loss rules beyond retained EEC ownership
- License expiration scheduling, grace periods, pending-renewal authority, and effects on existing orders
- Whether an appeal stays an enforcement action
- Emergency overrides and after-the-fact review requirements
- Future changes to the approved public verification result categories and disclosure text
- Whether any future Discord command may cause a state change; the initial commands are read-only
- Sheet failure escalation beyond the approved 15-minute target cadence

No workflow-dependent implementation should guess these decisions. A decision record and updated transition tests are required first.

## 22. Keystone-material procurement workflow

### Establish policy

1. An economic steward selects a canonical material.
2. Staff configure the player-sourced reserve mode and ordered critical, minimum, target, and surplus thresholds.
3. Staff publish an effective-dated guaranteed purchase offer after the actual floor rate is approved.
4. The offer becomes visible on the internal economy desk. Publishing it does not create stock.

### Register a producer

1. An EEC agent identifies the player character or organization selling material.
2. A procurement officer creates a private supplier record and receives an `EEC-SUP-*` reference.
3. The supplier remains distinct from licensed dealers. Selling material to the Company grants no authority to buy wholesale goods.

### Accept a delivery

1. The supplier brings gathered material to an authorized EEC agent or warehouse interaction.
2. The agent selects the supplier, current offer, receiving location, and inspected accepted quantity.
3. Supabase revalidates the current offer, minimum, supply policy, supplier standing, fungible item, warehouse scope, and request ID.
4. One transaction creates the `EEC-PRC-*` delivery, snapshotted payment obligation, balanced external-to-physical ledger receipt, audit record, and outbox event.
5. The reserve quantity becomes visible from ledger-derived stock. The delivery remains `pending` for settlement.

### Record payment

1. Staff perform the in-character or administrative Septim payment through the server's approved mechanism.
2. A procurement officer records its voucher, log, or payment reference and an audit reason.
3. The delivery becomes paid. No second stock movement occurs.

### Supply pressure and resale

1. The economy dashboard compares available reserve with configured thresholds and approved unfulfilled demand.
2. Low reserve can prompt a new or changed future offer; it never changes an existing accepted delivery rate.
3. Licensed businesses may order reserve stock under separately approved wholesale schedules.
4. A high emergency or convenience resale price protects the ordinary player market. It is not calculated from the purchase offer in frontend code.
5. When reserve is unavailable, an order may wait for replenishment; staff do not spawn stock to clear the queue.

