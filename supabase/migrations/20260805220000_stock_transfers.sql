alter table public.inventory_accounts
  drop constraint inventory_accounts_account_kind_check;
alter table public.inventory_accounts
  drop constraint inventory_accounts_stock_state_check;
alter table public.inventory_accounts
  drop constraint inventory_accounts_check;
alter table public.inventory_accounts
  add constraint inventory_accounts_account_kind_check
  check (account_kind in ('physical', 'custody', 'external'));
alter table public.inventory_accounts
  add constraint inventory_accounts_stock_state_check
  check (stock_state in (
    'available', 'receiving', 'quarantine', 'damaged',
    'in_transit', 'consigned', 'external_source'
  ));
alter table public.inventory_accounts
  add constraint inventory_accounts_shape_check check (
    (
      account_kind = 'physical'
      and owner_party_id is not null
      and custodian_party_id is not null
      and warehouse_id is not null
      and stock_location_id is not null
      and stock_state in ('available', 'receiving', 'quarantine', 'damaged')
    )
    or (
      account_kind = 'custody'
      and owner_party_id is not null
      and custodian_party_id is not null
      and warehouse_id is null
      and stock_location_id is null
      and stock_state in ('in_transit', 'consigned')
    )
    or (
      account_kind = 'external'
      and owner_party_id is null
      and custodian_party_id is null
      and warehouse_id is null
      and stock_location_id is null
      and stock_state = 'external_source'
    )
  );

create unique index inventory_accounts_custody_identity_idx
  on public.inventory_accounts (
    item_id, owner_party_id, custodian_party_id, stock_state
  )
  where account_kind = 'custody';

alter table public.inventory_transactions
  drop constraint inventory_transactions_transaction_type_check;
alter table public.inventory_transactions
  drop constraint inventory_transactions_reversal_shape_check;
alter table public.inventory_transactions
  add constraint inventory_transactions_transaction_type_check
  check (transaction_type in (
    'receipt', 'issue', 'transfer_dispatch', 'transfer_receipt', 'reversal'
  ));
alter table public.inventory_transactions
  add constraint inventory_transactions_reversal_shape_check
  check (
    (
      transaction_type in (
        'receipt', 'issue', 'transfer_dispatch', 'transfer_receipt'
      )
      and reversal_of_id is null
    )
    or (transaction_type = 'reversal' and reversal_of_id is not null)
  );

create table public.stock_transfers (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  item_id uuid not null references public.items(id) on delete restrict,
  quantity numeric(18, 3) not null check (quantity > 0),
  owner_party_id uuid not null references public.parties(id) on delete restrict,
  source_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  destination_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  source_inventory_account_id uuid not null
    references public.inventory_accounts(id) on delete restrict,
  destination_inventory_account_id uuid not null
    references public.inventory_accounts(id) on delete restrict,
  transit_inventory_account_id uuid
    references public.inventory_accounts(id) on delete restrict,
  status text not null default 'requested'
    check (status in (
      'requested', 'authorized', 'dispatched', 'disputed', 'received', 'cancelled'
    )),
  requested_by_actor_id uuid not null
    references public.actor_profiles(id) on delete restrict,
  requested_at timestamptz not null default now(),
  request_reason text not null check (btrim(request_reason) <> ''),
  source_request_id uuid not null unique,
  authorized_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  authorized_at timestamptz,
  authorization_reason text,
  authorization_request_id uuid unique,
  dispatched_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  dispatched_at timestamptz,
  dispatch_reason text,
  dispatch_request_id uuid unique,
  dispatch_transaction_id uuid unique
    references public.inventory_transactions(id) on delete restrict,
  received_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  received_at timestamptz,
  receipt_reason text,
  receipt_request_id uuid unique,
  receipt_transaction_id uuid unique
    references public.inventory_transactions(id) on delete restrict,
  disputed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  disputed_at timestamptz,
  dispute_reason text,
  dispute_request_id uuid unique,
  cancelled_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  cancelled_at timestamptz,
  cancellation_reason text,
  cancellation_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (source_warehouse_id <> destination_warehouse_id),
  check (source_inventory_account_id <> destination_inventory_account_id),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (
    (status = 'requested' and authorized_at is null and dispatched_at is null)
    or (status = 'authorized' and authorized_at is not null and dispatched_at is null)
    or (
      status in ('dispatched', 'disputed')
      and authorized_at is not null
      and dispatched_at is not null
      and received_at is null
      and cancelled_at is null
    )
    or (
      status = 'received'
      and authorized_at is not null
      and dispatched_at is not null
      and received_at is not null
      and cancelled_at is null
    )
    or (status = 'cancelled' and dispatched_at is null and cancelled_at is not null)
  )
);

