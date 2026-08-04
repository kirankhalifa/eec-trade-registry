begin;

select plan(68);

select has_table('public', 'warehouses', 'warehouses table exists');
select has_table('public', 'stock_locations', 'stock locations table exists');
select has_table('public', 'inventory_accounts', 'inventory accounts table exists');
select has_table('public', 'inventory_transactions', 'inventory transactions table exists');
select has_table('public', 'inventory_ledger_entries', 'immutable quantity ledger exists');
select has_table('public', 'reservations', 'reservations table exists');
select has_table('public', 'reservation_events', 'reservation history exists');
select has_column('public', 'inventory_ledger_entries', 'quantity_delta', 'ledger stores signed quantity deltas');
select hasnt_column('public', 'inventory_accounts', 'current_quantity', 'inventory accounts do not store editable current stock');
select has_function('public', 'get_staff_inventory_workspace', array[]::text[], 'staff inventory workspace RPC exists');
select has_function(
  'public',
  'staff_post_inventory_receipt',
  array['uuid', 'uuid', 'numeric', 'text', 'text', 'uuid'],
  'receipt command exists'
);
select has_function(
  'public',
  'staff_reverse_inventory_transaction',
  array['uuid', 'text', 'uuid'],
  'receipt reversal command exists'
);
select has_function(
  'public',
  'staff_create_reservation',
  array['uuid', 'uuid', 'numeric', 'text', 'uuid'],
  'reservation command exists'
);
select has_function(
  'public',
  'staff_extend_reservation',
  array['uuid', 'bigint', 'timestamp with time zone', 'text', 'uuid'],
  'reservation extension command exists'
);
select has_function(
  'public',
  'staff_release_reservation',
  array['uuid', 'bigint', 'text', 'uuid'],
  'reservation release command exists'
);
select has_function(
  'public',
  'staff_expire_reservation',
  array['uuid', 'bigint', 'text', 'uuid'],
  'reservation expiry command exists'
);
select ok((select relrowsecurity from pg_class where oid = 'public.inventory_accounts'::regclass), 'inventory accounts have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.inventory_ledger_entries'::regclass), 'ledger entries have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.reservations'::regclass), 'reservations have RLS');
select ok(not has_table_privilege('authenticated', 'public.inventory_accounts', 'select'), 'authenticated users cannot read accounts directly');
select ok(not has_table_privilege('authenticated', 'public.inventory_ledger_entries', 'insert'), 'authenticated users cannot post ledger entries directly');
select ok(
  not has_function_privilege(
    'anon',
    'public.staff_post_inventory_receipt(uuid,uuid,numeric,text,text,uuid)',
    'execute'
  ),
  'anonymous callers cannot reach receipt commands'
);
select is((select display_name from public.warehouses where code = 'eec-primary'), 'East Empire Company Warehouse', 'approved EEC warehouse is configured data');
select is((select count(*)::integer from public.inventory_accounts), 0, 'seed configuration does not invent opening stock');

insert into public.warehouses (
  id, code, display_name, jurisdiction_id, operating_party_id, default_timezone
)
values (
  'aa000000-0000-0000-0000-000000000002',
  'test-secondary',
  'Test Secondary Warehouse',
  '90000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000004',
  'America/New_York'
);

insert into public.stock_locations (
  id, warehouse_id, code, display_name, location_type
)
values (
  'ab000000-0000-0000-0000-000000000010',
  'aa000000-0000-0000-0000-000000000002',
  'available',
  'Secondary available stock',
  'available'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b4000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'warehouse.operator@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b4000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'scoped.operator@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b4000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'inventory.controller@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b4000000-0000-0000-0000-000000000004',
    'authenticated', 'authenticated', 'inventory.requester@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c4000000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-000000000001', 'Warehouse Operator', 'staff'),
  ('c4000000-0000-0000-0000-000000000002', 'b4000000-0000-0000-0000-000000000002', 'Scoped Warehouse Operator', 'staff'),
  ('c4000000-0000-0000-0000-000000000003', 'b4000000-0000-0000-0000-000000000003', 'Inventory Controller', 'staff'),
  ('c4000000-0000-0000-0000-000000000004', 'b4000000-0000-0000-0000-000000000004', 'Order Requester', 'dealer');

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope
)
values
  (
    'd4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'warehouse_operator'),
    '2026-01-01T00:00:00Z',
    '{}'::jsonb
  ),
  (
    'd4000000-0000-0000-0000-000000000002',
    'c4000000-0000-0000-0000-000000000002',
    (select id from public.staff_roles where code = 'warehouse_operator'),
    '2026-01-01T00:00:00Z',
    '{"warehouse_ids":["aa000000-0000-0000-0000-000000000002"]}'::jsonb
  ),
  (
    'd4000000-0000-0000-0000-000000000003',
    'c4000000-0000-0000-0000-000000000003',
    (select id from public.staff_roles where code = 'inventory_controller'),
    '2026-01-01T00:00:00Z',
    '{}'::jsonb
  );

