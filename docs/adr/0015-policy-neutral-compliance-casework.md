# ADR 0015: Policy-neutral compliance casework

Status: Accepted

Date: 2026-08-10

## Context

The launch suite needs structured inspections, allegations, evidence, findings, actions, and appeals. The institution has not yet approved a violation taxonomy, evidence standard, notice rules, filing windows, reviewer-independence rules, stays, action effects, restoration, or retention. Treating a generic case command as authority to suspend a license, seize an asset, or change standing would invent policy and create unsafe coupling.

## Decision

- Add configured case, allegation, and action types with generic policy-neutral seed values.
- Keep allegations, findings, and evidence metadata in separate append-only records. Opening a case or recording an allegation never creates a finding.
- Use explicit finding outcomes: substantiated, not substantiated, or inconclusive.
- Store only evidence metadata and an approved reference in this increment; object storage and its access policy remain separate.
- Implement an explicit versioned case transition graph, assignment, written resolution, close, and reasoned reopen.
- Permit only record-only compliance action types. Approval, decline, void, and appeal outcomes are historical decisions with `effect_applied` constrained false.
- Record one filed appeal per approved action and explicit outcomes without inferring standing, timeliness, stay, notice, or restoration.
- Require current database permissions, optimistic versions, request idempotency, audit entries, immutable case events, and durable outbox events.

## Consequences

Staff can run a defensible private case file and clearly distinguish claim, evidence, finding, recommendation, review, and appeal. No casework command can silently change a license, dealer authorization, order, quota, reservation, stock position, transfer, consignment, or asset. Cross-domain effects must be introduced later as action-type-specific atomic functions after the governing policy is approved.

## Forward path

Future migrations may add configured taxonomies, filing clocks, notice generation, evidence object storage, independence constraints, emergency authority, stays, retention, public notices, and atomic cross-domain effect/reversal functions. They must append to the current history rather than rewrite allegations, evidence metadata, findings, or events.