create table public.stock_transfer_events (
  id uuid primary key default extensions.gen_random_uuid(),
  stock_transfer_id uuid not null references public.stock_transfers(id) on delete restrict,
  event_type text not null check (event_type in (
    'requested', 'authorized', 'dispatched', 'disputed', 'received', 'cancelled'
  )),
  previous_state jsonb,
  new_state jsonb not null,
  changed_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now()
);

comment on table public.stock_transfers is
  'Warehouse-to-warehouse custody workflow. Dispatch and receipt are separate balanced ledger movements through an in-transit account.';
comment on table public.stock_transfer_events is
  'Immutable transfer decision and custody history. Post-dispatch exceptions use dispute or receipt rather than cancellation.';

create index stock_transfers_source_queue_idx
  on public.stock_transfers(source_warehouse_id, status, requested_at desc);
create index stock_transfers_destination_queue_idx
  on public.stock_transfers(destination_warehouse_id, status, requested_at desc);
create index stock_transfer_events_transfer_idx
  on public.stock_transfer_events(stock_transfer_id, created_at);

create trigger stock_transfers_set_updated_at
before update on public.stock_transfers
for each row execute function private.set_updated_at();
create trigger stock_transfers_audit
after insert or update or delete on public.stock_transfers
for each row execute function private.capture_audit_row();
create trigger stock_transfer_events_immutable
before update or delete on public.stock_transfer_events
for each row execute function private.reject_immutable_inventory_change();

alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_events enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  ('inventory.transfer.read', 'Read stock transfers', 'View warehouse transfer queues and immutable transfer history.'),
  ('inventory.transfer.create', 'Request stock transfers', 'Create an auditable warehouse-to-warehouse transfer request.'),
  ('inventory.transfer.authorize', 'Authorize stock transfers', 'Authorize a requested transfer before stock can leave its source warehouse.'),
  ('inventory.transfer.dispatch', 'Dispatch stock transfers', 'Post a balanced source-to-transit movement for an authorized transfer.'),
  ('inventory.transfer.receive', 'Receive stock transfers', 'Post a balanced transit-to-destination movement or record a receiving dispute.'),
  ('inventory.transfer.cancel', 'Cancel pending stock transfers', 'Cancel a transfer before dispatch; dispatched stock must use dispute or return workflows.');

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'warehouse_operator'
  and permission.code in (
    'inventory.transfer.read', 'inventory.transfer.create',
    'inventory.transfer.dispatch', 'inventory.transfer.receive'
  )
) or (
  role.code = 'inventory_controller'
  and permission.code like 'inventory.transfer.%'
) or (
  role.code = 'auditor'
  and permission.code = 'inventory.transfer.read'
);

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values ('stock_transfer', 'EEC-TRN', 1001, 4);

create function private.allocate_stock_transfer_reference()
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
  where reference.document_type = 'stock_transfer'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');
  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'stock_transfer';
  return allocated_reference;
exception
  when no_data_found then
    raise exception using errcode = '55000', message = 'stock_transfer_reference_sequence_unavailable';
end;
$$;

create function private.require_transfer_warehouse_permission(
  p_permission_code text,
  p_warehouse_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from private.current_staff_warehouse_assignments(
      p_permission_code,
      p_warehouse_id
    )
  ) then
    raise exception using errcode = '42501', message = 'staff_warehouse_permission_denied';
  end if;
