# ADR 0010: One-way projection integrations

- Status: accepted
- Date: 2026-08-05

## Context

The platform requires public Google Sheet exports, Discord public lookups, and private staff alerts. Supabase PostgreSQL must remain the sole authority, integration failure must not roll back committed business work, and no external credential may be stored in a normal application record or browser bundle.

## Decision

- Store approved non-secret destinations, export contracts, notification templates, event routes, run metadata, leases, retries, and delivery results in Supabase.
- Keep the Supabase service-role key, Google service-account credentials, Discord bot token, Discord interaction public key, and cron secret in the managed server environment. Never return them from a staff projection.
- Seed every external destination and schedule inactive. An authorized `integration_operator` must configure an identifier and explicitly activate it with an audit reason.
- Run the delivery worker from a Vercel cron route protected by `CRON_SECRET`. The worker uses the service role only for narrowly granted projection and delivery functions.
- Export the public catalogue, dealer registry, and license registry as full Sheet-tab replacements every 15 minutes when enabled. Include source and generation metadata, record row count/checksum/range, and never read values back.
- Materialize Discord deliveries from transactional outbox events through versioned templates and routes. Use database deduplication, bounded retry, and time-bounded claims. Do not use webhooks; post with a server-only bot token and suppress mentions.
- Expose `/catalogue`, `/dealer`, and `/license` as read-only Discord application commands. Verify the Ed25519 signature over the unmodified request body and reject stale requests. These commands call the same public disclosure boundaries as the website.
- Provide `/staff/integrations` for authorized monitoring, non-secret destination configuration, schedule activation, manual snapshots, and reasoned replay. Replay changes only delivery metadata and is audited.
- Keep Discord OAuth staff authentication separate from bot delivery and application commands. Neither guild state nor a Discord role grants business authority.

## Consequences

- A committed order, license, reservation, or inventory receipt survives a Google or Discord outage.
- Sheet edits, Discord messages, reactions, and message deletion have no path back into business tables.
- Operators can identify stale or failed work without seeing credentials and can replay only failed work through secured functions.
- Public Sheet creation, sharing, and ownership remain an external launch operation. The service account must receive edit access and public viewer access must be configured in Google.
- Global Discord commands may take time to propagate; guild-scoped registration is available for launch testing.
- Final channel ownership, retention, escalation, and any future private or state-changing Discord command require separate policy approval.

## Rejected alternatives

- Treating Google Sheets or Discord as writable administrative stores was rejected because it creates competing state and bypasses database rules.
- Sending notifications synchronously inside business transactions was rejected because an external outage would prevent authoritative work from committing.
- Storing bot, webhook, Google, or service-role credentials in destination rows was rejected because staff-readable configuration must remain non-secret.
- Anonymous export enumeration endpoints were rejected because the public website and exact-reference verification contracts are narrower than a bulk export.
- Unsigned Discord HTTP handling was rejected because request origin could not be authenticated.
