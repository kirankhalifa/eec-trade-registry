# EEC Trade Registry — Permissions and Data Exposure

Status: Governing permission model under ADR 0005
Security model: Deny by default, least privilege, scoped authority, and PostgreSQL row-level security

## 1. Principles

1. Authentication proves an actor identity; it does not by itself grant business authority.
2. Authorization is resolved from active role or representative assignments, jurisdiction, warehouse, portfolio, subject, state, and time.
3. Supabase PostgreSQL policies and secure functions enforce authorization. Hidden buttons and frontend routes are not security boundaries.
4. Anonymous access uses explicit public views or functions, never broad table access.
5. Dealer access is limited to the parties the actor currently represents and to deliberately exposed fields.
6. Staff receive composable roles. Job titles do not imply unrestricted access.
7. High-risk actions can require a reason, elevated scope, a second approver, or segregation of duties.
8. Integration identities receive purpose-built read or delivery scopes; service-role credentials are never a general application identity.
9. Sensitive data is classified and returned only when both role and purpose permit it.
10. Every consequential authorization decision and action is auditable.

## 2. Actor classes

### Anonymous public

Unauthenticated browser or public Discord command. May view only approved public projections.

### Authenticated dealer representative

Human actor with an active session and an effective representative grant for one or more parties.

### Regional factor

Human actor or appointed party with a time-bounded authority profile for specified jurisdictions or portfolios. A factor may also hold staff roles, but factor status alone does not grant database access.

### Staff

Authenticated human with one or more effective staff role assignments. Scope may be global or limited by jurisdiction, warehouse, and portfolio.

### Auditor

Staff role with read-only access to approved business and audit history. Sensitive evidence access is a separate permission.

### Integration principal

Non-human identity for a narrowly defined system purpose, such as public exports, Discord delivery, Discord lookup, document generation, or scheduling.

### System maintenance principal

Highly privileged server-side identity for migrations and controlled operations. It is not used by a browser, bot command handler, or routine background job.

## 3. Proposed permission scopes

Scope names are provisional; they should become stable machine identifiers before implementation.

### Catalogue

- `catalogue.public.read`
- `catalogue.dealer.read`
- `catalogue.private.read`
- `catalogue.manage`
- `pricing.manage`
- `pricing.override.request`
- `pricing.override.approve`
- `control_policy.manage`
- `publication.manage`

### Parties and dealers

- `party.own.read`
- `party.private.read`
- `party.manage`
- `dealer.own.read`
- `dealer.manage`
- `representative.manage`
- `factor_assignment.manage`
- `standing.read`
- `standing.manage`

### Licensing

- `application.own.create`
- `application.own.read`
- `application.review`
- `license.own.read`
- `license.private.read`
- `license.issue`
- `license.renew`
- `license.condition.manage`
- `license.suspend`
- `license.reinstate`
- `license.revoke`
- `endorsement.manage`

### Orders and allocation

- Dealer grant scopes: `order.create`, `order.read`, `order.cancel`
- `order.private.read`
- `order.review`
- `order.approve.ordinary`
- `order.approve.restricted`
- `order.approve.unique`
- `order.price.edit`
- `order.cancel`
- `reservation.manage`
- `quota.read`
- `quota.adjust`
- `circulation.override`

### Warehouse and custody

- `inventory.position.read`
- `inventory.receipt.post`
- `inventory.receipt.reverse`
- `inventory.issue.post`
- `inventory.adjust.request`
- `inventory.adjust.approve`
- `inventory.reconcile`
- `transfer.request`
- `transfer.authorize`
- `transfer.dispatch`
- `transfer.receive`
- `asset.private.read`
- `asset.register`
- `asset.reserve`
- `asset.custody.transfer`
- `asset.inspect`
- `asset.lifecycle.manage`

