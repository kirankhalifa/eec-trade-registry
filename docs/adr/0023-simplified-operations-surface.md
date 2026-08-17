# ADR 0023: Simplified operations surface

- Status: accepted
- Date: 2026-08-17

## Context

The platform accumulated a separate route, form, counter, and vocabulary set for nearly every secure command. Those commands are necessary for authorization, inventory integrity, custody, and auditability, but presenting them all as ordinary navigation made routine server work harder than a spreadsheet. Agents were asked to select classifications that Supabase could derive and to understand references that the system could carry automatically.

The product owner requires ordinary work to feel like a familiar checkout application: a new Agent should record a correct order or material purchase on their first attempt in approximately 30 seconds. Advanced machinery must remain discoverable and explained, but it must not compete with routine work.

## Decision

- The primary staff navigation contains only Today, New order, Buy materials, Orders, Stock, Applications, Customers, and Catalogue.
- Today presents four routine starting actions and only non-zero work requiring attention. It contains one collapsed **Staff tools** panel that explains and links advanced pricing, licensing, reserve policy, fulfillment queues, transfers, consignments, unique goods, documents, compliance, integrations, access, and system health.
- The advanced systems remain implemented and permission checked. “Dark” means absent from primary navigation and ordinary forms, not deleted or unaudited.
- Order intake asks for the buying account, optional recipient, goods, quantity, and handoff. The selected account determines business or individual channel, license context, price path, and personal-limit policy. The browser may request an authoritative preview, but Supabase revalidates the command and freezes the accepted result.
- Material purchasing asks for supplier, material, and quantity. The active guaranteed offer and normal receiving location are derived. The database atomically records procurement evidence and the balanced inventory receipt.
- Ordinary stock receipt asks for item and quantity when one receiving location exists. Traceable routine provenance is supplied by the server action. Player-sourced-only and serialized-item guards remain database invariants.
- Each order remains the canonical workspace for review, stock holding, and handoff. Queue-wide reservation and fulfillment pages are advanced exception tools.
- Public references, internal versions, rule precedence, ledger accounts, reservation records, technical role bundles, and routine audit wording are not inputs in ordinary forms.
- Existing governing technical documents remain authoritative for invariants. `docs/OPERATOR_GUIDE.md` is the only guide written for ordinary Agents.

## Consequences

- The common path is substantially smaller without changing Supabase authority, RLS, ledger, custody, history, idempotency, or permission behavior.
- Advanced features remain available from one explained panel and from the object to which they apply.
- Some secure operations remain separate transactions even when presented on one page. Interface simplicity must never be implemented by merging business states in the browser.
- New primary navigation items, routine fields, visible states, or standalone desks require evidence that an ordinary operator must make that decision repeatedly. Otherwise they belong on the relevant object or in Staff tools.
- The usability acceptance test is a first-time Agent completing an ordinary order and an ordinary material purchase without documentation in approximately 30 seconds each.
