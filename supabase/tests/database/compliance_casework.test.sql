begin;

select plan(104);

select has_table('public', 'compliance_case_types', 'case type configuration exists');
select has_table('public', 'compliance_violation_types', 'violation type configuration exists');
select has_table('public', 'compliance_action_types', 'action type configuration exists');
select has_table('public', 'compliance_cases', 'compliance case register exists');
select has_table('public', 'compliance_inspections', 'inspection register exists');
select has_table('public', 'compliance_allegations', 'allegation register exists');
select has_table('public', 'compliance_findings', 'finding register exists');
select has_table('public', 'compliance_evidence', 'evidence metadata register exists');
select has_table('public', 'compliance_actions', 'action register exists');
select has_table('public', 'compliance_appeals', 'appeal register exists');
select has_table('public', 'compliance_events', 'case history exists');
select has_function('public', 'get_staff_compliance_workspace', array[]::text[], 'compliance workspace exists');
select has_function('public', 'get_staff_compliance_case', array['uuid'], 'case detail projection exists');
select has_function('public', 'staff_create_compliance_case', array['uuid','uuid','text','uuid','text','text','uuid','text','uuid'], 'case creation command exists');
select has_function('public', 'staff_transition_compliance_case', array['uuid','bigint','text','uuid','text','text','uuid'], 'case transition command exists');
select has_function('public', 'staff_create_compliance_inspection', array['uuid','timestamp with time zone','text','text','text','uuid'], 'inspection planning command exists');
select has_function('public', 'staff_finish_compliance_inspection', array['uuid','bigint','text','text','text','uuid'], 'inspection completion command exists');
select has_function('public', 'staff_record_compliance_allegation', array['uuid','uuid','text','text','uuid'], 'allegation command exists');
select has_function('public', 'staff_record_compliance_evidence', array['uuid','uuid','text','text','text','text','timestamp with time zone','text','uuid'], 'evidence command exists');
select has_function('public', 'staff_record_compliance_finding', array['uuid','uuid','text','text','text','uuid'], 'finding command exists');
select has_function('public', 'staff_recommend_compliance_action', array['uuid','uuid','uuid','text','uuid','text','text','uuid'], 'action recommendation command exists');
select has_function('public', 'staff_review_compliance_action', array['uuid','bigint','text','text','uuid'], 'action review command exists');
select has_function('public', 'staff_record_compliance_appeal', array['uuid','uuid','text','text','uuid'], 'appeal filing command exists');
select has_function('public', 'staff_decide_compliance_appeal', array['uuid','bigint','text','text','text','text','uuid'], 'appeal decision command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_cases'::regclass), 'cases have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_inspections'::regclass), 'inspections have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_allegations'::regclass), 'allegations have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_findings'::regclass), 'findings have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_evidence'::regclass), 'evidence has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_actions'::regclass), 'actions have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_appeals'::regclass), 'appeals have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.compliance_events'::regclass), 'events have RLS');
select ok(not has_table_privilege('authenticated', 'public.compliance_cases', 'select'), 'authenticated cannot read case rows directly');
select ok(not has_table_privilege('authenticated', 'public.compliance_allegations', 'update'), 'authenticated cannot rewrite allegations');
select ok(not has_table_privilege('authenticated', 'public.compliance_evidence', 'select'), 'evidence metadata is not directly readable');
select ok(not has_table_privilege('authenticated', 'public.compliance_events', 'insert'), 'authenticated cannot forge history');
select ok(not has_function_privilege('anon', 'public.staff_create_compliance_case(uuid,uuid,text,uuid,text,text,uuid,text,uuid)', 'execute'), 'anonymous cannot open cases');
select ok(not has_function_privilege('anon', 'public.staff_review_compliance_action(uuid,bigint,text,text,uuid)', 'execute'), 'anonymous cannot review actions');
select is((select count(*)::integer from public.permission_scopes where code like 'compliance.%'), 9, 'nine compliance permissions exist including executable-effect authority');
select is((select count(*)::integer from public.staff_roles where code = 'compliance_officer'), 1, 'compliance officer role exists');
select is((select count(*)::integer from public.notification_templates where event_type like 'compliance.%'), 3, 'three compliance templates exist');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'compliance.%'), 3, 'three compliance routes exist');
select is((select effect_mode from public.compliance_action_types where code = 'recorded-notice'), 'record_only', 'seeded action cannot apply a domain effect');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'compliance_appeals_one_filed_per_action_idx'), 'one filed appeal per action is enforced');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('b9000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'compliance.officer@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('b9000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'compliance.auditor@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('b9000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'compliance.denied@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());
insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c9000000-0000-0000-0000-000000000001', 'b9000000-0000-0000-0000-000000000001', 'Compliance Officer', 'staff'),
  ('c9000000-0000-0000-0000-000000000002', 'b9000000-0000-0000-0000-000000000002', 'Compliance Auditor', 'staff'),
  ('c9000000-0000-0000-0000-000000000003', 'b9000000-0000-0000-0000-000000000003', 'Unassigned Staff', 'staff');
insert into public.staff_assignments (id, actor_id, staff_role_id, effective_from, assignment_scope)
values
  ('d9000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001', (select id from public.staff_roles where code = 'compliance_officer'), '2026-01-01T00:00:00Z', '{}'::jsonb),
  ('d9000000-0000-0000-0000-000000000002', 'c9000000-0000-0000-0000-000000000002', (select id from public.staff_roles where code = 'auditor'), '2026-01-01T00:00:00Z', '{}'::jsonb);

select set_config('test.compliance_case_type_id', (select id::text from public.compliance_case_types where code = 'general-review'), true);
select set_config('test.compliance_violation_type_id', (select id::text from public.compliance_violation_types where code = 'unclassified-matter'), true);
select set_config('test.compliance_action_type_id', (select id::text from public.compliance_action_types where code = 'recorded-notice'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_compliance_workspace()$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot open compliance casework');
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_compliance_workspace()$test$, 'auditor can read the case queue');
select throws_ok($test$select * from public.staff_create_compliance_case(current_setting('test.compliance_case_type_id')::uuid, null, 'none', null, 'restricted', 'Read-only attempt.', null, 'Try opening case', 'f9000000-0000-0000-0000-000000000001')$test$, '42501', 'staff_permission_denied', 'auditor cannot open a case');

select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_compliance_workspace()$test$, 'compliance officer can open casework');
select throws_ok($test$select * from public.staff_create_compliance_case(current_setting('test.compliance_case_type_id')::uuid, null, 'license', '10000000-0000-0000-0000-000000000001', 'restricted', 'Invalid relation.', null, 'Reject invalid relation', 'f9000000-0000-0000-0000-000000000002')$test$, '22023', 'compliance_case_invalid', 'a nonexistent related record is rejected');
select lives_ok($test$select * from public.staff_create_compliance_case(
  current_setting('test.compliance_case_type_id')::uuid,
  '92000000-0000-0000-0000-000000000001', 'license', '99000000-0000-0000-0000-000000000001',
  'restricted', 'Review a recorded matter without presuming an outcome.', 'c9000000-0000-0000-0000-000000000001',
  'Open for structured triage', 'f9000000-0000-0000-0000-000000000003'
)$test$, 'officer can open a policy-neutral case');
select lives_ok($test$select * from public.staff_create_compliance_case(
  current_setting('test.compliance_case_type_id')::uuid,
  '92000000-0000-0000-0000-000000000001', 'license', '99000000-0000-0000-0000-000000000001',
  'restricted', 'Review a recorded matter without presuming an outcome.', 'c9000000-0000-0000-0000-000000000001',
  'Open for structured triage', 'f9000000-0000-0000-0000-000000000003'
)$test$, 'case creation is idempotent');

reset role;
select set_config('test.compliance_case_id', (select id::text from public.compliance_cases where source_request_id = 'f9000000-0000-0000-0000-000000000003'), true);
select is((select count(*)::integer from public.compliance_cases), 1, 'one case is stored');
select is((select status from public.compliance_cases where id = current_setting('test.compliance_case_id')::uuid), 'open', 'opening does not imply a finding state');
select is((select count(*)::integer from public.compliance_events where event_type = 'case_opened'), 1, 'opening writes one immutable event');
select is((select count(*)::integer from public.outbox_events where event_type = 'compliance.case_opened'), 1, 'opening writes one outbox event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select public.get_staff_compliance_case(%L::uuid)$test$, current_setting('test.compliance_case_id')), 'officer can read the case file');
select lives_ok(format($test$select * from public.staff_create_compliance_inspection(%L::uuid, '2026-08-20T14:00:00Z', 'Configured premises', 'Observe and document current records.', 'Plan inspection', 'f9000000-0000-0000-0000-000000000004')$test$, current_setting('test.compliance_case_id')), 'officer can plan an inspection');

reset role;
select set_config('test.compliance_inspection_id', (select id::text from public.compliance_inspections where source_request_id = 'f9000000-0000-0000-0000-000000000004'), true);
select is((select status from public.compliance_inspections where id = current_setting('test.compliance_inspection_id')::uuid), 'planned', 'inspection starts as planned');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_finish_compliance_inspection(%L::uuid, 1, 'completed', '', 'Missing observations', 'f9000000-0000-0000-0000-000000000005')$test$, current_setting('test.compliance_inspection_id')), '22023', 'compliance_inspection_transition_invalid', 'completed inspection requires observations');
select lives_ok(format($test$select * from public.staff_finish_compliance_inspection(%L::uuid, 1, 'completed', 'Records were observed and preserved.', 'Complete inspection', 'f9000000-0000-0000-0000-000000000006')$test$, current_setting('test.compliance_inspection_id')), 'officer can complete an inspection');
select lives_ok(format($test$select * from public.staff_finish_compliance_inspection(%L::uuid, 1, 'completed', 'Records were observed and preserved.', 'Complete inspection', 'f9000000-0000-0000-0000-000000000006')$test$, current_setting('test.compliance_inspection_id')), 'inspection completion is idempotent');
select lives_ok(format($test$select * from public.staff_record_compliance_allegation(%L::uuid, current_setting('test.compliance_violation_type_id')::uuid, 'A matter is alleged for investigation.', 'Record unproven allegation', 'f9000000-0000-0000-0000-000000000007')$test$, current_setting('test.compliance_case_id')), 'officer can record an allegation');

reset role;
select set_config('test.compliance_allegation_id', (select id::text from public.compliance_allegations where source_request_id = 'f9000000-0000-0000-0000-000000000007'), true);
select is((select count(*)::integer from public.compliance_findings), 0, 'an allegation creates no finding');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_record_compliance_finding(%L::uuid, %L::uuid, 'substantiated', 'Premature rationale.', 'Try premature finding', 'f9000000-0000-0000-0000-000000000008')$test$, current_setting('test.compliance_case_id'), current_setting('test.compliance_allegation_id')), '22023', 'compliance_finding_invalid', 'finding cannot be recorded before investigation');
select lives_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 1, 'investigating', 'c9000000-0000-0000-0000-000000000001', null, 'Begin investigation', 'f9000000-0000-0000-0000-000000000009')$test$, current_setting('test.compliance_case_id')), 'case can enter investigation');
select lives_ok(format($test$select * from public.staff_record_compliance_evidence(%L::uuid, %L::uuid, 'system_record', 'restricted', 'AUDIT-REF-1', 'Immutable system-record reference.', '2026-08-10T00:00:00Z', 'Record evidence metadata', 'f9000000-0000-0000-0000-000000000010')$test$, current_setting('test.compliance_case_id'), current_setting('test.compliance_inspection_id')), 'officer can record restricted evidence metadata');
select lives_ok(format($test$select * from public.staff_record_compliance_finding(%L::uuid, %L::uuid, 'inconclusive', 'The preserved record does not support a conclusive outcome.', 'Record explicit finding', 'f9000000-0000-0000-0000-000000000011')$test$, current_setting('test.compliance_case_id'), current_setting('test.compliance_allegation_id')), 'officer can record an explicit finding during investigation');

