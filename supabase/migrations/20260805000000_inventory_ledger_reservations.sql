create table public.warehouses (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{1,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  operating_party_id uuid not null references public.parties(id) on delete restrict,
  default_timezone text not null check (btrim(default_timezone) <> ''),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stock_locations (
  id uuid primary key default extensions.gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  parent_location_id uuid,
  code text not null check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  location_type text not null
    check (location_type in ('receiving', 'available', 'quarantine', 'damaged')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (warehouse_id, code),
  unique (id, warehouse_id),
  foreign key (parent_location_id, warehouse_id)
    references public.stock_locations(id, warehouse_id) on delete restrict
);

create table public.inventory_accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete restrict,
  account_kind text not null check (account_kind in ('physical', 'external')),
  owner_party_id uuid references public.parties(id) on delete restrict,
  custodian_party_id uuid references public.parties(id) on delete restrict,
  warehouse_id uuid references public.warehouses(id) on delete restrict,
  stock_location_id uuid,
  stock_state text not null
    check (stock_state in ('available', 'receiving', 'quarantine', 'damaged', 'external_source')),
  status text not null default 'active' check (status in ('active', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (stock_location_id, warehouse_id)
    references public.stock_locations(id, warehouse_id) on delete restrict,
  check (
    (
      account_kind = 'physical'
      and owner_party_id is not null
      and custodian_party_id is not null
      and warehouse_id is not null
      and stock_location_id is not null
      and stock_state <> 'external_source'
    )
    or (
      account_kind = 'external'
      and owner_party_id is null
      and custodian_party_id is null
      and warehouse_id is null
      and stock_location_id is null
      and stock_state = 'external_source'
    )
  )
);

create unique index inventory_accounts_physical_identity_idx
  on public.inventory_accounts (
    item_id,
    owner_party_id,
    custodian_party_id,
    warehouse_id,
    stock_location_id,
    stock_state
  )
  where account_kind = 'physical';

create unique index inventory_accounts_external_item_idx
  on public.inventory_accounts (item_id)
  where account_kind = 'external';

create table public.inventory_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  transaction_type text not null check (transaction_type in ('receipt', 'reversal')),
  status text not null default 'posted' check (status = 'posted'),
  occurred_at timestamptz not null,
  posted_at timestamptz not null default now(),
  posted_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  permission_code text not null,
  source_reference text not null check (btrim(source_reference) <> ''),
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  reversal_of_id uuid unique references public.inventory_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (
    (transaction_type = 'receipt' and reversal_of_id is null)
    or (transaction_type = 'reversal' and reversal_of_id is not null)
  )
);

create table public.inventory_ledger_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  inventory_transaction_id uuid not null
    references public.inventory_transactions(id) on delete restrict,
  line_number smallint not null check (line_number > 0),
  inventory_account_id uuid not null references public.inventory_accounts(id) on delete restrict,
  item_id uuid not null references public.items(id) on delete restrict,
  quantity_delta numeric(18, 3) not null check (quantity_delta <> 0),
  created_at timestamptz not null default now(),
  unique (inventory_transaction_id, line_number)
);

create table public.reservations (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  order_line_id uuid not null references public.order_lines(id) on delete restrict,
  inventory_account_id uuid not null references public.inventory_accounts(id) on delete restrict,
  quantity numeric(18, 3) not null check (quantity > 0),
  status text not null default 'active'
    check (status in ('active', 'released', 'expired', 'consumed')),
  reserved_at timestamptz not null default now(),
  expires_at timestamptz not null,
  released_at timestamptz,
  released_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  release_reason text,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > reserved_at),
  check (
    (status = 'active' and released_at is null and released_by_actor_id is null and release_reason is null)
    or (
      status in ('released', 'expired')
      and released_at is not null
      and released_by_actor_id is not null
      and btrim(release_reason) <> ''
    )
    or status = 'consumed'
  )
);

create table public.reservation_events (
  id uuid primary key default extensions.gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id) on delete restrict,
  event_type text not null check (event_type in ('created', 'extended', 'released', 'expired')),
  previous_state jsonb,
  new_state jsonb not null,
  changed_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now()
);

comment on table public.inventory_ledger_entries is
  'Immutable double-entry quantity ledger. Physical balances are derived by summing entries.';
comment on table public.reservations is
  'Time-bounded claims against derived physical stock; reservations never change ledger quantity.';
comment on column public.reservations.expires_at is
  'Initial creation uses the approved 48-hour term. Extensions require a separate authorized command.';

create index stock_locations_warehouse_idx on public.stock_locations(warehouse_id, active);
create index inventory_accounts_position_idx
  on public.inventory_accounts(warehouse_id, item_id, stock_state, status);
create index inventory_ledger_entries_account_idx
  on public.inventory_ledger_entries(inventory_account_id, created_at);
create index inventory_ledger_entries_transaction_idx
  on public.inventory_ledger_entries(inventory_transaction_id, line_number);
create index reservations_account_active_idx
  on public.reservations(inventory_account_id, expires_at)
  where status = 'active';
create index reservations_order_line_idx on public.reservations(order_line_id, created_at);
create index reservation_events_reservation_idx
  on public.reservation_events(reservation_id, created_at);

alter table public.order_line_events
  drop constraint order_line_events_event_type_check;
alter table public.order_line_events
  add constraint order_line_events_event_type_check
  check (event_type in (
    'submitted', 'reviewed', 'price_changed', 'reservation_changed', 'cancelled'
  ));

create trigger warehouses_set_updated_at before update on public.warehouses
for each row execute function private.set_updated_at();
create trigger stock_locations_set_updated_at before update on public.stock_locations
for each row execute function private.set_updated_at();
create trigger inventory_accounts_set_updated_at before update on public.inventory_accounts
for each row execute function private.set_updated_at();
create trigger reservations_set_updated_at before update on public.reservations
for each row execute function private.set_updated_at();

create trigger warehouses_audit after insert or update or delete on public.warehouses
for each row execute function private.capture_audit_row();
create trigger stock_locations_audit after insert or update or delete on public.stock_locations
for each row execute function private.capture_audit_row();
create trigger inventory_accounts_audit after insert or update or delete on public.inventory_accounts
for each row execute function private.capture_audit_row();
create trigger inventory_transactions_audit after insert or update or delete
on public.inventory_transactions
for each row execute function private.capture_audit_row();
create trigger inventory_ledger_entries_audit after insert or update or delete
on public.inventory_ledger_entries
for each row execute function private.capture_audit_row();
create trigger reservations_audit after insert or update or delete on public.reservations
for each row execute function private.capture_audit_row();
create trigger reservation_events_audit after insert or update or delete
on public.reservation_events
for each row execute function private.capture_audit_row();

