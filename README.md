# EEC Trade Registry

A configurable trade, licensing, wholesale distribution, inventory, and compliance platform. Supabase PostgreSQL is the sole authoritative data source; the web portal and future integrations are projections of its records.

The active implementation includes the unauthenticated public catalogue, Discord OAuth staff sign-in with database-authorized staff operations, exact-reference public dealer and license verification, credential-based dealer access with effective-dated representation, an audited staff licensing office, wholesale order intake, warehouse ledger and reservation operations, fungible fulfillment, warehouse transfers, serialized-asset custody, and one-way projection integrations. Dealers can submit and track requisitions without price or stock on hand; authorized staff can review them, post balanced fungible receipts, derive on-hand/available positions, manage 48-hour stock reservations, atomically consume a reservation into a balanced stock issue, move stock through explicit in-transit custody, and register, exclusively allocate, transfer, inspect, lose, recover, seize, retire, or destroy individually controlled goods through append-only custody evidence. A leased worker replaces approved public Google Sheet tabs and delivers allowlisted Discord alerts, while signed Discord commands expose only the existing public catalogue and verification contracts. Applications, renewal, unique-asset fulfillment, consignment, reconciliation, compliance cases, and generated documents remain future policy-gated work.

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

After `supabase start`, replace the placeholder in `.env.local` with the local anon key printed by the CLI. Set `NEXT_PUBLIC_SITE_URL` to the exact portal origin; production requires HTTPS. Never place the service-role key in a browser environment variable.

The integration variables in `.env.example` are server-only. Leave destinations disabled when credentials are absent. A copied placeholder is intentionally invalid and must never be used in production.

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

The staff portal is available at `http://127.0.0.1:3000/staff/login`. It presents Discord OAuth only; there is no staff email/password form. Supabase Auth owns the application session, and authentication alone grants no staff access.

For local development only:

1. Configure a Discord developer application with the local Supabase callback `http://localhost:54321/auth/v1/callback` and enable the Discord provider in local Supabase Auth.
2. Complete Discord sign-in once, open local Supabase Studio at `http://127.0.0.1:54323`, and copy the resulting user UUID.
3. In the local SQL editor, assign the existing configurable catalogue role to that exact identity:

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

This bootstrap procedure is for disposable local environments. In production, provider enrollment and actor/role assignment are separate controlled operations. The Discord display name is never an identity key. MFA, recovery, and access-review details remain policy-gated.

## Public verification fixtures

After `npm run db:reset`, the public verification pages are available at:

- `http://127.0.0.1:3000/verify/dealer` with fictional reference `DLR-DEMO-A7K9`
- `http://127.0.0.1:3000/verify/license` with fictional reference `LIC-DEMO-4Q2M`

These are demonstration records, not approved institutional terminology or policy. Public lookups use exact references and return the same `not_verifiable` contract for unknown, malformed, private, and unpublished records. Production launch still requires edge rate limiting and abuse monitoring.

## Local dealer access

The dealer portal is available at `http://127.0.0.1:3000/dealer/login`. Authentication alone grants no organization access.

For local development only:

1. Create an email/password user in local Supabase Studio and copy its user UUID.
2. In the local SQL editor, link that identity to the fictional seeded dealer:

```sql
with created_actor as (
  insert into public.actor_profiles (
    auth_user_id,
    display_name,
    actor_type
  )
  values (
    '<AUTH_USER_UUID>',
    'Local Dealer Representative',
    'dealer'
  )
  returning id
)
insert into public.party_representatives (
  principal_party_id,
  actor_id,
  role_definition_id,
  authority_scope,
  verified_at
)
select
  '92000000-0000-0000-0000-000000000001',
  created_actor.id,
  role.id,
  '{
    "portal.read": true,
    "order.read": true,
    "order.create": true,
    "order.cancel": true
  }'::jsonb,
  now()
from created_actor
join public.representative_role_definitions as role
  on role.code = 'portal-representative';
```

The overview remains read-only, while `/dealer/orders` exposes only the represented party's order projection and secure order commands. Submission records demand but does not reserve or move stock. Production enrollment, recovery, revocation operations, magic links, and secure private-link exchange require approved administrative workflows.

## Local licensing access

