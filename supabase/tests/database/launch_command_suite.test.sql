begin;

select plan(45);

select has_table('public','commercial_channel_policies','commercial channel policy table exists');
select has_table('public','price_schedule_bindings','price binding table exists');
select has_table('public','direct_customer_profiles','direct customer table exists');
select has_table('public','personal_quota_entries','personal quota table exists');
select has_table('public','license_applications','license application table exists');
select has_table('public','license_renewal_events','license renewal history exists');
select has_table('public','consignment_finance_terms','consignment terms exist');
select has_table('public','consignment_settlements','consignment settlements exist');
select has_table('public','unique_fulfillments','unique fulfillment evidence exists');
select has_table('public','compliance_effect_executions','compliance effect evidence exists');
select has_table('public','generated_documents','generated document snapshots exist');
select has_function('public','staff_create_trade_order',array['text','uuid','text','text','uuid','uuid','uuid','text','text','jsonb','text','uuid'],'assisted order command exists');
select has_function('public','public_submit_license_application',array['text','text','text','text','text','text','text[]','text','uuid'],'public application command exists');
select has_function('public','staff_fulfill_unique_asset',array['uuid','bigint','bigint','text','uuid'],'unique fulfillment command exists');
select has_function('public','staff_generate_document_snapshot',array['text','uuid','text','uuid'],'document command exists');
select has_function('public','get_staff_command_dashboard',array[]::text[],'dashboard projection exists');
select is((select price_multiplier_basis_points from public.commercial_channel_policies where channel_code='direct_individual'),30000,'direct premium is exactly three times base');
select is((select count(*)::integer from public.permission_scopes where code in ('dashboard.read','order.assisted.create','pricing.binding.manage','license.application.review','consignment.finance.manage','asset.fulfill','compliance.effect.apply','document.generate','document.private.read')),9,'launch permissions are configured');
select is((select count(*)::integer from public.staff_roles where code='finance_officer'),1,'finance officer role is configured');
select ok((select relrowsecurity from pg_class where oid='public.license_applications'::regclass),'application table has RLS');
select ok((select relrowsecurity from pg_class where oid='public.generated_documents'::regclass),'document table has RLS');
select ok(not has_table_privilege('anon','public.license_applications','select'),'anonymous callers cannot enumerate applications');
select ok(not has_table_privilege('authenticated','public.personal_quota_entries','insert'),'staff cannot bypass quota commands');
select ok(has_function_privilege('anon','public.public_submit_license_application(text,text,text,text,text,text,text[],text,uuid)','execute'),'anonymous callers may submit constrained applications');
select ok(not has_function_privilege('anon','public.staff_create_trade_order(text,uuid,text,text,uuid,uuid,uuid,text,text,jsonb,text,uuid)','execute'),'anonymous callers cannot create staff orders');

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values('fb100000-0000-4000-8000-000000000001','authenticated','authenticated','launch.admin@example.test',extensions.crypt('test-password',extensions.gen_salt('bf')),now(),now(),now());
insert into public.actor_profiles(id,auth_user_id,display_name,actor_type)
values('fb200000-0000-4000-8000-000000000001','fb100000-0000-4000-8000-000000000001','Launch Administrator','staff');
insert into public.staff_assignments(actor_id,staff_role_id,effective_from,assignment_scope)
select 'fb200000-0000-4000-8000-000000000001',role.id,'2026-01-01T00:00:00Z','{}'::jsonb from public.staff_roles role where role.code='platform_administrator';

