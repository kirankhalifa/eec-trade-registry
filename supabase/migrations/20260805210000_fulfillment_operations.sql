alter table public.inventory_transactions
  drop constraint inventory_transactions_transaction_type_check;
alter table public.inventory_transactions
  drop constraint inventory_transactions_check;
alter table public.inventory_transactions
  add constraint inventory_transactions_transaction_type_check
  check (transaction_type in ('receipt', 'issue', 'reversal'));
alter table public.inventory_transactions
  add constraint inventory_transactions_reversal_shape_check
  check (
    (transaction_type in ('receipt', 'issue') and reversal_of_id is null)
    or (transaction_type = 'reversal' and reversal_of_id is not null)
  );

alter table public.reservations
  add column consumed_at timestamptz,
  add column consumed_by_actor_id uuid
    references public.actor_profiles(id) on delete restrict,
  add column consumption_transaction_id uuid unique
    references public.inventory_transactions(id) on delete restrict,
  add constraint reservations_consumption_state_check check (
    (
      status = 'consumed'
      and consumed_at is not null
      and consumed_by_actor_id is not null
      and consumption_transaction_id is not null
    )
    or (
      status <> 'consumed'
      and consumed_at is null
      and consumed_by_actor_id is null
      and consumption_transaction_id is null
    )
  );

alter table public.reservation_events
  drop constraint reservation_events_event_type_check;
alter table public.reservation_events
  add constraint reservation_events_event_type_check
  check (event_type in ('created', 'extended', 'released', 'expired', 'consumed'));

alter table public.order_line_events
  drop constraint order_line_events_event_type_check;
alter table public.order_line_events
  add constraint order_line_events_event_type_check
  check (event_type in (
    'submitted', 'reviewed', 'price_changed', 'reservation_changed',
    'fulfillment_changed', 'cancelled'
  ));

create table public.order_fulfillments (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  order_id uuid not null references public.orders(id) on delete restrict,
  order_line_id uuid not null references public.order_lines(id) on delete restrict,
  reservation_id uuid not null unique references public.reservations(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  inventory_transaction_id uuid not null unique
    references public.inventory_transactions(id) on delete restrict,
  fulfillment_mode text not null
    check (fulfillment_mode in ('collection', 'delivery', 'consignment')),
  quantity numeric(18, 3) not null check (quantity > 0),
  status text not null default 'completed'
    check (status in ('completed', 'reversed')),
  completed_at timestamptz not null default now(),
  completed_by_actor_id uuid not null
    references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  reversed_at timestamptz,
  reversed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  reversal_reason text,
  reversal_request_id uuid unique,
  reversal_transaction_id uuid unique
    references public.inventory_transactions(id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (order_line_id, order_id)
    references public.order_lines(id, order_id) on delete restrict,
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (
    (
      status = 'completed'
      and reversed_at is null
      and reversed_by_actor_id is null
      and reversal_reason is null
      and reversal_request_id is null
      and reversal_transaction_id is null
    )
    or (
      status = 'reversed'
      and reversed_at is not null
      and reversed_by_actor_id is not null
      and btrim(reversal_reason) <> ''
      and reversal_request_id is not null
      and reversal_transaction_id is not null
    )
  )
);

comment on table public.order_fulfillments is
  'Authoritative completion evidence linking one consumed fungible reservation to one balanced stock issue. Reversals restore stock but never reactivate the consumed claim.';
comment on column public.order_fulfillments.inventory_transaction_id is
  'Balanced physical-to-external inventory issue. The order records the recipient; the external ledger account is not a custody registry.';

create index order_fulfillments_order_idx
  on public.order_fulfillments(order_id, completed_at desc);
create index order_fulfillments_warehouse_idx
  on public.order_fulfillments(warehouse_id, completed_at desc);

create trigger order_fulfillments_set_updated_at
before update on public.order_fulfillments
for each row execute function private.set_updated_at();
create trigger order_fulfillments_audit
after insert or update or delete on public.order_fulfillments
for each row execute function private.capture_audit_row();

alter table public.order_fulfillments enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'inventory.fulfillment.read',
    'Read fulfillment operations',
    'View consumable reservations and completed or reversed stock issues in assigned warehouses.'
  ),
  (
    'inventory.fulfillment.post',
    'Post order fulfillment',
    'Consume a current fungible reservation and post its balanced stock issue atomically.'
  ),
  (
    'inventory.fulfillment.reverse',
    'Reverse order fulfillment',
    'Post a linked stock reversal and reopen authoritative demand without reactivating the consumed reservation.'
  );

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'warehouse_operator'
  and permission.code in (
    'inventory.fulfillment.read', 'inventory.fulfillment.post'
  )
) or (
  role.code = 'inventory_controller'
  and permission.code in (
    'inventory.fulfillment.read', 'inventory.fulfillment.post',
    'inventory.fulfillment.reverse'
  )
) or (
  role.code = 'order_officer'
  and permission.code = 'inventory.fulfillment.read'
);

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values ('fulfillment', 'EEC-FUL', 1001, 4);

