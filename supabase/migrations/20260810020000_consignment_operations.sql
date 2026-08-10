alter table public.inventory_transactions
  drop constraint inventory_transactions_transaction_type_check;
alter table public.inventory_transactions
  drop constraint inventory_transactions_reversal_shape_check;
alter table public.inventory_transactions
  add constraint inventory_transactions_transaction_type_check
  check (transaction_type in (
    'receipt', 'issue', 'transfer_dispatch', 'transfer_receipt',
    'consignment_issue', 'consignment_settlement', 'reversal'
  ));
alter table public.inventory_transactions
  add constraint inventory_transactions_reversal_shape_check
  check (
    (
      transaction_type in (
        'receipt', 'issue', 'transfer_dispatch', 'transfer_receipt',
        'consignment_issue', 'consignment_settlement'
      )
      and reversal_of_id is null
    )
    or (transaction_type = 'reversal' and reversal_of_id is not null)
  );

create table public.consignment_agreements (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  owner_party_id uuid not null references public.parties(id) on delete restrict,
  consignee_party_id uuid not null references public.parties(id) on delete restrict,
  jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'suspended', 'closed')),
  effective_from timestamptz not null,
  effective_until timestamptz,
  terms_summary text not null default '' check (char_length(terms_summary) <= 4000),
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  status_request_id uuid unique,
  status_reason text,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (owner_party_id <> consignee_party_id),
  check (effective_until is null or effective_until > effective_from),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.consignment_issues (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  agreement_id uuid not null references public.consignment_agreements(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  source_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  source_inventory_account_id uuid not null references public.inventory_accounts(id) on delete restrict,
  consigned_inventory_account_id uuid not null references public.inventory_accounts(id) on delete restrict,
  issue_transaction_id uuid not null unique references public.inventory_transactions(id) on delete restrict,
  quantity_issued numeric(18, 3) not null check (quantity_issued > 0),
  quantity_sold numeric(18, 3) not null default 0 check (quantity_sold >= 0),
  quantity_returned numeric(18, 3) not null default 0 check (quantity_returned >= 0),
  status text not null default 'active' check (status in ('active', 'closed')),
  issued_at timestamptz not null default now(),
  issued_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  issue_reason text not null check (btrim(issue_reason) <> ''),
  source_request_id uuid not null unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (quantity_sold + quantity_returned <= quantity_issued),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.consignment_reports (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  consignment_issue_id uuid not null references public.consignment_issues(id) on delete restrict,
  consignee_party_id uuid not null references public.parties(id) on delete restrict,
  status text not null default 'submitted'
    check (status in ('submitted', 'accepted', 'rejected')),
  quantity_sold numeric(18, 3) not null default 0 check (quantity_sold >= 0),
  quantity_returned numeric(18, 3) not null default 0 check (quantity_returned >= 0),
  quantity_lost numeric(18, 3) not null default 0 check (quantity_lost >= 0),
  quantity_damaged numeric(18, 3) not null default 0 check (quantity_damaged >= 0),
  observed_on_hand numeric(18, 3) not null check (observed_on_hand >= 0),
  report_notes text not null default '' check (char_length(report_notes) <= 4000),
  submitted_at timestamptz not null default now(),
  submitted_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  representation_id uuid not null references public.party_representatives(id) on delete restrict,
  source_request_id uuid not null unique,
  reviewed_at timestamptz,
  reviewed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  review_reason text,
  review_request_id uuid unique,
  settlement_transaction_id uuid unique references public.inventory_transactions(id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'submitted' and reviewed_at is null and reviewed_by_actor_id is null and review_reason is null)
    or (
      status in ('accepted', 'rejected')
      and reviewed_at is not null
      and reviewed_by_actor_id is not null
      and btrim(review_reason) <> ''
    )
  ),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.consignment_events (
  id uuid primary key default extensions.gen_random_uuid(),
  agreement_id uuid not null references public.consignment_agreements(id) on delete restrict,
  consignment_issue_id uuid references public.consignment_issues(id) on delete restrict,
  consignment_report_id uuid references public.consignment_reports(id) on delete restrict,
  event_type text not null check (event_type in (
    'agreement_created', 'agreement_status_changed', 'stock_issued',
    'report_submitted', 'report_accepted', 'report_rejected', 'issue_closed'
  )),
  previous_state jsonb,
  new_state jsonb not null,
  changed_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  represented_party_id uuid references public.parties(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  occurred_at timestamptz not null default now()
);

create index consignment_agreements_party_idx
  on public.consignment_agreements(consignee_party_id, status, effective_from);
create index consignment_issues_agreement_idx
  on public.consignment_issues(agreement_id, status, issued_at desc);
create index consignment_reports_issue_idx
  on public.consignment_reports(consignment_issue_id, status, submitted_at desc);
create unique index consignment_reports_one_submitted_per_issue_idx
  on public.consignment_reports(consignment_issue_id)
  where status = 'submitted';
create index consignment_events_agreement_idx
  on public.consignment_events(agreement_id, occurred_at, id);

create trigger consignment_agreements_set_updated_at
before update on public.consignment_agreements
for each row execute function private.set_updated_at();
create trigger consignment_issues_set_updated_at
before update on public.consignment_issues
for each row execute function private.set_updated_at();
create trigger consignment_reports_set_updated_at
before update on public.consignment_reports
for each row execute function private.set_updated_at();
create trigger consignment_agreements_audit
after insert or update or delete on public.consignment_agreements
for each row execute function private.capture_audit_row();
create trigger consignment_issues_audit
after insert or update or delete on public.consignment_issues
for each row execute function private.capture_audit_row();
create trigger consignment_reports_audit
after insert or update or delete on public.consignment_reports
for each row execute function private.capture_audit_row();
create trigger consignment_events_immutable
before update or delete on public.consignment_events
for each row execute function private.reject_immutable_inventory_change();

alter table public.consignment_agreements enable row level security;
alter table public.consignment_issues enable row level security;
alter table public.consignment_reports enable row level security;
alter table public.consignment_events enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  ('consignment.private.read', 'Read consignments', 'View private agreement, custody, report, and reconciliation records.'),
  ('consignment.agreement.manage', 'Manage consignment agreements', 'Create and change policy-neutral consignment agreements.'),
  ('consignment.issue', 'Issue consigned stock', 'Move available fungible stock into consignee custody while retaining ownership.'),
  ('consignment.report.accept', 'Review consignment reports', 'Accept or reject dealer-submitted consignment observations.'),
  ('consignment.return', 'Receive consignment returns', 'Post accepted returns into an authorized warehouse location.');

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'inventory_controller' and permission.code like 'consignment.%'
) or (
  role.code = 'warehouse_operator'
  and permission.code in ('consignment.private.read', 'consignment.issue', 'consignment.return')
) or (
  role.code = 'order_officer'
  and permission.code in (
    'consignment.private.read', 'consignment.agreement.manage', 'consignment.report.accept'
  )
);

update public.representative_role_definitions
set default_scope = default_scope || jsonb_build_object(
  'consignment.read', true,
  'consignment.report', true
)
where code = 'portal-representative';

update public.party_representatives as representative
set authority_scope = representative.authority_scope || jsonb_build_object(
  'consignment.read', true,
  'consignment.report', true
)
from public.representative_role_definitions as role_definition
where role_definition.id = representative.role_definition_id
  and role_definition.code = 'portal-representative';

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values
  ('consignment_agreement', 'EEC-CAG', 1001, 4),
  ('consignment_issue', 'EEC-CIS', 1001, 4),
  ('consignment_report', 'EEC-CRP', 1001, 4);

create function private.allocate_consignment_reference(p_document_type text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare sequence_record record; allocated_reference text;
begin
  if p_document_type not in ('consignment_agreement', 'consignment_issue', 'consignment_report') then
    raise exception using errcode = '22023', message = 'consignment_reference_type_invalid';
  end if;
  select reference.prefix, reference.next_value, reference.padding
  into strict sequence_record
  from public.reference_sequences as reference
  where reference.document_type = p_document_type and reference.active
  for update;
  allocated_reference := sequence_record.prefix || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');
  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = p_document_type;
  return allocated_reference;
exception when no_data_found then
  raise exception using errcode = '55000', message = 'consignment_reference_sequence_unavailable';
end;
$$;

create function public.get_staff_consignment_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.staff_has_permission('consignment.private.read') then
    raise exception using errcode = '42501', message = 'staff_permission_denied';
  end if;
  return jsonb_build_object(
    'capabilities', jsonb_build_object(
      'can_manage_agreements', private.staff_has_permission('consignment.agreement.manage'),
      'can_issue', private.staff_has_permission('consignment.issue'),
      'can_review', private.staff_has_permission('consignment.report.accept'),
      'can_receive_returns', private.staff_has_permission('consignment.return')
    ),
    'owners', coalesce((
      select jsonb_agg(distinct jsonb_build_object(
        'id', warehouse.operating_party_id, 'display_name', party.display_name
      ))
      from public.warehouses as warehouse
      join public.parties as party on party.id = warehouse.operating_party_id
      where warehouse.status = 'active'
    ), '[]'::jsonb),
    'consignees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', party.id, 'display_name', party.display_name
      ) order by party.display_name)
      from public.parties as party
      where party.status = 'active' and exists (
        select 1 from public.dealer_authorizations as dealer
        join public.dealer_status_definitions as status on status.id = dealer.status_definition_id
          and status.confers_authority
        where dealer.dealer_party_id = party.id
          and dealer.effective_from <= statement_timestamp()
          and (dealer.effective_until is null or dealer.effective_until > statement_timestamp())
      )
    ), '[]'::jsonb),
    'jurisdictions', coalesce((
      select jsonb_agg(jsonb_build_object('id', jurisdiction.id, 'display_name', jurisdiction.public_name)
        order by jurisdiction.public_name)
      from public.jurisdictions as jurisdiction where jurisdiction.status = 'active'
    ), '[]'::jsonb),
    'source_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', account.id, 'item_id', item.id, 'item_code', item.item_code,
        'item_name', item.display_name, 'owner_party_id', account.owner_party_id,
        'warehouse_id', warehouse.id, 'warehouse_name', warehouse.display_name,
        'location_name', location.display_name,
        'available', position.on_hand - position.reserved
      ) order by warehouse.display_name, location.display_name, item.display_name)
      from public.inventory_accounts as account
      join public.items as item on item.id = account.item_id and item.inventory_mode = 'fungible'
      join public.warehouses as warehouse on warehouse.id = account.warehouse_id
      join public.stock_locations as location on location.id = account.stock_location_id
      cross join lateral (
        select
          coalesce((select sum(entry.quantity_delta) from public.inventory_ledger_entries as entry
            where entry.inventory_account_id = account.id), 0) as on_hand,
          coalesce((select sum(reservation.quantity) from public.reservations as reservation
            where reservation.inventory_account_id = account.id and reservation.status = 'active'
              and reservation.expires_at > statement_timestamp()), 0) as reserved
      ) as position
      where account.account_kind = 'physical' and account.stock_state = 'available'
        and account.status = 'active'
        and exists (select 1 from private.current_staff_warehouse_assignments(
          'consignment.issue', account.warehouse_id))
    ), '[]'::jsonb),
    'return_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', account.id, 'item_id', item.id, 'item_code', item.item_code,
        'owner_party_id', account.owner_party_id, 'warehouse_id', warehouse.id,
        'warehouse_name', warehouse.display_name, 'location_name', location.display_name
      ) order by warehouse.display_name, location.display_name, item.display_name)
      from public.inventory_accounts as account
      join public.items as item on item.id = account.item_id
      join public.warehouses as warehouse on warehouse.id = account.warehouse_id
      join public.stock_locations as location on location.id = account.stock_location_id
      where account.account_kind = 'physical' and account.stock_state = 'available'
        and account.status = 'active'
        and exists (select 1 from private.current_staff_warehouse_assignments(
          'consignment.return', account.warehouse_id))
    ), '[]'::jsonb),
    'agreements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', agreement.id, 'public_reference', agreement.public_reference,
        'version', agreement.version, 'status', agreement.status,
        'owner_party_id', agreement.owner_party_id, 'owner_name', owner.display_name,
        'consignee_party_id', agreement.consignee_party_id,
        'consignee_name', consignee.display_name,
        'jurisdiction_name', jurisdiction.public_name,
        'effective_from', agreement.effective_from,
        'effective_until', agreement.effective_until,
        'terms_summary', agreement.terms_summary
      ) order by agreement.created_at desc)
      from public.consignment_agreements as agreement
      join public.parties as owner on owner.id = agreement.owner_party_id
      join public.parties as consignee on consignee.id = agreement.consignee_party_id
      join public.jurisdictions as jurisdiction on jurisdiction.id = agreement.jurisdiction_id
    ), '[]'::jsonb),
    'issues', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', issue.id, 'public_reference', issue.public_reference,
        'version', issue.version, 'status', issue.status,
        'agreement_id', issue.agreement_id,
        'agreement_reference', agreement.public_reference,
        'item_id', issue.item_id, 'item_code', item.item_code, 'item_name', item.display_name,
        'consignee_name', consignee.display_name,
        'quantity_issued', issue.quantity_issued,
        'quantity_sold', issue.quantity_sold,
        'quantity_returned', issue.quantity_returned,
        'quantity_outstanding', issue.quantity_issued - issue.quantity_sold - issue.quantity_returned,
        'issued_at', issue.issued_at
      ) order by issue.issued_at desc)
      from public.consignment_issues as issue
      join public.consignment_agreements as agreement on agreement.id = issue.agreement_id
      join public.items as item on item.id = issue.item_id
      join public.parties as consignee on consignee.id = agreement.consignee_party_id
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', report.id, 'public_reference', report.public_reference,
        'version', report.version, 'status', report.status,
        'consignment_issue_id', report.consignment_issue_id,
        'issue_reference', issue.public_reference,
        'item_id', issue.item_id, 'item_code', item.item_code,
        'consignee_name', consignee.display_name,
        'quantity_sold', report.quantity_sold,
        'quantity_returned', report.quantity_returned,
        'quantity_lost', report.quantity_lost,
        'quantity_damaged', report.quantity_damaged,
        'observed_on_hand', report.observed_on_hand,
        'report_notes', report.report_notes,
        'submitted_at', report.submitted_at
      ) order by report.submitted_at desc)
      from public.consignment_reports as report
      join public.consignment_issues as issue on issue.id = report.consignment_issue_id
      join public.consignment_agreements as agreement on agreement.id = issue.agreement_id
      join public.items as item on item.id = issue.item_id
      join public.parties as consignee on consignee.id = agreement.consignee_party_id
    ), '[]'::jsonb)
  );
