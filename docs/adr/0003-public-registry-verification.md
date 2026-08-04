# ADR 0003: Exact-reference public registry verification

Status: Accepted for the policy-neutral implementation increment
Date: 2026-08-04

## Context

The public must be able to verify approved dealer authorizations and issued licenses without authenticating. Party identity, internal standing, private notes, applications, contacts, and compliance records must remain private. Public reference formats, disclosure policy, staff authority, issuance policy, and production abuse thresholds are unresolved.

## Decision

- Store parties, dealer authorizations, licenses, classes, endorsements, conditions, jurisdictions, and public status labels as normalized Supabase records.
- Keep dealer authorization and licensing separate; neither implies the other.
- Require both party-level and record-level public disclosure before a record can be projected.
- Expose anonymous reads only through fixed-search-path `security definer` functions with explicit field lists. Grant no direct table access.
- Accept exact references only. Normalize case, surrounding whitespace, and repeated whitespace while leaving the numbering vocabulary configurable.
- Return one fixed-contract row for every lookup. Unknown, malformed, private, unpublished, and non-public-status records all return `not_verifiable` without echoing stored fields.
- Keep public result labels and authority semantics configurable through status-definition records. Independently derive that an elapsed effective term cannot confer current authority.
- Treat verification as read-only. It creates no authority and makes no eligibility, pricing, stock, allocation, or transaction decision.

## Consequences

The public portal can verify fictional seeded records without exposing source tables or private fields. Exact lookup avoids introducing unapproved name-search and enumeration behavior. Database tests cover grants, RLS, non-enumeration, term expiry, and field leakage.

This increment does not authorize staff to create, issue, renew, suspend, reinstate, revoke, or surrender records. It also does not implement party representatives, dealer sessions, factor assignments, rate limiting, abuse monitoring, or production reference generation. Those require the unresolved policies in the roadmap and must use audited authoritative commands when implemented.
