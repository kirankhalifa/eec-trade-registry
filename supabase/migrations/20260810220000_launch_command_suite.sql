-- Launch command suite: assisted trade, direct premium orders, applications,
-- settlement, serialized fulfillment, executable sanctions, documents, and dashboard.

insert into public.permission_scopes (code, display_name, description)
values
  ('dashboard.read', 'Read command dashboard', 'View the cross-domain operating summary and launch queues.'),
  ('order.assisted.create', 'Create assisted orders', 'Enter verified-business and direct-individual orders for customers.'),
  ('pricing.binding.manage', 'Manage price precedence', 'Configure effective-dated dealer, class, type, jurisdiction, and channel price bindings.'),
  ('license.application.review', 'Review license applications', 'Review public applications and issue or renew authority from an approved application.'),
  ('consignment.finance.manage', 'Manage consignment finance', 'Configure commissions, create settlements, and record payment evidence.'),
  ('asset.fulfill', 'Fulfill unique assets', 'Consume an exclusive asset reservation and transfer custody to the ordering party.'),
  ('compliance.effect.apply', 'Apply compliance effects', 'Approve configured cross-domain sanctions and atomically apply their effects.'),
  ('document.generate', 'Generate official documents', 'Create immutable source snapshots for official PDF projections.'),
  ('document.private.read', 'Read generated documents', 'Read generated-document snapshots and download their PDF projections.');

insert into public.staff_roles (code, display_name, description, is_elevated)
values ('finance_officer', 'Finance officer', 'Manages consignment commission terms, settlement amounts, and payment evidence.', true);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles role
cross join public.permission_scopes permission
where
  (role.code = 'platform_administrator')
  or (role.code = 'order_officer' and permission.code in ('dashboard.read','order.assisted.create','document.generate','document.private.read'))
  or (role.code = 'catalogue_manager' and permission.code in ('dashboard.read','pricing.binding.manage'))
  or (role.code = 'licensing_officer' and permission.code in ('dashboard.read','license.application.review','document.generate','document.private.read'))
  or (role.code = 'finance_officer' and permission.code in ('dashboard.read','consignment.finance.manage','document.generate','document.private.read'))
  or (role.code = 'inventory_controller' and permission.code in ('dashboard.read','asset.fulfill','document.generate','document.private.read'))
  or (role.code = 'warehouse_operator' and permission.code = 'dashboard.read')
  or (role.code = 'compliance_officer' and permission.code in ('dashboard.read','compliance.effect.apply','document.private.read'))
  or (role.code = 'economic_steward' and permission.code = 'dashboard.read')
  or (role.code = 'procurement_officer' and permission.code = 'dashboard.read')
  or (role.code = 'fulfillment_officer' and permission.code = 'dashboard.read')
  or (role.code = 'transfer_coordinator' and permission.code = 'dashboard.read')
  or (role.code = 'consignment_officer' and permission.code = 'dashboard.read')
on conflict do nothing;

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values
  ('direct_customer', 'EEC-CUS', 1001, 4),
  ('license_application', 'EEC-LAP', 1001, 4),
  ('consignment_settlement', 'EEC-CST', 1001, 4),
  ('unique_fulfillment', 'EEC-UFL', 1001, 4),
  ('generated_document', 'EEC-DOC', 1001, 4);

create function private.allocate_launch_reference(p_document_type text)
returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare sequence_record record; allocated text;
begin
  if p_document_type not in ('direct_customer','license_application','consignment_settlement','unique_fulfillment','generated_document') then
    raise exception using errcode = '22023', message = 'launch_reference_type_invalid';
  end if;
  select sequence.prefix, sequence.next_value, sequence.padding into strict sequence_record
  from public.reference_sequences sequence
  where sequence.document_type = p_document_type and sequence.active for update;
  allocated := sequence_record.prefix || '-' || lpad(sequence_record.next_value::text, sequence_record.padding, '0');
  update public.reference_sequences sequence set next_value = sequence.next_value + 1
  where sequence.document_type = p_document_type;
  return allocated;
exception when no_data_found then
  raise exception using errcode = '55000', message = 'launch_reference_sequence_unavailable';
end;
$$;

-- Explicit order channels and immutable pricing provenance.
alter table public.orders alter column dealer_authorization_id drop not null;
alter table public.orders
  add column source_channel text not null default 'dealer_portal'
    check (source_channel in ('dealer_portal','staff_assisted_business','direct_individual')),
  add column entered_by_staff_actor_id uuid references public.actor_profiles(id) on delete restrict,
  add column customer_contact_name text,
  add constraint orders_channel_authority_check check (
    (source_channel = 'dealer_portal' and dealer_authorization_id is not null and entered_by_staff_actor_id is null)
    or (source_channel = 'staff_assisted_business' and dealer_authorization_id is not null and entered_by_staff_actor_id is not null)
    or (source_channel = 'direct_individual' and dealer_authorization_id is null and license_id is null and entered_by_staff_actor_id is not null)
  );

alter table public.order_lines
  add column price_schedule_id_snapshot uuid references public.price_schedules(id) on delete restrict,
  add column price_rule_id_snapshot uuid references public.price_rules(id) on delete restrict,
  add column price_source_snapshot text,
  add column base_price_minor_snapshot bigint check (base_price_minor_snapshot is null or base_price_minor_snapshot >= 0),
  add column price_multiplier_basis_points_snapshot integer check (price_multiplier_basis_points_snapshot is null or price_multiplier_basis_points_snapshot > 0);

