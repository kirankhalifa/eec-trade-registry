alter table public.audit_log
  add column represented_party_id uuid references public.parties(id) on delete restrict;

alter table public.currencies
  add column is_default boolean not null default false;

create unique index currencies_one_default_idx
  on public.currencies ((is_default))
  where is_default;

update public.currencies
set is_default = true
where code = 'SEP';

comment on column public.currencies.is_default is
  'Deployment-configured transaction currency. Business functions must not branch on a currency code.';

create or replace function private.capture_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_row jsonb;
  current_row jsonb;
  affected_id uuid;
  resolved_auth_user_id uuid;
  resolved_actor_id uuid;
  resolved_assignment_id uuid;
  resolved_represented_party_id uuid;
  resolved_request_id uuid;
  resolved_correlation_id uuid;
begin
  previous_row := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  current_row := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  affected_id := coalesce(
    nullif(current_row ->> 'id', '')::uuid,
    nullif(previous_row ->> 'id', '')::uuid
  );
  resolved_auth_user_id := auth.uid();
  resolved_actor_id := nullif(current_setting('app.actor_id', true), '')::uuid;
  resolved_assignment_id := nullif(current_setting('app.staff_assignment_id', true), '')::uuid;
  resolved_represented_party_id :=
    nullif(current_setting('app.represented_party_id', true), '')::uuid;
  resolved_request_id := nullif(current_setting('app.request_id', true), '')::uuid;
  resolved_correlation_id := nullif(current_setting('app.correlation_id', true), '')::uuid;

  insert into public.audit_log (
    auth_user_id,
    actor_id,
    represented_party_id,
    action,
    record_type,
    record_id,
    previous_state,
    new_state,
    reason,
    request_id,
    correlation_id,
    source_surface,
    permission_code,
    staff_assignment_id
  )
  values (
    resolved_auth_user_id,
    resolved_actor_id,
    resolved_represented_party_id,
    lower(tg_op),
    format('%I.%I', tg_table_schema, tg_table_name),
    affected_id,
    previous_row,
    current_row,
    nullif(current_setting('app.audit_reason', true), ''),
    resolved_request_id,
    resolved_correlation_id,
    coalesce(nullif(current_setting('app.source_surface', true), ''), 'database'),
    nullif(current_setting('app.permission_code', true), ''),
    resolved_assignment_id
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create table public.orders (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  ordering_party_id uuid not null references public.parties(id) on delete restrict,
  dealer_authorization_id uuid not null
    references public.dealer_authorizations(id) on delete restrict,
  license_id uuid references public.licenses(id) on delete restrict,
  jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  fulfillment_mode text not null
    check (fulfillment_mode in ('collection', 'delivery', 'consignment')),
  status text not null default 'submitted'
    check (status in (
      'submitted',
      'under_review',
      'awaiting_stock',
      'approved',
      'partially_approved',
      'denied',
      'cancelled',
      'processing',
      'fulfilled'
    )),
  currency_code text not null check (currency_code ~ '^[A-Z0-9_]{2,12}$'),
  dealer_notes text not null default '' check (char_length(dealer_notes) <= 2000),
  submitted_at timestamptz not null default now(),
  requested_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.order_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  line_number smallint not null check (line_number > 0),
  item_id uuid not null references public.items(id) on delete restrict,
  item_code_snapshot text not null,
  item_name_snapshot text not null,
  unit_code_snapshot text not null,
  quantity_requested numeric(18, 3) not null check (quantity_requested > 0),
  quantity_approved numeric(18, 3)
    check (quantity_approved is null or quantity_approved > 0),
  quantity_fulfilled numeric(18, 3) not null default 0
    check (quantity_fulfilled >= 0),
  status text not null default 'review_required'
    check (status in (
      'review_required',
      'approved',
      'partially_approved',
      'awaiting_stock',
      'partially_awaiting_stock',
      'denied',
      'cancelled',
      'reserved',
      'ready',
      'fulfilled'
    )),
  unit_price_minor_snapshot bigint check (unit_price_minor_snapshot >= 0),
  currency_code_snapshot text not null check (currency_code_snapshot ~ '^[A-Z0-9_]{2,12}$'),
  pricing_status text not null default 'pending'
    check (pricing_status in ('pending', 'configured')),
  control_profile_code_snapshot text not null,
  requires_staff_review_snapshot boolean not null,
  requires_transaction_approval_snapshot boolean not null,
  requires_serial_tracking_snapshot boolean not null,
  review_reason_codes jsonb not null default '[]'::jsonb
    check (jsonb_typeof(review_reason_codes) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (order_id, line_number),
  unique (order_id, item_id),
  unique (id, order_id),
  check (quantity_approved is null or quantity_approved <= quantity_requested),
  check (quantity_fulfilled <= coalesce(quantity_approved, quantity_requested))
);

create table public.order_status_events (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  previous_status text,
  new_status text not null,
  event_type text not null check (event_type in ('submitted', 'status_changed', 'cancelled')),
  changed_by uuid not null references public.actor_profiles(id) on delete restrict,
  represented_party_id uuid references public.parties(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table public.order_line_events (
  id uuid primary key default extensions.gen_random_uuid(),
  order_line_id uuid not null references public.order_lines(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  event_type text not null check (event_type in ('submitted', 'reviewed', 'price_changed', 'cancelled')),
  previous_state jsonb,
  new_state jsonb not null,
  changed_by uuid not null references public.actor_profiles(id) on delete restrict,
  represented_party_id uuid references public.parties(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  foreign key (order_line_id, order_id)
    references public.order_lines(id, order_id) on delete restrict,
  unique (request_id, order_line_id, event_type)
);

comment on table public.orders is
  'Dealer requisitions. Submission is permitted without stock and does not create inventory movement or reservation.';
comment on column public.order_lines.unit_price_minor_snapshot is
  'Nullable by approved policy. Null means pending pricing and is never interpreted as zero.';
comment on table public.order_line_events is
  'Append-only line decisions and price history. Current line columns are a versioned projection of accepted events.';

create index orders_party_idx on public.orders(ordering_party_id, submitted_at desc);
create index orders_status_idx on public.orders(status, submitted_at);
create index order_lines_order_idx on public.order_lines(order_id, line_number);
create index order_status_events_order_idx on public.order_status_events(order_id, created_at desc);
create index order_line_events_order_idx on public.order_line_events(order_id, created_at desc);

create trigger orders_set_updated_at before update on public.orders
for each row execute function private.set_updated_at();
create trigger order_lines_set_updated_at before update on public.order_lines
for each row execute function private.set_updated_at();

create trigger orders_audit after insert or update or delete on public.orders
for each row execute function private.capture_audit_row();
create trigger order_lines_audit after insert or update or delete on public.order_lines
for each row execute function private.capture_audit_row();
create trigger order_status_events_audit after insert or update or delete on public.order_status_events
for each row execute function private.capture_audit_row();
create trigger order_line_events_audit after insert or update or delete on public.order_line_events
for each row execute function private.capture_audit_row();

alter table public.orders enable row level security;
alter table public.order_lines enable row level security;
alter table public.order_status_events enable row level security;
alter table public.order_line_events enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'order.private.read',
    'Read order records',
    'View the staff order queue, dealer notes, line decisions, and pending prices.'
  ),
  (
    'order.review',
    'Review orders',
    'Approve, partially approve, deny, or place submitted order lines in awaiting-stock state.'
  ),
  (
    'order.approve.ordinary',
    'Approve ordinary orders',
    'Approve ordinary-control order lines through the secure review command.'
  ),
  (
    'order.approve.restricted',
    'Approve restricted orders',
    'Approve restricted-control order lines through the secure review command.'
  ),
  (
    'order.approve.unique',
    'Approve unique orders',
    'Approve unique-control order lines through the secure review command before serialized allocation.'
  ),
  (
    'order.price.edit',
    'Edit order prices',
    'Set or clear an order-line Septim price through an audited command.'
  ),
  (
    'order.cancel',
    'Cancel orders',
    'Cancel an unfulfilled order through an audited command.'
  );

insert into public.staff_roles (code, display_name, description)
values (
  'order_officer',
  'Order officer',
  'May read, review, price, and cancel dealer requisitions under the initial permission-based policy.'
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'order_officer'
  and permission.code in (
    'order.private.read',
    'order.review',
    'order.approve.ordinary',
    'order.approve.restricted',
    'order.approve.unique',
    'order.price.edit',
    'order.cancel'
  );

insert into public.reference_sequences (
  document_type,
  prefix,
  next_value,
  padding
)
values ('order', 'EEC-ORD', 1001, 4);

update public.representative_role_definitions
set default_scope = default_scope || jsonb_build_object(
  'order.read', true,
  'order.create', true,
  'order.cancel', true
)
where code = 'portal-representative';

create function private.current_dealer_representations(p_scope_code text)
returns table (
  actor_id uuid,
  representation_id uuid,
  principal_party_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    actor.id,
    representative_grant.id,
    representative_grant.principal_party_id
  from public.actor_profiles as actor
  join public.party_representatives as representative_grant
    on representative_grant.actor_id = actor.id
    and representative_grant.revoked_at is null
    and representative_grant.effective_from <= statement_timestamp()
    and (
      representative_grant.effective_until is null
      or representative_grant.effective_until > statement_timestamp()
    )
    and coalesce(
      (representative_grant.authority_scope ->> p_scope_code)::boolean,
      false
    )
  join public.representative_role_definitions as representative_role
    on representative_role.id = representative_grant.role_definition_id
    and representative_role.active
  where actor.auth_user_id = auth.uid()
    and actor.actor_type = 'dealer'
    and actor.status = 'active'
    and exists (
      select 1
      from public.dealer_authorizations as current_dealer_record
      join public.dealer_status_definitions as current_dealer_status
        on current_dealer_status.id = current_dealer_record.status_definition_id
        and current_dealer_status.confers_authority
      where current_dealer_record.dealer_party_id = representative_grant.principal_party_id
        and current_dealer_record.effective_from <= statement_timestamp()
        and (
          current_dealer_record.effective_until is null
          or current_dealer_record.effective_until > statement_timestamp()
        )
    );
$$;

create function private.require_dealer_representation(
  p_principal_party_id uuid,
  p_scope_code text
)
returns table (actor_id uuid, representation_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '28000', message = 'dealer_authentication_required';
  end if;

  return query
  select current_grant.actor_id, current_grant.representation_id
  from private.current_dealer_representations(p_scope_code) as current_grant
  where current_grant.principal_party_id = p_principal_party_id
  limit 1;

  if not found then
    raise exception using errcode = '42501', message = 'dealer_scope_denied';
  end if;
end;
$$;

create function private.set_dealer_audit_context(
  p_principal_party_id uuid,
  p_scope_code text,
  p_reason text,
  p_request_id uuid
)
returns table (actor_id uuid, representation_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_grant record;
  normalized_reason text;
begin
  normalized_reason := btrim(coalesce(p_reason, ''));
  if normalized_reason = '' or char_length(normalized_reason) > 500 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'request_id_required';
  end if;

  select * into strict current_grant
  from private.require_dealer_representation(p_principal_party_id, p_scope_code);

  perform set_config('app.actor_id', current_grant.actor_id::text, true);
  perform set_config('app.staff_assignment_id', '', true);
  perform set_config('app.represented_party_id', p_principal_party_id::text, true);
  perform set_config('app.permission_code', 'dealer.' || p_scope_code, true);
  perform set_config('app.audit_reason', normalized_reason, true);
  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.correlation_id', p_request_id::text, true);
  perform set_config('app.source_surface', 'dealer_portal', true);

  return query select current_grant.actor_id, current_grant.representation_id;
end;
$$;

create function private.allocate_order_reference()
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
  where reference.document_type = 'order'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix
    || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');

  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'order';

  return allocated_reference;
exception
  when no_data_found then
    raise exception using errcode = '55000', message = 'order_reference_sequence_unavailable';
end;
$$;

create function public.get_dealer_order_reference_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  representations jsonb;
begin
  if not exists (select 1 from private.current_dealer_representations('order.create')) then
    raise exception using errcode = '42501', message = 'dealer_scope_denied';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'party_id', party.id,
        'party_name', party.display_name,
        'dealer_authorizations', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'id', dealer_record.id,
                'public_reference', dealer_record.public_reference,
                'jurisdiction_code', jurisdiction.code,
                'jurisdiction_label', jurisdiction.public_name
              )
              order by dealer_record.public_reference
            )
            from public.dealer_authorizations as dealer_record
            join public.dealer_status_definitions as dealer_status
              on dealer_status.id = dealer_record.status_definition_id
              and dealer_status.confers_authority
            join public.jurisdictions as jurisdiction
              on jurisdiction.id = dealer_record.jurisdiction_id
            where dealer_record.dealer_party_id = party.id
              and dealer_record.effective_from <= statement_timestamp()
              and (
                dealer_record.effective_until is null
                or dealer_record.effective_until > statement_timestamp()
              )
          ),
          '[]'::jsonb
        ),
        'licenses', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'id', license_record.id,
                'public_reference', license_record.public_reference,
                'class_label', license_class.display_name
              )
              order by license_record.public_reference
            )
            from public.licenses as license_record
            join public.license_status_definitions as license_status
              on license_status.id = license_record.status_definition_id
              and license_status.confers_authority
            join public.license_classes as license_class
              on license_class.id = license_record.license_class_id
            where license_record.holder_party_id = party.id
              and license_record.effective_from <= statement_timestamp()
              and (
                license_record.expires_at is null
                or license_record.expires_at > statement_timestamp()
              )
          ),
          '[]'::jsonb
        )
      )
      order by party.display_name, party.id
    ),
    '[]'::jsonb
  )
  into representations
  from (
    select distinct accessible.principal_party_id
    from private.current_dealer_representations('order.create') as accessible
  ) as accessible_party
  join public.parties as party on party.id = accessible_party.principal_party_id;

  return jsonb_build_object(
    'representations', representations,
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', item.id,
            'item_code', item.item_code,
            'display_name', publication.public_name,
            'unit_code', unit.code,
            'unit_name', unit.display_name,
            'control_label', control.display_name,
            'availability_label', availability.display_name,
            'pricing_status', 'pending'
          )
          order by publication.public_name, item.item_code
        )
        from public.items as item
        join public.units_of_measure as unit on unit.id = item.unit_id
        join public.item_publications as publication
          on publication.item_id = item.id
          and publication.audience_code = 'public'
          and publication.publication_status = 'published'
          and publication.effective_from <= statement_timestamp()
          and (
            publication.effective_until is null
            or publication.effective_until > statement_timestamp()
          )
        join public.control_profiles as control
          on control.id = publication.control_profile_id
        join public.availability_profiles as availability
          on availability.id = publication.availability_profile_id
        where item.status = 'active'
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create function public.get_dealer_orders()
returns table (
  id uuid,
  public_reference text,
  ordering_party_id uuid,
  ordering_party_name text,
  dealer_reference text,
  license_reference text,
  fulfillment_mode text,
  status text,
  currency_code text,
  dealer_notes text,
  submitted_at timestamptz,
  version bigint,
  lines jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from private.current_dealer_representations('order.read')) then
    raise exception using errcode = '42501', message = 'dealer_scope_denied';
  end if;

  return query
  select
    order_record.id,
    order_record.public_reference,
    order_record.ordering_party_id,
    ordering_party.display_name,
    dealer_record.public_reference,
    license_record.public_reference,
    order_record.fulfillment_mode,
    order_record.status,
    order_record.currency_code,
    order_record.dealer_notes,
    order_record.submitted_at,
    order_record.version,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', line.id,
            'line_number', line.line_number,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'unit_code', line.unit_code_snapshot,
            'quantity_requested', line.quantity_requested,
            'quantity_approved', line.quantity_approved,
            'quantity_fulfilled', line.quantity_fulfilled,
            'status', line.status,
            'unit_price_minor', line.unit_price_minor_snapshot,
            'pricing_status', line.pricing_status,
            'control_profile_code', line.control_profile_code_snapshot
          )
          order by line.line_number
        )
        from public.order_lines as line
        where line.order_id = order_record.id
      ),
      '[]'::jsonb
    )
  from public.orders as order_record
  join public.parties as ordering_party on ordering_party.id = order_record.ordering_party_id
  join public.dealer_authorizations as dealer_record
    on dealer_record.id = order_record.dealer_authorization_id
  left join public.licenses as license_record on license_record.id = order_record.license_id
  where exists (
    select 1
    from private.current_dealer_representations('order.read') as current_grant
    where current_grant.principal_party_id = order_record.ordering_party_id
  )
  order by order_record.submitted_at desc, order_record.public_reference;