Implementation note: `warehouse_operator` receives private read, registration, allocation, custody-transfer, and inspection capabilities; `inventory_controller` receives all serialized-asset capabilities, including lifecycle transitions; and `order_officer` receives private read and allocation. Registration remains warehouse-scoped. No asset permission grants direct table access, public disclosure, transaction-specific approval, or unique fulfillment authority.

### Consignment and finance

- `consignment.private.read`
- `consignment.agreement.manage`
- `consignment.issue`
- `consignment.report.accept`
- `consignment.return`
- `commercial_terms.read`
- `commercial_terms.manage`
- `settlement.read`
- `settlement.manage`

Implementation note: `inventory_controller` receives every current consignment permission. `warehouse_operator` receives private read, warehouse-scoped issue, and warehouse-scoped return. `order_officer` receives private read, agreement management, and report review. Current portal representatives receive `consignment.read` and `consignment.report` dealer scopes, including a migration backfill for existing grants. Dealer functions still resolve an active representation for the exact consignee; no role label, Discord role, or direct table grant creates authority. Commercial and settlement permissions remain proposed and ungranted.

### Compliance and audit

- `compliance.private.read`
- `compliance.case.manage`
- `compliance.inspection.manage`
- `compliance.evidence.manage`
- `compliance.finding.record`
- `compliance.action.recommend`
- `compliance.action.approve`
- `compliance.appeal.manage`
- `audit.read`
- `audit.export`

Implementation note: the elevated configurable `compliance_officer` role receives all eight implemented compliance permissions. `auditor` receives private read only. Direct table access remains denied, evidence metadata does not grant object-storage access, and every command re-resolves the current assignment. The initial role may both recommend and approve because ADR 0005 rejects an inferred universal two-person rule; a future configured independence policy may narrow that authority for specific action types.

### Administration and integrations

- `configuration.read`
- `configuration.manage`
- `access.manage`
- `integration.private.read`
- `integration.manage`
- `integration.replay`
- `document.generate`
- `system.health.read`

## 4. Proposed staff roles

Roles are composable bundles and may be narrowed by assignment scope.

### Clerk

Can read routine party, dealer, license, and order information; enter drafts; request missing information; and generate approved documents. Cannot approve, post inventory, change prices, or impose compliance actions.

### Catalogue manager

Can manage items, categories, public presentation, price proposals, and control assignments. High-impact price or control changes may require approval by another role.

The initial Slice 2 implementation grants the configurable `catalogue_manager` role only `catalogue.private.read` and `catalogue.manage`. Publication, pricing, control-policy, access-management, and approval permissions remain unassigned until their policy is approved.

### Licensing officer

Can review applications, issue or renew within assigned authority, grant ordinary endorsements, and manage routine conditions. Suspension, revocation, or exceptional endorsements may require senior or compliance approval.

The implemented initial role receives `license.private.read`, `license.issue`, `license.activate`, `license.suspend`, `license.reinstate`, `license.revoke`, `license.surrender.record`, and `endorsement.manage`. Each command resolves its exact permission at execution time. Renewal, conditions, application review, limits, and action-specific secondary approval are not yet granted.

### Order officer

Can review and approve orders within an assigned control level and value/quantity limit, manage routine reservations, and cancel eligible unfulfilled lines.

The implemented initial role receives `order.private.read`, `order.review`, `order.approve.ordinary`, `order.approve.restricted`, `order.approve.unique`, `order.price.edit`, and `order.cancel`. Each approval command resolves the exact control permission from stored line snapshots. Assignment limits and reservation authority are not yet implemented.

### Warehouse operator

Can receive, pick, dispatch, and receive transfers for assigned warehouses. Cannot self-approve reconciliation adjustments above configured thresholds.

The implemented role receives `inventory.position.read`, `inventory.receipt.post`, `reservation.manage`, `reservation.extend`, `reservation.release`, `inventory.fulfillment.read`, `inventory.fulfillment.post`, and routine transfer read/create/dispatch/receive permissions. Each function evaluates `assignment_scope.warehouse_ids`; an absent key means all configured warehouses, while a present array is an allowlist. Picking stages and reconciliation permissions remain future work.

