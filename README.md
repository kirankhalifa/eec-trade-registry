# EEC Trade Registry

A configurable trade, licensing, wholesale distribution, inventory, and compliance platform. Supabase PostgreSQL is the sole authoritative data source; the web portal and future integrations are projections of its records.

The active implementation slice is the unauthenticated public catalogue. Dealer access, licensing, ordering, warehouse inventory, Discord, and Google Sheets remain documented but unimplemented.

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
