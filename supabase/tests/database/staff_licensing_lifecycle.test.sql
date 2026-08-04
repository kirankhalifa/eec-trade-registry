begin;

select plan(47);

select has_table('public', 'reference_sequences', 'reference sequence table exists');
select has_table('public', 'license_status_events', 'license status history table exists');
select has_table('public', 'license_endorsement_events', 'endorsement history table exists');
select has_table('public', 'outbox_events', 'durable outbox table exists');
select has_column('public', 'licenses', 'source_request_id', 'license issuance has an idempotency key');
select has_column('public', 'license_endorsements', 'version', 'endorsement records have a concurrency version');

select has_function(
  'public',
  'get_staff_license_queue',
  array['text'],
  'staff licensing queue RPC exists'
);
select has_function(
  'public',
  'get_staff_license',
  array['uuid'],
  'staff license detail RPC exists'
);
select has_function(
  'public',
  'get_staff_licensing_reference_data',
  array[]::text[],
  'staff licensing reference RPC exists'
);
select has_function(
  'public',
  'staff_issue_license',
  array[
    'uuid', 'uuid', 'text', 'text', 'text', 'timestamp with time zone',
    'timestamp with time zone', 'boolean', 'text', 'text', 'text[]', 'text', 'uuid'
  ],
  'secure license issuance command exists'
);
select has_function(
  'public',
  'staff_change_license_status',
  array['uuid', 'bigint', 'text', 'text', 'uuid'],
  'secure license status command exists'
);
select has_function(
  'public',
  'staff_grant_license_endorsement',
  array[
    'uuid', 'bigint', 'text', 'timestamp with time zone',
    'timestamp with time zone', 'boolean', 'text', 'uuid'
  ],
  'secure endorsement grant command exists'
);
select has_function(
  'public',
  'staff_revoke_license_endorsement',
  array['uuid', 'bigint', 'text', 'uuid'],
  'secure endorsement revocation command exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.license_status_events'::regclass),
  'license history has row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.license_endorsement_events'::regclass),
  'endorsement history has row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.outbox_events'::regclass),
  'outbox has row-level security enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.licenses', 'select'),
  'authenticated callers cannot read license source tables directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.outbox_events', 'select'),
  'authenticated callers cannot read integration work directly'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.staff_issue_license(uuid,uuid,text,text,text,timestamp with time zone,timestamp with time zone,boolean,text,text,text[],text,uuid)',
    'execute'
  ),
  'anonymous callers cannot execute license issuance'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.staff_issue_license(uuid,uuid,text,text,text,timestamp with time zone,timestamp with time zone,boolean,text,text,text[],text,uuid)',
    'execute'
  ),
  'authenticated callers may reach the secure issuance boundary'
);
select is(
  (select count(*)::integer from public.license_classes where active),
  3,
  'three approved configurable license classes are seeded'
);
select is(
  (select count(*)::integer from public.endorsement_definitions where code in ('regulated-goods', 'consignment', 'serialized-custody')),
  3,
  'approved modular endorsement configuration is seeded'
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
    'b2000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'licensing.officer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'b2000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'catalogue.only@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name)
values
  (
    'c2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001',
    'Licensing Officer'
  ),
  (
    'c2000000-0000-0000-0000-000000000002',
    'b2000000-0000-0000-0000-000000000002',
    'Catalogue Only Staff'
  );

insert into public.staff_assignments (
  id,
  actor_id,
  staff_role_id,
  effective_from
)
values
  (
    'd2000000-0000-0000-0000-000000000001',
    'c2000000-0000-0000-0000-000000000001',
    (select id from public.staff_roles where code = 'licensing_officer'),
    '2026-01-01T00:00:00Z'
  ),
  (
    'd2000000-0000-0000-0000-000000000002',
    'c2000000-0000-0000-0000-000000000002',
    (select id from public.staff_roles where code = 'catalogue_manager'),
    '2026-01-01T00:00:00Z'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select throws_ok(
  $test$select * from public.get_staff_license_queue(null)$test$,
  '42501',
  'staff_permission_denied',
  'staff without licensing permission cannot read the queue'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*)::integer from public.get_staff_license_queue(null)),
  2,
  'a licensing officer sees the seeded internal license queue'
);

select lives_ok(
  $test$
    select * from public.staff_issue_license(
      '92000000-0000-0000-0000-000000000002',
      null,
      'general-trade',
      'harbor-district',
      'active',
      null,
      null,
      true,
      'Public issuance notice.',
      'Private issuance note.',
      array['regulated-goods'],
      'Issue approved general trade authority.',
      'e2000000-0000-0000-0000-000000000001'
    )
  $test$,
  'an authorized officer can issue a license with a modular endorsement'
);

select is(
  (
    select public_reference
    from public.get_staff_license_queue('EEC-LIC-1001')
  ),
  'EEC-LIC-1001',
  'the secure allocator creates the configured immutable reference'
);

select is(
  (
    select count(*)::integer
    from public.get_staff_license_queue('EEC-LIC-1001')
    where status_code = 'active'
      and version = 1
      and jsonb_array_length(endorsements) = 1
  ),
  1,
  'issuance creates one current license with its initial endorsement'
);

select lives_ok(
  $test$
    select * from public.staff_issue_license(
      '92000000-0000-0000-0000-000000000002',
      null,
      'general-trade',
      'harbor-district',
      'active',
      null,
      null,
      true,
      'Public issuance notice.',
      'Private issuance note.',
      array['regulated-goods'],
      'Issue approved general trade authority.',
      'e2000000-0000-0000-0000-000000000001'
    )
  $test$,
  'retrying issuance with the same request id is safe'
);

reset role;