end;
$$;

create function private.assert_custody_account_nonnegative()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_kind text;
  current_quantity numeric(18, 3);
begin
  select account.account_kind into account_kind
  from public.inventory_accounts as account
  where account.id = new.inventory_account_id;
  if account_kind = 'custody' then
    select coalesce(sum(entry.quantity_delta), 0)
    into current_quantity
    from public.inventory_ledger_entries as entry
    where entry.inventory_account_id = new.inventory_account_id;
    if current_quantity < 0 then
      raise exception using errcode = '23514', message = 'inventory_negative_custody';
    end if;
  end if;
  return null;
end;
$$;

create constraint trigger inventory_custody_nonnegative_check
after insert on public.inventory_ledger_entries
deferrable initially immediate
for each row execute function private.assert_custody_account_nonnegative();

create function public.get_staff_transfer_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from private.current_staff_warehouse_assignments(
      'inventory.transfer.read', null
    )
  ) then
    raise exception using errcode = '42501', message = 'staff_warehouse_permission_denied';
  end if;

  return jsonb_build_object(
    'accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', account.id,
        'warehouse_id', warehouse.id,
        'warehouse_name', warehouse.display_name,
        'location_name', location.display_name,
        'item_id', item.id,
        'item_code', item.item_code,
        'item_name', item.display_name,
        'owner_party_id', account.owner_party_id,
        'on_hand', coalesce(position.on_hand, 0),
        'reserved', coalesce(position.reserved, 0),
        'available', coalesce(position.on_hand, 0) - coalesce(position.reserved, 0)
      ) order by warehouse.display_name, item.display_name, location.display_name)
      from public.inventory_accounts as account
      join public.warehouses as warehouse on warehouse.id = account.warehouse_id
      join public.stock_locations as location on location.id = account.stock_location_id
      join public.items as item on item.id = account.item_id
      left join lateral (
        select
          (select coalesce(sum(entry.quantity_delta), 0)
           from public.inventory_ledger_entries as entry
           where entry.inventory_account_id = account.id) as on_hand,
          (select coalesce(sum(reservation.quantity), 0)
           from public.reservations as reservation
           where reservation.inventory_account_id = account.id
             and reservation.status = 'active'
             and reservation.expires_at > statement_timestamp()) as reserved
      ) as position on true
      where account.account_kind = 'physical'
        and account.status = 'active'
        and account.stock_state = 'available'
        and exists (
          select 1 from private.current_staff_warehouse_assignments(
            'inventory.transfer.read', warehouse.id
          )
        )
    ), '[]'::jsonb),
    'transfers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', transfer.id,
        'public_reference', transfer.public_reference,
        'version', transfer.version,
        'status', transfer.status,
        'quantity', transfer.quantity,
        'requested_at', transfer.requested_at,
        'authorized_at', transfer.authorized_at,
        'dispatched_at', transfer.dispatched_at,
        'received_at', transfer.received_at,
        'disputed_at', transfer.disputed_at,
        'cancelled_at', transfer.cancelled_at,
        'item_code', item.item_code,
        'item_name', item.display_name,
        'source_warehouse_id', source_warehouse.id,
        'source_warehouse_name', source_warehouse.display_name,
        'source_location_name', source_location.display_name,
        'destination_warehouse_id', destination_warehouse.id,
        'destination_warehouse_name', destination_warehouse.display_name,
        'destination_location_name', destination_location.display_name,
        'can_authorize', exists (
          select 1 from private.current_staff_warehouse_assignments(
            'inventory.transfer.authorize', source_warehouse.id
          )
        ),
        'can_dispatch', exists (
          select 1 from private.current_staff_warehouse_assignments(
            'inventory.transfer.dispatch', source_warehouse.id
          )
        ),
        'can_receive', exists (
          select 1 from private.current_staff_warehouse_assignments(
            'inventory.transfer.receive', destination_warehouse.id
          )
        ),
        'can_cancel', exists (
          select 1 from private.current_staff_warehouse_assignments(
            'inventory.transfer.cancel', source_warehouse.id
          )
        )
      ) order by transfer.requested_at desc, transfer.id)
      from public.stock_transfers as transfer
      join public.items as item on item.id = transfer.item_id
      join public.warehouses as source_warehouse
        on source_warehouse.id = transfer.source_warehouse_id
      join public.warehouses as destination_warehouse
        on destination_warehouse.id = transfer.destination_warehouse_id
      join public.inventory_accounts as source_account
        on source_account.id = transfer.source_inventory_account_id
      join public.stock_locations as source_location
        on source_location.id = source_account.stock_location_id
      join public.inventory_accounts as destination_account
        on destination_account.id = transfer.destination_inventory_account_id
      join public.stock_locations as destination_location
        on destination_location.id = destination_account.stock_location_id
      where exists (
        select 1 from private.current_staff_warehouse_assignments(
          'inventory.transfer.read', source_warehouse.id
        )
      ) or exists (
        select 1 from private.current_staff_warehouse_assignments(
          'inventory.transfer.read', destination_warehouse.id
        )
      )
    ), '[]'::jsonb)
  );
