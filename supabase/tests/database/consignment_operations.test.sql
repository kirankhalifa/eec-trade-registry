begin;

select plan(78);

select has_table('public', 'consignment_agreements', 'consignment agreement register exists');
select has_table('public', 'consignment_issues', 'consignment custody issue register exists');
select has_table('public', 'consignment_reports', 'consignment report register exists');
select has_table('public', 'consignment_events', 'consignment history exists');
select has_function('public', 'get_staff_consignment_workspace', array[]::text[], 'staff workspace exists');
select has_function('public', 'staff_create_consignment_agreement', array['uuid','uuid','uuid','timestamp with time zone','timestamp with time zone','text','text','uuid'], 'agreement command exists');
select has_function('public', 'staff_change_consignment_agreement_status', array['uuid','bigint','text','text','uuid'], 'agreement status command exists');
select has_function('public', 'staff_issue_consignment_stock', array['uuid','uuid','numeric','text','uuid'], 'custody issue command exists');
select has_function('public', 'get_dealer_consignments', array[]::text[], 'dealer custody workspace exists');
select has_function('public', 'dealer_submit_consignment_report', array['uuid','numeric','numeric','numeric','numeric','numeric','text','text','uuid'], 'dealer report command exists');
select has_function('public', 'staff_accept_consignment_report', array['uuid','bigint','uuid','text','uuid'], 'report acceptance command exists');
select has_function('public', 'staff_reject_consignment_report', array['uuid','bigint','text','uuid'], 'report rejection command exists');
select ok((select relrowsecurity from pg_class where oid = 'public.consignment_agreements'::regclass), 'agreements have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.consignment_issues'::regclass), 'issues have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.consignment_reports'::regclass), 'reports have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.consignment_events'::regclass), 'events have RLS');
select ok(not has_table_privilege('authenticated', 'public.consignment_agreements', 'select'), 'authenticated cannot read agreements directly');
select ok(not has_table_privilege('authenticated', 'public.consignment_reports', 'update'), 'authenticated cannot edit reports directly');
select ok(not has_table_privilege('authenticated', 'public.consignment_events', 'insert'), 'authenticated cannot forge history');
select ok(not has_function_privilege('anon', 'public.staff_issue_consignment_stock(uuid,uuid,numeric,text,uuid)', 'execute'), 'anonymous cannot issue stock');
select ok(not has_function_privilege('anon', 'public.dealer_submit_consignment_report(uuid,numeric,numeric,numeric,numeric,numeric,text,text,uuid)', 'execute'), 'anonymous cannot report custody');
select is((select count(*)::integer from public.permission_scopes where code like 'consignment.%'), 6, 'six consignment permissions exist including finance authority');
select is((select count(*)::integer from public.notification_templates where event_type like 'consignment.%'), 4, 'four consignment notification templates exist');
select is((select count(*)::integer from public.integration_event_routes where event_type like 'consignment.%'), 4, 'four consignment notification routes exist');
select ok((select default_scope ?& array['consignment.read','consignment.report'] from public.representative_role_definitions where code = 'portal-representative'), 'dealer role advertises custody scopes');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'consignment_reports_one_submitted_per_issue_idx'), 'one pending report is enforced by a partial unique index');

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('b8000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'consignment.controller@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('b8000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'consignment.dealer@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('b8000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'consignment.other@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now()),
  ('b8000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'consignment.unassigned@example.test', extensions.crypt('test-password', extensions.gen_salt('bf')), now(), now(), now());

insert into public.actor_profiles (id, auth_user_id, display_name, actor_type)
values
  ('c8000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001', 'Consignment Controller', 'staff'),
  ('c8000000-0000-0000-0000-000000000002', 'b8000000-0000-0000-0000-000000000002', 'Consignment Representative', 'dealer'),
  ('c8000000-0000-0000-0000-000000000003', 'b8000000-0000-0000-0000-000000000003', 'Other Representative', 'dealer'),
  ('c8000000-0000-0000-0000-000000000004', 'b8000000-0000-0000-0000-000000000004', 'Unassigned Staff', 'staff');

insert into public.staff_assignments (id, actor_id, staff_role_id, effective_from, assignment_scope)
values ('d8000000-0000-0000-0000-000000000001', 'c8000000-0000-0000-0000-000000000001', (select id from public.staff_roles where code = 'inventory_controller'), '2026-01-01T00:00:00Z', '{}'::jsonb);

insert into public.party_representatives (id, principal_party_id, actor_id, role_definition_id, authority_scope, verified_at)
values
  ('d8000000-0000-0000-0000-000000000002', '92000000-0000-0000-0000-000000000001', 'c8000000-0000-0000-0000-000000000002', (select id from public.representative_role_definitions where code = 'portal-representative'), '{"portal.read":true,"consignment.read":true,"consignment.report":true}'::jsonb, now()),
  ('d8000000-0000-0000-0000-000000000003', '92000000-0000-0000-0000-000000000003', 'c8000000-0000-0000-0000-000000000003', (select id from public.representative_role_definitions where code = 'portal-representative'), '{"portal.read":true}'::jsonb, now());

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
select throws_ok($test$select public.get_staff_consignment_workspace()$test$, '42501', 'staff_permission_denied', 'unassigned staff cannot open consignment operations');
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok($test$select public.get_dealer_consignments()$test$, '42501', 'dealer_scope_denied', 'dealer without custody scope cannot open the workspace');

select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok($test$select public.get_staff_consignment_workspace()$test$, 'controller can open consignment operations');
select lives_ok(
  $test$select * from public.staff_post_inventory_receipt(
    'ab000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000001',
    20, 'CONSIGNMENT-SOURCE', 'Prepare consignment source stock',
    'f8000000-0000-0000-0000-000000000001'
  )$test$,
  'controller can prepare warehouse stock'
);
select lives_ok(
  $test$select * from public.staff_create_consignment_agreement(
    '92000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001', '2026-08-01T00:00:00Z', '2027-08-01T00:00:00Z',
    'Test terms without financial policy.', 'Approve test agreement',
    'f8000000-0000-0000-0000-000000000002'
  )$test$,
  'controller can create a valid agreement'
);
select lives_ok(
  $test$select * from public.staff_create_consignment_agreement(
    '92000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001', '2026-08-01T00:00:00Z', '2027-08-01T00:00:00Z',
    'Test terms without financial policy.', 'Approve test agreement',
    'f8000000-0000-0000-0000-000000000002'
  )$test$,
  'agreement creation is idempotent'
);

reset role;
select is((select count(*)::integer from public.consignment_agreements where source_request_id = 'f8000000-0000-0000-0000-000000000002'), 1, 'one agreement is recorded');
select is((select count(*)::integer from public.consignment_events where event_type = 'agreement_created'), 1, 'agreement creation writes one domain event');
select is((select count(*)::integer from public.outbox_events where event_type = 'consignment.agreement_created'), 1, 'agreement creation writes one outbox event');
select set_config('test.consignment_agreement_id', (select id::text from public.consignment_agreements where source_request_id = 'f8000000-0000-0000-0000-000000000002'), true);
select set_config('test.consignment_source_account_id', (select id::text from public.inventory_accounts where warehouse_id = 'aa000000-0000-0000-0000-000000000001' and stock_location_id = 'ab000000-0000-0000-0000-000000000002' and item_id = '70000000-0000-0000-0000-000000000001'), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_issue_consignment_stock(%L::uuid, %L::uuid, 8, 'Issue dealer custody', 'f8000000-0000-0000-0000-000000000003')$test$, current_setting('test.consignment_agreement_id'), current_setting('test.consignment_source_account_id')), 'controller can issue stock into dealer custody');
select lives_ok(format($test$select * from public.staff_issue_consignment_stock(%L::uuid, %L::uuid, 8, 'Issue dealer custody', 'f8000000-0000-0000-0000-000000000003')$test$, current_setting('test.consignment_agreement_id'), current_setting('test.consignment_source_account_id')), 'custody issue is idempotent');

reset role;
select set_config('test.consignment_issue_id', (select id::text from public.consignment_issues where source_request_id = 'f8000000-0000-0000-0000-000000000003'), true);
select is((select count(*)::integer from public.consignment_issues where source_request_id = 'f8000000-0000-0000-0000-000000000003'), 1, 'one custody issue is recorded');
select is((select count(*)::integer from public.inventory_transactions where transaction_type = 'consignment_issue'), 1, 'one issue transaction is posted');
select is((select count(*)::integer from public.inventory_ledger_entries where inventory_transaction_id = (select issue_transaction_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), 2, 'issue posts two ledger lines');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_transaction_id = (select issue_transaction_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), 0::numeric, 'issue ledger is balanced');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_account_id = current_setting('test.consignment_source_account_id')::uuid), 12::numeric, 'warehouse source balance decreases');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_account_id = (select consigned_inventory_account_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), 8::numeric, 'dealer custody balance increases');
select is((select owner_party_id from public.inventory_accounts where id = (select consigned_inventory_account_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), '92000000-0000-0000-0000-000000000004'::uuid, 'owner is retained in custody');
select is((select custodian_party_id from public.inventory_accounts where id = (select consigned_inventory_account_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), '92000000-0000-0000-0000-000000000001'::uuid, 'dealer is recorded as custodian');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_issue_consignment_stock(%L::uuid, %L::uuid, 99, 'Exceed stock', 'f8000000-0000-0000-0000-000000000004')$test$, current_setting('test.consignment_agreement_id'), current_setting('test.consignment_source_account_id')), '23514', 'consignment_stock_unavailable', 'stock cannot be over-issued');