select is(
  (select count(*)::integer from public.licenses where source_request_id = 'e2000000-0000-0000-0000-000000000001'),
  1,
  'an issuance retry does not duplicate business state'
);

select is(
  (select count(*)::integer from public.outbox_events where deduplication_key = 'license.issued:e2000000-0000-0000-0000-000000000001'),
  1,
  'an issuance retry does not duplicate integration work'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (
    select result_code
    from public.public_license_verification('EEC-LIC-1001')
  ),
  'valid',
  'an issued public license is immediately verifiable'
);

select throws_ok(
  $test$
    select * from public.staff_change_license_status(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      99,
      'suspended',
      'Attempt stale status update.',
      'e2000000-0000-0000-0000-000000000002'
    )
  $test$,
  '40001',
  'license_version_conflict',
  'a stale lifecycle command cannot overwrite current state'
);

select lives_ok(
  $test$
    select * from public.staff_change_license_status(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      1,
      'suspended',
      'Suspend for an approved recorded review.',
      'e2000000-0000-0000-0000-000000000003'
    )
  $test$,
  'an authorized officer can suspend a license'
);

select is(
  (select result_code from public.public_license_verification('EEC-LIC-1001')),
  'suspended',
  'public verification reflects the committed suspension'
);

select lives_ok(
  $test$
    select * from public.staff_change_license_status(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      2,
      'active',
      'Reinstate after the recorded review completed.',
      'e2000000-0000-0000-0000-000000000004'
    )
  $test$,
  'an authorized officer can reinstate a suspended current-term license'
);

select lives_ok(
  $test$
    select * from public.staff_grant_license_endorsement(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      3,
      'consignment',
      null,
      null,
      true,
      'Grant approved consignment authority.',
      'e2000000-0000-0000-0000-000000000005'
    )
  $test$,
  'an authorized officer can grant a modular endorsement'
);

select is(
  (
    select jsonb_array_length(endorsements)
    from public.get_staff_license_queue('EEC-LIC-1001')
  ),
  2,
  'the endorsement grant is returned by the authorized projection'
);

select throws_ok(
  $test$
    select * from public.staff_grant_license_endorsement(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      4,
      'consignment',
      null,
      null,
      true,
      'Attempt a duplicate active endorsement.',
      'e2000000-0000-0000-0000-000000000006'
    )
  $test$,
  '22023',
  'endorsement_already_active',
  'overlapping duplicate endorsement authority is rejected'
);

select lives_ok(
  $test$
    select * from public.staff_revoke_license_endorsement(
      (
        select endorsement ->> 'id'
        from public.get_staff_license_queue('EEC-LIC-1001'),
        lateral jsonb_array_elements(endorsements) as endorsement
        where endorsement ->> 'code' = 'consignment'
      )::uuid,
      4,
      'Withdraw approved consignment authority.',
      'e2000000-0000-0000-0000-000000000007'
    )
  $test$,
  'an authorized officer can revoke an endorsement without deleting it'
);

select is(
  (
    select count(*)::integer
    from public.get_staff_license_queue('EEC-LIC-1001'),
      lateral jsonb_array_elements(endorsements) as endorsement
    where endorsement ->> 'code' = 'consignment'
      and endorsement ->> 'revoked_at' is not null
  ),
  1,
  'revoked endorsement history remains visible to authorized staff'
);

select lives_ok(
  $test$
    select * from public.staff_change_license_status(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      5,
      'revoked',
      'Record the final authorized revocation.',
      'e2000000-0000-0000-0000-000000000008'
    )
  $test$,
  'an authorized officer can record a terminal revocation'
);

select throws_ok(
  $test$
    select * from public.staff_change_license_status(
      (select id from public.get_staff_license_queue('EEC-LIC-1001')),
      6,
      'active',
      'Attempt to rewrite terminal history.',
      'e2000000-0000-0000-0000-000000000009'
    )
  $test$,
  '22023',
  'license_transition_invalid',
  'a revoked license cannot be silently reactivated'
);

select is(
  (select result_code from public.public_license_verification('EEC-LIC-1001')),
  'revoked',
  'public verification reflects terminal revocation'
);

reset role;

select ok(
  (
    select
      audit.actor_id = 'c2000000-0000-0000-0000-000000000001'::uuid
      and audit.auth_user_id = 'b2000000-0000-0000-0000-000000000001'::uuid
      and audit.permission_code = 'license.issue'
      and audit.reason = 'Issue approved general trade authority.'
      and audit.request_id = 'e2000000-0000-0000-0000-000000000001'::uuid
      and audit.previous_state is null
      and audit.new_state ->> 'public_reference' = 'EEC-LIC-1001'
    from public.audit_log as audit
    where audit.record_type = 'public.licenses'
      and audit.new_state ->> 'public_reference' = 'EEC-LIC-1001'
    order by audit.occurred_at desc, audit.id desc
    limit 1
  ),
  'issuance records complete actor, permission, reason, request, and state evidence'
);

select is(
  (
    select count(*)::integer
    from public.license_status_events
    where license_id = (select id from public.licenses where public_reference = 'EEC-LIC-1001')
  ),
  4,
  'issuance and every accepted status transition have append-only domain history'
);

select is(
  (
    select count(*)::integer
    from public.license_endorsement_events
    where license_id = (select id from public.licenses where public_reference = 'EEC-LIC-1001')
  ),
  2,
  'post-issuance endorsement grant and revocation have append-only domain history'
);

select is(
  (
    select count(*)::integer
    from public.outbox_events
    where aggregate_id = (select id from public.licenses where public_reference = 'EEC-LIC-1001')
  ),
  6,
  'each accepted lifecycle command creates one durable outbox event'
);

select * from finish();
rollback;
