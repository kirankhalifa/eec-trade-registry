begin;

select plan(51);

select has_table('public', 'dealer_authorization_events', 'dealer authorization history table exists');
select has_column('public', 'dealer_authorizations', 'source_request_id', 'dealer onboarding has an idempotency key');
select has_function('public', 'get_staff_dealer_queue', array['text'], 'staff dealer queue exists');
select has_function('public', 'get_staff_dealer', array['uuid'], 'staff dealer detail exists');
select has_function('public', 'get_staff_dealer_reference_data', array[]::text[], 'staff dealer reference data exists');
select has_function('public', 'staff_create_dealer_authorization', array['text','text','text','text','text','text','text','text','text','text','boolean','text','uuid'], 'dealer onboarding command exists');
select has_function('public', 'staff_update_dealer_authorization', array['uuid','bigint','text','text','text','text','text','text','boolean','text','uuid'], 'dealer update command exists');
select has_function('public', 'staff_change_dealer_authorization_status', array['uuid','bigint','text','text','uuid'], 'dealer status command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.dealer_authorization_events'::regclass), 'dealer history has RLS');
select ok(not has_table_privilege('authenticated', 'public.dealer_authorization_events', 'select'), 'authenticated callers cannot read dealer history directly');
select ok(not has_function_privilege('anon', 'public.staff_create_dealer_authorization(text,text,text,text,text,text,text,text,text,text,boolean,text,uuid)', 'execute'), 'anonymous callers cannot onboard dealers');
select ok(has_function_privilege('authenticated', 'public.staff_create_dealer_authorization(text,text,text,text,text,text,text,text,text,text,boolean,text,uuid)', 'execute'), 'authenticated callers may reach the protected onboarding boundary');
select is((select count(*)::integer from public.permission_scopes where code like 'dealer.%'), 7, 'seven dealer registry permissions exist');
select is((select count(*)::integer from public.staff_role_permissions as assignment join public.staff_roles as role on role.id = assignment.staff_role_id where role.code = 'dealer_registry_officer'), 7, 'dealer registry role has seven scoped permissions');
select is((select count(*)::integer from public.dealer_status_definitions where code in ('suspended', 'revoked')), 2, 'suspended and revoked statuses are configured');
select is((select count(*)::integer from public.reference_sequences where document_type = 'dealer_authorization'), 1, 'dealer references use a configurable sequence');
select is((select count(*)::integer from public.notification_templates where event_type like 'dealer.authorization_%'), 3, 'three dealer notification templates exist');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'dealer.authorization_%'), 3, 'three dealer staff-alert routes exist');
select is((select count(*)::integer from public.integration_event_routes as route join public.integration_destinations as destination on destination.id = route.destination_id where route.event_type like 'dealer.authorization_%' and destination.code = 'staff-alerts'), 3, 'dealer notifications target only the configured staff alert destination');
select ok((select message_template from public.notification_templates where event_type = 'dealer.authorization_status_changed') like '%{{previous_status_code}}%{{status_code}}%', 'dealer status notification uses authoritative event payload fields');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('be000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'dealer.registry@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('be000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'dealer.denied@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('bf000000-0000-0000-0000-000000000001', 'be000000-0000-0000-0000-000000000001', 'Dealer Registry Officer', 'staff'),
  ('bf000000-0000-0000-0000-000000000002', 'be000000-0000-0000-0000-000000000002', 'No Dealer Authority', 'staff');

insert into public.staff_assignments (id, actor_id, staff_role_id, effective_from)
values (
  'c1000000-0000-0000-0000-000000000001',
  'bf000000-0000-0000-0000-000000000001',
  (select id from public.staff_roles where code = 'dealer_registry_officer'),
  '2026-01-01T00:00:00Z'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($test$select * from public.get_staff_dealer_queue(null)$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot read the private dealer registry');

select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select * from public.get_staff_dealer_queue(null)$test$, 'dealer registry officer can read the queue');
select ok(public.get_staff_dealer_reference_data() -> 'dealer_types' @> '[{"code":"wholesale-counterparty"}]'::jsonb, 'reference data exposes configured dealer types');

select lives_ok($test$
  select * from public.staff_create_dealer_authorization(
    'organization', 'North Harbor Supply LLC', 'North Harbor Supply', 'North Harbor Supply',
    'wholesale-counterparty', 'harbor-district', 'active', 'North Harbor trade counter',
    'Current public authorization.', 'Private onboarding evidence.', true,
    'Onboard the approved counterparty.', 'c2000000-0000-0000-0000-000000000001'
  )
$test$, 'authorized staff can onboard a dealer atomically');

select lives_ok($test$
  select * from public.staff_create_dealer_authorization(
    'organization', 'North Harbor Supply LLC', 'North Harbor Supply', 'North Harbor Supply',
    'wholesale-counterparty', 'harbor-district', 'active', 'North Harbor trade counter',
    'Current public authorization.', 'Private onboarding evidence.', true,
    'Onboard the approved counterparty.', 'c2000000-0000-0000-0000-000000000001'
  )
$test$, 'dealer onboarding is idempotent');

reset role;
select is((select count(*)::integer from public.dealer_authorizations where source_request_id = 'c2000000-0000-0000-0000-000000000001'), 1, 'one dealer authorization is stored');
select is((select count(*)::integer from public.parties as party join public.dealer_authorizations as dealer on dealer.dealer_party_id = party.id where dealer.source_request_id = 'c2000000-0000-0000-0000-000000000001'), 1, 'one party is stored with the authorization');
select is((select count(*)::integer from public.dealer_authorization_events where request_id = 'c2000000-0000-0000-0000-000000000001'), 1, 'onboarding history is append-only and idempotent');
select is((select count(*)::integer from public.audit_log where record_type = 'public.dealer_authorizations' and request_id = 'c2000000-0000-0000-0000-000000000001'), 1, 'dealer onboarding is audited once');
select is((select count(*)::integer from public.outbox_events where deduplication_key = 'dealer.authorization_created:c2000000-0000-0000-0000-000000000001'), 1, 'dealer onboarding emits one durable event');
select matches((select public_reference from public.dealer_authorizations where source_request_id = 'c2000000-0000-0000-0000-000000000001'), '^EEC-DLR-[0-9]{4,}$', 'dealer public reference comes from configuration');
select set_config('test.dealer_id', (select id::text from public.dealer_authorizations where source_request_id = 'c2000000-0000-0000-0000-000000000001'), true);
select set_config('test.dealer_reference', (select public_reference from public.dealer_authorizations where id = current_setting('test.dealer_id')::uuid), true);
select is((select result_code from public.public_dealer_verification(current_setting('test.dealer_reference'))), 'valid', 'new active disclosed dealer verifies publicly');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_update_dealer_authorization(%L::uuid, 99, 'North Harbor Supply LLC', 'North Harbor Supply', 'North Harbor Supply', 'North Harbor counter', 'Updated public note.', 'Updated private note.', true, 'Reject stale edit.', 'c2000000-0000-0000-0000-000000000002')$test$, current_setting('test.dealer_id')), '40001', 'dealer_authorization_version_conflict', 'stale dealer detail edits are rejected');
select lives_ok(format($test$select * from public.staff_update_dealer_authorization(%L::uuid, 1, 'North Harbor Supply Company', 'North Harbor Trade', 'North Harbor Trade', 'North Harbor counter', 'Updated public note.', 'Updated private note.', true, 'Record approved identity update.', 'c2000000-0000-0000-0000-000000000003')$test$, current_setting('test.dealer_id')), 'authorized staff can update dealer details');

reset role;
select is((select version from public.dealer_authorizations where id = current_setting('test.dealer_id')::uuid), 2::bigint, 'dealer update increments the concurrency version');
select is((select count(*)::integer from public.dealer_authorization_events where request_id = 'c2000000-0000-0000-0000-000000000003' and event_type = 'details_updated'), 1, 'dealer update writes immutable history');
select is((select party.display_name from public.parties as party join public.dealer_authorizations as dealer on dealer.dealer_party_id = party.id where dealer.id = current_setting('test.dealer_id')::uuid), 'North Harbor Trade', 'dealer identity is updated with its authorization');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_change_dealer_authorization_status(%L::uuid, 2, 'internal-review', 'Reject invalid transition.', 'c2000000-0000-0000-0000-000000000004')$test$, current_setting('test.dealer_id')), '22023', 'dealer_transition_invalid', 'active authority cannot return to internal review');
select lives_ok(format($test$select * from public.staff_change_dealer_authorization_status(%L::uuid, 2, 'suspended', 'Suspend pending a recorded review.', 'c2000000-0000-0000-0000-000000000005')$test$, current_setting('test.dealer_id')), 'authorized staff can suspend dealer authority');

