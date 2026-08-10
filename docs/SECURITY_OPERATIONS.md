# Security and operations runbook

Status: Production baseline implemented; launch exercises and external controls remain open

## Implemented controls

- Supabase PostgreSQL is the only authoritative store.
- Public, dealer, and staff callers use explicit functions; direct table grants are denied.
- Staff authentication uses Discord OAuth through Supabase Auth, while effective-dated database assignments grant business authority.
- Platform-administrator grants and revocations are audited, idempotent, and protected against removal of the last active administrator.
- Inventory is ledger-derived, consequential mutations require reasons and request identifiers, and integrations use durable retryable work records.
- Production responses set HSTS at the hosting edge and application-controlled CSP, clickjacking, MIME-sniffing, referrer, cross-origin, and browser-permission headers.
- Secrets are server-only managed environment variables and never stored in destination configuration records.

## Daily operator review

1. Open `/staff/operations` and review failed outbox, delivery, and export counts; expired leases; overdue definitions; expired active reservations; in-transit/disputed transfers; and open compliance work.
2. Open `/staff/integrations` and confirm the 15-minute scheduler is active, runtime credentials report ready, and recent export/delivery attempts are not failed.
3. Confirm the public Sheet shows current `Generated at` values for Catalogue, Dealers, and Licenses.
4. Investigate through source records and audited commands. Never edit a Sheet or Discord message as a repair.

## Incident response

1. Record the detection time, affected surface, reporter, and correlation/request identifiers.
2. Disable only the affected integration destination or export definition when external publication must stop. Do not disable authoritative business functions without an approved incident decision.
3. Preserve audit, outbox, delivery, export-run, domain-event, and hosting logs. Do not rewrite or delete evidence.
4. Rotate any potentially exposed secret in its owning provider, update the managed server environment, redeploy, and invalidate the old credential.
5. Reconcile database state before replaying failed projections. Replays project existing state and must not create independent business state.
6. Record resolution, validation evidence, remaining exposure, and the owner of every follow-up.

## Backup and restore exercise

The environment owner must run this before public beta and after material recovery changes:

1. Confirm the Supabase plan's backup schedule, retention, and point-in-time recovery capability in the production project.
2. Create an isolated recovery project. Never restore over production for a rehearsal.
3. Restore the selected recovery point, then apply any later committed migrations in order.
4. Run schema lint, the complete pgTAP suite, and representative public/staff/dealer read checks against the isolated restore.
5. Reconcile ledger-derived balances, active reservations, transfer custody, serialized current state, outbox/export state, and audit row counts with the source checkpoint.
6. Record measured recovery point and recovery time, discrepancies, approver, and evidence location.
7. Destroy recovery credentials and the isolated project according to the approved retention policy.

No restore exercise is considered complete merely because a dashboard reports that a backup exists.

## Secret rotation order

Rotate one credential at a time and verify the affected path before continuing:

1. Integration worker secret and Supabase service-role credential
2. Google service-account credential and Sheet access
3. Discord bot token, public key, and configured channel access
4. Supabase Auth provider secret

Never paste secret values into issues, logs, audit reasons, SQL history, screenshots, or documentation.

## External launch gates still requiring owner evidence

- Edge rate limits and abuse monitoring for public catalogue, verification, and Discord endpoints
- MFA or equivalent elevated-account control for provider and database operators
- A completed isolated restore exercise with measured RPO/RTO
- Approved retention/redaction policy and incident/support ownership
- Discord bot token installation, command registration, and staff-alert channel configuration
- Accessibility and supported-browser validation at the approved target
- Formal permission and threat-model review with no unaccepted critical/high findings