create function private.allocate_fulfillment_reference()
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
  where reference.document_type = 'fulfillment'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix
    || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');

  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'fulfillment';

  return allocated_reference;
exception
  when no_data_found then
    raise exception using
      errcode = '55000',
      message = 'fulfillment_reference_sequence_unavailable';
end;
$$;

create function public.get_staff_fulfillment_workspace()
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
      'inventory.fulfillment.read',
      null
    )
  ) then
    raise exception using
      errcode = '42501',
      message = 'staff_warehouse_permission_denied';
  end if;

  return jsonb_build_object(
    'ready_reservations', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', reservation.id,
            'public_reference', reservation.public_reference,
            'version', reservation.version,
            'quantity', reservation.quantity,
            'expires_at', reservation.expires_at,
            'warehouse_id', warehouse.id,
            'warehouse_name', warehouse.display_name,
            'location_name', location.display_name,
            'order_id', order_record.id,
            'order_reference', order_record.public_reference,
            'fulfillment_mode', order_record.fulfillment_mode,
            'ordering_party_name', ordering_party.display_name,
            'order_line_id', line.id,
            'line_number', line.line_number,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'unit_code', line.unit_code_snapshot,
            'quantity_approved', line.quantity_approved,
            'quantity_fulfilled', line.quantity_fulfilled
          ) order by reservation.expires_at, reservation.public_reference
        )
        from public.reservations as reservation
        join public.inventory_accounts as account
          on account.id = reservation.inventory_account_id
        join public.warehouses as warehouse on warehouse.id = account.warehouse_id
        join public.stock_locations as location on location.id = account.stock_location_id
        join public.order_lines as line on line.id = reservation.order_line_id
        join public.orders as order_record on order_record.id = line.order_id
        join public.parties as ordering_party
          on ordering_party.id = order_record.ordering_party_id
        join public.items as item on item.id = line.item_id
        where reservation.status = 'active'
          and reservation.expires_at > statement_timestamp()
          and account.account_kind = 'physical'
          and account.stock_state = 'available'
          and account.status = 'active'
          and item.inventory_mode = 'fungible'
          and line.quantity_approved is not null
          and line.quantity_fulfilled + reservation.quantity <= line.quantity_approved
          and exists (
            select 1
            from private.current_staff_warehouse_assignments(
              'inventory.fulfillment.post',
              warehouse.id
            )
          )
      ),
      '[]'::jsonb
    ),
    'fulfillments', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', fulfillment.id,
            'public_reference', fulfillment.public_reference,
            'version', fulfillment.version,
            'status', fulfillment.status,
            'quantity', fulfillment.quantity,
            'fulfillment_mode', fulfillment.fulfillment_mode,
            'completed_at', fulfillment.completed_at,
            'reversed_at', fulfillment.reversed_at,
            'warehouse_id', warehouse.id,
            'warehouse_name', warehouse.display_name,
            'order_reference', order_record.public_reference,
            'ordering_party_name', ordering_party.display_name,
            'line_number', line.line_number,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'unit_code', line.unit_code_snapshot,
            'inventory_transaction_id', fulfillment.inventory_transaction_id,
            'reversal_transaction_id', fulfillment.reversal_transaction_id,
            'can_reverse', fulfillment.status = 'completed'
              and exists (
                select 1
                from private.current_staff_warehouse_assignments(
                  'inventory.fulfillment.reverse',
                  warehouse.id
                )
              )
          ) order by fulfillment.completed_at desc, fulfillment.id
        )
        from public.order_fulfillments as fulfillment
        join public.warehouses as warehouse on warehouse.id = fulfillment.warehouse_id
        join public.orders as order_record on order_record.id = fulfillment.order_id
        join public.parties as ordering_party
          on ordering_party.id = order_record.ordering_party_id
        join public.order_lines as line on line.id = fulfillment.order_line_id
        where exists (
          select 1
          from private.current_staff_warehouse_assignments(
            'inventory.fulfillment.read',
            warehouse.id
          )
        )
        limit 100
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create function public.staff_fulfill_reservation(
  p_reservation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (
  fulfillment_id uuid,
  public_reference text,
  inventory_transaction_id uuid,
  reservation_version bigint,
  order_version bigint,
  line_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  reservation_record record;
  line_record record;
  existing_fulfillment record;
  external_account_id uuid;
  issue_transaction_id uuid;
  created_fulfillment_id uuid;
  created_reference text;
  next_reservation_state jsonb;
  next_reservation_version bigint;
  next_line_state jsonb;
  next_line_version bigint;
  next_line_status text;
  next_order_status text;
  next_order_version bigint;
  remaining_reserved numeric(18, 3);
  current_on_hand numeric(18, 3);
begin
  select
    reservation.*,
    account.item_id as account_item_id,
    account.warehouse_id,
    account.account_kind,
    account.stock_state,
    account.status as account_status,
    item.inventory_mode
  into reservation_record
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  join public.items as item on item.id = account.item_id
  where reservation.id = p_reservation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'reservation_not_found';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'inventory.fulfillment.post',
    reservation_record.warehouse_id,
    p_reason,
    p_request_id
  );

  select fulfillment.* into existing_fulfillment
  from public.order_fulfillments as fulfillment
  where fulfillment.source_request_id = p_request_id;
  if found then
    if existing_fulfillment.reservation_id <> p_reservation_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select
      existing_fulfillment.id,
      existing_fulfillment.public_reference,
      existing_fulfillment.inventory_transaction_id,
      reservation.version,
      order_record.version,
      line.version,
      line.status
    from public.reservations as reservation
    join public.order_lines as line on line.id = reservation.order_line_id
    join public.orders as order_record on order_record.id = line.order_id
    where reservation.id = p_reservation_id;
    return;
  end if;

  perform 1
  from public.inventory_accounts as account
  where account.id = reservation_record.inventory_account_id
  for update;

  select
    reservation.*,
    account.item_id as account_item_id,
    account.warehouse_id,
    account.account_kind,
    account.stock_state,
    account.status as account_status,
    item.inventory_mode
  into reservation_record
  from public.reservations as reservation
  join public.inventory_accounts as account
    on account.id = reservation.inventory_account_id
  join public.items as item on item.id = account.item_id
  where reservation.id = p_reservation_id
  for update of reservation;

  select
    line.*,
    order_record.id as current_order_id,
    order_record.status as current_order_status,
    order_record.fulfillment_mode
  into line_record
  from public.order_lines as line
  join public.orders as order_record on order_record.id = line.order_id
  where line.id = reservation_record.order_line_id
  for update of order_record, line;

  if reservation_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'reservation_version_conflict';
  end if;
  if reservation_record.status <> 'active'
    or reservation_record.expires_at <= statement_timestamp() then
    raise exception using errcode = '22023', message = 'reservation_not_fulfillable';
  end if;
  if reservation_record.account_kind <> 'physical'
    or reservation_record.stock_state <> 'available'
    or reservation_record.account_status <> 'active' then
    raise exception using errcode = '22023', message = 'inventory_account_not_fulfillable';
  end if;
  if reservation_record.inventory_mode <> 'fungible' then
    raise exception using errcode = '22023', message = 'serialized_fulfillment_requires_asset_registry';
  end if;
  if line_record.item_id <> reservation_record.account_item_id
    or line_record.quantity_approved is null
    or line_record.quantity_fulfilled + reservation_record.quantity
      > line_record.quantity_approved then
    raise exception using errcode = '22023', message = 'fulfillment_exceeds_approved_quantity';
  end if;

  select coalesce(sum(entry.quantity_delta), 0)
  into current_on_hand
  from public.inventory_ledger_entries as entry
  where entry.inventory_account_id = reservation_record.inventory_account_id;
  if current_on_hand < reservation_record.quantity then
    raise exception using errcode = '23514', message = 'inventory_fulfillment_stock_insufficient';
  end if;

  insert into public.inventory_accounts (item_id, account_kind, stock_state)
  values (reservation_record.account_item_id, 'external', 'external_source')
  on conflict (item_id) where account_kind = 'external'
  do nothing;

  select account.id into strict external_account_id
  from public.inventory_accounts as account
  where account.item_id = reservation_record.account_item_id
    and account.account_kind = 'external';

  perform 1
  from public.inventory_accounts as account
  where account.id in (
    reservation_record.inventory_account_id,
    external_account_id
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
    request_id
  )
  values (
    'issue',
    statement_timestamp(),
    actor_id,
    'inventory.fulfillment.post',
    'Fulfillment of ' || reservation_record.public_reference,
    btrim(p_reason),
    p_request_id
  )
  returning id into issue_transaction_id;

  update public.reservations as reservation
  set
    status = 'consumed',
    consumed_at = statement_timestamp(),
    consumed_by_actor_id = actor_id,
    consumption_transaction_id = issue_transaction_id,
    version = reservation.version + 1
  where reservation.id = p_reservation_id
  returning reservation.version, to_jsonb(reservation.*)
  into next_reservation_version, next_reservation_state;

  insert into public.inventory_ledger_entries (
    inventory_transaction_id,
    line_number,
    inventory_account_id,
    item_id,
    quantity_delta
  )
  values
    (
      issue_transaction_id,
      1,
      reservation_record.inventory_account_id,
      reservation_record.account_item_id,
      -reservation_record.quantity
    ),
    (
      issue_transaction_id,
      2,
      external_account_id,
      reservation_record.account_item_id,
      reservation_record.quantity
    );

  created_reference := private.allocate_fulfillment_reference();
  insert into public.order_fulfillments (
    public_reference,
    order_id,
    order_line_id,
    reservation_id,
    warehouse_id,
    inventory_transaction_id,
    fulfillment_mode,
    quantity,
    completed_by_actor_id,
    source_request_id
  )
  values (
    created_reference,
    line_record.current_order_id,
    line_record.id,
    p_reservation_id,
    reservation_record.warehouse_id,
    issue_transaction_id,
    line_record.fulfillment_mode,
    reservation_record.quantity,
    actor_id,
    p_request_id
  )
  returning id into created_fulfillment_id;

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
    'consumed',
    to_jsonb(reservation_record)
      - 'account_item_id' - 'warehouse_id' - 'account_kind'
      - 'stock_state' - 'account_status' - 'inventory_mode',
    next_reservation_state,
    actor_id,
    btrim(p_reason),
    p_request_id
  );

  select coalesce(sum(reservation.quantity), 0)
  into remaining_reserved
  from public.reservations as reservation
  where reservation.order_line_id = line_record.id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();

  next_line_status := case
    when line_record.quantity_fulfilled + reservation_record.quantity
      >= line_record.quantity_approved then 'fulfilled'
    when remaining_reserved
      >= line_record.quantity_approved
        - line_record.quantity_fulfilled
        - reservation_record.quantity then 'reserved'
    when remaining_reserved > 0 then 'partially_awaiting_stock'
    else 'awaiting_stock'
  end;

  update public.order_lines as line
  set
    quantity_fulfilled = line.quantity_fulfilled + reservation_record.quantity,
    status = next_line_status,
    version = line.version + 1
  where line.id = line_record.id
  returning line.version, to_jsonb(line.*)
  into next_line_version, next_line_state;

  next_order_status := private.derive_order_status(line_record.current_order_id);
  update public.orders as order_record
  set status = next_order_status, version = order_record.version + 1
  where order_record.id = line_record.current_order_id
  returning order_record.version into next_order_version;

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
    line_record.id,
    line_record.current_order_id,
    'fulfillment_changed',
    to_jsonb(line_record)
      - 'current_order_id' - 'current_order_status' - 'fulfillment_mode',
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
    'fulfillment.completed',
    'order_fulfillment',
    created_fulfillment_id,
    jsonb_build_object(
      'fulfillment_id', created_fulfillment_id,
      'public_reference', created_reference,
      'order_id', line_record.current_order_id,
      'order_reference', (
        select order_record.public_reference
        from public.orders as order_record
        where order_record.id = line_record.current_order_id
      ),
      'order_line_id', line_record.id,
      'reservation_id', p_reservation_id,
      'warehouse_id', reservation_record.warehouse_id,
      'item_id', reservation_record.account_item_id,
      'quantity', reservation_record.quantity,
      'fulfillment_mode', line_record.fulfillment_mode
    ),
    'fulfillment.completed:' || p_request_id::text
  );

  return query
  select
    created_fulfillment_id,
    created_reference,
    issue_transaction_id,
    next_reservation_version,
    next_order_version,
    next_line_version,
    next_line_status;
