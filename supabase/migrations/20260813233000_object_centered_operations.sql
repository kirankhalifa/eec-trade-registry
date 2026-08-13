-- Keep the command dashboard focused on human decisions. Worker projections
-- remain available on the dedicated system-health surface.
create or replace function public.get_staff_command_dashboard()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('dashboard.read');
  return jsonb_build_object(
    'generated_at',statement_timestamp(),
    'capabilities',jsonb_build_object(
      'can_manage_access',private.staff_has_permission('access.assignment.manage'),
      'can_review_applications',private.staff_has_permission('license.application.review')),
    'access',jsonb_build_object(
      'requests_pending',case when private.staff_has_permission('access.assignment.manage')
        then (select count(*) from public.staff_access_requests where status='pending') else 0 end),
    'orders',jsonb_build_object(
      'submitted',(select count(*) from public.orders where status='submitted'),
      'under_review',(select count(*) from public.orders where status='under_review'),
      'awaiting_stock',(select count(*) from public.orders where status='awaiting_stock'),
      'processing',(select count(*) from public.orders where status='processing'),
      'direct_this_week',(select count(*) from public.orders where source_channel='direct_individual' and submitted_at>=date_trunc('week',statement_timestamp()))),
    'inventory',jsonb_build_object(
      'critical_reserves',(select count(*) from public.item_supply_policies policy where policy.critical_level is not null and coalesce((
        select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_accounts account on account.id=entry.inventory_account_id
        where entry.item_id=policy.item_id and account.account_kind='physical'),0)<=policy.critical_level),
      'expired_reservations',(select count(*) from public.reservations where status='active' and expires_at<=statement_timestamp()),
      'asset_exceptions',(select count(*) from public.serialized_assets where status in ('missing','damaged','seized'))),
    'licensing',jsonb_build_object(
      'applications_pending',(select count(*) from public.license_applications where status in ('submitted','under_review')),
      'active_licenses',(select count(*) from public.licenses license join public.license_status_definitions status on status.id=license.status_definition_id where status.confers_authority and (license.expires_at is null or license.expires_at>statement_timestamp())),
      'expiring_30_days',(select count(*) from public.licenses where expires_at between statement_timestamp() and statement_timestamp()+interval '30 days')),
    'finance',jsonb_build_object(
      'settlements_pending',(select count(*) from public.consignment_settlements where status='pending'),
      'procurement_payments_pending',(select count(*) from public.procurement_deliveries where settlement_status='pending')),
    'compliance',jsonb_build_object(
      'open_cases',(select count(*) from public.compliance_cases where status not in ('resolved','no_action','closed')),
      'actions_pending',(select count(*) from public.compliance_actions where status='recommended')),
    'integrations',jsonb_build_object(
      'outbox_failed',(select count(*) from public.outbox_events where status='failed'),
      'deliveries_failed',(select count(*) from public.integration_deliveries where status='failed'),
      'exports_failed',(select count(*) from public.export_runs where status='failed')),
    'documents',jsonb_build_object('generated_7_days',(select count(*) from public.generated_documents where generated_at>=statement_timestamp()-interval '7 days')),
    'recent_orders',coalesce((select jsonb_agg(row_data) from (select jsonb_build_object('id',order_item.id,'reference',order_item.public_reference,
      'customer',party.display_name,'channel',order_item.source_channel,'status',order_item.status,'submitted_at',order_item.submitted_at) row_data
      from public.orders order_item join public.parties party on party.id=order_item.ordering_party_id order by order_item.submitted_at desc limit 8) recent),'[]'::jsonb),
    'recent_audit',case when private.staff_has_permission('audit.private.read') then coalesce((select jsonb_agg(row_data) from (
      select jsonb_build_object('id',audit.id,'action',audit.action,'record_type',audit.record_type,'occurred_at',audit.occurred_at,'reason',audit.reason) row_data
      from public.audit_log audit
      where audit.actor_id is not null
        and audit.record_type not in ('public.export_runs','public.integration_deliveries','public.outbox_events')
      order by audit.occurred_at desc limit 12) recent),'[]'::jsonb) else '[]'::jsonb end
  );
end $$;

-- Retire only the original catalogue demonstration goods. The canonical rows
-- remain archived for audit recovery, but players can no longer browse or
-- quote their invented fixture prices as policy.
update public.item_publications as publication
set publication_status = 'withdrawn',
    effective_until = case
      when publication.effective_until is null
        then greatest(publication.effective_from + interval '1 microsecond', statement_timestamp())
      else publication.effective_until
    end
where publication.item_id in (
  select item.id from public.items as item
  where item.item_code in ('EQ-LANTERN-001','EQ-SURVEY-001','MT-FIBER-001','SG-CHRONO-001')
)
and publication.publication_status = 'published';

update public.price_rules as price_rule
set effective_until = greatest(price_rule.effective_from + interval '1 microsecond', statement_timestamp())
where price_rule.item_id in (
  select item.id from public.items as item
  where item.item_code in ('EQ-LANTERN-001','EQ-SURVEY-001','MT-FIBER-001','SG-CHRONO-001')
)
and price_rule.effective_until is null;

update public.items
set status = 'archived'
where item_code in ('EQ-LANTERN-001','EQ-SURVEY-001','MT-FIBER-001','SG-CHRONO-001')
  and status = 'active';
