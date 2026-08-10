# ADR 0016: Audited platform administration

Status: Accepted

## Context

Production staff authority was initially provisioned by an authenticated database operator because no access-management surface existed. Repeating manual SQL would weaken audit consistency, invite scope errors, and make safe revocation difficult. Operational queues also need a private overview without allowing a dashboard to become an automatic repair mechanism.

## Decision

- Add a composable `platform_administrator` role containing only staff-access read/manage, private access-audit read, and operational-health read permissions.
- Grant and revoke effective-dated staff assignments only through security-definer commands that re-resolve the caller, require a reason and request identifier, record audit snapshots, and emit outbox events.
- Prevent revocation of the final currently effective platform-administrator assignment.
- Keep business-domain roles separate; platform administration does not imply catalogue, licensing, order, warehouse, integration, or compliance authority.
- Expose policy-neutral health counts for stale or failed work. The console never repairs, retries, expires, reverses, or changes domain records implicitly.
- Keep authentication-provider and Discord role labels non-authoritative.

## Consequences

Future staff provisioning can occur through the application with a reconstructable history. Emergency database provisioning remains a documented break-glass operation and must set explicit audit context. The last-administrator rule reduces accidental self-lockout but does not replace recovery procedures, MFA, secret rotation, or a tested break-glass process.