end;
$$;

create function public.staff_create_stock_transfer(
  p_source_inventory_account_id uuid,
  p_destination_inventory_account_id uuid,
  p_quantity numeric,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  account_record record;
  existing_transfer record;
  created_transfer_id uuid;
  created_reference text;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode = '22023', message = 'transfer_quantity_invalid';
  end if;
  select
    source_account.item_id,
    source_account.owner_party_id,
    source_account.warehouse_id as source_warehouse_id,
    destination_account.warehouse_id as destination_warehouse_id,
    source_account.account_kind as source_kind,
    destination_account.account_kind as destination_kind,
    source_account.stock_state as source_state,
    destination_account.stock_state as destination_state,
    source_account.status as source_status,
    destination_account.status as destination_status,
    destination_account.item_id as destination_item_id,
    destination_account.owner_party_id as destination_owner_party_id,
    item.inventory_mode
  into account_record
  from public.inventory_accounts as source_account
  join public.inventory_accounts as destination_account
    on destination_account.id = p_destination_inventory_account_id
  join public.items as item on item.id = source_account.item_id
  where source_account.id = p_source_inventory_account_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'transfer_account_not_found';
  end if;
  if account_record.source_kind <> 'physical'
    or account_record.destination_kind <> 'physical'
    or account_record.source_state <> 'available'
    or account_record.destination_state <> 'available'
    or account_record.source_status <> 'active'
    or account_record.destination_status <> 'active'
    or account_record.source_warehouse_id = account_record.destination_warehouse_id
    or account_record.item_id <> account_record.destination_item_id
    or account_record.owner_party_id <> account_record.destination_owner_party_id
  then
    raise exception using errcode = '22023', message = 'transfer_account_incompatible';
  end if;
  if account_record.inventory_mode <> 'fungible' then
    raise exception using errcode = '22023', message = 'serialized_transfer_requires_asset_registry';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.create', account_record.source_warehouse_id,
    p_reason, p_request_id
  );
  perform private.require_transfer_warehouse_permission(
    'inventory.transfer.create', account_record.destination_warehouse_id
  );

  select transfer.id, transfer.public_reference, transfer.version, transfer.status
  into existing_transfer
  from public.stock_transfers as transfer
  where transfer.source_request_id = p_request_id;
  if found then
    return query select existing_transfer.id, existing_transfer.public_reference,
      existing_transfer.version, existing_transfer.status;
    return;
  end if;

  created_reference := private.allocate_stock_transfer_reference();
  insert into public.stock_transfers (
    public_reference, item_id, quantity, owner_party_id,
    source_warehouse_id, destination_warehouse_id,
    source_inventory_account_id, destination_inventory_account_id,
    requested_by_actor_id, request_reason, source_request_id
  ) values (
    created_reference, account_record.item_id, p_quantity,
    account_record.owner_party_id, account_record.source_warehouse_id,
    account_record.destination_warehouse_id, p_source_inventory_account_id,
    p_destination_inventory_account_id, actor_id, btrim(p_reason), p_request_id
  ) returning id into created_transfer_id;

  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, new_state, changed_by_actor_id, reason, request_id
  ) values (
    created_transfer_id, 'requested', jsonb_build_object(
      'status', 'requested', 'quantity', p_quantity,
      'source_warehouse_id', account_record.source_warehouse_id,
      'destination_warehouse_id', account_record.destination_warehouse_id
    ), actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'transfer.requested', 'stock_transfer', created_transfer_id,
    jsonb_build_object('public_reference', created_reference, 'quantity', p_quantity),
    'transfer.requested:' || p_request_id::text
  );
  return query select created_transfer_id, created_reference, 1::bigint, 'requested'::text;
