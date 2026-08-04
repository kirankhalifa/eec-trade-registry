# ADR 0004: Credential-based dealer registry access

Status: Accepted for the policy-neutral implementation increment
Date: 2026-08-04

## Context

Dealer representatives need low-friction private access, but authentication must not imply authority to act for an organization. The product permits lightweight credentials or secure private links. Enrollment, credential recovery, private-link reuse, organization switching, private pricing, ordering, and step-up authentication policies remain unresolved.

## Decision

- Implement the lightweight credential path first with Supabase Auth sessions.
- Represent an authenticated dealer as an `actor_profile` with stable machine type `dealer`.
- Store authority to act for an organization in separate, effective-dated `party_representatives` records with configurable role definitions, constrained JSON scopes, verification metadata, revocation, overlap protection, and audit triggers.
- Recognize only the policy-neutral `portal.read` scope in this increment.
- Require a current representation and a current dealer authorization whose configured status confers authority.
- Expose private data only through `get_dealer_portal_overview()`, a fixed-search-path security-definer function. Authenticated callers have no direct source-table reads.
- Return only organizations linked to the current dealer actor. Include dealer and license summaries, current endorsements, and public conditions; exclude private notes, legal names, unrelated parties, pricing, orders, stock, standing, applications, and compliance data.
- Keep the portal read-only. It performs no eligibility, price, quota, allocation, reservation, or transaction calculation.

## Consequences

An individually authenticated representative can review the registry records of each currently represented, actively authorized dealer organization. Expired, revoked, unscoped, staff, and inactive-dealer access fails closed at the database boundary. Cross-organization isolation is covered by pgTAP tests.

Secure-link token issuance and exchange, representative enrollment administration, organization selection for future commands, credential recovery, magic links, step-up authentication, and dealer transaction workflows remain explicitly deferred until their policies are approved.
