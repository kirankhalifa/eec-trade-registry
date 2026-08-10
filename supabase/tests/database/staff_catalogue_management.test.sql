begin;

select plan(35);

select has_table('public', 'actor_profiles', 'actor profiles table exists');
select has_table('public', 'permission_scopes', 'permission scopes table exists');
select has_table('public', 'staff_roles', 'staff roles table exists');
select has_table('public', 'staff_assignments', 'staff assignments table exists');
select has_column('public', 'items', 'version', 'catalogue items have a concurrency version');

select has_function(
  'public',
  'get_staff_catalogue_items',
  array['text'],
  'staff catalogue work queue RPC exists'
);
select has_function(
  'public',
  'get_staff_catalogue_item',
  array['uuid'],
  'staff catalogue detail RPC exists'
);
select has_function(
  'public',
  'get_staff_catalogue_reference_data',
  array[]::text[],
  'staff catalogue reference RPC exists'
);
select has_function(
  'public',
  'staff_create_catalogue_item',
  array['text', 'text', 'text', 'text', 'text', 'text', 'text', 'text', 'text', 'uuid'],
  'secure create command exists'
);
select has_function(
  'public',
  'staff_update_catalogue_item',
  array['uuid', 'bigint', 'text', 'text', 'text', 'text', 'text', 'text', 'text', 'uuid'],
  'secure update command exists'
);
select has_function(
  'public',
  'staff_set_catalogue_item_status',
  array['uuid', 'bigint', 'text', 'text', 'uuid'],
  'secure archive and restore command exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.actor_profiles'::regclass),
  'actor profiles have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.permission_scopes'::regclass),
  'permission scopes have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.staff_roles'::regclass),
  'staff roles have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.staff_assignments'::regclass),
  'staff assignments have row-level security enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.items', 'select'),
  'authenticated users cannot query catalogue tables directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.actor_profiles', 'select'),
  'authenticated users cannot query actor profiles directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_log', 'select'),
  'authenticated users cannot query audit evidence directly'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.staff_create_catalogue_item(text,text,text,text,text,text,text,text,text,uuid)',
    'execute'
  ),
  'anonymous callers cannot execute staff catalogue commands'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.staff_create_catalogue_item(text,text,text,text,text,text,text,text,text,uuid)',
    'execute'
  ),
  'authenticated callers may reach the secure command boundary'
);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
values
  (
    'b0000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'catalogue.manager@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'no.assignment@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'expired.assignment@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name)
values
  (
    'c0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    'Catalogue Manager'
  ),
  (
    'c0000000-0000-0000-0000-000000000002',
    'b0000000-0000-0000-0000-000000000002',
    'Unassigned Staff'
  ),
  (
    'c0000000-0000-0000-0000-000000000003',
    'b0000000-0000-0000-0000-000000000003',
    'Expired Staff'
  );

insert into public.staff_assignments (
  id,
  actor_id,
  staff_role_id,
  effective_from,
  effective_until
)
values
  (
    'd0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'catalogue_manager'),
    '2026-01-01T00:00:00Z',
    null
  ),
  (
    'd0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000003',
    (select id from public.staff_roles where code = 'catalogue_manager'),
    '2025-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b0000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select throws_ok(
  $test$select * from public.get_staff_catalogue_items(null)$test$,
  '42501',
  'staff_permission_denied',
  'an authenticated user without an assignment is denied'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b0000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);

select throws_ok(
  $test$select * from public.get_staff_catalogue_items(null)$test$,
  '42501',
  'staff_permission_denied',
  'an expired staff assignment is denied'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*)::integer from public.get_staff_catalogue_items(null)),
  11,
  'an active catalogue manager sees the internal work queue'
);

select lives_ok(
  $test$
    select * from public.staff_create_catalogue_item(
      'STAFF-TEST-1',
      'staff-test-item',
      'Staff test item',
      'An unpublished item created through the secure staff command.',
      'equipment',
      'each',
      'fungible',
      'Internal staff-only test note.',
      'Create a catalogue draft for permission testing.',
      'e0000000-0000-0000-0000-000000000001'
    )
  $test$,
  'an authorized catalogue manager can create a canonical item'
);

select is(
  (
    select count(*)::integer
    from public.get_staff_catalogue_items('STAFF-TEST-1')
    where item_code = 'STAFF-TEST-1'
      and version = 1
      and publication_status is null
  ),
  1,
  'a newly created item is internal and unpublished'
);

