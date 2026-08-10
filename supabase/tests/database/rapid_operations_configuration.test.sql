begin;

select plan(46);

select has_table('public', 'staff_command_receipts', 'staff command receipt table exists');
select has_function('public', 'get_staff_configuration_workspace', array[]::text[], 'configuration workspace exists');
select has_function('public', 'staff_create_configuration_reference', array['text','text','text','text','text','text','smallint','integer','text','uuid'], 'reference creation command exists');
select has_function('public', 'staff_create_control_profile', array['text','text','text','boolean','boolean','boolean','text','uuid'], 'control creation command exists');
select has_function('public', 'staff_quick_post_inventory_receipt', array['uuid','text','numeric','text','text','uuid'], 'quick receipt command exists');
select has_function('public', 'staff_set_item_public_terms', array['uuid','boolean','text','text','text','text','text','numeric','numeric','text','uuid','bigint','text','uuid'], 'public terms command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.staff_command_receipts'::regclass), 'command receipts have RLS');
select ok(not has_table_privilege('authenticated', 'public.staff_command_receipts', 'insert'), 'authenticated callers cannot insert command receipts');
select ok(not has_function_privilege('anon', 'public.staff_quick_post_inventory_receipt(uuid,text,numeric,text,text,uuid)', 'execute'), 'anonymous callers cannot quick-post inventory');
select is((select count(*)::integer from public.permission_scopes where code in ('configuration.read','configuration.manage','publication.manage','pricing.manage')), 4, 'four rapid administration permissions are configured');
select is((select count(*)::integer from public.staff_role_permissions rp join public.staff_roles role on role.id = rp.staff_role_id join public.permission_scopes permission on permission.id = rp.permission_scope_id where role.code = 'platform_administrator' and permission.code like 'configuration.%'), 2, 'platform administrators receive configuration read and manage');
select is((select count(*)::integer from public.staff_role_permissions rp join public.staff_roles role on role.id = rp.staff_role_id join public.permission_scopes permission on permission.id = rp.permission_scope_id where role.code = 'catalogue_manager' and permission.code in ('configuration.read','publication.manage','pricing.manage')), 3, 'catalogue managers receive the new catalogue presentation permissions');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('fa100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rapid.admin@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('fa100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rapid.denied@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('fa200000-0000-4000-8000-000000000001', 'fa100000-0000-4000-8000-000000000001', 'Rapid Administrator', 'staff'),
  ('fa200000-0000-4000-8000-000000000002', 'fa100000-0000-4000-8000-000000000002', 'Denied Operator', 'staff');

insert into public.staff_assignments (actor_id, staff_role_id, effective_from, assignment_scope)
select 'fa200000-0000-4000-8000-000000000001', role.id, '2026-01-01T00:00:00Z', '{}'::jsonb
from public.staff_roles as role
where role.code in ('platform_administrator','catalogue_manager','economic_steward','warehouse_operator');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_configuration_workspace()$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot read configuration');

select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_configuration_workspace()$test$, 'authorized administrator can read configuration');
select lives_ok($test$
  select * from public.staff_create_configuration_reference(
    'item_category', 'rapid-test', 'Rapid test goods', '', 'Created in a database test.', '', 0, 95,
    'Create a configurable category.', 'fa300000-0000-4000-8000-000000000001'
  )
$test$, 'administrator can add a configuration option');
select lives_ok($test$
  select * from public.staff_create_configuration_reference(
    'item_category', 'rapid-test', 'Rapid test goods', '', 'Created in a database test.', '', 0, 95,
    'Create a configurable category.', 'fa300000-0000-4000-8000-000000000001'
  )
$test$, 'configuration creation retry is idempotent');

reset role;
select is((select count(*)::integer from public.item_categories where code = 'rapid-test'), 1, 'retry creates one category');
select is((select count(*)::integer from public.staff_command_receipts where request_id = 'fa300000-0000-4000-8000-000000000001'), 1, 'configuration command stores one idempotency receipt');
select ok(exists(select 1 from public.audit_log where record_type = 'public.item_categories' and request_id = 'fa300000-0000-4000-8000-000000000001'), 'configuration creation is audited');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($test$
  select * from public.staff_quick_create_item(
    '', '', 'Rapid Stocked Good', 'A stocked good created in one command.',
    'rapid-test', 'each', 'warehouse_stocked', 'ordinary', 'available', true,
    'Available through current trade terms.',
    '80000000-0000-0000-0000-000000000001', 250,
    null, null, 30, 60, false, null, 100,
    'ab000000-0000-0000-0000-000000000002', 12, '',
    'Create, publish, price, and receive the test item.',
    'fa300000-0000-4000-8000-000000000002'
  )
$test$, 'one command creates, publishes, prices, configures, and receives an item');
select lives_ok($test$
  select * from public.staff_quick_create_item(
    '', '', 'Rapid Stocked Good', 'A stocked good created in one command.',
    'rapid-test', 'each', 'warehouse_stocked', 'ordinary', 'available', true,
    'Available through current trade terms.',
    '80000000-0000-0000-0000-000000000001', 250,
    null, null, 30, 60, false, null, 100,
    'ab000000-0000-0000-0000-000000000002', 12, '',
    'Create, publish, price, and receive the test item.',
    'fa300000-0000-4000-8000-000000000002'
  )
$test$, 'complete item onboarding retry is idempotent');

