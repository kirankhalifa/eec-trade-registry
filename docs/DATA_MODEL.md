# EEC Trade Registry — Conceptual Data Model

Status: Governing conceptual model; implementation proceeds under ADR 0005
Database: Supabase PostgreSQL  
Authority: Supabase is the only authoritative source of business data.

## 1. Modeling conventions

### 1.1 General rules

- Use UUID primary keys internally unless a measured requirement justifies another type.
- Keep human-readable codes in separate immutable, unique columns. Codes are references, not primary keys.
- Use `timestamptz` in UTC for instants and `date` only for policy dates with no time-of-day meaning.
- Use integer minor units plus a currency reference for money. Never use floating-point money.
- Use effective-dated records for rules and authorizations that change over time.
- Prefer reference tables or validated configuration records for changeable domain vocabulary.
- Stable machine statuses may use constrained text or PostgreSQL enums only when their transition semantics are truly stable. Display labels remain configurable.
- Every mutable authoritative table includes `created_at`, `created_by`, `updated_at`, and `updated_by` where meaningful.
- Consequential changes also create an immutable audit entry; timestamps alone are not sufficient history.
- Soft deletion is not a universal substitute for history. Use explicit archive, inactive, reversal, supersession, or terminal status semantics.

### 1.2 Configuration-first terminology

The following must not be inferred from names or embedded in frontend conditionals:

- Jurisdictions and regions
- Party and dealer types
- Staff titles and regional factor portfolios
- License classes and endorsement definitions
- Item categories, tags, and control profiles
- Price schedules, quotas, circulation rules, and approval policies
- Currency labels, document prefixes, number formats, and notification templates

The working labels `ordinary`, `restricted`, and `unique` describe initial control behaviors. They must be seeded configuration codes or behavior flags, not lore-specific item-name logic.

### 1.3 Derived values

Do not store a value as freely editable state when it can be authoritatively derived. Examples:

- `inventory_on_hand` = posted inventory ledger movements
- `inventory_available` = on-hand minus active reservations, with approved policy adjustments
- `license_is_valid` = status, effective dates, holder/dealer standing, and applicable conditions
- `quota_remaining` = allowance plus adjustments minus committed consumption and active holds
- `asset_current_custodian` = accepted custody events
- `expiring_soon` = expiration date compared with a configured window

Materialized views or caches may accelerate these values, but they remain rebuildable projections and are updated transactionally or refreshed from source records.

## 2. Domain map

```text
Identity and access
  auth.users -> actor_profiles -> staff_assignments / party_representatives
                         -> portal_access_grants

Parties and authority
  parties -> dealer_authorizations -> licenses -> license_endorsements
       \-> factor_assignments           \-> license_conditions

Catalogue and policy
  items -> item_publications
       -> item_control_assignments -> control_profiles
       -> price_rules -> price_schedules
       -> quota_policies

Commerce
  parties -> orders -> order_lines -> reservations
                           \-> approvals / price snapshots / quota holds

Inventory and custody
  warehouses -> stock_locations -> inventory_accounts -> inventory_ledger_entries
  items -> serialized_assets -> asset_events
  orders -> transfers -> transfer_lines -> ledger entries / asset events

Compliance
  parties / licenses / orders / assets -> compliance_cases
                                      -> inspections -> findings
                                      -> enforcement_actions -> appeals

Projections and evidence
  outbox_events -> integration_deliveries
  export_definitions -> export_runs
  all consequential domains -> audit_log
```

## 3. Identity and access

### `actor_profiles`

Application-level identity linked one-to-one with `auth.users` when the actor authenticates.

Key fields:

- `id`
- `auth_user_id` nullable and unique
- `display_name`
- `actor_type` such as staff, dealer representative, integration, or system
- `status`
- `last_authenticated_at`

An actor is not necessarily a legal or commercial party. A representative may authenticate as an actor while acting for an organization party.

Implementation note: actor profiles currently support the stable machine types `staff` and `dealer`. User-facing role and organization titles remain configuration records.

### `staff_roles`

Configurable role definitions with stable permission bundles or references to permission scopes.

Key fields:

- `id`, `code`, `display_name`
- `description`
- `is_assignable`
- `is_elevated`

### `staff_assignments`

Effective-dated assignment of an actor to a role and optional jurisdiction, warehouse, or portfolio.