alter table public.warehouses enable row level security;
alter table public.stock_locations enable row level security;
alter table public.inventory_accounts enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.inventory_ledger_entries enable row level security;
alter table public.reservations enable row level security;
alter table public.reservation_events enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'inventory.position.read',
    'Read inventory positions',
    'View ledger-derived on-hand, reserved, and available positions in assigned warehouses.'
  ),
  (
    'inventory.receipt.post',
    'Post inventory receipts',
    'Post balanced fungible receipts into assigned warehouse locations.'
  ),
  (
    'inventory.receipt.reverse',
    'Reverse inventory receipts',
    'Post a linked reversal of an immutable receipt when stock and reservations permit.'
  ),
  (
    'reservation.manage',
    'Create stock reservations',
    'Create atomic time-bounded stock claims for approved order quantities.'
  ),
  (
    'reservation.extend',
    'Extend stock reservations',
    'Extend a current reservation with a reason.'
  ),
  (
    'reservation.release',
    'Release stock reservations',
    'Release or record expiry of an unconsumed reservation with a reason.'
  );

insert into public.staff_roles (code, display_name, description)
values
  (
    'warehouse_operator',
    'Warehouse operator',
    'May read assigned inventory, post receipts, and manage routine reservations.'
  ),
  (
    'inventory_controller',
    'Inventory controller',
    'May supervise immutable receipt corrections and routine reservation operations.'
  );

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'warehouse_operator'
  and permission.code in (
    'inventory.position.read', 'inventory.receipt.post',
    'reservation.manage', 'reservation.extend', 'reservation.release'
  )
) or (
  role.code = 'inventory_controller'
  and permission.code in (
    'inventory.position.read', 'inventory.receipt.post', 'inventory.receipt.reverse',
    'reservation.manage', 'reservation.extend', 'reservation.release'
  )
) or (
  role.code = 'order_officer'
  and permission.code in (
    'inventory.position.read', 'reservation.manage',
    'reservation.extend', 'reservation.release'
  )
);

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values ('reservation', 'EEC-RES', 1001, 4);

