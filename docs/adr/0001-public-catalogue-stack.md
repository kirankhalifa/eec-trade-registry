# ADR 0001: Public catalogue implementation stack

Status: Accepted for Slice 1
Date: 2026-08-04

## Context

The first roadmap slice requires a searchable public catalogue with no login, while Supabase PostgreSQL remains the sole authority. The repository had documentation but no application or database tooling. The product owner authorized implementation without selecting a web framework, package manager, hosting provider, locale, currency, or final setting vocabulary.

## Decision

- Use a small npm workspace with a Next.js App Router application in `apps/portal`.
- Use strict TypeScript for all application code.
- Query only purpose-built Supabase RPC functions with the public anon key. The portal receives no direct table privileges and never uses a service-role key.
- Use versioned SQL migrations and pgTAP tests under `supabase/`.
- Keep display vocabulary, currency presentation, control profiles, and availability language in database records. Development seed values are fictional examples rather than institutional policy.
- Render catalogue data on the server per request. Search and category filtering are parameters to the authoritative public projection.
- Do not introduce Tailwind, a component framework, or state-management dependency for this slice; plain CSS is sufficient and reduces initial surface area.

## Consequences

- The public catalogue is end-to-end and deployable once a Supabase project and web host are selected.
- Public data exposure can be tested at the database boundary.
- Docker is required to execute the full local Supabase test suite.
- Hosting, staff authentication, production locale/currency, and future app boundaries remain unresolved and can be decided without replacing the Slice 1 data contract.

## Alternatives considered

- A static JSON catalogue was rejected because it would create business state outside Supabase.
- Direct browser table queries were rejected because anonymous users must not receive broad table grants.
- A larger multi-app scaffold was deferred because the current slice has only one user-facing surface.