`inventory_controller` additionally receives `inventory.receipt.reverse`, `inventory.fulfillment.reverse`, and the complete transfer permission set including authorization and pre-dispatch cancellation. A fulfillment reversal restores ledger stock and reopens demand without granting authority to rewrite the original issue or reactivate its consumed reservation. Transfer authorization may be performed by any sufficiently scoped controller; no universal two-person rule is assumed.

### Inventory controller

Can supervise reconciliations, approve adjustments, manage warehouses, and review inventory history. Whether this role may also dispatch stock is a segregation-of-duties decision.

The implemented initial role receives the warehouse-operator foundation plus `inventory.receipt.reverse`. Reversal is an append-only correction permission, not authority to edit posted transactions or create arbitrary adjustments.

### Regional factor

Can view and act only for an assigned region or portfolio. Candidate powers include dealer sponsorship, application recommendation, order coordination, and transfer receipt. Exact powers come from the factor's authority profile.

### Compliance officer

Can manage cases, inspections, evidence, findings, and action recommendations. Applying suspensions, seizures, or revocations may require a separate approving role.

### Finance officer

Can view commercial terms and manage approved settlement, deposits, credits, or balances once those features are defined. Cannot alter stock or licensing authority solely through finance access.

### Administrator

Can manage configuration, assignments, integration destinations, and emergency access. Administrative access does not automatically authorize commercial, warehouse, licensing, or compliance decisions.

### Auditor

Read-only access to configured business history and audit records. Evidence, private identity data, and secret metadata remain separate scopes.

## 5. Capability matrix

Legend: `V` view, `C` create/request, `M` manage/execute, `A` approve, `—` no access by default. Every non-public entry is still subject to row, field, state, region, warehouse, and assignment scope.

| Capability | Public | Dealer rep | Clerk | Catalogue mgr | Licensing officer | Order officer | Warehouse operator | Factor | Compliance | Admin | Auditor |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Public catalogue | V | V | V | V | V | V | V | V | V | V | V |
| Private dealer catalogue | — | V own | V | V | V | V | V | V scoped | V | V | V |
| Public verification | V | V | V | V | V | V | V | V | V | V | V |
| Own dealer/license details | — | V own | V | V | M scoped | V | V | V scoped | V | V | V |
| Private party/contact data | — | V limited own | V scoped | — | V scoped | V limited | V fulfillment-only | V scoped | V scoped | M access config | V approved |
| Create application | — | C own | C | — | C/M scoped | — | — | C scoped | — | — | — |
| Review/issue license | — | — | support | — | M/A scoped | — | — | recommend | recommend/action | — | V |
| Suspend/revoke license | — | — | — | — | scoped if granted | — | — | recommend | A/M scoped | emergency config only | V |
| Manage catalogue | — | — | draft support | M | V | V | V | V scoped | V | config only | V |
| Manage price rules | — | — | — | M scoped | V | V | — | recommend | — | config only | V |
| Override order price | — | — | — | request | V | request/A scoped | — | request scoped | — | — | V |
| Create order | — | C own | C on behalf | — | — | C/M | — | C scoped | — | — | V |
| Approve order | — | — | — | — | compliance input | A by level | — | A only if profile grants | compliance input | — | V |
| Create/release reservation | — | — | — | — | — | M | fulfillment consume only | M if granted | suspend request | — | V |
| View inventory position | coarse only if public | policy-safe | V | V | V | V | V | V scoped | V | V | V |
| Post receipt/issue | — | receipt acknowledgement only | — | — | — | — | M scoped | M only if granted | seizure workflow only | — | V |
| Approve adjustment | — | — | — | — | — | — | separate controller | — | case-linked input | — | V |
| Transfer custody | — | accept own if permitted | — | — | — | request | dispatch/receive | scoped | seize/return via action | — | V |
| Manage unique assets | public subset | own custody subset | V limited | V | V | V | M physical | V scoped | M compliance | — | V |
| Submit consignment report | — | C own | C on behalf | — | — | review | receive return | C/M scoped | V | — | V |
| Manage compliance case | — | own notices/responses | support only | — | V relevant | V relevant | V relevant | V scoped | M/A | — | V approved |
| Read audit log | — | own status history only | — | limited domain history | limited domain history | limited domain history | limited domain history | limited scoped | V scoped | V access events | V |
| Manage access/roles | — | — | — | — | — | — | — | — | — | M | V assignments |
| Run/replay exports | — | — | — | request | — | — | — | — | — | M | V |

