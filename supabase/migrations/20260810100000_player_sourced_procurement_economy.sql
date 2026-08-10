create table public.item_supply_policies (
  id uuid primary key default extensions.gen_random_uuid(),
  item_id uuid not null unique references public.items(id) on delete restrict,
  supply_mode text not null check (supply_mode in (
    'warehouse_stocked', 'player_sourced_reserve', 'made_to_order',
    'limited_release', 'serialized_unique'
  )),
  procurement_enabled boolean not null default false,
  player_sourced_only boolean not null default false,
  admin_receipt_allowed boolean not null default true,
  critical_level numeric(18, 3) check (critical_level is null or critical_level >= 0),
  minimum_level numeric(18, 3) check (minimum_level is null or minimum_level >= 0),
  target_level numeric(18, 3) check (target_level is null or target_level >= 0),
  surplus_level numeric(18, 3) check (surplus_level is null or surplus_level >= 0),
  direct_individual_allowed boolean not null default false,
  direct_weekly_limit numeric(18, 3) check (direct_weekly_limit is null or direct_weekly_limit > 0),
  business_bulk_review_threshold numeric(18, 3)
    check (business_bulk_review_threshold is null or business_bulk_review_threshold > 0),
  configured_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (not player_sourced_only or (procurement_enabled and not admin_receipt_allowed)),
  check (direct_individual_allowed or direct_weekly_limit is null),
  check (critical_level is null or minimum_level is null or critical_level <= minimum_level),
  check (minimum_level is null or target_level is null or minimum_level <= target_level),
  check (target_level is null or surplus_level is null or target_level <= surplus_level)
);

create table public.procurement_suppliers (
  id uuid primary key default extensions.gen_random_uuid(),
  party_id uuid not null unique references public.parties(id) on delete restrict,
  public_reference text not null unique,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  notes text not null default '' check (char_length(notes) <= 2000),
  registered_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.procurement_offers (
  id uuid primary key default extensions.gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete restrict,
  currency_id uuid not null references public.currencies(id) on delete restrict,
  status text not null default 'active' check (status in ('draft', 'active', 'retired')),
  amount_minor bigint not null check (amount_minor > 0),
  minimum_quantity numeric(18, 3) not null default 1 check (minimum_quantity > 0),
  staff_review_quantity numeric(18, 3)
    check (staff_review_quantity is null or staff_review_quantity >= minimum_quantity),
  effective_from timestamptz not null,
  effective_until timestamptz,
  notes text not null default '' check (char_length(notes) <= 2000),
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  exclude using gist (
    item_id with =,
    currency_id with =,
    tstzrange(effective_from, coalesce(effective_until, 'infinity'::timestamptz), '[)') with &&
  ) where (status = 'active')
);

create table public.procurement_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  supplier_id uuid not null references public.procurement_suppliers(id) on delete restrict,
  procurement_offer_id uuid not null references public.procurement_offers(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  stock_location_id uuid not null references public.stock_locations(id) on delete restrict,
  inventory_transaction_id uuid not null unique
    references public.inventory_transactions(id) on delete restrict,
  quantity numeric(18, 3) not null check (quantity > 0),
  amount_minor_per_unit bigint not null check (amount_minor_per_unit > 0),
  total_amount_minor bigint not null check (total_amount_minor > 0),
  currency_code text not null check (currency_code ~ '^[A-Z0-9_]{2,12}$'),
  settlement_status text not null default 'pending' check (settlement_status in ('pending', 'paid')),
  received_at timestamptz not null default now(),
  received_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  settled_at timestamptz,
  settled_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  settlement_reference text,
  source_request_id uuid not null unique,
  settlement_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (total_amount_minor = round(quantity * amount_minor_per_unit)::bigint),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (
    (settlement_status = 'pending' and settled_at is null and settled_by_actor_id is null
      and settlement_reference is null and settlement_request_id is null)
    or
    (settlement_status = 'paid' and settled_at is not null and settled_by_actor_id is not null
      and btrim(settlement_reference) <> '' and settlement_request_id is not null)
  )
);

comment on table public.item_supply_policies is
  'Configurable sourcing and reserve policy. Null thresholds mean policy has not yet set a numeric target.';
comment on table public.procurement_offers is
  'Effective-dated guaranteed purchase offers. An offer is not stock and does not prove delivery.';
comment on table public.procurement_deliveries is
  'Player-supplied goods accepted into custody, atomically linked to an immutable balanced receipt.';
comment on column public.procurement_deliveries.settlement_status is
  'Operational settlement evidence only; it is not a general ledger or treasury balance.';

create index procurement_offers_item_idx
  on public.procurement_offers(item_id, status, effective_from desc);
create index procurement_deliveries_supplier_idx
  on public.procurement_deliveries(supplier_id, received_at desc);
create index procurement_deliveries_item_idx
  on public.procurement_deliveries(item_id, received_at desc);
create index procurement_deliveries_pending_idx
  on public.procurement_deliveries(received_at) where settlement_status = 'pending';

create trigger item_supply_policies_set_updated_at before update on public.item_supply_policies
for each row execute function private.set_updated_at();
create trigger procurement_suppliers_set_updated_at before update on public.procurement_suppliers
for each row execute function private.set_updated_at();
create trigger procurement_offers_set_updated_at before update on public.procurement_offers
for each row execute function private.set_updated_at();
create trigger procurement_deliveries_set_updated_at before update on public.procurement_deliveries
for each row execute function private.set_updated_at();

create trigger item_supply_policies_audit after insert or update or delete on public.item_supply_policies
for each row execute function private.capture_audit_row();
create trigger procurement_suppliers_audit after insert or update or delete on public.procurement_suppliers
for each row execute function private.capture_audit_row();
create trigger procurement_offers_audit after insert or update or delete on public.procurement_offers
for each row execute function private.capture_audit_row();
create trigger procurement_deliveries_audit after insert or update or delete on public.procurement_deliveries
for each row execute function private.capture_audit_row();

alter table public.item_supply_policies enable row level security;
alter table public.procurement_suppliers enable row level security;
alter table public.procurement_offers enable row level security;
alter table public.procurement_deliveries enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  ('economy.dashboard.read', 'Read economy dashboard', 'View reserve coverage, demand pressure, purchasing commitments, and indicative spreads.'),
  ('procurement.supplier.manage', 'Manage procurement suppliers', 'Register player and business suppliers for material intake.'),
  ('procurement.policy.manage', 'Manage supply policy', 'Configure sourcing modes, reserve targets, and purchasing-channel limits.'),
  ('procurement.offer.manage', 'Manage procurement offers', 'Publish effective-dated guaranteed purchase offers.'),
  ('procurement.delivery.receive', 'Receive procurement delivery', 'Accept supplier goods and post the balanced inventory receipt atomically.'),
  ('procurement.delivery.settle', 'Settle procurement delivery', 'Record audited evidence that an accepted delivery was paid.');

insert into public.staff_roles (code, display_name, description)
values
  ('procurement_officer', 'Procurement officer', 'Registers suppliers, receives player-sourced material, and records settlement.'),
  ('economic_steward', 'Economic steward', 'Sets reserve and purchase-offer policy and monitors economic pressure.');

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'procurement_officer'
  and permission.code in (
    'economy.dashboard.read', 'procurement.supplier.manage',
    'procurement.delivery.receive', 'procurement.delivery.settle', 'inventory.position.read'
  )
) or (
  role.code = 'economic_steward'
  and permission.code in (
    'economy.dashboard.read', 'procurement.policy.manage', 'procurement.offer.manage',
    'procurement.supplier.manage'
  )
) or (
  role.code = 'inventory_controller'
  and permission.code in (
    'economy.dashboard.read', 'procurement.delivery.receive', 'procurement.delivery.settle'
  )
);

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values
  ('procurement_supplier', 'EEC-SUP', 1001, 4),
  ('procurement_delivery', 'EEC-PRC', 1001, 4);