end;
$$;

create function public.staff_authorize_stock_transfer(
  p_stock_transfer_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  transfer_record record;
begin
  select transfer.* into transfer_record
  from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id;
  if not found then raise exception using errcode = 'P0002', message = 'stock_transfer_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.authorize', transfer_record.source_warehouse_id,
    p_reason, p_request_id
  );
  perform private.require_transfer_warehouse_permission(
    'inventory.transfer.authorize', transfer_record.destination_warehouse_id
  );
  if transfer_record.authorization_request_id = p_request_id then
    return query select transfer_record.id, transfer_record.version, transfer_record.status;
    return;
  end if;
  select transfer.* into transfer_record
  from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id for update;
  if transfer_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'stock_transfer_version_conflict';
  end if;
  if transfer_record.status <> 'requested' then
    raise exception using errcode = '22023', message = 'stock_transfer_not_authorizable';
  end if;
  update public.stock_transfers as transfer set
    status = 'authorized', authorized_by_actor_id = actor_id,
    authorized_at = statement_timestamp(), authorization_reason = btrim(p_reason),
    authorization_request_id = p_request_id, version = transfer.version + 1
  where transfer.id = p_stock_transfer_id
  returning transfer.* into transfer_record;
  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    transfer_record.id, 'authorized', jsonb_build_object('status', 'requested'),
    jsonb_build_object('status', 'authorized'), actor_id, btrim(p_reason), p_request_id
  );
  return query select transfer_record.id, transfer_record.version, transfer_record.status;
end;
$$;

