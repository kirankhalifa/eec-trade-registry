begin;

select plan(60);

select has_table('public', 'orders', 'orders table exists');
select has_table('public', 'order_lines', 'order lines table exists');
select has_table('public', 'order_status_events', 'order status history exists');
select has_table('public', 'order_line_events', 'order line history exists');
select has_column('public', 'audit_log', 'represented_party_id', 'audit records represented-party context');
select has_column('public', 'currencies', 'is_default', 'transaction currency is deployment configuration');
select has_column('public', 'order_lines', 'unit_price_minor_snapshot', 'line price is a nullable snapshot');
select has_column('public', 'orders', 'version', 'orders have a concurrency version');
select is((select code from public.currencies where is_default), 'SEP', 'Septims are selected through default currency data');

select has_function('public', 'get_dealer_order_reference_data', array[]::text[], 'dealer order reference RPC exists');
select has_function('public', 'get_dealer_orders', array[]::text[], 'dealer order list RPC exists');
select has_function('public', 'get_dealer_order', array['uuid'], 'dealer order detail RPC exists');
select has_function(
  'public',
  'dealer_submit_order',
  array['uuid', 'uuid', 'uuid', 'text', 'uuid[]', 'numeric[]', 'text', 'text', 'uuid'],
  'dealer submission command exists'
);
select has_function(
  'public',
  'dealer_cancel_order',
  array['uuid', 'bigint', 'text', 'uuid'],
  'dealer cancellation command exists'
);
select has_function('public', 'get_staff_order_queue', array['text'], 'staff order queue RPC exists');
select has_function('public', 'get_staff_order', array['uuid'], 'staff order detail RPC exists');
select has_function(
  'public',
  'staff_review_order_line',
  array['uuid', 'bigint', 'text', 'numeric', 'bigint', 'text', 'uuid'],
  'staff line review command exists'
);
select has_function(
  'public',
  'staff_set_order_line_price',
  array['uuid', 'bigint', 'bigint', 'text', 'uuid'],
  'staff nullable price command exists'
);
select has_function(
  'public',
  'staff_cancel_order',
  array['uuid', 'bigint', 'text', 'uuid'],
  'staff cancellation command exists'
);

select ok((select relrowsecurity from pg_class where oid = 'public.orders'::regclass), 'orders have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.order_lines'::regclass), 'order lines have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.order_status_events'::regclass), 'order status events have RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.order_line_events'::regclass), 'order line events have RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.orders', 'select'), 'authenticated callers cannot read orders directly');
select ok(not has_table_privilege('authenticated', 'public.order_lines', 'select'), 'authenticated callers cannot read order lines directly');
select ok(
  not has_function_privilege(
    'anon',
    'public.dealer_submit_order(uuid,uuid,uuid,text,uuid[],numeric[],text,text,uuid)',
    'execute'
  ),
  'anonymous callers cannot submit dealer orders'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.dealer_submit_order(uuid,uuid,uuid,text,uuid[],numeric[],text,text,uuid)',
    'execute'
  ),
  'authenticated callers may reach the secured order boundary'
);
select ok(
  (select default_scope ?& array['order.read', 'order.create', 'order.cancel'] from public.representative_role_definitions where code = 'portal-representative'),
  'the configurable dealer role advertises all initial order scopes'
);
select ok(
  (select count(*) = 3 from public.permission_scopes where code in ('order.approve.ordinary', 'order.approve.restricted', 'order.approve.unique')),
  'control-specific approval permissions are distinct'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b3000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'dealer.orders@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b3000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'other.dealer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b3000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'order.officer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b3000000-0000-0000-0000-000000000004',
    'authenticated', 'authenticated', 'limited.order.officer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b3000000-0000-0000-0000-000000000005',
    'authenticated', 'authenticated', 'licensing.only@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c3000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000001', 'Ordering Representative', 'dealer'),
  ('c3000000-0000-0000-0000-000000000002', 'b3000000-0000-0000-0000-000000000002', 'Other Representative', 'dealer'),
  ('c3000000-0000-0000-0000-000000000003', 'b3000000-0000-0000-0000-000000000003', 'Order Officer', 'staff'),
  ('c3000000-0000-0000-0000-000000000004', 'b3000000-0000-0000-0000-000000000004', 'Limited Order Officer', 'staff'),
  ('c3000000-0000-0000-0000-000000000005', 'b3000000-0000-0000-0000-000000000005', 'Licensing Only', 'staff');

