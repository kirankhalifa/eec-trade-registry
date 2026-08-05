begin;

select plan(67);

select has_table('public', 'serialized_assets', 'serialized asset register exists');
select has_table('public', 'asset_reservations', 'exclusive asset reservations exist');
select has_table('public', 'asset_events', 'immutable asset events exist');
select has_table('public', 'asset_inspections', 'asset inspection evidence exists');
select has_function('public', 'get_staff_asset_workspace', array[]::text[], 'asset workspace exists');
select has_function('public', 'staff_register_serialized_asset', array['uuid','uuid','text','text','text','text','uuid'], 'asset registration command exists');
select has_function('public', 'staff_reserve_serialized_asset', array['uuid','uuid','bigint','text','uuid'], 'exclusive reservation command exists');
select has_function('public', 'staff_release_asset_reservation', array['uuid','bigint','text','uuid'], 'reservation release command exists');
select has_function('public', 'staff_transfer_serialized_asset_custody', array['uuid','bigint','uuid','uuid','text','text','uuid'], 'custody transfer command exists');
select has_function('public', 'staff_record_asset_inspection', array['uuid','bigint','text','text','timestamp with time zone','text','uuid'], 'inspection command exists');
select has_function('public', 'staff_change_serialized_asset_status', array['uuid','bigint','text','text','uuid'], 'lifecycle command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.serialized_assets'::regclass), 'asset register has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.asset_reservations'::regclass), 'asset reservations have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.asset_events'::regclass), 'asset history has RLS');
select ok(not has_table_privilege('authenticated', 'public.serialized_assets', 'select'), 'authenticated cannot read asset rows directly');
select ok(not has_table_privilege('authenticated', 'public.asset_events', 'insert'), 'authenticated cannot forge asset events');
select ok(not has_function_privilege('anon', 'public.staff_register_serialized_asset(uuid,uuid,text,text,text,text,uuid)', 'execute'), 'anonymous cannot register assets');
select is((select count(*)::integer from public.permission_scopes where code like 'asset.%'), 6, 'six asset permissions are configured');
select is((select count(*)::integer from public.notification_templates where event_type like 'asset.%'), 4, 'four asset notification templates are configured');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'asset.%'), 4, 'four asset notification routes are configured');
select ok(
  exists (select 1 from pg_indexes where indexname = 'asset_reservations_one_active_asset_idx'),
  'one active reservation per asset is enforced'
);
select ok(
  exists (select 1 from pg_indexes where indexname = 'asset_reservations_one_active_line_idx'),
  'one active serialized allocation per order line is enforced'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b7000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
    'asset.controller@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  ),
  (
    'b7000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
    'asset.operator@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  ),
  (
    'b7000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
    'asset.unauthorized@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001', 'Asset Controller', 'staff'),
  ('c7000000-0000-0000-0000-000000000002', 'b7000000-0000-0000-0000-000000000002', 'Asset Operator', 'staff'),
  ('c7000000-0000-0000-0000-000000000003', 'b7000000-0000-0000-0000-000000000003', 'Unassigned Asset Viewer', 'staff');

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope
)
values
  (
    'd7000000-0000-0000-0000-000000000001',
    'c7000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'inventory_controller'),
    '2026-01-01T00:00:00Z', '{}'::jsonb
  ),
  (
    'd7000000-0000-0000-0000-000000000002',
    'c7000000-0000-0000-0000-000000000002',
    (select id from public.staff_roles where code = 'warehouse_operator'),
    '2026-01-01T00:00:00Z', '{}'::jsonb
  );

insert into public.orders (
  id, public_reference, ordering_party_id, dealer_authorization_id,
  jurisdiction_id, fulfillment_mode, status, currency_code,
  requested_by_actor_id, source_request_id
)
values (
  'e7000000-0000-0000-0000-000000000001', 'EEC-ORD-ASSET-1',
  '92000000-0000-0000-0000-000000000001',
  '95000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001', 'collection', 'approved', 'SEP',
  'c7000000-0000-0000-0000-000000000001',
  'e7000000-0000-0000-0000-000000000011'
);

insert into public.order_lines (
  id, order_id, line_number, item_id, item_code_snapshot, item_name_snapshot,
  unit_code_snapshot, quantity_requested, quantity_approved, status,
  currency_code_snapshot, control_profile_code_snapshot,
  requires_staff_review_snapshot, requires_transaction_approval_snapshot,
  requires_serial_tracking_snapshot
)
values (
  'e7100000-0000-0000-0000-000000000001',
  'e7000000-0000-0000-0000-000000000001', 1,
  '70000000-0000-0000-0000-000000000004', 'SG-CHRONO-001',
  'Master Navigation Chronometer', 'each', 1, 1, 'approved', 'SEP',
  'unique', true, true, true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok(
  $test$select public.get_staff_asset_workspace()$test$,
  '42501', 'staff_permission_denied',
  'unassigned staff cannot open the asset workspace'
);

select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $test$select * from public.staff_register_serialized_asset(
    '70000000-0000-0000-0000-000000000004',
    'ab000000-0000-0000-0000-000000000002',
    'CHRONO-TEST-001', 'good', 'Test provenance chain.',
    'Register inspected unique stock.',
    'f7000000-0000-0000-0000-000000000001'
  )$test$,
  'warehouse operator can register a serialized asset'
);
select lives_ok(
  $test$select * from public.staff_register_serialized_asset(
    '70000000-0000-0000-0000-000000000004',
    'ab000000-0000-0000-0000-000000000002',
    'CHRONO-TEST-001', 'good', 'Test provenance chain.',
    'Register inspected unique stock.',
    'f7000000-0000-0000-0000-000000000001'
  )$test$,
  'registration retry is idempotent'
);
select lives_ok($test$select public.get_staff_asset_workspace()$test$, 'operator can read serialized assets');
select is(jsonb_array_length(public.get_staff_asset_workspace() -> 'assets'), 1, 'workspace exposes the registered asset');
select set_config(
  'test.asset_id',
  public.get_staff_asset_workspace() -> 'assets' -> 0 ->> 'id', true
);

reset role;
select ok((select public_reference from public.serialized_assets where source_request_id = 'f7000000-0000-0000-0000-000000000001') ~ '^EEC-AST-[0-9]{4}$', 'asset reference uses configured sequence');
select is((select status from public.serialized_assets where source_request_id = 'f7000000-0000-0000-0000-000000000001'), 'available', 'registered good asset is available');
select is((select count(*)::integer from public.asset_events where event_type = 'registered'), 1, 'registration writes one event');
select is((select count(*)::integer from public.outbox_events where event_type = 'asset.registered'), 1, 'registration emits one durable event');
select throws_ok(
  $test$insert into public.serialized_assets (
    public_reference, item_id, serial_marking, owner_party_id,
    current_custodian_party_id, current_warehouse_id, current_stock_location_id,
    registered_by_actor_id, source_request_id
  ) values (
    'EEC-AST-DUPLICATE', '70000000-0000-0000-0000-000000000004', 'chrono-test-001',
    '92000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000004',
    'aa000000-0000-0000-0000-000000000001', 'ab000000-0000-0000-0000-000000000002',
    'c7000000-0000-0000-0000-000000000001', 'f7000000-0000-0000-0000-000000000099'
  )$test$,
  '23505', null,
  'serial markings are unique per canonical item without case sensitivity'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_reserve_serialized_asset(
      %L::uuid, 'e7100000-0000-0000-0000-000000000001', 1,
      'Allocate the approved unique line.',
      'f7000000-0000-0000-0000-000000000002'
    )$test$,
    current_setting('test.asset_id')
  ),
  'operator can exclusively reserve an asset to approved unique demand'
);
select lives_ok(
  format(
    $test$select * from public.staff_reserve_serialized_asset(
      %L::uuid, 'e7100000-0000-0000-0000-000000000001', 1,
      'Allocate the approved unique line.',
      'f7000000-0000-0000-0000-000000000002'
    )$test$,
    current_setting('test.asset_id')
  ),
  'asset reservation retry is idempotent'
);
select set_config(
  'test.asset_reservation_id',
  public.get_staff_asset_workspace() -> 'assets' -> 0 -> 'active_reservation' ->> 'id',
  true
);
select throws_ok(
  format(
    $test$select * from public.staff_transfer_serialized_asset_custody(
      %L::uuid, 2, '92000000-0000-0000-0000-000000000001', null,
      'good', 'Attempt reserved custody movement.',
      'f7000000-0000-0000-0000-000000000003'
    )$test$,
    current_setting('test.asset_id')
  ),
  '22023', 'serialized_asset_not_transferable',
  'reserved asset cannot change custody outside reservation consumption'
);