reset role;

select ok(
  (
    select
      audit.actor_id = 'c0000000-0000-0000-0000-000000000001'::uuid
      and audit.auth_user_id = 'b0000000-0000-0000-0000-000000000001'::uuid
      and audit.permission_code = 'catalogue.manage'
      and audit.staff_assignment_id = 'd0000000-0000-0000-0000-000000000001'::uuid
      and audit.reason = 'Create a catalogue draft for permission testing.'
      and audit.request_id = 'e0000000-0000-0000-0000-000000000001'::uuid
      and audit.previous_state is null
      and audit.new_state ->> 'item_code' = 'STAFF-TEST-1'
    from public.audit_log as audit
    where audit.record_type = 'public.items'
      and audit.new_state ->> 'item_code' = 'STAFF-TEST-1'
    order by audit.occurred_at desc, audit.id desc
    limit 1
  ),
  'the create command records complete actor, permission, reason, and request context'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select lives_ok(
  $test$
    select * from public.staff_update_catalogue_item(
      (
        select id
        from public.get_staff_catalogue_items('STAFF-TEST-1')
        where item_code = 'STAFF-TEST-1'
      ),
      1,
      'Updated staff test item',
      'Updated through the secure staff command.',
      'equipment',
      'each',
      'fungible',
      'Updated internal note.',
      'Correct the catalogue draft description.',
      'e0000000-0000-0000-0000-000000000002'
    )
  $test$,
  'an authorized catalogue manager can update mutable fields'
);

select is(
  (
    select display_name || ':' || version::text
    from public.get_staff_catalogue_items('STAFF-TEST-1')
    where item_code = 'STAFF-TEST-1'
  ),
  'Updated staff test item:2',
  'an update changes the record and advances its concurrency version'
);

select throws_ok(
  $test$
    select * from public.staff_update_catalogue_item(
      (
        select id
        from public.get_staff_catalogue_items('STAFF-TEST-1')
        where item_code = 'STAFF-TEST-1'
      ),
      1,
      'Stale update',
      'This update must fail.',
      'equipment',
      'each',
      'fungible',
      '',
      'Attempt a stale update.',
      'e0000000-0000-0000-0000-000000000003'
    )
  $test$,
  '40001',
  'catalogue_version_conflict',
  'a stale update is rejected instead of overwriting newer work'
);

select throws_ok(
  $test$
    select * from public.staff_set_catalogue_item_status(
      '70000000-0000-0000-0000-000000000001',
      1,
      'archived',
      '',
      'e0000000-0000-0000-0000-000000000004'
    )
  $test$,
  '22023',
  'reason_required',
  'a status change requires an audit reason'
);

select lives_ok(
  $test$
    select * from public.staff_set_catalogue_item_status(
      '70000000-0000-0000-0000-000000000001',
      1,
      'archived',
      'Policy-neutral archive test.',
      'e0000000-0000-0000-0000-000000000005'
    )
  $test$,
  'an authorized catalogue manager can archive an item'
);

select is(
  (
    select count(*)::integer
    from public.get_public_catalogue_item('harbor-lantern')
  ),
  0,
  'archiving the canonical item removes it from the public projection'
);

select lives_ok(
  $test$
    select * from public.staff_set_catalogue_item_status(
      '70000000-0000-0000-0000-000000000001',
      2,
      'active',
      'Restore after policy-neutral archive test.',
      'e0000000-0000-0000-0000-000000000006'
    )
  $test$,
  'an authorized catalogue manager can restore an archived item'
);

select is(
  (
    select count(*)::integer
    from public.get_public_catalogue_item('harbor-lantern')
  ),
  1,
  'restoring the canonical item returns its effective publication'
);

reset role;

select ok(
  (
    select
      audit.previous_state ->> 'status' = 'active'
      and audit.new_state ->> 'status' = 'archived'
      and audit.reason = 'Policy-neutral archive test.'
      and audit.request_id = 'e0000000-0000-0000-0000-000000000005'::uuid
    from public.audit_log as audit
    where audit.record_type = 'public.items'
      and audit.record_id = '70000000-0000-0000-0000-000000000001'::uuid
      and audit.reason = 'Policy-neutral archive test.'
    order by audit.occurred_at desc, audit.id desc
    limit 1
  ),
  'an archive records its exact previous and new state'
);

select * from finish();
rollback;
