# East Empire Company — Player and Discord Admin Handbook

Audience: Players, licensed business owners, EEC agents, warehouse staff, and Discord administrators  
Purpose: Explain the roleplay workflow in ordinary language  
Production portal: <https://eec-trade-registry-portal.vercel.app>  
Public registry: <https://eec-trade-registry-portal.vercel.app/verify>  
Public Sheet: <https://docs.google.com/spreadsheets/d/13bJeSAUF52cQnudC_l0JNOlKmcYY0wRWIq8OVqiEdrc/edit>

Administrators who need exact field-by-field instructions for adding items, stock, categories, units, supply workflows, license types, endorsements, prices, dealers, licenses, or staff access should use [Section 7 of the Complete User Guide](USER_GUIDE.md#7-complete-guide-to-adding-things).

## 1. The short version

An ordinary member of the public does not order wholesale goods directly from the East Empire Company.

The normal chain is:

```text
Customer
  -> licensed business
  -> authorized EEC agent
  -> EEC order review
  -> warehouse reservation and fulfillment
  -> licensed business receives the goods
  -> business supplies its customer
```

Example:

> Aurelion Earandil in Solitude wants a Nocturnal Dress. He goes to a business authorized to trade with the EEC. That business confirms what he wants and contacts an EEC agent. The agent verifies the business, creates or processes the business's order, and arranges fulfillment. The EEC sells or issues the dress to the licensed business—not directly to Aurelion. The business then completes its separate transaction with Aurelion.

That separation matters. Aurelion is the business's customer. The licensed business is the EEC's ordering party.

## 2. Who is who?

### Customer or member of the public

This is a player such as Aurelion who wants an item.

The customer can:

- Browse the public EEC catalogue
- Ask a licensed business to source an item
- Check a business's public EEC dealer reference
- Check a public license reference
- Receive the item from the business after the business obtains it

The customer cannot:

- Enter the staff portal
- Place a wholesale EEC order in their own name
- Reserve EEC warehouse stock
- Bypass the licensed business
- Treat catalogue visibility as permission to buy

### Licensed business

This is the shop, merchant, guild, institution, or other counterparty that deals with the EEC.

The business normally needs:

1. A current EEC dealer authorization
2. A current EEC license appropriate to the trade
3. Any endorsement required for the item
4. A verified representative who may speak or act for the business

The business receives the customer's request, decides whether it wants to take the job, and brings the commercial request to an EEC agent.

### Business representative

This is the player authorized to act for the licensed business. The representative may be its owner, manager, buyer, or another approved character.

The representative can use the dealer portal when granted the required access. They must never borrow another player's credentials or use an EEC staff account.

### EEC agent

This is an authorized Company player acting on behalf of the EEC in game and in the portal.

Depending on assigned roles, an agent may:

- Check a business's dealer authorization and license
- Help prepare an order
- Review an order
- Approve ordinary, restricted, or unique lines within authority
- Set or confirm a price when permitted
- Place an order into awaiting-stock status
- Coordinate with the warehouse
- Report the result to the business

An agent is not automatically allowed to do everything. The portal checks the agent's active role and permission for each action.

### Warehouse agent

This is the EEC staff member who deals with physical stock.

The warehouse agent may:

- Receive stock
- Create a reservation for an approved order
- Prepare and fulfill the order
- Dispatch or receive warehouse transfers
- Issue stock into consignment custody

Approving an order is not the same as moving stock. The warehouse performs the stock operation separately.

### Licensing officer

This staff member issues and maintains business licenses and endorsements. They do not make a business licensed merely by saying so in Discord; the authoritative license must exist in the portal.

### Discord or server administrator

The server administrator manages the people and channels around the workflow, but Discord permissions alone do not grant portal authority.

The administrator should:

- Direct players to the correct business or EEC desk
- Keep private business discussions out of public channels
- Ensure EEC staff use individual Discord accounts
- Never treat a Discord role as proof of an EEC license
- Use portal references when handing work between staff

## 3. The two checks a business needs

A dealer authorization and a license are different things.

### Dealer authorization

This answers:

> Is this party recognized by the EEC as an authorized dealer or counterparty in this jurisdiction?

### License

This answers:

> What kind of trade is this party licensed to conduct, and what endorsements or conditions apply?

A business may have one without the other. For an order that requires both, both must be current.

Public players can use exact references at:

- <https://eec-trade-registry-portal.vercel.app/verify/dealer>
- <https://eec-trade-registry-portal.vercel.app/verify/license>

Public verification is useful confirmation, but the EEC agent still checks the private staff record before making a decision.

## 4. Aurelion's Nocturnal Dress — the complete story

This section follows one order from the first conversation to final delivery.

The example names are roleplay examples. Item rules, license classes, jurisdictions, and control levels come from portal configuration rather than character or item-name checks.

### Stage 1: Aurelion finds the item

Aurelion opens the public catalogue and finds **Nocturnal Dress**.

The listing may show:

- Public description
- Public price, if one is configured
- Broad availability wording
- Control category
- Any public purchasing requirement

A public listing does not mean Aurelion can purchase directly. It also does not guarantee that the dress is physically in an EEC warehouse.

### Stage 2: Aurelion approaches a licensed business

Aurelion contacts a business in Solitude that claims to trade through the EEC.

He should ask for:

- The business's public EEC dealer reference
- Its relevant public license reference, when appropriate
- The price and terms the business is offering him

Aurelion or a Discord helper can check the references on the public verification page.

The EEC registry verifies the business's EEC authority. It does not settle Aurelion's private deal with the business.

### Stage 3: The business accepts Aurelion's request

The business decides whether it wants to obtain the dress for Aurelion.

The business should establish:

- Exact catalogue item
- Quantity
- Desired collection or delivery arrangement
- Whether substitutes are acceptable
- Any timing request
- Its own price or deposit arrangement with Aurelion

The EEC does not currently maintain the final retail transaction between Aurelion and the business. Unless a later policy requires end-customer reporting, Aurelion does not become the ordering party in the EEC order.

### Stage 4: The business contacts an EEC agent

The business representative contacts an authorized EEC agent in the approved in-game or Discord channel.

A useful request looks like:

```text
Business: [business name]
Dealer reference: [DLR reference]
License reference: [LIC reference]
Requested item: Nocturnal Dress
Quantity: 1
Requested method: Collection in Solitude
Timing: As available
Business contact: [authorized representative]
Notes: Customer order; no substitute without confirmation
```

Do not put passwords, private links, staff tokens, or unnecessary personal information into the message.

### Stage 5: The EEC agent verifies the business

The agent opens the staff portal and checks:

1. Is the dealer authorization current?
2. Is it for the relevant jurisdiction?
3. Is public/private status consistent with the record presented?
4. Is the license current?
5. Does the license class cover this kind of trade?
6. Is any required endorsement present and effective?
7. Is the person making the request an active representative of the business?
8. Are there any relevant public or staff-visible conditions?

The agent does not accept a screenshot, Discord nickname, guild role, or copied Sheet row as the final proof. The portal record is authoritative.

### Stage 6: The order is entered

The EEC order belongs to the licensed business.

The order should record:

- Ordering business
- Dealer authorization
- Relevant license when required
- Item and quantity
- Fulfillment preference
- Price snapshot or explicit price-pending state
- Control profile snapshot
- Requesting representative
- EEC actor and reason when entered or processed by staff

#### Current live-portal method

The deployed portal currently requires the business's authorized representative to submit the requisition through the dealer portal. The EEC agent then opens the staff order queue and reviews it.

#### Agreed assisted-order method

The intended roleplay workflow also allows the EEC agent to enter the order directly on behalf of the verified business after receiving the request. That staff-assisted order-entry screen and command are not yet present in the deployed portal.

Until that feature is implemented:

- Do not ask the EEC agent to log in as the business.
- Do not share dealer passwords.
- Have the verified business representative submit the dealer requisition.
- The agent may guide the representative and then process the resulting order.

This is the one software gap between the exact roleplay chain described here and the current production order-entry screen.

### Stage 7: The EEC agent reviews the order

The agent opens the staff order desk and reviews the line.

The agent can make one of the supported decisions:

- Approve the full quantity
- Approve part of the quantity
- Mark it awaiting stock
- Deny it
- Set or update the authorized order price

The required permission depends on whether the configured item control is ordinary, restricted, or unique.

The agent records a clear reason, for example:

```text
Verified current dealer authorization and commercial license.
Approved one unit for collection when stock becomes available.
```

The agent should not write vague reasons such as `done`, `okay`, or `admin request`.

### Stage 8: The system checks stock separately

Order approval does not remove a dress from inventory.

There are now two possible paths.

#### Dress is in stock

The warehouse agent creates a reservation against one available unit.

The reservation:

- Claims the unit for this approved order
- Reduces available quantity
- Does not yet remove physical on-hand stock
- Expires after the configured period unless extended or consumed

#### Dress is not in stock

The order remains awaiting stock.

This is allowed. The Company has recorded real commercial demand without inventing stock or posting a negative balance.

When stock arrives, the warehouse can create the reservation and continue.

### Stage 9: Warehouse fulfillment

When the business is ready to collect or receive the order, the warehouse agent opens the fulfillment desk.

The agent confirms:

- Correct business
- Correct order and line
- Correct item
- Correct quantity
- Active, unexpired reservation
- Correct warehouse
- Collection or receipt details

Completing fulfillment:

- Consumes the reservation
- Posts the physical inventory issue
- Updates fulfilled quantity
- Updates order status
- Writes audit and history
- Queues any configured notification

The stock movement and order update happen together. A partial failure does not leave the warehouse reduced while the order still appears unfulfilled.

### Stage 10: The business receives the dress

Under the approved wholesale baseline, title and custody pass for the confirmed collected or received quantity.

The EEC's transaction is now with the licensed business. The business can complete its separate arrangement with Aurelion.

If Aurelion paid a deposit or agreed to a retail price, that arrangement is between Aurelion and the business unless a future EEC policy explicitly brings it into the platform.

### Stage 11: Aurelion receives the dress

The business gives or sells the Nocturnal Dress to Aurelion under their agreement.

The EEC order history should show the business as the ordering and receiving party. It should not pretend that Aurelion held an EEC wholesale account.

## 5. Who clicks what?

| Moment | Person | Portal area | Action |
|---|---|---|---|
| Browse | Aurelion | Public catalogue | Find the Nocturnal Dress |
| Verify | Aurelion or helper | Public verification | Check exact dealer/license references |
| Accept request | Business | Roleplay/Discord | Agree to source the item |
| Submit current live order | Business representative | Dealer orders | Create and submit requisition |
| Review | EEC agent | Staff orders | Approve, partially approve, await stock, price, or deny |
| Reserve | Warehouse agent | Inventory/fulfillment workflow | Claim available stock |
| Fulfill | Warehouse agent | Staff fulfillment | Consume reservation and issue stock |
| Receive | Business | Roleplay/receipt | Confirm collection or delivery |
| Final sale | Business and Aurelion | Outside EEC wholesale registry | Complete their own retail transaction |

When staff-assisted order entry is added, the **Submit current live order** row may be performed by the EEC agent on behalf of the verified business. The business remains the ordering party.

## 6. Scenario: no stock is available

1. The licensed business requests one dress.
2. The EEC agent verifies and approves the request.
3. Inventory shows zero available.
4. The agent selects **Awaiting stock**.
5. The business is told the request is accepted but not allocated.
6. A later warehouse receipt adds stock through the ledger.
7. Warehouse staff creates a reservation.
8. Fulfillment continues normally.

Suggested player-facing response:

```text
Your business order has been accepted by the EEC but is awaiting stock.
No unit has been reserved yet. We will update the licensed business when
the warehouse can allocate the item.
```

Never promise a collection date merely because the order exists.

## 7. Scenario: only part of the order is available

Suppose the business requests three dresses and only one can be approved or supplied.

The EEC agent can approve one and leave the remainder denied or awaiting stock according to the supported decision and policy.

The warehouse reserves and fulfills only the approved quantity.

The business must tell Aurelion whether it will:

- Accept the partial result
- Wait for the remainder
- Cancel the still-eligible unfulfilled request
- Make a new arrangement

Fulfilled quantity cannot be retroactively cancelled.

## 8. Scenario: the business is authorized, but its license is wrong

The business has a valid dealer reference but does not hold the license class or endorsement required for the configured item.

The agent should:

1. Explain that dealer authorization and item authority are separate.
2. Avoid creating fictional approval notes or using another business's license.
3. Deny or hold the order according to the implemented state and policy.
4. Direct the business to the licensing office if an appropriate application or direct issuance path is available.

Suggested response:

```text
The business is recognized as an EEC dealer, but its current license does
not authorize this requested trade. The order cannot proceed under the
present authority.
```

## 9. Scenario: the license or dealer authority has expired

An old record may still exist without conferring current authority.

The agent checks effective dates and status rather than relying on the existence of a reference. The business must be renewed, reinstated, or otherwise brought into current authority through the approved licensing/dealer workflow before a new order proceeds.

Do not backdate or alter an order to make an expired license appear valid.

## 10. Scenario: restricted goods

If the Nocturnal Dress is configured as restricted, the item may require stronger review.

The agent checks:

- Required license class
- Required endorsement
- Jurisdiction
- Current business and representative authority
- Any configured conditions
- Restricted-order approval permission

A routine order officer without restricted approval permission cannot approve the line simply because everyone agrees in Discord.

The item name itself does not make it restricted. The configured control profile does.

## 11. Scenario: unique or individually tracked goods

If the requested dress is an individually tracked unique asset, the EEC deals with a specific `EEC-AST` record rather than a generic quantity.

The asset can be registered, inspected, allocated, and moved through recorded custody events. One asset cannot be allocated to two orders or have two current custodians.

Important current limitation:

- Asset allocation is implemented.
- Unique-asset fulfillment into an order is not yet complete.
- The EEC agent must not claim that allocation alone completed the sale or custody transfer.

## 12. Scenario: customer changes their mind

Because the EEC order belongs to the licensed business, the business decides whether to cancel its order request.

Before reservation or fulfillment progress, an authorized representative or staff member may cancel an eligible order.

After stock has been reserved, cancellation must also correctly release the claim through the approved workflow.

After fulfillment, use a return, reversal, or dispute workflow when available. Do not rewrite the order as though collection never happened.

The business's separate refund or deposit arrangement with Aurelion is outside the current EEC platform.

## 13. Scenario: the wrong item or quantity is handed over

Do not edit the completed ledger movement.

An inventory controller should:

1. Identify the original fulfillment and request ID.
2. Post the supported linked reversal with a reason.
3. Confirm stock and demand reopen correctly.
4. Create a new reservation if the correct quantity will be fulfilled.
5. Complete the corrected fulfillment.

The original mistake remains visible in history.

## 14. Scenario: business wants stock on consignment

Consignment is different from a normal wholesale order.

Under consignment:

- EEC remains the owner.
- The licensed business becomes the custodian.
- The business reports sold, returned, lost, damaged, and observed stock.
- Reports are claims until EEC staff accepts them.

Example:

```text
EEC consigns 10 dresses to the business.
Business reports 3 sold, 2 returned, 5 on hand.
EEC verifies 10 - 3 - 2 = 5 and accepts the report.
```

Loss or damage cannot be accepted through the routine path until liability and exception policy are approved.

## 15. Scenario: public verification and the Sheet disagree

The portal's Supabase result is authoritative. The Google Sheet is a scheduled public copy and may lag briefly.

An EEC admin should:

1. Check the source dealer or license record in the staff portal.
2. Check whether public disclosure is enabled.
3. Open `/staff/integrations`.
4. Check the latest `Dealers` or `Licenses` export run.
5. Confirm the Sheet's generated timestamp.
6. Queue a manual snapshot with a reason if an immediate refresh is required.

Do not edit the Sheet to force the answer.

## 16. What information should be recorded?

Record what the EEC needs to operate the wholesale transaction:

- Licensed business
- Verified representative
- Dealer and license references
- Catalogue item and quantity
- Fulfillment preference
- Price state
- Control and approval result
- Staff actor and reason
- Reservation and warehouse records
- Collection or receipt evidence supported by the workflow

Do not automatically record the final customer's private information. Aurelion's name may be useful in the roleplay conversation, but the current EEC ordering party is the business. End-customer reporting remains a policy decision.

## 17. Suggested Discord channel flow

A practical channel setup could use:

```text
#eec-catalogue-and-verification
  Public links, catalogue information, and verification help

#licensed-business-desk
  Business representatives contact EEC agents

#eec-order-operations
  Private staff coordination using order references

#eec-warehouse
  Private reservation, collection, and transfer coordination

#eec-compliance
  Restricted casework; never public allegations or evidence
```

Channel names are examples. Actual server names and permissions are configuration and administration choices.

### Good business request

```text
Requesting business: Solitude trading business
Dealer reference: DLR-...
License reference: LIC-...
Item: Nocturnal Dress
Quantity: 1
Method: Collection
Representative: [name]
```

### Bad business request

```text
my customer needs that black dress, admin pls spawn one
```

The second request does not identify the authoritative business, authority, item, quantity, or fulfillment path.

## 18. Suggested EEC agent response templates

### Received

```text
The EEC has received the request from [business] for [quantity] × [item].
Dealer and license authority are being checked. This message is not yet an
approval or stock reservation.
```

### Approved and reserved

```text
Order [EEC-ORD reference] has been approved for [quantity] × [item].
The warehouse has an active reservation. Collection or delivery details
will be coordinated with the licensed business.
```

### Approved but awaiting stock

```text
Order [EEC-ORD reference] has been approved but is awaiting stock.
No unit is currently reserved. The licensed business will be contacted
when allocation becomes available.
```

### Denied for authority

```text
The request cannot proceed under the business's current EEC authority.
The dealer or license record does not satisfy the configured requirement
for this item. Contact the licensing desk for the appropriate next step.
```

### Fulfilled

```text
Order [EEC-ORD reference] has been fulfilled to [business] for
[quantity] × [item]. The business may now complete its separate
arrangement with its customer.
```

## 19. What the Google Sheet is for

The public Sheet is linked to Supabase and refreshes on the scheduled projection cycle.

It helps players and admins browse public catalogue, dealer, and license data outside the main site.

It is not used to:

- Place orders
- Approve licenses
- Reserve stock
- Record fulfillment
- Change dealer status
- Grant permissions

If someone edits a cell, that edit does not enter the EEC database and will normally be overwritten on a later refresh.

## 20. Rules for EEC agents

1. Verify the business and representative before acting.
2. Keep the business—not the final customer—as the EEC ordering party.
3. Use the portal, not Discord roles or Sheet rows, as authority.
4. Never share or borrow credentials.
5. Do not promise stock until a reservation exists.
6. Do not claim fulfillment until the ledger issue is posted.
7. Do not bypass control-level permissions.
8. Write useful reasons for decisions.
9. Correct posted mistakes through reversals.
10. Keep private notes and compliance information out of public channels.

## 21. Rules for licensed businesses

1. Keep dealer authorization and licenses current.
2. Use only verified representatives.
3. Quote exact EEC item names or codes and quantities.
4. Understand that order acceptance is not stock allocation.
5. Do not promise an EEC collection date before confirmation.
6. Do not give staff credentials to a customer or another business.
7. Keep your retail transaction with the customer separate from the EEC wholesale order.
8. Report consigned sales and stock honestly.

## 22. Rules for ordinary players

1. Browse the public catalogue.
2. Use a business with verifiable EEC authority.
3. Understand that public availability is not exact warehouse stock.
4. Arrange your retail price, deposit, and pickup with the business.
5. Ask the business—not EEC warehouse staff—for updates on your retail purchase.
6. Report suspected fraud through the appropriate staff or compliance route rather than making public accusations.

## 23. Rules for Discord admins

1. Never use a Discord role as the only proof of a license or staff power.
2. Keep order and business channels appropriately private.
3. Direct the public to verification rather than exposing staff screenshots.
4. Require EEC staff to use individual accounts.
5. Do not copy bot tokens, webhooks, private links, or service credentials into channels.
6. Use EEC public references when handing work off.
7. Remember that deleting a Discord message does not cancel an order.
8. Remember that a reaction emoji is not approval.

## 24. Current software status in plain language

### Working now

- Public catalogue
- Dealer and license verification
- Discord OAuth staff login
- Dealer credential login
- Dealer order submission
- Staff order review and pricing
- Orders without stock on hand
- Partial approval and partial fulfillment
- Ledger stock receipts and reversals
- Reservations
- Fungible fulfillment
- Warehouse transfers
- Consignment custody and dealer reports
- Dealer onboarding and authorization status
- Direct license issuance and endorsements
- Serialized asset registry and allocation
- Compliance cases and appeals at record-only depth
- Audited staff-role administration
- Public Google Sheet refreshes
- Operations and integration monitoring

### Not yet working exactly as described

- EEC agent directly creates a new order on behalf of the business from the staff portal

The current safe workaround is dealer-representative submission followed by EEC agent review. Staff must not impersonate the business.

### Still policy-gated

- Public license applications and renewals
- Regional factor powers
- Quotas
- Dealer-specific pricing rules
- Consignment finance and loss settlement
- Unique-asset fulfillment
- Automatic cross-domain compliance sanctions
- Official generated documents
- Final-customer reporting

## 25. Admin shift checklist

### Start of shift

1. Sign in through Discord.
2. Check `/staff/operations` for failed or overdue work.
3. Check `/staff/integrations` for the latest Sheet export.
4. Check expired reservations and open transfers.
5. Check the staff order queue.

### For every order

1. Confirm the business.
2. Confirm the representative.
3. Confirm dealer authorization.
4. Confirm license and endorsements.
5. Confirm the exact item and quantity.
6. Confirm the control level.
7. Record a clear decision and reason.
8. Do not promise stock before reservation.
9. Hand off to the warehouse with the EEC order reference.
10. Confirm fulfillment before telling the business it is complete.

### End of shift

1. Check for orders left under review without explanation.
2. Check active reservations nearing expiry.
3. Check dispatched or disputed transfers.
4. Check failed exports or delivery work.
5. Hand unresolved work to the next agent using portal references.

## 26. The golden rule

When the roleplay conversation, Discord message, Google Sheet, and portal appear to disagree:

> Stop and check the authoritative Supabase-backed portal record.

Do not solve a disagreement by editing the Sheet, changing a Discord role, deleting a message, sharing credentials, or inventing an approval. Use the correct EEC workflow and leave an auditable reason.
## 27. Live workflow: miners, keystone materials, and Company reserves

This is the ordinary player-facing story for iron ore, stone, leather rolls, lumber, cloth, and any later material configured the same way.

1. A miner, hunter, lumber worker, or supplier gathers goods through normal server play.
2. An EEC agent can always offer the currently approved Company floor price. The floor is intentionally a safe fallback, not the best possible market price.
3. If the player accepts, the agent registers them as a supplier if necessary. This does not make the player a licensed EEC dealer.
4. The agent inspects and accepts the quantity on the Economy desk. The website creates an `EEC-PRC-*` receipt, adds the actual goods to warehouse reserve, and records exactly how many Septims the Company owes.
5. After paying the player through the approved server method, the agent records the payment or voucher reference. Warehouse stock is unchanged by this second step because the goods already arrived.
6. Smiths and other businesses can still buy directly from players at negotiated prices. If they need a large quantity immediately, they may seek Company reserve stock at the separately configured high convenience price.

The intended result is a corridor:

```text
guaranteed EEC buy floor
        < ordinary player-to-player market
        < expensive EEC emergency reserve sale
```

If reserves run low, the dashboard says so and approved orders can wait for material. Agents must not create keystone inventory with the generic receipt form just to clear an order.

### Economy desk quick procedure for admins

Open `/staff/economy`.

- The desk is an action queue containing only procurement materials. A made-to-order catalogue item such as a dress does not appear in this reserve table.
- If every material needs setup, use the prominent **Set the first material** action. Do not interpret a page of zeroes as real policy.
- Open the material you are handling. Its page shows real ledger stock, active reservations, approved unmet demand, recent buying, and its configured target band.
- **Set safety levels** changes policy thresholds; it never changes stock.
- **Publish purchase rate** sets the guaranteed per-unit floor for that material. SEP and the material are derived rather than reselected.
- **Receive delivery** is the physical handoff. Choose the supplier and enter the accepted quantity. A single warehouse, receiving location, offer, or currency is derived automatically.
- If the supplier is not listed, expand **Supplier not listed?** on that material and register the character or organization actually supplying the goods.
- **Record paid** is used only after the Septim payment happened elsewhere. Enter a Discord log, voucher, ticket, or other approved reference.

Do not use a supplier reference as a dealer reference, license number, or login. Those identifiers prove different relationships.

<!-- FEATURE_STATUS:START -->
## Current feature status

This table is generated from the same manifest used by the application. Do not edit it by hand.

| Capability | Status | Portal route |
| --- | --- | --- |
| Public catalogue | Live | `/` |
| Dealer and license verification | Live | `/verify` |
| New license applications | Live | `/apply` |
| License renewal requests | Live | `/apply` |
| Staff-assisted and direct order entry | Live | `/staff/orders/new` |
| Ledger inventory and reservations | Live | `/staff/inventory` |
| Keystone material procurement | Live | `/staff/economy` |
| Unique-asset fulfillment | Live | `/staff/assets/fulfillment` |
| Consignment settlement | Live | `/staff/consignments/finance` |
| Official document generation | Live | `/staff/documents/new` |
| Effective price rules | Live | `/staff/pricing` |
| Google Sheets and Discord projections | Built; external setup required | `/staff/integrations` |
| Stock-count reconciliation | Policy-gated | — |
| Compliance evidence file storage | Policy-gated | — |
<!-- FEATURE_STATUS:END -->