select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 2, 'missing', 'Attempt missing while reserved.',
      'f7000000-0000-0000-0000-000000000004'
    )$test$,
    current_setting('test.asset_id')
  ),
  '22023', 'asset_active_reservation_requires_release',
  'controller must release active allocation before lifecycle action'
);
select lives_ok(
  format(
    $test$select * from public.staff_release_asset_reservation(
      %L::uuid, 1, 'Order allocation withdrawn.',
      'f7000000-0000-0000-0000-000000000005'
    )$test$,
    current_setting('test.asset_reservation_id')
  ),
  'authorized staff can release an asset reservation'
);
select lives_ok(
  format(
    $test$select * from public.staff_release_asset_reservation(
      %L::uuid, 1, 'Order allocation withdrawn.',
      'f7000000-0000-0000-0000-000000000005'
    )$test$,
    current_setting('test.asset_reservation_id')
  ),
  'reservation release retry is idempotent'
);

reset role;
select is((select status from public.asset_reservations where id = current_setting('test.asset_reservation_id')::uuid), 'released', 'reservation is terminally released');
select is((select status from public.serialized_assets where id = current_setting('test.asset_id')::uuid), 'available', 'release restores internal availability');
select is((select count(*)::integer from public.asset_events where asset_id = current_setting('test.asset_id')::uuid), 3, 'registration, reservation, and release are preserved');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_record_asset_inspection(
      %L::uuid, 3, 'fair', 'Calibration within serviceable range.',
      statement_timestamp() + interval '90 days', 'Routine condition inspection.',
      'f7000000-0000-0000-0000-000000000006'
    )$test$,
    current_setting('test.asset_id')
  ),
  'operator can append inspection evidence'
);
select lives_ok(
  format(
    $test$select * from public.staff_record_asset_inspection(
      %L::uuid, 3, 'fair', 'Calibration within serviceable range.',
      statement_timestamp() + interval '90 days', 'Routine condition inspection.',
      'f7000000-0000-0000-0000-000000000006'
    )$test$,
    current_setting('test.asset_id')
  ),
  'inspection retry is idempotent'
);
select lives_ok(
  format(
    $test$select * from public.staff_transfer_serialized_asset_custody(
      %L::uuid, 4, '92000000-0000-0000-0000-000000000001', null,
      'fair', 'Accepted external custodian handoff.',
      'f7000000-0000-0000-0000-000000000007'
    )$test$,
    current_setting('test.asset_id')
  ),
  'operator can record accepted external custody'
);
select lives_ok(
  format(
    $test$select * from public.staff_transfer_serialized_asset_custody(
      %L::uuid, 4, '92000000-0000-0000-0000-000000000001', null,
      'fair', 'Accepted external custodian handoff.',
      'f7000000-0000-0000-0000-000000000007'
    )$test$,
    current_setting('test.asset_id')
  ),
  'custody retry is idempotent'
);