This matrix is a starting design, not approved institutional policy.

## 6. Row and context scoping

Permission scope alone is insufficient. Secure functions and RLS must also evaluate context.

### Dealer scope

A dealer representative can access a row only when:

- The session is valid.
- An active representative grant links the actor to the principal party.
- The grant includes the requested action.
- The record belongs to or is deliberately shared with that party.
- The dealer authorization and any required access grant remain active.
- Field-level disclosure permits the requested columns.

### Staff scope

A staff actor can act only when:

- At least one active role assignment contains the needed permission.
- Assignment jurisdiction, warehouse, or portfolio covers the subject.
- The record is in a state where the action is allowed.
- Any value, quantity, control-level, or risk threshold is within the actor's authority.
- Required reason, reauthentication, and approval steps are satisfied.
- Segregation-of-duties constraints do not disqualify the actor.

### Factor scope

Factor access is the intersection of:

- Active factor assignment
- Authority profile
- Jurisdiction or portfolio
- Any staff role assignment
- Record state and approval limit

No authorization check should use a text title such as `factor` as sufficient proof.

### Integration scope

An integration principal receives only an allowlist of functions and projection columns. Destination configuration is server-side. The bot or exporter cannot query arbitrary tables.

The implemented `integration_operator` role bundles `integration.private.read`, `integration.manage`, and `integration.replay`. It may inspect the integration workspace, store or change non-secret spreadsheet/channel identifiers, enable approved definitions, request a snapshot, and replay a failed delivery with an audit reason. It cannot read secret environment values, edit template SQL, query business tables directly, or change source business state. Worker claim/complete/fail functions and enumerating export projections are executable only by the server-side `service_role` principal.

## 7. Data classification

### Public

Approved for anonymous publication, such as public catalogue fields and selected verification fields.

### Dealer-confidential

Visible to active representatives of the owning party and authorized staff, such as private prices, own orders, conditions, quota presentation, and collection instructions.

### Internal

Visible to authorized staff, such as operational stock, assignments, internal notes, work queues, and non-public policies.

### Restricted

Limited to explicit roles and purposes, such as identity data, risk classifications, compliance cases, evidence, enforcement deliberations, audit snapshots, and secret metadata.

### Secret

Credentials and tokens, including Supabase service-role keys, Discord bot tokens, webhook URLs, Google service-account credentials, private-link raw tokens, signing keys, and private status tokens. Secrets are not stored in ordinary application tables or repository files.

## 8. Field-level exposure

### Public catalogue projection may include

- Item code or public slug
- Public display name, description, media, category, and tags
- Public price and currency display when approved
- Plain-language purchase requirements
- Public control label
- Coarse availability and generated-at time
- Bulk minimum or order increment in plain language

It must not include exact warehouse/location, exact stock by default, wholesale or contract prices, acquisition cost, internal notes, risk logic, unpublished controls, or private asset data.

### Public license verification may include

- Public license reference
- Approved public holder or organization name
- License class label
- Approved endorsements
- Jurisdiction
- Validity result
- Effective/expiration dates if approved
- Public conditions or notice text
- Verification timestamp

It must not include application answers, private contacts, internal standing, staff notes, compliance allegations, orders, payments, access tokens, or hidden conditions.

### Public dealer verification may include

