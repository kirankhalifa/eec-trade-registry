create table public.serialized_assets (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  item_id uuid not null references public.items(id) on delete restrict,
  serial_marking text,
  owner_party_id uuid not null references public.parties(id) on delete restrict,
  current_custodian_party_id uuid not null references public.parties(id) on delete restrict,
  current_warehouse_id uuid references public.warehouses(id) on delete restrict,
  current_stock_location_id uuid,
  condition_code text not null default 'unknown'
    check (condition_code in ('excellent', 'good', 'fair', 'damaged', 'unknown')),
  status text not null default 'available'
    check (status in (
      'available', 'reserved', 'in_custody', 'missing',
      'damaged', 'seized', 'retired', 'destroyed'
    )),
  provenance_summary text not null default '' check (char_length(provenance_summary) <= 4000),
  registered_at timestamptz not null default now(),
  registered_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  next_inspection_due_at timestamptz,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (current_stock_location_id, current_warehouse_id)
    references public.stock_locations(id, warehouse_id) on delete restrict,
  check (serial_marking is null or btrim(serial_marking) <> ''),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (
    (current_warehouse_id is null and current_stock_location_id is null)
    or (current_warehouse_id is not null and current_stock_location_id is not null)
  )
);

create unique index serialized_assets_item_serial_idx
  on public.serialized_assets(item_id, lower(serial_marking))
  where serial_marking is not null;
create index serialized_assets_custody_idx
  on public.serialized_assets(current_custodian_party_id, status, updated_at desc);
create index serialized_assets_inspection_due_idx
  on public.serialized_assets(next_inspection_due_at)
  where next_inspection_due_at is not null
    and status not in ('retired', 'destroyed');

create table public.asset_reservations (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  asset_id uuid not null references public.serialized_assets(id) on delete restrict,
  order_line_id uuid not null references public.order_lines(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'released', 'consumed', 'expired')),
  reserved_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  terminated_at timestamptz,
  terminated_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  termination_reason text,
  termination_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > reserved_at),
  check (
    (status = 'active' and terminated_at is null and terminated_by_actor_id is null and termination_reason is null)
    or (
      status <> 'active'
      and terminated_at is not null
      and terminated_by_actor_id is not null
      and btrim(termination_reason) <> ''
    )
  )
);

create unique index asset_reservations_one_active_asset_idx
  on public.asset_reservations(asset_id) where status = 'active';
create unique index asset_reservations_one_active_line_idx
  on public.asset_reservations(order_line_id) where status = 'active';
create index asset_reservations_expiry_idx
  on public.asset_reservations(expires_at) where status = 'active';

create table public.asset_events (
  id uuid primary key default extensions.gen_random_uuid(),
  asset_id uuid not null references public.serialized_assets(id) on delete restrict,
  event_type text not null check (event_type in (
    'registered', 'reserved', 'reservation_released', 'reservation_expired',
    'reservation_consumed', 'custody_transferred', 'inspection_recorded',
    'condition_changed', 'status_changed', 'missing', 'recovered',
    'seized', 'retired', 'destroyed'
  )),
  occurred_at timestamptz not null default now(),
  recorded_at timestamptz not null default now(),
  recorded_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  from_custodian_party_id uuid references public.parties(id) on delete restrict,
  to_custodian_party_id uuid references public.parties(id) on delete restrict,
  from_stock_location_id uuid references public.stock_locations(id) on delete restrict,
  to_stock_location_id uuid references public.stock_locations(id) on delete restrict,
  condition_before text,
  condition_after text,
  order_line_id uuid references public.order_lines(id) on delete restrict,
  asset_reservation_id uuid references public.asset_reservations(id) on delete restrict,
  accepted_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  accepted_at timestamptz,
  previous_state jsonb,
  new_state jsonb not null,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check ((accepted_at is null and accepted_by_actor_id is null) or (accepted_at is not null and accepted_by_actor_id is not null))
);

create index asset_events_asset_idx on public.asset_events(asset_id, occurred_at, id);

create table public.asset_inspections (
  id uuid primary key default extensions.gen_random_uuid(),
  asset_id uuid not null references public.serialized_assets(id) on delete restrict,
  inspected_at timestamptz not null,
  inspected_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  custodian_party_id uuid not null references public.parties(id) on delete restrict,
  stock_location_id uuid references public.stock_locations(id) on delete restrict,
  condition_code text not null
    check (condition_code in ('excellent', 'good', 'fair', 'damaged', 'unknown')),
  observation text not null check (btrim(observation) <> '' and char_length(observation) <= 4000),
  next_due_at timestamptz,
  request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (next_due_at is null or next_due_at > inspected_at)
);