select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 3, 2, 0, 0, 3, 'Wrong party', 'Submit count', 'f8000000-0000-0000-0000-000000000005')$test$, current_setting('test.consignment_issue_id')), '42501', 'dealer_scope_denied', 'the wrong dealer cannot report another party custody');

select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok($test$select public.get_dealer_consignments()$test$, 'authorized dealer can open its custody workspace');
select lives_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 3, 2, 0, 0, 3, 'Count reconciled.', 'Periodic custody count', 'f8000000-0000-0000-0000-000000000006')$test$, current_setting('test.consignment_issue_id')), 'dealer can submit a reconciled report');
select lives_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 3, 2, 0, 0, 3, 'Count reconciled.', 'Periodic custody count', 'f8000000-0000-0000-0000-000000000006')$test$, current_setting('test.consignment_issue_id')), 'dealer report submission is idempotent');
select throws_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 0, 0, 0, 0, 8, '', 'Duplicate pending count', 'f8000000-0000-0000-0000-000000000007')$test$, current_setting('test.consignment_issue_id')), '23505', 'consignment_report_already_pending', 'only one report may await review');

reset role;
select set_config('test.consignment_report_id', (select id::text from public.consignment_reports where source_request_id = 'f8000000-0000-0000-0000-000000000006'), true);
select is((select count(*)::integer from public.consignment_reports where consignment_issue_id = current_setting('test.consignment_issue_id')::uuid), 1, 'one report is stored after retry');
select is((select count(*)::integer from public.outbox_events where event_type = 'consignment.report_submitted'), 1, 'report submission writes one outbox event');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_accept_consignment_report(%L::uuid, 1, null, 'Missing return account', 'f8000000-0000-0000-0000-000000000008')$test$, current_setting('test.consignment_report_id')), '42501', 'consignment_return_destination_denied', 'returned stock requires an authorized physical destination');
select lives_ok(format($test$select * from public.staff_accept_consignment_report(%L::uuid, 1, %L::uuid, 'Accept reconciled evidence', 'f8000000-0000-0000-0000-000000000009')$test$, current_setting('test.consignment_report_id'), current_setting('test.consignment_source_account_id')), 'controller can accept a reconciled sale and return');
select lives_ok(format($test$select * from public.staff_accept_consignment_report(%L::uuid, 1, %L::uuid, 'Accept reconciled evidence', 'f8000000-0000-0000-0000-000000000009')$test$, current_setting('test.consignment_report_id'), current_setting('test.consignment_source_account_id')), 'report acceptance is idempotent');