- Dealer public reference
- Approved public name and premises/region display
- Dealer type
- Authorization result and term if approved
- Approved license summary or link
- Public notices

The implemented anonymous surface is limited to `public_dealer_verification(text)` and `public_license_verification(text)`. Anonymous and ordinary authenticated callers have no direct table access. Both functions use exact normalized references, fixed response contracts, and record-level public-disclosure flags. Production rate limiting remains an edge and operations requirement rather than database business state.

### Dealer portal may include

- The representative's own profile and represented parties
- Own dealer authorization, licenses, endorsements, conditions, applications, orders, reservations, transfers, and documents
- Applicable prices and policy-safe quota/availability information
- Notices and actions required from that dealer

It must not reveal another dealer's data, internal price-cost basis, other parties' allocations, internal standing/risk, investigation details beyond served notices, staff deliberations, or global stock unless approved.

### Staff views

Staff views should select only fields needed for the task. A warehouse operator does not require full application answers; a catalogue manager does not require private compliance evidence; an administrator does not automatically require commercial or evidence content.

## 9. High-risk and dual-control actions

Candidate actions requiring stronger controls:

- Service-role or role-assignment changes
- License suspension, revocation, or emergency reinstatement
- Unique-asset approval, seizure, destruction, or custody correction
- Restricted-order approval above configured thresholds
- Price override beyond configured limits
- Quota or circulation-ceiling override
- Negative-stock exception or reconciliation adjustment above a threshold
- Backdated ledger, license, endorsement, or enforcement records
- Export of audit or restricted evidence data
- Replay to a public Discord or Sheet destination after content has changed

Possible controls:

- Mandatory reason code and narrative
- Recent reauthentication
- Different requester and approver
- Approval by a role outside the requester's chain
- Time-bounded approval
- Automatic compliance or audit review
- High-priority outbox alert

There is no universal dual-control rule. Any active actor with the required permission and scope may complete an action. The final matrix may still require a distinct approver for specifically configured high-risk actions; those requirements must be explicit rather than inferred from role titles.

## 10. RLS and secure-function requirements

- Enable RLS on every table exposed through the Supabase API.
- Revoke default grants and add the minimum explicit grants.
- Anonymous access should target public views/functions only.
- Use `security invoker` views when possible. Any `security definer` function must have a fixed safe `search_path`, explicit grants, validated inputs, and its own authorization checks.
- Do not trust caller-supplied party, role, jurisdiction, warehouse, price, or actor identifiers without resolving them against the session.
- Avoid direct client writes to consequential tables. Use purpose-built functions.
- Functions must fail closed if authorization configuration is missing or ambiguous.
- Background workers use a dedicated integration principal or server-only credentials and still call business functions for business changes.
- Service-role credentials bypass RLS and therefore require explicit application-level authorization; they must not be sent to clients.
- Object storage policies must match record permissions for images, certificates, invoices, and evidence.

## 11. Authentication and session requirements

### Staff

- Supabase Auth cookie sessions initiated through individual Discord OAuth identities; no staff email/password form
- Fixed allowlisted OAuth callback and server-side PKCE code exchange
- Discord provider subject and Supabase Auth UUID are identity data, never role or permission claims
- Multi-factor authentication for elevated roles before launch
- Shorter sessions or step-up authentication for high-risk actions
- Immediate assignment revocation and practical session invalidation
- No shared staff accounts

### Dealers

- Lightweight credentials, magic links, or secure-link session exchange
- Representative relationship verified before private access
- Revocable sessions and grants
- Sensitive actions may require stronger identity than catalogue viewing
- Private URLs are not posted in public Discord channels or exported Sheets

The implemented credential path grants authenticated dealer actors reachability to `get_dealer_portal_overview()` plus order reference/list/detail and submission/cancellation functions. Each function resolves the required `portal.read`, `order.read`, `order.create`, or `order.cancel` representative scope and a current authority-conferring dealer authorization. Order projections are organization-scoped and another dealer receives the same not-found behavior for an inaccessible order identifier. Direct party, representation, dealer, license, endorsement, condition, order, event, audit, and outbox table reads remain denied.