reset role;
select is((select outcome from public.compliance_findings where source_request_id = 'f9000000-0000-0000-0000-000000000011'), 'inconclusive', 'finding outcome is explicit');
select is((select count(*)::integer from public.compliance_allegations), 1, 'finding does not rewrite the allegation');
select is((select confidentiality_level from public.compliance_evidence where source_request_id = 'f9000000-0000-0000-0000-000000000010'), 'restricted', 'evidence classification is retained');
select throws_ok($test$update public.compliance_allegations set statement = 'rewrite'$test$, '55000', 'posted_inventory_is_immutable', 'allegations are immutable');
select throws_ok($test$delete from public.compliance_findings$test$, '55000', 'posted_inventory_is_immutable', 'findings are immutable');
select throws_ok($test$update public.compliance_evidence set description = 'rewrite'$test$, '55000', 'posted_inventory_is_immutable', 'evidence metadata is immutable');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_recommend_compliance_action(%L::uuid, current_setting('test.compliance_action_type_id')::uuid, '92000000-0000-0000-0000-000000000001', 'license', '99000000-0000-0000-0000-000000000001', 'Record a notice for review.', 'Recommend record-only action', 'f9000000-0000-0000-0000-000000000012')$test$, current_setting('test.compliance_case_id')), 'officer can recommend a record-only action');
select lives_ok(format($test$select * from public.staff_recommend_compliance_action(%L::uuid, current_setting('test.compliance_action_type_id')::uuid, '92000000-0000-0000-0000-000000000001', 'license', '99000000-0000-0000-0000-000000000001', 'Record a notice for review.', 'Recommend record-only action', 'f9000000-0000-0000-0000-000000000012')$test$, current_setting('test.compliance_case_id')), 'action recommendation is idempotent');

