# ADR 0020: Launch command suite

Status: Accepted  
Date: 2026-08-10

## Context

The production foundation could manage catalogue, dealers, issued licenses, dealer-entered orders, inventory, procurement, fulfillment, transfers, consignments, serialized assets, compliance casework, exports, and Discord integrations. Server launch still required staff-assisted customer intake, a direct premium channel, enforceable personal limits, public licensing intake, financial settlement evidence, unique delivery, configured enforcement effects, official records, and one operational overview.

The owner approved a mixed commercial model: licensed businesses receive applicable wholesale terms; an individual may buy directly through an EEC agent but pays three times the public base price. Per-item weekly personal limits remain configurable. License durations and consignment commission rates are not universal and must not be guessed.

## Decision

1. Orders identify one of three channels: dealer self-service, staff-assisted licensed business, or direct individual.
2. Staff-assisted business entry revalidates a current dealer authorization and a current authority-conferring license. The staff actor is recorded as the entering EEC agent.
3. Direct customers receive stable private registry profiles. Direct goods must be explicitly enabled by item supply policy.
4. Direct pricing is `public base price × 3` (`30000` basis points). The chosen schedule, rule, base amount, multiplier, result, currency, and precedence source are snapshotted on every order line.
5. Personal limits use an institution-time-zone weekly window. Submission creates a quota hold, fulfillment consumes it, and denial or cancellation releases it. A database advisory lock serializes competing requests for the same customer, item, and week.
6. Price precedence is: specific party, license class, dealer type, jurisdiction, channel default, then an unbound audience fallback. Effective dates and explicit priority break ties.
7. Anyone may submit a license application or renewal without login. The applicant receives a private status token whose digest alone is stored. A licensing officer supplies the holder, term, and decision; no default duration or grace period is invented.
8. Consignment commission is effective-dated per agreement. An accepted report plus actual unit sale price produces a frozen gross, commission, and owner amount. Payment evidence is recorded, but this is not a treasury general ledger.
9. Unique fulfillment atomically consumes the exact serialized-asset reservation, transfers custody to the ordering party, fulfills the line, derives order status, and records an immutable fulfillment receipt source.
10. Compliance action types may specify one narrow effect: suspend the exact license, suspend the exact dealer authorization, cancel the exact unfulfilled order, or seize the exact unreserved asset. The effect executes atomically only after an authorized action review and stores exact previous/new state.
11. Official PDFs are projections of immutable generated-document snapshots. Each PDF displays the source record/version and SHA-256 checksum.
12. A cross-domain command dashboard reports work and exceptions but does not correct business state automatically.

## Consequences

- Frontend code collects intent but does not calculate authoritative prices, quotas, commissions, sanctions, custody, or status.
- Direct orders fail closed when a public base price is unavailable or the weekly limit would be exceeded.
- Order submission remains possible without stock; reservation and fulfillment remain separate.
- Google Sheets, Discord, and PDFs remain projections of Supabase records.
- Commission rates, license terms, eligibility, grace periods, payment execution, and appeal-stay policy still require institutional decisions where not explicitly configured.