end;
$$;

create function public.get_dealer_order(p_order_id uuid)
returns table (
  id uuid,
  public_reference text,
  ordering_party_id uuid,
  ordering_party_name text,
  dealer_reference text,
  license_reference text,
  fulfillment_mode text,
  status text,
  currency_code text,
  dealer_notes text,
  submitted_at timestamptz,
  version bigint,
  lines jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select order_projection.*
  from public.get_dealer_orders() as order_projection
  where order_projection.id = p_order_id;
$$;

create function public.dealer_submit_order(
  p_ordering_party_id uuid,
  p_dealer_authorization_id uuid,
  p_license_id uuid,
  p_fulfillment_mode text,
  p_item_ids uuid[],
  p_quantities numeric[],
  p_dealer_notes text,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, public_reference text, version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_grant record;
  existing_order record;
  dealer_record record;
  license_record record;
  currency_record record;
  created_order_id uuid;
  created_reference text;
  line_record record;
  line_index integer;
  line_count integer;
begin
  select * into strict current_grant
  from private.set_dealer_audit_context(
    p_ordering_party_id,
    'order.create',
    p_reason,
    p_request_id
  );

  select order_record.id, order_record.public_reference, order_record.version
  into existing_order
  from public.orders as order_record
  where order_record.source_request_id = p_request_id;
  if found then
    if not exists (
      select 1 from public.orders as existing
      where existing.id = existing_order.id
        and existing.ordering_party_id = p_ordering_party_id
    ) then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query select existing_order.id, existing_order.public_reference, existing_order.version;
    return;
  end if;

  select
    dealer_authorization.id,
    dealer_authorization.jurisdiction_id
  into dealer_record
  from public.dealer_authorizations as dealer_authorization
  join public.dealer_status_definitions as dealer_status
    on dealer_status.id = dealer_authorization.status_definition_id
    and dealer_status.confers_authority
  where dealer_authorization.id = p_dealer_authorization_id
    and dealer_authorization.dealer_party_id = p_ordering_party_id
    and dealer_authorization.effective_from <= statement_timestamp()
    and (
      dealer_authorization.effective_until is null
      or dealer_authorization.effective_until > statement_timestamp()
    );
  if not found then
    raise exception using errcode = '22023', message = 'dealer_authorization_invalid';
  end if;

  if p_license_id is not null then
    select licensed.id
    into license_record
    from public.licenses as licensed
    join public.license_status_definitions as license_status
      on license_status.id = licensed.status_definition_id
      and license_status.confers_authority
    where licensed.id = p_license_id
      and licensed.holder_party_id = p_ordering_party_id
      and licensed.jurisdiction_id = dealer_record.jurisdiction_id
      and licensed.effective_from <= statement_timestamp()
      and (licensed.expires_at is null or licensed.expires_at > statement_timestamp());
    if not found then
      raise exception using errcode = '22023', message = 'order_license_invalid';
    end if;
  end if;

  if p_fulfillment_mode not in ('collection', 'delivery', 'consignment') then
    raise exception using errcode = '22023', message = 'fulfillment_mode_invalid';
  end if;
  if char_length(coalesce(btrim(p_dealer_notes), '')) > 2000 then
    raise exception using errcode = '22023', message = 'dealer_notes_invalid';
  end if;

  line_count := coalesce(cardinality(p_item_ids), 0);
  if line_count = 0 or line_count > 50 or line_count <> coalesce(cardinality(p_quantities), 0) then
    raise exception using errcode = '22023', message = 'order_lines_invalid';
  end if;
  if (
    select count(distinct requested.item_id)
    from unnest(p_item_ids) as requested(item_id)
  ) <> line_count then
    raise exception using errcode = '22023', message = 'order_items_duplicate';
  end if;
  if exists (
    select 1
    from unnest(p_quantities) as requested(quantity)
    where requested.quantity <= 0
  ) then
    raise exception using errcode = '22023', message = 'order_quantity_invalid';
  end if;

  select currency.code into currency_record
  from public.currencies as currency
  where currency.active
    and currency.is_default
  limit 1;
  if not found then
    raise exception using errcode = '55000', message = 'order_currency_unavailable';
  end if;

  created_reference := private.allocate_order_reference();
  insert into public.orders (
    public_reference,
    ordering_party_id,
    dealer_authorization_id,
    license_id,
    jurisdiction_id,
    fulfillment_mode,
    currency_code,
    dealer_notes,
    requested_by_actor_id,
    source_request_id
  )
  values (
    created_reference,
    p_ordering_party_id,
    p_dealer_authorization_id,
    p_license_id,
    dealer_record.jurisdiction_id,
    p_fulfillment_mode,
    currency_record.code,
    coalesce(btrim(p_dealer_notes), ''),
    current_grant.actor_id,
    p_request_id
  )
  returning orders.id into created_order_id;

  for line_index in 1..line_count loop
    select
      item.id,
      item.item_code,
      publication.public_name,
      unit.code as unit_code,
      control.code as control_code,
      control.requires_staff_review,
      control.requires_transaction_approval,
      control.requires_serial_tracking
    into line_record
    from public.items as item
    join public.units_of_measure as unit on unit.id = item.unit_id
    join public.item_publications as publication
      on publication.item_id = item.id
      and publication.audience_code = 'public'
      and publication.publication_status = 'published'
      and publication.effective_from <= statement_timestamp()
      and (
        publication.effective_until is null
        or publication.effective_until > statement_timestamp()
      )
    join public.control_profiles as control on control.id = publication.control_profile_id
    where item.id = p_item_ids[line_index]
      and item.status = 'active';
    if not found then
      raise exception using errcode = '22023', message = 'order_item_unavailable';
    end if;

    insert into public.order_lines (
      order_id,
      line_number,
      item_id,
      item_code_snapshot,
      item_name_snapshot,
      unit_code_snapshot,
      quantity_requested,
      currency_code_snapshot,
      control_profile_code_snapshot,
      requires_staff_review_snapshot,
      requires_transaction_approval_snapshot,
      requires_serial_tracking_snapshot,
      review_reason_codes
    )
    values (
      created_order_id,
      line_index,
      line_record.id,
      line_record.item_code,
      line_record.public_name,
      line_record.unit_code,
      p_quantities[line_index],
      currency_record.code,
      line_record.control_code,
      line_record.requires_staff_review,
      line_record.requires_transaction_approval,
      line_record.requires_serial_tracking,
      jsonb_build_array(
        'pricing_pending',
        case
          when line_record.requires_serial_tracking then 'unique_approval_required'
          when line_record.requires_staff_review then 'staff_review_required'
          else 'routine_review'
        end
      )
    )
    returning * into line_record;

    insert into public.order_line_events (
      order_line_id,
      order_id,
      event_type,
      new_state,
      changed_by,
      represented_party_id,
      reason,
      request_id
    )
    values (
      line_record.id,
      created_order_id,
      'submitted',
      to_jsonb(line_record),
      current_grant.actor_id,
      p_ordering_party_id,
      btrim(p_reason),
      p_request_id
    );
  end loop;

  insert into public.order_status_events (
    order_id,
    new_status,
    event_type,
    changed_by,
    represented_party_id,
    reason,
    request_id
  )
  values (
    created_order_id,
    'submitted',
    'submitted',
    current_grant.actor_id,
    p_ordering_party_id,
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
    'order.submitted',
    'order',
    created_order_id,
    jsonb_build_object(
      'order_id', created_order_id,
      'public_reference', created_reference,
      'ordering_party_id', p_ordering_party_id,
      'line_count', line_count,
      'stock_checked', false,
      'pricing_status', 'pending'
    ),
    'order.submitted:' || p_request_id::text
  );

  return query select created_order_id, created_reference, 1::bigint;
end;
$$;

create function private.cancel_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_actor_id uuid,
  p_represented_party_id uuid,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  order_record record;
  existing_event record;
  line_record record;
  previous_line_state jsonb;
  next_line_state jsonb;
  next_version bigint;
begin
  select event.order_id into existing_event
  from public.order_status_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.order_id <> p_order_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select existing.id, existing.version, existing.status
    from public.orders as existing where existing.id = p_order_id;
    return;
  end if;

  select current_order.id, current_order.version, current_order.status
  into order_record
  from public.orders as current_order
  where current_order.id = p_order_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'order_not_found';
  end if;
  if order_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'order_version_conflict';
  end if;
  if order_record.status in ('cancelled', 'denied', 'fulfilled') then
    raise exception using errcode = '22023', message = 'order_cancellation_invalid';
  end if;
  if exists (
    select 1
    from public.order_lines as line
    where line.order_id = p_order_id
      and (
        line.quantity_fulfilled > 0
        or line.status in ('reserved', 'ready', 'fulfilled')
      )
  ) then
    raise exception using errcode = '22023', message = 'order_cancellation_invalid';
  end if;

  for line_record in
    select line.*
    from public.order_lines as line
    where line.order_id = p_order_id
      and line.status not in ('cancelled', 'denied', 'fulfilled')
    order by line.line_number
    for update
  loop
    previous_line_state := to_jsonb(line_record);
    update public.order_lines as line
    set status = 'cancelled', version = line.version + 1
    where line.id = line_record.id
    returning to_jsonb(line.*) into next_line_state;

    insert into public.order_line_events (
      order_line_id,
      order_id,
      event_type,
      previous_state,
      new_state,
      changed_by,
      represented_party_id,
      reason,
      request_id
    )
    values (
      line_record.id,
      p_order_id,
      'cancelled',
      previous_line_state,
      next_line_state,
      p_actor_id,
      p_represented_party_id,
      btrim(p_reason),
      p_request_id
    );
  end loop;

  update public.orders as current_order
  set status = 'cancelled', version = current_order.version + 1
  where current_order.id = p_order_id
  returning current_order.version into next_version;

  insert into public.order_status_events (
    order_id,
    previous_status,
    new_status,
    event_type,
    changed_by,
    represented_party_id,
    reason,
    request_id
  )
  values (
    p_order_id,
    order_record.status,
    'cancelled',
    'cancelled',
    p_actor_id,
    p_represented_party_id,
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
    'order.cancelled',
    'order',
    p_order_id,
    jsonb_build_object('order_id', p_order_id, 'previous_status', order_record.status),
    'order.cancelled:' || p_request_id::text
  );

  return query select p_order_id, next_version, 'cancelled'::text;
end;
$$;

create function public.dealer_cancel_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  ordering_party_id uuid;
  current_grant record;
begin
  if auth.uid() is null then
    raise exception using errcode = '28000', message = 'dealer_authentication_required';
  end if;

  select order_record.ordering_party_id into ordering_party_id
  from public.orders as order_record
  where order_record.id = p_order_id
    and exists (
      select 1
      from private.current_dealer_representations('order.cancel') as accessible_grant
      where accessible_grant.principal_party_id = order_record.ordering_party_id
    );
  if not found then
    raise exception using errcode = 'P0002', message = 'order_not_found';
  end if;

  select * into strict current_grant
  from private.set_dealer_audit_context(
    ordering_party_id,
    'order.cancel',
    p_reason,
    p_request_id
  );

  return query
  select cancelled.*
  from private.cancel_order(
    p_order_id,
    p_expected_version,
    current_grant.actor_id,
    ordering_party_id,
    p_reason,
    p_request_id
  ) as cancelled;
end;
$$;

create function public.get_staff_order_queue(p_search text default null)
returns table (
  id uuid,
  public_reference text,
  ordering_party_id uuid,
  ordering_party_name text,
  dealer_reference text,
  license_reference text,
  fulfillment_mode text,
  status text,
  currency_code text,
  dealer_notes text,
  submitted_at timestamptz,
  version bigint,
  lines jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('order.private.read');

  return query
  select
    order_record.id,
    order_record.public_reference,
    order_record.ordering_party_id,
    ordering_party.display_name,
    dealer_record.public_reference,
    license_record.public_reference,
    order_record.fulfillment_mode,
    order_record.status,
    order_record.currency_code,
    order_record.dealer_notes,
    order_record.submitted_at,
    order_record.version,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', line.id,
            'line_number', line.line_number,
            'item_code', line.item_code_snapshot,
            'item_name', line.item_name_snapshot,
            'unit_code', line.unit_code_snapshot,
            'quantity_requested', line.quantity_requested,
            'quantity_approved', line.quantity_approved,
            'quantity_fulfilled', line.quantity_fulfilled,
            'status', line.status,
            'unit_price_minor', line.unit_price_minor_snapshot,
            'pricing_status', line.pricing_status,
            'control_profile_code', line.control_profile_code_snapshot,
            'requires_staff_review', line.requires_staff_review_snapshot,
            'requires_transaction_approval', line.requires_transaction_approval_snapshot,
            'requires_serial_tracking', line.requires_serial_tracking_snapshot,
            'review_reason_codes', line.review_reason_codes,
            'version', line.version
          )
          order by line.line_number
        )
        from public.order_lines as line
        where line.order_id = order_record.id
      ),
      '[]'::jsonb
    )
  from public.orders as order_record
  join public.parties as ordering_party on ordering_party.id = order_record.ordering_party_id
  join public.dealer_authorizations as dealer_record
    on dealer_record.id = order_record.dealer_authorization_id
  left join public.licenses as license_record on license_record.id = order_record.license_id
  where p_search is null
    or btrim(p_search) = ''
    or order_record.public_reference ilike '%' || btrim(p_search) || '%'
    or ordering_party.display_name ilike '%' || btrim(p_search) || '%'
  order by
    case order_record.status
      when 'submitted' then 0
      when 'under_review' then 1
      when 'awaiting_stock' then 2
      else 3
    end,
    order_record.submitted_at;