reset role;
select set_config('test.compliance_action_id', (select id::text from public.compliance_actions where source_request_id = 'f9000000-0000-0000-0000-000000000012'), true);
select is((select count(*)::integer from public.compliance_actions), 1, 'one action is recorded after retry');
select is((select effect_applied from public.compliance_actions where id = current_setting('test.compliance_action_id')::uuid), false, 'recommendation has no domain effect');
select set_config('test.license_status_before', (select status_definition_id::text from public.licenses where id = '99000000-0000-0000-0000-000000000001'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_review_compliance_action(%L::uuid, 1, 'approved', 'Approve record-only notice', 'f9000000-0000-0000-0000-000000000013')$test$, current_setting('test.compliance_action_id')), 'authorized officer can approve the record-only action');
select lives_ok(format($test$select * from public.staff_review_compliance_action(%L::uuid, 1, 'approved', 'Approve record-only notice', 'f9000000-0000-0000-0000-000000000013')$test$, current_setting('test.compliance_action_id')), 'action review is idempotent');

reset role;
select is((select status from public.compliance_actions where id = current_setting('test.compliance_action_id')::uuid), 'approved', 'action review records approval');
select is((select effect_applied from public.compliance_actions where id = current_setting('test.compliance_action_id')::uuid), false, 'approved record-only action still has no domain effect');
select is((select status_definition_id::text from public.licenses where id = '99000000-0000-0000-0000-000000000001'), current_setting('test.license_status_before'), 'compliance approval does not silently change license state');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_record_compliance_appeal(%L::uuid, '92000000-0000-0000-0000-000000000001', 'The party requests review of the recorded action.', 'Record appeal filing', 'f9000000-0000-0000-0000-000000000014')$test$, current_setting('test.compliance_action_id')), 'officer can record an appeal');
select throws_ok(format($test$select * from public.staff_record_compliance_appeal(%L::uuid, '92000000-0000-0000-0000-000000000001', 'Duplicate appeal.', 'Reject duplicate appeal', 'f9000000-0000-0000-0000-000000000015')$test$, current_setting('test.compliance_action_id')), '23505', 'compliance_appeal_already_filed', 'only one appeal may await decision for an action');

