# EEC Platform Engineering Rules

This file applies to the entire repository. Read it before planning or changing code, schema, infrastructure, integrations, or product documentation.

## 1. Mission and current scope

Build a configurable trade, licensing, wholesale distribution, inventory, and compliance platform. Preserve institutional auditability without hard-coding setting-specific terminology when configuration will work.

The product owner authorized implementation on 2026-08-04. The active scope is the policy-neutral credential-based dealer portal foundation in `docs/ROADMAP.md`: dealer actor profiles, effective-dated representative grants, organization isolation, and a private read-only registry overview resolved by Supabase. Secure-link exchange, enrollment administration, license lifecycle commands, private pricing, orders, reservations, inventory, integrations, and compliance remain out of scope until their policy gates are resolved.

## 2. Required reading

Before implementation work, read the documents relevant to the task:

- `docs/PRODUCT_SPEC.md` for product boundary, principles, assumptions, and policy questions
- `docs/DATA_MODEL.md` for conceptual entities, invariants, transaction boundaries, and RLS direction
- `docs/WORKFLOWS.md` for transitions, user journeys, and failure behavior
- `docs/PERMISSIONS.md` for roles, scopes, data classification, and exposure rules
- `docs/ROADMAP.md` for sequencing, slice boundaries, and release gates

If a task conflicts with these documents, stop and surface the conflict. Update the governing documentation or record an approved architecture/policy decision before implementing a different behavior.

## 3. Source of truth

Supabase PostgreSQL is the only authoritative data source.

Google Sheets, Discord messages, generated documents, caches, search indexes, and public exports are projections of database records. They must not maintain independent business state or become a fallback authority when Supabase is unavailable.

Projection records must be rebuildable, identify their source or watermark where appropriate, and display freshness when users could mistake them for current state.

## 4. Business logic

Business-critical operations must run through database functions or secure server functions. Frontend code must not independently calculate authoritative:

- Inventory balances or availability
- License or endorsement eligibility
- Quota or circulation consumption
- Reservations
- Prices or price overrides
- Order approval
- Custody or title transfers
- Compliance effects

Clients may display clearly labeled estimates for usability. The authoritative function must re-read current state and revalidate on submission.

Every consequential command must define:

- Authenticated actor and represented party, if any
- Required permission and assignment scope
- Allowed source states and target state
- Transaction boundary and coupled records
- Concurrency strategy
- Idempotency behavior
- Audit and domain-history records
- Outbox events
- Stable success and error contract

## 5. Inventory and custody

Inventory is ledger-based. Never directly overwrite an item's calculated current stock.

- Posted ledger entries are immutable.
- Correct errors with linked reversal and corrective transactions.
- Reservations are explicit claims separate from physical on-hand quantity.
- Available stock is derived from posted stock and active reservations under approved policy.
- Inventory posting and reservation functions must be safe under concurrent requests.
- Model in-transit stock explicitly.
- Model owner and custodian separately where consignment or other custody arrangements require it.
- Track individually controlled goods as serialized assets with append-only custody/lifecycle events.
- Never store an editable `current_holder` or similar field as the sole authority for a unique asset.

Negative stock, backdating, large adjustments, custody corrections, and destructive asset lifecycle events require an explicit approved policy and elevated authorization.

## 6. Auditability

Every consequential staff or integration action must record:

- Actor and authentication context
- Action
- Record affected
- Previous state
- New state
- Timestamp
- Optional or policy-required reason
- Request or correlation identifier
- On-behalf-of or represented-party context where applicable

Audit records are append-only. Domain status/event history and the audit log must be written in the same transaction as the change they describe.

Do not leak secrets or unnecessary restricted data into audit snapshots. Follow the approved redaction and retention policy once defined.

## 7. Security

Never commit secrets.

Never expose:

- Supabase service-role keys
- Discord bot tokens
- Discord webhook URLs
- Google service-account credentials
- Private status or access tokens
- Private-link raw tokens
- Signing or encryption keys

Additional requirements:

- Enable row-level security on every table exposed through Supabase APIs.
- Deny by default and grant the narrowest permissions.
- Anonymous users query explicit public views or functions only.
- Dealer access is restricted to actively represented parties and approved fields.
- Staff access is scoped by active role, jurisdiction, warehouse, portfolio, state, and approval limit.
- UI visibility is not authorization.
- Never trust caller-supplied actor, party, role, price, region, warehouse, or permission claims.
- Store only strong digests of private-link tokens; prefer single-use, short-lived exchange for scoped sessions.
- Keep service-role credentials server-side. RLS bypass does not replace authorization inside server operations.
- Give each integration a distinct, purpose-limited principal and secret.
- Fix `search_path`, validate inputs, and explicitly grant execution for any `security definer` function.
- Rate-limit and monitor public catalogue, verification, and Discord lookup endpoints.
- Never use real production credentials or sensitive personal data in tests, fixtures, screenshots, or examples.

## 8. Configurability and terminology

Do not hard-code Elder Scrolls or other deployment-specific terminology when configuration would work.

Prefer configuration/reference data for:

- Organization, region, office, warehouse, rank, and factor titles
- License classes and endorsements
- Item categories, tags, and control profiles
- Price schedules, quota windows, circulation rules, and approval policies
- Currency and calendar display
- Public status messages, notices, document prefixes, seals, and templates
- Discord channel mappings and Google export destinations

Stable machine states may be fixed when their process semantics must be tested. Keep user-facing labels configurable. Never infer policy from an item name, category display label, spreadsheet tab, Discord role name, or free-text condition.

## 9. Database development

- Use a versioned database migration for every schema, function, policy, trigger, view, grant, seed-configuration, or extension change.
- Never make an undocumented manual production schema change.
- Prefer forward fixes after deployment; document any safe rollback path.
- Keep migrations deterministic and safe to apply in the intended order.
- Qualify database objects and avoid unsafe mutable `search_path` behavior.
- Use constraints for local invariants and authoritative functions for cross-record transitions.
- Use effective-dated records for changing rules and authorizations.
- Store timestamps in UTC and money as integer minor units with currency metadata.
- Keep public human-readable references separate from internal primary keys.
- Avoid arbitrary executable rule expressions stored as data. Use a constrained, versioned, deterministic rules model.
- Stage imports in restricted tables; validate, normalize, report exceptions, and preserve provenance before promotion.
- Treat blank, `None`, `0`, duplicated, or conflicting legacy values as unresolved data unless mapping policy explicitly defines them.

## 10. Concurrency and idempotency

Any operation that allocates, reserves, approves, posts, transfers, or changes authority must be designed for concurrent callers.

- Choose row locks, advisory locks, serializable transactions, unique constraints, compare-and-swap versioning, or another explicit mechanism appropriate to the invariant.
- Add idempotency keys to commands that may be retried after timeouts or queue redelivery.
- A repeated logical request must not duplicate orders, approvals, quota entries, reservations, ledger transactions, custody events, messages, documents, or exports.
- Test races such as the final stock unit, final quota unit, reservation expiry versus fulfillment, and two requests for one serialized asset.
- Never fix a concurrency problem solely by disabling a button in the UI.

## 11. Integrations and generated artifacts

- Use a transactional outbox or equivalent durable pattern for notifications and exports.
- Commit business state before external delivery.
- Record delivery attempts, failures, destination, and external message/version identifiers.
- Make delivery retryable and idempotent.
- A failed integration must not roll back or mutate committed business state.
- Discord lookups query approved functions at request time.
- Discord messages, reactions, and edits are not approvals or fulfillment evidence.
- Google Sheets are one-way projections; never import arbitrary edits as business state.
- Generated licenses, invoices, manifests, and notices are snapshots with source record and generation metadata, not editable authority.

## 12. TypeScript and application code