reset role;
select is((select status.code from public.dealer_authorizations as dealer join public.dealer_status_definitions as status on status.id = dealer.status_definition_id where dealer.id = current_setting('test.dealer_id')::uuid), 'suspended', 'dealer status is suspended');
select is((select result_code from public.public_dealer_verification(current_setting('test.dealer_reference'))), 'suspended', 'public verification reflects suspension');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_change_dealer_authorization_status(%L::uuid, 3, 'active', 'Reinstate after review.', 'c2000000-0000-0000-0000-000000000006')$test$, current_setting('test.dealer_id')), 'authorized staff can reinstate dealer authority');

reset role;
select is((select status.code from public.dealer_authorizations as dealer join public.dealer_status_definitions as status on status.id = dealer.status_definition_id where dealer.id = current_setting('test.dealer_id')::uuid), 'active', 'dealer status is active again');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_change_dealer_authorization_status(%L::uuid, 4, 'revoked', 'Revoke recorded authority.', 'c2000000-0000-0000-0000-000000000007')$test$, current_setting('test.dealer_id')), 'authorized staff can revoke dealer authority');

reset role;
select is((select status.code from public.dealer_authorizations as dealer join public.dealer_status_definitions as status on status.id = dealer.status_definition_id where dealer.id = current_setting('test.dealer_id')::uuid), 'revoked', 'dealer status is terminally revoked');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_change_dealer_authorization_status(%L::uuid, 5, 'active', 'Reject terminal transition.', 'c2000000-0000-0000-0000-000000000008')$test$, current_setting('test.dealer_id')), '22023', 'dealer_transition_invalid', 'revoked authority cannot be reactivated');

reset role;
select is((select count(*)::integer from public.outbox_events where aggregate_id = current_setting('test.dealer_id')::uuid and event_type = 'dealer.authorization_status_changed'), 3, 'each valid dealer transition emits an outbox event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"be000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($test$
  select * from public.staff_create_dealer_authorization(
    'organization', 'Denied Dealer', 'Denied Dealer', 'Denied Dealer', 'wholesale-counterparty',
    'harbor-district', 'active', '', '', '', false, 'Attempt unauthorized onboarding.',
    'c2000000-0000-0000-0000-000000000009'
  )
$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot onboard a dealer');
select ok(not has_table_privilege('authenticated', 'public.dealer_authorizations', 'insert'), 'authenticated callers cannot bypass the dealer command with direct inserts');
select ok(not has_table_privilege('authenticated', 'public.dealer_authorization_events', 'update'), 'dealer history cannot be rewritten directly');

reset role;
select is((select private_notes from public.dealer_authorizations where id = current_setting('test.dealer_id')::uuid), 'Updated private note.', 'private dealer evidence remains authoritative and private');

select * from finish();
rollback;
