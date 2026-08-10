begin;

select plan(55);

select has_table('public', 'item_supply_policies', 'item supply policy table exists');
select has_table('public', 'procurement_suppliers', 'procurement supplier table exists');
select has_table('public', 'procurement_offers', 'effective-dated procurement offer table exists');
select has_table('public', 'procurement_deliveries', 'accepted delivery table exists');
select has_function('public', 'get_staff_economy_workspace', array[]::text[], 'economy workspace exists');
select has_function('public', 'staff_upsert_item_supply_policy', array['uuid','text','boolean','boolean','boolean','numeric','numeric','numeric','numeric','boolean','numeric','numeric','bigint','text','uuid'], 'policy command exists');
select has_function('public', 'staff_register_procurement_supplier', array['text','text','text','uuid','text','text','uuid'], 'supplier command exists');
select has_function('public', 'staff_create_procurement_offer', array['uuid','uuid','bigint','numeric','numeric','timestamp with time zone','timestamp with time zone','text','text','uuid'], 'purchase offer command exists');
select has_function('public', 'staff_record_procurement_delivery', array['uuid','uuid','uuid','numeric','text','uuid'], 'delivery command exists');
select has_function('public', 'staff_mark_procurement_delivery_paid', array['uuid','bigint','text','text','uuid'], 'settlement evidence command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.item_supply_policies'::regclass), 'supply policies have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.procurement_suppliers'::regclass), 'suppliers have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.procurement_offers'::regclass), 'offers have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.procurement_deliveries'::regclass), 'deliveries have RLS');
select ok(not has_table_privilege('authenticated', 'public.procurement_deliveries', 'insert'), 'authenticated callers cannot insert deliveries directly');
select ok(not has_function_privilege('anon', 'public.staff_record_procurement_delivery(uuid,uuid,uuid,numeric,text,uuid)', 'execute'), 'anonymous callers cannot receive goods');
select is((select count(*)::integer from public.permission_scopes where code like 'procurement.%' or code = 'economy.dashboard.read'), 6, 'six economic permissions are configured');
select is((select count(*)::integer from public.staff_roles where code in ('procurement_officer','economic_steward')), 2, 'two separated economic roles are configured');
select is((select count(*)::integer from public.items where item_code like 'RM-%'), 5, 'five initial keystone material records are configured');
select is((select count(*)::integer from public.endorsement_definitions where code in ('raw-materials','smithing-metalwork','alchemical-goods','arcane-goods','tailoring-textiles','bulk-distribution','consignment')), 7, 'seven modular trade endorsements are configured, including the existing consignment authority');
select is((select count(*)::integer from public.item_supply_policies where player_sourced_only), 5, 'all initial keystone materials require player sourcing');
select is((select count(*)::integer from public.procurement_offers), 0, 'migration does not guess an economic purchase rate');
select ok(exists(select 1 from public.get_public_catalogue(null, 'raw-materials') where item_code = 'RM-IRON-ORE'), 'raw materials are visible in the public catalogue');
select is((select count(*)::integer from public.inventory_accounts where item_id = 'ce000000-0000-0000-0000-000000000001'), 0, 'configuration does not invent material stock');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('d1000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'steward@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('d1000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'procurement@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('d1000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'denied@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Economic Steward', 'staff'),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'Procurement Officer', 'staff'),
  ('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000003', 'Denied Actor', 'staff');

insert into public.staff_assignments (id, actor_id, staff_role_id, effective_from, assignment_scope)
values
  ('d3000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', (select id from public.staff_roles where code = 'economic_steward'), '2026-01-01T00:00:00Z', '{}'::jsonb),
  ('d3000000-0000-0000-0000-000000000002', 'd2000000-0000-0000-0000-000000000002', (select id from public.staff_roles where code = 'procurement_officer'), '2026-01-01T00:00:00Z', '{}'::jsonb),
  ('d3000000-0000-0000-0000-000000000003', 'd2000000-0000-0000-0000-000000000002', (select id from public.staff_roles where code = 'warehouse_operator'), '2026-01-01T00:00:00Z', '{}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_economy_workspace()$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot read economic operations');

select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_economy_workspace()$test$, 'economic steward can read the economy dashboard');
select lives_ok($test$
  select * from public.staff_upsert_item_supply_policy(
    'ce000000-0000-0000-0000-000000000001', 'player_sourced_reserve', true, true, false,
    10, 25, 50, 100, false, null, 250, 1,
    'Approve initial reserve corridor without setting a purchase price.',
    'd4000000-0000-0000-0000-000000000001'
  )
$test$, 'economic steward can configure reserve thresholds');
select is((select (position ->> 'policy_version')::bigint from jsonb_array_elements(public.get_staff_economy_workspace() -> 'positions') position where position ->> 'item_code' = 'RM-IRON-ORE'), 2::bigint, 'secured projection exposes the incremented policy version');
select lives_ok($test$
  select * from public.staff_create_procurement_offer(
    'ce000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
    25, 5, 250, statement_timestamp() - interval '1 hour', null,
    'Guaranteed producer floor; intentionally below ordinary player market rates.',
    'Approve the first tested material purchase floor.', 'd4000000-0000-0000-0000-000000000002'
  )
$test$, 'economic steward can publish an active guaranteed purchase offer');
select lives_ok($test$
  select * from public.staff_create_procurement_offer(
    'ce000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
    25, 5, 250, statement_timestamp() - interval '1 hour', null,
    'Guaranteed producer floor; intentionally below ordinary player market rates.',
    'Approve the first tested material purchase floor.', 'd4000000-0000-0000-0000-000000000002'
  )
$test$, 'purchase offer retry is idempotent');

reset role;
select is((select count(*)::integer from public.procurement_offers where source_request_id = 'd4000000-0000-0000-0000-000000000002'), 1, 'one purchase offer is stored');
select set_config('test.offer_id', (select id::text from public.procurement_offers where source_request_id = 'd4000000-0000-0000-0000-000000000002'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok($test$
  select * from public.staff_register_procurement_supplier(
    'individual', 'Aurelia Stonehand', 'Aurelia Stonehand',
    '90000000-0000-0000-0000-000000000001', 'Independent miner.',
    'Register an approved producer for warehouse deliveries.',
    'd4000000-0000-0000-0000-000000000003'
  )
$test$, 'procurement officer can register a supplier');
select lives_ok($test$
  select * from public.staff_register_procurement_supplier(
    'individual', 'Aurelia Stonehand', 'Aurelia Stonehand',
    '90000000-0000-0000-0000-000000000001', 'Independent miner.',
    'Register an approved producer for warehouse deliveries.',
    'd4000000-0000-0000-0000-000000000003'
  )
$test$, 'supplier registration retry is idempotent');

reset role;
select matches((select public_reference from public.procurement_suppliers where source_request_id = 'd4000000-0000-0000-0000-000000000003'), '^EEC-SUP-[0-9]{4,}$', 'supplier receives a configured stable reference');
select is((select count(*)::integer from public.procurement_suppliers where source_request_id = 'd4000000-0000-0000-0000-000000000003'), 1, 'one supplier is stored');
select set_config('test.supplier_id', (select id::text from public.procurement_suppliers where source_request_id = 'd4000000-0000-0000-0000-000000000003'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($test$
  select * from public.staff_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002', 'ce000000-0000-0000-0000-000000000001',
    10, 'ADMIN-SPAWN', 'Attempt a generic keystone material receipt.',
    'd4000000-0000-0000-0000-000000000004'
  )
$test$, '23514', 'player_sourced_procurement_required', 'generic administrative receipts cannot create keystone material stock');
select lives_ok(format($test$
  select * from public.staff_record_procurement_delivery(
    %L::uuid, %L::uuid, 'ab000000-0000-0000-0000-000000000002', 10,
    'Accept ten inspected units from the registered producer.',
    'd4000000-0000-0000-0000-000000000005'
  )
$test$, current_setting('test.supplier_id'), current_setting('test.offer_id')), 'procurement delivery can create real reserve stock');
select lives_ok(format($test$
  select * from public.staff_record_procurement_delivery(
    %L::uuid, %L::uuid, 'ab000000-0000-0000-0000-000000000002', 10,
    'Accept ten inspected units from the registered producer.',
    'd4000000-0000-0000-0000-000000000005'
  )
$test$, current_setting('test.supplier_id'), current_setting('test.offer_id')), 'delivery retry is idempotent');

reset role;
select is((select count(*)::integer from public.procurement_deliveries where source_request_id = 'd4000000-0000-0000-0000-000000000005'), 1, 'one delivery is stored');
select set_config('test.delivery_id', (select id::text from public.procurement_deliveries where source_request_id = 'd4000000-0000-0000-0000-000000000005'), true);
select set_config('test.transaction_id', (select inventory_transaction_id::text from public.procurement_deliveries where id = current_setting('test.delivery_id')::uuid), true);
select is((select total_amount_minor from public.procurement_deliveries where id = current_setting('test.delivery_id')::uuid), 250::bigint, 'accepted quantity snapshots the offer into a 250 SEP obligation');
select is((select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_accounts account on account.id = entry.inventory_account_id where entry.item_id = 'ce000000-0000-0000-0000-000000000001' and account.account_kind = 'physical'), 10::numeric, 'delivery creates ten units of physical reserve');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_transaction_id = current_setting('test.transaction_id')::uuid), 0::numeric, 'delivery transaction is balanced');
select is((select permission_code from public.inventory_transactions where id = current_setting('test.transaction_id')::uuid), 'procurement.delivery.receive', 'ledger provenance identifies supplier delivery authority');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'procurement.delivery_received:d4000000-0000-0000-0000-000000000005'), 1, 'delivery emits one durable integration event');
select ok(exists(select 1 from public.audit_log where record_type = 'public.procurement_deliveries' and request_id = 'd4000000-0000-0000-0000-000000000005' and actor_id = 'd2000000-0000-0000-0000-000000000002'), 'delivery audit records exact actor and request');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select ok((select position ->> 'on_hand' = '10.000' and position ->> 'reserve_state' = 'critical' from jsonb_array_elements(public.get_staff_economy_workspace() -> 'positions') position where position ->> 'item_code' = 'RM-IRON-ORE'), 'dashboard derives reserve quantity and threshold state');
select ok(public.get_staff_economy_workspace() -> 'offers' @> jsonb_build_array(jsonb_build_object('id', current_setting('test.offer_id'))), 'dashboard exposes current approved purchase offer');
select ok(public.get_staff_economy_workspace() -> 'suppliers' @> jsonb_build_array(jsonb_build_object('id', current_setting('test.supplier_id'))), 'dashboard exposes registered supplier');
select lives_ok(format($test$
  select * from public.staff_mark_procurement_delivery_paid(
    %L::uuid, 1, 'VOUCHER-1001', 'Record payment handed to the producer.',
    'd4000000-0000-0000-0000-000000000006'
  )
$test$, current_setting('test.delivery_id')), 'procurement officer can record settlement evidence');
select lives_ok(format($test$
  select * from public.staff_mark_procurement_delivery_paid(
    %L::uuid, 1, 'VOUCHER-1001', 'Record payment handed to the producer.',
    'd4000000-0000-0000-0000-000000000006'
  )
$test$, current_setting('test.delivery_id')), 'settlement retry is idempotent despite stale version');

reset role;
select is((select settlement_status from public.procurement_deliveries where id = current_setting('test.delivery_id')::uuid), 'paid', 'delivery is marked paid');
select is((select version from public.procurement_deliveries where id = current_setting('test.delivery_id')::uuid), 2::bigint, 'settlement increments optimistic version');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'procurement.delivery_paid:d4000000-0000-0000-0000-000000000006'), 1, 'settlement emits one durable event');
select ok(not has_table_privilege('authenticated', 'public.item_supply_policies', 'update'), 'authenticated callers cannot bypass policy commands');
select ok((select player_sourced_only and not admin_receipt_allowed and procurement_enabled from public.item_supply_policies where item_id = 'ce000000-0000-0000-0000-000000000001'), 'keystone policy remains player-sourced after operations');

select * from finish();
rollback;