create function private.allocate_procurement_reference(p_document_type text)
returns text
language plpgsql volatile security definer set search_path = ''
as $$
declare
  sequence_record record;
  allocated_reference text;
begin
  if p_document_type not in ('procurement_supplier', 'procurement_delivery') then
    raise exception using errcode = '22023', message = 'procurement_reference_type_invalid';
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
  raise exception using errcode = '55000', message = 'procurement_reference_sequence_unavailable';
end;
$$;

create function private.enforce_player_sourced_receipt()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  posting_permission text;
begin
  if new.quantity_delta <= 0 then return new; end if;
  if not exists (
    select 1 from public.inventory_accounts as account
    where account.id = new.inventory_account_id and account.account_kind = 'physical'
  ) then return new; end if;
  select transaction.permission_code into posting_permission
  from public.inventory_transactions as transaction
  where transaction.id = new.inventory_transaction_id;
  if posting_permission = 'inventory.receipt.post' and exists (
    select 1 from public.item_supply_policies as policy
    where policy.item_id = new.item_id and not policy.admin_receipt_allowed
  ) then
    raise exception using errcode = '23514', message = 'player_sourced_procurement_required';
  end if;
  return new;
end;
$$;

create trigger inventory_ledger_player_source_guard
before insert on public.inventory_ledger_entries
for each row execute function private.enforce_player_sourced_receipt();