create function public.staff_dispatch_stock_transfer(
  p_stock_transfer_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, version bigint, status text, inventory_transaction_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  transfer_record record;
  transit_account_id uuid;
  created_transaction_id uuid;
  current_on_hand numeric(18, 3);
  current_reserved numeric(18, 3);
  in_transit_custodian_id uuid;
begin
  select transfer.* into transfer_record
  from public.stock_transfers as transfer where transfer.id = p_stock_transfer_id;
  if not found then raise exception using errcode = 'P0002', message = 'stock_transfer_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.dispatch', transfer_record.source_warehouse_id,
    p_reason, p_request_id
  );
  if transfer_record.dispatch_request_id = p_request_id then
    return query select transfer_record.id, transfer_record.version,
      transfer_record.status, transfer_record.dispatch_transaction_id;
    return;
  end if;
  select transfer.* into transfer_record
  from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id for update;
  if transfer_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'stock_transfer_version_conflict';
  end if;
  if transfer_record.status <> 'authorized' then
    raise exception using errcode = '22023', message = 'stock_transfer_not_dispatchable';
  end if;
  select warehouse.operating_party_id into strict in_transit_custodian_id
  from public.warehouses as warehouse
  where warehouse.id = transfer_record.source_warehouse_id;

  insert into public.inventory_accounts (
    item_id, account_kind, owner_party_id, custodian_party_id, stock_state
  ) values (
    transfer_record.item_id, 'custody', transfer_record.owner_party_id,
    in_transit_custodian_id, 'in_transit'
  ) on conflict (item_id, owner_party_id, custodian_party_id, stock_state)
    where account_kind = 'custody' do nothing;
  select account.id into strict transit_account_id
  from public.inventory_accounts as account
  where account.account_kind = 'custody'
    and account.item_id = transfer_record.item_id
    and account.owner_party_id = transfer_record.owner_party_id
    and account.custodian_party_id = in_transit_custodian_id
    and account.stock_state = 'in_transit';

  perform 1 from public.inventory_accounts as account
  where account.id in (transfer_record.source_inventory_account_id, transit_account_id)
  order by account.id for update;
  select coalesce(sum(entry.quantity_delta), 0) into current_on_hand
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = transfer_record.source_inventory_account_id;
  select coalesce(sum(reservation.quantity), 0) into current_reserved
  from public.reservations as reservation
  where reservation.inventory_account_id = transfer_record.source_inventory_account_id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();
  if current_on_hand - current_reserved < transfer_record.quantity then
    raise exception using errcode = '23514', message = 'transfer_stock_unavailable';
  end if;

  insert into public.inventory_transactions (
    transaction_type, occurred_at, posted_by_actor_id, permission_code,
    source_reference, reason, request_id
  ) values (
    'transfer_dispatch', statement_timestamp(), actor_id,
    'inventory.transfer.dispatch', transfer_record.public_reference,
    btrim(p_reason), p_request_id
  ) returning id into created_transaction_id;
  insert into public.inventory_ledger_entries (
    inventory_transaction_id, line_number, inventory_account_id, item_id, quantity_delta
  ) values
    (created_transaction_id, 1, transfer_record.source_inventory_account_id, transfer_record.item_id, -transfer_record.quantity),
    (created_transaction_id, 2, transit_account_id, transfer_record.item_id, transfer_record.quantity);
  update public.stock_transfers as transfer set
    status = 'dispatched', transit_inventory_account_id = transit_account_id,
    dispatched_by_actor_id = actor_id, dispatched_at = statement_timestamp(),
    dispatch_reason = btrim(p_reason), dispatch_request_id = p_request_id,
    dispatch_transaction_id = created_transaction_id, version = transfer.version + 1
  where transfer.id = transfer_record.id returning transfer.* into transfer_record;
  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    transfer_record.id, 'dispatched', jsonb_build_object('status', 'authorized'),
    jsonb_build_object('status', 'dispatched', 'transaction_id', created_transaction_id),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'transfer.dispatched', 'stock_transfer', transfer_record.id,
    jsonb_build_object('public_reference', transfer_record.public_reference,
      'quantity', transfer_record.quantity,
      'source_warehouse_id', transfer_record.source_warehouse_id,
      'destination_warehouse_id', transfer_record.destination_warehouse_id),
    'transfer.dispatched:' || p_request_id::text
  );
  return query select transfer_record.id, transfer_record.version,
    transfer_record.status, created_transaction_id;
end;
$$;