reset role;
select set_config('test.compliance_appeal_id', (select id::text from public.compliance_appeals where source_request_id = 'f9000000-0000-0000-0000-000000000014'), true);
select is((select status from public.compliance_appeals where id = current_setting('test.compliance_appeal_id')::uuid), 'filed', 'appeal begins as filed');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_decide_compliance_appeal(%L::uuid, 1, 'decided', 'reversed', 'The record-only action should be reversed.', 'Complete appeal review', 'f9000000-0000-0000-0000-000000000016')$test$, current_setting('test.compliance_appeal_id')), 'officer can record an appeal outcome');
select lives_ok(format($test$select * from public.staff_decide_compliance_appeal(%L::uuid, 1, 'decided', 'reversed', 'The record-only action should be reversed.', 'Complete appeal review', 'f9000000-0000-0000-0000-000000000016')$test$, current_setting('test.compliance_appeal_id')), 'appeal decision is idempotent');

reset role;
select is((select outcome from public.compliance_appeals where id = current_setting('test.compliance_appeal_id')::uuid), 'reversed', 'appeal outcome is explicit');
select is((select effect_applied from public.compliance_actions where id = current_setting('test.compliance_action_id')::uuid), false, 'appeal does not invent a cross-domain effect');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 2, 'deciding', 'c9000000-0000-0000-0000-000000000001', null, 'Move to decision', 'f9000000-0000-0000-0000-000000000017')$test$, current_setting('test.compliance_case_id')), 'case can enter deciding');
select throws_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 3, 'resolved', 'c9000000-0000-0000-0000-000000000001', null, 'Missing resolution', 'f9000000-0000-0000-0000-000000000018')$test$, current_setting('test.compliance_case_id')), '22023', 'compliance_resolution_required', 'resolution text is required');
select lives_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 3, 'resolved', 'c9000000-0000-0000-0000-000000000001', 'Review completed with an inconclusive finding and recorded appeal outcome.', 'Resolve case', 'f9000000-0000-0000-0000-000000000019')$test$, current_setting('test.compliance_case_id')), 'case can be resolved with an explicit resolution');
select lives_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 4, 'closed', 'c9000000-0000-0000-0000-000000000001', null, 'Close resolved case', 'f9000000-0000-0000-0000-000000000020')$test$, current_setting('test.compliance_case_id')), 'resolved case can close');
select throws_ok(format($test$select * from public.staff_record_compliance_allegation(%L::uuid, current_setting('test.compliance_violation_type_id')::uuid, 'Late allegation.', 'Reject closed mutation', 'f9000000-0000-0000-0000-000000000021')$test$, current_setting('test.compliance_case_id')), '22023', 'compliance_allegation_invalid', 'closed case rejects new allegations');
select lives_ok(format($test$select * from public.staff_transition_compliance_case(%L::uuid, 5, 'reopened', 'c9000000-0000-0000-0000-000000000001', null, 'Reopen with reason', 'f9000000-0000-0000-0000-000000000022')$test$, current_setting('test.compliance_case_id')), 'closed case can be reopened with authority and reason');

