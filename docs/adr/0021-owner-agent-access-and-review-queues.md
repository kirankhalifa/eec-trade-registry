# ADR 0021: Owner/Agent access and explicit review queues

- Status: accepted
- Date: 2026-08-13

## Context

Discord OAuth proved a staff user's identity but an unassigned successful login produced no owner-visible record. The owner could therefore see that Auth users existed in Supabase without having a safe portal workflow to identify, approve, deny, or block them. Staff authority was also presented as a long list of technical roles even though the intended server-facing model is Owner, Agent, business, and public. Public license applications were counted on the dashboard but their decision form was buried in the general launch desk.

## Decision

- A first successful Discord OAuth callback creates or refreshes a `staff_access_requests` record keyed by immutable Supabase Auth and Discord provider identifiers.
- A pending request grants no actor profile, staff assignment, data access, or business authority.
- The owner receives an owner-only access queue and dashboard count. Approval creates or reactivates the actor and grants the single user-facing **Agent** assignment in one audited, version-checked, idempotent database command. Denial grants nothing. Blocking disables the actor and revokes current Agent authority.
- Existing active platform administrators receive the user-facing **Owner** assignment during migration without losing any existing authority.
- The ordinary portal presents only Owner and Agent as staff access classes. Granular permission scopes and legacy role bundles remain internal authorization machinery and test fixtures; they are not ordinary server-administration choices.
- Owner receives all current permission scopes. Agent receives current day-to-day scopes but cannot administer staff access or read restricted audit history. Future permission migrations must deliberately decide whether a new scope belongs to Owner, Agent, or both.
- **Business** is not a global staff role. Business access remains bound to a specific party, dealer authorization, and representative grant through the Dealer portal. The public remains unauthenticated.
- New access requests and decisions create durable outbox events. Discord delivery is only a notification projection and depends on a configured staff-alert destination.
- License applications receive a dedicated staff review workspace showing requested endorsements, canonical-holder selection, approval or denial controls, and recent decision history. The existing authoritative application decision function remains the only mutation path.

## Consequences

- Authentication, pending review, and active authority are visibly different states.
- Historical Auth users with Discord identities but no active staff assignment are backfilled as pending requests so the owner can resolve them.
- Display-name changes never identify authority. Immutable provider and Auth identifiers remain the binding keys.
- The final owner cannot be blocked from the Agent review queue. Owner succession and emergency recovery remain explicit operational-policy decisions.
- The simplified Agent bundle is intentionally broad for the approved small-server operating model. Database functions still check the exact permission, scope, record state, version, and business invariant for every command.
- Application approval still requires an existing canonical holder for a new license. The reviewer onboards the business/party first rather than silently creating an ambiguous legal party from free text.

## Unresolved policy

- Owner succession, emergency access, inactive-account timeouts, MFA, and step-up authentication
- Whether Agents should later split into scoped regional or specialist access classes at larger server scale
- Retention period for denied and blocked access requests and provider metadata
- Whether access-request notifications should use Discord, another private channel, or both in production