create function public.staff_upsert_item_supply_policy(
  p_item_id uuid,
  p_supply_mode text,
  p_procurement_enabled boolean,
  p_player_sourced_only boolean,
  p_admin_receipt_allowed boolean,
  p_critical_level numeric,
  p_minimum_level numeric,
  p_target_level numeric,
  p_surplus_level numeric,
  p_direct_individual_allowed boolean,
  p_direct_weekly_limit numeric,
  p_business_bulk_review_threshold numeric,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (policy_id uuid, version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing_policy public.item_supply_policies%rowtype;
begin
  actor_id := private.set_staff_audit_context('procurement.policy.manage', p_reason, p_request_id);
  if not exists (select 1 from public.items where id = p_item_id and status = 'active') then
    raise exception using errcode = 'P0002', message = 'supply_policy_item_not_found';
  end if;
  select * into existing_policy from public.item_supply_policies where item_id = p_item_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> existing_policy.version then
      raise exception using errcode = '40001', message = 'version_conflict';
    end if;
    update public.item_supply_policies as policy set
      supply_mode = p_supply_mode, procurement_enabled = p_procurement_enabled,
      player_sourced_only = p_player_sourced_only, admin_receipt_allowed = p_admin_receipt_allowed,
      critical_level = p_critical_level, minimum_level = p_minimum_level,
      target_level = p_target_level, surplus_level = p_surplus_level,
      direct_individual_allowed = p_direct_individual_allowed,
      direct_weekly_limit = case when p_direct_individual_allowed then p_direct_weekly_limit end,
      business_bulk_review_threshold = p_business_bulk_review_threshold,
      configured_by_actor_id = actor_id, version = policy.version + 1
    where policy.id = existing_policy.id
    returning policy.id, policy.version into policy_id, version;
  else
    if p_expected_version is not null then
      raise exception using errcode = '40001', message = 'version_conflict';
    end if;
    insert into public.item_supply_policies (
      item_id, supply_mode, procurement_enabled, player_sourced_only, admin_receipt_allowed,
      critical_level, minimum_level, target_level, surplus_level,
      direct_individual_allowed, direct_weekly_limit, business_bulk_review_threshold,
      configured_by_actor_id
    ) values (
      p_item_id, p_supply_mode, p_procurement_enabled, p_player_sourced_only, p_admin_receipt_allowed,
      p_critical_level, p_minimum_level, p_target_level, p_surplus_level,
      p_direct_individual_allowed, case when p_direct_individual_allowed then p_direct_weekly_limit end,
      p_business_bulk_review_threshold, actor_id
    ) returning item_supply_policies.id, item_supply_policies.version into policy_id, version;
  end if;
  return next;
end;
$$;

create function public.staff_register_procurement_supplier(
  p_party_type_code text,
  p_legal_name text,
  p_display_name text,
  p_jurisdiction_id uuid,
  p_notes text,
  p_reason text,
  p_request_id uuid
)
returns table (supplier_id uuid, party_id uuid, public_reference text)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing_supplier public.procurement_suppliers%rowtype;
begin
  actor_id := private.set_staff_audit_context('procurement.supplier.manage', p_reason, p_request_id);
  select * into existing_supplier from public.procurement_suppliers where source_request_id = p_request_id;
  if found then
    supplier_id := existing_supplier.id; party_id := existing_supplier.party_id;
    public_reference := existing_supplier.public_reference; return next; return;
  end if;
  if btrim(coalesce(p_legal_name, '')) = '' or btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'supplier_name_required';
  end if;
  insert into public.parties (
    party_type_id, legal_name, display_name, public_display_name,
    primary_jurisdiction_id, public_profile_enabled
  ) values (
    (select id from public.party_types where code = p_party_type_code),
    btrim(p_legal_name), btrim(p_display_name), null, p_jurisdiction_id, false
  ) returning id into party_id;
  insert into public.procurement_suppliers (
    party_id, public_reference, notes, registered_by_actor_id, source_request_id
  ) values (
    party_id, private.allocate_procurement_reference('procurement_supplier'),
    btrim(coalesce(p_notes, '')), actor_id, p_request_id
  ) returning procurement_suppliers.id, procurement_suppliers.public_reference into supplier_id, public_reference;
  return next;
exception when not_null_violation then
  raise exception using errcode = '22023', message = 'supplier_reference_data_invalid';
end;
$$;

create function public.staff_create_procurement_offer(
  p_item_id uuid,
  p_currency_id uuid,
  p_amount_minor bigint,
  p_minimum_quantity numeric,
  p_staff_review_quantity numeric,
  p_effective_from timestamptz,
  p_effective_until timestamptz,
  p_notes text,
  p_reason text,
  p_request_id uuid
)
returns table (offer_id uuid, version bigint)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; existing_offer public.procurement_offers%rowtype;
begin
  actor_id := private.set_staff_audit_context('procurement.offer.manage', p_reason, p_request_id);
  select * into existing_offer from public.procurement_offers where source_request_id = p_request_id;
  if found then offer_id := existing_offer.id; version := existing_offer.version; return next; return; end if;
  if not exists (
    select 1 from public.item_supply_policies
    where item_id = p_item_id and procurement_enabled
  ) then raise exception using errcode = '22023', message = 'procurement_not_enabled'; end if;
  insert into public.procurement_offers (
    item_id, currency_id, amount_minor, minimum_quantity, staff_review_quantity,
    effective_from, effective_until, notes, created_by_actor_id, source_request_id
  ) values (
    p_item_id, p_currency_id, p_amount_minor, p_minimum_quantity,
    p_staff_review_quantity, p_effective_from, p_effective_until,
    btrim(coalesce(p_notes, '')), actor_id, p_request_id
  ) returning procurement_offers.id, procurement_offers.version into offer_id, version;
  return next;
end;
$$;

create function public.staff_record_procurement_delivery(
  p_supplier_id uuid,
  p_procurement_offer_id uuid,
  p_stock_location_id uuid,
  p_quantity numeric,
  p_reason text,
  p_request_id uuid
)
returns table (
  delivery_id uuid, public_reference text, inventory_transaction_id uuid,
  quantity numeric, total_amount_minor bigint, currency_code text
)
language plpgsql volatile security definer set search_path = ''
as $$
declare
  actor_id uuid; supplier_record record; offer_record record; location_record record;
  existing_delivery public.procurement_deliveries%rowtype;
  physical_account_id uuid; external_account_id uuid; created_transaction_id uuid;
  created_delivery_id uuid; created_reference text; computed_total bigint;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode = '22023', message = 'procurement_quantity_invalid';
  end if;
  select * into existing_delivery from public.procurement_deliveries where source_request_id = p_request_id;
  if found then
    delivery_id := existing_delivery.id; public_reference := existing_delivery.public_reference;
    inventory_transaction_id := existing_delivery.inventory_transaction_id;
    quantity := existing_delivery.quantity; total_amount_minor := existing_delivery.total_amount_minor;
    currency_code := existing_delivery.currency_code; return next; return;
  end if;
  select supplier.id, supplier.party_id into supplier_record
  from public.procurement_suppliers supplier where supplier.id = p_supplier_id and supplier.status = 'active';
  if not found then raise exception using errcode = 'P0002', message = 'procurement_supplier_not_found'; end if;
  select offer.*, currency.code as currency_code into offer_record
  from public.procurement_offers offer join public.currencies currency on currency.id = offer.currency_id and currency.active
  join public.item_supply_policies policy on policy.item_id = offer.item_id and policy.procurement_enabled
  where offer.id = p_procurement_offer_id and offer.status = 'active'
    and offer.effective_from <= statement_timestamp()
    and (offer.effective_until is null or offer.effective_until > statement_timestamp());
  if not found then raise exception using errcode = 'P0002', message = 'procurement_offer_not_active'; end if;
  if p_quantity < offer_record.minimum_quantity then
    raise exception using errcode = '22023', message = 'procurement_minimum_not_met';
  end if;
  select location.id, location.warehouse_id, warehouse.operating_party_id,
    case location.location_type when 'available' then 'available' else 'receiving' end as stock_state
  into location_record
  from public.stock_locations location join public.warehouses warehouse
    on warehouse.id = location.warehouse_id and warehouse.status = 'active'
  where location.id = p_stock_location_id and location.active
    and location.location_type in ('receiving', 'available');
  if not found then raise exception using errcode = 'P0002', message = 'procurement_location_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'procurement.delivery.receive', location_record.warehouse_id, p_reason, p_request_id
  );
  insert into public.inventory_accounts (
    item_id, account_kind, owner_party_id, custodian_party_id,
    warehouse_id, stock_location_id, stock_state
  ) values (
    offer_record.item_id, 'physical', location_record.operating_party_id,
    location_record.operating_party_id, location_record.warehouse_id,
    location_record.id, location_record.stock_state
  ) on conflict (
    item_id, owner_party_id, custodian_party_id, warehouse_id, stock_location_id, stock_state
  ) where account_kind = 'physical' do nothing;
  select account.id into strict physical_account_id from public.inventory_accounts account
  where account.item_id = offer_record.item_id and account.account_kind = 'physical'
    and account.owner_party_id = location_record.operating_party_id
    and account.custodian_party_id = location_record.operating_party_id
    and account.warehouse_id = location_record.warehouse_id
    and account.stock_location_id = location_record.id and account.stock_state = location_record.stock_state;
  insert into public.inventory_accounts (item_id, account_kind, stock_state)
  values (offer_record.item_id, 'external', 'external_source')
  on conflict (item_id) where account_kind = 'external' do nothing;
  select account.id into strict external_account_id from public.inventory_accounts account
  where account.item_id = offer_record.item_id and account.account_kind = 'external';
  perform 1 from public.inventory_accounts account
  where account.id in (physical_account_id, external_account_id) order by account.id for update;
  created_reference := private.allocate_procurement_reference('procurement_delivery');
  insert into public.inventory_transactions (
    transaction_type, occurred_at, posted_by_actor_id, permission_code,
    source_reference, reason, request_id
  ) values (
    'receipt', statement_timestamp(), actor_id, 'procurement.delivery.receive',
    created_reference, btrim(p_reason), p_request_id
  ) returning id into created_transaction_id;
  insert into public.inventory_ledger_entries (
    inventory_transaction_id, line_number, inventory_account_id, item_id, quantity_delta
  ) values
    (created_transaction_id, 1, external_account_id, offer_record.item_id, -p_quantity),
    (created_transaction_id, 2, physical_account_id, offer_record.item_id, p_quantity);
  computed_total := round(p_quantity * offer_record.amount_minor)::bigint;
  insert into public.procurement_deliveries (
    public_reference, supplier_id, procurement_offer_id, item_id, warehouse_id,
    stock_location_id, inventory_transaction_id, quantity, amount_minor_per_unit,
    total_amount_minor, currency_code, received_by_actor_id, source_request_id
  ) values (
    created_reference, p_supplier_id, p_procurement_offer_id, offer_record.item_id,
    location_record.warehouse_id, location_record.id, created_transaction_id, p_quantity,
    offer_record.amount_minor, computed_total, offer_record.currency_code, actor_id, p_request_id
  ) returning id into created_delivery_id;
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'procurement.delivery_received', 'procurement_delivery', created_delivery_id,
    jsonb_build_object(
      'delivery_id', created_delivery_id, 'public_reference', created_reference,
      'supplier_id', p_supplier_id, 'item_id', offer_record.item_id,
      'quantity', p_quantity, 'total_amount_minor', computed_total,
      'currency_code', offer_record.currency_code, 'warehouse_id', location_record.warehouse_id
    ), 'procurement.delivery_received:' || p_request_id::text
  );
  delivery_id := created_delivery_id; public_reference := created_reference;
  inventory_transaction_id := created_transaction_id; quantity := p_quantity;
  total_amount_minor := computed_total; currency_code := offer_record.currency_code;
  return next;