create function private.current_staff_warehouse_assignments(
  p_permission_code text,
  p_warehouse_id uuid default null
)
returns table (
  actor_id uuid,
  staff_assignment_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select actor.id, assignment.id
  from public.actor_profiles as actor
  join public.staff_assignments as assignment
    on assignment.actor_id = actor.id
    and assignment.revoked_at is null
    and assignment.effective_from <= statement_timestamp()
    and (
      assignment.effective_until is null
      or assignment.effective_until > statement_timestamp()
    )
  join public.staff_role_permissions as role_permission
    on role_permission.staff_role_id = assignment.staff_role_id
  join public.permission_scopes as permission
    on permission.id = role_permission.permission_scope_id
    and permission.code = p_permission_code
    and permission.active
  where actor.auth_user_id = auth.uid()
    and actor.actor_type = 'staff'
    and actor.status = 'active'
    and (
      p_warehouse_id is null
      or not (assignment.assignment_scope ? 'warehouse_ids')
      or (
        jsonb_typeof(assignment.assignment_scope -> 'warehouse_ids') = 'array'
        and assignment.assignment_scope -> 'warehouse_ids' ? p_warehouse_id::text
      )
    );
$$;

create function private.set_warehouse_audit_context(
  p_permission_code text,
  p_warehouse_id uuid,
  p_reason text,
  p_request_id uuid
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  permission_grant record;
  normalized_reason text;
begin
  normalized_reason := btrim(coalesce(p_reason, ''));
  if normalized_reason = '' or char_length(normalized_reason) > 500 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'request_id_required';
  end if;

  select current_grant.* into permission_grant
  from private.current_staff_warehouse_assignments(
    p_permission_code,
    p_warehouse_id
  ) as current_grant
  order by current_grant.staff_assignment_id
  limit 1;
  if not found then
    raise exception using errcode = '42501', message = 'staff_warehouse_permission_denied';
  end if;

  perform set_config('app.actor_id', permission_grant.actor_id::text, true);
  perform set_config(
    'app.staff_assignment_id',
    permission_grant.staff_assignment_id::text,
    true
  );
  perform set_config('app.represented_party_id', '', true);
  perform set_config('app.permission_code', p_permission_code, true);
  perform set_config('app.audit_reason', normalized_reason, true);
  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.correlation_id', p_request_id::text, true);
  perform set_config('app.source_surface', 'staff_portal', true);

  return permission_grant.actor_id;
end;
$$;

create function private.reject_immutable_inventory_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'posted_inventory_is_immutable';
end;
$$;

create trigger inventory_transactions_immutable
before update or delete on public.inventory_transactions
for each row execute function private.reject_immutable_inventory_change();
create trigger inventory_ledger_entries_immutable
before update or delete on public.inventory_ledger_entries
for each row execute function private.reject_immutable_inventory_change();
create trigger reservation_events_immutable
before update or delete on public.reservation_events
for each row execute function private.reject_immutable_inventory_change();

create function private.validate_inventory_ledger_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.inventory_accounts as account
    where account.id = new.inventory_account_id
      and account.item_id = new.item_id
      and account.status = 'active'
  ) then
    raise exception using errcode = '23514', message = 'inventory_account_item_mismatch';
  end if;
  return new;
end;
$$;

create trigger inventory_ledger_entry_validate
before insert on public.inventory_ledger_entries
for each row execute function private.validate_inventory_ledger_entry();

create function private.assert_inventory_ledger_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  transaction_id uuid;
  account_id uuid;
  account_record record;
  transaction_balance numeric(18, 3);
  on_hand_quantity numeric(18, 3);
  reserved_quantity numeric(18, 3);
begin
  transaction_id := new.inventory_transaction_id;
  account_id := new.inventory_account_id;

  select coalesce(sum(entry.quantity_delta), 0)
  into transaction_balance
  from public.inventory_ledger_entries as entry
  where entry.inventory_transaction_id = transaction_id;
  if transaction_balance <> 0 then
    raise exception using errcode = '23514', message = 'inventory_transaction_unbalanced';
  end if;

  select account.account_kind into account_record
  from public.inventory_accounts as account
  where account.id = account_id;
  if account_record.account_kind = 'physical' then
    select coalesce(sum(entry.quantity_delta), 0)
    into on_hand_quantity
    from public.inventory_ledger_entries as entry
    where entry.inventory_account_id = account_id;

    select coalesce(sum(reservation.quantity), 0)
    into reserved_quantity
    from public.reservations as reservation
    where reservation.inventory_account_id = account_id
      and reservation.status = 'active'
      and reservation.expires_at > statement_timestamp();

    if on_hand_quantity < 0 then
      raise exception using errcode = '23514', message = 'inventory_negative_stock';
    end if;
    if on_hand_quantity < reserved_quantity then
      raise exception using errcode = '23514', message = 'inventory_reserved_stock_violation';
    end if;
  end if;
  return null;
end;
$$;

create constraint trigger inventory_ledger_state_check
after insert on public.inventory_ledger_entries
deferrable initially immediate
for each row execute function private.assert_inventory_ledger_state();

create function private.assert_reservation_availability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_id uuid;
  on_hand_quantity numeric(18, 3);
  reserved_quantity numeric(18, 3);
begin
  account_id := new.inventory_account_id;
  if not exists (
    select 1 from public.inventory_accounts as account
    where account.id = account_id and account.account_kind = 'physical'
  ) then
    return null;
  end if;

  select coalesce(sum(entry.quantity_delta), 0)
  into on_hand_quantity
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = account_id;

  select coalesce(sum(reservation.quantity), 0)
  into reserved_quantity
  from public.reservations as reservation
  where reservation.inventory_account_id = account_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();

  if reserved_quantity > on_hand_quantity then
    raise exception using errcode = '23514', message = 'inventory_reservation_overdrawn';
  end if;
  return null;
end;
$$;

create constraint trigger reservation_availability_check
after insert or update on public.reservations
deferrable initially immediate
for each row execute function private.assert_reservation_availability();

create function private.allocate_reservation_reference()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  sequence_record record;
  allocated_reference text;
begin
  select reference.prefix, reference.next_value, reference.padding
  into strict sequence_record
  from public.reference_sequences as reference
  where reference.document_type = 'reservation'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix
    || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');

  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'reservation';

  return allocated_reference;
exception
  when no_data_found then
    raise exception using errcode = '55000', message = 'reservation_reference_sequence_unavailable';
end;
$$;

create function private.derive_order_status(p_order_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when bool_and(line.status = 'cancelled') then 'cancelled'
    when bool_and(line.status = 'denied') then 'denied'
    when bool_and(line.status in ('fulfilled', 'denied', 'cancelled'))
      and bool_or(line.status = 'fulfilled') then 'fulfilled'
    when bool_or(line.status in ('awaiting_stock', 'partially_awaiting_stock'))
      then 'awaiting_stock'
    when bool_or(line.status = 'review_required') then 'under_review'
    when bool_or(line.status in ('reserved', 'ready', 'fulfilled')) then 'processing'
    when bool_and(line.status = 'approved') then 'approved'
    when bool_and(line.status in ('approved', 'partially_approved', 'denied'))
      then 'partially_approved'
    else 'under_review'
  end
  from public.order_lines as line
  where line.order_id = p_order_id;
$$;

create function public.get_staff_inventory_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from private.current_staff_warehouse_assignments(
      'inventory.position.read',
      null
    )
  ) then
    raise exception using errcode = '42501', message = 'staff_warehouse_permission_denied';
  end if;

  return jsonb_build_object(
    'warehouses', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', warehouse.id,
            'code', warehouse.code,
            'display_name', warehouse.display_name,
            'timezone', warehouse.default_timezone,
            'locations', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', location.id,
                    'code', location.code,
                    'display_name', location.display_name,
                    'location_type', location.location_type
                  ) order by location.display_name
                )
                from public.stock_locations as location
                where location.warehouse_id = warehouse.id
                  and location.active
              ),
              '[]'::jsonb
            )
          ) order by warehouse.display_name
        )
        from public.warehouses as warehouse
        where warehouse.status = 'active'
          and exists (
            select 1
            from private.current_staff_warehouse_assignments(
              'inventory.position.read',
              warehouse.id
            )
          )
      ),
      '[]'::jsonb
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', item.id,
            'item_code', item.item_code,
            'display_name', item.display_name,
            'inventory_mode', item.inventory_mode,
            'unit_code', unit.code
          ) order by item.display_name, item.item_code
        )
        from public.items as item
        join public.units_of_measure as unit on unit.id = item.unit_id
        where item.status = 'active'
      ),
      '[]'::jsonb
    ),
    'positions', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'account_id', position.account_id,
            'warehouse_id', position.warehouse_id,
            'warehouse_name', position.warehouse_name,
            'location_name', position.location_name,
            'item_id', position.item_id,
            'item_code', position.item_code,
            'item_name', position.item_name,
            'unit_code', position.unit_code,
            'stock_state', position.stock_state,
            'on_hand', position.on_hand,
            'reserved', position.reserved,
            'available', position.on_hand - position.reserved
          ) order by position.warehouse_name, position.location_name, position.item_name
        )
        from (
          select
            account.id as account_id,
            warehouse.id as warehouse_id,
            warehouse.display_name as warehouse_name,
            location.display_name as location_name,
            item.id as item_id,
            item.item_code,
            item.display_name as item_name,
            unit.code as unit_code,
            account.stock_state,
            coalesce(
              (
                select sum(entry.quantity_delta)
                from public.inventory_ledger_entries as entry
                where entry.inventory_account_id = account.id
              ),
              0
            ) as on_hand,
            coalesce(
              (
                select sum(reservation.quantity)
                from public.reservations as reservation
                where reservation.inventory_account_id = account.id
                  and reservation.status = 'active'
                  and reservation.expires_at > statement_timestamp()
              ),
              0
            ) as reserved
          from public.inventory_accounts as account
          join public.warehouses as warehouse on warehouse.id = account.warehouse_id
          join public.stock_locations as location on location.id = account.stock_location_id
          join public.items as item on item.id = account.item_id
          join public.units_of_measure as unit on unit.id = item.unit_id
          where account.account_kind = 'physical'
            and account.status = 'active'
            and exists (
              select 1
              from private.current_staff_warehouse_assignments(
                'inventory.position.read',
                warehouse.id
              )
            )
        ) as position
      ),
      '[]'::jsonb
    ),
    'order_lines', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', line.id,
            'order_id', order_record.id,
            'order_reference', order_record.public_reference,
            'order_status', order_record.status,
            'order_version', order_record.version,
            'ordering_party_name', ordering_party.display_name,
            'line_number', line.line_number,
            'item_id', line.item_id,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'unit_code', line.unit_code_snapshot,
            'quantity_approved', line.quantity_approved,
            'quantity_fulfilled', line.quantity_fulfilled,
            'quantity_reserved', coalesce(
              (
                select sum(reservation.quantity)
                from public.reservations as reservation
                where reservation.order_line_id = line.id
                  and reservation.status = 'active'
                  and reservation.expires_at > statement_timestamp()
              ),
              0
            ),
            'status', line.status,
            'control_profile_code', line.control_profile_code_snapshot
          ) order by order_record.submitted_at, order_record.public_reference, line.line_number
        )
        from public.order_lines as line
        join public.orders as order_record on order_record.id = line.order_id
        join public.parties as ordering_party on ordering_party.id = order_record.ordering_party_id
        where line.quantity_approved is not null
          and line.quantity_fulfilled < line.quantity_approved
          and line.status in (
            'approved', 'partially_approved', 'awaiting_stock',
            'partially_awaiting_stock', 'reserved'
          )
          and exists (
            select 1
            from private.current_staff_warehouse_assignments(
              'reservation.manage',
              null
            )
          )
      ),
      '[]'::jsonb
    ),
    'transactions', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', transaction_record.id,
            'transaction_type', transaction_record.transaction_type,
            'source_reference', transaction_record.source_reference,
            'reason', transaction_record.reason,
            'posted_at', transaction_record.posted_at,
            'reversal_of_id', transaction_record.reversal_of_id,
            'is_reversed', exists (
              select 1
              from public.inventory_transactions as reversal
              where reversal.reversal_of_id = transaction_record.id
            ),
            'warehouse_id', warehouse.id,
            'warehouse_name', warehouse.display_name,
            'item_code', item.item_code,
            'item_name', item.display_name,
            'quantity_delta', physical_entry.quantity_delta
          ) order by transaction_record.posted_at desc, transaction_record.id
        )
        from public.inventory_transactions as transaction_record
        join public.inventory_ledger_entries as physical_entry
          on physical_entry.inventory_transaction_id = transaction_record.id
        join public.inventory_accounts as account
          on account.id = physical_entry.inventory_account_id
          and account.account_kind = 'physical'
        join public.warehouses as warehouse on warehouse.id = account.warehouse_id
        join public.items as item on item.id = physical_entry.item_id
        where exists (
          select 1
          from private.current_staff_warehouse_assignments(
            'inventory.position.read',
            warehouse.id
          )
        )
      ),
      '[]'::jsonb
    ),
    'reservations', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', reservation.id,
            'public_reference', reservation.public_reference,
            'order_line_id', reservation.order_line_id,
            'order_reference', order_record.public_reference,
            'line_number', line.line_number,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'warehouse_id', warehouse.id,
            'warehouse_name', warehouse.display_name,
            'location_name', location.display_name,
            'quantity', reservation.quantity,
            'status', reservation.status,
            'effective_status', case
              when reservation.status = 'active'
                and reservation.expires_at <= statement_timestamp()
                then 'elapsed'
              else reservation.status
            end,
            'reserved_at', reservation.reserved_at,
            'expires_at', reservation.expires_at,
            'version', reservation.version
          ) order by reservation.expires_at, reservation.public_reference
        )
        from public.reservations as reservation
        join public.order_lines as line on line.id = reservation.order_line_id
        join public.orders as order_record on order_record.id = line.order_id
        join public.inventory_accounts as account on account.id = reservation.inventory_account_id
        join public.warehouses as warehouse on warehouse.id = account.warehouse_id
        join public.stock_locations as location on location.id = account.stock_location_id
        where exists (
          select 1
          from private.current_staff_warehouse_assignments(
            'inventory.position.read',
            warehouse.id
          )
        )
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create function public.staff_post_inventory_receipt(
  p_stock_location_id uuid,
  p_item_id uuid,
  p_quantity numeric,
  p_source_reference text,
  p_reason text,
  p_request_id uuid
)
returns table (
  transaction_id uuid,
  inventory_account_id uuid,
  on_hand numeric,
  available numeric
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  location_record record;
  existing_transaction record;
  physical_account_id uuid;
  external_account_id uuid;
  created_transaction_id uuid;
  current_on_hand numeric(18, 3);
  current_reserved numeric(18, 3);
  normalized_source text;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode = '22023', message = 'inventory_quantity_invalid';
  end if;
  normalized_source := btrim(coalesce(p_source_reference, ''));
  if normalized_source = '' or char_length(normalized_source) > 200 then
    raise exception using errcode = '22023', message = 'inventory_source_reference_invalid';
  end if;

  select
    location.id,
    location.warehouse_id,
    location.location_type,
    warehouse.operating_party_id,
    item.inventory_mode
  into location_record
  from public.stock_locations as location
  join public.warehouses as warehouse
    on warehouse.id = location.warehouse_id and warehouse.status = 'active'
  join public.items as item on item.id = p_item_id and item.status = 'active'
  where location.id = p_stock_location_id
    and location.active;
  if not found then
    raise exception using errcode = 'P0002', message = 'inventory_receipt_target_not_found';
  end if;
  if location_record.inventory_mode <> 'fungible' then
    raise exception using errcode = '22023', message = 'serialized_receipt_requires_asset_registry';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'inventory.receipt.post',
    location_record.warehouse_id,
    p_reason,
    p_request_id
  );

  select current_transaction.id, current_transaction.transaction_type
  into existing_transaction
  from public.inventory_transactions as current_transaction
  where current_transaction.request_id = p_request_id;
  if found then
    if existing_transaction.transaction_type <> 'receipt' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select
      current_transaction.id,
      account.id,
      coalesce(sum(entry.quantity_delta), 0),
      coalesce(sum(entry.quantity_delta), 0) - coalesce(
        (
          select sum(reservation.quantity)
          from public.reservations as reservation
          where reservation.inventory_account_id = account.id
            and reservation.status = 'active'
            and reservation.expires_at > statement_timestamp()
        ),
        0
      )
    from public.inventory_transactions as current_transaction
    join public.inventory_ledger_entries as source_entry
      on source_entry.inventory_transaction_id = current_transaction.id
    join public.inventory_accounts as account
      on account.id = source_entry.inventory_account_id
      and account.account_kind = 'physical'
    join public.inventory_ledger_entries as entry
      on entry.inventory_account_id = account.id
    where current_transaction.id = existing_transaction.id
    group by current_transaction.id, account.id;
    return;
  end if;

  insert into public.inventory_accounts (
    item_id,
    account_kind,
    owner_party_id,
    custodian_party_id,
    warehouse_id,
    stock_location_id,
    stock_state
  )
  values (
    p_item_id,
    'physical',
    location_record.operating_party_id,
    location_record.operating_party_id,
    location_record.warehouse_id,
    location_record.id,
    case location_record.location_type
      when 'available' then 'available'
      when 'receiving' then 'receiving'
      when 'quarantine' then 'quarantine'
      else 'damaged'
    end
  )
  on conflict (
    item_id,
    owner_party_id,
    custodian_party_id,
    warehouse_id,
    stock_location_id,
    stock_state
  ) where account_kind = 'physical'
  do nothing;

  select account.id into strict physical_account_id
  from public.inventory_accounts as account
  where account.item_id = p_item_id
    and account.account_kind = 'physical'
    and account.owner_party_id = location_record.operating_party_id
    and account.custodian_party_id = location_record.operating_party_id
    and account.warehouse_id = location_record.warehouse_id
    and account.stock_location_id = location_record.id
    and account.stock_state = case location_record.location_type
      when 'available' then 'available'
      when 'receiving' then 'receiving'
      when 'quarantine' then 'quarantine'
      else 'damaged'
    end;

  insert into public.inventory_accounts (item_id, account_kind, stock_state)
  values (p_item_id, 'external', 'external_source')
  on conflict (item_id) where account_kind = 'external'
  do nothing;

  select account.id into strict external_account_id
  from public.inventory_accounts as account
  where account.item_id = p_item_id
    and account.account_kind = 'external';

  perform 1
  from public.inventory_accounts as account
  where account.id in (physical_account_id, external_account_id)
  order by account.id
  for update;

  insert into public.inventory_transactions (
    transaction_type,
    occurred_at,
    posted_by_actor_id,
    permission_code,
    source_reference,
    reason,
    request_id
  )
  values (
    'receipt',
    statement_timestamp(),
    actor_id,
    'inventory.receipt.post',
    normalized_source,
    btrim(p_reason),
    p_request_id
  )
  returning id into created_transaction_id;

  insert into public.inventory_ledger_entries (
    inventory_transaction_id,
    line_number,
    inventory_account_id,
    item_id,
    quantity_delta
  )
  values
    (created_transaction_id, 1, external_account_id, p_item_id, -p_quantity),
    (created_transaction_id, 2, physical_account_id, p_item_id, p_quantity);

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  )
  values (
    'inventory.receipt_posted',
    'inventory_transaction',
    created_transaction_id,
    jsonb_build_object(
      'transaction_id', created_transaction_id,
      'warehouse_id', location_record.warehouse_id,
      'inventory_account_id', physical_account_id,
      'item_id', p_item_id,
      'quantity', p_quantity
    ),
    'inventory.receipt_posted:' || p_request_id::text
  );

  select coalesce(sum(entry.quantity_delta), 0)
  into current_on_hand
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = physical_account_id;
  select coalesce(sum(reservation.quantity), 0)
  into current_reserved
  from public.reservations as reservation
  where reservation.inventory_account_id = physical_account_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();

  return query
  select created_transaction_id, physical_account_id, current_on_hand,
    current_on_hand - current_reserved;
