# ADR 0018: Player-sourced keystone reserves and market corridor

Status: Approved  
Date: 2026-08-10

## Context

The East Empire Company is intended to stabilize the server economy for baseline productive materials such as ore, stone, leather, lumber, and cloth. A producer should always have a buyer at a deliberately modest guaranteed rate. A business that urgently needs a large quantity may buy from Company reserves at a deliberately high published rate. Ordinary player-to-player trade should remain more attractive between those two prices.

These reserves must represent material gathered and sold by players. Creating keystone stock through administrative spawning would erase the production sink, make the dashboard economically false, and let an unlimited institutional supply crowd out player trade.

## Decision

1. Keystone materials use the configurable `player_sourced_reserve` supply mode.
2. A material marked `player_sourced_only` cannot enter physical stock through the generic administrative receipt command.
3. Staff publish an effective-dated guaranteed purchase offer only after a rate is approved. No rate defaults to zero and no illustrative rate becomes policy automatically.
4. A supplier is a player or organization that sells goods to the Company. Supplier registration does not grant dealer authorization or a license.
5. Staff accept a supplier delivery against a current purchase offer. Acceptance atomically creates a delivery record, a snapshotted payment obligation, and a balanced immutable inventory receipt.
6. Payment evidence is recorded separately from warehouse receipt. A pending payment does not change stock, and a received delivery does not falsely assert payment.
7. Reserve thresholds are configurable per item. On-hand and available quantities are always derived from the inventory ledger; thresholds never overwrite stock.
8. Company resale terms are a separate effective-dated price policy. The intended corridor is a modest guaranteed buy floor, an ordinary player market between the boundaries, and a high convenience or emergency reserve price.
9. Orders may be accepted without current stock. The system exposes unmet approved demand and reserve pressure rather than inventing supply.
10. Finished or imported goods may use other configurable supply modes. This decision does not prohibit authorized non-player sourcing for every catalogue item.

## Consequences

- The Company acts as a buyer of last resort without becoming the best routine buyer.
- Emergency reserves come from player production and can genuinely run low.
- Producers, licensed businesses, and EEC agents remain distinct counterparties with different records and permissions.
- Staff can explain every unit of keystone material by an accepted delivery and immutable ledger entry.
- The dashboard can show physical reserve, reservations, back-orders, recent procurement, obligations, and recorded settlement without claiming to be a treasury general ledger.
- Exact floor rates, reserve targets, emergency resale prices, commissions, and periodic limits remain operating-policy decisions entered as data.

## Rejected alternatives

### Administrative spawning for reserve replenishment

Rejected for keystone materials because it destroys economic provenance and makes the institutional reserve unlimited.

### One editable stock cell per material

Rejected because it cannot preserve movement history, reservations, reversals, warehouse scope, supplier provenance, or concurrent correctness.

### Treating a Discord post or Sheet row as a delivery

Rejected because projections cannot create authoritative custody or payment obligations.
