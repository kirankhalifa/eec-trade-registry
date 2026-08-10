# ADR 0014: Fungible consignment custody boundary

Status: Accepted

Date: 2026-08-10

## Context

The platform must distribute stock to authorized dealers without losing the distinction between ownership and custody. Pricing, settlement schedules, reporting cadence, shrinkage tolerance, proof of sale, loss/damage disposition, and serialized consignment policy are unresolved. A useful operational increment must therefore control physical units without inventing financial or exception policy.

## Decision

- Model an effective-dated agreement between one configured warehouse owner and one currently authorized dealer in one jurisdiction.
- Issue fungible stock only from an available physical account and only after subtracting active reservations.
- Post each issue as a balanced ledger transaction from physical stock to a `custody` account whose state is `consigned`, retaining owner and recording the dealer as custodian.
- Permit only a currently scoped representative of the consignee to view positions and submit reports.
- Treat submitted sold, returned, lost, damaged, and observed quantities as claims. Allow at most one submitted report per issue.
- Accept a routine report only when sold and returned quantities exactly reconcile the observed outstanding balance and loss/damage are zero.
- Post accepted sold quantity to an external account and accepted return quantity to an authorized matching physical account in one balanced transaction. Rejection has no inventory effect.
- Close an issue only at zero outstanding custody and block agreement closure while any issue remains outstanding.
- Require exact database permissions, warehouse scope where applicable, optimistic versions, request idempotency, audit records, immutable domain history, and transactional outbox events.

## Consequences

Staff and dealers can operate a controlled fungible consignment register without spreadsheets or Discord becoming business state. Ownership remains explicit throughout custody. The system deliberately does not calculate price, commission, amount due, tax, quota, reporting deadlines, shrinkage allowance, or liability. A loss or damage observation is preserved and rejected from routine settlement until an approved exception/compliance workflow exists. Serialized assets use their separate event model and are not issued through this command.

## Forward path

Later decisions may add configured commercial schedules, due dates, financial settlements, evidence attachments, exception/compliance cases, serialized consignment, and multi-step dispatch/acceptance. Those additions must reference these custody records and append new evidence; they must not rewrite posted ledger entries or accepted reports.