end;
$$;

create function public.staff_create_consignment_agreement(
  p_owner_party_id uuid,
  p_consignee_party_id uuid,
  p_jurisdiction_id uuid,
  p_effective_from timestamptz,
  p_effective_until timestamptz,
  p_terms_summary text,
  p_reason text,
  p_request_id uuid
)
returns table (agreement_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; existing_record record; created_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('consignment.agreement.manage', p_reason, p_request_id);
  select agreement.id, agreement.public_reference, agreement.version, agreement.status
  into existing_record from public.consignment_agreements as agreement
  where agreement.source_request_id = p_request_id;
  if found then
    return query select existing_record.id, existing_record.public_reference,
      existing_record.version, existing_record.status;
    return;
  end if;
  if p_owner_party_id = p_consignee_party_id
    or p_effective_from is null
    or (p_effective_until is not null and p_effective_until <= p_effective_from)
    or char_length(coalesce(p_terms_summary, '')) > 4000
  then raise exception using errcode = '22023', message = 'consignment_agreement_invalid'; end if;
  if not exists (select 1 from public.warehouses as warehouse
    where warehouse.operating_party_id = p_owner_party_id and warehouse.status = 'active')
  then raise exception using errcode = '22023', message = 'consignment_owner_invalid'; end if;
  if not exists (
    select 1 from public.dealer_authorizations as dealer
    join public.dealer_status_definitions as status on status.id = dealer.status_definition_id
      and status.confers_authority
    where dealer.dealer_party_id = p_consignee_party_id
      and dealer.effective_from <= statement_timestamp()
      and (dealer.effective_until is null or dealer.effective_until > statement_timestamp())
  ) then raise exception using errcode = '22023', message = 'consignment_consignee_invalid'; end if;
  if not exists (select 1 from public.jurisdictions as jurisdiction
    where jurisdiction.id = p_jurisdiction_id and jurisdiction.status = 'active')
  then raise exception using errcode = 'P0002', message = 'jurisdiction_not_found'; end if;
  created_reference := private.allocate_consignment_reference('consignment_agreement');
  insert into public.consignment_agreements (
    public_reference, owner_party_id, consignee_party_id, jurisdiction_id,
    effective_from, effective_until, terms_summary, created_by_actor_id, source_request_id
  ) values (
    created_reference, p_owner_party_id, p_consignee_party_id, p_jurisdiction_id,
    p_effective_from, p_effective_until, coalesce(p_terms_summary, ''), actor_id, p_request_id
  ) returning id into created_id;
  insert into public.consignment_events (
    agreement_id, event_type, new_state, changed_by_actor_id, reason, request_id
  ) values (
    created_id, 'agreement_created',
    jsonb_build_object('status', 'active', 'owner_party_id', p_owner_party_id,
      'consignee_party_id', p_consignee_party_id),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'consignment.agreement_created', 'consignment_agreement', created_id,
    jsonb_build_object('public_reference', created_reference,
      'consignee_party_id', p_consignee_party_id),
    'consignment.agreement_created:' || p_request_id::text
  );
  return query select created_id, created_reference, 1::bigint, 'active'::text;
end;
$$;

create function public.staff_change_consignment_agreement_status(
  p_agreement_id uuid,
  p_expected_version bigint,
  p_status text,
  p_reason text,
  p_request_id uuid
)
returns table (agreement_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; agreement_record record; previous_status text;
begin
  actor_id := private.set_staff_audit_context('consignment.agreement.manage', p_reason, p_request_id);
  select agreement.* into agreement_record from public.consignment_agreements as agreement
  where agreement.id = p_agreement_id;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_agreement_not_found'; end if;
  if agreement_record.status_request_id = p_request_id then
    return query select agreement_record.id, agreement_record.version, agreement_record.status;
    return;
  end if;
  select agreement.* into agreement_record from public.consignment_agreements as agreement
  where agreement.id = p_agreement_id for update;
  if agreement_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'consignment_agreement_version_conflict';
  end if;
  previous_status := agreement_record.status;
  if not (
    (previous_status = 'active' and p_status in ('suspended', 'closed'))
    or (previous_status = 'suspended' and p_status in ('active', 'closed'))
  ) then raise exception using errcode = '22023', message = 'consignment_agreement_transition_invalid'; end if;
  if p_status = 'closed' and exists (
    select 1 from public.consignment_issues as issue
    where issue.agreement_id = p_agreement_id
      and issue.quantity_issued > issue.quantity_sold + issue.quantity_returned
  ) then raise exception using errcode = '22023', message = 'consignment_agreement_has_outstanding_custody'; end if;
  update public.consignment_agreements as agreement set
    status = p_status, status_request_id = p_request_id,
    status_reason = btrim(p_reason), version = agreement.version + 1
  where agreement.id = p_agreement_id returning agreement.* into agreement_record;
  insert into public.consignment_events (
    agreement_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    agreement_record.id, 'agreement_status_changed',
    jsonb_build_object('status', previous_status), jsonb_build_object('status', p_status),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select agreement_record.id, agreement_record.version, agreement_record.status;
end;
$$;

create function public.staff_issue_consignment_stock(
  p_agreement_id uuid,
  p_source_inventory_account_id uuid,
  p_quantity numeric,
  p_reason text,
  p_request_id uuid
)
returns table (consignment_issue_id uuid, public_reference text, version bigint, status text, inventory_transaction_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; agreement_record record; account_record record;
  existing_record record; consigned_account_id uuid; transaction_id uuid;
  created_id uuid; created_reference text; on_hand numeric(18,3); reserved numeric(18,3);
begin
  select account.id, account.item_id, account.owner_party_id, account.custodian_party_id,
    account.warehouse_id, account.account_kind, account.stock_state, account.status,
    item.inventory_mode
  into account_record
  from public.inventory_accounts as account
  join public.items as item on item.id = account.item_id
  where account.id = p_source_inventory_account_id;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_source_account_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'consignment.issue', account_record.warehouse_id, p_reason, p_request_id
  );
  select issue.id, issue.public_reference, issue.version, issue.status, issue.issue_transaction_id
  into existing_record from public.consignment_issues as issue
  where issue.source_request_id = p_request_id;
  if found then
    return query select existing_record.id, existing_record.public_reference,
      existing_record.version, existing_record.status, existing_record.issue_transaction_id;
    return;
  end if;
  if p_quantity is null or p_quantity <= 0
    or account_record.account_kind <> 'physical'
    or account_record.stock_state <> 'available'
    or account_record.status <> 'active'
    or account_record.inventory_mode <> 'fungible'
  then raise exception using errcode = '22023', message = 'consignment_issue_invalid'; end if;
  select agreement.* into agreement_record from public.consignment_agreements as agreement
  where agreement.id = p_agreement_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_agreement_not_found'; end if;
  if agreement_record.status <> 'active'
    or agreement_record.effective_from > statement_timestamp()
    or (agreement_record.effective_until is not null and agreement_record.effective_until <= statement_timestamp())
    or agreement_record.owner_party_id <> account_record.owner_party_id
  then raise exception using errcode = '22023', message = 'consignment_agreement_not_issuable'; end if;
  insert into public.inventory_accounts (
    item_id, account_kind, owner_party_id, custodian_party_id, stock_state
  ) values (
    account_record.item_id, 'custody', agreement_record.owner_party_id,
    agreement_record.consignee_party_id, 'consigned'
  ) on conflict (item_id, owner_party_id, custodian_party_id, stock_state)
    where account_kind = 'custody' do nothing;
  select account.id into strict consigned_account_id
  from public.inventory_accounts as account
  where account.account_kind = 'custody' and account.item_id = account_record.item_id
    and account.owner_party_id = agreement_record.owner_party_id
    and account.custodian_party_id = agreement_record.consignee_party_id
    and account.stock_state = 'consigned';
  perform 1 from public.inventory_accounts as account
  where account.id in (p_source_inventory_account_id, consigned_account_id)
  order by account.id for update;
  select coalesce(sum(entry.quantity_delta), 0) into on_hand
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = p_source_inventory_account_id;
  select coalesce(sum(reservation.quantity), 0) into reserved
  from public.reservations as reservation
  where reservation.inventory_account_id = p_source_inventory_account_id
    and reservation.status = 'active' and reservation.expires_at > statement_timestamp();
  if on_hand - reserved < p_quantity then
    raise exception using errcode = '23514', message = 'consignment_stock_unavailable';
  end if;
  insert into public.inventory_transactions (
    transaction_type, occurred_at, posted_by_actor_id, permission_code,
    source_reference, reason, request_id
  ) values (
    'consignment_issue', statement_timestamp(), actor_id, 'consignment.issue',
    agreement_record.public_reference, btrim(p_reason), p_request_id
  ) returning id into transaction_id;
  insert into public.inventory_ledger_entries (
    inventory_transaction_id, line_number, inventory_account_id, item_id, quantity_delta
  ) values
    (transaction_id, 1, p_source_inventory_account_id, account_record.item_id, -p_quantity),
    (transaction_id, 2, consigned_account_id, account_record.item_id, p_quantity);
  created_reference := private.allocate_consignment_reference('consignment_issue');
  insert into public.consignment_issues (
    public_reference, agreement_id, item_id, source_warehouse_id,
    source_inventory_account_id, consigned_inventory_account_id,
    issue_transaction_id, quantity_issued, issued_by_actor_id,
    issue_reason, source_request_id
  ) values (
    created_reference, agreement_record.id, account_record.item_id,
    account_record.warehouse_id, p_source_inventory_account_id,
    consigned_account_id, transaction_id, p_quantity, actor_id,
    btrim(p_reason), p_request_id
  ) returning id into created_id;
  insert into public.consignment_events (
    agreement_id, consignment_issue_id, event_type, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    agreement_record.id, created_id, 'stock_issued',
    jsonb_build_object('status', 'active', 'quantity_issued', p_quantity,
      'owner_party_id', agreement_record.owner_party_id,
      'custodian_party_id', agreement_record.consignee_party_id,
      'inventory_transaction_id', transaction_id),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'consignment.stock_issued', 'consignment_issue', created_id,
    jsonb_build_object('public_reference', created_reference, 'quantity', p_quantity,
      'consignee_party_id', agreement_record.consignee_party_id),
    'consignment.stock_issued:' || p_request_id::text
  );
  return query select created_id, created_reference, 1::bigint, 'active'::text, transaction_id;
end;
$$;

create function public.get_dealer_consignments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from private.current_dealer_representations('consignment.read')) then
    raise exception using errcode = '42501', message = 'dealer_scope_denied';
  end if;
  return jsonb_build_object('issues', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', issue.id, 'public_reference', issue.public_reference,
      'agreement_reference', agreement.public_reference,
      'consignee_party_id', agreement.consignee_party_id,
      'consignee_name', consignee.display_name,
      'item_code', item.item_code, 'item_name', item.display_name,
      'quantity_issued', issue.quantity_issued,
      'quantity_sold', issue.quantity_sold,
      'quantity_returned', issue.quantity_returned,
      'quantity_outstanding', issue.quantity_issued - issue.quantity_sold - issue.quantity_returned,
      'status', issue.status, 'version', issue.version,
      'issued_at', issue.issued_at,
      'reports', coalesce((select jsonb_agg(jsonb_build_object(
        'public_reference', report.public_reference, 'status', report.status,
        'quantity_sold', report.quantity_sold, 'quantity_returned', report.quantity_returned,
        'quantity_lost', report.quantity_lost, 'quantity_damaged', report.quantity_damaged,
        'observed_on_hand', report.observed_on_hand, 'submitted_at', report.submitted_at
      ) order by report.submitted_at desc) from public.consignment_reports as report
        where report.consignment_issue_id = issue.id), '[]'::jsonb)
    ) order by issue.issued_at desc)
    from public.consignment_issues as issue
    join public.consignment_agreements as agreement on agreement.id = issue.agreement_id
    join public.parties as consignee on consignee.id = agreement.consignee_party_id
    join public.items as item on item.id = issue.item_id
    where exists (select 1 from private.current_dealer_representations('consignment.read') as grant_record
      where grant_record.principal_party_id = agreement.consignee_party_id)
  ), '[]'::jsonb));
