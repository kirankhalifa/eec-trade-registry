# ADR 0002: Staff authentication and canonical draft management

Status: Accepted for the first Slice 2 increment

## Context

The roadmap calls for staff catalogue management, but catalogue approval authority, publication timing, backdating, price precedence, item-code correction, MFA, and production identity-provider policy are unresolved. Implementing those decisions now would turn assumptions into institutional policy.

The platform still needs a usable, testable authorization boundary before adding higher-risk workflows.

## Decision

- Use Supabase Auth cookie sessions through `@supabase/ssr`; verify server requests with `getClaims` rather than trusting an unverified cookie session.
- Keep authentication separate from business authority through actor profiles, configurable permission scopes and roles, and effective-dated staff assignments.
- Seed one minimal configurable `catalogue_manager` role containing only internal catalogue read and canonical item management permissions.
- Expose staff catalogue data and commands only through fixed-search-path security-definer functions that resolve the authenticated actor and active assignment themselves.
- Permit creation of unpublished canonical items, edits to mutable internal fields, and explicit archive/restore transitions.
- Keep item code and slug immutable after creation until correction policy is approved.
- Require optimistic concurrency versions, audit reasons, request IDs, and complete before/after audit context for every write.
- Keep publication, pricing, control-policy, role administration, and production identity policy outside this increment.

## Consequences

- A signed-in user with no active assignment receives no catalogue authority.
- Staff clients do not receive direct table grants and cannot bypass the command functions.
- Concurrent edits fail instead of silently overwriting one another.
- Archiving immediately affects the existing public projection because item status is authoritative, while historical publication and price records remain intact.
- Local staff users require an explicit development bootstrap assignment; production provisioning is not yet implemented.
- This foundation can accept approved publication and pricing policies later without replacing the authentication or audit model.

## Alternatives considered

- Supabase Auth metadata claims as catalogue roles were rejected because assignment changes must be effective-dated, auditable, and evaluated from authoritative database records.
- Direct authenticated table policies were rejected because consequential writes require centralized validation, concurrency handling, and audit context.
- Implementing publication and price forms with assumed defaults was rejected because the required scheduling, backdating, and approval decisions remain unresolved.