create table public.commercial_channel_policies (
  channel_code text primary key check (channel_code in ('dealer_portal','staff_assisted_business','direct_individual')),
  display_name text not null,
  price_multiplier_basis_points integer not null default 10000 check (price_multiplier_basis_points > 0),
  weekly_window_timezone text not null default 'America/New_York',
  week_starts_on smallint not null default 1 check (week_starts_on between 0 and 6),
  active boolean not null default true,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.commercial_channel_policies
  (channel_code, display_name, price_multiplier_basis_points, weekly_window_timezone, week_starts_on)
values
  ('dealer_portal', 'Dealer self-service', 10000, 'America/New_York', 1),
  ('staff_assisted_business', 'Staff-assisted licensed business', 10000, 'America/New_York', 1),
  ('direct_individual', 'Direct individual premium', 30000, 'America/New_York', 1);

create table public.price_schedule_bindings (
  id uuid primary key default extensions.gen_random_uuid(),
  price_schedule_id uuid not null references public.price_schedules(id) on delete restrict,
  binding_type text not null check (binding_type in ('party','license_class','dealer_type','jurisdiction','channel_default')),
  target_id uuid,
  channel_code text check (channel_code in ('dealer_portal','staff_assisted_business','direct_individual')),
  priority integer not null default 0,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  check ((binding_type = 'channel_default' and target_id is null and channel_code is not null)
    or (binding_type <> 'channel_default' and target_id is not null)),
  unique (price_schedule_id, binding_type, target_id, channel_code, effective_from)
);

create table public.direct_customer_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  party_id uuid not null unique references public.parties(id) on delete restrict,
  contact_label text not null default '' check (char_length(contact_label) <= 300),
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.personal_quota_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  party_id uuid not null references public.parties(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  order_line_id uuid not null unique references public.order_lines(id) on delete restrict,
  window_start timestamptz not null,
  window_end timestamptz not null,
  quantity numeric(18,3) not null check (quantity > 0),
  status text not null default 'held' check (status in ('held','consumed','released')),
  released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (window_end > window_start),
  check ((status = 'released') = (released_at is not null))
);
create index personal_quota_window_idx on public.personal_quota_entries(party_id,item_id,window_start,status);

-- Public license applications use a one-time status token; only its digest is stored.
create table public.license_applications (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  application_type text not null check (application_type in ('new','renewal')),
  applicant_name text not null check (btrim(applicant_name) <> '' and char_length(applicant_name) <= 200),
  contact_label text not null check (btrim(contact_label) <> '' and char_length(contact_label) <= 300),
  requested_license_class_id uuid not null references public.license_classes(id) on delete restrict,
  requested_jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  existing_license_id uuid references public.licenses(id) on delete restrict,
  statement text not null check (btrim(statement) <> '' and char_length(statement) <= 4000),
  status text not null default 'submitted' check (status in ('submitted','under_review','issued','renewed','denied','withdrawn')),
  status_token_digest text not null,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  review_reason text,
  issued_license_id uuid references public.licenses(id) on delete restrict,
  source_request_id uuid not null unique,
  review_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((application_type = 'renewal') = (existing_license_id is not null)),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.license_application_endorsements (
  application_id uuid not null references public.license_applications(id) on delete restrict,
  endorsement_definition_id uuid not null references public.endorsement_definitions(id) on delete restrict,
  primary key (application_id, endorsement_definition_id)
);

create table public.license_renewal_events (
  id uuid primary key default extensions.gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete restrict,
  application_id uuid not null unique references public.license_applications(id) on delete restrict,
  previous_expires_at timestamptz,
  new_expires_at timestamptz not null,
  renewed_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now()
);

-- Consignment money is settlement evidence, not an independent treasury ledger.
create table public.consignment_finance_terms (
  id uuid primary key default extensions.gen_random_uuid(),
  agreement_id uuid not null references public.consignment_agreements(id) on delete restrict,
  currency_code text not null check (currency_code ~ '^[A-Z0-9_]{2,12}$'),
  commission_basis_points integer not null check (commission_basis_points between 0 and 10000),
  effective_from timestamptz not null,
  effective_until timestamptz,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  exclude using gist (agreement_id with =, tstzrange(effective_from, coalesce(effective_until,'infinity'::timestamptz),'[)') with &&)
);

create table public.consignment_settlements (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  consignment_report_id uuid not null unique references public.consignment_reports(id) on delete restrict,
  finance_term_id uuid not null references public.consignment_finance_terms(id) on delete restrict,
  quantity_sold numeric(18,3) not null check (quantity_sold > 0),
  unit_sale_price_minor bigint not null check (unit_sale_price_minor >= 0),
  gross_amount_minor bigint not null check (gross_amount_minor >= 0),
  commission_amount_minor bigint not null check (commission_amount_minor >= 0),
  owner_amount_minor bigint not null check (owner_amount_minor >= 0),
  currency_code text not null,
  status text not null default 'pending' check (status in ('pending','paid','voided')),
  payment_reference text,
  paid_at timestamptz,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  paid_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  payment_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (gross_amount_minor = round(quantity_sold * unit_sale_price_minor)::bigint),
  check (owner_amount_minor + commission_amount_minor = gross_amount_minor),
  check ((status = 'paid' and paid_at is not null and paid_by_actor_id is not null and btrim(payment_reference) <> '')
    or (status <> 'paid' and paid_at is null and paid_by_actor_id is null and payment_reference is null)),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.unique_fulfillments (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  asset_reservation_id uuid not null unique references public.asset_reservations(id) on delete restrict,
  asset_id uuid not null references public.serialized_assets(id) on delete restrict,
  order_line_id uuid not null unique references public.order_lines(id) on delete restrict,
  recipient_party_id uuid not null references public.parties(id) on delete restrict,
  fulfilled_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  fulfilled_at timestamptz not null default now(),
  reason text not null check (btrim(reason) <> ''),
  source_request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

-- Official documents are immutable source snapshots. PDFs remain projections.
create table public.generated_documents (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  document_type text not null check (document_type in ('license_certificate','order_confirmation','unique_fulfillment_receipt','consignment_statement')),
  source_record_type text not null check (source_record_type in ('license','order','unique_fulfillment','consignment_settlement')),
  source_record_id uuid not null,
  source_version bigint not null check (source_version > 0),
  snapshot_payload jsonb not null check (jsonb_typeof(snapshot_payload) = 'object'),
  checksum_sha256 text not null check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  generated_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  generated_at timestamptz not null default now(),
  check (public_reference = private.normalize_registry_reference(public_reference))
);
create unique index generated_documents_source_version_idx
  on public.generated_documents(document_type,source_record_id,source_version);

-- Configured compliance action types can now execute a narrow, reviewed effect.
alter table public.compliance_action_types drop constraint compliance_action_types_effect_mode_check;
alter table public.compliance_action_types add constraint compliance_action_types_effect_mode_check
  check (effect_mode in ('record_only','license_suspend','dealer_suspend','order_cancel','asset_seize'));
alter table public.compliance_actions drop constraint compliance_actions_effect_applied_check;

insert into public.compliance_action_types(code,display_name,description,effect_mode)
values
  ('suspend-license','Suspend license','Suspend the exact related license when an authorized reviewer approves the action.','license_suspend'),
  ('suspend-dealer','Suspend dealer authority','Suspend the exact related dealer authorization when approved.','dealer_suspend'),
  ('cancel-order','Cancel order','Cancel the exact unfulfilled related order when approved.','order_cancel'),
  ('seize-asset','Seize serialized asset','Place the exact related serialized asset in seized status when approved.','asset_seize');

create table public.compliance_effect_executions (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_action_id uuid not null unique references public.compliance_actions(id) on delete restrict,
  effect_mode text not null,
  target_record_type text not null,
  target_record_id uuid not null,
  previous_state jsonb not null,
  new_state jsonb not null,
  applied_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  request_id uuid not null unique,
  applied_at timestamptz not null default now()
);

-- Standard audit, updated-at, RLS, and immutable evidence boundaries.
create trigger commercial_channel_policies_set_updated_at before update on public.commercial_channel_policies for each row execute function private.set_updated_at();
create trigger price_schedule_bindings_set_updated_at before update on public.price_schedule_bindings for each row execute function private.set_updated_at();
create trigger personal_quota_entries_set_updated_at before update on public.personal_quota_entries for each row execute function private.set_updated_at();
create trigger license_applications_set_updated_at before update on public.license_applications for each row execute function private.set_updated_at();
create trigger consignment_settlements_set_updated_at before update on public.consignment_settlements for each row execute function private.set_updated_at();

create trigger commercial_channel_policies_audit after insert or update or delete on public.commercial_channel_policies for each row execute function private.capture_audit_row();
create trigger price_schedule_bindings_audit after insert or update or delete on public.price_schedule_bindings for each row execute function private.capture_audit_row();
create trigger direct_customer_profiles_audit after insert or update or delete on public.direct_customer_profiles for each row execute function private.capture_audit_row();
create trigger personal_quota_entries_audit after insert or update or delete on public.personal_quota_entries for each row execute function private.capture_audit_row();
create trigger license_applications_audit after insert or update or delete on public.license_applications for each row execute function private.capture_audit_row();
create trigger license_renewal_events_audit after insert or update or delete on public.license_renewal_events for each row execute function private.capture_audit_row();
create trigger consignment_finance_terms_audit after insert or update or delete on public.consignment_finance_terms for each row execute function private.capture_audit_row();
create trigger consignment_settlements_audit after insert or update or delete on public.consignment_settlements for each row execute function private.capture_audit_row();
create trigger unique_fulfillments_audit after insert or update or delete on public.unique_fulfillments for each row execute function private.capture_audit_row();
create trigger generated_documents_audit after insert or update or delete on public.generated_documents for each row execute function private.capture_audit_row();
create trigger compliance_effect_executions_audit after insert or update or delete on public.compliance_effect_executions for each row execute function private.capture_audit_row();

alter table public.commercial_channel_policies enable row level security;
alter table public.price_schedule_bindings enable row level security;
alter table public.direct_customer_profiles enable row level security;
alter table public.personal_quota_entries enable row level security;
alter table public.license_applications enable row level security;
alter table public.license_application_endorsements enable row level security;
alter table public.license_renewal_events enable row level security;
alter table public.consignment_finance_terms enable row level security;
alter table public.consignment_settlements enable row level security;
alter table public.unique_fulfillments enable row level security;
alter table public.generated_documents enable row level security;
alter table public.compliance_effect_executions enable row level security;

create function private.resolve_trade_price(
  p_channel text, p_party_id uuid, p_dealer_authorization_id uuid,
  p_license_id uuid, p_jurisdiction_id uuid, p_item_id uuid
)
returns table (
  schedule_id uuid, rule_id uuid, amount_minor bigint, base_amount_minor bigint,
  multiplier_basis_points integer, currency_code text, source_label text
)
language sql stable security definer set search_path = ''
as $$
  with context as (
    select dealer.dealer_type_id, license.license_class_id,
      coalesce(policy.price_multiplier_basis_points,10000) multiplier
    from (select 1) seed
    left join public.dealer_authorizations dealer on dealer.id = p_dealer_authorization_id
    left join public.licenses license on license.id = p_license_id
    left join public.commercial_channel_policies policy on policy.channel_code = p_channel and policy.active
  ), candidates as (
    select schedule.id schedule_id, rule.id rule_id, rule.amount_minor base_amount,
      currency.code currency_code,
      case binding.binding_type
        when 'party' then 500 when 'license_class' then 400 when 'dealer_type' then 300
        when 'jurisdiction' then 200 when 'channel_default' then 100 else 0 end
        + binding.priority + schedule.priority rank,
      binding.binding_type || ':' || coalesce(binding.target_id::text,binding.channel_code) source_label
    from public.price_schedule_bindings binding
    join public.price_schedules schedule on schedule.id = binding.price_schedule_id
    join public.price_rules rule on rule.price_schedule_id = schedule.id and rule.item_id = p_item_id
    join public.currencies currency on currency.id = schedule.currency_id
    cross join context
    where schedule.status = 'active' and schedule.effective_from <= statement_timestamp()
      and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
      and rule.effective_from <= statement_timestamp()
      and (rule.effective_until is null or rule.effective_until > statement_timestamp())
      and binding.effective_from <= statement_timestamp()
      and (binding.effective_until is null or binding.effective_until > statement_timestamp())
      and (
        (binding.binding_type = 'party' and binding.target_id = p_party_id)
        or (binding.binding_type = 'license_class' and binding.target_id = context.license_class_id)
        or (binding.binding_type = 'dealer_type' and binding.target_id = context.dealer_type_id)
        or (binding.binding_type = 'jurisdiction' and binding.target_id = p_jurisdiction_id)
        or (binding.binding_type = 'channel_default' and binding.channel_code = p_channel)
      )
    union all
    select schedule.id, rule.id, rule.amount_minor, currency.code,
      schedule.priority + case when schedule.audience_code in ('wholesale','dealer') then 50 else 0 end,
      'audience:' || schedule.audience_code
    from public.price_schedules schedule
    join public.price_rules rule on rule.price_schedule_id = schedule.id and rule.item_id = p_item_id
    join public.currencies currency on currency.id = schedule.currency_id
    where schedule.status = 'active' and schedule.effective_from <= statement_timestamp()
      and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
      and rule.effective_from <= statement_timestamp()
      and (rule.effective_until is null or rule.effective_until > statement_timestamp())
      and not exists (select 1 from public.price_schedule_bindings binding where binding.price_schedule_id = schedule.id)
      and (
        (p_channel = 'direct_individual' and schedule.audience_code = 'public')
        or (p_channel <> 'direct_individual' and schedule.audience_code in ('wholesale','dealer','public'))
      )
  )
  select candidate.schedule_id, candidate.rule_id,
    round(candidate.base_amount * context.multiplier / 10000.0)::bigint,
    candidate.base_amount, context.multiplier, candidate.currency_code, candidate.source_label
  from candidates candidate cross join context
  order by candidate.rank desc, candidate.schedule_id
  limit 1;
$$;

create function private.apply_order_line_trade_terms()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare order_record record; price_record record; policy_record record;
  local_now timestamp; window_local timestamp; starts_at timestamptz; ends_at timestamptz; used numeric;
begin
  select order_item.* into strict order_record from public.orders order_item where order_item.id = new.order_id;
  select * into price_record from private.resolve_trade_price(
    order_record.source_channel, order_record.ordering_party_id, order_record.dealer_authorization_id,
    order_record.license_id, order_record.jurisdiction_id, new.item_id
  );
  if found then
    new.unit_price_minor_snapshot := price_record.amount_minor;
    new.currency_code_snapshot := price_record.currency_code;
    new.pricing_status := 'configured';
    new.price_schedule_id_snapshot := price_record.schedule_id;
    new.price_rule_id_snapshot := price_record.rule_id;
    new.price_source_snapshot := price_record.source_label;
    new.base_price_minor_snapshot := price_record.base_amount_minor;
    new.price_multiplier_basis_points_snapshot := price_record.multiplier_basis_points;
  elsif order_record.source_channel = 'direct_individual' then
    raise exception using errcode = '22023', message = 'direct_price_unavailable';
  end if;

  if order_record.source_channel = 'direct_individual' then
    select supply.*, channel.weekly_window_timezone into policy_record
    from public.item_supply_policies supply
    join public.commercial_channel_policies channel on channel.channel_code = 'direct_individual' and channel.active
    where supply.item_id = new.item_id and supply.direct_individual_allowed;
    if not found then raise exception using errcode = '22023', message = 'direct_item_not_allowed'; end if;
    if not exists (select 1 from public.direct_customer_profiles profile where profile.party_id = order_record.ordering_party_id) then
      raise exception using errcode = '22023', message = 'direct_customer_profile_required';
    end if;
    local_now := statement_timestamp() at time zone policy_record.weekly_window_timezone;
    window_local := date_trunc('week', local_now);
    starts_at := window_local at time zone policy_record.weekly_window_timezone;
    ends_at := (window_local + interval '7 days') at time zone policy_record.weekly_window_timezone;
    perform pg_advisory_xact_lock(hashtextextended(order_record.ordering_party_id::text || new.item_id::text || starts_at::text, 0));
    select coalesce(sum(quota.quantity),0) into used from public.personal_quota_entries quota
    where quota.party_id = order_record.ordering_party_id and quota.item_id = new.item_id
      and quota.window_start = starts_at and quota.status in ('held','consumed');
    if policy_record.direct_weekly_limit is not null and used + new.quantity_requested > policy_record.direct_weekly_limit then
      raise exception using errcode = '22023', message = 'direct_weekly_limit_exceeded';
    end if;
  end if;
  return new;
end;
$$;

create trigger order_lines_apply_trade_terms before insert on public.order_lines
for each row execute function private.apply_order_line_trade_terms();

create function private.record_order_line_quota()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare order_record record; timezone_name text; local_now timestamp; starts_at timestamptz;
begin
  select order_item.* into order_record from public.orders order_item where order_item.id = new.order_id;
  if order_record.source_channel <> 'direct_individual' then return new; end if;
  select policy.weekly_window_timezone into timezone_name from public.commercial_channel_policies policy
  where policy.channel_code = 'direct_individual';
  local_now := statement_timestamp() at time zone timezone_name;
  starts_at := date_trunc('week',local_now) at time zone timezone_name;
  insert into public.personal_quota_entries(party_id,item_id,order_line_id,window_start,window_end,quantity)
  values(order_record.ordering_party_id,new.item_id,new.id,starts_at,
    (date_trunc('week',local_now)+interval '7 days') at time zone timezone_name,new.quantity_requested);
  return new;
end;
$$;
create trigger order_lines_record_quota after insert on public.order_lines
for each row execute function private.record_order_line_quota();

create function private.sync_order_line_quota()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.status in ('denied','cancelled') and old.status is distinct from new.status then
    update public.personal_quota_entries set status = 'released', released_at = statement_timestamp()
    where order_line_id = new.id and status in ('held','consumed');
  elsif new.status = 'fulfilled' and old.status is distinct from new.status then
    update public.personal_quota_entries set status = 'consumed', released_at = null
    where order_line_id = new.id and status = 'held';
  end if;
  return new;
end;
$$;
create trigger order_lines_sync_quota after update of status on public.order_lines
for each row execute function private.sync_order_line_quota();

create function public.staff_create_trade_order(
  p_channel text, p_customer_party_id uuid, p_customer_name text, p_contact_label text,
  p_dealer_authorization_id uuid, p_license_id uuid, p_jurisdiction_id uuid,
  p_fulfillment_mode text, p_notes text, p_lines jsonb, p_reason text, p_request_id uuid
)
returns table(order_id uuid, public_reference text, version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing record; party_id uuid; jurisdiction_id uuid; dealer_record record;
  license_record record; line jsonb; item_record record; created_id uuid; created_reference text;
  line_number smallint := 0; currency_code text;
begin
  actor_id := private.set_staff_audit_context('order.assisted.create',p_reason,p_request_id);
  select order_item.id,order_item.public_reference,order_item.version into existing from public.orders order_item
  where order_item.source_request_id = p_request_id;
  if found then return query select existing.id,existing.public_reference,existing.version; return; end if;
  if p_channel not in ('staff_assisted_business','direct_individual') or p_fulfillment_mode not in ('collection','delivery','consignment')
    or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 or jsonb_array_length(p_lines) > 50 then
    raise exception using errcode = '22023', message = 'assisted_order_invalid';
  end if;
  select currency.code into strict currency_code from public.currencies currency where currency.is_default;
  if p_channel = 'staff_assisted_business' then
    select dealer.*, status.confers_authority into dealer_record
    from public.dealer_authorizations dealer join public.dealer_status_definitions status on status.id = dealer.status_definition_id
    where dealer.id = p_dealer_authorization_id and dealer.dealer_party_id = p_customer_party_id
      and status.confers_authority and dealer.effective_from <= statement_timestamp()
      and (dealer.effective_until is null or dealer.effective_until > statement_timestamp());
    if not found then raise exception using errcode = '22023', message = 'assisted_dealer_not_authorized'; end if;
    select license.* into license_record from public.licenses license
    join public.license_status_definitions status on status.id = license.status_definition_id and status.confers_authority
    where license.id = p_license_id and license.holder_party_id = p_customer_party_id
      and license.dealer_authorization_id = p_dealer_authorization_id
      and license.effective_from <= statement_timestamp() and (license.expires_at is null or license.expires_at > statement_timestamp());
    if not found then raise exception using errcode = '22023', message = 'assisted_license_not_authorized'; end if;
    party_id := p_customer_party_id; jurisdiction_id := dealer_record.jurisdiction_id;
  else
    jurisdiction_id := p_jurisdiction_id;
    if not exists(select 1 from public.jurisdictions jurisdiction where jurisdiction.id = jurisdiction_id and jurisdiction.status = 'active')
      or (p_customer_party_id is null and btrim(coalesce(p_customer_name,'')) = '') then raise exception using errcode = '22023', message = 'direct_customer_invalid'; end if;
    if p_customer_party_id is not null then
      select profile.party_id into party_id from public.direct_customer_profiles profile where profile.party_id = p_customer_party_id;
      if not found then raise exception using errcode = '22023', message = 'direct_customer_not_found'; end if;
    else
      insert into public.parties(party_type_id,legal_name,display_name,primary_jurisdiction_id)
      select type.id,btrim(p_customer_name),btrim(p_customer_name),jurisdiction_id from public.party_types type where type.code = 'individual'
      returning id into party_id;
      insert into public.direct_customer_profiles(public_reference,party_id,contact_label,created_by_actor_id,source_request_id)
      values(private.allocate_launch_reference('direct_customer'),party_id,btrim(coalesce(p_contact_label,'')),actor_id,p_request_id);
    end if;
  end if;
  created_reference := private.allocate_order_reference();
  insert into public.orders(public_reference,ordering_party_id,dealer_authorization_id,license_id,jurisdiction_id,
    fulfillment_mode,currency_code,dealer_notes,requested_by_actor_id,source_request_id,source_channel,
    entered_by_staff_actor_id,customer_contact_name)
  values(created_reference,party_id,case when p_channel='staff_assisted_business' then p_dealer_authorization_id end,
    case when p_channel='staff_assisted_business' then p_license_id end,jurisdiction_id,p_fulfillment_mode,currency_code,
    coalesce(p_notes,''),actor_id,p_request_id,p_channel,actor_id,nullif(btrim(coalesce(p_contact_label,'')),''))
  returning id into created_id;
  for line in select value from jsonb_array_elements(p_lines) loop
    line_number := line_number + 1;
    select item.id,item.item_code,item.display_name,unit.code unit_code,control.code control_code,
      control.requires_staff_review,control.requires_transaction_approval,control.requires_serial_tracking
    into item_record
    from public.items item join public.units_of_measure unit on unit.id=item.unit_id
    join public.item_publications publication on publication.item_id=item.id and publication.audience_code='public'
      and publication.publication_status='published' and publication.effective_from <= statement_timestamp()
      and (publication.effective_until is null or publication.effective_until > statement_timestamp())
    join public.control_profiles control on control.id=publication.control_profile_id
    where item.id = (line->>'item_id')::uuid and item.status='active';
    if not found or coalesce((line->>'quantity')::numeric,0) <= 0 then
      raise exception using errcode = '22023', message = 'assisted_order_line_invalid';
    end if;
    insert into public.order_lines(order_id,line_number,item_id,item_code_snapshot,item_name_snapshot,unit_code_snapshot,
      quantity_requested,currency_code_snapshot,control_profile_code_snapshot,requires_staff_review_snapshot,
      requires_transaction_approval_snapshot,requires_serial_tracking_snapshot,review_reason_codes)
    values(created_id,line_number,item_record.id,item_record.item_code,item_record.display_name,item_record.unit_code,
      (line->>'quantity')::numeric,currency_code,item_record.control_code,item_record.requires_staff_review,
      item_record.requires_transaction_approval,item_record.requires_serial_tracking,
      case when p_channel='direct_individual' then '["direct_individual"]'::jsonb else '["staff_assisted"]'::jsonb end);
  end loop;
  insert into public.order_status_events(order_id,new_status,event_type,changed_by,reason,request_id)
  values(created_id,'submitted','submitted',actor_id,btrim(p_reason),p_request_id);
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('order.submitted','order',created_id,jsonb_build_object('public_reference',created_reference,'source_channel',p_channel),
    'order.submitted:'||p_request_id::text);
  return query select created_id,created_reference,1::bigint;
end;
$$;

create function public.public_submit_license_application(
  p_application_type text, p_applicant_name text, p_contact_label text,
  p_license_class_code text, p_jurisdiction_code text, p_existing_license_reference text,
  p_endorsement_codes text[], p_statement text, p_request_id uuid
)
returns table(application_id uuid, public_reference text, status_token text)
language plpgsql volatile security definer set search_path = ''
as $$
declare existing record; class_id uuid; jurisdiction_id uuid; existing_license_id uuid;
  created_id uuid; created_reference text; token text;
begin
  select application.id,application.public_reference into existing from public.license_applications application
  where application.source_request_id=p_request_id;
  if found then raise exception using errcode='22023',message='application_retry_requires_saved_status_token'; end if;
  if p_application_type not in ('new','renewal') or btrim(coalesce(p_applicant_name,''))='' or btrim(coalesce(p_contact_label,''))=''
    or btrim(coalesce(p_statement,''))='' or char_length(p_applicant_name)>200 or char_length(p_contact_label)>300
    or char_length(p_statement)>4000 then raise exception using errcode='22023',message='license_application_invalid'; end if;
  select class.id into class_id from public.license_classes class where class.code=lower(btrim(p_license_class_code)) and class.active;
  if not found then raise exception using errcode='22023',message='license_application_class_invalid'; end if;
  select jurisdiction.id into jurisdiction_id from public.jurisdictions jurisdiction
  where jurisdiction.code=lower(btrim(p_jurisdiction_code)) and jurisdiction.status='active';
  if not found then raise exception using errcode='22023',message='license_application_jurisdiction_invalid'; end if;
  if p_application_type='renewal' then
    select license.id into existing_license_id from public.licenses license
    where license.public_reference=private.normalize_registry_reference(p_existing_license_reference);
    if not found then raise exception using errcode='22023',message='renewal_license_not_found'; end if;
  elsif nullif(btrim(coalesce(p_existing_license_reference,'')),'') is not null then
    raise exception using errcode='22023',message='new_application_cannot_reference_license';
  end if;
  if exists(select 1 from unnest(coalesce(p_endorsement_codes,array[]::text[])) code
    where not exists(select 1 from public.endorsement_definitions definition where definition.code=lower(btrim(code)) and definition.active))
    then raise exception using errcode='22023',message='license_application_endorsement_invalid'; end if;
  perform set_config('app.actor_id','',true); perform set_config('app.permission_code','public.license.apply',true);
  perform set_config('app.audit_reason','Public license application submitted.',true);
  perform set_config('app.request_id',p_request_id::text,true); perform set_config('app.source_surface','public_portal',true);
  created_reference:=private.allocate_launch_reference('license_application');
  token:=encode(extensions.gen_random_bytes(24),'hex');
  insert into public.license_applications(public_reference,application_type,applicant_name,contact_label,
    requested_license_class_id,requested_jurisdiction_id,existing_license_id,statement,status_token_digest,source_request_id)
  values(created_reference,p_application_type,btrim(p_applicant_name),btrim(p_contact_label),class_id,jurisdiction_id,
    existing_license_id,btrim(p_statement),encode(extensions.digest(token,'sha256'),'hex'),p_request_id)
  returning id into created_id;
  insert into public.license_application_endorsements(application_id,endorsement_definition_id)
  select created_id,definition.id from public.endorsement_definitions definition
  join (select distinct lower(btrim(code)) code from unnest(coalesce(p_endorsement_codes,array[]::text[])) code) requested
    on requested.code=definition.code;
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('license.application_submitted','license_application',created_id,
    jsonb_build_object('public_reference',created_reference,'application_type',p_application_type),
    'license.application_submitted:'||p_request_id::text);
  return query select created_id,created_reference,token;
end;
$$;

create function public.public_get_license_application_status(p_reference text,p_status_token text)
returns table(public_reference text,application_type text,applicant_name text,status text,submitted_at timestamptz,reviewed_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select application.public_reference,application.application_type,application.applicant_name,
    application.status,application.submitted_at,application.reviewed_at
  from public.license_applications application
  where application.public_reference=private.normalize_registry_reference(p_reference)
    and application.status_token_digest=encode(extensions.digest(coalesce(p_status_token,''),'sha256'),'hex');
$$;

create function public.get_public_license_application_options()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'license_classes',coalesce((select jsonb_agg(jsonb_build_object('code',class.code,'label',class.public_display_name) order by class.public_display_name)
      from public.license_classes class where class.active),'[]'::jsonb),
    'jurisdictions',coalesce((select jsonb_agg(jsonb_build_object('code',jurisdiction.code,'label',jurisdiction.public_name) order by jurisdiction.public_name)
      from public.jurisdictions jurisdiction where jurisdiction.status='active'),'[]'::jsonb),
    'endorsements',coalesce((select jsonb_agg(jsonb_build_object('code',definition.code,'label',definition.public_display_name,'description',definition.description) order by definition.public_display_name)
      from public.endorsement_definitions definition where definition.active),'[]'::jsonb)
  );
$$;

create function public.staff_decide_license_application(
  p_application_id uuid,p_expected_version bigint,p_decision text,p_holder_party_id uuid,
  p_effective_from timestamptz,p_expires_at timestamptz,p_initial_status_code text,
  p_reason text,p_request_id uuid
)
returns table(application_id uuid,status text,issued_license_id uuid,version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; application record; issued record; endorsement_codes text[];
begin
  actor_id:=private.set_staff_audit_context('license.application.review',p_reason,p_request_id);
  select item.* into application from public.license_applications item where item.id=p_application_id;
  if not found then raise exception using errcode='P0002',message='license_application_not_found'; end if;
  if application.review_request_id=p_request_id then
    return query select application.id,application.status,application.issued_license_id,application.version; return;
  end if;
  select item.* into application from public.license_applications item where item.id=p_application_id for update;
  if application.version<>p_expected_version then raise exception using errcode='40001',message='license_application_version_conflict'; end if;
  if application.status not in ('submitted','under_review') or p_decision not in ('approve','deny') then
    raise exception using errcode='22023',message='license_application_transition_invalid'; end if;
  if p_decision='deny' then
    update public.license_applications set status='denied',reviewed_at=statement_timestamp(),reviewed_by_actor_id=actor_id,
      review_reason=btrim(p_reason),review_request_id=p_request_id,version=version+1 where id=p_application_id returning * into application;
  elsif application.application_type='new' then
    if p_holder_party_id is null then raise exception using errcode='22023',message='license_application_holder_required'; end if;
    select coalesce(array_agg(definition.code),array[]::text[]) into endorsement_codes
    from public.license_application_endorsements requested join public.endorsement_definitions definition
      on definition.id=requested.endorsement_definition_id where requested.application_id=application.id;
    select * into issued from public.staff_issue_license(p_holder_party_id,null,
      (select code from public.license_classes where id=application.requested_license_class_id),
      (select code from public.jurisdictions where id=application.requested_jurisdiction_id),
      coalesce(nullif(btrim(p_initial_status_code),''),'active'),p_effective_from,p_expires_at,false,'',
      'Issued from application '||application.public_reference,endorsement_codes,p_reason,p_request_id);
    update public.license_applications set status='issued',reviewed_at=statement_timestamp(),reviewed_by_actor_id=actor_id,
      review_reason=btrim(p_reason),review_request_id=p_request_id,issued_license_id=issued.id,version=version+1
    where id=p_application_id returning * into application;
  else
    if p_expires_at is null or p_expires_at<=statement_timestamp() then raise exception using errcode='22023',message='license_renewal_term_invalid'; end if;
    insert into public.license_renewal_events(license_id,application_id,previous_expires_at,new_expires_at,renewed_by_actor_id,reason,request_id)
    select license.id,application.id,license.expires_at,p_expires_at,actor_id,btrim(p_reason),p_request_id
    from public.licenses license where license.id=application.existing_license_id;
    update public.licenses license set expires_at=p_expires_at,version=license.version+1 where license.id=application.existing_license_id;
    update public.license_applications set status='renewed',reviewed_at=statement_timestamp(),reviewed_by_actor_id=actor_id,
      review_reason=btrim(p_reason),review_request_id=p_request_id,issued_license_id=existing_license_id,version=version+1
    where id=p_application_id returning * into application;
  end if;
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('license.application_decided','license_application',application.id,
    jsonb_build_object('public_reference',application.public_reference,'status',application.status,'license_id',application.issued_license_id),
    'license.application_decided:'||p_request_id::text);
  return query select application.id,application.status,application.issued_license_id,application.version;
end;
$$;

create function public.staff_configure_price_binding(
  p_schedule_id uuid,p_binding_type text,p_target_id uuid,p_channel_code text,p_priority integer,
  p_effective_from timestamptz,p_effective_until timestamptz,p_reason text,p_request_id uuid
)
returns table(binding_id uuid,version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing record; created_id uuid;
begin
  actor_id:=private.set_staff_audit_context('pricing.binding.manage',p_reason,p_request_id);
  select binding.id,binding.version into existing from public.price_schedule_bindings binding where binding.source_request_id=p_request_id;
  if found then return query select existing.id,existing.version; return; end if;
  if not exists(select 1 from public.price_schedules schedule where schedule.id=p_schedule_id)
    or p_binding_type not in ('party','license_class','dealer_type','jurisdiction','channel_default') then
    raise exception using errcode='22023',message='price_binding_invalid'; end if;
  if (p_binding_type='party' and not exists(select 1 from public.parties where id=p_target_id))
    or (p_binding_type='license_class' and not exists(select 1 from public.license_classes where id=p_target_id))
    or (p_binding_type='dealer_type' and not exists(select 1 from public.dealer_types where id=p_target_id))
    or (p_binding_type='jurisdiction' and not exists(select 1 from public.jurisdictions where id=p_target_id)) then
    raise exception using errcode='22023',message='price_binding_target_invalid'; end if;
  insert into public.price_schedule_bindings(price_schedule_id,binding_type,target_id,channel_code,priority,effective_from,effective_until,created_by_actor_id,source_request_id)
  values(p_schedule_id,p_binding_type,case when p_binding_type='channel_default' then null else p_target_id end,
    case when p_binding_type='channel_default' then p_channel_code end,coalesce(p_priority,0),coalesce(p_effective_from,statement_timestamp()),p_effective_until,actor_id,p_request_id)
  returning id into created_id;
  return query select created_id,1::bigint;
end;
$$;

create function public.staff_configure_consignment_finance_terms(
  p_agreement_id uuid,p_currency_code text,p_commission_basis_points integer,
  p_effective_from timestamptz,p_effective_until timestamptz,p_reason text,p_request_id uuid
)
returns table(finance_term_id uuid)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing_id uuid; created_id uuid;
begin
  actor_id:=private.set_staff_audit_context('consignment.finance.manage',p_reason,p_request_id);
  select term.id into existing_id from public.consignment_finance_terms term where term.source_request_id=p_request_id;
  if found then return query select existing_id; return; end if;
  if not exists(select 1 from public.consignment_agreements agreement where agreement.id=p_agreement_id and agreement.status='active')
    or not exists(select 1 from public.currencies currency where currency.code=upper(btrim(p_currency_code)))
    or p_commission_basis_points not between 0 and 10000 then
    raise exception using errcode='22023',message='consignment_finance_terms_invalid'; end if;
  insert into public.consignment_finance_terms(agreement_id,currency_code,commission_basis_points,effective_from,effective_until,created_by_actor_id,source_request_id)
  values(p_agreement_id,upper(btrim(p_currency_code)),p_commission_basis_points,coalesce(p_effective_from,statement_timestamp()),p_effective_until,actor_id,p_request_id)
  returning id into created_id;
  return query select created_id;
end;
$$;

create function public.staff_create_consignment_settlement(
  p_consignment_report_id uuid,p_unit_sale_price_minor bigint,p_reason text,p_request_id uuid
)
returns table(settlement_id uuid,public_reference text,gross_amount_minor bigint,commission_amount_minor bigint,owner_amount_minor bigint,version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing record; report_record record; term_record record; created record;
  gross bigint; commission bigint;
begin
  actor_id:=private.set_staff_audit_context('consignment.finance.manage',p_reason,p_request_id);
  select settlement.* into existing from public.consignment_settlements settlement where settlement.source_request_id=p_request_id;
  if found then return query select existing.id,existing.public_reference,existing.gross_amount_minor,existing.commission_amount_minor,existing.owner_amount_minor,existing.version; return; end if;
  select report.*,issue.agreement_id into report_record from public.consignment_reports report
  join public.consignment_issues issue on issue.id=report.consignment_issue_id
  where report.id=p_consignment_report_id and report.status='accepted' and report.quantity_sold>0;
  if not found or p_unit_sale_price_minor is null or p_unit_sale_price_minor<0 then
    raise exception using errcode='22023',message='consignment_settlement_invalid'; end if;
  select term.* into term_record from public.consignment_finance_terms term
  where term.agreement_id=report_record.agreement_id and term.effective_from<=report_record.submitted_at
    and (term.effective_until is null or term.effective_until>report_record.submitted_at)
  order by term.effective_from desc limit 1;
  if not found then raise exception using errcode='22023',message='consignment_finance_terms_missing'; end if;
  gross:=round(report_record.quantity_sold*p_unit_sale_price_minor)::bigint;
  commission:=round(gross*term_record.commission_basis_points/10000.0)::bigint;
  insert into public.consignment_settlements(public_reference,consignment_report_id,finance_term_id,quantity_sold,
    unit_sale_price_minor,gross_amount_minor,commission_amount_minor,owner_amount_minor,currency_code,created_by_actor_id,source_request_id)
  values(private.allocate_launch_reference('consignment_settlement'),report_record.id,term_record.id,report_record.quantity_sold,
    p_unit_sale_price_minor,gross,commission,gross-commission,term_record.currency_code,actor_id,p_request_id)
  returning * into created;
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('consignment.settlement_created','consignment_settlement',created.id,
    jsonb_build_object('public_reference',created.public_reference,'gross_amount_minor',gross,'owner_amount_minor',gross-commission),
    'consignment.settlement_created:'||p_request_id::text);
  return query select created.id,created.public_reference,created.gross_amount_minor,created.commission_amount_minor,created.owner_amount_minor,created.version;
end;
$$;

create function public.staff_mark_consignment_settlement_paid(
  p_settlement_id uuid,p_expected_version bigint,p_payment_reference text,p_reason text,p_request_id uuid
)
returns table(settlement_id uuid,status text,version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; settlement record;
begin
  actor_id:=private.set_staff_audit_context('consignment.finance.manage',p_reason,p_request_id);
  select item.* into settlement from public.consignment_settlements item where item.id=p_settlement_id;
  if not found then raise exception using errcode='P0002',message='consignment_settlement_not_found'; end if;
  if settlement.payment_request_id=p_request_id then return query select settlement.id,settlement.status,settlement.version; return; end if;
  select item.* into settlement from public.consignment_settlements item where item.id=p_settlement_id for update;
  if settlement.version<>p_expected_version then raise exception using errcode='40001',message='consignment_settlement_version_conflict'; end if;
  if settlement.status<>'pending' or btrim(coalesce(p_payment_reference,''))='' then
    raise exception using errcode='22023',message='consignment_payment_invalid'; end if;
  update public.consignment_settlements set status='paid',payment_reference=btrim(p_payment_reference),paid_at=statement_timestamp(),
    paid_by_actor_id=actor_id,payment_request_id=p_request_id,version=version+1 where id=p_settlement_id returning * into settlement;
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('consignment.settlement_paid','consignment_settlement',settlement.id,
    jsonb_build_object('public_reference',settlement.public_reference,'payment_reference',settlement.payment_reference),
    'consignment.settlement_paid:'||p_request_id::text);
  return query select settlement.id,settlement.status,settlement.version;
end;
$$;

create function public.staff_fulfill_unique_asset(
  p_asset_reservation_id uuid,p_expected_reservation_version bigint,p_expected_asset_version bigint,
  p_reason text,p_request_id uuid
)
returns table(unique_fulfillment_id uuid,public_reference text,order_id uuid,order_status text)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing record; reservation record; asset record; line record; order_record record;
  created_id uuid; created_reference text; next_order_status text;
begin
  actor_id:=private.set_staff_audit_context('asset.fulfill',p_reason,p_request_id);
  select fulfillment.*,line.order_id into existing from public.unique_fulfillments fulfillment
  join public.order_lines line on line.id=fulfillment.order_line_id where fulfillment.source_request_id=p_request_id;
  if found then return query select existing.id,existing.public_reference,existing.order_id,
    (select status from public.orders where id=existing.order_id); return; end if;
  select item.* into reservation from public.asset_reservations item where item.id=p_asset_reservation_id for update;
  if not found then raise exception using errcode='P0002',message='asset_reservation_not_found'; end if;
  if reservation.version<>p_expected_reservation_version then raise exception using errcode='40001',message='asset_reservation_version_conflict'; end if;
  if reservation.status<>'active' or reservation.expires_at<=statement_timestamp() then raise exception using errcode='22023',message='asset_reservation_not_active'; end if;
  select item.* into asset from public.serialized_assets item where item.id=reservation.asset_id for update;
  if asset.version<>p_expected_asset_version then raise exception using errcode='40001',message='serialized_asset_version_conflict'; end if;
  select item.* into line from public.order_lines item where item.id=reservation.order_line_id for update;
  select item.* into order_record from public.orders item where item.id=line.order_id for update;
  if asset.status<>'reserved' or line.quantity_approved<>1 or line.quantity_fulfilled<>0 or not line.requires_serial_tracking_snapshot
    or line.status not in ('approved','awaiting_stock','partially_approved','reserved','ready') then
    raise exception using errcode='22023',message='unique_fulfillment_ineligible'; end if;
  update public.asset_reservations set status='consumed',terminated_at=statement_timestamp(),terminated_by_actor_id=actor_id,
    termination_reason=btrim(p_reason),termination_request_id=p_request_id,version=version+1 where id=reservation.id;
  update public.serialized_assets set current_custodian_party_id=order_record.ordering_party_id,current_warehouse_id=null,
    current_stock_location_id=null,status='in_custody',version=version+1 where id=asset.id;
  update public.order_lines set quantity_fulfilled=1,status='fulfilled',version=version+1 where id=line.id;
  next_order_status:=private.derive_order_status(order_record.id);
  update public.orders set status=next_order_status,version=version+1 where id=order_record.id;
  created_reference:=private.allocate_launch_reference('unique_fulfillment');
  insert into public.unique_fulfillments(public_reference,asset_reservation_id,asset_id,order_line_id,recipient_party_id,
    fulfilled_by_actor_id,reason,source_request_id)
  values(created_reference,reservation.id,asset.id,line.id,order_record.ordering_party_id,actor_id,btrim(p_reason),p_request_id)
  returning id into created_id;
  insert into public.asset_events(asset_id,event_type,recorded_by_actor_id,from_custodian_party_id,to_custodian_party_id,
    from_stock_location_id,order_line_id,asset_reservation_id,accepted_by_actor_id,accepted_at,previous_state,new_state,reason,request_id)
  values(asset.id,'custody_transferred',actor_id,asset.current_custodian_party_id,order_record.ordering_party_id,
    asset.current_stock_location_id,line.id,reservation.id,actor_id,statement_timestamp(),
    jsonb_build_object('status','reserved','reservation_id',reservation.id),
    jsonb_build_object('status','in_custody','recipient_party_id',order_record.ordering_party_id,'fulfillment_id',created_id),
    btrim(p_reason),p_request_id);
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('asset.unique_fulfilled','unique_fulfillment',created_id,
    jsonb_build_object('public_reference',created_reference,'asset_reference',asset.public_reference,'order_reference',order_record.public_reference),
    'asset.unique_fulfilled:'||p_request_id::text);
  return query select created_id,created_reference,order_record.id,next_order_status;
end;
$$;

create or replace function public.staff_recommend_compliance_action(
  p_compliance_case_id uuid,p_action_type_id uuid,p_subject_party_id uuid,
  p_related_record_type text,p_related_record_id uuid,p_recommendation text,
  p_reason text,p_request_id uuid
)
returns table(compliance_action_id uuid,public_reference text,version bigint,status text)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; case_status text; existing record; action_type record; created_id uuid; created_reference text;
begin
  actor_id:=private.set_staff_audit_context('compliance.action.recommend',p_reason,p_request_id);
  select action.id,action.public_reference,action.version,action.status into existing
  from public.compliance_actions action where action.source_request_id=p_request_id;
  if found then return query select existing.id,existing.public_reference,existing.version,existing.status; return; end if;
  select case_item.status into case_status from public.compliance_cases case_item where case_item.id=p_compliance_case_id;
  if not found then raise exception using errcode='P0002',message='compliance_case_not_found'; end if;
  select type.* into action_type from public.compliance_action_types type where type.id=p_action_type_id and type.active;
  if not found or case_status not in ('investigating','awaiting_response','deciding')
    or btrim(coalesce(p_recommendation,''))='' or char_length(p_recommendation)>4000
    or not private.compliance_related_record_exists(coalesce(p_related_record_type,'none'),p_related_record_id) then
    raise exception using errcode='22023',message='compliance_action_invalid'; end if;
  if (action_type.effect_mode='license_suspend' and p_related_record_type<>'license')
    or (action_type.effect_mode='dealer_suspend' and p_related_record_type<>'dealer_authorization')
    or (action_type.effect_mode='order_cancel' and p_related_record_type<>'order')
    or (action_type.effect_mode='asset_seize' and p_related_record_type<>'serialized_asset') then
    raise exception using errcode='22023',message='compliance_effect_target_mismatch'; end if;
  created_reference:=private.allocate_compliance_reference('compliance_action');
  insert into public.compliance_actions(public_reference,compliance_case_id,action_type_id,subject_party_id,
    related_record_type,related_record_id,recommendation,recommended_by_actor_id,source_request_id)
  values(created_reference,p_compliance_case_id,p_action_type_id,p_subject_party_id,coalesce(p_related_record_type,'none'),
    p_related_record_id,btrim(p_recommendation),actor_id,p_request_id) returning id into created_id;
  insert into public.compliance_events(compliance_case_id,event_type,related_record_type,related_record_id,new_state,changed_by_actor_id,reason,request_id)
  values(p_compliance_case_id,'action_recommended','compliance_action',created_id,
    jsonb_build_object('status','recommended','effect_mode',action_type.effect_mode),actor_id,btrim(p_reason),p_request_id);
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('compliance.action_recommended','compliance_action',created_id,
    jsonb_build_object('public_reference',created_reference,'case_id',p_compliance_case_id,'effect_mode',action_type.effect_mode),
    'compliance.action_recommended:'||p_request_id::text);
  return query select created_id,created_reference,1::bigint,'recommended'::text;
end;
$$;

create or replace function public.staff_review_compliance_action(
  p_compliance_action_id uuid,p_expected_version bigint,p_status text,p_reason text,p_request_id uuid
)
returns table(compliance_action_id uuid,version bigint,status text,effect_applied boolean)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; action_record record; type_record record; previous_state jsonb; next_state jsonb;
  suspended_status_id uuid;
begin
  actor_id:=private.set_staff_audit_context('compliance.action.approve',p_reason,p_request_id);
  select action.*,type.effect_mode into action_record from public.compliance_actions action
  join public.compliance_action_types type on type.id=action.action_type_id where action.id=p_compliance_action_id;
  if not found then raise exception using errcode='P0002',message='compliance_action_not_found'; end if;
  if action_record.review_request_id=p_request_id then
    return query select action_record.id,action_record.version,action_record.status,action_record.effect_applied; return;
  end if;
  select action.*,type.effect_mode into action_record from public.compliance_actions action
  join public.compliance_action_types type on type.id=action.action_type_id where action.id=p_compliance_action_id for update of action;
  if action_record.version<>p_expected_version then raise exception using errcode='40001',message='compliance_action_version_conflict'; end if;
  if action_record.status<>'recommended' or p_status not in ('approved','declined','voided') then
    raise exception using errcode='22023',message='compliance_action_transition_invalid'; end if;
  if p_status='approved' and action_record.effect_mode<>'record_only' then
    perform 1 from private.require_staff_permission('compliance.effect.apply');
    if action_record.effect_mode='license_suspend' then
      select to_jsonb(license) into previous_state from public.licenses license where license.id=action_record.related_record_id for update;
      if previous_state is null then raise exception using errcode='P0002',message='sanction_target_not_found'; end if;
      select status.id into suspended_status_id from public.license_status_definitions status where status.code='suspended';
      update public.licenses as license set status_definition_id=suspended_status_id,version=license.version+1 where license.id=action_record.related_record_id returning to_jsonb(license.*) into next_state;
    elsif action_record.effect_mode='dealer_suspend' then
      select to_jsonb(dealer) into previous_state from public.dealer_authorizations dealer where dealer.id=action_record.related_record_id for update;
      if previous_state is null then raise exception using errcode='P0002',message='sanction_target_not_found'; end if;
      select status.id into suspended_status_id from public.dealer_status_definitions status where status.code='suspended';
      update public.dealer_authorizations as dealer set status_definition_id=suspended_status_id,version=dealer.version+1 where dealer.id=action_record.related_record_id returning to_jsonb(dealer.*) into next_state;
    elsif action_record.effect_mode='order_cancel' then
      select to_jsonb(order_item) into previous_state from public.orders order_item where order_item.id=action_record.related_record_id for update;
      if previous_state is null then raise exception using errcode='P0002',message='sanction_target_not_found'; end if;
      if (previous_state->>'status') in ('fulfilled','cancelled')
        or exists(select 1 from public.reservations reservation join public.order_lines line on line.id=reservation.order_line_id
          where line.order_id=action_record.related_record_id and reservation.status='active')
        or exists(select 1 from public.asset_reservations reservation join public.order_lines line on line.id=reservation.order_line_id
          where line.order_id=action_record.related_record_id and reservation.status='active') then
        raise exception using errcode='22023',message='sanction_order_not_cancellable'; end if;
      update public.order_lines set status='cancelled',version=version+1 where order_id=action_record.related_record_id and status not in ('fulfilled','denied','cancelled');
      update public.orders as order_item set status='cancelled',version=order_item.version+1 where order_item.id=action_record.related_record_id returning to_jsonb(order_item.*) into next_state;
    elsif action_record.effect_mode='asset_seize' then
      select to_jsonb(asset) into previous_state from public.serialized_assets asset where asset.id=action_record.related_record_id for update;
      if previous_state is null then raise exception using errcode='P0002',message='sanction_target_not_found'; end if;
      if (previous_state->>'status') in ('retired','destroyed','seized') or exists(select 1 from public.asset_reservations reservation where reservation.asset_id=action_record.related_record_id and reservation.status='active') then
        raise exception using errcode='22023',message='sanction_asset_not_seizable'; end if;
      update public.serialized_assets as asset set status='seized',version=asset.version+1 where asset.id=action_record.related_record_id returning to_jsonb(asset.*) into next_state;
    end if;
    insert into public.compliance_effect_executions(compliance_action_id,effect_mode,target_record_type,target_record_id,
      previous_state,new_state,applied_by_actor_id,request_id)
    values(action_record.id,action_record.effect_mode,action_record.related_record_type,action_record.related_record_id,
      previous_state,next_state,actor_id,p_request_id);
  end if;
  update public.compliance_actions action set status=p_status,reviewed_by_actor_id=actor_id,reviewed_at=statement_timestamp(),
    review_reason=btrim(p_reason),review_request_id=p_request_id,
    effect_applied=(p_status='approved' and action_record.effect_mode<>'record_only'),version=action.version+1
  where action.id=p_compliance_action_id returning action.* into action_record;
  insert into public.compliance_events(compliance_case_id,event_type,related_record_type,related_record_id,previous_state,new_state,changed_by_actor_id,reason,request_id)
  values(action_record.compliance_case_id,'action_reviewed','compliance_action',action_record.id,
    jsonb_build_object('status','recommended'),jsonb_build_object('status',p_status,'effect_applied',action_record.effect_applied),
    actor_id,btrim(p_reason),p_request_id);
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('compliance.action_reviewed','compliance_action',action_record.id,
    jsonb_build_object('public_reference',action_record.public_reference,'status',p_status,'effect_applied',action_record.effect_applied),
    'compliance.action_reviewed:'||p_request_id::text);
  return query select action_record.id,action_record.version,action_record.status,action_record.effect_applied;
end;
$$;

create function public.staff_generate_document_snapshot(
  p_document_type text,p_source_record_id uuid,p_reason text,p_request_id uuid
)
returns table(document_id uuid,public_reference text,checksum_sha256 text)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing record; payload jsonb; source_type text; source_version bigint; created record;
begin
  actor_id:=private.set_staff_audit_context('document.generate',p_reason,p_request_id);
  select document.id,document.public_reference,document.checksum_sha256 into existing
  from public.generated_documents document where document.source_request_id=p_request_id;
  if found then return query select existing.id,existing.public_reference,existing.checksum_sha256; return; end if;
  if p_document_type='license_certificate' then
    source_type:='license';
    select license.version,jsonb_build_object(
      'document_title','East Empire Company License','license_reference',license.public_reference,
      'holder_name',party.display_name,'class_name',class.public_display_name,'jurisdiction',jurisdiction.public_name,
      'status',status.display_name,'issued_at',license.issued_at,'effective_from',license.effective_from,'expires_at',license.expires_at,
      'endorsements',coalesce((select jsonb_agg(definition.public_display_name order by definition.public_display_name)
        from public.license_endorsements endorsement join public.endorsement_definitions definition on definition.id=endorsement.endorsement_definition_id
        where endorsement.license_id=license.id and endorsement.revoked_at is null),'[]'::jsonb),
      'public_notes',license.public_notes
    ) into source_version,payload
    from public.licenses license join public.parties party on party.id=license.holder_party_id
    join public.license_classes class on class.id=license.license_class_id
    join public.jurisdictions jurisdiction on jurisdiction.id=license.jurisdiction_id
    join public.license_status_definitions status on status.id=license.status_definition_id where license.id=p_source_record_id;
  elsif p_document_type='order_confirmation' then
    source_type:='order';
    select order_item.version,jsonb_build_object(
      'document_title','East Empire Company Order Confirmation','order_reference',order_item.public_reference,
      'customer_name',party.display_name,'source_channel',order_item.source_channel,'status',order_item.status,
      'currency_code',order_item.currency_code,'submitted_at',order_item.submitted_at,'fulfillment_mode',order_item.fulfillment_mode,
      'lines',coalesce((select jsonb_agg(jsonb_build_object('line',line.line_number,'item_code',line.item_code_snapshot,
        'item_name',line.item_name_snapshot,'quantity',line.quantity_requested,'unit',line.unit_code_snapshot,
        'unit_price_minor',line.unit_price_minor_snapshot,'price_source',line.price_source_snapshot,'multiplier_basis_points',line.price_multiplier_basis_points_snapshot)
        order by line.line_number) from public.order_lines line where line.order_id=order_item.id),'[]'::jsonb)
    ) into source_version,payload from public.orders order_item join public.parties party on party.id=order_item.ordering_party_id
    where order_item.id=p_source_record_id;
  elsif p_document_type='unique_fulfillment_receipt' then
    source_type:='unique_fulfillment'; source_version:=1;
    select jsonb_build_object('document_title','East Empire Company Unique Asset Fulfillment Receipt',
      'fulfillment_reference',fulfillment.public_reference,'asset_reference',asset.public_reference,'item_name',item.display_name,
      'serial_marking',asset.serial_marking,'order_reference',order_item.public_reference,'recipient_name',party.display_name,
      'fulfilled_at',fulfillment.fulfilled_at,'reason',fulfillment.reason)
    into payload from public.unique_fulfillments fulfillment join public.serialized_assets asset on asset.id=fulfillment.asset_id
    join public.items item on item.id=asset.item_id join public.order_lines line on line.id=fulfillment.order_line_id
    join public.orders order_item on order_item.id=line.order_id join public.parties party on party.id=fulfillment.recipient_party_id
    where fulfillment.id=p_source_record_id;
  elsif p_document_type='consignment_statement' then
    source_type:='consignment_settlement';
    select settlement.version,jsonb_build_object('document_title','East Empire Company Consignment Settlement Statement',
      'settlement_reference',settlement.public_reference,'report_reference',report.public_reference,
      'owner_name',owner.display_name,'consignee_name',consignee.display_name,'quantity_sold',settlement.quantity_sold,
      'unit_sale_price_minor',settlement.unit_sale_price_minor,'gross_amount_minor',settlement.gross_amount_minor,
      'commission_amount_minor',settlement.commission_amount_minor,'owner_amount_minor',settlement.owner_amount_minor,
      'currency_code',settlement.currency_code,'status',settlement.status,'payment_reference',settlement.payment_reference)
    into source_version,payload from public.consignment_settlements settlement
    join public.consignment_reports report on report.id=settlement.consignment_report_id
    join public.consignment_issues issue on issue.id=report.consignment_issue_id
    join public.consignment_agreements agreement on agreement.id=issue.agreement_id
    join public.parties owner on owner.id=agreement.owner_party_id join public.parties consignee on consignee.id=agreement.consignee_party_id
    where settlement.id=p_source_record_id;
  else raise exception using errcode='22023',message='generated_document_type_invalid';
  end if;
  if payload is null then raise exception using errcode='P0002',message='generated_document_source_not_found'; end if;
  insert into public.generated_documents(public_reference,document_type,source_record_type,source_record_id,source_version,
    snapshot_payload,checksum_sha256,generated_by_actor_id,source_request_id)
  values(private.allocate_launch_reference('generated_document'),p_document_type,source_type,p_source_record_id,source_version,
    payload,encode(extensions.digest(payload::text,'sha256'),'hex'),actor_id,p_request_id) returning * into created;
  insert into public.outbox_events(event_type,aggregate_type,aggregate_id,payload,deduplication_key)
  values('document.generated','generated_document',created.id,
    jsonb_build_object('public_reference',created.public_reference,'document_type',created.document_type,'checksum_sha256',created.checksum_sha256),
    'document.generated:'||p_request_id::text);
  return query select created.id,created.public_reference,created.checksum_sha256;
end;
$$;

create function public.get_staff_generated_documents()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('document.private.read');
  return coalesce((select jsonb_agg(jsonb_build_object('id',document.id,'public_reference',document.public_reference,
    'document_type',document.document_type,'source_record_type',document.source_record_type,'source_record_id',document.source_record_id,
    'source_version',document.source_version,'checksum_sha256',document.checksum_sha256,'generated_at',document.generated_at)
    order by document.generated_at desc) from public.generated_documents document),'[]'::jsonb);
end $$;

create function public.get_staff_generated_document(p_document_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ declare result jsonb; begin
  perform 1 from private.require_staff_permission('document.private.read');
  select jsonb_build_object('id',document.id,'public_reference',document.public_reference,'document_type',document.document_type,
    'source_record_type',document.source_record_type,'source_record_id',document.source_record_id,'source_version',document.source_version,
    'snapshot_payload',document.snapshot_payload,'checksum_sha256',document.checksum_sha256,'generated_at',document.generated_at)
  into result from public.generated_documents document where document.id=p_document_id;
  return result;
end $$;

create function public.get_staff_command_dashboard()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('dashboard.read');
  return jsonb_build_object(
    'generated_at',statement_timestamp(),
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
      from public.audit_log audit order by audit.occurred_at desc limit 12) recent),'[]'::jsonb) else '[]'::jsonb end
  );
end $$;

create function public.get_staff_launch_workspace()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('dashboard.read');
  return jsonb_build_object(
    'capabilities',jsonb_build_object(
      'can_create_order',private.staff_has_permission('order.assisted.create'),
      'can_review_applications',private.staff_has_permission('license.application.review'),
      'can_manage_finance',private.staff_has_permission('consignment.finance.manage'),
      'can_manage_pricing',private.staff_has_permission('pricing.binding.manage'),
      'can_fulfill_asset',private.staff_has_permission('asset.fulfill'),
      'can_generate_documents',private.staff_has_permission('document.generate')),
    'jurisdictions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'label',public_name) order by public_name) from public.jurisdictions where status='active'),'[]'::jsonb),
    'items',coalesce((select jsonb_agg(jsonb_build_object('id',item.id,'code',item.item_code,'name',publication.public_name,'unit',unit.code,
      'direct_allowed',coalesce(policy.direct_individual_allowed,false),'direct_weekly_limit',policy.direct_weekly_limit) order by publication.public_name)
      from public.items item join public.units_of_measure unit on unit.id=item.unit_id
      join public.item_publications publication on publication.item_id=item.id and publication.audience_code='public' and publication.publication_status='published'
        and publication.effective_from<=statement_timestamp() and (publication.effective_until is null or publication.effective_until>statement_timestamp())
      left join public.item_supply_policies policy on policy.item_id=item.id where item.status='active'),'[]'::jsonb),
    'businesses',case when private.staff_has_permission('order.assisted.create') then coalesce((select jsonb_agg(jsonb_build_object(
      'party_id',party.id,'party_name',party.display_name,'dealer_authorization_id',dealer.id,'dealer_reference',dealer.public_reference,
      'jurisdiction_id',dealer.jurisdiction_id,'licenses',coalesce((select jsonb_agg(jsonb_build_object('id',license.id,'reference',license.public_reference,'class',class.public_display_name)
        order by license.public_reference) from public.licenses license join public.license_classes class on class.id=license.license_class_id
        join public.license_status_definitions license_status on license_status.id=license.status_definition_id
        where license.dealer_authorization_id=dealer.id and license_status.confers_authority and license.effective_from<=statement_timestamp()
          and (license.expires_at is null or license.expires_at>statement_timestamp())),'[]'::jsonb)) order by party.display_name)
      from public.dealer_authorizations dealer join public.parties party on party.id=dealer.dealer_party_id
      join public.dealer_status_definitions status on status.id=dealer.status_definition_id
      where status.confers_authority and dealer.effective_from<=statement_timestamp() and (dealer.effective_until is null or dealer.effective_until>statement_timestamp())),'[]'::jsonb) else '[]'::jsonb end,
    'direct_customers',case when private.staff_has_permission('order.assisted.create') then coalesce((select jsonb_agg(jsonb_build_object('party_id',party.id,'name',party.display_name,'reference',profile.public_reference)
      order by party.display_name) from public.direct_customer_profiles profile join public.parties party on party.id=profile.party_id where party.status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'applications',case when private.staff_has_permission('license.application.review') then coalesce((select jsonb_agg(jsonb_build_object(
      'id',application.id,'reference',application.public_reference,'type',application.application_type,'applicant_name',application.applicant_name,
      'contact_label',application.contact_label,'class_name',class.public_display_name,'jurisdiction_name',jurisdiction.public_name,
      'statement',application.statement,'status',application.status,'version',application.version,'submitted_at',application.submitted_at,
      'existing_license_reference',license.public_reference) order by application.submitted_at)
      from public.license_applications application join public.license_classes class on class.id=application.requested_license_class_id
      join public.jurisdictions jurisdiction on jurisdiction.id=application.requested_jurisdiction_id
      left join public.licenses license on license.id=application.existing_license_id where application.status in ('submitted','under_review')),'[]'::jsonb) else '[]'::jsonb end,
    'parties',case when private.staff_has_permission('license.application.review') then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',display_name) order by display_name) from public.parties where status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'settlement_candidates',case when private.staff_has_permission('consignment.finance.manage') then coalesce((select jsonb_agg(jsonb_build_object(
      'report_id',report.id,'report_reference',report.public_reference,'agreement_reference',agreement.public_reference,'quantity_sold',report.quantity_sold)
      order by report.submitted_at) from public.consignment_reports report join public.consignment_issues issue on issue.id=report.consignment_issue_id
      join public.consignment_agreements agreement on agreement.id=issue.agreement_id where report.status='accepted' and report.quantity_sold>0
      and not exists(select 1 from public.consignment_settlements settlement where settlement.consignment_report_id=report.id)),'[]'::jsonb) else '[]'::jsonb end,
    'consignment_agreements',case when private.staff_has_permission('consignment.finance.manage') then coalesce((select jsonb_agg(jsonb_build_object(
      'id',agreement.id,'label',agreement.public_reference||' - '||owner.display_name||' / '||consignee.display_name)
      order by agreement.public_reference) from public.consignment_agreements agreement join public.parties owner on owner.id=agreement.owner_party_id
      join public.parties consignee on consignee.id=agreement.consignee_party_id where agreement.status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'settlements',case when private.staff_has_permission('consignment.finance.manage') then coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'reference',public_reference,'gross',gross_amount_minor,'commission',commission_amount_minor,'owner_amount',owner_amount_minor,
      'currency',currency_code,'status',status,'version',version) order by created_at desc) from public.consignment_settlements),'[]'::jsonb) else '[]'::jsonb end,
    'unique_reservations',case when private.staff_has_permission('asset.fulfill') then coalesce((select jsonb_agg(jsonb_build_object(
      'reservation_id',reservation.id,'reservation_reference',reservation.public_reference,'reservation_version',reservation.version,
      'asset_id',asset.id,'asset_reference',asset.public_reference,'asset_version',asset.version,'order_reference',order_item.public_reference,
      'customer_name',party.display_name,'expires_at',reservation.expires_at) order by reservation.expires_at)
      from public.asset_reservations reservation join public.serialized_assets asset on asset.id=reservation.asset_id
      join public.order_lines line on line.id=reservation.order_line_id join public.orders order_item on order_item.id=line.order_id
      join public.parties party on party.id=order_item.ordering_party_id where reservation.status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'document_sources',case when private.staff_has_permission('document.generate') then jsonb_build_object(
      'licenses',coalesce((select jsonb_agg(jsonb_build_object('id',license.id,'label',license.public_reference||' - '||party.display_name) order by license.public_reference)
        from public.licenses license join public.parties party on party.id=license.holder_party_id),'[]'::jsonb),
      'orders',coalesce((select jsonb_agg(jsonb_build_object('id',order_item.id,'label',order_item.public_reference||' - '||party.display_name) order by order_item.submitted_at desc)
        from public.orders order_item join public.parties party on party.id=order_item.ordering_party_id),'[]'::jsonb),
      'fulfillments',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',public_reference) order by fulfilled_at desc) from public.unique_fulfillments),'[]'::jsonb),
      'settlements',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',public_reference) order by created_at desc) from public.consignment_settlements),'[]'::jsonb)) else '{}'::jsonb end,
    'price_schedules',case when private.staff_has_permission('pricing.binding.manage') then coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',display_name,'audience',audience_code) order by display_name)
      from public.price_schedules where status<>'retired'),'[]'::jsonb) else '[]'::jsonb end,
    'price_targets',case when private.staff_has_permission('pricing.binding.manage') then jsonb_build_object(
      'parties',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',display_name) order by display_name) from public.parties where status='active'),'[]'::jsonb),
      'license_classes',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',public_display_name) order by public_display_name) from public.license_classes where active),'[]'::jsonb),
      'dealer_types',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',display_name) order by display_name) from public.dealer_types where active),'[]'::jsonb),
      'jurisdictions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',public_name) order by public_name) from public.jurisdictions where status='active'),'[]'::jsonb)) else '{}'::jsonb end
  );