Key fields:

- `actor_id`, `staff_role_id`
- `jurisdiction_id` nullable
- `warehouse_id` nullable
- `effective_from`, `effective_until`
- `granted_by`, `revoked_by`, `revoked_at`

### `party_representatives`

Effective-dated authority for an actor or person party to act for another party.

Key fields:

- `principal_party_id`
- `representative_party_id` nullable
- `actor_id` nullable
- `authority_scope`
- `effective_from`, `effective_until`
- `status`, `verified_at`, `verified_by`

At least one representative identity is required. The authorization function must validate both dates and scope.

Implementation note: the credential-based dealer portal implements actor-linked representative grants, configurable representative roles, JSON scope with `portal.read`, effective dates, revocation, verification time, overlap protection, audit triggers, and a secured organization-scoped overview. Representative-party and private-link exchange paths remain future work.

### `portal_access_grants`

Metadata for secure private-link access when used. Raw tokens are never stored.

Key fields:

- `id`, `party_id`, optional `actor_id`
- `token_digest`
- `scope`
- `issued_at`, `expires_at`, `used_at`, `revoked_at`
- `issued_by`, `last_ip_hash` or other privacy-approved abuse metadata

Preferred behavior is to exchange the grant for a short-lived scoped session. Reuse, extension, and revocation policies are unresolved.

### `integration_principals`

Narrowly scoped non-human identities for Discord, Google export, document generation, and scheduled jobs.

Key fields:

- `id`, `code`, `display_name`
- `allowed_scopes`
- `status`
- `credential_reference` containing only a secret-manager reference, never the secret

## 4. Configuration and jurisdiction

### `jurisdictions`

Hierarchical regions or operating territories.

Key fields:

- `id`, `code`, `display_name`
- `parent_id` nullable
- `status`
- `default_timezone`

### `currencies`

Display and arithmetic metadata.

Key fields:

- `id`, `code`, `display_name`, `symbol`
- `minor_unit_scale`
- `rounding_mode`
- `status`

Initial configured record: code `SEP`, display name `Septims`, zero fractional minor units. This is deployment data, not a currency branch in application logic.

### `number_sequences`

Configuration for human-friendly public references, with allocation performed by an authoritative function.

Key fields:

- `id`, `document_type`, optional `jurisdiction_id`
- `prefix_template`, `next_value`, `padding`
- `reset_policy`

Sequence allocation must be concurrency-safe. Once assigned, references do not change if display names or regions are renamed.

### `policy_versions`

Optional registry of approved policy bundles or rule versions.

Key fields:

- `id`, `code`, `display_name`
- `effective_from`, `effective_until`
- `approved_by`, `approved_at`
- `configuration` or links to normalized rule records

Business records should store the policy or rule version used when reproducibility matters.

## 5. Parties, dealers, and factors

Implementation status: the public-verification increment implements jurisdictions, party types, protected party source records, dealer types, configurable dealer statuses, and effective-dated dealer authorizations. Contacts, external identities, representatives, factors, standing, and staff mutation commands remain future policy-gated work.

### `parties`

One record per person, organization, public institution, or system-recognized commercial entity.

Key fields:

- `id`, `party_type_id`
- `legal_name`, `display_name`
- `public_reference` nullable and unique
- `status`
- `primary_jurisdiction_id` nullable
- `public_profile_enabled`

Sensitive contact and identity data should be stored in separately protected tables rather than mixed into public-facing party fields.

### `party_types`

Configurable classification such as person, business, institution, government body, or other deployment-specific type.

### `party_contacts`

Contact points with verification and visibility classification.

Key fields:

- `party_id`, `contact_type`, `value_ciphertext` or appropriately protected value
- `visibility` such as private, staff, dealer, or public
- `verified_at`, `status`

### `external_identities`

Bindings to approved external systems, including Discord.

Key fields:

- `party_id` or `actor_id`
- `provider`, `external_subject_id`
- `verified_at`, `verified_by`, `revoked_at`

Never use a display name as an identity key.

### `dealer_authorizations`

Effective-dated authorization for a party to operate as a dealer or approved counterparty.

Key fields:

- `id`, `dealer_party_id`, `public_reference`
- `dealer_type_id`, `jurisdiction_id`
- `status`
- `approved_premises` or normalized premises references
- `effective_from`, `effective_until`
- `sponsoring_party_id` or `factor_assignment_id` nullable
- `public_notes`, `private_notes`
- `approved_by`, `approved_at`

Dealer authorization and licensing are separate. Policy may require both.

### `factor_assignments`

Appoints a party or actor as a regional factor for a period and scope.

Key fields:

- `factor_party_id`, optional `actor_id`
- `jurisdiction_id`, optional `portfolio_definition`
- `authority_profile_id`
- `effective_from`, `effective_until`
- `status`, `appointed_by`

The title alone grants no permission; functions resolve authority from the assignment and profile.

### `standing_records`

Effective-dated internal standing or risk classifications for a party or dealer.

Key fields:

- `party_id`, `standing_type_id`
- `effective_from`, `effective_until`
- `reason`, `recorded_by`
- `publicly_disclosable`

Standing is private by default and must not be returned by public verification functions.

## 6. Licensing

Implementation status: the public-verification increment implements configurable license classes and statuses, issued-license source records, modular endorsement grants, public/private conditions, and narrow exact-reference projections. Applications, reviews, status-event commands, and issuance or lifecycle operations remain future policy-gated work.

### `license_classes`

Configurable definitions of license families.

Key fields:

- `id`, `code`, `display_name`, `description`
- `default_duration`
- `holder_party_types`
- `public_disclosure_profile_id`
- `status`

### `endorsement_definitions`

Modular authorities or commodity scopes attachable to licenses.

Key fields:

- `id`, `code`, `display_name`, `description`
- `default_duration`
- `requires_endorsement_id` nullable
- `exclusivity_group` nullable
- `status`

### `license_applications`

Requests for a new license, renewal, endorsement change, reinstatement, or other configured service.

Key fields:

- `id`, `public_reference`
- `application_type`
- `applicant_party_id`, optional `dealer_authorization_id`
- `requested_license_class_id`
- `jurisdiction_id`
- `status`
- `submitted_at`, `assigned_to`, `decided_at`, `decided_by`
- `decision`, `decision_reason`
- `source_payload` for versioned answers, subject to retention and privacy controls

Application status is not license status.

### `application_endorsement_requests`

Requested endorsement, scope, and applicant justification for an application.

### `application_reviews`

Append-only review events, evidence requests, interviews, recommendations, and decisions.

### `licenses`

Issued legal or institutional authority.

Key fields:

- `id`, `public_reference`
- `holder_party_id`
- `dealer_authorization_id` nullable
- `license_class_id`, `jurisdiction_id`
- `status` such as provisional, active, suspended, revoked, expired, or surrendered
- `issued_at`, `effective_from`, `expires_at`
- `issued_by`, `approved_by`
- `source_application_id`
- `policy_version_id` nullable
- `public_notes`, `private_notes`

Pending and under-review are application states. `expiring_soon` is derived. Revocation and suspension details belong in status history and enforcement records, not only the current row.

### `license_status_events`

Append-only transitions with effective time, actor, reason, related compliance action, and previous/new status.

### `license_endorsements`

An effective-dated endorsement granted to a license.

Key fields:

- `license_id`, `endorsement_definition_id`
- `status`
- `effective_from`, `expires_at`
- `scope_configuration`
- `granted_by`, `source_application_id`

### `license_conditions`

Structured or templated conditions that may apply to a license or endorsement.

Key fields:

- `license_id`, optional `license_endorsement_id`
- `condition_definition_id`
- `parameters`
- `effective_from`, `effective_until`
- `public_visibility`
- `imposed_by`, `reason`

Conditions that influence eligibility must be machine-readable or explicitly connected to a rule; prose alone cannot enforce policy.

## 7. Catalogue, control, pricing, and quotas

### `items`

Canonical item type.

Key fields:

- `id`, `item_code`, `display_name`
- `category_id`, optional `unit_of_measure_id`
- `description`
- `inventory_mode` such as fungible or serialized
- `status`
- `default_currency_id`

An item name never determines authorization or control behavior.

### `item_categories` and `item_tags`

Configurable classification used for navigation and rule targeting. Tags may be many-to-many through `item_tag_assignments`.

### `item_publications`

Effective-dated public or audience-specific presentation.

Key fields:

- `item_id`, `audience_profile_id`, optional `jurisdiction_id`
- `publication_status`
- `public_name`, `public_description`, `media_reference`
- `availability_display_policy`
- `effective_from`, `effective_until`

Publication does not imply eligibility or stock.

### `control_profiles`

Configurable behavior for classes of controlled goods.

Key fields:

- `id`, `code`, `display_name`
- `requires_staff_review`
- `requires_transaction_approval`
- `requires_serial_tracking`
- `requires_custody_acceptance`
- `default_reservation_duration`
- `public_message_template_id`

Initial seeded profiles may correspond to ordinary, restricted, and unique behavior.

### `item_control_assignments`

Effective-dated attachment of a control profile and requirements to an item, optionally scoped by jurisdiction.

Key fields:

- `item_id`, `control_profile_id`, optional `jurisdiction_id`
- `effective_from`, `effective_until`
- `required_license_class_ids` or normalized rule links
- `required_endorsement_ids` or normalized rule links
- `approval_policy_id` nullable
- `quota_policy_id` nullable
- `circulation_policy_id` nullable

Normalized join tables are preferred where rules must be queried or constrained individually.

### `price_schedules`

Named commercial schedules such as public, wholesale, contract, or special allocation pricing.

Key fields:

- `id`, `code`, `display_name`
- `currency_id`, `status`
- `effective_from`, `effective_until`
- `audience_rule_id` nullable

### `price_rules`

Effective-dated rule records selecting or calculating a price for an item and eligible context.

Key fields:

- `price_schedule_id`, `item_id` or category target
- optional `jurisdiction_id`, `party_id`, `dealer_type_id`, `license_class_id`, `endorsement_id`
- `amount_minor` or approved calculation parameters
- `priority`
- `effective_from`, `effective_until`
- `approved_by`, `policy_version_id`

Rule precedence must be deterministic and tested. Arbitrary executable expressions in data are prohibited unless a safe rules design is approved.

### `quota_policies`

Defines subject, item scope, allowance, window, and hold/consumption behavior.

Key fields:

- `id`, `code`, `subject_type`
- item, category, control, license, or endorsement scope
- `allowance_quantity`
- `window_type`, `window_parameters`
- `carryover_policy`, `reservation_policy`
- `effective_from`, `effective_until`

### `quota_entries`

Append-only allowance adjustments, holds, consumption, releases, and reversals linked to orders or policy actions.

Key fields:

- `quota_policy_id`, `subject_id`
- `entry_type`, `quantity`
- `effective_at`, `window_key`
- `order_line_id` nullable, `reservation_id` nullable
- `reversal_of_id` nullable
- `recorded_by`, `reason`

Remaining quota is derived. Repeated requests must not create duplicate entries.

## 8. Orders and reservations

### `orders`

Commercial requisition header.

Key fields:

- `id`, `public_reference`
- `ordering_party_id`, optional `dealer_authorization_id`
- `license_id` nullable
- `jurisdiction_id`
- `fulfillment_mode` such as wholesale, consignment, institutional issue, or other configured mode
- `status`
- `currency_id`
- `submitted_at`, `requested_by_actor_id`
- `assigned_to_actor_id`
- `requested_fulfillment_at`
- `version` for optimistic concurrency where appropriate

### `order_lines`

Key fields:

- `order_id`, `line_number`, `item_id`
- `quantity_requested`, `quantity_approved`, `quantity_fulfilled`
- `status`
- `unit_price_minor_snapshot`
- `price_rule_id_snapshot`, `price_schedule_id_snapshot`
- `eligibility_snapshot`
- `control_profile_id_snapshot`
- `requested_destination_id` nullable

Submitted line snapshots preserve the decision context but do not replace current validation for later consequential transitions.

### `order_status_events`

Append-only header and line transition history, with actor, reason, previous/new state, and correlation ID.

### `approvals`

Generic but constrained approval records for orders, price overrides, unique assets, transfers, or other supported subjects.

Key fields:

- `subject_type`, `subject_id`
- `approval_policy_id`, `approval_step`
- `decision`, `decided_by`, `decided_at`
- `reason`, `expires_at`

Database constraints and functions must prevent an actor from satisfying incompatible approval steps where segregation of duties applies.

### `reservations`

Time-bounded stock claim.

Key fields:

- `id`, `order_line_id`, `item_id`
- `warehouse_id` or `inventory_account_id`
- `quantity`
- `status` such as active, consumed, released, expired, or cancelled
- `reserved_at`, `expires_at`
- `consumed_at`, `released_at`
- `created_by`, `release_reason`
- `idempotency_key`

Reservation functions lock or otherwise serialize the relevant stock scope so concurrent requests cannot over-reserve. Partial reservations use separate records or explicit remaining quantities with complete history.

### `order_price_overrides`

Requested and approved changes to a line price.

Key fields:

- `order_line_id`
- `previous_amount_minor`, `requested_amount_minor`, `approved_amount_minor`
- `requested_by`, `reason`
- `approved_by`, `approved_at`
- `status`

## 9. Warehouses, inventory, and transfers

### `warehouses`

Physical or controlled facilities with jurisdiction, operating status, and access scope.

### `stock_locations`

Hierarchical locations within or associated with a warehouse, including quarantine or receiving areas. Dealer premises are modeled separately and may be referenced as custody destinations.

### `inventory_accounts`

A logical stock account identifying item, owner, custodian, location, and stock state. This enables custody and ownership to differ for consignment and in-transit stock.

Key fields:

- `id`, `item_id`
- `owner_party_id`
- `custodian_party_id`
- `warehouse_id` or external `location_party_id`
- `stock_state` such as available physical custody, quarantine, damaged, in transit, or external sink/source
- `status`

Accounts do not store editable current quantity.

### `inventory_transactions`

Header grouping an atomic set of ledger entries.

Key fields:

- `id`, `transaction_type`
- `occurred_at`, `posted_at`, `posted_by`
- `source_document_type`, `source_document_id`
- `idempotency_key`
- `reason`
- `reversal_of_id` nullable

### `inventory_ledger_entries`

Immutable quantity movements within an inventory transaction.

Key fields:

- `inventory_transaction_id`
- `inventory_account_id`
- `item_id`
- `quantity_delta`
- `unit_of_measure_id`
- `line_number`

For a fungible item, each posted transaction must balance across appropriate source, destination, or explicitly modeled external accounts. A correction posts a new reversing transaction; it never edits the original entry.

### `stock_counts` and `stock_count_lines`

Physical reconciliation sessions and observations. Approval posts ledger adjustments; the count itself never overwrites a balance.

### `transfers`

Movement of custody between locations or custodians.

Key fields:

- `id`, `public_reference`
- `source_account_scope`, `destination_account_scope`
- `status`
- `requested_at`, `authorized_at`, `dispatched_at`, `received_at`
- `requested_by`, `authorized_by`, `dispatched_by`, `received_by`
- `related_order_id` nullable
- `custody_terms`

### `transfer_lines`

Item quantities or serialized asset references. Dispatch posts movement to an in-transit account when appropriate; receipt posts movement to the destination. Cancellation after dispatch requires a return or exception workflow, not deletion.

### `consignment_agreements`

Effective-dated commercial terms linking owner, consignee, jurisdiction, price/settlement policy, reporting frequency, loss terms, and allowed items.

### `consignment_reports`

Dealer-reported sales, returns, losses, and on-hand observations. Reports are claims until accepted through an authoritative reconciliation or settlement function.

## 10. Serialized assets and custody

### `serialized_assets`

One record per individually controlled item.

Key fields:

- `id`, `asset_code`, `item_id`
- `serial_or_marking` nullable
- `status`
- `registered_at`, `registered_by`
- `provenance_summary` subject to visibility controls

Do not treat an asset's editable `current_holder` column as authoritative.

### `asset_events`

Append-only lifecycle and custody events.

Key fields:

- `asset_id`, `event_type`
- `occurred_at`, `recorded_at`, `recorded_by`
- `from_custodian_party_id`, `to_custodian_party_id`
- `from_location_id`, `to_location_id`
- `condition_before`, `condition_after`
- `transfer_id`, `order_line_id`, or `compliance_case_id` nullable
- `accepted_by` and `accepted_at` when custody acceptance is required
- `reversal_of_id` nullable
- `reason`

Authoritative functions enforce a valid event sequence and exactly one current custody state.

### `asset_reservations`

Exclusive, time-bounded allocation of a serialized asset to an order line or approved purpose. A partial unique-asset reservation is impossible.