end;
$$;

create function public.staff_reverse_fulfillment(
  p_fulfillment_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (
  fulfillment_id uuid,
  fulfillment_version bigint,
  reversal_transaction_id uuid,
  order_version bigint,
  line_version bigint,
  line_status text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  fulfillment_record record;
  line_record record;
  created_reversal_id uuid;
  next_fulfillment_version bigint;
  next_line_version bigint;
  next_line_status text;
  next_line_state jsonb;
  next_order_status text;
  next_order_version bigint;
  remaining_reserved numeric(18, 3);
begin
  select fulfillment.* into fulfillment_record
  from public.order_fulfillments as fulfillment
  where fulfillment.id = p_fulfillment_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'fulfillment_not_found';
  end if;

  actor_id := private.set_warehouse_audit_context(
    'inventory.fulfillment.reverse',
    fulfillment_record.warehouse_id,
    p_reason,
    p_request_id
  );

  if fulfillment_record.reversal_request_id = p_request_id then
    return query
    select
      fulfillment.id,
      fulfillment.version,
      fulfillment.reversal_transaction_id,
      order_record.version,
      line.version,
      line.status
    from public.order_fulfillments as fulfillment
    join public.order_lines as line on line.id = fulfillment.order_line_id
    join public.orders as order_record on order_record.id = line.order_id
    where fulfillment.id = p_fulfillment_id;
    return;
  end if;
  if exists (
    select 1
    from public.order_fulfillments as fulfillment
    where fulfillment.reversal_request_id = p_request_id
  ) then
    raise exception using errcode = '22023', message = 'request_id_reused';
  end if;

  perform 1
  from public.inventory_accounts as account
  where account.id in (
    select entry.inventory_account_id
    from public.inventory_ledger_entries as entry
    where entry.inventory_transaction_id = fulfillment_record.inventory_transaction_id
  )
  order by account.id
  for update;

  select fulfillment.* into fulfillment_record
  from public.order_fulfillments as fulfillment
  where fulfillment.id = p_fulfillment_id
  for update;

  select
    line.*,
    order_record.id as current_order_id,
    order_record.status as current_order_status
  into line_record
  from public.order_lines as line
  join public.orders as order_record on order_record.id = line.order_id
  where line.id = fulfillment_record.order_line_id
  for update of order_record, line;

  if fulfillment_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'fulfillment_version_conflict';
  end if;
  if fulfillment_record.status <> 'completed'
    or exists (
      select 1
      from public.inventory_transactions as reversal
      where reversal.reversal_of_id = fulfillment_record.inventory_transaction_id
    ) then
    raise exception using errcode = '22023', message = 'fulfillment_not_reversible';
  end if;
  if line_record.quantity_fulfilled < fulfillment_record.quantity then
    raise exception using errcode = '23514', message = 'fulfillment_reversal_quantity_invalid';
  end if;

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
    'inventory.fulfillment.reverse',
    'Reversal of ' || fulfillment_record.public_reference,
    btrim(p_reason),
    p_request_id,
    fulfillment_record.inventory_transaction_id
  )
  returning id into created_reversal_id;

  insert into public.inventory_ledger_entries (
    inventory_transaction_id,
    line_number,
    inventory_account_id,
    item_id,
    quantity_delta
  )
  select
    created_reversal_id,
    original_entry.line_number,
    original_entry.inventory_account_id,
    original_entry.item_id,
    -original_entry.quantity_delta
  from public.inventory_ledger_entries as original_entry
  where original_entry.inventory_transaction_id
    = fulfillment_record.inventory_transaction_id
  order by original_entry.line_number;

  update public.order_fulfillments as fulfillment
  set
    status = 'reversed',
    reversed_at = statement_timestamp(),
    reversed_by_actor_id = actor_id,
    reversal_reason = btrim(p_reason),
    reversal_request_id = p_request_id,
    reversal_transaction_id = created_reversal_id,
    version = fulfillment.version + 1
  where fulfillment.id = p_fulfillment_id
  returning fulfillment.version into next_fulfillment_version;

  select coalesce(sum(reservation.quantity), 0)
  into remaining_reserved
  from public.reservations as reservation
  where reservation.order_line_id = line_record.id
    and reservation.status = 'active'
    and reservation.expires_at > statement_timestamp();

  next_line_status := case
    when remaining_reserved
      >= line_record.quantity_approved
        - line_record.quantity_fulfilled
        + fulfillment_record.quantity then 'reserved'
    when remaining_reserved > 0 then 'partially_awaiting_stock'
    else 'awaiting_stock'
  end;

  update public.order_lines as line
  set
    quantity_fulfilled = line.quantity_fulfilled - fulfillment_record.quantity,
    status = next_line_status,
    version = line.version + 1
  where line.id = line_record.id
  returning line.version, to_jsonb(line.*)
  into next_line_version, next_line_state;

  next_order_status := private.derive_order_status(line_record.current_order_id);
  update public.orders as order_record
  set status = next_order_status, version = order_record.version + 1
  where order_record.id = line_record.current_order_id
  returning order_record.version into next_order_version;

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
    line_record.id,
    line_record.current_order_id,
    'fulfillment_changed',
    to_jsonb(line_record) - 'current_order_id' - 'current_order_status',
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
    'fulfillment.reversed',
    'order_fulfillment',
    p_fulfillment_id,
    jsonb_build_object(
      'fulfillment_id', p_fulfillment_id,
      'public_reference', fulfillment_record.public_reference,
      'order_id', fulfillment_record.order_id,
      'order_line_id', fulfillment_record.order_line_id,
      'quantity', fulfillment_record.quantity,
      'reversal_transaction_id', created_reversal_id
    ),
    'fulfillment.reversed:' || p_request_id::text
  );

  return query
  select
    p_fulfillment_id,
    next_fulfillment_version,
    created_reversal_id,
    next_order_version,
    next_line_version,
    next_line_status;
