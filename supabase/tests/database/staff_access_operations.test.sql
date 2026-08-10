begin;

select plan(49);

select has_column('public', 'staff_assignments', 'source_request_id', 'assignment grants have idempotency keys');
select has_column('public', 'staff_assignments', 'revocation_request_id', 'assignment revocations have idempotency keys');
select is((select count(*)::integer from public.staff_roles where code = 'platform_administrator'), 1, 'platform administrator role exists');
select has_function('public', 'get_staff_operations_workspace', array[]::text[], 'operations workspace exists');
select has_function('public', 'staff_grant_role_assignment', array['uuid','uuid','timestamp with time zone','timestamp with time zone','jsonb','text','uuid'], 'grant command exists');
select has_function('public', 'staff_revoke_role_assignment', array['uuid','text','uuid'], 'revoke command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.staff_assignments'::regclass), 'staff assignments retain RLS');
select ok(not has_table_privilege('authenticated', 'public.staff_assignments', 'select'), 'authenticated cannot read assignments directly');
select ok(not has_function_privilege('anon', 'public.staff_grant_role_assignment(uuid,uuid,timestamptz,timestamptz,jsonb,text,uuid)', 'execute'), 'anonymous cannot grant roles');
select ok(not has_function_privilege('anon', 'public.staff_revoke_role_assignment(uuid,text,uuid)', 'execute'), 'anonymous cannot revoke roles');
select is((select count(*)::integer from public.permission_scopes where code in ('access.private.read','access.assignment.manage','audit.private.read','operations.health.read')), 4, 'four operations permissions exist');
select is((select count(*)::integer from public.staff_role_permissions as rp join public.staff_roles as role on role.id = rp.staff_role_id where role.code = 'platform_administrator'), 6, 'platform administrator has six scoped operations and configuration permissions');
select is((select count(*)::integer from public.notification_templates where event_type like 'access.assignment_%'), 2, 'two access notification templates exist');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'access.assignment_%'), 2, 'two access notification routes exist');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('ba000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'platform.admin@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('ba000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'platform.target@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('ba000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'platform.denied@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('bb000000-0000-0000-0000-000000000001', 'ba000000-0000-0000-0000-000000000001', 'Platform Administrator', 'staff'),
  ('bb000000-0000-0000-0000-000000000002', 'ba000000-0000-0000-0000-000000000002', 'Access Target', 'staff'),
  ('bb000000-0000-0000-0000-000000000003', 'ba000000-0000-0000-0000-000000000003', 'No Authority', 'staff');

select set_config('test.platform_role_id', (select id::text from public.staff_roles where code = 'platform_administrator'), true);
select set_config('test.auditor_role_id', (select id::text from public.staff_roles where code = 'auditor'), true);

insert into public.staff_assignments (
  id, actor_id, staff_role_id, effective_from, assignment_scope, source_request_id
) values (
  'bc000000-0000-0000-0000-000000000001',
  'bb000000-0000-0000-0000-000000000001',
  current_setting('test.platform_role_id')::uuid,
  '2026-01-01T00:00:00Z',
  '{}'::jsonb,
  'bd000000-0000-0000-0000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_operations_workspace()$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot read operations');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_operations_workspace()$test$, 'platform administrator can read operations');
select is((public.get_staff_operations_workspace() #>> '{capabilities,can_manage_assignments}')::boolean, true, 'platform administrator can manage assignments');
select ok(public.get_staff_operations_workspace() -> 'roles' @> '[{"code":"platform_administrator"}]'::jsonb, 'workspace contains the platform role');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_operations_workspace()$test$, '42501', 'staff_permission_denied', 'target has no implied access');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_grant_role_assignment('10000000-0000-0000-0000-000000000001', %L::uuid, '2026-01-01T00:00:00Z', null, '{}'::jsonb, 'Reject missing actor', 'bd000000-0000-0000-0000-000000000002')$test$, current_setting('test.auditor_role_id')), 'P0002', 'staff_actor_not_found', 'missing actor is rejected');
select throws_ok($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '2026-01-01T00:00:00Z', null, '{}'::jsonb, 'Reject missing role', 'bd000000-0000-0000-0000-000000000003')$test$, 'P0002', 'staff_role_not_found', 'missing role is rejected');
select throws_ok(format($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', %L::uuid, '2026-02-01T00:00:00Z', '2026-01-01T00:00:00Z', '{}'::jsonb, 'Reject invalid term', 'bd000000-0000-0000-0000-000000000004')$test$, current_setting('test.auditor_role_id')), '22023', 'staff_assignment_invalid', 'invalid effective term is rejected');
select lives_ok(format($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', %L::uuid, '2026-01-01T00:00:00Z', null, '{}'::jsonb, 'Grant audit access', 'bd000000-0000-0000-0000-000000000005')$test$, current_setting('test.auditor_role_id')), 'administrator can grant an auditor role');
select lives_ok(format($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', %L::uuid, '2026-01-01T00:00:00Z', null, '{}'::jsonb, 'Grant audit access', 'bd000000-0000-0000-0000-000000000005')$test$, current_setting('test.auditor_role_id')), 'grant is idempotent');

reset role;
select is((select count(*)::integer from public.staff_assignments where source_request_id = 'bd000000-0000-0000-0000-000000000005'), 1, 'one auditor assignment is stored');
select is((select count(*)::integer from public.audit_log where record_type = 'public.staff_assignments' and request_id = 'bd000000-0000-0000-0000-000000000005'), 1, 'grant is audited once');
select is((select count(*)::integer from public.outbox_events where event_type = 'access.assignment_granted' and deduplication_key = 'access.assignment_granted:bd000000-0000-0000-0000-000000000005'), 1, 'grant emits one outbox event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_compliance_workspace()$test$, 'auditor grant becomes effective');
select throws_ok($test$select public.get_staff_operations_workspace()$test$, '42501', 'staff_permission_denied', 'auditor does not gain operations access');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', %L::uuid, '2026-02-01T00:00:00Z', null, '{}'::jsonb, 'Reject overlap', 'bd000000-0000-0000-0000-000000000006')$test$, current_setting('test.auditor_role_id')), '23P01', 'staff_assignment_conflict', 'overlapping assignment is rejected');
select lives_ok(format($test$select * from public.staff_grant_role_assignment('bb000000-0000-0000-0000-000000000002', %L::uuid, '2026-01-01T00:00:00Z', null, '{}'::jsonb, 'Grant a second administrator', 'bd000000-0000-0000-0000-000000000007')$test$, current_setting('test.platform_role_id')), 'second platform administrator can be granted');

reset role;
select is(private.active_platform_administrator_count()::integer, 2, 'two platform administrators are active');
select set_config('test.auditor_assignment_id', (select id::text from public.staff_assignments where source_request_id = 'bd000000-0000-0000-0000-000000000005'), true);
select set_config('test.target_platform_assignment_id', (select id::text from public.staff_assignments where source_request_id = 'bd000000-0000-0000-0000-000000000007'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_revoke_role_assignment(%L::uuid, 'Revoke audit access', 'bd000000-0000-0000-0000-000000000008')$test$, current_setting('test.auditor_assignment_id')), 'administrator can revoke an assignment');
select lives_ok(format($test$select * from public.staff_revoke_role_assignment(%L::uuid, 'Revoke audit access', 'bd000000-0000-0000-0000-000000000008')$test$, current_setting('test.auditor_assignment_id')), 'revoke is idempotent');

reset role;
select ok((select revoked_at is not null from public.staff_assignments where id = current_setting('test.auditor_assignment_id')::uuid), 'assignment is marked revoked');
select is((select count(*)::integer from public.outbox_events where event_type = 'access.assignment_revoked' and deduplication_key = 'access.assignment_revoked:bd000000-0000-0000-0000-000000000008'), 1, 'revoke emits one outbox event');
select is((select count(*)::integer from public.audit_log where record_type = 'public.staff_assignments' and request_id = 'bd000000-0000-0000-0000-000000000008'), 1, 'revoke is audited once');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_revoke_role_assignment(%L::uuid, 'Reject duplicate revoke', 'bd000000-0000-0000-0000-000000000009')$test$, current_setting('test.auditor_assignment_id')), '22023', 'staff_assignment_already_revoked', 'different replay key cannot rewrite a revocation');
select lives_ok(format($test$select * from public.staff_revoke_role_assignment(%L::uuid, 'Remove second administrator', 'bd000000-0000-0000-0000-000000000010')$test$, current_setting('test.target_platform_assignment_id')), 'one of two platform administrators can be revoked');

reset role;
select is(private.active_platform_administrator_count()::integer, 1, 'one platform administrator remains');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok($test$select * from public.staff_revoke_role_assignment('bc000000-0000-0000-0000-000000000001', 'Reject last administrator removal', 'bd000000-0000-0000-0000-000000000011')$test$, '55000', 'last_platform_administrator_required', 'last active platform administrator cannot be revoked');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_compliance_workspace()$test$, '42501', 'staff_permission_denied', 'revoked auditor access is no longer effective');

select set_config('request.jwt.claims', '{"sub":"ba000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select ok(jsonb_array_length(public.get_staff_operations_workspace() -> 'recent_access_audit') >= 4, 'workspace exposes recent access audit evidence');
select ok((public.get_staff_operations_workspace() -> 'health') ? 'reservations_expired_active', 'workspace exposes expired reservation health');
select ok(public.get_staff_operations_workspace() -> 'actors' @> '[{"display_name":"Platform Administrator"}]'::jsonb, 'workspace includes staff actors');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'staff_assignments' and indexdef like '%source_request_id%'), 'grant request id is uniquely indexed');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'staff_assignments' and indexdef like '%revocation_request_id%'), 'revoke request id is uniquely indexed');
select ok(has_function_privilege('authenticated', 'public.get_staff_operations_workspace()', 'execute'), 'authenticated role can invoke the protected workspace');
select ok(not has_table_privilege('authenticated', 'public.staff_assignments', 'insert'), 'authenticated cannot insert assignments directly');

select * from finish();
rollback;
