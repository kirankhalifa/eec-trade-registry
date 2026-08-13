begin;

select plan(45);

select has_table('public', 'staff_access_requests', 'Discord access requests are stored authoritatively');
select is((select count(*)::integer from public.staff_roles where code = 'owner'), 1, 'one user-facing Owner role exists');
select is((select count(*)::integer from public.staff_roles where code = 'agent'), 1, 'one user-facing Agent role exists');
select is(
  (select count(*)::integer from public.staff_role_permissions role_permission join public.staff_roles role on role.id = role_permission.staff_role_id where role.code = 'owner'),
  (select count(*)::integer from public.permission_scopes where active),
  'Owner receives every active permission'
);
select is(
  (select count(*)::integer from public.staff_role_permissions role_permission join public.staff_roles role on role.id = role_permission.staff_role_id join public.permission_scopes permission on permission.id = role_permission.permission_scope_id where role.code = 'agent' and permission.code = 'access.assignment.manage'),
  0,
  'Agent cannot administer staff access'
);
select ok((select relrowsecurity from pg_class where oid = 'public.staff_access_requests'::regclass), 'access requests have RLS');
select ok(not has_table_privilege('authenticated', 'public.staff_access_requests', 'select'), 'authenticated users cannot enumerate requests directly');
select ok(not has_function_privilege('anon', 'public.register_staff_access_request(uuid)', 'execute'), 'anonymous callers cannot register staff access');
select ok(has_function_privilege('authenticated', 'public.register_staff_access_request(uuid)', 'execute'), 'authenticated Discord users can register for review');
select has_function('public', 'get_my_staff_access_state', array[]::text[], 'self access-state projection exists');
select has_function('public', 'get_owner_access_workspace', array[]::text[], 'owner access workspace exists');
select has_function('public', 'owner_review_staff_access_request', array['uuid','bigint','text','text','uuid'], 'owner review command exists');
select has_function('public', 'get_staff_license_application_review_workspace', array[]::text[], 'dedicated application review workspace exists');
select is((select count(*)::integer from public.notification_templates where event_type in ('access.request_submitted', 'access.request_reviewed')), 2, 'access request notification projections are configured');
select is((select count(*)::integer from public.staff_roles where code = 'business'), 0, 'Business is not a global staff role');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('fc100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'owner@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('fc100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'applicant@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
values
  (
    'fc110000-0000-4000-8000-000000000001', '111111111111111111',
    'fc100000-0000-4000-8000-000000000001',
    '{"sub":"111111111111111111","full_name":"Registry Owner"}'::jsonb,
    'discord', now(), now(), now()
  ),
  (
    'fc110000-0000-4000-8000-000000000002', '222222222222222222',
    'fc100000-0000-4000-8000-000000000002',
    '{"sub":"222222222222222222","full_name":"Prospective Agent"}'::jsonb,
    'discord', now(), now(), now()
  );

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values ('fc200000-0000-4000-8000-000000000001', 'fc100000-0000-4000-8000-000000000001', 'Registry Owner', 'staff');

insert into public.staff_assignments (actor_id, staff_role_id, effective_from, assignment_scope)
select 'fc200000-0000-4000-8000-000000000001', role.id, '2026-01-01T00:00:00Z', '{}'::jsonb
from public.staff_roles as role where role.code = 'owner';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $test$select public.register_staff_access_request('fc300000-0000-4000-8000-000000000001')$test$,
  'first Discord login creates a pending request'
);
reset role;

select is((select count(*)::integer from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002' and status = 'pending'), 1, 'one pending request is stored');
select is((select count(*)::integer from public.outbox_events where event_type = 'access.request_submitted' and aggregate_id = (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')), 1, 'new request emits one durable notification event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.get_my_staff_access_state() ->> 'state', 'pending', 'requester sees pending rather than authority');
select throws_ok($test$select public.get_staff_command_dashboard()$test$, '42501', 'staff_permission_denied', 'pending identity cannot read staff dashboard');
select throws_ok($test$select public.get_owner_access_workspace()$test$, '42501', 'staff_permission_denied', 'pending identity cannot read owner queue');

select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_owner_access_workspace()$test$, 'Owner can read access workspace');
select ok(public.get_owner_access_workspace() -> 'requests' @> '[{"display_name":"Prospective Agent","status":"pending"}]'::jsonb, 'owner queue identifies the pending Discord user');
select is((public.get_staff_command_dashboard() #>> '{access,requests_pending}')::integer, 1, 'owner dashboard shows pending access count');

select lives_ok(format(
  $test$select * from public.owner_review_staff_access_request(%L::uuid, 1, 'approve', 'Known server agent.', 'fc300000-0000-4000-8000-000000000002')$test$,
  (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')
), 'Owner approves the request as Agent');
select lives_ok(format(
  $test$select * from public.owner_review_staff_access_request(%L::uuid, 1, 'approve', 'Known server agent.', 'fc300000-0000-4000-8000-000000000002')$test$,
  (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')
), 'approval retry is idempotent');
reset role;

select is((select count(*)::integer from public.actor_profiles where auth_user_id = 'fc100000-0000-4000-8000-000000000002' and status = 'active'), 1, 'approval creates one active actor');
select is((select count(*)::integer from public.staff_assignments assignment join public.staff_roles role on role.id = assignment.staff_role_id join public.actor_profiles actor on actor.id = assignment.actor_id where actor.auth_user_id = 'fc100000-0000-4000-8000-000000000002' and role.code = 'agent' and assignment.revoked_at is null), 1, 'approval creates one Agent assignment');
select is((select status from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002'), 'approved', 'request records approval');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.get_my_staff_access_state() ->> 'state', 'authorized', 'approved Agent becomes authorized');
select is(public.get_my_staff_access_state() ->> 'access_class', 'agent', 'approved identity receives only Agent access class');
select lives_ok($test$select public.get_staff_command_dashboard()$test$, 'Agent can use the day-to-day dashboard');

select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(public.get_owner_access_workspace() -> 'staff' @> '[{"display_name":"Prospective Agent","access_class":"agent"}]'::jsonb, 'owner roster shows the Agent');
select lives_ok(format(
  $test$select * from public.owner_review_staff_access_request(%L::uuid, 2, 'block', 'Agent access withdrawn.', 'fc300000-0000-4000-8000-000000000003')$test$,
  (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')
), 'Owner can block an approved Agent');
reset role;

select is((select status from public.actor_profiles where auth_user_id = 'fc100000-0000-4000-8000-000000000002'), 'disabled', 'blocking disables the actor');
select ok((select revoked_at is not null from public.staff_assignments assignment join public.staff_roles role on role.id = assignment.staff_role_id join public.actor_profiles actor on actor.id = assignment.actor_id where actor.auth_user_id = 'fc100000-0000-4000-8000-000000000002' and role.code = 'agent'), 'blocking revokes Agent assignment');
select is((select status from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002'), 'blocked', 'request records block');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.get_my_staff_access_state() ->> 'state', 'blocked', 'blocked user sees blocked state');

select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(format(
  $test$select * from public.owner_review_staff_access_request(%L::uuid, 3, 'approve', 'Agent reinstated after review.', 'fc300000-0000-4000-8000-000000000004')$test$,
  (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')
), 'Owner can deliberately reapprove a blocked Agent');
reset role;

select is((select count(*)::integer from public.staff_assignments assignment join public.staff_roles role on role.id = assignment.staff_role_id join public.actor_profiles actor on actor.id = assignment.actor_id where actor.auth_user_id = 'fc100000-0000-4000-8000-000000000002' and role.code = 'agent' and assignment.revoked_at is null), 1, 'reapproval creates one current Agent assignment');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.get_my_staff_access_state() ->> 'state', 'authorized', 'reapproved Agent regains access');

select set_config('request.jwt.claims', '{"sub":"fc100000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_license_application_review_workspace()$test$, 'Owner can open dedicated license application review workspace');
reset role;

select cmp_ok((select count(*)::integer from public.audit_log where record_type in ('public.staff_access_requests', 'public.actor_profiles', 'public.staff_assignments') and request_id in ('fc300000-0000-4000-8000-000000000001','fc300000-0000-4000-8000-000000000002','fc300000-0000-4000-8000-000000000003','fc300000-0000-4000-8000-000000000004')), '>=', 7, 'registration and every authority change are audited');
select is((select count(*)::integer from public.outbox_events where event_type = 'access.request_reviewed' and aggregate_id = (select id from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002')), 3, 'approval, block, and reapproval each emit durable review events');
select is((select version::integer from public.staff_access_requests where auth_user_id = 'fc100000-0000-4000-8000-000000000002'), 4, 'request version protects all three decisions');

select * from finish();
rollback;
