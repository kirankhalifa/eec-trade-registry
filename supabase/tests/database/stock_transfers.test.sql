begin;

select plan(66);

select has_table('public', 'stock_transfers', 'stock transfer register exists');
select has_table('public', 'stock_transfer_events', 'stock transfer history exists');
select has_column('public', 'stock_transfers', 'transit_inventory_account_id', 'transfers retain the transit account');
select has_column('public', 'stock_transfers', 'dispatch_transaction_id', 'transfers retain dispatch evidence');
select has_column('public', 'stock_transfers', 'receipt_transaction_id', 'transfers retain receipt evidence');
select has_function('public', 'get_staff_transfer_workspace', array[]::text[], 'staff transfer workspace exists');
select has_function('public', 'staff_create_stock_transfer', array['uuid','uuid','numeric','text','uuid'], 'transfer request command exists');
select has_function('public', 'staff_authorize_stock_transfer', array['uuid','bigint','text','uuid'], 'transfer authorization command exists');
select has_function('public', 'staff_dispatch_stock_transfer', array['uuid','bigint','text','uuid'], 'transfer dispatch command exists');
select has_function('public', 'staff_receive_stock_transfer', array['uuid','bigint','text','uuid'], 'transfer receipt command exists');
select has_function('public', 'staff_dispute_stock_transfer', array['uuid','bigint','text','uuid'], 'transfer dispute command exists');
select has_function('public', 'staff_cancel_stock_transfer', array['uuid','bigint','text','uuid'], 'transfer cancellation command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.stock_transfers'::regclass), 'transfer register has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.stock_transfer_events'::regclass), 'transfer history has RLS');
select ok(not has_table_privilege('authenticated', 'public.stock_transfers', 'select'), 'authenticated cannot read transfer rows directly');
select ok(not has_table_privilege('authenticated', 'public.stock_transfer_events', 'insert'), 'authenticated cannot forge transfer history');
select ok(not has_function_privilege('anon', 'public.staff_dispatch_stock_transfer(uuid,bigint,text,uuid)', 'execute'), 'anonymous cannot dispatch stock');
select is((select count(*)::integer from public.permission_scopes where code like 'inventory.transfer.%'), 6, 'six transfer permissions are configured');
select is((select count(*)::integer from public.notification_templates where event_type like 'transfer.%'), 4, 'four transfer notification templates are configured');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'transfer.%'), 4, 'four transfer notification routes are configured');
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'inventory_accounts_custody_identity_idx'
  ),
  'custody account identity is unique'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgname = 'inventory_custody_nonnegative_check'
      and not tgisinternal
  ),
  'custody balances have a deferred nonnegative guard'
);

insert into public.warehouses (
  id, code, display_name, jurisdiction_id, operating_party_id, default_timezone
)
values (
  'aa000000-0000-0000-0000-000000000003',
  'transfer-secondary',
  'Transfer Secondary Warehouse',
  '90000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000004',
  'America/New_York'
);

insert into public.stock_locations (
  id, warehouse_id, code, display_name, location_type
)
values (
  'ab000000-0000-0000-0000-000000000020',
  'aa000000-0000-0000-0000-000000000003',
  'available',
  'Transfer destination',
  'available'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b5000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
    'transfer.operator@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  ),
  (
    'b5000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
    'transfer.controller@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  ),
  (
    'b5000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
    'transfer.unauthorized@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c5000000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'Transfer Operator', 'staff'),
  ('c5000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000002', 'Transfer Controller', 'staff'),
  ('c5000000-0000-0000-0000-000000000003', 'b5000000-0000-0000-0000-000000000003', 'Unassigned Staff', 'staff');

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope
)
values
  (
    'd5000000-0000-0000-0000-000000000001',
    'c5000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'warehouse_operator'),
    '2026-01-01T00:00:00Z', '{}'::jsonb
  ),
  (
    'd5000000-0000-0000-0000-000000000002',
    'c5000000-0000-0000-0000-000000000002',
    (select id from public.staff_roles where code = 'inventory_controller'),
    '2026-01-01T00:00:00Z', '{}'::jsonb
  );

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok(
  $test$select public.get_staff_transfer_workspace()$test$,
  '42501', 'staff_warehouse_permission_denied',
  'unassigned staff cannot open transfer operations'
);

select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $test$select * from public.staff_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000001',
    12, 'TRANSFER-SOURCE-STOCK', 'Prepare source stock',
    'f5000000-0000-0000-0000-000000000001'
  )$test$,
  'operator can prepare source stock'
);
select lives_ok(
  $test$select * from public.staff_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000020',
    '70000000-0000-0000-0000-000000000001',
    2, 'TRANSFER-DESTINATION-STOCK', 'Prepare destination account',
    'f5000000-0000-0000-0000-000000000002'
  )$test$,
  'operator can prepare the destination account'
);