end;
$$;

create function public.staff_mark_procurement_delivery_paid(
  p_delivery_id uuid,
  p_expected_version bigint,
  p_settlement_reference text,
  p_reason text,
  p_request_id uuid
)
returns table (delivery_id uuid, version bigint, settlement_status text)
language plpgsql volatile security definer set search_path = ''
as $$
declare actor_id uuid; delivery_record public.procurement_deliveries%rowtype;
begin
  actor_id := private.set_staff_audit_context('procurement.delivery.settle', p_reason, p_request_id);
  select * into delivery_record from public.procurement_deliveries where id = p_delivery_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'procurement_delivery_not_found'; end if;
  if delivery_record.settlement_request_id = p_request_id then
    delivery_id := delivery_record.id; version := delivery_record.version;
    settlement_status := delivery_record.settlement_status; return next; return;
  end if;
  if delivery_record.settlement_status <> 'pending' then
    raise exception using errcode = '22023', message = 'procurement_delivery_already_settled';
  end if;
  if delivery_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'version_conflict';
  end if;
  if btrim(coalesce(p_settlement_reference, '')) = '' then
    raise exception using errcode = '22023', message = 'settlement_reference_required';
  end if;
  update public.procurement_deliveries delivery set
    settlement_status = 'paid', settled_at = statement_timestamp(),
    settled_by_actor_id = actor_id, settlement_reference = btrim(p_settlement_reference),
    settlement_request_id = p_request_id, version = delivery.version + 1
  where delivery.id = p_delivery_id
  returning delivery.id, delivery.version, delivery.settlement_status
    into delivery_id, version, settlement_status;
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'procurement.delivery_paid', 'procurement_delivery', p_delivery_id,
    jsonb_build_object('delivery_id', p_delivery_id, 'settlement_reference', btrim(p_settlement_reference)),
    'procurement.delivery_paid:' || p_request_id::text
  );
  return next;