end;
$$;

create function public.get_staff_order(p_order_id uuid)
returns table (
  id uuid,
  public_reference text,
  ordering_party_id uuid,
  ordering_party_name text,
  dealer_reference text,
  license_reference text,
  fulfillment_mode text,
  status text,
  currency_code text,
  dealer_notes text,
  submitted_at timestamptz,
  version bigint,
  lines jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select order_projection.*
  from public.get_staff_order_queue(null) as order_projection
  where order_projection.id = p_order_id;
$$;

create function public.staff_review_order_line(
  p_order_line_id uuid,
  p_expected_order_version bigint,
  p_decision text,
  p_quantity_approved numeric,
  p_unit_price_minor bigint,
  p_reason text,
  p_request_id uuid
)
returns table (order_id uuid, order_version bigint, order_status text, line_status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  permission_code text;
  existing_event record;
  current_order record;
  current_line record;
  next_line_status text;
  next_order_status text;
  next_order_version bigint;
  previous_line_state jsonb;
  next_line_state jsonb;
begin
  perform 1 from private.require_staff_permission('order.private.read');

  select event.order_id, event.order_line_id into existing_event
  from public.order_line_events as event
  where event.request_id = p_request_id
    and event.event_type = 'reviewed';
  if found then
    if existing_event.order_line_id <> p_order_line_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select order_record.id, order_record.version, order_record.status, line.status
    from public.orders as order_record
    join public.order_lines as line on line.order_id = order_record.id
    where line.id = p_order_line_id;
    return;
  end if;

  select
    order_record.id,
    order_record.version,
    order_record.status
  into current_order
  from public.orders as order_record
  join public.order_lines as line on line.order_id = order_record.id
  where line.id = p_order_line_id
  for update of order_record;
  if not found then
    raise exception using errcode = 'P0002', message = 'order_line_not_found';
  end if;
  if current_order.version <> p_expected_order_version then
    raise exception using errcode = '40001', message = 'order_version_conflict';
  end if;
  if current_order.status in ('cancelled', 'denied', 'fulfilled') then
    raise exception using errcode = '22023', message = 'order_review_invalid';
  end if;

  select line.* into current_line
  from public.order_lines as line
  where line.id = p_order_line_id
  for update;
  previous_line_state := to_jsonb(current_line);
  if current_line.status not in (
    'review_required', 'approved', 'partially_approved',
    'awaiting_stock', 'partially_awaiting_stock'
  ) then
    raise exception using errcode = '22023', message = 'order_line_review_invalid';
  end if;

  if p_decision not in ('approve', 'awaiting_stock', 'deny') then
    raise exception using errcode = '22023', message = 'order_decision_invalid';
  end if;
  if p_unit_price_minor is not null and p_unit_price_minor < 0 then
    raise exception using errcode = '22023', message = 'order_price_invalid';
  end if;

  permission_code := case
    when p_decision = 'deny' then 'order.review'
    when current_line.requires_serial_tracking_snapshot then 'order.approve.unique'
    when current_line.requires_staff_review_snapshot
      or current_line.requires_transaction_approval_snapshot
      then 'order.approve.restricted'
    else 'order.approve.ordinary'
  end;
  actor_id := private.set_staff_audit_context(
    permission_code,
    p_reason,
    p_request_id,
    'staff_portal'
  );

  if p_decision = 'deny' then
    if p_quantity_approved is not null then
      raise exception using errcode = '22023', message = 'approved_quantity_invalid';
    end if;
    next_line_status := 'denied';
  else
    if p_quantity_approved is null
      or p_quantity_approved <= 0
      or p_quantity_approved > current_line.quantity_requested then
      raise exception using errcode = '22023', message = 'approved_quantity_invalid';
    end if;
    next_line_status := case
      when p_decision = 'awaiting_stock' and p_quantity_approved < current_line.quantity_requested
        then 'partially_awaiting_stock'
      when p_decision = 'awaiting_stock' then 'awaiting_stock'
      when p_quantity_approved < current_line.quantity_requested then 'partially_approved'
      else 'approved'
    end;
  end if;

  update public.order_lines as line
  set
    quantity_approved = case when p_decision = 'deny' then null else p_quantity_approved end,
    status = next_line_status,
    unit_price_minor_snapshot = p_unit_price_minor,
    pricing_status = case when p_unit_price_minor is null then 'pending' else 'configured' end,
    version = line.version + 1
  where line.id = p_order_line_id
  returning to_jsonb(line.*) into next_line_state;

  select case
    when bool_and(line.status = 'denied') then 'denied'
    when bool_and(line.status in (
      'approved', 'partially_approved', 'awaiting_stock',
      'partially_awaiting_stock', 'denied'
    )) and bool_or(line.status in ('awaiting_stock', 'partially_awaiting_stock'))
      then 'awaiting_stock'
    when bool_and(line.status in ('approved', 'partially_approved', 'denied'))
      and bool_or(line.status in ('partially_approved', 'denied'))
      then 'partially_approved'
    when bool_and(line.status = 'approved') then 'approved'
    else 'under_review'
  end
  into next_order_status
  from public.order_lines as line
  where line.order_id = current_order.id;

  update public.orders as order_record
  set status = next_order_status, version = order_record.version + 1
  where order_record.id = current_order.id
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
    p_order_line_id,
    current_order.id,
    'reviewed',
    previous_line_state,
    next_line_state,
    actor_id,
    btrim(p_reason),
    p_request_id
  );

  if next_order_status <> current_order.status then
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
      current_order.id,
      current_order.status,
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
    'order.line_reviewed',
    'order',
    current_order.id,
    jsonb_build_object(
      'order_id', current_order.id,
      'order_line_id', p_order_line_id,
      'line_status', next_line_status,
      'order_status', next_order_status,
      'pricing_status', case when p_unit_price_minor is null then 'pending' else 'configured' end,
      'stock_reserved', false
    ),
    'order.line_reviewed:' || p_request_id::text
  );

  return query
  select current_order.id, next_order_version, next_order_status, next_line_status;