update public.dealer_authorizations
set status_definition_id = '94000000-0000-0000-0000-000000000001'
where id = '95000000-0000-0000-0000-000000000002';

insert into public.party_representatives (
  id, principal_party_id, actor_id, role_definition_id, authority_scope, verified_at
)
values
  (
    'd3000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000001',
    'c3000000-0000-0000-0000-000000000001',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read":true,"order.read":true,"order.create":true,"order.cancel":true}'::jsonb,
    now()
  ),
  (
    'd3000000-0000-0000-0000-000000000002',
    '92000000-0000-0000-0000-000000000003',
    'c3000000-0000-0000-0000-000000000002',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read":true,"order.read":true,"order.create":true,"order.cancel":true}'::jsonb,
    now()
  );

insert into public.staff_roles (id, code, display_name, description)
values (
  'a3000000-0000-0000-0000-000000000001',
  'limited_order_officer',
  'Limited order officer',
  'Test role without unique-order approval.'
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select 'a3000000-0000-0000-0000-000000000001', permission.id
from public.permission_scopes as permission
where permission.code in (
  'order.private.read', 'order.review',
  'order.approve.ordinary', 'order.approve.restricted'
);

insert into public.staff_assignments (id, actor_id, staff_role_id, effective_from)
values
  (
    'd3000000-0000-0000-0000-000000000010',
    'c3000000-0000-0000-0000-000000000003',
    (select id from public.staff_roles where code = 'order_officer'),
    '2026-01-01T00:00:00Z'
  ),
  (
    'd3000000-0000-0000-0000-000000000011',
    'c3000000-0000-0000-0000-000000000004',
    'a3000000-0000-0000-0000-000000000001',
    '2026-01-01T00:00:00Z'
  ),
  (
    'd3000000-0000-0000-0000-000000000012',
    'c3000000-0000-0000-0000-000000000005',
    (select id from public.staff_roles where code = 'licensing_officer'),
    '2026-01-01T00:00:00Z'
  );

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

select is(
  (select jsonb_array_length(get_dealer_order_reference_data() -> 'items')),
  10,
  'dealer order catalogue exposes all ten currently published active items'
);
select ok(
  not (get_dealer_order_reference_data() -> 'items')::text like '%Unpublished Prototype%',
  'dealer order reference data does not leak unpublished catalogue records'
);
select is((select count(*)::integer from public.get_dealer_orders()), 0, 'dealer begins with no orders');

select lives_ok(
  $test$
    select * from public.dealer_submit_order(
      '92000000-0000-0000-0000-000000000001',
      '95000000-0000-0000-0000-000000000001',
      null,
      'collection',
      array[
        '70000000-0000-0000-0000-000000000001'::uuid,
        '70000000-0000-0000-0000-000000000004'::uuid
      ],
      array[2::numeric, 1::numeric],
      'No current stock is required to submit this request.',
      'Submit a mixed-control requisition for review.',
      'e3000000-0000-0000-0000-000000000001'
    )
  $test$,
  'dealer can submit a multi-line order without a license, price, or stock record'
);

select is(
  (select public_reference from public.get_dealer_orders()),
  'EEC-ORD-1001',
  'order reference is allocated from configurable sequence state'
);
select is(
  (select status || ':' || version::text from public.get_dealer_orders()),
  'submitted:1',
  'new order enters submitted state at version one'
);
select ok(
  (
    select bool_and(
      (
        line ->> 'pricing_status' = 'configured'
        and line -> 'unit_price_minor' <> 'null'::jsonb
        and (line ->> 'unit_price_minor')::bigint >= 0
      ) or (
        line ->> 'pricing_status' = 'pending'
        and line -> 'unit_price_minor' = 'null'::jsonb
      )
    )
    from public.get_dealer_orders(), lateral jsonb_array_elements(lines) as line
  ),
  'submitted lines configure available prices and preserve unavailable prices as null pending values'
);
select ok(
  (
    select bool_and(line ->> 'status' = 'review_required')
    from public.get_dealer_orders(), lateral jsonb_array_elements(lines) as line
  ),
  'every submitted line enters authoritative review without auto-approval'
);
select ok(
  (
    select exists (
      select 1
      from jsonb_array_elements(lines) as line
      where line ->> 'control_profile_code' = 'unique'
        and line ->> 'status' = 'review_required'
    )
    from public.get_dealer_orders()
  ),
  'unique goods cannot follow an ordinary auto-approval path'
);

select lives_ok(
  $test$
    select * from public.dealer_submit_order(
      '92000000-0000-0000-0000-000000000001',
      '95000000-0000-0000-0000-000000000001',
      null,
      'collection',
      array[
        '70000000-0000-0000-0000-000000000001'::uuid,
        '70000000-0000-0000-0000-000000000004'::uuid
      ],
      array[2::numeric, 1::numeric],
      'No current stock is required to submit this request.',
      'Submit a mixed-control requisition for review.',
      'e3000000-0000-0000-0000-000000000001'
    )
  $test$,
  'retrying dealer submission with the same request id is safe'
);

reset role;
select is((select count(*)::integer from public.orders where source_request_id = 'e3000000-0000-0000-0000-000000000001'), 1, 'submission retry does not duplicate the order');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'order.submitted:e3000000-0000-0000-0000-000000000001'), 1, 'submission retry does not duplicate outbox work');
select set_config(
  'test.submitted_order_id',
  (select id::text from public.orders where public_reference = 'EEC-ORD-1001'),
  true
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::integer from public.get_dealer_orders()), 0, 'another dealer cannot see the submitted order');
select throws_ok(
  $test$
    select * from public.dealer_cancel_order(
      current_setting('test.submitted_order_id')::uuid,
      1,
      'Attempt cross-dealer cancellation.',
      'e3000000-0000-0000-0000-000000000002'
    )
  $test$,
  'P0002',
  'order_not_found',
  'another dealer cannot cancel the order'
);