- Use TypeScript for application, worker, and integration code.
- Enable strict type checking; do not normalize unsafe `any` use.
- Generate or maintain database types from the reviewed schema, but do not confuse generated types with authorization.
- Keep domain commands and projection queries behind clear server interfaces.
- Validate external input at every trust boundary.
- Return stable machine error codes with safe user messages and request IDs.
- Keep clients presentation-focused and free of duplicated business rules.
- Keep modules focused; avoid circular dependencies and cross-surface imports that bypass intended boundaries.
- Do not add a dependency without explaining its need, license, maintenance risk, and security impact when material.

## 13. Testing

Add tests for every business rule and authorization path introduced.

At minimum, affected work should cover:

- Allowed and forbidden state transitions
- Anonymous and authenticated RLS behavior
- Correct dealer, wrong dealer, expired representative, and revoked access cases
- Correct staff role, wrong region/warehouse, insufficient approval tier, and prohibited self-approval
- Price-rule precedence and effective dates
- License/endorsement validity and condition enforcement
- Quota hold, consumption, release, reset, and reversal
- Reservation concurrency, expiry, extension, consumption, and retry
- Ledger balance, reversal, reconciliation, and immutable posted history
- Unique-asset reservation and single-custodian invariants
- Outbox retry and deduplication
- Public and dealer projections for restricted-field leakage
- Migration behavior against representative data

Use deterministic time and IDs where useful. Prefer tests of database functions and RLS for authoritative rules; frontend tests do not substitute for them.

## 14. Documentation and policy decisions

- Document assumptions explicitly.
- Maintain unresolved policy questions in the governing specification until the product owner decides them.
- Do not silently convert an assumption, example, or seed value into policy.
- Record material architecture and policy decisions in a durable decision record, including context, decision, alternatives, and consequences.
- Update product, data model, workflow, permission, and roadmap documents in the same focused change when behavior changes.
- Use generic examples unless setting-specific vocabulary is intentionally configured seed content.

If a required policy decision is missing, implement only the policy-neutral foundation that is clearly in scope or stop and request the decision. Do not invent institutional authority.

## 15. Change discipline

- Keep pull requests focused; do not combine unrelated features.
- Use one branch per issue or coherent change.
- Read existing migrations and relevant documents before editing.
- Inspect the working tree and preserve unrelated user changes.
- Explain data, permission, migration, and integration impact in the pull request.
- Include tests run, results, risks, and unresolved decisions.
- Avoid drive-by formatting or dependency upgrades.
- Do not merge generated files that contain secrets, machine-specific paths, or private data.
- Never rewrite shared branch history or discard user changes without explicit authorization.

## 16. Definition of done

A change is complete only when all applicable items are true:

- Scope and policy dependencies are clear.
- Governing documentation agrees with the behavior.
- Schema changes are migrated and reviewed.
- Authoritative business logic is server-side and transactional.
- RLS, grants, field exposure, and storage policies are correct.
- Audit history and outbox behavior are present.
- Concurrency and idempotency are addressed.
- Business-rule and permission tests pass.
- Types, formatting, and relevant builds pass.
- No secret or restricted fixture data is introduced.
- Operational and rollback/forward-fix implications are documented.
- The pull request contains only the intended change.

## 17. Prohibited shortcuts

Do not:

- Use Google Sheets, Discord, browser storage, or generated documents as authoritative business state
- Store or edit a `current_stock` value as the inventory authority
- Delete or rewrite posted ledger entries or custody history
- Calculate authoritative eligibility, quota, reservations, prices, or custody in frontend code
- Grant broad table access because a UI currently hides sensitive fields
- Use the Supabase service role in a browser or expose it to an integration client
- Store raw private-link tokens
- Model license classes as duplicated catalogues
- Conflate dealer authorization, licensing, endorsement, pricing, and allocation
- Infer permissions from Discord display roles without verified binding and database authorization
- Hard-code item-name checks or lore-specific categories into business logic
- Implement unresolved policy by guessing
- Mark a feature complete without business-rule and permission tests

When a requested shortcut conflicts with these rules, explain the conflict and propose a compliant path before proceeding.

