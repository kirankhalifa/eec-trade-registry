alter table public.dealer_authorizations
  add column source_request_id uuid unique;

create table public.dealer_authorization_events (
  id uuid primary key default extensions.gen_random_uuid(),
  dealer_authorization_id uuid not null references public.dealer_authorizations(id) on delete restrict,
  event_type text not null check (event_type in ('created', 'details_updated', 'status_changed')),
  previous_status_definition_id uuid references public.dealer_status_definitions(id) on delete restrict,
  new_status_definition_id uuid references public.dealer_status_definitions(id) on delete restrict,
  changed_by uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now(),
  check (
    (event_type = 'status_changed' and previous_status_definition_id is not null and new_status_definition_id is not null)
    or (event_type = 'created' and previous_status_definition_id is null and new_status_definition_id is not null)
    or (event_type = 'details_updated' and previous_status_definition_id is null and new_status_definition_id is null)
  )
);

comment on table public.dealer_authorization_events is
  'Append-only staff history for dealer onboarding, public/private detail changes, and authority transitions.';

create index dealer_authorization_events_record_idx
  on public.dealer_authorization_events(dealer_authorization_id, created_at desc);

create trigger dealer_authorization_events_audit
after insert or update or delete on public.dealer_authorization_events
for each row execute function private.capture_audit_row();

alter table public.dealer_authorization_events enable row level security;

insert into public.dealer_status_definitions (
  code, display_name, public_result_code, confers_authority, publicly_verifiable
)
values
  ('suspended', 'Suspended authorization', 'suspended', false, true),
  ('revoked', 'Revoked authorization', 'revoked', false, true)
on conflict (code) do nothing;

insert into public.permission_scopes (code, display_name, description)
values
  ('dealer.private.read', 'Read dealer registry', 'View private party and dealer authorization records.'),
  ('dealer.create', 'Onboard dealers', 'Create a party and its initial dealer authorization atomically.'),
  ('dealer.update', 'Update dealer records', 'Update dealer identity and authorization presentation through an audited command.'),
  ('dealer.activate', 'Activate dealer authority', 'Activate an authorization under the configured dealer policy.'),
  ('dealer.suspend', 'Suspend dealer authority', 'Suspend an active dealer authorization.'),
  ('dealer.reinstate', 'Reinstate dealer authority', 'Restore a suspended dealer authorization.'),
  ('dealer.revoke', 'Revoke dealer authority', 'Permanently revoke a dealer authorization.');