end;
$$;

create function public.get_staff_economy_workspace()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('economy.dashboard.read');
  return jsonb_build_object(
    'generated_at', statement_timestamp(),
    'positions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'item_id', item.id, 'item_code', item.item_code, 'item_name', item.display_name,
        'unit_code', unit.code, 'supply_mode', policy.supply_mode,
        'procurement_enabled', policy.procurement_enabled,
        'player_sourced_only', policy.player_sourced_only,
        'admin_receipt_allowed', policy.admin_receipt_allowed,
        'critical_level', policy.critical_level, 'minimum_level', policy.minimum_level,
        'target_level', policy.target_level, 'surplus_level', policy.surplus_level,
        'direct_individual_allowed', policy.direct_individual_allowed,
        'direct_weekly_limit', policy.direct_weekly_limit,
        'business_bulk_review_threshold', policy.business_bulk_review_threshold,
        'policy_version', policy.version,
        'on_hand', coalesce(stock.on_hand, 0),
        'reserved', coalesce(stock.reserved, 0),
        'available', coalesce(stock.available, 0),
        'backordered', coalesce(demand.backordered, 0),
        'procured_7d', coalesce(procurement.procured_7d, 0),
        'committed_7d_minor', coalesce(procurement.committed_7d_minor, 0),
        'paid_7d_minor', coalesce(procurement.paid_7d_minor, 0),
        'reserve_state', case
          when policy.target_level is null then 'unconfigured'
          when coalesce(stock.available, 0) <= coalesce(policy.critical_level, 0) then 'critical'
          when policy.minimum_level is not null and coalesce(stock.available, 0) < policy.minimum_level then 'below_minimum'
          when policy.surplus_level is not null and coalesce(stock.available, 0) >= policy.surplus_level then 'surplus'
          when coalesce(stock.available, 0) >= policy.target_level then 'target_met'
          else 'building'
        end
      ) order by item.display_name)
      from public.items item
      join public.units_of_measure unit on unit.id = item.unit_id
      join public.item_supply_policies policy on policy.item_id = item.id
      left join lateral (
        select
          coalesce(sum(entry.quantity_delta) filter (where account.account_kind = 'physical'), 0) as on_hand,
          coalesce(sum(entry.quantity_delta) filter (
            where account.account_kind = 'physical' and account.stock_state = 'available'
          ), 0) - coalesce((
            select sum(reservation.quantity) from public.reservations reservation
            join public.inventory_accounts reserved_account on reserved_account.id = reservation.inventory_account_id
            where reserved_account.item_id = item.id and reservation.status = 'active'
              and reservation.expires_at > statement_timestamp()
          ), 0) as available,
          coalesce((
            select sum(reservation.quantity) from public.reservations reservation
            join public.inventory_accounts reserved_account on reserved_account.id = reservation.inventory_account_id
            where reserved_account.item_id = item.id and reservation.status = 'active'
              and reservation.expires_at > statement_timestamp()
          ), 0) as reserved
        from public.inventory_accounts account
        left join public.inventory_ledger_entries entry on entry.inventory_account_id = account.id
        where account.item_id = item.id
      ) stock on true
      left join lateral (
        select coalesce(sum(greatest(
          coalesce(line.quantity_approved, 0) - line.quantity_fulfilled - coalesce(active_claim.quantity, 0), 0
        )), 0) as backordered
        from public.order_lines line join public.orders ordered on ordered.id = line.order_id
        left join lateral (
          select coalesce(sum(reservation.quantity), 0) as quantity
          from public.reservations reservation
          where reservation.order_line_id = line.id and reservation.status = 'active'
            and reservation.expires_at > statement_timestamp()
        ) active_claim on true
        where line.item_id = item.id
          and ordered.status in ('submitted', 'under_review', 'awaiting_stock', 'approved', 'partially_approved', 'processing')
          and line.status in ('approved', 'awaiting_stock')
      ) demand on true
      left join lateral (
        select
          coalesce(sum(delivery.quantity) filter (
            where delivery.received_at >= statement_timestamp() - interval '7 days'
              and reversal.id is null
          ), 0) as procured_7d,
          coalesce(sum(delivery.total_amount_minor) filter (
            where delivery.received_at >= statement_timestamp() - interval '7 days'
              and reversal.id is null
          ), 0) as committed_7d_minor,
          coalesce(sum(delivery.total_amount_minor) filter (
            where delivery.settlement_status = 'paid'
              and delivery.settled_at >= statement_timestamp() - interval '7 days'
              and reversal.id is null
          ), 0) as paid_7d_minor
        from public.procurement_deliveries delivery
        left join public.inventory_transactions reversal
          on reversal.reversal_of_id = delivery.inventory_transaction_id
        where delivery.item_id = item.id
      ) procurement on true
    ), '[]'::jsonb),
    'offers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', offer.id, 'item_id', offer.item_id, 'item_code', item.item_code,
        'item_name', item.display_name, 'unit_code', unit.code,
        'currency_id', currency.id, 'currency_code', currency.code,
        'currency_symbol', currency.symbol, 'amount_minor', offer.amount_minor,
        'minimum_quantity', offer.minimum_quantity,
        'staff_review_quantity', offer.staff_review_quantity,
        'effective_from', offer.effective_from, 'effective_until', offer.effective_until,
        'status', offer.status, 'notes', offer.notes, 'version', offer.version,
        'is_current', offer.status = 'active' and offer.effective_from <= statement_timestamp()
          and (offer.effective_until is null or offer.effective_until > statement_timestamp())
      ) order by offer.effective_from desc)
      from public.procurement_offers offer join public.items item on item.id = offer.item_id
      join public.units_of_measure unit on unit.id = item.unit_id
      join public.currencies currency on currency.id = offer.currency_id
      where offer.status <> 'retired'
    ), '[]'::jsonb),
    'suppliers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', supplier.id, 'party_id', party.id, 'public_reference', supplier.public_reference,
        'display_name', party.display_name, 'legal_name', party.legal_name,
        'party_type_code', party_type.code, 'status', supplier.status,
        'notes', supplier.notes, 'version', supplier.version
      ) order by party.display_name)
      from public.procurement_suppliers supplier join public.parties party on party.id = supplier.party_id
      join public.party_types party_type on party_type.id = party.party_type_id
    ), '[]'::jsonb),
    'deliveries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', delivery.id, 'public_reference', delivery.public_reference,
        'supplier_id', delivery.supplier_id, 'supplier_name', party.display_name,
        'item_id', delivery.item_id, 'item_code', item.item_code, 'item_name', item.display_name,
        'unit_code', unit.code, 'warehouse_name', warehouse.display_name,
        'location_name', location.display_name, 'quantity', delivery.quantity,
        'amount_minor_per_unit', delivery.amount_minor_per_unit,
        'total_amount_minor', delivery.total_amount_minor, 'currency_code', delivery.currency_code,
        'settlement_status', delivery.settlement_status,
        'received_at', delivery.received_at, 'settled_at', delivery.settled_at,
        'settlement_reference', delivery.settlement_reference,
        'version', delivery.version, 'is_reversed', reversal.id is not null
      ) order by delivery.received_at desc)
      from (
        select * from public.procurement_deliveries order by received_at desc limit 100
      ) delivery join public.procurement_suppliers supplier on supplier.id = delivery.supplier_id
      join public.parties party on party.id = supplier.party_id
      join public.items item on item.id = delivery.item_id
      join public.units_of_measure unit on unit.id = item.unit_id
      join public.warehouses warehouse on warehouse.id = delivery.warehouse_id
      join public.stock_locations location on location.id = delivery.stock_location_id
      left join public.inventory_transactions reversal on reversal.reversal_of_id = delivery.inventory_transaction_id
    ), '[]'::jsonb),
    'warehouses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', warehouse.id, 'display_name', warehouse.display_name,
        'locations', coalesce((select jsonb_agg(jsonb_build_object(
          'id', location.id, 'display_name', location.display_name, 'location_type', location.location_type
        ) order by location.display_name) from public.stock_locations location
          where location.warehouse_id = warehouse.id and location.active
            and location.location_type in ('receiving', 'available')), '[]'::jsonb)
      ) order by warehouse.display_name)
      from public.warehouses warehouse where warehouse.status = 'active'
        and exists (select 1 from private.current_staff_warehouse_assignments(
          'procurement.delivery.receive', warehouse.id
        ))
    ), '[]'::jsonb),
    'currencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', currency.id, 'code', currency.code, 'display_name', currency.display_name,
        'symbol', currency.symbol, 'minor_unit_scale', currency.minor_unit_scale
      ) order by currency.display_name) from public.currencies currency where currency.active
    ), '[]'::jsonb),
    'jurisdictions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', jurisdiction.id, 'code', jurisdiction.code, 'display_name', jurisdiction.public_name
      ) order by jurisdiction.public_name) from public.jurisdictions jurisdiction where jurisdiction.status = 'active'
    ), '[]'::jsonb),
    'party_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', party_type.code, 'display_name', party_type.display_name
      ) order by party_type.display_name) from public.party_types party_type where party_type.active
    ), '[]'::jsonb)
  );