end;
$$;

create function public.staff_reverse_inventory_transaction(
  p_inventory_transaction_id uuid,
  p_reason text,
  p_request_id uuid
)
returns table (transaction_id uuid, reversal_of_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  original_transaction record;
  existing_transaction record;
  warehouse_id uuid;
  created_transaction_id uuid;
begin
  select
    original.id,
    original.transaction_type,
    original.source_reference,
    original.reversal_of_id
  into original_transaction
  from public.inventory_transactions as original
  where original.id = p_inventory_transaction_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'inventory_transaction_not_found';
  end if;

  select account.warehouse_id into warehouse_id
  from public.inventory_ledger_entries as entry
  join public.inventory_accounts as account
    on account.id = entry.inventory_account_id
    and account.account_kind = 'physical'
  where entry.inventory_transaction_id = p_inventory_transaction_id
  limit 1;
  if not found then
    raise exception using errcode = '22023', message = 'inventory_transaction_not_reversible';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'inventory.receipt.reverse',
    warehouse_id,
    p_reason,
    p_request_id
  );

  select current_transaction.id, current_transaction.reversal_of_id
  into existing_transaction
  from public.inventory_transactions as current_transaction
  where current_transaction.request_id = p_request_id;
  if found then
    if existing_transaction.reversal_of_id <> p_inventory_transaction_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query select existing_transaction.id, existing_transaction.reversal_of_id;
    return;
  end if;

  perform 1
  from public.inventory_transactions as locked_transaction
  where locked_transaction.id = p_inventory_transaction_id
  for update;
  if original_transaction.transaction_type <> 'receipt'
    or original_transaction.reversal_of_id is not null
    or exists (
      select 1
      from public.inventory_transactions as reversal
      where reversal.reversal_of_id = p_inventory_transaction_id
    ) then
    raise exception using errcode = '22023', message = 'inventory_transaction_not_reversible';
  end if;

  perform 1
  from public.inventory_accounts as account
  where account.id in (
    select entry.inventory_account_id
    from public.inventory_ledger_entries as entry
    where entry.inventory_transaction_id = p_inventory_transaction_id
  )
  order by account.id
  for update;

  insert into public.inventory_transactions (
    transaction_type,
    occurred_at,
    posted_by_actor_id,
    permission_code,
    source_reference,
    reason,
    request_id,
    reversal_of_id
  )
  values (
    'reversal',
    statement_timestamp(),
    actor_id,
    'inventory.receipt.reverse',
    'Reversal of ' || original_transaction.source_reference,
    btrim(p_reason),
    p_request_id,
    p_inventory_transaction_id
  )
  returning id into created_transaction_id;

  insert into public.inventory_ledger_entries (
    inventory_transaction_id,
    line_number,
    inventory_account_id,
    item_id,
    quantity_delta
  )
  select
    created_transaction_id,
    original_entry.line_number,
    original_entry.inventory_account_id,
    original_entry.item_id,
    -original_entry.quantity_delta
  from public.inventory_ledger_entries as original_entry
  where original_entry.inventory_transaction_id = p_inventory_transaction_id
  order by original_entry.line_number;

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  )
  values (
    'inventory.transaction_reversed',
    'inventory_transaction',
    created_transaction_id,
    jsonb_build_object(
      'transaction_id', created_transaction_id,
      'reversal_of_id', p_inventory_transaction_id,
      'warehouse_id', warehouse_id
    ),
    'inventory.transaction_reversed:' || p_request_id::text
  );

  return query select created_transaction_id, p_inventory_transaction_id;