create index asset_inspections_asset_idx on public.asset_inspections(asset_id, inspected_at desc);

create trigger serialized_assets_set_updated_at
before update on public.serialized_assets
for each row execute function private.set_updated_at();
create trigger asset_reservations_set_updated_at
before update on public.asset_reservations
for each row execute function private.set_updated_at();
create trigger serialized_assets_audit
after insert or update or delete on public.serialized_assets
for each row execute function private.capture_audit_row();
create trigger asset_reservations_audit
after insert or update or delete on public.asset_reservations
for each row execute function private.capture_audit_row();
create trigger asset_events_immutable
before update or delete on public.asset_events
for each row execute function private.reject_immutable_inventory_change();
create trigger asset_inspections_immutable
before update or delete on public.asset_inspections
for each row execute function private.reject_immutable_inventory_change();

alter table public.serialized_assets enable row level security;
alter table public.asset_reservations enable row level security;
alter table public.asset_events enable row level security;
alter table public.asset_inspections enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  ('asset.private.read', 'Read serialized assets', 'View private serialized-asset identity, custody, allocation, condition, and event history.'),
  ('asset.register', 'Register serialized assets', 'Register one serialized good with initial owner, custodian, location, and provenance.'),
  ('asset.reserve', 'Reserve serialized assets', 'Create and release exclusive time-bounded asset allocations for approved unique demand.'),
  ('asset.custody.transfer', 'Transfer serialized asset custody', 'Record an accepted custody transfer while preserving ownership and prior history.'),
  ('asset.inspect', 'Inspect serialized assets', 'Append inspection evidence, condition, and the next due date.'),
  ('asset.lifecycle.manage', 'Manage serialized asset lifecycle', 'Record loss, recovery, damage, seizure, retirement, or destruction with reason.');

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'warehouse_operator'
  and permission.code in (
    'asset.private.read', 'asset.register', 'asset.reserve',
    'asset.custody.transfer', 'asset.inspect'
  )
) or (
  role.code = 'inventory_controller'
  and permission.code like 'asset.%'
) or (
  role.code = 'order_officer'
  and permission.code in ('asset.private.read', 'asset.reserve')
);

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values
  ('serialized_asset', 'EEC-AST', 1001, 4),
  ('asset_reservation', 'EEC-ARV', 1001, 4);

create function private.allocate_asset_reference(p_document_type text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare sequence_record record; allocated_reference text;
begin
  if p_document_type not in ('serialized_asset', 'asset_reservation') then
    raise exception using errcode = '22023', message = 'asset_reference_type_invalid';
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
  raise exception using errcode = '55000', message = 'asset_reference_sequence_unavailable';
end;
$$;

create function private.staff_has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.actor_profiles as actor
    join public.staff_assignments as assignment
      on assignment.actor_id = actor.id
      and assignment.revoked_at is null
      and assignment.effective_from <= statement_timestamp()
      and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    join public.staff_role_permissions as role_permission
      on role_permission.staff_role_id = assignment.staff_role_id
    join public.permission_scopes as permission
      on permission.id = role_permission.permission_scope_id
      and permission.active
      and permission.code = p_permission_code
    where actor.auth_user_id = auth.uid()
      and actor.actor_type = 'staff'
      and actor.status = 'active'
  );
$$;