end;
$$;

-- Domain vocabulary is configuration. These records can be renamed or extended without code changes.
insert into public.units_of_measure (id, code, display_name, symbol, quantity_scale)
values
  ('ca000000-0000-0000-0000-000000000001', 'material-unit', 'Material unit', 'unit', 0),
  ('ca000000-0000-0000-0000-000000000002', 'garment', 'Garment', 'garment', 0);

insert into public.item_categories (id, code, display_name, description, sort_order)
values
  ('cb000000-0000-0000-0000-000000000001', 'raw-materials', 'Raw materials', 'Keystone inputs purchased from player production and held as real reserves.', 10),
  ('cb000000-0000-0000-0000-000000000002', 'smithed-goods', 'Smithed goods', 'Finished metalwork and smithing products.', 20),
  ('cb000000-0000-0000-0000-000000000003', 'alchemical-goods', 'Alchemical goods', 'Ingredients and prepared alchemical products.', 30),
  ('cb000000-0000-0000-0000-000000000004', 'arcane-goods', 'Arcane goods', 'Arcane services, components, and controlled works.', 40),
  ('cb000000-0000-0000-0000-000000000005', 'tailoring-goods', 'Tailoring goods', 'Textiles and finished garments.', 50);

insert into public.control_profiles (
  id, code, display_name, public_description,
  requires_staff_review, requires_transaction_approval, requires_serial_tracking
) values (
  'cc000000-0000-0000-0000-000000000001', 'ordinary-economic', 'Ordinary economic good',
  'Ordinary trade rules apply. Published purchasing and ordering terms remain subject to current policy.',
  false, false, false
);