insert into public.orders (
  id,
  public_reference,
  ordering_party_id,
  dealer_authorization_id,
  jurisdiction_id,
  fulfillment_mode,
  status,
  currency_code,
  requested_by_actor_id,
  source_request_id
)
values
  (
    'e4000000-0000-0000-0000-000000000001',
    'EEC-ORD-TEST-1',
    '92000000-0000-0000-0000-000000000001',
    '95000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    'collection',
    'approved',
    'SEP',
    'c4000000-0000-0000-0000-000000000004',
    'e4000000-0000-0000-0000-000000000011'
  ),
  (
    'e4000000-0000-0000-0000-000000000002',
    'EEC-ORD-TEST-2',
    '92000000-0000-0000-0000-000000000001',
    '95000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    'collection',
    'approved',
    'SEP',
    'c4000000-0000-0000-0000-000000000004',
    'e4000000-0000-0000-0000-000000000012'
  );

insert into public.order_lines (
  id,
  order_id,
  line_number,
  item_id,
  item_code_snapshot,
  item_name_snapshot,
  unit_code_snapshot,
  quantity_requested,
  quantity_approved,
  status,
  currency_code_snapshot,
  control_profile_code_snapshot,
  requires_staff_review_snapshot,
  requires_transaction_approval_snapshot,
  requires_serial_tracking_snapshot
)
values
  (
    'e4100000-0000-0000-0000-000000000001',
    'e4000000-0000-0000-0000-000000000001',
    1,
    '70000000-0000-0000-0000-000000000001',
    'NAV-COMPASS',
    'Navigation Compass',
    'each',
    8,
    8,
    'approved',
    'SEP',
    'ordinary',
    false,
    false,
    false
  ),
  (
    'e4100000-0000-0000-0000-000000000002',
    'e4000000-0000-0000-0000-000000000002',
    1,
    '70000000-0000-0000-0000-000000000001',
    'NAV-COMPASS',
    'Navigation Compass',
    'each',
    10,
    10,
    'approved',
    'SEP',
    'ordinary',
    false,
    false,
    false
  );

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b4000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is(
  (select jsonb_array_length(get_staff_inventory_workspace() -> 'warehouses')),
  1,
  'warehouse-scoped operator sees only the assigned warehouse'
);
select is(
  get_staff_inventory_workspace() -> 'warehouses' -> 0 ->> 'code',
  'test-secondary',
  'warehouse scope is enforced in the projection'
);
select throws_ok(
  $test$
    select * from public.staff_post_inventory_receipt(
      'ab000000-0000-0000-0000-000000000002',
      '70000000-0000-0000-0000-000000000001',
      10,
      'SCOPE-DENIED',
      'Attempt receipt outside assigned warehouse.',
      'e4200000-0000-0000-0000-000000000001'
    )
  $test$,
  '42501',
  'staff_warehouse_permission_denied',
  'warehouse scope is enforced by the receipt command'
);