The licensing office is available at `http://127.0.0.1:3000/staff/licensing`. A staff login also needs the configurable `licensing_officer` role. For disposable local development, follow the staff bootstrap pattern above and select `licensing_officer` instead of `catalogue_manager`.

Licensing commands allocate references, record immutable status/endorsement history, write full audit context, and enqueue durable outbox events in one transaction. The current issue form intentionally creates an open-term license because duration and renewal policy have not been approved.

## Local order desk access

The staff order desk is available at `http://127.0.0.1:3000/staff/orders`. A staff login also needs the configurable `order_officer` role. For disposable local development, follow the staff bootstrap pattern above and select `order_officer` instead of `catalogue_manager`.

The role contains separate read, routine review, ordinary, restricted, unique, price-edit, and cancellation permissions. The current desk never derives stock in the browser and cannot create a reservation or inventory movement.

## Local inventory access

The inventory desk is available at `http://127.0.0.1:3000/staff/inventory`. For disposable local development, follow the staff bootstrap pattern and select `warehouse_operator` for receipt and routine reservation work, or `inventory_controller` for linked receipt reversals as well.

An empty `assignment_scope` grants the role across configured warehouses. To restrict an assignment, set `assignment_scope` to `{"warehouse_ids":["<WAREHOUSE_UUID>"]}`. The seeded primary warehouse UUID is `aa000000-0000-0000-0000-000000000001`; no opening balance is seeded. Use the receipt command so every quantity originates in the immutable ledger.

## Local fulfillment access

The fulfillment desk is available at `http://127.0.0.1:3000/staff/fulfillment`. A `warehouse_operator` can consume an active fungible reservation, while an `inventory_controller` can also post a linked reversal. Completion consumes the claim, posts a balanced physical-to-external issue, increments fulfilled demand, derives line/order status, audits the exact assignment, and emits an outbox event in one database transaction. Reversal restores stock and reopens demand but deliberately leaves the original reservation consumed.

## Projection integrations

The integration console is available at `/staff/integrations` to an authenticated actor assigned the `integration_operator` role. It exposes destination identifiers and delivery metadata only; it never returns credentials. The seeded Google and Discord destinations and all Sheet schedules start disabled.

For Google Sheets:

1. Create a spreadsheet in the account that will own the public document.
2. Create a Google Cloud service account with the Sheets API enabled, then store its email and private key in the deployment's server-only environment variables.
3. Share the spreadsheet with the service-account email as an editor. Configure public viewer access in Google if this is the public registry Sheet.
4. In `/staff/integrations`, enter only the spreadsheet ID from its URL, activate the destination, then activate the approved catalogue, dealer, and license definitions.
5. Queue a manual snapshot and confirm the `Catalogue`, `Dealers`, and `Licenses` tabs show source and generated-at metadata. Scheduled replacement then runs every 15 minutes.

For Discord:

1. Add `https://<portal-origin>/api/discord/interactions` as the application's Interactions Endpoint URL.
2. Store `DISCORD_APPLICATION_ID`, `DISCORD_PUBLIC_KEY`, and the server-only bot token in the deployment environment. The bot needs only the permissions required to view and send messages in the selected private alert channel.
3. Optionally set `DISCORD_GUILD_ID` for immediate guild-scoped command testing. Omit it for global registration.
4. Register the declared commands once using the protected deployment endpoint. In PowerShell, load the cron secret into a process variable and call:

```powershell
$headers = @{ Authorization = "Bearer $env:EEC_CRON_SECRET" }
Invoke-RestMethod -Method Post -Headers $headers -Uri "https://<portal-origin>/api/admin/discord/register-commands"
```

5. Enter the numeric private alert channel ID in `/staff/integrations` and activate the destination only after a test message path is ready.

Supabase Cron invokes `/api/cron/integrations` every 15 minutes through `pg_net`. The migration creates the inactive-until-configured network job, but it sends no request until Supabase Vault contains both `eec_integration_worker_url` (the full production route URL) and `eec_integration_cron_secret` (the same value as Vercel `CRON_SECRET`). Create those two secrets in the Supabase Vault dashboard after the production deployment exists; never paste them into a migration. Do not make either protected route public through a proxy that strips authorization. Sheet edits, Discord commands, messages, emoji, and deletions never change source business data.