end;
$$;

create function public.staff_create_reservation(
  p_order_line_id uuid,
  p_inventory_account_id uuid,
  p_quantity numeric,
  p_reason text,
  p_request_id uuid
)
returns table (
  reservation_id uuid,
  public_reference text,
  reservation_version bigint,
  expires_at timestamptz,
  order_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  account_record record;
  line_record record;
  order_record record;
  existing_reservation record;
  created_reservation_id uuid;
  created_reference text;
  created_expires_at timestamptz;
  on_hand_quantity numeric(18, 3);
  account_reserved_quantity numeric(18, 3);
  line_reserved_quantity numeric(18, 3);
  remaining_quantity numeric(18, 3);
  next_line_status text;
  next_order_status text;
  next_order_version bigint;
  previous_line_state jsonb;
  next_line_state jsonb;
  created_reservation_state jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode = '22023', message = 'reservation_quantity_invalid';
  end if;

  select
    account.id,
    account.item_id,
    account.warehouse_id,
    account.account_kind,
    account.stock_state,
    account.status,
    item.inventory_mode
  into account_record
  from public.inventory_accounts as account
  join public.items as item on item.id = account.item_id
  where account.id = p_inventory_account_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'inventory_account_not_found';
  end if;
  if account_record.account_kind <> 'physical'
    or account_record.stock_state <> 'available'
    or account_record.status <> 'active' then
    raise exception using errcode = '22023', message = 'inventory_account_not_reservable';
  end if;
  if account_record.inventory_mode <> 'fungible' then
    raise exception using errcode = '22023', message = 'serialized_reservation_requires_asset_registry';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'reservation.manage',
    account_record.warehouse_id,
    p_reason,
    p_request_id
  );

  select reservation.* into existing_reservation
  from public.reservations as reservation
  where reservation.source_request_id = p_request_id;
  if found then
    if existing_reservation.order_line_id <> p_order_line_id
      or existing_reservation.inventory_account_id <> p_inventory_account_id
      or existing_reservation.quantity <> p_quantity then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    select current_order.version into next_order_version
    from public.orders as current_order
    join public.order_lines as current_line on current_line.order_id = current_order.id
    where current_line.id = p_order_line_id;
    return query
    select
      existing_reservation.id,
      existing_reservation.public_reference,
      existing_reservation.version,
      existing_reservation.expires_at,
      next_order_version,
      (select current_line.status from public.order_lines as current_line
        where current_line.id = p_order_line_id);
    return;
  end if;

  perform 1
  from public.inventory_accounts as account
  where account.id = p_inventory_account_id
  for update;

  select
    line.*,
    current_order.id as current_order_id,
    current_order.status as current_order_status,
    current_order.version as current_order_version
  into line_record
  from public.order_lines as line
  join public.orders as current_order on current_order.id = line.order_id
  where line.id = p_order_line_id
  for update of current_order, line;
  if not found then
    raise exception using errcode = 'P0002', message = 'order_line_not_found';
  end if;
  if line_record.item_id <> account_record.item_id then
    raise exception using errcode = '22023', message = 'reservation_item_mismatch';
  end if;
  if line_record.quantity_approved is null
    or line_record.status not in (
      'approved', 'partially_approved', 'awaiting_stock',
      'partially_awaiting_stock', 'reserved'
    ) then
    raise exception using errcode = '22023', message = 'order_line_not_reservable';
  end if;

  select coalesce(sum(entry.quantity_delta), 0)
  into on_hand_quantity
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = p_inventory_account_id;
  select coalesce(sum(reservation.quantity), 0)
  into account_reserved_quantity
  from public.reservations as reservation
  where reservation.inventory_account_id = p_inventory_account_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();
  if on_hand_quantity - account_reserved_quantity < p_quantity then
    raise exception using errcode = '22023', message = 'inventory_available_insufficient';
  end if;

  select coalesce(sum(reservation.quantity), 0)
  into line_reserved_quantity
  from public.reservations as reservation
  where reservation.order_line_id = p_order_line_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();
  remaining_quantity := line_record.quantity_approved
    - line_record.quantity_fulfilled
    - line_reserved_quantity;
  if p_quantity > remaining_quantity then
    raise exception using errcode = '22023', message = 'reservation_exceeds_approved_quantity';
  end if;

  created_reference := private.allocate_reservation_reference();
  created_expires_at := statement_timestamp() + interval '48 hours';
  insert into public.reservations (
    public_reference,
    order_line_id,
    inventory_account_id,
    quantity,
    expires_at,
    created_by_actor_id,
    source_request_id
  )
  values (
    created_reference,
    p_order_line_id,
    p_inventory_account_id,
    p_quantity,
    created_expires_at,
    actor_id,
    p_request_id
  )
  returning id, to_jsonb(reservations.*)
  into created_reservation_id, created_reservation_state;

  previous_line_state := to_jsonb(line_record) - 'current_order_id'
    - 'current_order_status' - 'current_order_version';
  next_line_status := case
    when line_reserved_quantity + p_quantity
      >= line_record.quantity_approved - line_record.quantity_fulfilled
      then 'reserved'
    else 'partially_awaiting_stock'
  end;
  update public.order_lines as line
  set status = next_line_status, version = line.version + 1
  where line.id = p_order_line_id
  returning to_jsonb(line.*) into next_line_state;

  next_order_status := private.derive_order_status(line_record.current_order_id);
  update public.orders as current_order
  set status = next_order_status, version = current_order.version + 1
  where current_order.id = line_record.current_order_id
  returning current_order.version into next_order_version;

  insert into public.reservation_events (
    reservation_id,
    event_type,
    new_state,
    changed_by_actor_id,
    reason,
    request_id
  )
  values (
    created_reservation_id,
    'created',
    created_reservation_state,
    actor_id,
    btrim(p_reason),
    p_request_id
  );

  insert into public.order_line_events (
    order_line_id,
    order_id,
    event_type,
    previous_state,
    new_state,
    changed_by,
    reason,
    request_id
  )
  values (
    p_order_line_id,
    line_record.current_order_id,
    'reservation_changed',
    previous_line_state,
    next_line_state,
    actor_id,
    btrim(p_reason),
    p_request_id
  );

  if next_order_status <> line_record.current_order_status then
    insert into public.order_status_events (
      order_id,
      previous_status,
      new_status,
      event_type,
      changed_by,
      reason,
      request_id
    )
    values (
      line_record.current_order_id,
      line_record.current_order_status,
      next_order_status,
      'status_changed',
      actor_id,
      btrim(p_reason),
      p_request_id
    );
  end if;

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  )
  values (
    'reservation.created',
    'reservation',
    created_reservation_id,
    jsonb_build_object(
      'reservation_id', created_reservation_id,
      'public_reference', created_reference,
      'order_line_id', p_order_line_id,
      'inventory_account_id', p_inventory_account_id,
      'quantity', p_quantity,
      'expires_at', created_expires_at
    ),
    'reservation.created:' || p_request_id::text
  );

  return query
  select created_reservation_id, created_reference, 1::bigint,
    created_expires_at, next_order_version, next_line_status;