end;
$$;

create function public.staff_set_order_line_price(
  p_order_line_id uuid,
  p_expected_order_version bigint,
  p_unit_price_minor bigint,
  p_reason text,
  p_request_id uuid
)
returns table (order_id uuid, order_version bigint, unit_price_minor bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing_event record;
  current_order record;
  current_line record;
  next_order_version bigint;
  next_line_state jsonb;
begin
  actor_id := private.set_staff_audit_context(
    'order.price.edit',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select event.order_id, event.order_line_id into existing_event
  from public.order_line_events as event
  where event.request_id = p_request_id
    and event.event_type = 'price_changed';
  if found then
    if existing_event.order_line_id <> p_order_line_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select order_record.id, order_record.version, line.unit_price_minor_snapshot
    from public.orders as order_record
    join public.order_lines as line on line.order_id = order_record.id
    where line.id = p_order_line_id;
    return;
  end if;

  select order_record.id, order_record.version, order_record.status
  into current_order
  from public.orders as order_record
  join public.order_lines as line on line.order_id = order_record.id
  where line.id = p_order_line_id
  for update of order_record;
  if not found then
    raise exception using errcode = 'P0002', message = 'order_line_not_found';
  end if;
  if current_order.version <> p_expected_order_version then
    raise exception using errcode = '40001', message = 'order_version_conflict';
  end if;
  if current_order.status in ('cancelled', 'denied', 'fulfilled') then
    raise exception using errcode = '22023', message = 'order_price_change_invalid';
  end if;
  if p_unit_price_minor is not null and p_unit_price_minor < 0 then
    raise exception using errcode = '22023', message = 'order_price_invalid';
  end if;

  select line.* into current_line
  from public.order_lines as line
  where line.id = p_order_line_id
  for update;

  update public.order_lines as line
  set
    unit_price_minor_snapshot = p_unit_price_minor,
    pricing_status = case when p_unit_price_minor is null then 'pending' else 'configured' end,
    version = line.version + 1
  where line.id = p_order_line_id
  returning to_jsonb(line.*) into next_line_state;

  update public.orders as order_record
  set version = order_record.version + 1
  where order_record.id = current_order.id
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
    p_order_line_id,
    current_order.id,
    'price_changed',
    to_jsonb(current_line),
    next_line_state,
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
    'order.line_price_changed',
    'order',
    current_order.id,
    jsonb_build_object(
      'order_id', current_order.id,
      'order_line_id', p_order_line_id,
      'pricing_status', case when p_unit_price_minor is null then 'pending' else 'configured' end
    ),
    'order.line_price_changed:' || p_request_id::text
  );

  return query select current_order.id, next_order_version, p_unit_price_minor;
end;
$$;

create function public.staff_cancel_order(
  p_order_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
begin
  actor_id := private.set_staff_audit_context(
    'order.cancel',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  return query
  select cancelled.*
  from private.cancel_order(
    p_order_id,
    p_expected_version,
    actor_id,
    null,
    p_reason,
    p_request_id
  ) as cancelled;
end;
$$;

revoke all on public.orders from anon, authenticated;
revoke all on public.order_lines from anon, authenticated;
revoke all on public.order_status_events from anon, authenticated;
revoke all on public.order_line_events from anon, authenticated;

revoke all on function private.current_dealer_representations(text)
  from public, anon, authenticated;
revoke all on function private.require_dealer_representation(uuid, text)
  from public, anon, authenticated;
revoke all on function private.set_dealer_audit_context(uuid, text, text, uuid)
  from public, anon, authenticated;
revoke all on function private.allocate_order_reference()
  from public, anon, authenticated;
revoke all on function private.cancel_order(uuid, bigint, uuid, uuid, text, uuid)
  from public, anon, authenticated;

revoke execute on function public.get_dealer_order_reference_data() from public, anon;
revoke execute on function public.get_dealer_orders() from public, anon;
revoke execute on function public.get_dealer_order(uuid) from public, anon;
revoke execute on function public.dealer_submit_order(
  uuid, uuid, uuid, text, uuid[], numeric[], text, text, uuid
) from public, anon;
revoke execute on function public.dealer_cancel_order(uuid, bigint, text, uuid)
  from public, anon;
revoke execute on function public.get_staff_order_queue(text) from public, anon;
revoke execute on function public.get_staff_order(uuid) from public, anon;
revoke execute on function public.staff_review_order_line(
  uuid, bigint, text, numeric, bigint, text, uuid
) from public, anon;
revoke execute on function public.staff_set_order_line_price(
  uuid, bigint, bigint, text, uuid
) from public, anon;
revoke execute on function public.staff_cancel_order(uuid, bigint, text, uuid)
  from public, anon;

grant execute on function public.get_dealer_order_reference_data() to authenticated;
grant execute on function public.get_dealer_orders() to authenticated;
grant execute on function public.get_dealer_order(uuid) to authenticated;
grant execute on function public.dealer_submit_order(
  uuid, uuid, uuid, text, uuid[], numeric[], text, text, uuid
) to authenticated;
grant execute on function public.dealer_cancel_order(uuid, bigint, text, uuid)
  to authenticated;
grant execute on function public.get_staff_order_queue(text) to authenticated;
grant execute on function public.get_staff_order(uuid) to authenticated;
grant execute on function public.staff_review_order_line(
  uuid, bigint, text, numeric, bigint, text, uuid
) to authenticated;
grant execute on function public.staff_set_order_line_price(
  uuid, bigint, bigint, text, uuid
) to authenticated;
grant execute on function public.staff_cancel_order(uuid, bigint, text, uuid)
  to authenticated;