end;
$$;

insert into public.notification_templates (
  code,
  event_type,
  destination_type,
  message_template
)
values (
  'staff-fulfillment-completed-v1',
  'fulfillment.completed',
  'discord_channel',
  'Fulfillment {{public_reference}} completed for order {{order_reference}}. Quantity: {{quantity}}. Mode: {{fulfillment_mode}}.'
);

insert into public.integration_event_routes (
  event_type,
  destination_id,
  notification_template_id,
  active
)
select
  template.event_type,
  destination.id,
  template.id,
  true
from public.notification_templates as template
join public.integration_destinations as destination
  on destination.code = 'staff-alerts'
where template.code = 'staff-fulfillment-completed-v1';

revoke all on public.order_fulfillments from anon, authenticated;
revoke all on function private.allocate_fulfillment_reference()
  from public, anon, authenticated;

revoke execute on function public.get_staff_fulfillment_workspace()
  from public, anon;
revoke execute on function public.staff_fulfill_reservation(
  uuid, bigint, text, uuid
) from public, anon;
revoke execute on function public.staff_reverse_fulfillment(
  uuid, bigint, text, uuid
) from public, anon;

grant execute on function public.get_staff_fulfillment_workspace()
  to authenticated;
grant execute on function public.staff_fulfill_reservation(
  uuid, bigint, text, uuid
) to authenticated;
grant execute on function public.staff_reverse_fulfillment(
  uuid, bigint, text, uuid
) to authenticated;