select set_config('request.jwt.claims', '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $test$select count(*) from public.inventory_accounts$test$,
  '42501',
  'permission denied for table inventory_accounts',
  'staff cannot bypass the inventory projection with direct table reads'
);
select lives_ok(
  $test$
    select * from public.staff_post_inventory_receipt(
      'ab000000-0000-0000-0000-000000000002',
      '70000000-0000-0000-0000-000000000001',
      10,
      'RECEIPT-TEST-001',
      'Receive ten fungible units into available stock.',
      'e4200000-0000-0000-0000-000000000002'
    )
  $test$,
  'authorized operator can post a fungible receipt'
);
select lives_ok(
  $test$
    select * from public.staff_post_inventory_receipt(
      'ab000000-0000-0000-0000-000000000002',
      '70000000-0000-0000-0000-000000000001',
      10,
      'RECEIPT-TEST-001',
      'Receive ten fungible units into available stock.',
      'e4200000-0000-0000-0000-000000000002'
    )
  $test$,
  'receipt retry is idempotent'
);
select throws_ok(
  $test$
    select * from public.staff_post_inventory_receipt(
      'ab000000-0000-0000-0000-000000000002',
      '70000000-0000-0000-0000-000000000004',
      1,
      'SERIAL-TEST-001',
      'Attempt serialized receipt without asset registration.',
      'e4200000-0000-0000-0000-000000000003'
    )
  $test$,
  '22023',
  'serialized_receipt_requires_asset_registry',
  'serialized goods cannot enter the fungible ledger path'
);
select ok(
  (
    select position ->> 'on_hand' = '10.000'
      and position ->> 'reserved' = '0'
      and position ->> 'available' = '10.000'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'positions') as position
    where position ->> 'item_id' = '70000000-0000-0000-0000-000000000001'
  ),
  'workspace derives ten on hand and ten available from ledger entries'
);