end;
$$;

create function public.dealer_submit_consignment_report(
  p_consignment_issue_id uuid,
  p_quantity_sold numeric,
  p_quantity_returned numeric,
  p_quantity_lost numeric,
  p_quantity_damaged numeric,
  p_observed_on_hand numeric,
  p_report_notes text,
  p_reason text,
  p_request_id uuid
)
returns table (consignment_report_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare issue_record record; audit_record record; existing_record record;
  created_id uuid; created_reference text; current_outstanding numeric(18,3);
begin
  select issue.*, agreement.consignee_party_id, agreement.status as agreement_status
  into issue_record
  from public.consignment_issues as issue
  join public.consignment_agreements as agreement on agreement.id = issue.agreement_id
  where issue.id = p_consignment_issue_id;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_issue_not_found'; end if;
  select * into audit_record from private.set_dealer_audit_context(
    issue_record.consignee_party_id, 'consignment.report', p_reason, p_request_id
  );
  select report.id, report.public_reference, report.version, report.status
  into existing_record from public.consignment_reports as report
  where report.source_request_id = p_request_id;
  if found then
    return query select existing_record.id, existing_record.public_reference,
      existing_record.version, existing_record.status;
    return;
  end if;
  current_outstanding := issue_record.quantity_issued
    - issue_record.quantity_sold - issue_record.quantity_returned;
  if issue_record.status <> 'active' or issue_record.agreement_status = 'closed'
    or p_quantity_sold is null or p_quantity_sold < 0
    or p_quantity_returned is null or p_quantity_returned < 0
    or p_quantity_lost is null or p_quantity_lost < 0
    or p_quantity_damaged is null or p_quantity_damaged < 0
    or p_observed_on_hand is null or p_observed_on_hand < 0
    or p_quantity_sold + p_quantity_returned + p_quantity_lost + p_quantity_damaged > current_outstanding
    or char_length(coalesce(p_report_notes, '')) > 4000
  then raise exception using errcode = '22023', message = 'consignment_report_invalid'; end if;
  if exists (select 1 from public.consignment_reports as report
    where report.consignment_issue_id = p_consignment_issue_id and report.status = 'submitted')
  then raise exception using errcode = '23505', message = 'consignment_report_already_pending'; end if;
  created_reference := private.allocate_consignment_reference('consignment_report');
  insert into public.consignment_reports (
    public_reference, consignment_issue_id, consignee_party_id,
    quantity_sold, quantity_returned, quantity_lost, quantity_damaged,
    observed_on_hand, report_notes, submitted_by_actor_id, representation_id,
    source_request_id
  ) values (
    created_reference, issue_record.id, issue_record.consignee_party_id,
    p_quantity_sold, p_quantity_returned, p_quantity_lost, p_quantity_damaged,
    p_observed_on_hand, coalesce(p_report_notes, ''), audit_record.actor_id,
    audit_record.representation_id, p_request_id
  ) returning id into created_id;
  insert into public.consignment_events (
    agreement_id, consignment_issue_id, consignment_report_id,
    event_type, new_state, changed_by_actor_id, represented_party_id,
    reason, request_id
  ) values (
    issue_record.agreement_id, issue_record.id, created_id, 'report_submitted',
    jsonb_build_object('status', 'submitted', 'quantity_sold', p_quantity_sold,
      'quantity_returned', p_quantity_returned, 'quantity_lost', p_quantity_lost,
      'quantity_damaged', p_quantity_damaged, 'observed_on_hand', p_observed_on_hand),
    audit_record.actor_id, issue_record.consignee_party_id,
    btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'consignment.report_submitted', 'consignment_report', created_id,
    jsonb_build_object('public_reference', created_reference,
      'issue_reference', issue_record.public_reference,
      'consignee_party_id', issue_record.consignee_party_id),
    'consignment.report_submitted:' || p_request_id::text
  );
  return query select created_id, created_reference, 1::bigint, 'submitted'::text;
end;
$$;

create function public.staff_accept_consignment_report(
  p_consignment_report_id uuid,
  p_expected_version bigint,
  p_return_inventory_account_id uuid,
  p_reason text,
  p_request_id uuid
)
returns table (consignment_report_id uuid, report_version bigint, issue_version bigint, report_status text, issue_status text, inventory_transaction_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; report_record record; issue_record record; agreement_record record;
  return_account record; external_account_id uuid; transaction_id uuid;
  consigned_on_hand numeric(18,3); expected_observed numeric(18,3);
  next_issue_status text; next_issue_version bigint;
begin
  actor_id := private.set_staff_audit_context('consignment.report.accept', p_reason, p_request_id);
  select report.* into report_record from public.consignment_reports as report
  where report.id = p_consignment_report_id;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_report_not_found'; end if;
  if report_record.review_request_id = p_request_id then
    select issue.version, issue.status into strict next_issue_version, next_issue_status
    from public.consignment_issues as issue where issue.id = report_record.consignment_issue_id;
    return query select report_record.id, report_record.version, next_issue_version,
      report_record.status, next_issue_status, report_record.settlement_transaction_id;
    return;
  end if;
  select report.* into report_record from public.consignment_reports as report
  where report.id = p_consignment_report_id for update;
  select issue.* into issue_record from public.consignment_issues as issue
  where issue.id = report_record.consignment_issue_id for update;
  select agreement.* into strict agreement_record from public.consignment_agreements as agreement
  where agreement.id = issue_record.agreement_id for update;
  if report_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'consignment_report_version_conflict';
  end if;
  if report_record.status <> 'submitted' or issue_record.status <> 'active' then
    raise exception using errcode = '22023', message = 'consignment_report_not_acceptable';
  end if;
  if report_record.quantity_lost > 0 or report_record.quantity_damaged > 0 then
    raise exception using errcode = '22023', message = 'consignment_report_requires_exception_review';
  end if;
  expected_observed := issue_record.quantity_issued - issue_record.quantity_sold
    - issue_record.quantity_returned - report_record.quantity_sold - report_record.quantity_returned;
  if report_record.observed_on_hand <> expected_observed then
    raise exception using errcode = '22023', message = 'consignment_observation_mismatch';
  end if;
  if report_record.quantity_returned > 0 then
    select account.id, account.item_id, account.owner_party_id,
      account.custodian_party_id, account.warehouse_id,
      account.account_kind, account.stock_state, account.status
    into return_account from public.inventory_accounts as account
    where account.id = p_return_inventory_account_id;
    if not found or return_account.item_id <> issue_record.item_id
      or return_account.owner_party_id <> agreement_record.owner_party_id
      or return_account.custodian_party_id <> agreement_record.owner_party_id
      or return_account.account_kind <> 'physical'
      or return_account.stock_state <> 'available'
      or return_account.status <> 'active'
      or not exists (select 1 from private.current_staff_warehouse_assignments(
        'consignment.return', return_account.warehouse_id))
    then raise exception using errcode = '42501', message = 'consignment_return_destination_denied'; end if;
  elsif p_return_inventory_account_id is not null then
    raise exception using errcode = '22023', message = 'consignment_return_destination_unexpected';
  end if;
  if report_record.quantity_sold + report_record.quantity_returned > 0 then
    if report_record.quantity_sold > 0 then
      insert into public.inventory_accounts (item_id, account_kind, stock_state)
      values (issue_record.item_id, 'external', 'external_source')
      on conflict (item_id) where account_kind = 'external' do nothing;
      select account.id into strict external_account_id from public.inventory_accounts as account
      where account.item_id = issue_record.item_id and account.account_kind = 'external';
    end if;
    perform 1 from public.inventory_accounts as account
    where account.id in (
      issue_record.consigned_inventory_account_id,
      coalesce(external_account_id, issue_record.consigned_inventory_account_id),
      coalesce(p_return_inventory_account_id, issue_record.consigned_inventory_account_id)
    ) order by account.id for update;
    select coalesce(sum(entry.quantity_delta), 0) into consigned_on_hand
    from public.inventory_ledger_entries as entry
    where entry.inventory_account_id = issue_record.consigned_inventory_account_id;
    if consigned_on_hand < report_record.quantity_sold + report_record.quantity_returned then
      raise exception using errcode = '23514', message = 'consignment_custody_stock_insufficient';
    end if;
    insert into public.inventory_transactions (
      transaction_type, occurred_at, posted_by_actor_id, permission_code,
      source_reference, reason, request_id
    ) values (
      'consignment_settlement', statement_timestamp(), actor_id,
      'consignment.report.accept', report_record.public_reference,
      btrim(p_reason), p_request_id
    ) returning id into transaction_id;
    insert into public.inventory_ledger_entries (
      inventory_transaction_id, line_number, inventory_account_id, item_id, quantity_delta
    )
    select
      transaction_id,
      movement.line_number,
      movement.inventory_account_id,
      issue_record.item_id,
      movement.quantity_delta
    from (
      values
        (
          1,
          issue_record.consigned_inventory_account_id,
          -(report_record.quantity_sold + report_record.quantity_returned)
        ),
        (2, external_account_id, report_record.quantity_sold),
        (3, p_return_inventory_account_id, report_record.quantity_returned)
    ) as movement(line_number, inventory_account_id, quantity_delta)
    where movement.quantity_delta <> 0;
  end if;
  next_issue_status := case when expected_observed = 0 then 'closed' else 'active' end;
  update public.consignment_reports as report set
    status = 'accepted', reviewed_at = statement_timestamp(),
    reviewed_by_actor_id = actor_id, review_reason = btrim(p_reason),
    review_request_id = p_request_id, settlement_transaction_id = transaction_id,
    version = report.version + 1
  where report.id = report_record.id returning report.* into report_record;
  update public.consignment_issues as issue set
    quantity_sold = issue.quantity_sold + report_record.quantity_sold,
    quantity_returned = issue.quantity_returned + report_record.quantity_returned,
    status = next_issue_status, version = issue.version + 1
  where issue.id = issue_record.id returning issue.version into next_issue_version;
  insert into public.consignment_events (
    agreement_id, consignment_issue_id, consignment_report_id,
    event_type, previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    agreement_record.id, issue_record.id, report_record.id, 'report_accepted',
    jsonb_build_object('report_status', 'submitted', 'issue_status', issue_record.status),
    jsonb_build_object('report_status', 'accepted', 'issue_status', next_issue_status,
      'quantity_sold', report_record.quantity_sold,
      'quantity_returned', report_record.quantity_returned,
      'inventory_transaction_id', transaction_id),
    actor_id, btrim(p_reason), p_request_id
  );
  if next_issue_status = 'closed' then
    insert into public.consignment_events (
      agreement_id, consignment_issue_id, event_type, previous_state, new_state,
      changed_by_actor_id, reason, request_id
    ) values (
      agreement_record.id, issue_record.id, 'issue_closed',
      jsonb_build_object('status', 'active'), jsonb_build_object('status', 'closed'),
      actor_id, btrim(p_reason), extensions.gen_random_uuid()
    );
  end if;
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'consignment.report_accepted', 'consignment_report', report_record.id,
    jsonb_build_object('public_reference', report_record.public_reference,
      'issue_reference', issue_record.public_reference,
      'quantity_sold', report_record.quantity_sold,
      'quantity_returned', report_record.quantity_returned,
      'issue_status', next_issue_status),
    'consignment.report_accepted:' || p_request_id::text
  );
  return query select report_record.id, report_record.version, next_issue_version,
    report_record.status, next_issue_status, transaction_id;
end;
$$;

create function public.staff_reject_consignment_report(
  p_consignment_report_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (consignment_report_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; report_record record; issue_record record;
begin
  actor_id := private.set_staff_audit_context('consignment.report.accept', p_reason, p_request_id);
  select report.* into report_record from public.consignment_reports as report
  where report.id = p_consignment_report_id;
  if not found then raise exception using errcode = 'P0002', message = 'consignment_report_not_found'; end if;
  if report_record.review_request_id = p_request_id then
    return query select report_record.id, report_record.version, report_record.status;
    return;
  end if;
  select report.* into report_record from public.consignment_reports as report
  where report.id = p_consignment_report_id for update;
  if report_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'consignment_report_version_conflict';
  end if;
  if report_record.status <> 'submitted' then
    raise exception using errcode = '22023', message = 'consignment_report_not_reviewable';
  end if;
  select issue.* into strict issue_record from public.consignment_issues as issue
  where issue.id = report_record.consignment_issue_id;
  update public.consignment_reports as report set
    status = 'rejected', reviewed_at = statement_timestamp(),
    reviewed_by_actor_id = actor_id, review_reason = btrim(p_reason),
    review_request_id = p_request_id, version = report.version + 1
  where report.id = report_record.id returning report.* into report_record;
  insert into public.consignment_events (
    agreement_id, consignment_issue_id, consignment_report_id,
    event_type, previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    issue_record.agreement_id, issue_record.id, report_record.id, 'report_rejected',
    jsonb_build_object('status', 'submitted'), jsonb_build_object('status', 'rejected'),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select report_record.id, report_record.version, report_record.status;
end;
$$;

insert into public.notification_templates (
  code, event_type, destination_type, message_template
)
values
  ('staff-consignment-agreement-v1', 'consignment.agreement_created', 'discord_channel', 'Consignment agreement {{public_reference}} was created.'),
  ('staff-consignment-issued-v1', 'consignment.stock_issued', 'discord_channel', 'Consignment {{public_reference}} issued {{quantity}} units.'),
  ('staff-consignment-report-v1', 'consignment.report_submitted', 'discord_channel', 'Consignment report {{public_reference}} requires review.'),
  ('staff-consignment-accepted-v1', 'consignment.report_accepted', 'discord_channel', 'Consignment report {{public_reference}} was accepted.');

insert into public.integration_event_routes (
  event_type, destination_id, notification_template_id, active
)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type in (
  'consignment.agreement_created', 'consignment.stock_issued',
  'consignment.report_submitted', 'consignment.report_accepted'
);

revoke all on public.consignment_agreements from anon, authenticated;
revoke all on public.consignment_issues from anon, authenticated;
revoke all on public.consignment_reports from anon, authenticated;
revoke all on public.consignment_events from anon, authenticated;
revoke all on function private.allocate_consignment_reference(text) from public, anon, authenticated;
revoke all on function public.get_staff_consignment_workspace() from public, anon;
revoke all on function public.staff_create_consignment_agreement(uuid,uuid,uuid,timestamptz,timestamptz,text,text,uuid) from public, anon;
revoke all on function public.staff_change_consignment_agreement_status(uuid,bigint,text,text,uuid) from public, anon;
revoke all on function public.staff_issue_consignment_stock(uuid,uuid,numeric,text,uuid) from public, anon;
revoke all on function public.get_dealer_consignments() from public, anon;
revoke all on function public.dealer_submit_consignment_report(uuid,numeric,numeric,numeric,numeric,numeric,text,text,uuid) from public, anon;
revoke all on function public.staff_accept_consignment_report(uuid,bigint,uuid,text,uuid) from public, anon;
revoke all on function public.staff_reject_consignment_report(uuid,bigint,text,uuid) from public, anon;
grant execute on function public.get_staff_consignment_workspace() to authenticated;
grant execute on function public.staff_create_consignment_agreement(uuid,uuid,uuid,timestamptz,timestamptz,text,text,uuid) to authenticated;
grant execute on function public.staff_change_consignment_agreement_status(uuid,bigint,text,text,uuid) to authenticated;
grant execute on function public.staff_issue_consignment_stock(uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.get_dealer_consignments() to authenticated;
grant execute on function public.dealer_submit_consignment_report(uuid,numeric,numeric,numeric,numeric,numeric,text,text,uuid) to authenticated;
grant execute on function public.staff_accept_consignment_report(uuid,bigint,uuid,text,uuid) to authenticated;
grant execute on function public.staff_reject_consignment_report(uuid,bigint,text,uuid) to authenticated;