insert into public.price_rules(price_schedule_id,item_id,amount_minor,effective_from,approved_at)
values('80000000-0000-0000-0000-000000000001','ce000000-0000-0000-0000-000000000006',1000,'2026-08-10T00:00:00Z','2026-08-10T00:00:00Z');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fb100000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($test$
  select * from public.staff_create_trade_order(
    'direct_individual',null,'Aurelion Earandil','aurelion',null,null,
    '90000000-0000-0000-0000-000000000001','collection','Direct counter order.',
    '[{"item_id":"ce000000-0000-0000-0000-000000000006","quantity":1}]'::jsonb,
    'Agent entered the direct request.','fb300000-0000-4000-8000-000000000001'
  )
$test$,'direct order command succeeds');
select lives_ok($test$select public.get_staff_command_dashboard()$test$,'authorized staff can read dashboard');
select lives_ok($test$select public.get_staff_launch_workspace()$test$,'authorized staff can read launch workspace');
reset role;

select is((select source_channel from public.orders where source_request_id='fb300000-0000-4000-8000-000000000001'),'direct_individual','order records direct channel');
select is((select base_price_minor_snapshot from public.order_lines line join public.orders order_item on order_item.id=line.order_id where order_item.source_request_id='fb300000-0000-4000-8000-000000000001'),1000::bigint,'line freezes public base price');
select is((select unit_price_minor_snapshot from public.order_lines line join public.orders order_item on order_item.id=line.order_id where order_item.source_request_id='fb300000-0000-4000-8000-000000000001'),3000::bigint,'line applies automatic three-times premium');
select is((select price_multiplier_basis_points_snapshot from public.order_lines line join public.orders order_item on order_item.id=line.order_id where order_item.source_request_id='fb300000-0000-4000-8000-000000000001'),30000,'line freezes multiplier provenance');
select is((select status from public.personal_quota_entries),'held','submission holds weekly quota');
select is((select quantity from public.personal_quota_entries),1::numeric,'quota holds requested quantity');
select set_config('test.direct_party_id',(select party_id::text from public.direct_customer_profiles limit 1),true);
select set_config('test.direct_order_id',(select id::text from public.orders where source_request_id='fb300000-0000-4000-8000-000000000001'),true);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"fb100000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok(format($test$
  select * from public.staff_create_trade_order(
    'direct_individual',%L::uuid,'','aurelion',null,null,
    '90000000-0000-0000-0000-000000000001','collection','Second direct order.',
    '[{"item_id":"ce000000-0000-0000-0000-000000000006","quantity":1}]'::jsonb,
    'Attempt another request.','fb300000-0000-4000-8000-000000000002'
  )
$test$,current_setting('test.direct_party_id')),'22023','direct_weekly_limit_exceeded','second same-week quantity is rejected');
select lives_ok(format($test$select * from public.staff_cancel_order(%L::uuid,1,'Customer cancelled.','fb300000-0000-4000-8000-000000000003')$test$,
  current_setting('test.direct_order_id')),'staff can cancel the direct order');
reset role;
select is((select status from public.personal_quota_entries),'released','cancellation releases quota');

set local role anon;
select lives_ok($test$
  select * from public.public_submit_license_application('new','Solitude Tailor','tailor-discord','trade-general','harbor-district',null,
    array['tailoring-textiles'],'Operate a licensed tailoring business.','fb300000-0000-4000-8000-000000000004')
$test$,'anonymous applicant can submit');
reset role;
select is((select status from public.license_applications where source_request_id='fb300000-0000-4000-8000-000000000004'),'submitted','application enters submitted state');
select ok((select status_token_digest ~ '^[0-9a-f]{64}$' from public.license_applications where source_request_id='fb300000-0000-4000-8000-000000000004'),'only a SHA-256 token digest is stored');
select is((select count(*)::integer from public.license_application_endorsements),1,'requested endorsement is recorded');
select ok(exists(select 1 from public.outbox_events where event_type='license.application_submitted'),'application emits durable projection work');
select ok(exists(select 1 from public.audit_log where record_type='public.orders' and request_id='fb300000-0000-4000-8000-000000000001'),'assisted order is audited');
select ok(exists(select 1 from public.audit_log where record_type='public.personal_quota_entries'),'quota changes are audited');
select ok(not has_table_privilege('authenticated','public.generated_documents','insert'),'authenticated callers cannot forge document snapshots');

select * from finish();
rollback;