create function public.staff_receive_stock_transfer(
  p_stock_transfer_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, version bigint, status text, inventory_transaction_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  transfer_record record;
  created_transaction_id uuid;
  transit_quantity numeric(18, 3);
begin
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id;
  if not found then raise exception using errcode = 'P0002', message = 'stock_transfer_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.receive', transfer_record.destination_warehouse_id,
    p_reason, p_request_id
  );
  if transfer_record.receipt_request_id = p_request_id then
    return query select transfer_record.id, transfer_record.version,
      transfer_record.status, transfer_record.receipt_transaction_id;
    return;
  end if;
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id for update;
  if transfer_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'stock_transfer_version_conflict';
  end if;
  if transfer_record.status not in ('dispatched', 'disputed') then
    raise exception using errcode = '22023', message = 'stock_transfer_not_receivable';
  end if;
  perform 1 from public.inventory_accounts as account
  where account.id in (
    transfer_record.transit_inventory_account_id,
    transfer_record.destination_inventory_account_id
  ) order by account.id for update;
  select coalesce(sum(entry.quantity_delta), 0) into transit_quantity
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = transfer_record.transit_inventory_account_id;
  if transit_quantity < transfer_record.quantity then
    raise exception using errcode = '23514', message = 'transfer_transit_stock_unavailable';
  end if;
  insert into public.inventory_transactions (
    transaction_type, occurred_at, posted_by_actor_id, permission_code,
    source_reference, reason, request_id
  ) values (
    'transfer_receipt', statement_timestamp(), actor_id,
    'inventory.transfer.receive', transfer_record.public_reference,
    btrim(p_reason), p_request_id
  ) returning id into created_transaction_id;
  insert into public.inventory_ledger_entries (
    inventory_transaction_id, line_number, inventory_account_id, item_id, quantity_delta
  ) values
    (created_transaction_id, 1, transfer_record.transit_inventory_account_id, transfer_record.item_id, -transfer_record.quantity),
    (created_transaction_id, 2, transfer_record.destination_inventory_account_id, transfer_record.item_id, transfer_record.quantity);
  update public.stock_transfers as transfer set
    status = 'received', received_by_actor_id = actor_id,
    received_at = statement_timestamp(), receipt_reason = btrim(p_reason),
    receipt_request_id = p_request_id,
    receipt_transaction_id = created_transaction_id,
    version = transfer.version + 1
  where transfer.id = transfer_record.id returning transfer.* into transfer_record;
  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    transfer_record.id, 'received', jsonb_build_object('status', case when transfer_record.disputed_at is null then 'dispatched' else 'disputed' end),
    jsonb_build_object('status', 'received', 'transaction_id', created_transaction_id),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'transfer.received', 'stock_transfer', transfer_record.id,
    jsonb_build_object('public_reference', transfer_record.public_reference,
      'quantity', transfer_record.quantity,
      'destination_warehouse_id', transfer_record.destination_warehouse_id),
    'transfer.received:' || p_request_id::text
  );
  return query select transfer_record.id, transfer_record.version,
    transfer_record.status, created_transaction_id;
end;
$$;

create function public.staff_dispute_stock_transfer(
  p_stock_transfer_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; transfer_record record;
begin
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id;
  if not found then raise exception using errcode = 'P0002', message = 'stock_transfer_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.receive', transfer_record.destination_warehouse_id,
    p_reason, p_request_id
  );
  if transfer_record.dispute_request_id = p_request_id then
    return query select transfer_record.id, transfer_record.version, transfer_record.status;
    return;
  end if;
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id for update;
  if transfer_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'stock_transfer_version_conflict';
  end if;
  if transfer_record.status <> 'dispatched' then
    raise exception using errcode = '22023', message = 'stock_transfer_not_disputable';
  end if;
  update public.stock_transfers as transfer set
    status = 'disputed', disputed_by_actor_id = actor_id,
    disputed_at = statement_timestamp(), dispute_reason = btrim(p_reason),
    dispute_request_id = p_request_id, version = transfer.version + 1
  where transfer.id = transfer_record.id returning transfer.* into transfer_record;
  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    transfer_record.id, 'disputed', jsonb_build_object('status', 'dispatched'),
    jsonb_build_object('status', 'disputed'), actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'transfer.disputed', 'stock_transfer', transfer_record.id,
    jsonb_build_object('public_reference', transfer_record.public_reference,
      'reason', btrim(p_reason)), 'transfer.disputed:' || p_request_id::text
  );
  return query select transfer_record.id, transfer_record.version, transfer_record.status;
end;
$$;