### `asset_inspections`

Inspection observations, condition, custodian confirmation, next due date, evidence references, and findings. Sensitive evidence uses private object storage with access controls.

## 11. Compliance

### `compliance_cases`

Case container linked through join tables to parties, licenses, orders, transfers, or assets.

Key fields:

- `id`, `case_reference`, `case_type_id`
- `status`
- `opened_at`, `opened_by`, `assigned_to`
- `confidentiality_level`
- `summary`, `closed_at`, `resolution`

### `inspections`

Scheduled or completed compliance activity with scope, participants, observations, and evidence references.

### `allegations` and `findings`

Separate tables or explicitly separated record types. A finding must not be inferred merely because an allegation exists.

### `enforcement_actions`

Recorded actions such as notice, condition, quota adjustment, suspension, seizure, or revocation. Exact types are configurable.

Key fields:

- `case_id`, `action_type_id`
- `subject_type`, `subject_id`
- `status`
- `effective_from`, `effective_until`
- `authorized_by`, `authorized_at`
- `reason`, `public_notice_text` nullable

If an action changes another domain's state, one function must post both the enforcement action and the domain transition atomically.

### `appeals`

Links appellant, challenged action, filing date, status, reviewer, decision, and effective outcome. Whether an appeal stays an action is policy-controlled.

## 12. Audit, integrations, and projections

### `audit_log`

Append-only record of consequential activity.

Key fields:

- `id`, `occurred_at`
- `actor_id`, `auth_user_id`, `actor_type`
- `action`
- `record_type`, `record_id`
- `previous_state`, `new_state`
- `reason`
- `request_id`, `correlation_id`
- `source_surface`
- `sensitivity_class`

Write access is limited to trusted functions. Update and delete are denied. A redaction policy must govern sensitive snapshots.

### `outbox_events`

Durable events created in the same transaction as business state.

Key fields:

- `id`, `event_type`, `aggregate_type`, `aggregate_id`
- `payload_version`, `payload`
- `occurred_at`, `available_at`
- `status`, `attempt_count`, `last_error`
- `deduplication_key`

### `integration_deliveries`

One row per event destination and attempt history or delivery summary.

Key fields:

- `outbox_event_id`, `destination_type`, `destination_reference`
- `status`, `attempt_count`
- `first_attempted_at`, `delivered_at`, `last_error`
- `external_message_id` nullable

An external message ID is delivery metadata, not business authority.

### `export_definitions`

Approved projection source, column contract, destination reference, refresh policy, and visibility.

### `export_runs`

Records watermark, row count, generated-at time, checksum, destination version, status, attempts, and error. It does not import Sheet edits.

### Public views and functions

Expected projections include:

- `public_catalogue_v`
- `public_license_verification(...)`
- `public_dealer_verification(...)`
- `dealer_catalogue(...)`
- `dealer_order_summary(...)`
- `staff_inventory_position_v`
- `staff_work_queue_v`

The implemented public functions are `public_license_verification(text)` and `public_dealer_verification(text)`. They return one fixed response row and indistinguishable unknown, malformed, unpublished, private-record, and non-public-status behavior. Other names remain provisional.

## 13. Cross-domain invariants

The database and secure business functions must enforce at least these invariants:

1. A submitted order line retains its price, eligibility, and control-rule provenance.
2. A reservation cannot exceed authoritatively available stock at commit time. Order submission may precede stock availability and does not itself create a reservation.
3. The same idempotency key cannot post the same business operation twice.
4. Posted inventory entries are immutable and corrections reference the original transaction.
5. A serialized asset has at most one active reservation and one current accepted custodian.
6. Unique-asset fulfillment references the specific asset, not only an item quantity.
7. A license cannot be active outside its effective interval or after a terminal revocation or surrender event.
8. An endorsement cannot authorize activity outside the containing license's authority or dates.
9. An actor can act for a dealer only within an active representative grant and session scope.
10. A dealer-facing or public query cannot expose private notes, risk data, evidence, credential metadata, or internal-only goods.
11. A quota hold and a stock reservation created for one order line commit or roll back together when policy couples them.
12. Dispatch and receipt record in-transit custody; post-dispatch cancellation cannot erase movement.
13. Consignment tracks owner and custodian independently.
14. A consequential status change creates both domain history and an audit record in the same transaction.
15. An integration failure cannot undo committed business state, and a retry cannot duplicate business state.

