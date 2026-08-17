# East Empire Company Trade Registry — Operator Guide

This is the everyday guide for Owners and Agents. It explains what to do in the site without requiring knowledge of the database, ledger, price rules, or internal permission system.

## The four rules

1. Start routine work from **Today**.
2. Describe what happened; let the site choose the rules.
3. Finish an order from that order’s page.
4. Use **Staff tools** only when the task specifically involves an advanced subject.

Supabase is the authoritative record. Google Sheets, Discord, and PDF documents copy approved information from it; editing those copies never changes the registry.

## Signing in

1. Open **Staff access** and choose **Continue with Discord**.
2. Discord proves which account you control. It does not grant EEC authority.
3. A first-time identity appears in the Owner’s access requests.
4. The Owner approves the person as an Agent, denies the request, or blocks it.
5. After approval, sign in again if the pending page does not refresh automatically.

There are only two staff roles:

- **Agent:** ordinary EEC work allowed by the assigned database permissions.
- **Owner:** all Agent work plus staff access, advanced policy, corrections, and system administration.

A business account is not a staff role. A public visitor has no staff access.

## Today

The Today page has four routine starting points:

- **Record an order**
- **Buy materials**
- **Review applications**
- **Receive stock**

Below them, **Needs attention** shows only real work: pending applications, orders awaiting review or stock, low reserves, unpaid purchases, access requests, or failed projections. Zero-value panels are omitted.

Recent orders open directly to the order page. You never need to copy an order reference between screens.

## Record an order

Open **New order**.

### Licensed business order

Example: Solitude Tailor orders a Nocturnal Dress for Aurelion Earandil.

1. Under **Who is buying?**, choose **Solitude Tailor**.
2. Under **Who is it for?**, enter **Aurelion Earandil**. This is optional and does not change who receives the wholesale terms.
3. Choose **Nocturnal Dress** and enter the quantity.
4. Choose **Collection** or **Delivery**.
5. Select **Check total**.
6. Confirm the licensed-business price and select **Record order**.

The site carries the active business authorization and license internally. Staff do not type a sales channel, license reference, dealer reference, price schedule, control level, warehouse, reservation, or audit reference.

### Direct individual order

1. Choose the returning individual under **Who is buying?**, or choose **New individual customer**.
2. For a new person, enter the character name and optional Discord name.
3. Choose the goods and quantity.
4. Choose collection or delivery.
5. Select **Check total**.
6. Confirm the premium price and remaining weekly limit, then select **Record order**.

Direct pricing and personal limits are determined by Supabase. Staff cannot bypass them by selecting a different form path.

### Multiple items

Select **Add another item** only when the same buyer is ordering more than one good. Do not create empty lines. An unwanted added line can be removed with the × button.

### Orders without stock

An order can be recorded when stock is unavailable. Recording demand does not create inventory. The order remains waiting until real stock is received or purchased.

### Consignment order

Open **Special order options** and select consignment only when the transaction is actually governed by an EEC consignment agreement. Ordinary wholesale resale is not consignment.

## Continue an order

Open **Orders**, search by customer or reference, and select **Open order**.

Each item shows a simple path:

`Ordered → Ready → Completed`

Only the next permitted action appears.

### Review

For an ordinary request, select **Approve order**. Open the alternate-decision section only to approve a different quantity, deliberately wait for stock, or deny the request.

Restricted or unique goods may require an Owner or another specifically authorized Agent. The button is not permission; Supabase checks authority again on submission.

### Make ready

When stock is available, select **Make order ready**. If there is one valid source, the site chooses it. If several sources could cover the order, choose the physical location.

This creates an internal stock hold so two Agents cannot promise the same unit. Operators do not manage a separate reservation desk during ordinary work.

### Complete handoff

Select **Confirm handoff** only after the recorded goods physically leave EEC custody for the buyer or recipient. That action consumes the hold, posts the inventory movement, updates the order, and records history together.

Never confirm handoff merely because an admin intends to spawn or deliver an item later.

### Cancel or correct

Cancellation is at the bottom of the order page. It preserves history and releases eligible outstanding claims. Completed quantities are corrected through a linked reversal, not by editing or deleting the original transaction.

## Buy player-supplied materials

Use **Buy materials** when a miner, hunter, lumber worker, or other supplier sells naturally produced reserve materials to the Company.

