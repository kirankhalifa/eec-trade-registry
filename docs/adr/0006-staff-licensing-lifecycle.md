# ADR 0006: Staff licensing lifecycle increment

Status: Accepted  
Date: 2026-08-04

## Context

ADR 0005 approved configurable license classes, modular endorsements, and permission-based staff authority, but license duration, application questions, applicant identity assurance, renewal, and grace policy remain unresolved. The existing registry tables were read-only fixtures with no secure staff lifecycle commands.

## Decision

Implement an immediately useful licensing-office increment without treating an application as approved authority:

- Seed three approved configurable license classes and the initial modular endorsements as reference data.
- Give a configurable licensing-officer role separate permissions for issue, activate, suspend, reinstate, revoke, surrender recording, endorsement management, and private read access.
- Allow a sufficiently permitted officer to issue an immediate or scheduled, open-term license to an existing active party. The initial UI does not invent an expiration date while duration policy is unresolved.
- Allocate immutable public references transactionally from a configurable sequence.
- Make issuance idempotent by request identifier and make subsequent mutations version-checked.
- Restrict status transitions to the documented provisional, active, suspended, revoked, and surrendered paths. Revoked and surrendered records are terminal in this increment.
- Preserve append-only status and endorsement events while audit triggers capture actor, authentication identity, permission, assignment, reason, request, previous state, and new state.
- Create a durable outbox event in the same transaction as each accepted lifecycle command. No external delivery worker is introduced here.
- Keep direct source-table access denied; the staff UI uses only narrow secure functions.

## Consequences

- Public verification and dealer views reflect committed licensing changes from the same source records.
- A staff-issued license is never represented as a pending application. Application, review, renewal, and generated-certificate workflows remain separate future increments.
- There is no universal second approval. Each command requires the specific active permission configured for that action.
- Open-term issuance is explicit, not a substitute for deciding duration policy. A future renewal model must preserve already-issued history.
- The outbox is now available for later Discord, Sheets, and document workers, but it cannot be queried or processed by ordinary browser sessions.