select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000005","role":"authenticated"}', true);
select throws_ok(
  $test$select * from public.get_staff_order_queue(null)$test$,
  '42501',
  'staff_permission_denied',
  'staff with only licensing authority cannot read orders'
);

select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.get_staff_order_queue(null)), 1, 'limited order officer can read the order queue');
select lives_ok(
  $test$
    select * from public.staff_review_order_line(
      (
        select (line ->> 'id')::uuid
        from public.get_staff_order_queue(null), lateral jsonb_array_elements(lines) as line
        where line ->> 'control_profile_code' = 'ordinary'
      ),
      1,
      'approve',
      1,
      null,
      'Partially approve the ordinary line with pricing pending.',
      'e3000000-0000-0000-0000-000000000003'
    )
  $test$,
  'ordinary line may be partially approved by the ordinary approval permission'
);
select throws_ok(
  $test$
    select * from public.staff_review_order_line(
      (
        select (line ->> 'id')::uuid
        from public.get_staff_order_queue(null), lateral jsonb_array_elements(lines) as line
        where line ->> 'control_profile_code' = 'unique'
      ),
      2,
      'awaiting_stock',
      1,
      null,
      'Attempt unique approval without its exact permission.',
      'e3000000-0000-0000-0000-000000000004'
    )
  $test$,
  '42501',
  'staff_permission_denied',
  'ordinary or restricted authority cannot approve a unique line'
);