reset role;
select is((select status from public.consignment_reports where id = current_setting('test.consignment_report_id')::uuid), 'accepted', 'report advances to accepted');
select is((select quantity_sold from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid), 3::numeric, 'accepted sold quantity is accumulated');
select is((select quantity_returned from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid), 2::numeric, 'accepted return quantity is accumulated');
select is((select quantity_issued - quantity_sold - quantity_returned from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid), 3::numeric, 'accepted report leaves the reconciled custody balance');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_transaction_id = (select settlement_transaction_id from public.consignment_reports where id = current_setting('test.consignment_report_id')::uuid)), 0::numeric, 'settlement ledger is balanced');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_account_id = current_setting('test.consignment_source_account_id')::uuid), 14::numeric, 'returns restore authorized warehouse stock');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_account_id = (select consigned_inventory_account_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), 3::numeric, 'custody balance matches accepted observation');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 0, 0, 1, 0, 2, 'One unit unlocated.', 'Report exception', 'f8000000-0000-0000-0000-000000000010')$test$, current_setting('test.consignment_issue_id')), 'dealer can report an exception without mutating stock');

reset role;
select set_config('test.exception_report_id', (select id::text from public.consignment_reports where source_request_id = 'f8000000-0000-0000-0000-000000000010'), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(format($test$select * from public.staff_accept_consignment_report(%L::uuid, 1, null, 'Try ordinary acceptance', 'f8000000-0000-0000-0000-000000000011')$test$, current_setting('test.exception_report_id')), '22023', 'consignment_report_requires_exception_review', 'lost stock cannot use ordinary acceptance');
select lives_ok(format($test$select * from public.staff_reject_consignment_report(%L::uuid, 1, 'Route to exception review', 'f8000000-0000-0000-0000-000000000012')$test$, current_setting('test.exception_report_id')), 'controller can reject the exception report without settlement');

reset role;
select is((select status from public.consignment_reports where id = current_setting('test.exception_report_id')::uuid), 'rejected', 'exception report is preserved as rejected');
select is((select count(*)::integer from public.inventory_transactions where transaction_type = 'consignment_settlement'), 1, 'rejection posts no inventory settlement');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.dealer_submit_consignment_report(%L::uuid, 3, 0, 0, 0, 0, 'Final count.', 'Final custody report', 'f8000000-0000-0000-0000-000000000013')$test$, current_setting('test.consignment_issue_id')), 'dealer can submit a final reconciled report');