## 14. Transaction boundaries and concurrency

Candidate secure functions, with final names to be decided during implementation:

- `submit_order`
- `evaluate_order_line`
- `approve_order_line`
- `reserve_inventory`
- `release_reservation`
- `expire_reservations`
- `post_inventory_transaction`
- `reverse_inventory_transaction`
- `dispatch_transfer`
- `receive_transfer`
- `allocate_serialized_asset`
- `transfer_asset_custody`
- `issue_license`
- `change_license_status`
- `grant_endorsement`
- `apply_enforcement_action`

Each function must:

- Authenticate the actor and resolve scoped authorization
- Re-read relevant current records inside the transaction
- Validate the state transition and approved policy version
- Use row locks, advisory locks, serializable isolation, or equivalent protection appropriate to the invariant
- Apply all coupled records atomically
- Record domain history and audit data
- Emit outbox events when needed
- Return a stable typed result
- Handle retry safely through an idempotency key where the caller may repeat a request

## 15. Row-level security direction

RLS is required on every exposed table.

- Anonymous users receive no direct table grants; they query explicit public views/functions.
- Dealer sessions can read only the parties they represent and records intentionally exposed to that relationship.
- Dealer writes are limited to safe draft or request inputs and preferably routed through secure functions.
- Staff access is constrained by active role assignment, jurisdiction, warehouse, and subject scope.
- Integration principals can execute only purpose-built projection or delivery functions.
- Service-role credentials remain server-only and are not a substitute for application authorization checks.
- Audit, compliance evidence, access grants, external identities, and contact data receive especially narrow policies.

RLS policy tests must include anonymous, wrong dealer, expired representative, cross-region staff, correct role, elevated role, and integration-principal cases.

## 16. Data import and migration

Legacy workbook import is staged, never loaded directly into authoritative tables.

Suggested flow:

1. Store the source file and checksum outside public access.
2. Import raw rows into a restricted staging schema with source sheet and row identifiers.
3. Normalize numeric money, Boolean display values, item names, categories, and duplicate records.
4. Map duplicated catalogue rows to one canonical item and explicit price rules.
5. Treat ambiguous limits such as blank, `None`, or `0` as unresolved mappings, not assumptions.
6. Validate references, conflicts, required fields, and totals.
7. Produce an exception report for product-owner decisions.
8. Promote approved mappings through an idempotent migration or import function.
9. Retain provenance so each imported record can be traced to its source row.

## 17. Assumptions

- PostgreSQL extensions used by Supabase may support cryptography, scheduling, and UUID generation, subject to environment review.
- Multiple representatives may act for one dealer, and one actor may represent multiple parties.
- Inventory uses a double-entry-style movement model for fungible stock and an event model for serialized assets.
- Reservations are claims separate from physical ledger balances.
- Business state and integration delivery state reside in the same PostgreSQL project but have distinct permissions.
- Public references are non-secret identifiers; private access tokens are separate, high-entropy secrets.

## 18. Unresolved modeling decisions

- Whether authorization rules use fully normalized policy tables, a constrained JSON rule format, or a versioned hybrid
- Whether stock ledger quantities are signed single-account entries or explicit debit/credit pairs at the API boundary
- Unit-of-measure conversion requirements and whether fractional quantities are allowed
- Exact owner and custodian parties for received, in-transit, sold, destroyed, seized, and unknown stock accounts
- Whether quotas are reserved on submission, approval, or stock reservation; order submission itself is permitted without stock
- Whether circulation ceilings are another quota policy or a separate aggregate constraint
- Price rule precedence and allowed calculation forms; price records may be absent and must never default to zero
- Reservation extension limits and detailed transfer, consignment, and settlement granularity beyond approved partial order handling
- Which license conditions require normalized enforcement fields
- Whether factor assignments are always staff identities or may represent contracted external parties
- Public-reference formats and whether identifiers encode jurisdiction or class
- Public history retention after expiration, revocation, correction, merger, or party rename
- Evidence storage, encryption, redaction, deletion, and legal retention policy
- Required historical snapshots for catalogue presentation and generated documents

These decisions must be captured in an approved decision record before the corresponding migrations are implemented.