end;
$$;

create function public.staff_extend_reservation(
  p_reservation_id uuid,
  p_expected_version bigint,
  p_expires_at timestamptz,
  p_reason text,
  p_request_id uuid
)
returns table (reservation_id uuid, version bigint, expires_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  current_reservation record;
  existing_event record;
  next_state jsonb;
  next_version bigint;
begin
  select reservation.*, account.warehouse_id
  into current_reservation
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  where reservation.id = p_reservation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'reservation_not_found';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'reservation.extend',
    current_reservation.warehouse_id,
    p_reason,
    p_request_id
  );

  select event.reservation_id, event.event_type into existing_event
  from public.reservation_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.reservation_id <> p_reservation_id
      or existing_event.event_type <> 'extended' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select reservation.id, reservation.version, reservation.expires_at
    from public.reservations as reservation
    where reservation.id = p_reservation_id;
    return;
  end if;

  select reservation.* into current_reservation
  from public.reservations as reservation
  where reservation.id = p_reservation_id
  for update;
  if current_reservation.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'reservation_version_conflict';
  end if;
  if current_reservation.status <> 'active'
    or current_reservation.expires_at <= statement_timestamp() then
    raise exception using errcode = '22023', message = 'reservation_extension_invalid';
  end if;
  if p_expires_at is null or p_expires_at <= current_reservation.expires_at then
    raise exception using errcode = '22023', message = 'reservation_expiration_invalid';
  end if;

  update public.reservations as reservation
  set expires_at = p_expires_at, version = reservation.version + 1
  where reservation.id = p_reservation_id
  returning reservation.version, to_jsonb(reservation.*)
  into next_version, next_state;

  insert into public.reservation_events (
    reservation_id,
    event_type,
    previous_state,
    new_state,
    changed_by_actor_id,
    reason,
    request_id
  )
  values (
    p_reservation_id,
    'extended',
    to_jsonb(current_reservation),
    next_state,
    actor_id,
    btrim(p_reason),
    p_request_id
  );

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  )
  values (
    'reservation.extended',
    'reservation',
    p_reservation_id,
    jsonb_build_object('reservation_id', p_reservation_id, 'expires_at', p_expires_at),
    'reservation.extended:' || p_request_id::text
  );

  return query select p_reservation_id, next_version, p_expires_at;