insert into public.availability_profiles (
  id, code, display_name, public_description, sort_order
) values (
  'cd000000-0000-0000-0000-000000000001', 'reserve-dependent', 'Reserve dependent',
  'Supply is drawn from goods actually purchased into Company reserves; an order may wait for replenishment.', 15
), (
  'cd000000-0000-0000-0000-000000000002', 'made-to-order', 'Made to order',
  'Orders may be accepted without warehouse stock and fulfilled after production or sourcing.', 25
);

insert into public.items (
  id, item_code, slug, display_name, description, category_id, unit_id, inventory_mode, internal_notes
) values
  ('ce000000-0000-0000-0000-000000000001', 'RM-IRON-ORE', 'iron-ore', 'Iron Ore', 'Unrefined iron ore purchased into the Company reserve.', 'cb000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001', 'fungible', 'Player-sourced keystone material. Never create stock with a generic administrative receipt.'),
  ('ce000000-0000-0000-0000-000000000002', 'RM-STONE', 'building-stone', 'Building Stone', 'Construction stone purchased into the Company reserve.', 'cb000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001', 'fungible', 'Player-sourced keystone material. Never create stock with a generic administrative receipt.'),
  ('ce000000-0000-0000-0000-000000000003', 'RM-LEATHER-ROLL', 'leather-roll', 'Leather Roll', 'Prepared leather purchased into the Company reserve.', 'cb000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001', 'fungible', 'Player-sourced keystone material. Never create stock with a generic administrative receipt.'),
  ('ce000000-0000-0000-0000-000000000004', 'RM-LUMBER', 'construction-lumber', 'Construction Lumber', 'Lumber purchased into the Company reserve.', 'cb000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001', 'fungible', 'Player-sourced keystone material. Never create stock with a generic administrative receipt.'),
  ('ce000000-0000-0000-0000-000000000005', 'RM-CLOTH', 'trade-cloth', 'Trade Cloth', 'General textile material purchased into the Company reserve.', 'cb000000-0000-0000-0000-000000000001', 'ca000000-0000-0000-0000-000000000001', 'fungible', 'Player-sourced keystone material. Never create stock with a generic administrative receipt.'),
  ('ce000000-0000-0000-0000-000000000006', 'TG-NOCTURNAL-DRESS', 'nocturnal-dress', 'Nocturnal Dress', 'A specialist finished garment available through licensed wholesale or premium direct ordering.', 'cb000000-0000-0000-0000-000000000005', 'ca000000-0000-0000-0000-000000000002', 'fungible', 'Channel pricing and commission policy remain configurable; no final rate is assumed by this migration.');