1. Choose the supplier.
2. Choose the material.
3. Enter the accepted quantity.
4. Confirm the guaranteed rate and total shown in the summary.
5. Select **Record purchase and add stock**.

The rate is read from the current effective offer. The command records the supplier purchase, freezes the amount owed, and posts the balanced stock receipt together.

If the supplier is new, open **New supplier**, enter the character or organization name, and register them. Registering a supplier does not make them a licensed wholesale business.

### Payment evidence

A new purchase is awaiting payment evidence until an Agent records the in-character payment or voucher reference. Open **Payments still to record** beneath the purchase form and select **Mark paid**. This status is evidence of an external Septim payment, not a bank account.

## Receive ordinary stock

Use **Stock → Receive ordinary stock** for goods whose supply policy permits a normal receipt.

1. Choose the item.
2. Enter the quantity physically received.
3. Select **Add to stock**.

Player-sourced-only materials are rejected from this form even if a button is shown incorrectly. Buy them through **Buy materials** so provenance and payment are captured. Unique goods use the unique-goods tool because each asset requires its own identity.

The stock table distinguishes:

- **On hand:** physically present according to posted movements.
- **Reserved:** held for existing orders.
- **Available:** on hand minus active holds.

The numbers are calculated; staff never overwrite a current-stock cell.

Advanced hold history, elapsed holds, reversals, and ledger evidence are under **Stock history and advanced controls**.

## Customers and licenses

Use **Customers** to find or add a licensed business. Open a business to see its current authorization and linked licenses.

A license is separate from the business authorization. Both may be required for wholesale ordering. The license page records class, endorsements, dates, standing, conditions, and public verification reference.

Use **Applications** for public requests:

1. Open the pending application.
2. Read the applicant statement and requested endorsements.
3. Match or create the correct holder record.
4. Approve and issue, renew, request correction where supported, or deny.
5. Enter a reason for the decision.

A pending application is never a valid license. Approval must finish the issuance or renewal transaction.

## Catalogue

Use **Catalogue** to find the goods and materials maintained by the Company. Select **Add item** for new ordinary configuration.

An item can exist without being public, without a price, and without stock. Blank pricing means unavailable or pending; it never means zero.

The item’s name does not control its rules. Supply workflow, public availability, license requirements, control profile, and inventory mode are configured records.

## Staff tools

The bottom of Today contains a collapsed **Staff tools** panel. Every tool is explained there. Open a tool only when the task involves it:

- **Licenses:** issue or change institutional authority.
- **Staff access:** approve Discord identities and manage Agents; Owner only.
- **Reference setup:** add reusable categories, units, license types, endorsements, and control profiles.
- **Reserve economy:** set reserve targets and guaranteed purchasing rates.
- **Advanced pricing:** create special business, license-class, regional, or channel pricing.
- **Fulfillment queue:** inspect handoffs across many orders during exception work.
- **Warehouse transfers:** record movement between configured locations and in-transit custody.
- **Consignments:** track EEC-owned stock held by businesses and settle accepted reports.
- **Unique goods:** register and transfer individually identified assets.
- **Official documents:** generate immutable PDF snapshots from current authoritative records.
- **Compliance:** record cases, evidence metadata, findings, appeals, and configured effects.
- **Sheets and Discord:** open the public Sheet, check export freshness, and inspect notification delivery.
- **System health:** inspect authoritative services, failures, access history, and operational audit; Owner only.

These tools are deliberately outside primary navigation. They remain available without making every Agent learn them before recording an order.

## Google Sheets and Discord

The public Google Sheet is a one-way copy of approved Supabase records. **Sheets and Discord** shows its destination, latest successful generation time, and failures. Editing the Sheet does not update the site.

Discord staff sign-in proves identity only. Discord roles do not grant EEC permissions. Bot lookups and notifications read approved Supabase projections; reactions and message edits do not approve orders or licenses.

## Fixing mistakes

- Unsubmitted form mistake: correct the field normally.
- Wrong pending order: cancel it with a reason and enter the correct order.
- Wrong posted receipt or handoff: use an authorized linked reversal.
- Wrong price on an uncompleted order: open the order’s recorded-price section and supply the reason.
- Wrong public item information: update the catalogue item; historical orders keep their original snapshots.
- Unsure what happened: stop and ask the Owner before posting another transaction.

Never delete history, edit Google Sheets as a correction, invent stock, share another person’s account, or use Discord messages as proof that a secure action occurred.