reset role;
select is((select count(*)::integer from public.items where display_name = 'Rapid Stocked Good'), 1, 'one canonical item is created');
select set_config('test.rapid_item_id', (select id::text from public.items where display_name = 'Rapid Stocked Good'), true);
select set_config('test.rapid_item_code', (select item_code from public.items where display_name = 'Rapid Stocked Good'), true);
select ok((select supply_mode = 'warehouse_stocked' and admin_receipt_allowed and not procurement_enabled from public.item_supply_policies where item_id = current_setting('test.rapid_item_id')::uuid), 'supply preset is authoritative database configuration');
select ok(exists(select 1 from public.item_publications where item_id = current_setting('test.rapid_item_id')::uuid and publication_status = 'published' and effective_until is null), 'quick-created item is publicly published');
select is((select amount_minor from public.price_rules where item_id = current_setting('test.rapid_item_id')::uuid and effective_until is null), 250::bigint, 'optional price is stored on the selected schedule');
select is((select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_accounts account on account.id = entry.inventory_account_id where entry.item_id = current_setting('test.rapid_item_id')::uuid and account.account_kind = 'physical'), 12::numeric, 'optional opening receipt creates physical stock');
select is((select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_transactions transaction on transaction.id = entry.inventory_transaction_id where transaction.request_id = 'fa300000-0000-4000-8000-000000000002'), 0::numeric, 'opening inventory transaction is balanced');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'catalogue.item_onboarded:fa300000-0000-4000-8000-000000000002'), 1, 'onboarding emits one durable projection event');
select is((select count(*)::integer from public.staff_command_receipts where request_id = 'fa300000-0000-4000-8000-000000000002'), 1, 'onboarding stores one command receipt');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$
  select * from public.staff_quick_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002', %L, 5, '', '',
    'fa300000-0000-4000-8000-000000000003'
  )
$test$, current_setting('test.rapid_item_code')), 'three-field quick receipt posts ordinary inventory');
select lives_ok(format($test$
  select * from public.staff_quick_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002', %L, 5, '', '',
    'fa300000-0000-4000-8000-000000000003'
  )
$test$, current_setting('test.rapid_item_code')), 'quick receipt retry is idempotent');

reset role;
select is((select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_accounts account on account.id = entry.inventory_account_id where entry.item_id = current_setting('test.rapid_item_id')::uuid and account.account_kind = 'physical'), 17::numeric, 'quick receipt increases ledger-derived stock once');
select is((select count(*)::integer from public.inventory_transactions where request_id = 'fa300000-0000-4000-8000-000000000003'), 1, 'quick receipt retry creates one inventory transaction');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok($test$
  select * from public.staff_quick_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002', 'RM-IRON-ORE', 5, '', '',
    'fa300000-0000-4000-8000-000000000004'
  )
$test$, 'P0002', 'quick_receipt_item_not_found', 'quick receipt cannot bypass player-sourced provenance');
select lives_ok(format($test$
  select * from public.staff_set_item_public_terms(
    %L::uuid, true, 'Rapid Stocked Good', 'Updated public description.',
    'ordinary', 'available', 'Updated public requirements.', null, 1,
    'set', '80000000-0000-0000-0000-000000000001', 300,
    'Replace current public terms and price.',
    'fa300000-0000-4000-8000-000000000005'
  )
$test$, current_setting('test.rapid_item_id')), 'authorized staff can replace effective public terms and price');
select lives_ok(format($test$
  select * from public.staff_set_item_public_terms(
    %L::uuid, true, 'Rapid Stocked Good', 'Updated public description.',
    'ordinary', 'available', 'Updated public requirements.', null, 1,
    'set', '80000000-0000-0000-0000-000000000001', 300,
    'Replace current public terms and price.',
    'fa300000-0000-4000-8000-000000000005'
  )
$test$, current_setting('test.rapid_item_id')), 'public terms retry is idempotent');

reset role;
select is((select amount_minor from public.price_rules where item_id = current_setting('test.rapid_item_id')::uuid and effective_until is null), 300::bigint, 'new price is current');
select is((select count(*)::integer from public.price_rules where item_id = current_setting('test.rapid_item_id')::uuid), 2, 'prior price remains as effective-dated history');
select is((select count(*)::integer from public.item_publications where item_id = current_setting('test.rapid_item_id')::uuid and publication_status = 'published' and effective_until is null), 1, 'exactly one public presentation is current');
select ok(exists(select 1 from public.item_publications where item_id = current_setting('test.rapid_item_id')::uuid and effective_until is not null), 'prior public presentation remains as history');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'catalogue.public_terms_changed:fa300000-0000-4000-8000-000000000005'), 1, 'public-term change emits one projection event');
select is((select count(*)::integer from public.staff_command_receipts where request_id = 'fa300000-0000-4000-8000-000000000005'), 1, 'public-term change stores one command receipt');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fa100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok((select item ->> 'price_amount_minor' = '300' from jsonb_array_elements(public.get_staff_configuration_workspace() -> 'items') item where item ->> 'id' = current_setting('test.rapid_item_id')), 'workspace immediately exposes current public price');
reset role;
select ok(not has_table_privilege('authenticated', 'public.item_categories', 'update'), 'authenticated users cannot edit categories directly');
select ok(not has_table_privilege('authenticated', 'public.item_publications', 'insert'), 'authenticated users cannot bypass publication commands');
select ok(not has_table_privilege('authenticated', 'public.price_rules', 'insert'), 'authenticated users cannot bypass price commands');

select * from finish();
rollback;