reset role;
select is((select count(*)::integer from public.asset_inspections where asset_id = current_setting('test.asset_id')::uuid), 1, 'one immutable inspection was recorded');
select is((select condition_code from public.serialized_assets where id = current_setting('test.asset_id')::uuid), 'fair', 'inspection updates the transactionally consistent condition projection');
select is((select status from public.serialized_assets where id = current_setting('test.asset_id')::uuid), 'in_custody', 'external handoff changes custody state');
select is((select current_custodian_party_id from public.serialized_assets where id = current_setting('test.asset_id')::uuid), '92000000-0000-0000-0000-000000000001'::uuid, 'current custodian projection matches accepted event');
select is((select owner_party_id from public.serialized_assets where id = current_setting('test.asset_id')::uuid), '92000000-0000-0000-0000-000000000004'::uuid, 'custody transfer does not change owner');
select ok((select next_inspection_due_at from public.serialized_assets where id = current_setting('test.asset_id')::uuid) > statement_timestamp(), 'next inspection is scheduled');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 5, 'missing', 'Operator attempts controlled loss action.',
      'f7000000-0000-0000-0000-000000000008'
    )$test$,
    current_setting('test.asset_id')
  ),
  '42501', 'staff_permission_denied',
  'routine operator cannot record controlled lifecycle actions'
);