reset role;
select is((select count(*)::integer from public.inventory_transactions), 1, 'idempotent receipt creates one transaction');
select is((select count(*)::integer from public.inventory_ledger_entries), 2, 'receipt creates balanced external and physical entries');
select is((select sum(quantity_delta) from public.inventory_ledger_entries), 0::numeric, 'receipt ledger entries balance to zero');
select is(
  (
    select sum(entry.quantity_delta)
    from public.inventory_ledger_entries as entry
    join public.inventory_accounts as account on account.id = entry.inventory_account_id
    where account.account_kind = 'physical'
  ),
  10::numeric,
  'physical stock is the sum of posted ledger deltas'
);
select is((select count(*)::integer from public.outbox_events where event_type = 'inventory.receipt_posted'), 1, 'receipt creates one durable outbox event');
select ok(
  (
    select audit.permission_code = 'inventory.receipt.post'
      and audit.actor_id = 'c4000000-0000-0000-0000-000000000001'::uuid
      and audit.staff_assignment_id = 'd4000000-0000-0000-0000-000000000001'::uuid
    from public.audit_log as audit
    where audit.record_type = 'public.inventory_transactions'
      and audit.request_id = 'e4200000-0000-0000-0000-000000000002'
  ),
  'receipt audit records exact actor, assignment, and permission'
);
select set_config(
  'test.inventory_account_id',
  (
    select account.id::text
    from public.inventory_accounts as account
    where account.account_kind = 'physical'
      and account.item_id = '70000000-0000-0000-0000-000000000001'
      and account.warehouse_id = 'aa000000-0000-0000-0000-000000000001'
  ),
  true
);
select set_config(
  'test.receipt_transaction_id',
  (select id::text from public.inventory_transactions where transaction_type = 'receipt'),
  true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_create_reservation(
      'e4100000-0000-0000-0000-000000000001',
      %L::uuid,
      6,
      'Reserve six approved units for collection.',
      'e4200000-0000-0000-0000-000000000004'
    )$test$,
    current_setting('test.inventory_account_id')
  ),
  'authorized operator can reserve part of an approved quantity'
);
select is(
  (select public_reference from public.staff_create_reservation(
    'e4100000-0000-0000-0000-000000000001',
    current_setting('test.inventory_account_id')::uuid,
    6,
    'Reserve six approved units for collection.',
    'e4200000-0000-0000-0000-000000000004'
  )),
  'EEC-RES-1001',
  'reservation retry returns the same configurable reference'
);
select ok(
  (
    select reservation.status = 'active'
      and reservation.version = 1
      and reservation.expires_at between statement_timestamp() + interval '47 hours 59 minutes'
        and statement_timestamp() + interval '48 hours 1 minute'
    from jsonb_to_recordset(get_staff_inventory_workspace() -> 'reservations')
      as reservation(status text, version bigint, expires_at timestamptz)
  ),
  'new reservation receives the approved 48-hour active term'
);
select ok(
  (
    select position ->> 'reserved' = '6.000'
      and position ->> 'available' = '4.000'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'positions') as position
    where position ->> 'account_id' = current_setting('test.inventory_account_id')
  ),
  'reservation reduces derived availability without changing on hand'
);
select is(
  (
    select line ->> 'order_status' || ':' || line ->> 'order_version'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'order_lines') as line
    where line ->> 'order_id' = 'e4000000-0000-0000-0000-000000000001'
  ),
  'awaiting_stock:2',
  'partial reservation moves the order to awaiting stock and increments its version'
);
select throws_ok(
  format(
    $test$select * from public.staff_create_reservation(
      'e4100000-0000-0000-0000-000000000002',
      %L::uuid,
      5,
      'Attempt to reserve more than the four available units.',
      'e4200000-0000-0000-0000-000000000005'
    )$test$,
    current_setting('test.inventory_account_id')
  ),
  '22023',
  'inventory_available_insufficient',
  'reservation cannot overdraw current available stock'
);
select lives_ok(
  format(
    $test$select * from public.staff_create_reservation(
      'e4100000-0000-0000-0000-000000000001',
      %L::uuid,
      2,
      'Reserve the remaining approved quantity.',
      'e4200000-0000-0000-0000-000000000006'
    )$test$,
    current_setting('test.inventory_account_id')
  ),
  'remaining approved quantity can be reserved atomically'
);
select is(
  (
    select line ->> 'order_status' || ':' || line ->> 'order_version'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'order_lines') as line
    where line ->> 'order_id' = 'e4000000-0000-0000-0000-000000000001'
  ),
  'processing:3',
  'fully reserved order advances to processing'
);
select ok(
  (
    select position ->> 'on_hand' = '10.000'
      and position ->> 'reserved' = '8.000'
      and position ->> 'available' = '2.000'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'positions') as position
    where position ->> 'account_id' = current_setting('test.inventory_account_id')
  ),
  'multiple reservations aggregate against one locked account'
);
select set_config(
  'test.first_reservation_id',
  (
    select reservation ->> 'id'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'reservations') as reservation
    where reservation ->> 'public_reference' = 'EEC-RES-1001'
  ),
  true
);
select set_config(
  'test.second_reservation_id',
  (
    select reservation ->> 'id'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'reservations') as reservation
    where reservation ->> 'public_reference' = 'EEC-RES-1002'
  ),
  true
);
select lives_ok(
  format(
    $test$select * from public.staff_extend_reservation(
      %L::uuid,
      1,
      statement_timestamp() + interval '72 hours',
      'Extend collection availability with authorization.',
      'e4200000-0000-0000-0000-000000000007'
    )$test$,
    current_setting('test.first_reservation_id')
  ),
  'authorized extension can lengthen an active reservation'
);
select is(
  (select reservation ->> 'version'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'reservations') as reservation
    where reservation ->> 'id' = current_setting('test.first_reservation_id')),
  '2',
  'reservation extension increments its optimistic version'
);
select lives_ok(
  format(
    $test$select * from public.staff_release_reservation(
      %L::uuid,
      2,
      'Release the unconsumed claim back to available stock.',
      'e4200000-0000-0000-0000-000000000008'
    )$test$,
    current_setting('test.first_reservation_id')
  ),
  'authorized release returns unconsumed stock availability'
);
select lives_ok(
  format(
    $test$select * from public.staff_release_reservation(
      %L::uuid,
      2,
      'Release the unconsumed claim back to available stock.',
      'e4200000-0000-0000-0000-000000000008'
    )$test$,
    current_setting('test.first_reservation_id')
  ),
  'reservation release retry is idempotent despite stale version'
);
select ok(
  (
    select position ->> 'on_hand' = '10.000'
      and position ->> 'reserved' = '2.000'
      and position ->> 'available' = '8.000'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'positions') as position
    where position ->> 'account_id' = current_setting('test.inventory_account_id')
  ),
  'release changes claims while the ledger-derived on-hand quantity remains ten'
);
select is(
  (
    select line ->> 'order_status' || ':' || line ->> 'order_version'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'order_lines') as line
    where line ->> 'order_id' = 'e4000000-0000-0000-0000-000000000001'
  ),
  'awaiting_stock:4',
  'releasing a partial claim returns the order to awaiting stock'
);