reset role;
select is((select status from public.compliance_cases where id = current_setting('test.compliance_case_id')::uuid), 'reopened', 'reopen state is explicit');
select is((select resolution from public.compliance_cases where id = current_setting('test.compliance_case_id')::uuid), null, 'reopening clears the prior current-resolution projection');
select is((select closed_at from public.compliance_cases where id = current_setting('test.compliance_case_id')::uuid), null, 'reopening clears the current closed timestamp');
select throws_ok($test$delete from public.compliance_events$test$, '55000', 'posted_inventory_is_immutable', 'case history cannot be deleted');
select ok((select count(*) from public.audit_log where record_type like 'public.compliance_%') >= 12, 'consequential casework is audited');
select ok((select count(*) from public.outbox_events where event_type like 'compliance.%') >= 8, 'casework emits durable integration events');
select ok((select count(*) from public.compliance_events where compliance_case_id = current_setting('test.compliance_case_id')::uuid) >= 13, 'case chronology retains every domain event');
select is((select count(*)::integer from public.compliance_findings where compliance_case_id = current_setting('test.compliance_case_id')::uuid), 1, 'the case retains exactly one explicit finding');
select is((select count(*)::integer from public.compliance_appeals where compliance_case_id = current_setting('test.compliance_case_id')::uuid), 1, 'the case retains exactly one appeal');

select * from finish();
rollback;