reset role;
select set_config(
  'test.transfer_source_account_id',
  (
    select account.id::text from public.inventory_accounts as account
    where account.warehouse_id = 'aa000000-0000-0000-0000-000000000001'
      and account.stock_location_id = 'ab000000-0000-0000-0000-000000000002'
      and account.item_id = '70000000-0000-0000-0000-000000000001'
  ),
  true
);
select set_config(
  'test.transfer_destination_account_id',
  (
    select account.id::text from public.inventory_accounts as account
    where account.warehouse_id = 'aa000000-0000-0000-0000-000000000003'
      and account.stock_location_id = 'ab000000-0000-0000-0000-000000000020'
      and account.item_id = '70000000-0000-0000-0000-000000000001'
  ),
  true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_create_stock_transfer(%L::uuid, %L::uuid, 5, 'Rebalance warehouses', 'f5000000-0000-0000-0000-000000000003')$test$,
    current_setting('test.transfer_source_account_id'),
    current_setting('test.transfer_destination_account_id')
  ),
  'operator can create a transfer request'
);
select lives_ok(
  format(
    $test$select * from public.staff_create_stock_transfer(%L::uuid, %L::uuid, 5, 'Rebalance warehouses', 'f5000000-0000-0000-0000-000000000003')$test$,
    current_setting('test.transfer_source_account_id'),
    current_setting('test.transfer_destination_account_id')
  ),
  'repeating the request is idempotent'
);
select lives_ok(
  $test$select public.get_staff_transfer_workspace()$test$,
  'operator can open the transfer workspace'
);
select set_config(
  'test.stock_transfer_id',
  (
    select stock_transfer_id::text
    from public.staff_create_stock_transfer(
      current_setting('test.transfer_source_account_id')::uuid,
      current_setting('test.transfer_destination_account_id')::uuid,
      5, 'Rebalance warehouses',
      'f5000000-0000-0000-0000-000000000003'
    )
  ),
  true
);
select throws_ok(
  format(
    $test$select * from public.staff_authorize_stock_transfer(%L, 1, 'Approve movement', 'f5000000-0000-0000-0000-000000000004')$test$,
    current_setting('test.stock_transfer_id')
  ),
  '42501', 'staff_warehouse_permission_denied',
  'warehouse operator cannot self-authorize a transfer'
);