create function public.get_staff_asset_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.staff_has_permission('asset.private.read') then
    raise exception using errcode = '42501', message = 'staff_permission_denied';
  end if;
  return jsonb_build_object(
    'capabilities', jsonb_build_object(
      'can_register', private.staff_has_permission('asset.register'),
      'can_reserve', private.staff_has_permission('asset.reserve'),
      'can_transfer', private.staff_has_permission('asset.custody.transfer'),
      'can_inspect', private.staff_has_permission('asset.inspect'),
      'can_manage_lifecycle', private.staff_has_permission('asset.lifecycle.manage')
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id, 'item_code', item.item_code, 'display_name', item.display_name
      ) order by item.display_name)
      from public.items as item
      where item.inventory_mode = 'serialized' and item.status = 'active'
    ), '[]'::jsonb),
    'locations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', location.id, 'warehouse_id', warehouse.id,
        'warehouse_name', warehouse.display_name, 'display_name', location.display_name,
        'custodian_party_id', warehouse.operating_party_id
      ) order by warehouse.display_name, location.display_name)
      from public.stock_locations as location
      join public.warehouses as warehouse on warehouse.id = location.warehouse_id
      where location.active and warehouse.status = 'active'
    ), '[]'::jsonb),
    'parties', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', party.id, 'display_name', party.display_name
      ) order by party.display_name)
      from public.parties as party where party.status = 'active'
    ), '[]'::jsonb),
    'order_lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', line.id, 'order_reference', order_record.public_reference,
        'line_number', line.line_number, 'item_id', line.item_id,
        'item_code', line.item_code_snapshot, 'item_name', line.item_name_snapshot,
        'ordering_party_name', party.display_name
      ) order by order_record.submitted_at, line.line_number)
      from public.order_lines as line
      join public.orders as order_record on order_record.id = line.order_id
      join public.parties as party on party.id = order_record.ordering_party_id
      where line.requires_serial_tracking_snapshot
        and line.quantity_approved = 1
        and line.quantity_fulfilled = 0
        and line.status in ('approved', 'awaiting_stock', 'partially_approved')
        and not exists (
          select 1 from public.asset_reservations as reservation
          where reservation.order_line_id = line.id and reservation.status = 'active'
        )
    ), '[]'::jsonb),
    'assets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', asset.id, 'public_reference', asset.public_reference,
        'version', asset.version, 'item_id', asset.item_id,
        'item_code', item.item_code, 'item_name', item.display_name,
        'serial_marking', asset.serial_marking,
        'owner_party_name', owner.display_name,
        'custodian_party_name', custodian.display_name,
        'warehouse_name', warehouse.display_name,
        'location_name', location.display_name,
        'condition_code', asset.condition_code, 'status', asset.status,
        'next_inspection_due_at', asset.next_inspection_due_at,
        'registered_at', asset.registered_at,
        'active_reservation', case when reservation.id is null then null else jsonb_build_object(
          'id', reservation.id, 'public_reference', reservation.public_reference,
          'version', reservation.version, 'expires_at', reservation.expires_at,
          'order_line_id', reservation.order_line_id,
          'order_reference', reserved_order.public_reference
        ) end
      ) order by asset.updated_at desc, asset.id)
      from public.serialized_assets as asset
      join public.items as item on item.id = asset.item_id
      join public.parties as owner on owner.id = asset.owner_party_id
      join public.parties as custodian on custodian.id = asset.current_custodian_party_id
      left join public.warehouses as warehouse on warehouse.id = asset.current_warehouse_id
      left join public.stock_locations as location on location.id = asset.current_stock_location_id
      left join public.asset_reservations as reservation
        on reservation.asset_id = asset.id and reservation.status = 'active'
      left join public.order_lines as reserved_line on reserved_line.id = reservation.order_line_id
      left join public.orders as reserved_order on reserved_order.id = reserved_line.order_id
    ), '[]'::jsonb)
  );
end;
$$;