insert into public.item_publications (
  item_id, audience_code, publication_status, public_name, public_description,
  control_profile_id, availability_profile_id, requirement_summary,
  bulk_minimum, order_increment, effective_from
)
select item.id, 'public', 'published', item.display_name, item.description,
  'cc000000-0000-0000-0000-000000000001',
  case when item.item_code like 'RM-%' then 'cd000000-0000-0000-0000-000000000001'::uuid
    else 'cd000000-0000-0000-0000-000000000002'::uuid end,
  case when item.item_code like 'RM-%'
    then 'Published reserve availability is informational; staff confirm quantity and current price when ordering.'
    else 'Licensed businesses receive approved wholesale terms. Direct personal requests use separate premium terms and limits.' end,
  null, 1, '2026-08-10T00:00:00Z'
from public.items item where item.id::text like 'ce000000-0000-0000-0000-00000000000%';

insert into public.item_supply_policies (
  item_id, supply_mode, procurement_enabled, player_sourced_only, admin_receipt_allowed
)
select item.id, 'player_sourced_reserve', true, true, false
from public.items item where item.item_code like 'RM-%';

insert into public.item_supply_policies (
  item_id, supply_mode, procurement_enabled, player_sourced_only, admin_receipt_allowed,
  direct_individual_allowed, direct_weekly_limit
) values (
  'ce000000-0000-0000-0000-000000000006', 'made_to_order', false, false, true, true, 1
);

insert into public.endorsement_definitions (
  id, code, display_name, public_display_name, description
) values
  ('cf000000-0000-0000-0000-000000000001', 'raw-materials', 'Raw material trade', 'Raw material trade', 'Authority to purchase or distribute ordinary raw materials under configured conditions.'),
  ('cf000000-0000-0000-0000-000000000002', 'smithing-metalwork', 'Smithing and metalwork', 'Smithing and metalwork', 'Authority for configured smithed goods and metalwork.'),
  ('cf000000-0000-0000-0000-000000000003', 'alchemical-goods', 'Alchemical goods', 'Alchemical goods', 'Authority for configured alchemical goods.'),
  ('cf000000-0000-0000-0000-000000000004', 'arcane-goods', 'Arcane goods', 'Arcane goods', 'Authority for configured arcane goods.'),
  ('cf000000-0000-0000-0000-000000000005', 'tailoring-textiles', 'Tailoring and textiles', 'Tailoring and textiles', 'Authority for configured garments, tailoring, and textiles.'),
  ('cf000000-0000-0000-0000-000000000006', 'bulk-distribution', 'Bulk distribution', 'Bulk distribution', 'Additional authority for quantities at or above configured bulk thresholds.');

revoke all on public.item_supply_policies from anon, authenticated;
revoke all on public.procurement_suppliers from anon, authenticated;
revoke all on public.procurement_offers from anon, authenticated;
revoke all on public.procurement_deliveries from anon, authenticated;
revoke all on function private.allocate_procurement_reference(text) from public, anon, authenticated;
revoke all on function private.enforce_player_sourced_receipt() from public, anon, authenticated;
revoke all on function public.get_staff_economy_workspace() from public, anon;
revoke all on function public.staff_upsert_item_supply_policy(uuid,text,boolean,boolean,boolean,numeric,numeric,numeric,numeric,boolean,numeric,numeric,bigint,text,uuid) from public, anon;
revoke all on function public.staff_register_procurement_supplier(text,text,text,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_create_procurement_offer(uuid,uuid,bigint,numeric,numeric,timestamptz,timestamptz,text,text,uuid) from public, anon;
revoke all on function public.staff_record_procurement_delivery(uuid,uuid,uuid,numeric,text,uuid) from public, anon;
revoke all on function public.staff_mark_procurement_delivery_paid(uuid,bigint,text,text,uuid) from public, anon;

grant execute on function public.get_staff_economy_workspace() to authenticated;
grant execute on function public.staff_upsert_item_supply_policy(uuid,text,boolean,boolean,boolean,numeric,numeric,numeric,numeric,boolean,numeric,numeric,bigint,text,uuid) to authenticated;
grant execute on function public.staff_register_procurement_supplier(text,text,text,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_create_procurement_offer(uuid,uuid,bigint,numeric,numeric,timestamptz,timestamptz,text,text,uuid) to authenticated;
grant execute on function public.staff_record_procurement_delivery(uuid,uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.staff_mark_procurement_delivery_paid(uuid,bigint,text,text,uuid) to authenticated;