end $$;

create or replace function public.get_staff_order_queue(p_search text default null)
returns table (
  id uuid,public_reference text,ordering_party_id uuid,ordering_party_name text,
  dealer_reference text,license_reference text,fulfillment_mode text,status text,
  currency_code text,dealer_notes text,submitted_at timestamptz,version bigint,lines jsonb
)
language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('order.private.read');
  return query select order_item.id,order_item.public_reference,order_item.ordering_party_id,party.display_name,
    coalesce(dealer.public_reference,case when order_item.source_channel='direct_individual' then 'DIRECT INDIVIDUAL' else 'STAFF ASSISTED' end),
    license.public_reference,order_item.fulfillment_mode,order_item.status,order_item.currency_code,order_item.dealer_notes,
    order_item.submitted_at,order_item.version,
    coalesce((select jsonb_agg(jsonb_build_object('id',line.id,'line_number',line.line_number,'item_code',line.item_code_snapshot,
      'item_name',line.item_name_snapshot,'unit_code',line.unit_code_snapshot,'quantity_requested',line.quantity_requested,
      'quantity_approved',line.quantity_approved,'quantity_fulfilled',line.quantity_fulfilled,'status',line.status,
      'unit_price_minor',line.unit_price_minor_snapshot,'pricing_status',line.pricing_status,
      'control_profile_code',line.control_profile_code_snapshot,'requires_staff_review',line.requires_staff_review_snapshot,
      'requires_transaction_approval',line.requires_transaction_approval_snapshot,'requires_serial_tracking',line.requires_serial_tracking_snapshot,
      'review_reason_codes',line.review_reason_codes,'version',line.version) order by line.line_number)
      from public.order_lines line where line.order_id=order_item.id),'[]'::jsonb)
  from public.orders order_item join public.parties party on party.id=order_item.ordering_party_id
  left join public.dealer_authorizations dealer on dealer.id=order_item.dealer_authorization_id
  left join public.licenses license on license.id=order_item.license_id
  where p_search is null or btrim(p_search)='' or order_item.public_reference ilike '%'||btrim(p_search)||'%'
    or party.display_name ilike '%'||btrim(p_search)||'%'
  order by case order_item.status when 'submitted' then 0 when 'under_review' then 1 when 'awaiting_stock' then 2 else 3 end,
    order_item.submitted_at;