insert into public.staff_roles (code, display_name, description, is_elevated)
values (
  'dealer_registry_officer',
  'Dealer registry officer',
  'May onboard, maintain, and transition dealer authorization records through audited commands.',
  true
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'dealer_registry_officer'
  and permission.code in (
    'dealer.private.read', 'dealer.create', 'dealer.update', 'dealer.activate',
    'dealer.suspend', 'dealer.reinstate', 'dealer.revoke'
  );

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values ('dealer_authorization', 'EEC-DLR', 1001, 4)
on conflict (document_type) do nothing;

create function private.allocate_dealer_reference()
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
  where reference.document_type = 'dealer_authorization'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');

  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'dealer_authorization';

  return allocated_reference;
exception
  when no_data_found then
    raise exception using errcode = '55000', message = 'dealer_reference_sequence_unavailable';
end;
$$;

create function public.get_staff_dealer_queue(p_search text default null)
returns table (
  id uuid,
  party_id uuid,
  public_reference text,
  legal_name text,
  display_name text,
  public_display_name text,
  party_type_code text,
  party_type_label text,
  dealer_type_code text,
  dealer_type_label text,
  jurisdiction_code text,
  jurisdiction_label text,
  status_code text,
  status_label text,
  approved_premises_public text,
  public_notes text,
  private_notes text,
  effective_from timestamptz,
  effective_until timestamptz,
  public_disclosure_enabled boolean,
  version bigint,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('dealer.private.read');

  return query
  select
    authorization.id,
    party.id,
    authorization.public_reference,
    party.legal_name,
    party.display_name,
    party.public_display_name,
    party_type.code,
    party_type.display_name,
    dealer_type.code,
    dealer_type.display_name,
    jurisdiction.code,
    jurisdiction.public_name,
    status.code,
    status.display_name,
    authorization.approved_premises_public,
    authorization.public_notes,
    authorization.private_notes,
    authorization.effective_from,
    authorization.effective_until,
    authorization.public_disclosure_enabled,
    authorization.version,
    authorization.updated_at
  from public.dealer_authorizations as authorization
  join public.parties as party on party.id = authorization.dealer_party_id
  join public.party_types as party_type on party_type.id = party.party_type_id
  join public.dealer_types as dealer_type on dealer_type.id = authorization.dealer_type_id
  join public.jurisdictions as jurisdiction on jurisdiction.id = authorization.jurisdiction_id
  join public.dealer_status_definitions as status on status.id = authorization.status_definition_id
  where p_search is null
    or btrim(p_search) = ''
    or authorization.public_reference ilike '%' || btrim(p_search) || '%'
    or party.display_name ilike '%' || btrim(p_search) || '%'
    or party.legal_name ilike '%' || btrim(p_search) || '%'
  order by authorization.updated_at desc, authorization.public_reference;
end;
$$;

create function public.get_staff_dealer(p_dealer_authorization_id uuid)
returns table (
  id uuid,
  party_id uuid,
  public_reference text,
  legal_name text,
  display_name text,
  public_display_name text,
  party_type_code text,
  party_type_label text,
  dealer_type_code text,
  dealer_type_label text,
  jurisdiction_code text,
  jurisdiction_label text,
  status_code text,
  status_label text,
  approved_premises_public text,
  public_notes text,
  private_notes text,
  effective_from timestamptz,
  effective_until timestamptz,
  public_disclosure_enabled boolean,
  version bigint,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select dealer.*
  from public.get_staff_dealer_queue(null) as dealer
  where dealer.id = p_dealer_authorization_id;
$$;

create function public.get_staff_dealer_reference_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('dealer.private.read');

  return jsonb_build_object(
    'party_types', coalesce((
      select jsonb_agg(jsonb_build_object('code', item.code, 'display_name', item.display_name) order by item.display_name)
      from public.party_types as item where item.active
    ), '[]'::jsonb),
    'dealer_types', coalesce((
      select jsonb_agg(jsonb_build_object('code', item.code, 'display_name', item.display_name) order by item.display_name)
      from public.dealer_types as item where item.active
    ), '[]'::jsonb),
    'jurisdictions', coalesce((
      select jsonb_agg(jsonb_build_object('code', item.code, 'display_name', item.public_name) order by item.public_name)
      from public.jurisdictions as item where item.status = 'active'
    ), '[]'::jsonb),
    'initial_statuses', coalesce((
      select jsonb_agg(jsonb_build_object('code', item.code, 'display_name', item.display_name) order by item.display_name)
      from public.dealer_status_definitions as item
      where item.active and item.code in ('active', 'internal-review')
    ), '[]'::jsonb)
  );
end;
$$;

create function public.staff_create_dealer_authorization(
  p_party_type_code text,
  p_legal_name text,
  p_display_name text,
  p_public_display_name text,
  p_dealer_type_code text,
  p_jurisdiction_code text,
  p_initial_status_code text,
  p_approved_premises_public text,
  p_public_notes text,
  p_private_notes text,
  p_public_disclosure_enabled boolean,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, party_id uuid, public_reference text, version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing_record record;
  party_type_record record;
  dealer_type_record record;
  jurisdiction_record record;
  status_record record;
  created_party_id uuid;
  created_authorization_id uuid;
  created_reference text;
  disclose boolean := coalesce(p_public_disclosure_enabled, false);
begin
  actor_id := private.set_staff_audit_context('dealer.create', p_reason, p_request_id, 'staff_portal');

  select authorization.id, authorization.dealer_party_id, authorization.public_reference, authorization.version
  into existing_record
  from public.dealer_authorizations as authorization
  where authorization.source_request_id = p_request_id;
  if found then
    return query select existing_record.id, existing_record.dealer_party_id, existing_record.public_reference, existing_record.version;
    return;
  end if;

  if btrim(coalesce(p_legal_name, '')) = '' or btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'dealer_party_name_invalid';
  end if;
  if disclose and btrim(coalesce(p_public_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'dealer_public_name_required';
  end if;

  select item.id into party_type_record from public.party_types as item
  where item.code = lower(btrim(p_party_type_code)) and item.active;
  if not found then raise exception using errcode = '22023', message = 'dealer_party_type_invalid'; end if;

  select item.id into dealer_type_record from public.dealer_types as item
  where item.code = lower(btrim(p_dealer_type_code)) and item.active;
  if not found then raise exception using errcode = '22023', message = 'dealer_type_invalid'; end if;

  select item.id into jurisdiction_record from public.jurisdictions as item
  where item.code = lower(btrim(p_jurisdiction_code)) and item.status = 'active';
  if not found then raise exception using errcode = '22023', message = 'dealer_jurisdiction_invalid'; end if;

  select item.id, item.code into status_record from public.dealer_status_definitions as item
  where item.code = lower(btrim(p_initial_status_code))
    and item.code in ('active', 'internal-review') and item.active;
  if not found then raise exception using errcode = '22023', message = 'dealer_initial_status_invalid'; end if;

  insert into public.parties (
    party_type_id, legal_name, display_name, public_display_name,
    primary_jurisdiction_id, public_profile_enabled
  ) values (
    party_type_record.id, btrim(p_legal_name), btrim(p_display_name),
    case when disclose then btrim(p_public_display_name) else null end,
    jurisdiction_record.id, disclose
  ) returning parties.id into created_party_id;

  created_reference := private.allocate_dealer_reference();

  insert into public.dealer_authorizations (
    dealer_party_id, public_reference, dealer_type_id, jurisdiction_id,
    status_definition_id, approved_premises_public, public_notes, private_notes,
    effective_from, public_disclosure_enabled, approved_by, approved_at, source_request_id
  ) values (
    created_party_id, created_reference, dealer_type_record.id, jurisdiction_record.id,
    status_record.id, nullif(btrim(coalesce(p_approved_premises_public, '')), ''),
    btrim(coalesce(p_public_notes, '')), btrim(coalesce(p_private_notes, '')),
    statement_timestamp(), disclose,
    case when status_record.code = 'active' then actor_id else null end,
    case when status_record.code = 'active' then statement_timestamp() else null end,
    p_request_id
  ) returning dealer_authorizations.id into created_authorization_id;

  insert into public.dealer_authorization_events (
    dealer_authorization_id, event_type, new_status_definition_id, changed_by, reason, request_id
  ) values (created_authorization_id, 'created', status_record.id, actor_id, btrim(p_reason), p_request_id);

  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values (
    'dealer.authorization_created', 'dealer_authorization', created_authorization_id,
    jsonb_build_object('dealer_authorization_id', created_authorization_id, 'party_id', created_party_id, 'public_reference', created_reference, 'status_code', status_record.code),
    'dealer.authorization_created:' || p_request_id::text
  );

  return query select created_authorization_id, created_party_id, created_reference, 1::bigint;
end;
$$;

create function public.staff_update_dealer_authorization(
  p_dealer_authorization_id uuid,
  p_expected_version bigint,
  p_legal_name text,
  p_display_name text,
  p_public_display_name text,
  p_approved_premises_public text,
  p_public_notes text,
  p_private_notes text,
  p_public_disclosure_enabled boolean,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  authorization_record record;
  existing_event record;
  next_version bigint;
  disclose boolean := coalesce(p_public_disclosure_enabled, false);
begin
  actor_id := private.set_staff_audit_context('dealer.update', p_reason, p_request_id, 'staff_portal');

  select event.dealer_authorization_id into existing_event
  from public.dealer_authorization_events as event where event.request_id = p_request_id;
  if found then
    if existing_event.dealer_authorization_id <> p_dealer_authorization_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query select authorization.id, authorization.version
    from public.dealer_authorizations as authorization where authorization.id = p_dealer_authorization_id;
    return;
  end if;

  select authorization.id, authorization.dealer_party_id, authorization.version
  into authorization_record
  from public.dealer_authorizations as authorization
  where authorization.id = p_dealer_authorization_id
  for update of authorization;
  if not found then raise exception using errcode = 'P0002', message = 'dealer_authorization_not_found'; end if;
  if authorization_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'dealer_authorization_version_conflict';
  end if;
  if btrim(coalesce(p_legal_name, '')) = '' or btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'dealer_party_name_invalid';
  end if;
  if disclose and btrim(coalesce(p_public_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'dealer_public_name_required';
  end if;

  update public.parties as party
  set legal_name = btrim(p_legal_name),
      display_name = btrim(p_display_name),
      public_display_name = case when disclose then btrim(p_public_display_name) else null end,
      public_profile_enabled = disclose,
      version = party.version + 1
  where party.id = authorization_record.dealer_party_id;

  update public.dealer_authorizations as authorization
  set approved_premises_public = nullif(btrim(coalesce(p_approved_premises_public, '')), ''),
      public_notes = btrim(coalesce(p_public_notes, '')),
      private_notes = btrim(coalesce(p_private_notes, '')),
      public_disclosure_enabled = disclose,
      version = authorization.version + 1
  where authorization.id = p_dealer_authorization_id
  returning authorization.version into next_version;

  insert into public.dealer_authorization_events (
    dealer_authorization_id, event_type, changed_by, reason, request_id
  ) values (p_dealer_authorization_id, 'details_updated', actor_id, btrim(p_reason), p_request_id);

  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values (
    'dealer.authorization_updated', 'dealer_authorization', p_dealer_authorization_id,
    jsonb_build_object('dealer_authorization_id', p_dealer_authorization_id, 'version', next_version),
    'dealer.authorization_updated:' || p_request_id::text
  );

  return query select p_dealer_authorization_id, next_version;
end;
$$;

create function public.staff_change_dealer_authorization_status(
  p_dealer_authorization_id uuid,
  p_expected_version bigint,
  p_target_status_code text,
  p_reason text,
  p_request_id uuid
)
returns table (id uuid, version bigint, status_code text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  authorization_record record;
  existing_event record;
  target_status record;
  permission_code text;
  actor_id uuid;
  next_version bigint;
begin
  perform 1 from private.require_staff_permission('dealer.private.read');

  select event.dealer_authorization_id into existing_event
  from public.dealer_authorization_events as event where event.request_id = p_request_id;
  if found then
    if existing_event.dealer_authorization_id <> p_dealer_authorization_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select authorization.id, authorization.version, status.code
    from public.dealer_authorizations as authorization
    join public.dealer_status_definitions as status on status.id = authorization.status_definition_id
    where authorization.id = p_dealer_authorization_id;
    return;
  end if;

  select authorization.id, authorization.version, authorization.effective_until,
         status.id as status_id, status.code as status_code
  into authorization_record
  from public.dealer_authorizations as authorization
  join public.dealer_status_definitions as status on status.id = authorization.status_definition_id
  where authorization.id = p_dealer_authorization_id
  for update of authorization;
  if not found then raise exception using errcode = 'P0002', message = 'dealer_authorization_not_found'; end if;
  if authorization_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'dealer_authorization_version_conflict';
  end if;

  select status.id, status.code into target_status
  from public.dealer_status_definitions as status
  where status.code = lower(btrim(p_target_status_code)) and status.active;
  if not found then raise exception using errcode = '22023', message = 'dealer_target_status_invalid'; end if;
  if target_status.code = authorization_record.status_code then
    raise exception using errcode = '22023', message = 'dealer_status_unchanged';
  end if;
  if not (
    (authorization_record.status_code = 'internal-review' and target_status.code in ('active', 'revoked'))
    or (authorization_record.status_code = 'active' and target_status.code in ('suspended', 'revoked'))
    or (authorization_record.status_code = 'suspended' and target_status.code in ('active', 'revoked'))
  ) then
    raise exception using errcode = '22023', message = 'dealer_transition_invalid';
  end if;
  if target_status.code = 'active' and authorization_record.effective_until is not null
    and authorization_record.effective_until <= statement_timestamp() then
    raise exception using errcode = '22023', message = 'expired_dealer_authorization_cannot_activate';
  end if;

  permission_code := case
    when target_status.code = 'active' and authorization_record.status_code = 'internal-review' then 'dealer.activate'
    when target_status.code = 'active' then 'dealer.reinstate'
    when target_status.code = 'suspended' then 'dealer.suspend'
    when target_status.code = 'revoked' then 'dealer.revoke'
  end;
  actor_id := private.set_staff_audit_context(permission_code, p_reason, p_request_id, 'staff_portal');

  update public.dealer_authorizations as authorization
  set status_definition_id = target_status.id,
      approved_by = case when target_status.code = 'active' then actor_id else authorization.approved_by end,
      approved_at = case when target_status.code = 'active' then statement_timestamp() else authorization.approved_at end,
      version = authorization.version + 1
  where authorization.id = p_dealer_authorization_id
  returning authorization.version into next_version;

  insert into public.dealer_authorization_events (
    dealer_authorization_id, event_type, previous_status_definition_id,
    new_status_definition_id, changed_by, reason, request_id
  ) values (
    p_dealer_authorization_id, 'status_changed', authorization_record.status_id,
    target_status.id, actor_id, btrim(p_reason), p_request_id
  );

  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values (
    'dealer.authorization_status_changed', 'dealer_authorization', p_dealer_authorization_id,
    jsonb_build_object('dealer_authorization_id', p_dealer_authorization_id, 'previous_status_code', authorization_record.status_code, 'status_code', target_status.code),
    'dealer.authorization_status_changed:' || p_request_id::text
  );

  return query select p_dealer_authorization_id, next_version, target_status.code;
end;
$$;

revoke all on public.dealer_authorization_events from anon, authenticated;
revoke all on function private.allocate_dealer_reference() from public, anon, authenticated;
revoke all on function public.get_staff_dealer_queue(text) from public, anon;
revoke all on function public.get_staff_dealer(uuid) from public, anon;
revoke all on function public.get_staff_dealer_reference_data() from public, anon;
revoke all on function public.staff_create_dealer_authorization(text,text,text,text,text,text,text,text,text,text,boolean,text,uuid) from public, anon;
revoke all on function public.staff_update_dealer_authorization(uuid,bigint,text,text,text,text,text,text,boolean,text,uuid) from public, anon;
revoke all on function public.staff_change_dealer_authorization_status(uuid,bigint,text,text,uuid) from public, anon;

grant execute on function public.get_staff_dealer_queue(text) to authenticated;
grant execute on function public.get_staff_dealer(uuid) to authenticated;
grant execute on function public.get_staff_dealer_reference_data() to authenticated;
grant execute on function public.staff_create_dealer_authorization(text,text,text,text,text,text,text,text,text,text,boolean,text,uuid) to authenticated;
grant execute on function public.staff_update_dealer_authorization(uuid,bigint,text,text,text,text,text,text,boolean,text,uuid) to authenticated;
grant execute on function public.staff_change_dealer_authorization_status(uuid,bigint,text,text,uuid) to authenticated;
