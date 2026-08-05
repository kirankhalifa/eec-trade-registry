# ADR 0012: Fungible stock transfer boundary

Status: Accepted for the initial transfer increment  
Date: 2026-08-05

## Decision

A fungible warehouse transfer is an authoritative lifecycle record plus two distinct balanced inventory transactions. Dispatch moves stock from a physical source account to an explicit in-transit custody account. Receipt moves it from transit to the destination physical account. Ownership is unchanged.

The initial command handles one item and one full quantity. Requested transfers require explicit controller authorization. Dispatch is irreversible through cancellation; receiving discrepancies preserve in-transit stock until an authorized resolution. All commands are warehouse-scoped, version checked, idempotent, reasoned, audited, and event producing.

## Consequences

- Stock cannot disappear between warehouses or be counted at both endpoints.
- Workflow status never substitutes for ledger evidence.
- Routine operators may request, dispatch, and receive; controllers authorize and may cancel before dispatch.
- Partial receipts, returns, carrier identities, proof attachments, and loss resolution remain additive workflows rather than overloaded status edits.
- Consignment and serialized assets will reuse owner/custodian separation but require dedicated domain records.