end $$;

create function private.reject_launch_evidence_change()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin raise exception using errcode='55000',message='launch_evidence_is_immutable'; end $$;
create trigger generated_documents_immutable before update or delete on public.generated_documents for each row execute function private.reject_launch_evidence_change();
create trigger license_renewal_events_immutable before update or delete on public.license_renewal_events for each row execute function private.reject_launch_evidence_change();
create trigger unique_fulfillments_immutable before update or delete on public.unique_fulfillments for each row execute function private.reject_launch_evidence_change();
create trigger compliance_effect_executions_immutable before update or delete on public.compliance_effect_executions for each row execute function private.reject_launch_evidence_change();

comment on table public.personal_quota_entries is 'Authoritative weekly personal-limit holds and consumption. Released entries preserve history and do not count against the active window.';
comment on table public.price_schedule_bindings is 'Effective-dated pricing precedence: party, license class, dealer type, jurisdiction, channel default, then unbound audience fallback.';
comment on table public.generated_documents is 'Immutable authoritative source snapshots. Rendered PDFs are projections and carry this checksum.';
comment on table public.consignment_settlements is 'Operational commission and payment evidence. This is not a general ledger or treasury balance.';
comment on table public.compliance_effect_executions is 'Exact previous/new state for an approved configured sanction applied atomically with action review.';

