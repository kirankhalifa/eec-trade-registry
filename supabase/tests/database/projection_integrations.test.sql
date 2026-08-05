begin;

select plan(48);

select has_table('public', 'integration_destinations', 'integration destinations table exists');
select has_table('public', 'notification_templates', 'notification templates table exists');
select has_table('public', 'integration_event_routes', 'event routes table exists');
select has_table('public', 'integration_deliveries', 'delivery attempts table exists');
select has_table('public', 'export_definitions', 'export definitions table exists');
select has_table('public', 'export_runs', 'export run history table exists');

select has_function(
  'public',
  'get_public_catalogue_export',
  array[]::text[],
  'public catalogue export projection exists'
);
select has_function(
  'public',
  'get_public_dealer_export',
  array[]::text[],
  'public dealer export projection exists'
);
select has_function(
  'public',
  'get_public_license_export',
  array[]::text[],
  'public license export projection exists'
);
select has_function(
  'public',
  'integration_claim_deliveries',
  array['text', 'integer', 'integer'],
  'delivery claim boundary exists'
);
select has_function(
  'public',
  'integration_claim_export_runs',
  array['text', 'integer', 'integer'],
  'export claim boundary exists'
);
select has_function(
  'public',
  'get_staff_integration_workspace',
  array[]::text[],
  'staff integration workspace exists'
);
select has_function(
  'private',
  'invoke_integration_worker',
  array[]::text[],
  'the protected scheduled worker invocation boundary exists'
);
select is(
  (
    select count(*)::integer
    from cron.job
    where jobname = 'eec-integration-worker'
      and schedule = '*/15 * * * *'
      and active
  ),
  1,
  'Supabase Cron owns one active 15-minute worker trigger'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.integration_destinations'::regclass),
  'integration destinations have RLS'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.integration_deliveries'::regclass),
  'integration deliveries have RLS'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.export_definitions'::regclass),
  'export definitions have RLS'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.export_runs'::regclass),
  'export runs have RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.integration_destinations', 'select'),
  'authenticated callers cannot read destination rows directly'
);
select ok(
  not has_table_privilege('anon', 'public.export_runs', 'select'),
  'anonymous callers cannot read export runs directly'
);
select ok(
  not has_function_privilege('anon', 'public.get_public_catalogue_export()', 'execute'),
  'anonymous callers cannot enumerate the catalogue export RPC'
);
select ok(
  has_function_privilege('service_role', 'public.get_public_catalogue_export()', 'execute'),
  'the server integration role can execute the catalogue export RPC'
);

select is(
  (select count(*)::integer from public.integration_destinations),
  2,
  'disabled Google and Discord destination definitions are seeded'
);
select is(
  (select count(*)::integer from public.export_definitions),
  3,
  'three public export definitions are seeded'
);
select is(
  (
    select count(*)::integer
    from public.notification_templates
    where event_type in (
      'dealer.application_submitted',
      'order.submitted',
      'license.issued',
      'license.status_changed',
      'reservation.created',
      'reservation.expired',
      'inventory.receipt_posted'
    )
  ),
  7,
  'the projection foundation notification templates are seeded'
);
select is(
  (select count(*)::integer from public.get_public_catalogue_export()),
  4,
  'the public catalogue export contains only the four published fixtures'
);
select is(
  (select count(*)::integer from public.get_public_dealer_export()),
  1,
  'the public dealer export excludes private authorizations'
);
select is(
  (select count(*)::integer from public.get_public_license_export()),
  1,
  'the public license export excludes private licenses'
);
select is(
  (
    select count(*)::integer
    from public.get_public_license_export()
    where public_reference = 'LIC-PRIVATE-DEMO'
  ),
  0,
  'the known private license fixture is not exported'
);

create temporary table integration_test_ids as
select
  (select id from public.integration_destinations where code = 'public-registry-sheet') as sheet_destination_id,
  (select id from public.integration_destinations where code = 'staff-alerts') as staff_alert_destination_id,
  (select id from public.export_definitions where code = 'public-catalogue') as catalogue_definition_id;