reset role;
select set_config('test.final_report_id', (select id::text from public.consignment_reports where source_request_id = 'f8000000-0000-0000-0000-000000000013'), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_accept_consignment_report(%L::uuid, 1, null, 'Accept final sale', 'f8000000-0000-0000-0000-000000000014')$test$, current_setting('test.final_report_id')), 'controller can accept the final reconciled report');

reset role;
select is((select status from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid), 'closed', 'zero outstanding custody closes the issue');
select is((select sum(quantity_delta) from public.inventory_ledger_entries where inventory_account_id = (select consigned_inventory_account_id from public.consignment_issues where id = current_setting('test.consignment_issue_id')::uuid)), 0::numeric, 'closed issue has zero custody balance');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select lives_ok(format($test$select * from public.staff_change_consignment_agreement_status(%L::uuid, 1, 'closed', 'Close completed agreement', 'f8000000-0000-0000-0000-000000000015')$test$, current_setting('test.consignment_agreement_id')), 'controller can close an agreement after custody reaches zero');

reset role;
select is((select status from public.consignment_agreements where id = current_setting('test.consignment_agreement_id')::uuid), 'closed', 'agreement is closed');
select throws_ok($test$update public.consignment_events set reason = 'rewrite'$test$, '55000', 'posted_inventory_is_immutable', 'consignment history cannot be rewritten');
select ok((select count(*) from public.audit_log where record_type in ('public.consignment_agreements','public.consignment_issues','public.consignment_reports')) >= 9, 'consequential consignment changes are audited');
select ok((select count(*) from public.outbox_events where event_type like 'consignment.%') >= 6, 'consignment lifecycle writes durable integration events');
select is((select count(*)::integer from public.consignment_events where agreement_id = current_setting('test.consignment_agreement_id')::uuid), 10, 'the complete lifecycle is retained as domain history');

select * from finish();
rollback;