reset role;
update public.reservations
set
  reserved_at = statement_timestamp() - interval '49 hours',
  expires_at = statement_timestamp() - interval '1 hour'
where id = current_setting('test.second_reservation_id')::uuid;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_expire_reservation(
      %L::uuid,
      1,
      'Record elapsed reservation and release its claim.',
      'e4200000-0000-0000-0000-000000000009'
    )$test$,
    current_setting('test.second_reservation_id')
  ),
  'elapsed reservation can be finalized as expired'
);
select is(
  (select reservation ->> 'effective_status'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'reservations') as reservation
    where reservation ->> 'id' = current_setting('test.second_reservation_id')),
  'expired',
  'expiry is explicit in the authoritative reservation state'
);
select ok(
  (
    select position ->> 'reserved' = '0'
      and position ->> 'available' = '10.000'
    from jsonb_array_elements(get_staff_inventory_workspace() -> 'positions') as position
    where position ->> 'account_id' = current_setting('test.inventory_account_id')
  ),
  'expired claims no longer reduce availability'
);

select set_config('request.jwt.claims', '{"sub":"b4000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_reverse_inventory_transaction(
      %L::uuid,
      'Reverse the incorrect receipt after all claims are released.',
      'e4200000-0000-0000-0000-000000000010'
    )$test$,
    current_setting('test.receipt_transaction_id')
  ),
  'inventory controller can post a linked reversal when stock is unclaimed'
);
select lives_ok(
  format(
    $test$select * from public.staff_reverse_inventory_transaction(
      %L::uuid,
      'Reverse the incorrect receipt after all claims are released.',
      'e4200000-0000-0000-0000-000000000010'
    )$test$,
    current_setting('test.receipt_transaction_id')
  ),
  'receipt reversal retry is idempotent'
);

reset role;
select is((select count(*)::integer from public.inventory_transactions), 2, 'receipt plus one reversal are preserved');
select is((select count(*)::integer from public.inventory_ledger_entries), 4, 'reversal adds entries without rewriting originals');
select is((select sum(quantity_delta) from public.inventory_ledger_entries), 0::numeric, 'all ledger transactions remain globally balanced');
select is(
  (
    select coalesce(sum(entry.quantity_delta), 0)
    from public.inventory_ledger_entries as entry
    join public.inventory_accounts as account on account.id = entry.inventory_account_id
    where account.account_kind = 'physical'
  ),
  0::numeric,
  'linked reversal returns the physical balance to zero'
);
select ok(
  exists (
    select 1 from public.inventory_transactions as reversal
    where reversal.reversal_of_id = current_setting('test.receipt_transaction_id')::uuid
  ),
  'reversal links to the immutable original transaction'
);
select throws_ok(
  format(
    $test$update public.inventory_transactions set reason = 'Rewrite' where id = %L::uuid$test$,
    current_setting('test.receipt_transaction_id')
  ),
  '55000',
  'posted_inventory_is_immutable',
  'posted transaction headers cannot be rewritten'
);
select throws_ok(
  $test$update public.inventory_ledger_entries set quantity_delta = 99 where line_number = 1$test$,
  '55000',
  'posted_inventory_is_immutable',
  'posted ledger entries cannot be rewritten'
);
select is((select count(*)::integer from public.reservation_events), 5, 'reservation create, extend, release, create, and expiry events are append-only');
select is((select count(*)::integer from public.outbox_events where aggregate_type in ('inventory_transaction', 'reservation')), 7, 'accepted inventory and reservation commands create durable outbox events');
select ok(
  (
    select audit.permission_code = 'reservation.release'
      and audit.actor_id = 'c4000000-0000-0000-0000-000000000001'::uuid
    from public.audit_log as audit
    where audit.record_type = 'public.reservations'
      and audit.request_id = 'e4200000-0000-0000-0000-000000000009'
  ),
  'expiry records exact actor and release permission in audit'
);

select * from finish();
rollback;