grant select on table integration_test_ids to authenticated, service_role;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at
)
values
  (
    'b5000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'integration.operator@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  ),
  (
    'b5000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'integration.denied@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  (
    'c5000000-0000-0000-0000-000000000001',
    'b5000000-0000-0000-0000-000000000001',
    'Integration Operator',
    'staff'
  ),
  (
    'c5000000-0000-0000-0000-000000000002',
    'b5000000-0000-0000-0000-000000000002',
    'Unassigned Integration User',
    'staff'
  );

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope
)
values (
  'd5000000-0000-0000-0000-000000000001',
  'c5000000-0000-0000-0000-000000000001',
  (select id from public.staff_roles where code = 'integration_operator'),
  '2026-01-01T00:00:00Z',
  '{}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b5000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select throws_ok(
  $test$select public.get_staff_integration_workspace()$test$,
  '42501',
  'staff_permission_denied',
  'an unassigned user cannot read integration operations'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select lives_ok(
  $test$select public.get_staff_integration_workspace()$test$,
  'an integration operator can read the operations workspace'
);

select lives_ok(
  $test$
    select *
    from public.staff_configure_integration_destination(
      (select sheet_destination_id from pg_temp.integration_test_ids),
      1,
      'test-spreadsheet-id',
      true,
      'Connect the approved public registry Sheet.',
      'e5000000-0000-0000-0000-000000000001'
    )
  $test$,
  'an integration operator can activate a non-secret Sheet destination'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.audit_log
    where record_type = 'public.integration_destinations'
      and reason = 'Connect the approved public registry Sheet.'
  ),
  1,
  'destination configuration is audited with its reason'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select lives_ok(
  $test$
    select *
    from public.staff_set_export_definition_status(
      (select catalogue_definition_id from pg_temp.integration_test_ids),
      1,
      true,
      'Enable the approved catalogue projection.',
      'e5000000-0000-0000-0000-000000000002'
    )
  $test$,
  'an integration operator can enable an approved export definition'
);

select lives_ok(
  $test$
    select public.staff_queue_export_run(
      (select catalogue_definition_id from pg_temp.integration_test_ids),
      'Publish the current catalogue snapshot.',
      'e5000000-0000-0000-0000-000000000003'
    )
  $test$,
  'an integration operator can queue a manual export run'
);

reset role;
set local role service_role;

select is(
  public.integration_queue_due_exports('2026-08-06T00:00:00Z'),
  1,
  'the scheduler queues one due active export definition'
);
select is(
  public.integration_queue_due_exports('2026-08-06T00:00:00Z'),
  0,
  'running the same scheduler instant again is idempotent'
);

create temporary table claimed_export_run as
select * from public.integration_claim_export_runs('test-worker', 1, 300);

select is(
  (select count(*)::integer from claimed_export_run),
  1,
  'one export run is claimed with a lease'
);
select is(
  (select projection_code from claimed_export_run),
  'public_catalogue',
  'the claim returns the approved projection contract'
);

select throws_ok(
  $test$
    select public.integration_complete_export_run(
      (select export_run_id from claimed_export_run),
      'e5000000-0000-0000-0000-000000000099',
      4,
      'checksum',
      'Catalogue!A1:P8',
      now(),
      now()
    )
  $test$,
  '40001',
  'export_lease_conflict',
  'an incorrect export lease cannot complete a run'
);

select lives_ok(
  $test$
    select public.integration_complete_export_run(
      (select export_run_id from claimed_export_run),
      (select lease_token from claimed_export_run),
      4,
      'test-checksum',
      'Catalogue!A1:P8',
      now(),
      now()
    )
  $test$,
  'the current export lease can record successful delivery'
);

reset role;

select is(
  (
    select status
    from public.export_runs
    where id = (select export_run_id from claimed_export_run)
  ),
  'delivered',
  'the delivered export run retains its authoritative status metadata'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select lives_ok(
  $test$
    select *
    from public.staff_configure_integration_destination(
      (select staff_alert_destination_id from pg_temp.integration_test_ids),
      1,
      '123456789012345678',
      true,
      'Connect the approved private staff alert channel.',
      'e5000000-0000-0000-0000-000000000004'
    )
  $test$,
  'an integration operator can activate the Discord channel destination'
);

reset role;

insert into public.outbox_events (
  id,
  event_type,
  aggregate_type,
  aggregate_id,
  payload,
  deduplication_key
)
values (
  'f5000000-0000-0000-0000-000000000001',
  'order.submitted',
  'order',
  'f5000000-0000-0000-0000-000000000002',
  '{"public_reference":"EEC-ORD-TEST","line_count":2,"pricing_status":"pending"}'::jsonb,
  'order.submitted:e5000000-0000-0000-0000-000000000005'
);

set local role service_role;

create temporary table claimed_delivery as
select * from public.integration_claim_deliveries('test-worker', 10, 120);

select is(
  (select count(*)::integer from claimed_delivery),
  1,
  'the active route materializes and claims one Discord delivery'
);
select is(
  (select event_type from claimed_delivery),
  'order.submitted',
  'the claimed delivery retains its versioned business event type'
);

select lives_ok(
  $test$
    select public.integration_complete_delivery(
      (select delivery_id from claimed_delivery),
      (select lease_token from claimed_delivery),
      'discord-message-1'
    )
  $test$,
  'the current delivery lease can record a Discord message id'
);

reset role;

select is(
  (
    select status
    from public.outbox_events
    where id = 'f5000000-0000-0000-0000-000000000001'
  ),
  'delivered',
  'all routed deliveries completing marks the source outbox event delivered'
);

set local role service_role;

select is(
  (
    select count(*)::integer
    from public.integration_claim_deliveries('test-worker', 10, 120)
  ),
  0,
  'a delivered event cannot create a duplicate external delivery'
);

reset role;

select * from finish();

rollback;