select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_authorize_stock_transfer(%L, 1, 'Approve movement', 'f5000000-0000-0000-0000-000000000004')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'inventory controller can authorize a transfer'
);
select lives_ok(
  format(
    $test$select * from public.staff_authorize_stock_transfer(%L, 1, 'Approve movement', 'f5000000-0000-0000-0000-000000000004')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'authorization retries are idempotent'
);

reset role;
select is((select status from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 'authorized', 'authorization advances transfer state');
select is((select version from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 2::bigint, 'authorization increments transfer version once');
select is((select count(*)::integer from public.stock_transfer_events where event_type = 'authorized'), 1, 'authorization writes one immutable event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_dispatch_stock_transfer(%L, 2, 'Release carrier custody', 'f5000000-0000-0000-0000-000000000005')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'operator can dispatch an authorized transfer'
);
select lives_ok(
  format(
    $test$select * from public.staff_dispatch_stock_transfer(%L, 2, 'Release carrier custody', 'f5000000-0000-0000-0000-000000000005')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'dispatch retries are idempotent'
);
select throws_ok(
  format(
    $test$select * from public.staff_cancel_stock_transfer(%L, 3, 'Try to erase dispatch', 'f5000000-0000-0000-0000-000000000006')$test$,
    current_setting('test.stock_transfer_id')
  ),
  '42501', 'staff_warehouse_permission_denied',
  'operator lacks the controller cancellation permission'
);

reset role;
select is((select status from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 'dispatched', 'dispatch advances transfer state');
select is((select version from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 3::bigint, 'dispatch increments transfer version once');
select is((select count(*)::integer from public.inventory_transactions where transaction_type = 'transfer_dispatch'), 1, 'dispatch posts one transaction');
select is((select count(*)::integer from public.inventory_ledger_entries where inventory_transaction_id = (select dispatch_transaction_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 2, 'dispatch posts two ledger entries');
select is((select coalesce(sum(quantity_delta), 0) from public.inventory_ledger_entries where inventory_transaction_id = (select dispatch_transaction_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 0::numeric, 'dispatch ledger is balanced');
select is((select coalesce(sum(quantity_delta), 0) from public.inventory_ledger_entries where inventory_account_id = (select source_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 7::numeric, 'source balance falls at dispatch');
select is((select coalesce(sum(quantity_delta), 0) from public.inventory_ledger_entries where inventory_account_id = (select transit_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 5::numeric, 'dispatched stock is represented in transit');
select is((select account_kind from public.inventory_accounts where id = (select transit_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 'custody', 'in-transit balance uses a custody account');
select is((select stock_state from public.inventory_accounts where id = (select transit_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 'in_transit', 'transit account has explicit state');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok(
  format(
    $test$select * from public.staff_cancel_stock_transfer(%L, 3, 'Post-dispatch cancellation', 'f5000000-0000-0000-0000-000000000006')$test$,
    current_setting('test.stock_transfer_id')
  ),
  '22023', 'stock_transfer_not_cancellable',
  'even a controller cannot cancel dispatched stock'
);

select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_dispute_stock_transfer(%L, 3, 'Seal mismatch at receiving', 'f5000000-0000-0000-0000-000000000007')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'destination operator can dispute a dispatched transfer'
);
select lives_ok(
  format(
    $test$select * from public.staff_receive_stock_transfer(%L, 4, 'Count reconciled and accepted', 'f5000000-0000-0000-0000-000000000008')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'destination operator can receive a disputed transfer after reconciliation'
);
select lives_ok(
  format(
    $test$select * from public.staff_receive_stock_transfer(%L, 4, 'Count reconciled and accepted', 'f5000000-0000-0000-0000-000000000008')$test$,
    current_setting('test.stock_transfer_id')
  ),
  'receipt retries are idempotent'
);

reset role;
select is((select status from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 'received', 'receipt closes transfer state');
select is((select version from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003'), 5::bigint, 'dispute and receipt each increment version once');
select is((select count(*)::integer from public.inventory_transactions where transaction_type = 'transfer_receipt'), 1, 'receipt posts one transaction');
select is((select coalesce(sum(quantity_delta), 0) from public.inventory_ledger_entries where inventory_account_id = (select transit_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 0::numeric, 'receipt clears in-transit quantity');
select is((select coalesce(sum(quantity_delta), 0) from public.inventory_ledger_entries where inventory_account_id = (select destination_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 7::numeric, 'receipt increases destination balance');
select is((select count(*)::integer from public.stock_transfer_events where stock_transfer_id = (select id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 5, 'full transfer has five immutable events');
select is((select count(*)::integer from public.outbox_events where event_type like 'transfer.%' and aggregate_id = (select id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), 4, 'transfer emits requested, dispatch, dispute, and receipt events');
select ok((select count(*) from public.audit_log where record_type = 'public.stock_transfers' and record_id = (select id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')) >= 5, 'every transfer state change is audited');
select ok((select public_reference from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003') ~ '^EEC-TRN-[0-9]{4}$', 'transfer reference uses configured sequence');
select is((select owner_party_id from public.inventory_accounts where id = (select transit_inventory_account_id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')), '92000000-0000-0000-0000-000000000004'::uuid, 'ownership remains unchanged in transit');

select throws_ok(
  format(
    $test$update public.stock_transfer_events set reason = 'rewrite' where stock_transfer_id = %L$test$,
    (select id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000003')
  ),
  '55000', 'posted_inventory_is_immutable',
  'transfer history cannot be rewritten'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_create_stock_transfer(%L::uuid, %L::uuid, 1, 'Create cancellable transfer', 'f5000000-0000-0000-0000-000000000009')$test$,
    current_setting('test.transfer_source_account_id'),
    current_setting('test.transfer_destination_account_id')
  ),
  'controller can create a second transfer'
);
select set_config(
  'test.cancel_transfer_id',
  (
    select stock_transfer_id::text
    from public.staff_create_stock_transfer(
      current_setting('test.transfer_source_account_id')::uuid,
      current_setting('test.transfer_destination_account_id')::uuid,
      1, 'Create cancellable transfer',
      'f5000000-0000-0000-0000-000000000009'
    )
  ),
  true
);
select lives_ok(
  format(
    $test$select * from public.staff_cancel_stock_transfer(%L, 1, 'Demand withdrawn before dispatch', 'f5000000-0000-0000-0000-000000000010')$test$,
    current_setting('test.cancel_transfer_id')
  ),
  'controller can cancel a pending transfer'
);

reset role;
select is((select status from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000009'), 'cancelled', 'pending cancellation is recorded');
select is((select count(*)::integer from public.inventory_transactions where source_reference = (select public_reference from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000009')), 0, 'cancelled transfer never posts inventory');
select is((select count(*)::integer from public.stock_transfer_events where stock_transfer_id = (select id from public.stock_transfers where source_request_id = 'f5000000-0000-0000-0000-000000000009')), 2, 'cancelled transfer preserves request and cancellation history');

select * from finish();
rollback;