select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 5, 'missing', 'Custodian reported asset missing.',
      'f7000000-0000-0000-0000-000000000008'
    )$test$,
    current_setting('test.asset_id')
  ),
  'controller can record a missing asset'
);
select lives_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 6, 'available', 'Asset recovered with existing custodian.',
      'f7000000-0000-0000-0000-000000000009'
    )$test$,
    current_setting('test.asset_id')
  ),
  'controller can record recovery'
);
select lives_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 7, 'seized', 'Asset held under authorized control.',
      'f7000000-0000-0000-0000-000000000010'
    )$test$,
    current_setting('test.asset_id')
  ),
  'controller can record seizure'
);
select lives_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 8, 'retired', 'Asset removed from circulation.',
      'f7000000-0000-0000-0000-000000000011'
    )$test$,
    current_setting('test.asset_id')
  ),
  'controller can retire a seized asset'
);
select throws_ok(
  format(
    $test$select * from public.staff_change_serialized_asset_status(
      %L::uuid, 9, 'available', 'Attempt terminal reactivation.',
      'f7000000-0000-0000-0000-000000000012'
    )$test$,
    current_setting('test.asset_id')
  ),
  '22023', 'asset_status_transition_invalid',
  'retired asset cannot be silently reactivated'
);

reset role;
select is((select status from public.serialized_assets where id = current_setting('test.asset_id')::uuid), 'retired', 'asset remains retired');
select is((select count(*)::integer from public.asset_events where asset_id = current_setting('test.asset_id')::uuid), 9, 'complete asset lifecycle is reconstructable from nine events');
select is((select count(*)::integer from public.outbox_events where aggregate_type = 'serialized_asset' and aggregate_id = current_setting('test.asset_id')::uuid), 7, 'material asset events emitted durable notifications');
select ok((select count(*) from public.audit_log where record_type = 'public.serialized_assets' and record_id = current_setting('test.asset_id')::uuid) >= 9, 'asset projection changes are audited');
select throws_ok(
  format($test$update public.asset_events set reason = 'rewrite' where asset_id = %L::uuid$test$, current_setting('test.asset_id')),
  '55000', 'posted_inventory_is_immutable',
  'asset events cannot be rewritten'
);
select throws_ok(
  format($test$delete from public.asset_inspections where asset_id = %L::uuid$test$, current_setting('test.asset_id')),
  '55000', 'posted_inventory_is_immutable',
  'inspection evidence cannot be deleted'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $test$select * from public.staff_register_serialized_asset(
    '70000000-0000-0000-0000-000000000004',
    'ab000000-0000-0000-0000-000000000002',
    'CHRONO-EXPIRY-001', 'good', 'Expiry test provenance.',
    'Register an allocation-expiry fixture.',
    'f7000000-0000-0000-0000-000000000013'
  )$test$,
  'operator can register a second asset for expiry handling'
);
reset role;
select set_config(
  'test.expiry_asset_id',
  (select id::text from public.serialized_assets
    where source_request_id = 'f7000000-0000-0000-0000-000000000013'),
  true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_reserve_serialized_asset(
      %L::uuid, 'e7100000-0000-0000-0000-000000000001', 1,
      'Allocate the expiry fixture.',
      'f7000000-0000-0000-0000-000000000014'
    )$test$,
    current_setting('test.expiry_asset_id')
  ),
  'operator can allocate the expiry fixture'
);
reset role;
update public.asset_reservations
set reserved_at = statement_timestamp() - interval '2 minutes',
  expires_at = statement_timestamp() - interval '1 minute'
where asset_id = current_setting('test.expiry_asset_id')::uuid and status = 'active';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(
  format(
    $test$select * from public.staff_release_asset_reservation(
      (select id from public.asset_reservations where asset_id = %L::uuid),
      1, 'Finalize the elapsed asset allocation.',
      'f7000000-0000-0000-0000-000000000015'
    )$test$,
    current_setting('test.expiry_asset_id')
  ),
  'controller can finalize an elapsed asset allocation'
);
reset role;
select is(
  (select status from public.asset_reservations
    where asset_id = current_setting('test.expiry_asset_id')::uuid),
  'expired',
  'elapsed asset allocation is preserved as expired rather than released'
);

select * from finish();
rollback;
