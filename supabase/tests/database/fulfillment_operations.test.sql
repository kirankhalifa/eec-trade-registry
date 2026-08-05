begin;

select plan(50);

select has_table('public', 'order_fulfillments', 'order fulfillment evidence exists');
select has_column('public', 'reservations', 'consumed_at', 'reservations record consumption time');
select has_column(
  'public',
  'reservations',
  'consumption_transaction_id',
  'reservations link to their immutable stock issue'
);
select has_function(
  'public',
  'get_staff_fulfillment_workspace',
  array[]::text[],
  'staff fulfillment workspace exists'
);
select has_function(
  'public',
  'staff_fulfill_reservation',
  array['uuid', 'bigint', 'text', 'uuid'],
  'reservation fulfillment command exists'
);
select has_function(
  'public',
  'staff_reverse_fulfillment',
  array['uuid', 'bigint', 'text', 'uuid'],
  'fulfillment reversal command exists'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.order_fulfillments'::regclass),
  'fulfillments have RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.order_fulfillments', 'select'),
  'authenticated users cannot read fulfillment rows directly'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.staff_fulfill_reservation(uuid,bigint,text,uuid)',
    'execute'
  ),
  'anonymous callers cannot fulfill reservations'
);
select is(
  (select count(*)::integer from public.permission_scopes where code like 'inventory.fulfillment.%'),
  3,
  'fulfillment permissions remain independently assignable'
);
select ok(
  exists (
    select 1
    from public.staff_roles as role
    join public.staff_role_permissions as role_permission
      on role_permission.staff_role_id = role.id
    join public.permission_scopes as permission
      on permission.id = role_permission.permission_scope_id
    where role.code = 'warehouse_operator'
      and permission.code = 'inventory.fulfillment.post'
  ),
  'warehouse operators can complete fulfillment'
);
select ok(
  not exists (
    select 1
    from public.staff_roles as role
    join public.staff_role_permissions as role_permission
      on role_permission.staff_role_id = role.id
    join public.permission_scopes as permission
      on permission.id = role_permission.permission_scope_id
    where role.code = 'warehouse_operator'
      and permission.code = 'inventory.fulfillment.reverse'
  ),
  'warehouse operators cannot reverse fulfillment'
);
select ok(
  exists (
    select 1
    from public.staff_roles as role
    join public.staff_role_permissions as role_permission
      on role_permission.staff_role_id = role.id
    join public.permission_scopes as permission
      on permission.id = role_permission.permission_scope_id
    where role.code = 'inventory_controller'
      and permission.code = 'inventory.fulfillment.reverse'
  ),
  'inventory controllers can reverse fulfillment'
);
select is(
  (
    select count(*)::integer
    from public.notification_templates
    where event_type = 'fulfillment.completed'
  ),
  1,
  'fulfillment completion has one versioned staff alert template'
);
select is(
  (
    select count(*)::integer
    from public.integration_event_routes
    where event_type = 'fulfillment.completed'
  ),
  1,
  'fulfillment alert routing is preconfigured behind the inactive destination'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b6000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'fulfillment.operator@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b6000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'fulfillment.controller@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b6000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'fulfillment.denied@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b6000000-0000-0000-0000-000000000004',
    'authenticated', 'authenticated', 'fulfillment.dealer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  (
    'c6000000-0000-0000-0000-000000000001',
    'b6000000-0000-0000-0000-000000000001',
    'Fulfillment Operator',
    'staff'
  ),
  (
    'c6000000-0000-0000-0000-000000000002',
    'b6000000-0000-0000-0000-000000000002',
    'Fulfillment Controller',
    'staff'
  ),
  (
    'c6000000-0000-0000-0000-000000000003',
    'b6000000-0000-0000-0000-000000000003',
    'Fulfillment Denied',
    'staff'
  ),
  (
    'c6000000-0000-0000-0000-000000000004',
    'b6000000-0000-0000-0000-000000000004',
    'Fulfillment Dealer',
    'dealer'
  );

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope
)
values
  (
    'd6000000-0000-0000-0000-000000000001',
    'c6000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'warehouse_operator'),
    '2026-01-01T00:00:00Z',
    '{}'::jsonb
  ),
  (
    'd6000000-0000-0000-0000-000000000002',
    'c6000000-0000-0000-0000-000000000002',
    (select id from public.staff_roles where code = 'inventory_controller'),
    '2026-01-01T00:00:00Z',
    '{}'::jsonb
  ),
  (
    'd6000000-0000-0000-0000-000000000003',
    'c6000000-0000-0000-0000-000000000003',
    (select id from public.staff_roles where code = 'catalogue_manager'),
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
values (
  'e6000000-0000-0000-0000-000000000001',
  'EEC-ORD-FULFILL-1',
  '92000000-0000-0000-0000-000000000001',
  '95000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001',
  'collection',
  'approved',
  'SEP',
  'c6000000-0000-0000-0000-000000000004',
  'e6000000-0000-0000-0000-000000000011'
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
values (
  'e6100000-0000-0000-0000-000000000001',
  'e6000000-0000-0000-0000-000000000001',
  1,
  '70000000-0000-0000-0000-000000000001',
  'EQ-LANTERN-001',
  'Harbor Lantern',
  'EA',
  10,
  10,
  'approved',
  'SEP',
  'standard-trade',
  false,
  false,
  false
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_staff_fulfillment_workspace()$test$,
  '42501',
  'staff_warehouse_permission_denied',
  'unassigned staff cannot read the fulfillment workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select lives_ok(
  $test$
    select * from public.staff_post_inventory_receipt(
      'ab000000-0000-0000-0000-000000000002',
      '70000000-0000-0000-0000-000000000001',
      10,
      'FULFILLMENT-STOCK-001',
      'Receive ten units for fulfillment testing.',
      'e6200000-0000-0000-0000-000000000001'
    )
  $test$,
  'warehouse operator can post source stock'
);

reset role;
select set_config(
  'test.fulfillment_account_id',
  (
    select account.id::text
    from public.inventory_accounts as account
    where account.account_kind = 'physical'
      and account.item_id = '70000000-0000-0000-0000-000000000001'
      and account.warehouse_id = 'aa000000-0000-0000-0000-000000000001'
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select lives_ok(
  format(
    $test$
      select * from public.staff_create_reservation(
        'e6100000-0000-0000-0000-000000000001',
        %L::uuid,
        10,
        'Reserve the approved quantity for collection.',
        'e6200000-0000-0000-0000-000000000002'
      )
    $test$,
    current_setting('test.fulfillment_account_id')
  ),
  'approved stock can be reserved before fulfillment'
);
select is(
  jsonb_array_length(
    public.get_staff_fulfillment_workspace() -> 'ready_reservations'
  ),
  1,
  'operator workspace exposes the one consumable reservation'
);
select set_config(
  'test.fulfillment_reservation_id',
  public.get_staff_fulfillment_workspace()
    -> 'ready_reservations' -> 0 ->> 'id',
  true
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
select throws_ok(
  format(
    $test$
      select * from public.staff_fulfill_reservation(
        %L::uuid,
        1,
        'Attempt fulfillment without warehouse authority.',
        'e6200000-0000-0000-0000-000000000003'
      )
    $test$,
    current_setting('test.fulfillment_reservation_id')
  ),
  '42501',
  'staff_warehouse_permission_denied',
  'staff without fulfillment authority cannot consume a reservation'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select lives_ok(
  format(
    $test$
      select * from public.staff_fulfill_reservation(
        %L::uuid,
        1,
        'Release the reserved goods to the authorized dealer.',
        'e6200000-0000-0000-0000-000000000004'
      )
    $test$,
    current_setting('test.fulfillment_reservation_id')
  ),
  'authorized operator can atomically fulfill a reservation'
);
select lives_ok(
  format(
    $test$
      select * from public.staff_fulfill_reservation(
        %L::uuid,
        1,
        'Release the reserved goods to the authorized dealer.',
        'e6200000-0000-0000-0000-000000000004'
      )
    $test$,
    current_setting('test.fulfillment_reservation_id')
  ),
  'fulfillment retry is idempotent despite the stale reservation version'
);
select is(
  (
    select public_reference
    from public.staff_fulfill_reservation(
      current_setting('test.fulfillment_reservation_id')::uuid,
      1,
      'Release the reserved goods to the authorized dealer.',
      'e6200000-0000-0000-0000-000000000004'
    )
  ),
  'EEC-FUL-1001',
  'fulfillment retry returns the same configurable reference'
);

reset role;
select set_config(
  'test.fulfillment_id',
  (
    select fulfillment.id::text
    from public.order_fulfillments as fulfillment
    where fulfillment.source_request_id
      = 'e6200000-0000-0000-0000-000000000004'
  ),
  true
);
select set_config(
  'test.fulfillment_issue_id',
  (
    select fulfillment.inventory_transaction_id::text
    from public.order_fulfillments as fulfillment
    where fulfillment.source_request_id
      = 'e6200000-0000-0000-0000-000000000004'
  ),
  true
);
select is(
  (select count(*)::integer from public.order_fulfillments),
  1,
  'idempotent fulfillment creates one evidence record'
);
select ok(
  (
    select fulfillment.status = 'completed'
      and fulfillment.version = 1
      and fulfillment.quantity = 10
    from public.order_fulfillments as fulfillment
    where fulfillment.id = current_setting('test.fulfillment_id')::uuid
  ),
  'completed fulfillment preserves its quantity and optimistic version'
);
select ok(
  (
    select reservation.status = 'consumed'
      and reservation.version = 2
      and reservation.consumed_at is not null
      and reservation.consumed_by_actor_id
        = 'c6000000-0000-0000-0000-000000000001'::uuid
      and reservation.consumption_transaction_id
        = current_setting('test.fulfillment_issue_id')::uuid
    from public.reservations as reservation
    where reservation.id = current_setting('test.fulfillment_reservation_id')::uuid
  ),
  'reservation consumption links the actor and stock issue'
);
select is(
  (
    select count(*)::integer
    from public.reservation_events as event
    where event.reservation_id
      = current_setting('test.fulfillment_reservation_id')::uuid
      and event.event_type = 'consumed'
  ),
  1,
  'reservation consumption is append-only history'
);
select is(
  (
    select line.quantity_fulfilled::text || ':' || line.status
    from public.order_lines as line
    where line.id = 'e6100000-0000-0000-0000-000000000001'
  ),
  '10.000:fulfilled',
  'fulfillment advances the line quantity and terminal status'
);
select is(
  (
    select order_record.status
    from public.orders as order_record
    where order_record.id = 'e6000000-0000-0000-0000-000000000001'
  ),
  'fulfilled',
  'fully completed demand advances the order'
);
select is(
  (
    select coalesce(sum(entry.quantity_delta), 0)
    from public.inventory_ledger_entries as entry
    where entry.inventory_account_id
      = current_setting('test.fulfillment_account_id')::uuid
  ),
  0::numeric,
  'stock issue reduces the physical position to zero'
);
select is(
  (
    select sum(entry.quantity_delta)
    from public.inventory_ledger_entries as entry
    where entry.inventory_transaction_id
      = current_setting('test.fulfillment_issue_id')::uuid
  ),
  0::numeric,
  'fulfillment issue remains balanced'
);
select is(
  (
    select entry.quantity_delta
    from public.inventory_ledger_entries as entry
    join public.inventory_accounts as account
      on account.id = entry.inventory_account_id
    where entry.inventory_transaction_id
      = current_setting('test.fulfillment_issue_id')::uuid
      and account.account_kind = 'physical'
  ),
  (-10)::numeric,
  'fulfillment posts a negative physical ledger entry'
);
select is(
  (
    select count(*)::integer
    from public.outbox_events
    where event_type = 'fulfillment.completed'
  ),
  1,
  'fulfillment writes one durable completion event'
);
select ok(
  (
    select audit.permission_code = 'inventory.fulfillment.post'
      and audit.actor_id = 'c6000000-0000-0000-0000-000000000001'::uuid
      and audit.staff_assignment_id
        = 'd6000000-0000-0000-0000-000000000001'::uuid
    from public.audit_log as audit
    where audit.record_type = 'public.order_fulfillments'
      and audit.request_id = 'e6200000-0000-0000-0000-000000000004'
  ),
  'fulfillment audit records exact actor, assignment, and permission'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select is(
  jsonb_array_length(public.get_staff_fulfillment_workspace() -> 'fulfillments'),
  1,
  'operator workspace exposes the completed fulfillment'
);
select throws_ok(
  format(
    $test$
      select * from public.staff_reverse_fulfillment(
        %L::uuid,
        1,
        'Attempt reversal without controller authority.',
        'e6200000-0000-0000-0000-000000000005'
      )
    $test$,
    current_setting('test.fulfillment_id')
  ),
  '42501',
  'staff_warehouse_permission_denied',
  'warehouse operator cannot reverse completed fulfillment'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
select lives_ok(
  format(
    $test$
      select * from public.staff_reverse_fulfillment(
        %L::uuid,
        1,
        'Correct the documented release and restore warehouse stock.',
        'e6200000-0000-0000-0000-000000000006'
      )
    $test$,
    current_setting('test.fulfillment_id')
  ),
  'inventory controller can reverse completed fulfillment'
);
select lives_ok(
  format(
    $test$
      select * from public.staff_reverse_fulfillment(
        %L::uuid,
        1,
        'Correct the documented release and restore warehouse stock.',
        'e6200000-0000-0000-0000-000000000006'
      )
    $test$,
    current_setting('test.fulfillment_id')
  ),
  'fulfillment reversal retry is idempotent despite stale version'
);

reset role;
select ok(
  (
    select fulfillment.status = 'reversed'
      and fulfillment.version = 2
      and fulfillment.reversed_at is not null
      and fulfillment.reversal_transaction_id is not null
    from public.order_fulfillments as fulfillment
    where fulfillment.id = current_setting('test.fulfillment_id')::uuid
  ),
  'reversal updates only the fulfillment control record with linked evidence'
);
select is(
  (
    select reservation.status
    from public.reservations as reservation
    where reservation.id = current_setting('test.fulfillment_reservation_id')::uuid
  ),
  'consumed',
  'reversal never reactivates the consumed reservation'
);
select is(
  (
    select line.quantity_fulfilled::text || ':' || line.status
    from public.order_lines as line
    where line.id = 'e6100000-0000-0000-0000-000000000001'
  ),
  '0.000:awaiting_stock',
  'reversal reopens demand without fabricating a new claim'
);
select is(
  (
    select order_record.status
    from public.orders as order_record
    where order_record.id = 'e6000000-0000-0000-0000-000000000001'
  ),
  'awaiting_stock',
  'reversal reopens the order'
);
select is(
  (
    select coalesce(sum(entry.quantity_delta), 0)
    from public.inventory_ledger_entries as entry
    where entry.inventory_account_id
      = current_setting('test.fulfillment_account_id')::uuid
  ),
  10::numeric,
  'linked reversal restores the physical stock position'
);
select ok(
  exists (
    select 1
    from public.inventory_transactions as reversal
    where reversal.reversal_of_id
      = current_setting('test.fulfillment_issue_id')::uuid
      and reversal.permission_code = 'inventory.fulfillment.reverse'
  ),
  'reversal transaction links to the immutable issue'
);
select is(
  (select count(*)::integer from public.inventory_transactions),
  3,
  'receipt, issue, and reversal transaction headers are preserved'
);
select is(
  (select count(*)::integer from public.inventory_ledger_entries),
  6,
  'each accepted inventory transaction remains balanced with two entries'
);
select is(
  (
    select count(*)::integer
    from public.outbox_events
    where event_type = 'fulfillment.reversed'
  ),
  1,
  'reversal writes one durable event'
);
select is(
  (
    select count(*)::integer
    from public.order_line_events as event
    where event.order_line_id = 'e6100000-0000-0000-0000-000000000001'
      and event.event_type = 'fulfillment_changed'
  ),
  2,
  'completion and reversal retain two line history records'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select throws_ok(
  format(
    $test$
      select * from public.staff_fulfill_reservation(
        %L::uuid,
        2,
        'Attempt to reuse a consumed claim.',
        'e6200000-0000-0000-0000-000000000007'
      )
    $test$,
    current_setting('test.fulfillment_reservation_id')
  ),
  '22023',
  'reservation_not_fulfillable',
  'consumed reservations cannot be fulfilled again after reversal'
);

reset role;
select throws_ok(
  format(
    $test$
      update public.inventory_transactions
      set reason = 'Rewrite forbidden'
      where id = %L::uuid
    $test$,
    current_setting('test.fulfillment_issue_id')
  ),
  '55000',
  'posted_inventory_is_immutable',
  'the original fulfillment issue cannot be rewritten'
);

select * from finish();
rollback;