The implemented licensing path grants authenticated callers reachability only to secured licensing projections and commands. Each function independently resolves an active staff actor, assignment, and exact permission. Direct license, history, audit, reference-sequence, and outbox table access remains denied.

The implemented staff order path follows the same reachability model. Queue/detail calls require `order.private.read`; review, control-level approval, price editing, and cancellation resolve separate current permissions inside security-definer commands. Direct order tables remain denied even to authenticated staff.

### Integrations

- Separate credential per environment and integration purpose
- Rotation and revocation procedure
- Secrets sourced from managed environment configuration
- No credential in repository, database audit snapshots, generated documents, chat, logs, or error messages

## 12. Audit expectations

Every allowed consequential action records:

- Actor, session or integration principal, and effective represented party
- Permission and assignment used where feasible
- Source surface and request/correlation ID
- Action and affected records
- Previous and new state
- Timestamp
- Reason and approval linkage
- Impersonation or on-behalf-of context

Denied high-risk actions should generate security telemetry without storing secret input. Routine public misses should be rate-limited and aggregated to avoid an unusable audit log.

## 13. Permission test matrix

Each protected function and RLS policy must later include tests for:

- Anonymous caller
- Authenticated actor with no assignments
- Dealer representative for the correct party
- Dealer representative for the wrong party
- Expired or revoked representative grant
- Secure link with valid, used, expired, and revoked token
- Correct staff role in scope
- Correct role in the wrong jurisdiction or warehouse
- Lower approval tier attempting a restricted or unique action
- Requester attempting prohibited self-approval
- Auditor attempting a write
- Admin without domain permission attempting a business action
- Integration principal calling an unapproved function
- Service function receiving a spoofed actor or party ID
- Public projection containing seeded restricted fields

## 14. Emergency access

If break-glass access is required, it must be a distinct, documented mechanism:

- Named individual identity; never a shared account
- Strong authentication and explicit activation reason
- Time-bounded elevated assignment
- Immediate notification to an independent reviewer
- Full read and write audit
- Automatic expiry
- Mandatory post-event review

Break-glass access does not permit secret disclosure, audit deletion, or untracked ledger changes.

## 15. Assumptions

- Supabase Auth is the identity and session provider for the application; Discord performs initial staff authentication under ADR 0009.
- Staff authority remains in effective-dated database assignments. Discord authorization, server membership, roles, display names, and bot permissions grant no business authority.
- Dealer access may begin with magic links or secure grants and evolve to persistent credentials without changing business authorization data.
- Roles are composable and assignments can be scoped.
- Public views return a deliberately smaller schema than staff or dealer views.
- Staff can hold multiple roles, but conflicts may block certain self-approval paths.

## 16. Unresolved policy decisions

- Final staff role bundles, approval limits, regional factor authority profiles, and any action-specific dual-control rules
- Whether staff multi-factor authentication is mandatory for all staff or only elevated actions
- Dealer identity proof beyond password authentication, enrollment, credential recovery, representative approval, and access-link reuse policy
- Which staff roles may see private contact data, internal standing, compliance evidence, and audit snapshots
- Any changes to the approved public verification field allowlists or exact-reference-only lookup behavior
- Exact stock and quota disclosure to dealers and the public
- Action-specific dual-control thresholds and incompatible-role combinations, if introduced
- Whether administrators can grant themselves domain roles and what review is required
- Session durations, step-up intervals, revocation behavior, and inactive-account policy
- Data retention and deletion rights for contacts, authentication metadata, applications, evidence, and audit logs
- Emergency-access custodians and review process
- Discord bot/command identity-binding method and which private commands are permitted; this is separate from the approved staff OAuth sign-in flow

These decisions are launch blockers for their affected surfaces and must be recorded before permission migrations are written.