revoke all on public.commercial_channel_policies,public.price_schedule_bindings,public.direct_customer_profiles,
  public.personal_quota_entries,public.license_applications,public.license_application_endorsements,
  public.license_renewal_events,public.consignment_finance_terms,public.consignment_settlements,
  public.unique_fulfillments,public.generated_documents,public.compliance_effect_executions from anon,authenticated;

revoke all on function private.allocate_launch_reference(text) from public,anon,authenticated;
revoke all on function private.resolve_trade_price(text,uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function private.apply_order_line_trade_terms() from public,anon,authenticated;
revoke all on function private.record_order_line_quota() from public,anon,authenticated;
revoke all on function private.sync_order_line_quota() from public,anon,authenticated;
revoke all on function private.reject_launch_evidence_change() from public,anon,authenticated;

revoke all on function public.public_submit_license_application(text,text,text,text,text,text,text[],text,uuid) from public,authenticated;
revoke all on function public.public_get_license_application_status(text,text) from public,authenticated;
revoke all on function public.get_public_license_application_options() from public,authenticated;
grant execute on function public.public_submit_license_application(text,text,text,text,text,text,text[],text,uuid) to anon;
grant execute on function public.public_get_license_application_status(text,text) to anon;
grant execute on function public.get_public_license_application_options() to anon;
grant execute on function public.public_submit_license_application(text,text,text,text,text,text,text[],text,uuid) to authenticated;
grant execute on function public.public_get_license_application_status(text,text) to authenticated;
grant execute on function public.get_public_license_application_options() to authenticated;

revoke all on function public.staff_create_trade_order(text,uuid,text,text,uuid,uuid,uuid,text,text,jsonb,text,uuid) from public,anon;
revoke all on function public.staff_decide_license_application(uuid,bigint,text,uuid,timestamptz,timestamptz,text,text,uuid) from public,anon;
revoke all on function public.staff_configure_price_binding(uuid,text,uuid,text,integer,timestamptz,timestamptz,text,uuid) from public,anon;
revoke all on function public.staff_configure_consignment_finance_terms(uuid,text,integer,timestamptz,timestamptz,text,uuid) from public,anon;
revoke all on function public.staff_create_consignment_settlement(uuid,bigint,text,uuid) from public,anon;
revoke all on function public.staff_mark_consignment_settlement_paid(uuid,bigint,text,text,uuid) from public,anon;
revoke all on function public.staff_fulfill_unique_asset(uuid,bigint,bigint,text,uuid) from public,anon;
revoke all on function public.staff_generate_document_snapshot(text,uuid,text,uuid) from public,anon;
revoke all on function public.get_staff_generated_documents() from public,anon;
revoke all on function public.get_staff_generated_document(uuid) from public,anon;
revoke all on function public.get_staff_command_dashboard() from public,anon;
revoke all on function public.get_staff_launch_workspace() from public,anon;

grant execute on function public.staff_create_trade_order(text,uuid,text,text,uuid,uuid,uuid,text,text,jsonb,text,uuid) to authenticated;
grant execute on function public.staff_decide_license_application(uuid,bigint,text,uuid,timestamptz,timestamptz,text,text,uuid) to authenticated;
grant execute on function public.staff_configure_price_binding(uuid,text,uuid,text,integer,timestamptz,timestamptz,text,uuid) to authenticated;
grant execute on function public.staff_configure_consignment_finance_terms(uuid,text,integer,timestamptz,timestamptz,text,uuid) to authenticated;
grant execute on function public.staff_create_consignment_settlement(uuid,bigint,text,uuid) to authenticated;
grant execute on function public.staff_mark_consignment_settlement_paid(uuid,bigint,text,text,uuid) to authenticated;
grant execute on function public.staff_fulfill_unique_asset(uuid,bigint,bigint,text,uuid) to authenticated;
grant execute on function public.staff_generate_document_snapshot(text,uuid,text,uuid) to authenticated;
grant execute on function public.get_staff_generated_documents() to authenticated;
grant execute on function public.get_staff_generated_document(uuid) to authenticated;
grant execute on function public.get_staff_command_dashboard() to authenticated;
grant execute on function public.get_staff_launch_workspace() to authenticated;