select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select lives_ok(
  $test$
    select * from public.staff_set_order_line_price(
      (
        select (line ->> 'id')::uuid
        from public.get_staff_order_queue(null), lateral jsonb_array_elements(lines) as line
        where line ->> 'control_profile_code' = 'ordinary'
      ),
      2,
      250,
      'Record the reviewed Septim unit price.',
      'e3000000-0000-0000-0000-000000000005'
    )
  $test$,
  'authorized staff can configure a previously blank line price'
);
select lives_ok(
  $test$
    select * from public.staff_review_order_line(
      (
        select (line ->> 'id')::uuid
        from public.get_staff_order_queue(null), lateral jsonb_array_elements(lines) as line
        where line ->> 'control_profile_code' = 'unique'
      ),
      3,
      'awaiting_stock',
      1,
      null,
      'Approve the unique request while waiting for an allocatable asset.',
      'e3000000-0000-0000-0000-000000000006'
    )
  $test$,
  'staff with unique approval permission can record approved demand awaiting stock'
);
select is(
  (select status || ':' || version::text from public.get_staff_order_queue(null)),
  'awaiting_stock:4',
  'mixed partial approval and unavailable unique stock produce awaiting-stock header state'
);
select ok(
  (
    select
      count(*) filter (where line ->> 'pricing_status' = 'configured' and line ->> 'unit_price_minor' = '250') = 1
      and count(*) filter (where line ->> 'pricing_status' = 'pending' and line -> 'unit_price_minor' = 'null'::jsonb) = 1
    from public.get_staff_order_queue(null), lateral jsonb_array_elements(lines) as line
  ),
  'configured and pending prices remain distinct in one order'
);

reset role;
select ok(
  (
    select audit.permission_code = 'order.approve.ordinary'
      and audit.represented_party_id is null
    from public.audit_log as audit
    where audit.record_type = 'public.order_lines'
      and audit.request_id = 'e3000000-0000-0000-0000-000000000003'
    order by audit.id desc limit 1
  ),
  'ordinary line approval records its exact staff permission and no represented party'
);
select ok(
  (
    select audit.actor_id = 'c3000000-0000-0000-0000-000000000001'::uuid
      and audit.represented_party_id = '92000000-0000-0000-0000-000000000001'::uuid
      and audit.permission_code = 'dealer.order.create'
    from public.audit_log as audit
    where audit.record_type = 'public.orders'
      and audit.request_id = 'e3000000-0000-0000-0000-000000000001'
    order by audit.id desc limit 1
  ),
  'dealer submission records actor, represented organization, and grant scope'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b3000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select status from public.get_dealer_orders()), 'awaiting_stock', 'dealer sees the committed awaiting-stock outcome');
select lives_ok(
  $test$
    select * from public.dealer_cancel_order(
      (select id from public.get_dealer_orders()),
      4,
      'Cancel before any fulfillment or inventory movement.',
      'e3000000-0000-0000-0000-000000000007'
    )
  $test$,
  'dealer can cancel the unfulfilled order'
);
select lives_ok(
  $test$
    select * from public.dealer_cancel_order(
      (select id from public.get_dealer_orders()),
      4,
      'Cancel before any fulfillment or inventory movement.',
      'e3000000-0000-0000-0000-000000000007'
    )
  $test$,
  'dealer cancellation retry is idempotent despite the stale original version'
);
select ok(
  (
    select status = 'cancelled'
      and (
        select bool_and(line ->> 'status' = 'cancelled')
        from jsonb_array_elements(lines) as line
      )
    from public.get_dealer_orders()
  ),
  'cancellation closes every unfulfilled line without deleting the order'
);

reset role;
select is((select count(*)::integer from public.order_status_events where order_id = (select id from public.orders where public_reference = 'EEC-ORD-1001')), 4, 'header submission, review changes, and cancellation are append-only');
select is((select count(*)::integer from public.order_line_events where order_id = (select id from public.orders where public_reference = 'EEC-ORD-1001')), 7, 'line submissions, decisions, price edit, and cancellations are append-only');
select is((select count(*)::integer from public.outbox_events where aggregate_type = 'order' and aggregate_id = (select id from public.orders where public_reference = 'EEC-ORD-1001')), 5, 'each accepted order command creates one durable outbox event');

select * from finish();
rollback;
