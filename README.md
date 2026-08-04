# EEC Trade Registry

A configurable trade, licensing, wholesale distribution, inventory, and compliance platform. Supabase PostgreSQL is the sole authoritative data source; the web portal and future integrations are projections of its records.

The active implementation includes the unauthenticated public catalogue, policy-neutral staff catalogue management, and exact-reference public dealer and license verification. Dealer sessions, license application and issuance workflows, ordering, warehouse inventory, Discord, and Google Sheets remain documented but unimplemented.

## Repository layout

```text
apps/portal/              Next.js public portal
supabase/migrations/      Versioned PostgreSQL schema and functions
supabase/tests/database/  pgTAP database and permission tests
supabase/seed.sql         Fictional development catalogue data
docs/                     Product and engineering documentation
```

## Requirements

- Node.js 20.9 or newer
- npm 10 or newer
- Docker-compatible runtime for the local Supabase stack

## Setup

```bash
npm install
# macOS/Linux: cp .env.example apps/portal/.env.local
# PowerShell: Copy-Item .env.example apps/portal/.env.local
npm run db:start
npm run db:reset
npm run dev
```

After `supabase start`, replace the placeholder in `.env.local` with the local anon key printed by the CLI. Never place the service-role key in a browser environment variable.

## Checks

```bash
npm run lint
npm run typecheck
npm run test
npm run build
npm run db:test
npm run db:lint
```

`npm run check` runs the application checks together. Database checks require the local Supabase stack.

## Database workflow

All schema changes belong in `supabase/migrations`. Development data belongs in `supabase/seed.sql`. Use `npm run db:reset` to rebuild the local database from migrations and seed data, and `npm run db:test` to execute pgTAP tests.

Do not make authoritative schema changes only through the hosted dashboard. See `AGENTS.md` for the complete engineering rules.

## Local staff access

The staff portal is available at `http://127.0.0.1:3000/staff/login`. Authentication alone grants no catalogue access.

For local development only:

1. Open local Supabase Studio at `http://127.0.0.1:54323`.
2. Create an email/password user under Authentication and copy its user UUID.
3. In the local SQL editor, assign the existing configurable catalogue role:

```sql
with created_actor as (
  insert into public.actor_profiles (auth_user_id, display_name)
  values ('<AUTH_USER_UUID>', 'Local Catalogue Manager')
  returning id
)
insert into public.staff_assignments (actor_id, staff_role_id)
select created_actor.id, role.id
from created_actor
join public.staff_roles as role on role.code = 'catalogue_manager';
```

This bootstrap procedure is for disposable local environments. Production staff provisioning, recovery, MFA, and access review remain policy-gated and require a controlled administrative workflow.

## Public verification fixtures

After `npm run db:reset`, the public verification pages are available at:

- `http://127.0.0.1:3000/verify/dealer` with fictional reference `DLR-DEMO-A7K9`
- `http://127.0.0.1:3000/verify/license` with fictional reference `LIC-DEMO-4Q2M`

These are demonstration records, not approved institutional terminology or policy. Public lookups use exact references and return the same `not_verifiable` contract for unknown, malformed, private, and unpublished records. Production launch still requires edge rate limiting and abuse monitoring.