create function public.staff_register_serialized_asset(
  p_item_id uuid,
  p_stock_location_id uuid,
  p_serial_marking text,
  p_condition_code text,
  p_provenance_summary text,
  p_reason text,
  p_request_id uuid
)
returns table (asset_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; location_record record; existing_asset record;
  created_asset_id uuid; created_reference text; normalized_serial text;
begin
  select location.id, location.warehouse_id, warehouse.operating_party_id,
    item.inventory_mode
  into location_record
  from public.stock_locations as location
  join public.warehouses as warehouse on warehouse.id = location.warehouse_id and warehouse.status = 'active'
  join public.items as item on item.id = p_item_id and item.status = 'active'
  where location.id = p_stock_location_id and location.active;
  if not found then raise exception using errcode = 'P0002', message = 'asset_registration_target_not_found'; end if;
  if location_record.inventory_mode <> 'serialized' then
    raise exception using errcode = '22023', message = 'asset_item_not_serialized';
  end if;
  if p_condition_code not in ('excellent', 'good', 'fair', 'damaged', 'unknown') then
    raise exception using errcode = '22023', message = 'asset_condition_invalid';
  end if;
  if char_length(coalesce(p_provenance_summary, '')) > 4000 then
    raise exception using errcode = '22023', message = 'asset_provenance_invalid';
  end if;
  normalized_serial := nullif(btrim(coalesce(p_serial_marking, '')), '');
  actor_id := private.set_warehouse_audit_context(
    'asset.register', location_record.warehouse_id, p_reason, p_request_id
  );
  select asset.id, asset.public_reference, asset.version, asset.status
  into existing_asset from public.serialized_assets as asset
  where asset.source_request_id = p_request_id;
  if found then
    return query select existing_asset.id, existing_asset.public_reference,
      existing_asset.version, existing_asset.status;
    return;
  end if;
  created_reference := private.allocate_asset_reference('serialized_asset');
  insert into public.serialized_assets (
    public_reference, item_id, serial_marking, owner_party_id,
    current_custodian_party_id, current_warehouse_id, current_stock_location_id,
    condition_code, status, provenance_summary, registered_by_actor_id,
    source_request_id
  ) values (
    created_reference, p_item_id, normalized_serial,
    location_record.operating_party_id, location_record.operating_party_id,
    location_record.warehouse_id, location_record.id, p_condition_code,
    case when p_condition_code = 'damaged' then 'damaged' else 'available' end,
    coalesce(p_provenance_summary, ''), actor_id, p_request_id
  ) returning id into created_asset_id;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id, to_custodian_party_id,
    to_stock_location_id, condition_after, new_state, reason, request_id
  ) values (
    created_asset_id, 'registered', actor_id, location_record.operating_party_id,
    location_record.id, p_condition_code,
    jsonb_build_object('status', case when p_condition_code = 'damaged' then 'damaged' else 'available' end,
      'warehouse_id', location_record.warehouse_id, 'stock_location_id', location_record.id),
    btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'asset.registered', 'serialized_asset', created_asset_id,
    jsonb_build_object('public_reference', created_reference, 'item_id', p_item_id,
      'condition_code', p_condition_code), 'asset.registered:' || p_request_id::text
  );
  return query select created_asset_id, created_reference, 1::bigint,
    case when p_condition_code = 'damaged' then 'damaged' else 'available' end;
end;
$$;