end;
$$;

create function private.terminate_reservation(
  p_reservation_id uuid,
  p_expected_version bigint,
  p_target_status text,
  p_actor_id uuid,
  p_reason text,
  p_request_id uuid
)
returns table (
  reservation_id uuid,
  reservation_version bigint,
  reservation_status text,
  order_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  existing_event record;
  current_reservation record;
  line_record record;
  next_reservation_state jsonb;
  next_reservation_version bigint;
  remaining_reserved numeric(18, 3);
  next_line_status text;
  previous_line_state jsonb;
  next_line_state jsonb;
  next_order_status text;
  next_order_version bigint;
begin
  if p_target_status not in ('released', 'expired') then
    raise exception using errcode = '22023', message = 'reservation_terminal_status_invalid';
  end if;

  select event.reservation_id, event.event_type into existing_event
  from public.reservation_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.reservation_id <> p_reservation_id
      or existing_event.event_type <> p_target_status then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select
      reservation.id,
      reservation.version,
      reservation.status,
      current_order.version,
      line.status
    from public.reservations as reservation
    join public.order_lines as line on line.id = reservation.order_line_id
    join public.orders as current_order on current_order.id = line.order_id
    where reservation.id = p_reservation_id;
    return;
  end if;

  select reservation.*, account.warehouse_id
  into current_reservation
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  where reservation.id = p_reservation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'reservation_not_found';
  end if;

  perform 1
  from public.inventory_accounts as account
  where account.id = current_reservation.inventory_account_id
  for update;

  select reservation.* into current_reservation
  from public.reservations as reservation
  where reservation.id = p_reservation_id
  for update;
  if current_reservation.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'reservation_version_conflict';
  end if;
  if current_reservation.status <> 'active' then
    raise exception using errcode = '22023', message = 'reservation_release_invalid';
  end if;
  if p_target_status = 'expired'
    and current_reservation.expires_at > statement_timestamp() then
    raise exception using errcode = '22023', message = 'reservation_not_elapsed';
  end if;

  select
    line.*,
    current_order.id as current_order_id,
    current_order.status as current_order_status
  into line_record
  from public.order_lines as line
  join public.orders as current_order on current_order.id = line.order_id
  where line.id = current_reservation.order_line_id
  for update of current_order, line;

  update public.reservations as reservation
  set
    status = p_target_status,
    released_at = statement_timestamp(),
    released_by_actor_id = p_actor_id,
    release_reason = btrim(p_reason),
    version = reservation.version + 1
  where reservation.id = p_reservation_id
  returning reservation.version, to_jsonb(reservation.*)
  into next_reservation_version, next_reservation_state;

  select coalesce(sum(reservation.quantity), 0)
  into remaining_reserved
  from public.reservations as reservation
  where reservation.order_line_id = current_reservation.order_line_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();

  next_line_status := case
    when remaining_reserved >= line_record.quantity_approved - line_record.quantity_fulfilled
      and remaining_reserved > 0 then 'reserved'
    when remaining_reserved > 0 then 'partially_awaiting_stock'
    else 'awaiting_stock'
  end;
  previous_line_state := to_jsonb(line_record) - 'current_order_id' - 'current_order_status';
  update public.order_lines as line
  set status = next_line_status, version = line.version + 1
  where line.id = current_reservation.order_line_id
  returning to_jsonb(line.*) into next_line_state;

  next_order_status := private.derive_order_status(line_record.current_order_id);
  update public.orders as current_order
  set status = next_order_status, version = current_order.version + 1
  where current_order.id = line_record.current_order_id
  returning current_order.version into next_order_version;

  insert into public.reservation_events (
    reservation_id,
    event_type,
    previous_state,
    new_state,
    changed_by_actor_id,
    reason,
    request_id
  )
  values (
    p_reservation_id,
    p_target_status,
    to_jsonb(current_reservation),
    next_reservation_state,
    p_actor_id,
    btrim(p_reason),
    p_request_id
  );

  insert into public.order_line_events (
    order_line_id,
    order_id,
    event_type,
    previous_state,
    new_state,
    changed_by,
    reason,
    request_id
  )
  values (
    current_reservation.order_line_id,
    line_record.current_order_id,
    'reservation_changed',
    previous_line_state,
    next_line_state,
    p_actor_id,
    btrim(p_reason),
    p_request_id
  );

  if next_order_status <> line_record.current_order_status then
    insert into public.order_status_events (
      order_id,
      previous_status,
      new_status,
      event_type,
      changed_by,
      reason,
      request_id
    )
    values (
      line_record.current_order_id,
      line_record.current_order_status,
      next_order_status,
      'status_changed',
      p_actor_id,
      btrim(p_reason),
      p_request_id
    );
  end if;

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  )
  values (
    'reservation.' || p_target_status,
    'reservation',
    p_reservation_id,
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'order_line_id', current_reservation.order_line_id,
      'status', p_target_status
    ),
    'reservation.' || p_target_status || ':' || p_request_id::text
  );

  return query
  select p_reservation_id, next_reservation_version, p_target_status,
    next_order_version, next_line_status;
