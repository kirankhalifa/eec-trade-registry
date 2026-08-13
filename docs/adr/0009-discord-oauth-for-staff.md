# ADR 0009: Discord OAuth for staff authentication

- Status: accepted
- Date: 2026-08-05

ADR 0021 supersedes the manual post-login provisioning procedure below with an owner-visible pending request and explicit Agent approval. The identity/authority separation and every other security decision in this ADR remain in force.

## Context

The staff portal initially exposed an email/password form while production identity-provider policy remained open. The product owner selected Discord OAuth for staff and requested no staff email-based sign-in experience. Supabase PostgreSQL must remain the authority for roles and permissions, and Supabase Auth must continue to own application sessions.

Discord authentication and the planned Discord bot integration solve different problems. Social OAuth proves an individual's identity for a web session. Bot commands, guild membership, Discord roles, notifications, and message delivery do not grant application authority.

## Decision

- Use Supabase Auth's Discord social provider for staff authentication.
- Expose one **Continue with Discord** action on the staff login page. Do not expose staff email/password sign-in, signup, or recovery controls.
- Use the Supabase server-side PKCE flow. The portal sends an exact configured HTTPS callback, exchanges the one-time code in a Next.js route handler, and stores the resulting Supabase session in cookies.
- Redirect successful callbacks only to the fixed staff route. Do not accept a caller-controlled continuation URL.
- Resolve business authority independently on every protected database call from the Supabase Auth UUID, active actor profile, effective-dated staff assignment, role, and permission.
- Bind and provision production staff by immutable provider/Supabase identifiers. Never use a Discord display name, username, guild nickname, guild membership, or Discord role as an authority key.
- Keep dealer authentication policy unchanged. Dealer email/password credentials and representative grants remain a separate surface.
- Keep Discord bot/command identity binding, server/channel configuration, and notification policy separate and unresolved where already documented.

The login experience does not ask the staff member to enter an email or password. The upstream provider and Supabase may process provider account attributes required for the OAuth identity; those attributes are not business authorization data and are not displayed as login credentials.

## Consequences

- A Discord-authenticated person with no actor profile or assignment fails closed at the secured database boundary.
- Provider configuration requires a Discord application secret stored only in Discord and Supabase managed configuration. It must never enter the repository, browser environment variables, logs, audit snapshots, or chat.
- Production must configure the exact portal origin and allowlist its `/auth/callback` URL in Supabase Auth.
- Initial owner provisioning remains a controlled deployment operation. Later staff provisioning uses the ADR 0021 queue: complete Discord authentication, then have an existing Owner approve that exact immutable identity as Agent.
- Open user enrollment may be disabled after the initial approved identity exists. This reduces unused Auth accounts but does not replace database authorization.
- MFA, provider-account recovery, inactive-account handling, session duration, and step-up requirements remain launch policy decisions.

## Rejected alternatives

- Keeping staff email/password as a fallback was rejected because it contradicts the selected staff experience and creates a second credential lifecycle.
- Treating Discord guild membership or roles as staff permission was rejected because external mutable state would become an authorization source.
- Storing a Discord client secret in Vercel or frontend code was rejected because Supabase Auth, not the portal, performs the provider token exchange.
- Using Discord usernames or display names for provisioning was rejected because they are mutable and not reliable identity keys.