create function public.staff_reserve_serialized_asset(
  p_asset_id uuid,
  p_order_line_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (asset_reservation_id uuid, public_reference text, asset_version bigint, reservation_version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; asset_record record; line_record record; existing_reservation record;
  created_reservation_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('asset.reserve', p_reason, p_request_id);
  select reservation.id, reservation.public_reference, reservation.version
  into existing_reservation from public.asset_reservations as reservation
  where reservation.source_request_id = p_request_id;
  if found then
    select asset.version into strict p_expected_version from public.serialized_assets as asset
    where asset.id = p_asset_id;
    return query select existing_reservation.id, existing_reservation.public_reference,
      p_expected_version, existing_reservation.version;
    return;
  end if;
  select asset.* into asset_record from public.serialized_assets as asset
  where asset.id = p_asset_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'serialized_asset_not_found'; end if;
  if asset_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'serialized_asset_version_conflict';
  end if;
  if asset_record.status <> 'available' then
    raise exception using errcode = '22023', message = 'serialized_asset_not_reservable';
  end if;
  select line.id, line.item_id, line.quantity_approved, line.quantity_fulfilled,
    line.requires_serial_tracking_snapshot, line.status
  into line_record from public.order_lines as line where line.id = p_order_line_id;
  if not found then raise exception using errcode = 'P0002', message = 'asset_order_line_not_found'; end if;
  if line_record.item_id <> asset_record.item_id
    or not line_record.requires_serial_tracking_snapshot
    or line_record.quantity_approved <> 1
    or line_record.quantity_fulfilled <> 0
    or line_record.status not in ('approved', 'awaiting_stock', 'partially_approved')
  then raise exception using errcode = '22023', message = 'asset_order_line_ineligible'; end if;
  created_reference := private.allocate_asset_reference('asset_reservation');
  insert into public.asset_reservations (
    public_reference, asset_id, order_line_id, expires_at,
    created_by_actor_id, source_request_id
  ) values (
    created_reference, p_asset_id, p_order_line_id,
    statement_timestamp() + interval '48 hours', actor_id, p_request_id
  ) returning id into created_reservation_id;
  update public.serialized_assets as asset set status = 'reserved', version = asset.version + 1
  where asset.id = p_asset_id returning asset.* into asset_record;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id, order_line_id,
    asset_reservation_id, previous_state, new_state, reason, request_id
  ) values (
    p_asset_id, 'reserved', actor_id, p_order_line_id, created_reservation_id,
    jsonb_build_object('status', 'available'),
    jsonb_build_object('status', 'reserved', 'reservation_id', created_reservation_id),
    btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'asset.reserved', 'serialized_asset', p_asset_id,
    jsonb_build_object('public_reference', asset_record.public_reference,
      'reservation_reference', created_reference, 'order_line_id', p_order_line_id),
    'asset.reserved:' || p_request_id::text
  );
  return query select created_reservation_id, created_reference,
    asset_record.version, 1::bigint;
end;
$$;

create function public.staff_release_asset_reservation(
  p_asset_reservation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (asset_reservation_id uuid, reservation_version bigint, asset_version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; reservation_record record; asset_record record;
  next_status text; termination_status text; event_code text;
begin
  actor_id := private.set_staff_audit_context('asset.reserve', p_reason, p_request_id);
  select reservation.* into reservation_record from public.asset_reservations as reservation
  where reservation.id = p_asset_reservation_id;
  if not found then raise exception using errcode = 'P0002', message = 'asset_reservation_not_found'; end if;
  if reservation_record.termination_request_id = p_request_id then
    select asset.version into strict p_expected_version from public.serialized_assets as asset
    where asset.id = reservation_record.asset_id;
    return query select reservation_record.id, reservation_record.version,
      p_expected_version, reservation_record.status;
    return;
  end if;
  select reservation.* into reservation_record from public.asset_reservations as reservation
  where reservation.id = p_asset_reservation_id for update;
  select asset.* into strict asset_record from public.serialized_assets as asset
  where asset.id = reservation_record.asset_id for update;
  if reservation_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'asset_reservation_version_conflict';
  end if;
  if reservation_record.status <> 'active' or asset_record.status <> 'reserved' then
    raise exception using errcode = '22023', message = 'asset_reservation_not_releasable';
  end if;
  next_status := case when asset_record.current_warehouse_id is null then 'in_custody' else 'available' end;
  termination_status := case
    when reservation_record.expires_at <= statement_timestamp() then 'expired'
    else 'released'
  end;
  event_code := case
    when termination_status = 'expired' then 'reservation_expired'
    else 'reservation_released'
  end;
  update public.asset_reservations as reservation set
    status = termination_status, terminated_at = statement_timestamp(),
    terminated_by_actor_id = actor_id, termination_reason = btrim(p_reason),
    termination_request_id = p_request_id, version = reservation.version + 1
  where reservation.id = reservation_record.id returning reservation.* into reservation_record;
  update public.serialized_assets as asset set status = next_status, version = asset.version + 1
  where asset.id = asset_record.id returning asset.* into asset_record;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id, order_line_id,
    asset_reservation_id, previous_state, new_state, reason, request_id
  ) values (
    asset_record.id, event_code, actor_id, reservation_record.order_line_id,
    reservation_record.id, jsonb_build_object('status', 'reserved'),
    jsonb_build_object('status', next_status), btrim(p_reason), p_request_id
  );
  return query select reservation_record.id, reservation_record.version,
    asset_record.version, reservation_record.status;
end;
$$;

create function public.staff_transfer_serialized_asset_custody(
  p_asset_id uuid,
  p_expected_version bigint,
  p_to_custodian_party_id uuid,
  p_to_stock_location_id uuid,
  p_condition_code text,
  p_reason text,
  p_request_id uuid
)
returns table (asset_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; asset_record record; destination_record record;
  existing_event record; next_status text; destination_warehouse_id uuid;
  previous_custodian_party_id uuid; previous_stock_location_id uuid;
  previous_warehouse_id uuid; previous_condition_code text; previous_status text;
begin
  actor_id := private.set_staff_audit_context('asset.custody.transfer', p_reason, p_request_id);
  select event.id into existing_event from public.asset_events as event
  where event.request_id = p_request_id and event.event_type = 'custody_transferred';
  if found then
    select asset.id, asset.version, asset.status into strict asset_record
    from public.serialized_assets as asset where asset.id = p_asset_id;
    return query select asset_record.id, asset_record.version, asset_record.status;
    return;
  end if;
  select asset.* into asset_record from public.serialized_assets as asset
  where asset.id = p_asset_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'serialized_asset_not_found'; end if;
  if asset_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'serialized_asset_version_conflict';
  end if;
  previous_custodian_party_id := asset_record.current_custodian_party_id;
  previous_stock_location_id := asset_record.current_stock_location_id;
  previous_warehouse_id := asset_record.current_warehouse_id;
  previous_condition_code := asset_record.condition_code;
  previous_status := asset_record.status;
  if asset_record.status not in ('available', 'in_custody', 'damaged')
    or exists (select 1 from public.asset_reservations as reservation where reservation.asset_id = p_asset_id and reservation.status = 'active')
  then raise exception using errcode = '22023', message = 'serialized_asset_not_transferable'; end if;
  if p_condition_code not in ('excellent', 'good', 'fair', 'damaged', 'unknown') then
    raise exception using errcode = '22023', message = 'asset_condition_invalid';
  end if;
  if p_to_stock_location_id is not null then
    select location.id, location.warehouse_id, warehouse.operating_party_id
    into destination_record
    from public.stock_locations as location
    join public.warehouses as warehouse on warehouse.id = location.warehouse_id
    where location.id = p_to_stock_location_id and location.active and warehouse.status = 'active';
    if not found or destination_record.operating_party_id <> p_to_custodian_party_id then
      raise exception using errcode = '22023', message = 'asset_custody_destination_invalid';
    end if;
    destination_warehouse_id := destination_record.warehouse_id;
    next_status := case when p_condition_code = 'damaged' then 'damaged' else 'available' end;
  else
    if not exists (select 1 from public.parties as party where party.id = p_to_custodian_party_id and party.status = 'active') then
      raise exception using errcode = 'P0002', message = 'asset_custodian_not_found';
    end if;
    destination_warehouse_id := null;
    next_status := case when p_condition_code = 'damaged' then 'damaged' else 'in_custody' end;
  end if;
  update public.serialized_assets as asset set
    current_custodian_party_id = p_to_custodian_party_id,
    current_warehouse_id = destination_warehouse_id,
    current_stock_location_id = p_to_stock_location_id,
    condition_code = p_condition_code, status = next_status,
    version = asset.version + 1
  where asset.id = p_asset_id returning asset.* into asset_record;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id,
    from_custodian_party_id, to_custodian_party_id,
    from_stock_location_id, to_stock_location_id,
    condition_before, condition_after, accepted_by_actor_id, accepted_at,
    previous_state, new_state, reason, request_id
  ) values (
    asset_record.id, 'custody_transferred', actor_id,
    previous_custodian_party_id, p_to_custodian_party_id,
    previous_stock_location_id, p_to_stock_location_id,
    previous_condition_code, p_condition_code, actor_id, statement_timestamp(),
    jsonb_build_object('version', p_expected_version, 'status', previous_status,
      'custodian_party_id', previous_custodian_party_id,
      'warehouse_id', previous_warehouse_id, 'stock_location_id', previous_stock_location_id,
      'condition_code', previous_condition_code),
    jsonb_build_object('status', next_status, 'custodian_party_id', p_to_custodian_party_id,
      'warehouse_id', destination_warehouse_id, 'stock_location_id', p_to_stock_location_id),
    btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'asset.custody_transferred', 'serialized_asset', asset_record.id,
    jsonb_build_object('public_reference', asset_record.public_reference,
      'custodian_party_id', p_to_custodian_party_id, 'status', next_status),
    'asset.custody_transferred:' || p_request_id::text
  );
  return query select asset_record.id, asset_record.version, asset_record.status;
end;
$$;

create function public.staff_record_asset_inspection(
  p_asset_id uuid,
  p_expected_version bigint,
  p_condition_code text,
  p_observation text,
  p_next_due_at timestamptz,
  p_reason text,
  p_request_id uuid
)
returns table (asset_id uuid, version bigint, condition_code text, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; asset_record record; existing_inspection record; next_status text;
  previous_condition_code text; previous_status text;
begin
  actor_id := private.set_staff_audit_context('asset.inspect', p_reason, p_request_id);
  select inspection.asset_id into existing_inspection from public.asset_inspections as inspection
  where inspection.request_id = p_request_id;
  if found then
    select asset.id, asset.version, asset.condition_code, asset.status into strict asset_record
    from public.serialized_assets as asset where asset.id = p_asset_id;
    return query select asset_record.id, asset_record.version,
      asset_record.condition_code, asset_record.status;
    return;
  end if;
  if p_condition_code not in ('excellent', 'good', 'fair', 'damaged', 'unknown')
    or btrim(coalesce(p_observation, '')) = ''
    or char_length(p_observation) > 4000
    or (p_next_due_at is not null and p_next_due_at <= statement_timestamp())
  then raise exception using errcode = '22023', message = 'asset_inspection_invalid'; end if;
  select asset.* into asset_record from public.serialized_assets as asset
  where asset.id = p_asset_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'serialized_asset_not_found'; end if;
  if asset_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'serialized_asset_version_conflict';
  end if;
  previous_condition_code := asset_record.condition_code;
  previous_status := asset_record.status;
  if asset_record.status in ('missing', 'seized', 'retired', 'destroyed', 'reserved') then
    raise exception using errcode = '22023', message = 'serialized_asset_not_inspectable';
  end if;
  next_status := case
    when p_condition_code = 'damaged' then 'damaged'
    when asset_record.current_warehouse_id is null then 'in_custody'
    else 'available'
  end;
  insert into public.asset_inspections (
    asset_id, inspected_at, inspected_by_actor_id, custodian_party_id,
    stock_location_id, condition_code, observation, next_due_at, request_id
  ) values (
    asset_record.id, statement_timestamp(), actor_id,
    asset_record.current_custodian_party_id, asset_record.current_stock_location_id,
    p_condition_code, btrim(p_observation), p_next_due_at, p_request_id
  );
  update public.serialized_assets as asset set condition_code = p_condition_code,
    status = next_status, next_inspection_due_at = p_next_due_at,
    version = asset.version + 1
  where asset.id = asset_record.id returning asset.* into asset_record;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id, from_custodian_party_id,
    to_custodian_party_id, from_stock_location_id, to_stock_location_id,
    condition_before, condition_after, previous_state, new_state, reason, request_id
  ) values (
    asset_record.id, 'inspection_recorded', actor_id,
    asset_record.current_custodian_party_id, asset_record.current_custodian_party_id,
    asset_record.current_stock_location_id, asset_record.current_stock_location_id,
    previous_condition_code, p_condition_code,
    jsonb_build_object('version', p_expected_version, 'status', previous_status,
      'condition_code', previous_condition_code),
    jsonb_build_object('status', next_status, 'condition_code', p_condition_code,
      'next_inspection_due_at', p_next_due_at), btrim(p_reason), p_request_id
  );
  return query select asset_record.id, asset_record.version,
    asset_record.condition_code, asset_record.status;
end;
$$;

create function public.staff_change_serialized_asset_status(
  p_asset_id uuid,
  p_expected_version bigint,
  p_status text,
  p_reason text,
  p_request_id uuid
)
returns table (asset_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; asset_record record; previous_status text;
  event_code text; existing_event record; target_status text;
begin
  actor_id := private.set_staff_audit_context('asset.lifecycle.manage', p_reason, p_request_id);
  select event.id into existing_event from public.asset_events as event
  where event.request_id = p_request_id;
  if found then
    select asset.id, asset.version, asset.status into strict asset_record
    from public.serialized_assets as asset where asset.id = p_asset_id;
    return query select asset_record.id, asset_record.version, asset_record.status;
    return;
  end if;
  select asset.* into asset_record from public.serialized_assets as asset
  where asset.id = p_asset_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'serialized_asset_not_found'; end if;
  if asset_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'serialized_asset_version_conflict';
  end if;
  if asset_record.status = 'reserved'
    or exists (select 1 from public.asset_reservations as reservation where reservation.asset_id = p_asset_id and reservation.status = 'active')
  then raise exception using errcode = '22023', message = 'asset_active_reservation_requires_release'; end if;
  previous_status := asset_record.status;
  if not (
    (previous_status in ('available', 'in_custody', 'damaged') and p_status in ('available', 'missing', 'damaged', 'seized', 'retired', 'destroyed'))
    or (previous_status = 'missing' and p_status = 'available')
    or (previous_status = 'seized' and p_status in ('available', 'retired', 'destroyed'))
  ) or p_status = previous_status then
    raise exception using errcode = '22023', message = 'asset_status_transition_invalid';
  end if;
  target_status := case
    when p_status = 'available' and asset_record.current_warehouse_id is null
      then 'in_custody'
    else p_status
  end;
  event_code := case
    when p_status = 'missing' then 'missing'
    when previous_status = 'missing' and p_status = 'available' then 'recovered'
    when p_status = 'damaged' then 'condition_changed'
    when p_status = 'seized' then 'seized'
    when p_status = 'retired' then 'retired'
    when p_status = 'destroyed' then 'destroyed'
    else 'status_changed'
  end;
  update public.serialized_assets as asset set status = target_status,
    condition_code = case when target_status = 'damaged' then 'damaged' else asset.condition_code end,
    version = asset.version + 1
  where asset.id = asset_record.id returning asset.* into asset_record;
  insert into public.asset_events (
    asset_id, event_type, recorded_by_actor_id, from_custodian_party_id,
    to_custodian_party_id, from_stock_location_id, to_stock_location_id,
    previous_state, new_state, reason, request_id
  ) values (
    asset_record.id, event_code, actor_id,
    asset_record.current_custodian_party_id, asset_record.current_custodian_party_id,
    asset_record.current_stock_location_id, asset_record.current_stock_location_id,
    jsonb_build_object('status', previous_status), jsonb_build_object('status', target_status),
    btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'asset.status_changed', 'serialized_asset', asset_record.id,
    jsonb_build_object('public_reference', asset_record.public_reference,
      'previous_status', previous_status, 'status', target_status),
    'asset.status_changed:' || p_request_id::text
  );
  return query select asset_record.id, asset_record.version, asset_record.status;
end;
$$;

insert into public.notification_templates (
  code, event_type, destination_type, message_template
)
values
  ('staff-asset-registered-v1', 'asset.registered', 'discord_channel', 'Serialized asset {{public_reference}} was registered with condition {{condition_code}}.'),
  ('staff-asset-reserved-v1', 'asset.reserved', 'discord_channel', 'Serialized asset {{public_reference}} was allocated as {{reservation_reference}}.'),
  ('staff-asset-custody-v1', 'asset.custody_transferred', 'discord_channel', 'Custody changed for serialized asset {{public_reference}}. Status: {{status}}.'),
  ('staff-asset-status-v1', 'asset.status_changed', 'discord_channel', 'Serialized asset {{public_reference}} changed from {{previous_status}} to {{status}}.');

insert into public.integration_event_routes (
  event_type, destination_id, notification_template_id, active
)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type in (
  'asset.registered', 'asset.reserved', 'asset.custody_transferred', 'asset.status_changed'
);

revoke all on public.serialized_assets from anon, authenticated;
revoke all on public.asset_reservations from anon, authenticated;
revoke all on public.asset_events from anon, authenticated;
revoke all on public.asset_inspections from anon, authenticated;
revoke all on function private.allocate_asset_reference(text) from public, anon, authenticated;
revoke all on function private.staff_has_permission(text) from public, anon, authenticated;
revoke all on function public.get_staff_asset_workspace() from public, anon;
revoke all on function public.staff_register_serialized_asset(uuid,uuid,text,text,text,text,uuid) from public, anon;
revoke all on function public.staff_reserve_serialized_asset(uuid,uuid,bigint,text,uuid) from public, anon;
revoke all on function public.staff_release_asset_reservation(uuid,bigint,text,uuid) from public, anon;
revoke all on function public.staff_transfer_serialized_asset_custody(uuid,bigint,uuid,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_record_asset_inspection(uuid,bigint,text,text,timestamptz,text,uuid) from public, anon;
revoke all on function public.staff_change_serialized_asset_status(uuid,bigint,text,text,uuid) from public, anon;
grant execute on function public.get_staff_asset_workspace() to authenticated;
grant execute on function public.staff_register_serialized_asset(uuid,uuid,text,text,text,text,uuid) to authenticated;
grant execute on function public.staff_reserve_serialized_asset(uuid,uuid,bigint,text,uuid) to authenticated;
grant execute on function public.staff_release_asset_reservation(uuid,bigint,text,uuid) to authenticated;
grant execute on function public.staff_transfer_serialized_asset_custody(uuid,bigint,uuid,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_record_asset_inspection(uuid,bigint,text,text,timestamptz,text,uuid) to authenticated;
grant execute on function public.staff_change_serialized_asset_status(uuid,bigint,text,text,uuid) to authenticated;