end;
$$;

create function public.staff_release_reservation(
  p_reservation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (
  reservation_id uuid,
  reservation_version bigint,
  reservation_status text,
  order_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  warehouse_id uuid;
begin
  select account.warehouse_id into warehouse_id
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  where reservation.id = p_reservation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'reservation_not_found';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'reservation.release',
    warehouse_id,
    p_reason,
    p_request_id
  );

  return query
  select released.*
  from private.terminate_reservation(
    p_reservation_id,
    p_expected_version,
    'released',
    actor_id,
    p_reason,
    p_request_id
  ) as released;
end;
$$;

create function public.staff_expire_reservation(
  p_reservation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (
  reservation_id uuid,
  reservation_version bigint,
  reservation_status text,
  order_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  warehouse_id uuid;
begin
  select account.warehouse_id into warehouse_id
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  where reservation.id = p_reservation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'reservation_not_found';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'reservation.release',
    warehouse_id,
    p_reason,
    p_request_id
  );

  return query
  select expired.*
  from private.terminate_reservation(
    p_reservation_id,
    p_expected_version,
    'expired',
    actor_id,
    p_reason,
    p_request_id
  ) as expired;
end;
$$;

revoke all on public.warehouses from anon, authenticated;
revoke all on public.stock_locations from anon, authenticated;
revoke all on public.inventory_accounts from anon, authenticated;
revoke all on public.inventory_transactions from anon, authenticated;
revoke all on public.inventory_ledger_entries from anon, authenticated;
revoke all on public.reservations from anon, authenticated;
revoke all on public.reservation_events from anon, authenticated;

revoke all on function private.current_staff_warehouse_assignments(text, uuid)
  from public, anon, authenticated;
revoke all on function private.set_warehouse_audit_context(text, uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function private.reject_immutable_inventory_change()
  from public, anon, authenticated;
revoke all on function private.validate_inventory_ledger_entry()
  from public, anon, authenticated;
revoke all on function private.assert_inventory_ledger_state()
  from public, anon, authenticated;
revoke all on function private.assert_reservation_availability()
  from public, anon, authenticated;
revoke all on function private.allocate_reservation_reference()
  from public, anon, authenticated;
revoke all on function private.derive_order_status(uuid)
  from public, anon, authenticated;
revoke all on function private.terminate_reservation(
  uuid, bigint, text, uuid, text, uuid
) from public, anon, authenticated;

revoke execute on function public.get_staff_inventory_workspace()
  from public, anon;
revoke execute on function public.staff_post_inventory_receipt(
  uuid, uuid, numeric, text, text, uuid
) from public, anon;
revoke execute on function public.staff_reverse_inventory_transaction(uuid, text, uuid)
  from public, anon;
revoke execute on function public.staff_create_reservation(
  uuid, uuid, numeric, text, uuid
) from public, anon;
revoke execute on function public.staff_extend_reservation(
  uuid, bigint, timestamptz, text, uuid
) from public, anon;
revoke execute on function public.staff_release_reservation(
  uuid, bigint, text, uuid
) from public, anon;
revoke execute on function public.staff_expire_reservation(
  uuid, bigint, text, uuid
) from public, anon;

grant execute on function public.get_staff_inventory_workspace()
  to authenticated;
grant execute on function public.staff_post_inventory_receipt(
  uuid, uuid, numeric, text, text, uuid
) to authenticated;
grant execute on function public.staff_reverse_inventory_transaction(uuid, text, uuid)
  to authenticated;
grant execute on function public.staff_create_reservation(
  uuid, uuid, numeric, text, uuid
) to authenticated;
grant execute on function public.staff_extend_reservation(
  uuid, bigint, timestamptz, text, uuid
) to authenticated;
grant execute on function public.staff_release_reservation(
  uuid, bigint, text, uuid
) to authenticated;
grant execute on function public.staff_expire_reservation(
  uuid, bigint, text, uuid
) to authenticated;