create function public.staff_cancel_stock_transfer(
  p_stock_transfer_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (stock_transfer_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; transfer_record record; previous_status text;
begin
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id;
  if not found then raise exception using errcode = 'P0002', message = 'stock_transfer_not_found'; end if;
  actor_id := private.set_warehouse_audit_context(
    'inventory.transfer.cancel', transfer_record.source_warehouse_id,
    p_reason, p_request_id
  );
  if transfer_record.cancellation_request_id = p_request_id then
    return query select transfer_record.id, transfer_record.version, transfer_record.status;
    return;
  end if;
  select transfer.* into transfer_record from public.stock_transfers as transfer
  where transfer.id = p_stock_transfer_id for update;
  if transfer_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'stock_transfer_version_conflict';
  end if;
  if transfer_record.status not in ('requested', 'authorized') then
    raise exception using errcode = '22023', message = 'stock_transfer_not_cancellable';
  end if;
  previous_status := transfer_record.status;
  update public.stock_transfers as transfer set
    status = 'cancelled', cancelled_by_actor_id = actor_id,
    cancelled_at = statement_timestamp(), cancellation_reason = btrim(p_reason),
    cancellation_request_id = p_request_id, version = transfer.version + 1
  where transfer.id = transfer_record.id returning transfer.* into transfer_record;
  insert into public.stock_transfer_events (
    stock_transfer_id, event_type, previous_state, new_state,
    changed_by_actor_id, reason, request_id
  ) values (
    transfer_record.id, 'cancelled', jsonb_build_object('status', previous_status),
    jsonb_build_object('status', 'cancelled'), actor_id, btrim(p_reason), p_request_id
  );
  return query select transfer_record.id, transfer_record.version, transfer_record.status;
end;
$$;

insert into public.notification_templates (
  code, event_type, destination_type, message_template
)
values
  ('staff-transfer-requested-v1', 'transfer.requested', 'discord_channel', 'Transfer {{public_reference}} was requested for quantity {{quantity}}.'),
  ('staff-transfer-dispatched-v1', 'transfer.dispatched', 'discord_channel', 'Transfer {{public_reference}} is in transit. Quantity: {{quantity}}.'),
  ('staff-transfer-received-v1', 'transfer.received', 'discord_channel', 'Transfer {{public_reference}} was received. Quantity: {{quantity}}.'),
  ('staff-transfer-disputed-v1', 'transfer.disputed', 'discord_channel', 'Transfer {{public_reference}} was disputed. Reason: {{reason}}.');

insert into public.integration_event_routes (
  event_type, destination_id, notification_template_id, active
)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type like 'transfer.%';

revoke all on public.stock_transfers from anon, authenticated;
revoke all on public.stock_transfer_events from anon, authenticated;
revoke all on function private.allocate_stock_transfer_reference() from public, anon, authenticated;
revoke all on function private.require_transfer_warehouse_permission(text, uuid) from public, anon, authenticated;
revoke all on function private.assert_custody_account_nonnegative() from public, anon, authenticated;
revoke all on function public.get_staff_transfer_workspace() from public, anon;
revoke all on function public.staff_create_stock_transfer(uuid, uuid, numeric, text, uuid) from public, anon;
revoke all on function public.staff_authorize_stock_transfer(uuid, bigint, text, uuid) from public, anon;
revoke all on function public.staff_dispatch_stock_transfer(uuid, bigint, text, uuid) from public, anon;
revoke all on function public.staff_receive_stock_transfer(uuid, bigint, text, uuid) from public, anon;
revoke all on function public.staff_dispute_stock_transfer(uuid, bigint, text, uuid) from public, anon;
revoke all on function public.staff_cancel_stock_transfer(uuid, bigint, text, uuid) from public, anon;
grant execute on function public.get_staff_transfer_workspace() to authenticated;
grant execute on function public.staff_create_stock_transfer(uuid, uuid, numeric, text, uuid) to authenticated;
grant execute on function public.staff_authorize_stock_transfer(uuid, bigint, text, uuid) to authenticated;
grant execute on function public.staff_dispatch_stock_transfer(uuid, bigint, text, uuid) to authenticated;
grant execute on function public.staff_receive_stock_transfer(uuid, bigint, text, uuid) to authenticated;
grant execute on function public.staff_dispute_stock_transfer(uuid, bigint, text, uuid) to authenticated;
grant execute on function public.staff_cancel_stock_transfer(uuid, bigint, text, uuid) to authenticated;
