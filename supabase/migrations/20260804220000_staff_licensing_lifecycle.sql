alter table public.licenses
  add column source_request_id uuid unique;

alter table public.license_endorsements
  add column version bigint not null default 1 check (version > 0);

create table public.reference_sequences (
  id uuid primary key default extensions.gen_random_uuid(),
  document_type text not null unique
    check (document_type ~ '^[a-z][a-z0-9_.-]{2,49}$'),
  prefix text not null check (prefix ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  next_value bigint not null check (next_value > 0),
  padding smallint not null default 4 check (padding between 1 and 12),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.license_status_events (
  id uuid primary key default extensions.gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete restrict,
  previous_status_definition_id uuid
    references public.license_status_definitions(id) on delete restrict,
  new_status_definition_id uuid not null
    references public.license_status_definitions(id) on delete restrict,
  event_type text not null check (event_type in ('issued', 'status_changed')),
  effective_at timestamptz not null default now(),
  changed_by uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now()
);

create table public.license_endorsement_events (
  id uuid primary key default extensions.gen_random_uuid(),
  license_endorsement_id uuid not null
    references public.license_endorsements(id) on delete restrict,
  license_id uuid not null references public.licenses(id) on delete restrict,
  event_type text not null check (event_type in ('granted', 'revoked')),
  effective_at timestamptz not null default now(),
  changed_by uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  created_at timestamptz not null default now(),
  foreign key (license_endorsement_id, license_id)
    references public.license_endorsements(id, license_id) on delete restrict
);

create table public.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null check (event_type ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  aggregate_type text not null check (aggregate_type ~ '^[a-z][a-z0-9_.-]{2,49}$'),
  aggregate_id uuid not null,
  payload_version smallint not null default 1 check (payload_version > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  occurred_at timestamptz not null default now(),
  available_at timestamptz not null default now(),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'delivered', 'failed', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  deduplication_key text not null unique check (btrim(deduplication_key) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.reference_sequences is
  'Configurable human-readable reference allocation. Callers never update counters directly.';
comment on table public.license_status_events is
  'Append-only domain history for issuance and license status transitions.';
comment on table public.license_endorsement_events is
  'Append-only domain history for endorsement grants and revocations.';
comment on table public.outbox_events is
  'Durable integration work created in the same transaction as business state. It is not business authority.';

create index license_status_events_license_idx
  on public.license_status_events(license_id, effective_at desc);
create index license_endorsement_events_license_idx
  on public.license_endorsement_events(license_id, effective_at desc);
create index outbox_events_pending_idx
  on public.outbox_events(status, available_at)
  where status in ('pending', 'failed');

create trigger reference_sequences_set_updated_at
before update on public.reference_sequences
for each row execute function private.set_updated_at();

create trigger outbox_events_set_updated_at
before update on public.outbox_events
for each row execute function private.set_updated_at();

create trigger reference_sequences_audit
after insert or update or delete on public.reference_sequences
for each row execute function private.capture_audit_row();

create trigger license_status_events_audit
after insert or update or delete on public.license_status_events
for each row execute function private.capture_audit_row();

create trigger license_endorsement_events_audit
after insert or update or delete on public.license_endorsement_events
for each row execute function private.capture_audit_row();

alter table public.reference_sequences enable row level security;
alter table public.license_status_events enable row level security;
alter table public.license_endorsement_events enable row level security;
alter table public.outbox_events enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'license.private.read',
    'Read licensing records',
    'View the internal licensing work queue, private notes, and lifecycle history.'
  ),
  (
    'license.issue',
    'Issue licenses',
    'Issue a configured license and its initial endorsements through the secure command.'
  ),
  (
    'license.activate',
    'Activate licenses',
    'Activate an issued provisional license through an audited status command.'
  ),
  (
    'license.suspend',
    'Suspend licenses',
    'Suspend an active or provisional license through an audited status command.'
  ),
  (
    'license.reinstate',
    'Reinstate licenses',
    'Restore a suspended current-term license through an audited status command.'
  ),
  (
    'license.revoke',
    'Revoke licenses',
    'Permanently revoke a non-terminal license through an audited status command.'
  ),
  (
    'license.surrender.record',
    'Record license surrender',
    'Record an authorized holder surrender through an audited status command.'
  ),
  (
    'endorsement.manage',
    'Manage endorsements',
    'Grant and revoke modular license endorsements through secure commands.'
  );

insert into public.staff_roles (
  code,
  display_name,
  description,
  is_elevated
)
values (
  'licensing_officer',
  'Licensing officer',
  'May read, issue, transition, and endorse licenses under the initial permission-based policy.',
  true
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'licensing_officer'
  and permission.code in (
    'license.private.read',
    'license.issue',
    'license.activate',
    'license.suspend',
    'license.reinstate',
    'license.revoke',
    'license.surrender.record',
    'endorsement.manage'
  );

insert into public.reference_sequences (
  document_type,
  prefix,
  next_value,
  padding
)
values ('license', 'EEC-LIC', 1001, 4);

insert into public.license_classes (
  id,
  code,
  display_name,
  public_display_name,
  description
)
values
  (
    '96000000-0000-0000-0000-000000000001',
    'commercial-dealer',
    'Commercial dealer license',
    'Commercial dealer license',
    'Configurable authority for an authorized commercial dealer.'
  ),
  (
    '96000000-0000-0000-0000-000000000002',
    'general-trade',
    'General trade license',
    'General trade license',
    'Configurable baseline authority for approved trade activity.'
  ),
  (
    '96000000-0000-0000-0000-000000000003',
    'institutional-trade',
    'Institutional trade license',
    'Institutional trade license',
    'Configurable authority for an approved institution or public body.'
  );

insert into public.license_status_definitions (
  id,
  code,
  display_name,
  public_result_code,
  confers_authority,
  publicly_verifiable
)
values
  (
    '97000000-0000-0000-0000-000000000001',
    'active',
    'Current license',
    'valid',
    true,
    true
  ),
  (
    '97000000-0000-0000-0000-000000000002',
    'internal-review',
    'Internal review',
    'not_verifiable',
    false,
    false
  ),
  (
    '97000000-0000-0000-0000-000000000003',
    'provisional',
    'Provisional license',
    'provisional',
    true,
    true
  ),
  (
    '97000000-0000-0000-0000-000000000004',
    'suspended',
    'Suspended license',
    'suspended',
    false,
    true
  ),
  (
    '97000000-0000-0000-0000-000000000005',
    'revoked',
    'Revoked license',
    'revoked',
    false,
    true
  ),
  (
    '97000000-0000-0000-0000-000000000006',
    'surrendered',
    'Surrendered license',
    'revoked',
    false,
    true
  ),
  (
    '97000000-0000-0000-0000-000000000007',
    'expired',
    'Expired license',
    'expired',
    false,
    true
  );

insert into public.endorsement_definitions (
  id,
  code,
  display_name,
  public_display_name,
  description
)
values
  (
    '98000000-0000-0000-0000-000000000010',
    'regulated-goods',
    'Regulated goods',
    'Regulated goods',
    'Configurable endorsement for goods that require additional authority.'
  ),
  (
    '98000000-0000-0000-0000-000000000011',
    'consignment',
    'Consignment operations',
    'Consignment operations',
    'Configurable endorsement for receiving goods on consignment.'
  ),
  (
    '98000000-0000-0000-0000-000000000012',
    'serialized-custody',
    'Serialized asset custody',
    'Serialized asset custody',
    'Configurable endorsement for custody of individually controlled assets.'
  );

create function private.allocate_license_reference()
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
  where reference.document_type = 'license'
    and reference.active
  for update;

  allocated_reference := sequence_record.prefix
    || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0');

  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.document_type = 'license';

  return allocated_reference;
exception
  when no_data_found then
    raise exception using
      errcode = '55000',
      message = 'license_reference_sequence_unavailable';
end;
$$;

create function public.get_staff_license_queue(p_search text default null)
returns table (
  id uuid,
  public_reference text,
  holder_name text,
  dealer_reference text,
  license_class_code text,
  license_class_label text,
  jurisdiction_code text,
  jurisdiction_label text,
  status_code text,
  status_label text,
  effective_from timestamptz,
  expires_at timestamptz,
  public_disclosure_enabled boolean,
  public_notes text,
  private_notes text,
  endorsements jsonb,
  version bigint,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('license.private.read');

  return query
  select
    license_record.id,
    license_record.public_reference,
    holder.display_name,
    dealer_record.public_reference,
    license_class.code,
    license_class.display_name,
    jurisdiction.code,
    jurisdiction.public_name,
    license_status.code,
    license_status.display_name,
    license_record.effective_from,
    license_record.expires_at,
    license_record.public_disclosure_enabled,
    license_record.public_notes,
    license_record.private_notes,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', granted.id,
            'code', definition.code,
            'label', definition.display_name,
            'effective_from', granted.effective_from,
            'expires_at', granted.expires_at,
            'revoked_at', granted.revoked_at,
            'public_disclosure_enabled', granted.public_disclosure_enabled,
            'version', granted.version
          )
          order by definition.display_name, granted.effective_from
        )
        from public.license_endorsements as granted
        join public.endorsement_definitions as definition
          on definition.id = granted.endorsement_definition_id
        where granted.license_id = license_record.id
      ),
      '[]'::jsonb
    ),
    license_record.version,
    license_record.updated_at
  from public.licenses as license_record
  join public.parties as holder on holder.id = license_record.holder_party_id
  left join public.dealer_authorizations as dealer_record
    on dealer_record.id = license_record.dealer_authorization_id
  join public.license_classes as license_class
    on license_class.id = license_record.license_class_id
  join public.jurisdictions as jurisdiction
    on jurisdiction.id = license_record.jurisdiction_id
  join public.license_status_definitions as license_status
    on license_status.id = license_record.status_definition_id
  where p_search is null
    or btrim(p_search) = ''
    or license_record.public_reference ilike '%' || btrim(p_search) || '%'
    or holder.display_name ilike '%' || btrim(p_search) || '%'
    or license_class.display_name ilike '%' || btrim(p_search) || '%'
  order by license_record.updated_at desc, license_record.public_reference;
end;
$$;

create function public.get_staff_license(p_license_id uuid)
returns table (
  id uuid,
  public_reference text,
  holder_name text,
  dealer_reference text,
  license_class_code text,
  license_class_label text,
  jurisdiction_code text,
  jurisdiction_label text,
  status_code text,
  status_label text,
  effective_from timestamptz,
  expires_at timestamptz,
  public_disclosure_enabled boolean,
  public_notes text,
  private_notes text,
  endorsements jsonb,
  version bigint,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select queue.*
  from public.get_staff_license_queue(null) as queue
  where queue.id = p_license_id;
$$;

create function public.get_staff_licensing_reference_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('license.private.read');

  return jsonb_build_object(
    'parties', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', party.id,
            'display_name', party.display_name,
            'party_type', party_type.display_name
          )
          order by party.display_name, party.id
        )
        from public.parties as party
        join public.party_types as party_type on party_type.id = party.party_type_id
        where party.status = 'active'
      ),
      '[]'::jsonb
    ),
    'dealer_authorizations', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', dealer_record.id,
            'party_id', dealer_record.dealer_party_id,
            'public_reference', dealer_record.public_reference
          )
          order by dealer_record.public_reference
        )
        from public.dealer_authorizations as dealer_record
      ),
      '[]'::jsonb
    ),
    'license_classes', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', definition.code, 'display_name', definition.display_name)
          order by definition.display_name
        )
        from public.license_classes as definition
        where definition.active
      ),
      '[]'::jsonb
    ),
    'jurisdictions', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', jurisdiction.code, 'display_name', jurisdiction.public_name)
          order by jurisdiction.public_name
        )
        from public.jurisdictions as jurisdiction
        where jurisdiction.status = 'active'
      ),
      '[]'::jsonb
    ),
    'initial_statuses', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', definition.code, 'display_name', definition.display_name)
          order by definition.display_name
        )
        from public.license_status_definitions as definition
        where definition.active
          and definition.code in ('active', 'provisional')
      ),
      '[]'::jsonb
    ),
    'endorsements', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', definition.code, 'display_name', definition.display_name)
          order by definition.display_name
        )
        from public.endorsement_definitions as definition
        where definition.active
      ),
      '[]'::jsonb
    )
  );
end;
$$;

create function public.staff_issue_license(
  p_holder_party_id uuid,
  p_dealer_authorization_id uuid,
  p_license_class_code text,
  p_jurisdiction_code text,
  p_initial_status_code text,
  p_effective_from timestamptz,
  p_expires_at timestamptz,
  p_public_disclosure_enabled boolean,
  p_public_notes text,
  p_private_notes text,
  p_endorsement_codes text[],
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
  actor_id uuid;
  existing_license record;
  holder_record record;
  dealer_record record;
  class_record record;
  jurisdiction_record record;
  status_record record;
  effective_at timestamptz;
  normalized_endorsement_codes text[];
  created_license_id uuid;
  created_reference text;
begin
  actor_id := private.set_staff_audit_context(
    'license.issue',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select license_record.id, license_record.public_reference, license_record.version
  into existing_license
  from public.licenses as license_record
  where license_record.source_request_id = p_request_id;

  if found then
    return query
    select existing_license.id, existing_license.public_reference, existing_license.version;
    return;
  end if;

  select party.id, party.public_profile_enabled
  into holder_record
  from public.parties as party
  where party.id = p_holder_party_id
    and party.status = 'active';
  if not found then
    raise exception using errcode = '22023', message = 'license_holder_invalid';
  end if;

  if coalesce(p_public_disclosure_enabled, false)
    and not holder_record.public_profile_enabled then
    raise exception using errcode = '22023', message = 'public_holder_profile_required';
  end if;

  if p_dealer_authorization_id is not null then
    select dealer_authorization.id
    into dealer_record
    from public.dealer_authorizations as dealer_authorization
    join public.dealer_status_definitions as dealer_status
      on dealer_status.id = dealer_authorization.status_definition_id
      and dealer_status.confers_authority
    where dealer_authorization.id = p_dealer_authorization_id
      and dealer_authorization.dealer_party_id = p_holder_party_id
      and dealer_authorization.effective_from <= statement_timestamp()
      and (
        dealer_authorization.effective_until is null
        or dealer_authorization.effective_until > statement_timestamp()
      );
    if not found then
      raise exception using errcode = '22023', message = 'dealer_authorization_invalid';
    end if;
  end if;

  select definition.id
  into class_record
  from public.license_classes as definition
  where definition.code = lower(btrim(p_license_class_code))
    and definition.active;
  if not found then
    raise exception using errcode = '22023', message = 'license_class_invalid';
  end if;

  select jurisdiction.id
  into jurisdiction_record
  from public.jurisdictions as jurisdiction
  where jurisdiction.code = lower(btrim(p_jurisdiction_code))
    and jurisdiction.status = 'active';
  if not found then
    raise exception using errcode = '22023', message = 'license_jurisdiction_invalid';
  end if;

  select definition.id, definition.code
  into status_record
  from public.license_status_definitions as definition
  where definition.code = lower(btrim(p_initial_status_code))
    and definition.code in ('active', 'provisional')
    and definition.active;
  if not found then
    raise exception using errcode = '22023', message = 'license_initial_status_invalid';
  end if;

  effective_at := coalesce(p_effective_from, statement_timestamp());
  if effective_at < statement_timestamp() then
    raise exception using errcode = '22023', message = 'license_backdating_not_allowed';
  end if;
  if p_expires_at is not null and p_expires_at <= effective_at then
    raise exception using errcode = '22023', message = 'license_term_invalid';
  end if;

  select coalesce(array_agg(distinct lower(btrim(code))), array[]::text[])
  into normalized_endorsement_codes
  from unnest(coalesce(p_endorsement_codes, array[]::text[])) as code
  where btrim(code) <> '';

  if exists (
    select 1
    from unnest(normalized_endorsement_codes) as requested(code)
    where not exists (
      select 1
      from public.endorsement_definitions as definition
      where definition.code = requested.code
        and definition.active
    )
  ) then
    raise exception using errcode = '22023', message = 'license_endorsement_invalid';
  end if;

  created_reference := private.allocate_license_reference();

  insert into public.licenses (
    public_reference,
    holder_party_id,
    dealer_authorization_id,
    license_class_id,
    jurisdiction_id,
    status_definition_id,
    issued_at,
    effective_from,
    expires_at,
    public_notes,
    private_notes,
    public_disclosure_enabled,
    issued_by,
    approved_by,
    source_request_id
  )
  values (
    created_reference,
    p_holder_party_id,
    p_dealer_authorization_id,
    class_record.id,
    jurisdiction_record.id,
    status_record.id,
    statement_timestamp(),
    effective_at,
    p_expires_at,
    coalesce(btrim(p_public_notes), ''),
    coalesce(btrim(p_private_notes), ''),
    coalesce(p_public_disclosure_enabled, false),
    actor_id,
    actor_id,
    p_request_id
  )
  returning licenses.id into created_license_id;

  if cardinality(normalized_endorsement_codes) > 0 then
    insert into public.license_endorsements (
      license_id,
      endorsement_definition_id,
      effective_from,
      expires_at,
      public_disclosure_enabled,
      granted_by
    )
    select
      created_license_id,
      definition.id,
      effective_at,
      p_expires_at,
      coalesce(p_public_disclosure_enabled, false),
      actor_id
    from public.endorsement_definitions as definition
    where definition.code = any(normalized_endorsement_codes);
  end if;

  insert into public.license_status_events (
    license_id,
    new_status_definition_id,
    event_type,
    effective_at,
    changed_by,
    reason,
    request_id
  )
  values (
    created_license_id,
    status_record.id,
    'issued',
    effective_at,
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
    'license.issued',
    'license',
    created_license_id,
    jsonb_build_object(
      'license_id', created_license_id,
      'public_reference', created_reference,
      'status_code', status_record.code
    ),
    'license.issued:' || p_request_id::text
  );

  return query select created_license_id, created_reference, 1::bigint;
end;
$$;

create function public.staff_change_license_status(
  p_license_id uuid,
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
  license_record record;
  existing_event record;
  target_status record;
  permission_code text;
  actor_id uuid;
  next_version bigint;
begin
  perform 1 from private.require_staff_permission('license.private.read');

  select event.license_id
  into existing_event
  from public.license_status_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.license_id <> p_license_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select current_license.id, current_license.version, current_status.code
    from public.licenses as current_license
    join public.license_status_definitions as current_status
      on current_status.id = current_license.status_definition_id
    where current_license.id = p_license_id;
    return;
  end if;

  select
    current_license.id,
    current_license.version,
    current_license.expires_at,
    current_status.id as status_id,
    current_status.code as status_code
  into license_record
  from public.licenses as current_license
  join public.license_status_definitions as current_status
    on current_status.id = current_license.status_definition_id
  where current_license.id = p_license_id
  for update of current_license;
  if not found then
    raise exception using errcode = 'P0002', message = 'license_not_found';
  end if;

  if license_record.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'license_version_conflict';
  end if;

  select definition.id, definition.code
  into target_status
  from public.license_status_definitions as definition
  where definition.code = lower(btrim(p_target_status_code))
    and definition.active;
  if not found then
    raise exception using errcode = '22023', message = 'license_target_status_invalid';
  end if;
  if target_status.code = license_record.status_code then
    raise exception using errcode = '22023', message = 'license_status_unchanged';
  end if;

  if not (
    (license_record.status_code = 'provisional' and target_status.code in ('active', 'suspended', 'revoked', 'surrendered'))
    or (license_record.status_code = 'active' and target_status.code in ('suspended', 'revoked', 'surrendered'))
    or (license_record.status_code = 'suspended' and target_status.code in ('active', 'revoked', 'surrendered'))
  ) then
    raise exception using errcode = '22023', message = 'license_transition_invalid';
  end if;

  if target_status.code = 'active'
    and license_record.expires_at is not null
    and license_record.expires_at <= statement_timestamp() then
    raise exception using errcode = '22023', message = 'expired_license_cannot_activate';
  end if;

  permission_code := case
    when target_status.code = 'active' and license_record.status_code = 'provisional'
      then 'license.activate'
    when target_status.code = 'active' then 'license.reinstate'
    when target_status.code = 'suspended' then 'license.suspend'
    when target_status.code = 'revoked' then 'license.revoke'
    when target_status.code = 'surrendered' then 'license.surrender.record'
  end;

  actor_id := private.set_staff_audit_context(
    permission_code,
    p_reason,
    p_request_id,
    'staff_portal'
  );

  update public.licenses as current_license
  set
    status_definition_id = target_status.id,
    version = current_license.version + 1
  where current_license.id = p_license_id
  returning current_license.version into next_version;

  insert into public.license_status_events (
    license_id,
    previous_status_definition_id,
    new_status_definition_id,
    event_type,
    changed_by,
    reason,
    request_id
  )
  values (
    p_license_id,
    license_record.status_id,
    target_status.id,
    'status_changed',
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
    'license.status_changed',
    'license',
    p_license_id,
    jsonb_build_object(
      'license_id', p_license_id,
      'previous_status_code', license_record.status_code,
      'status_code', target_status.code
    ),
    'license.status_changed:' || p_request_id::text
  );

  return query select p_license_id, next_version, target_status.code;
end;
$$;

create function public.staff_grant_license_endorsement(
  p_license_id uuid,
  p_expected_license_version bigint,
  p_endorsement_code text,
  p_effective_from timestamptz,
  p_expires_at timestamptz,
  p_public_disclosure_enabled boolean,
  p_reason text,
  p_request_id uuid
)
returns table (license_endorsement_id uuid, license_version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing_event record;
  license_record record;
  endorsement_record record;
  effective_at timestamptz;
  created_endorsement_id uuid;
  next_license_version bigint;
begin
  actor_id := private.set_staff_audit_context(
    'endorsement.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select event.license_endorsement_id, event.license_id
  into existing_event
  from public.license_endorsement_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.license_id <> p_license_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select existing_event.license_endorsement_id, current_license.version
    from public.licenses as current_license
    where current_license.id = p_license_id;
    return;
  end if;

  select
    current_license.id,
    current_license.version,
    current_license.effective_from,
    current_license.expires_at,
    current_status.code as status_code
  into license_record
  from public.licenses as current_license
  join public.license_status_definitions as current_status
    on current_status.id = current_license.status_definition_id
  where current_license.id = p_license_id
  for update of current_license;
  if not found then
    raise exception using errcode = 'P0002', message = 'license_not_found';
  end if;
  if license_record.version <> p_expected_license_version then
    raise exception using errcode = '40001', message = 'license_version_conflict';
  end if;
  if license_record.status_code in ('revoked', 'surrendered', 'expired') then
    raise exception using errcode = '22023', message = 'license_terminal';
  end if;

  select definition.id, definition.code, definition.prerequisite_endorsement_id, definition.exclusivity_group
  into endorsement_record
  from public.endorsement_definitions as definition
  where definition.code = lower(btrim(p_endorsement_code))
    and definition.active;
  if not found then
    raise exception using errcode = '22023', message = 'license_endorsement_invalid';
  end if;

  effective_at := coalesce(p_effective_from, statement_timestamp());
  if effective_at < license_record.effective_from then
    raise exception using errcode = '22023', message = 'endorsement_term_invalid';
  end if;
  if p_expires_at is not null and p_expires_at <= effective_at then
    raise exception using errcode = '22023', message = 'endorsement_term_invalid';
  end if;
  if license_record.expires_at is not null
    and (p_expires_at is null or p_expires_at > license_record.expires_at) then
    raise exception using errcode = '22023', message = 'endorsement_exceeds_license_term';
  end if;

  if endorsement_record.prerequisite_endorsement_id is not null
    and not exists (
      select 1
      from public.license_endorsements as prerequisite
      where prerequisite.license_id = p_license_id
        and prerequisite.endorsement_definition_id = endorsement_record.prerequisite_endorsement_id
        and prerequisite.revoked_at is null
        and prerequisite.effective_from <= effective_at
        and (prerequisite.expires_at is null or prerequisite.expires_at > effective_at)
    ) then
    raise exception using errcode = '22023', message = 'endorsement_prerequisite_missing';
  end if;

  if endorsement_record.exclusivity_group is not null
    and exists (
      select 1
      from public.license_endorsements as existing
      join public.endorsement_definitions as existing_definition
        on existing_definition.id = existing.endorsement_definition_id
      where existing.license_id = p_license_id
        and existing.revoked_at is null
        and existing_definition.exclusivity_group = endorsement_record.exclusivity_group
        and tstzrange(existing.effective_from, coalesce(existing.expires_at, 'infinity'::timestamptz), '[)')
          && tstzrange(effective_at, coalesce(p_expires_at, 'infinity'::timestamptz), '[)')
    ) then
    raise exception using errcode = '22023', message = 'endorsement_exclusivity_conflict';
  end if;

  insert into public.license_endorsements (
    license_id,
    endorsement_definition_id,
    effective_from,
    expires_at,
    public_disclosure_enabled,
    granted_by
  )
  values (
    p_license_id,
    endorsement_record.id,
    effective_at,
    p_expires_at,
    coalesce(p_public_disclosure_enabled, false),
    actor_id
  )
  returning license_endorsements.id into created_endorsement_id;

  update public.licenses as current_license
  set version = current_license.version + 1
  where current_license.id = p_license_id
  returning current_license.version into next_license_version;

  insert into public.license_endorsement_events (
    license_endorsement_id,
    license_id,
    event_type,
    effective_at,
    changed_by,
    reason,
    request_id
  )
  values (
    created_endorsement_id,
    p_license_id,
    'granted',
    effective_at,
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
    'license.endorsement_granted',
    'license',
    p_license_id,
    jsonb_build_object(
      'license_id', p_license_id,
      'license_endorsement_id', created_endorsement_id,
      'endorsement_code', endorsement_record.code
    ),
    'license.endorsement_granted:' || p_request_id::text
  );

  return query select created_endorsement_id, next_license_version;
exception
  when exclusion_violation then
    raise exception using errcode = '22023', message = 'endorsement_already_active';
end;
$$;

create function public.staff_revoke_license_endorsement(
  p_license_endorsement_id uuid,
  p_expected_license_version bigint,
  p_reason text,
  p_request_id uuid
)
returns table (license_endorsement_id uuid, license_version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing_event record;
  granted_record record;
  next_license_version bigint;
begin
  actor_id := private.set_staff_audit_context(
    'endorsement.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select event.license_endorsement_id, event.license_id
  into existing_event
  from public.license_endorsement_events as event
  where event.request_id = p_request_id;
  if found then
    if existing_event.license_endorsement_id <> p_license_endorsement_id then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    return query
    select existing_event.license_endorsement_id, current_license.version
    from public.licenses as current_license
    where current_license.id = existing_event.license_id;
    return;
  end if;

  select
    granted.id,
    granted.license_id,
    granted.revoked_at,
    current_license.version as license_version
  into granted_record
  from public.license_endorsements as granted
  join public.licenses as current_license on current_license.id = granted.license_id
  where granted.id = p_license_endorsement_id
  for update of granted, current_license;
  if not found then
    raise exception using errcode = 'P0002', message = 'license_endorsement_not_found';
  end if;
  if granted_record.license_version <> p_expected_license_version then
    raise exception using errcode = '40001', message = 'license_version_conflict';
  end if;
  if granted_record.revoked_at is not null then
    raise exception using errcode = '22023', message = 'license_endorsement_already_revoked';
  end if;

  update public.license_endorsements as granted
  set
    revoked_at = statement_timestamp(),
    version = granted.version + 1
  where granted.id = p_license_endorsement_id;

  update public.licenses as current_license
  set version = current_license.version + 1
  where current_license.id = granted_record.license_id
  returning current_license.version into next_license_version;

  insert into public.license_endorsement_events (
    license_endorsement_id,
    license_id,
    event_type,
    changed_by,
    reason,
    request_id
  )
  values (
    p_license_endorsement_id,
    granted_record.license_id,
    'revoked',
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
    'license.endorsement_revoked',
    'license',
    granted_record.license_id,
    jsonb_build_object(
      'license_id', granted_record.license_id,
      'license_endorsement_id', p_license_endorsement_id
    ),
    'license.endorsement_revoked:' || p_request_id::text
  );

  return query select p_license_endorsement_id, next_license_version;
end;
$$;

revoke all on public.reference_sequences from anon, authenticated;
revoke all on public.license_status_events from anon, authenticated;
revoke all on public.license_endorsement_events from anon, authenticated;
revoke all on public.outbox_events from anon, authenticated;

revoke all on function private.allocate_license_reference()
  from public, anon, authenticated;

revoke execute on function public.get_staff_license_queue(text) from public, anon;
revoke execute on function public.get_staff_license(uuid) from public, anon;
revoke execute on function public.get_staff_licensing_reference_data() from public, anon;
revoke execute on function public.staff_issue_license(
  uuid, uuid, text, text, text, timestamptz, timestamptz, boolean, text, text, text[], text, uuid
) from public, anon;
revoke execute on function public.staff_change_license_status(
  uuid, bigint, text, text, uuid
) from public, anon;
revoke execute on function public.staff_grant_license_endorsement(
  uuid, bigint, text, timestamptz, timestamptz, boolean, text, uuid
) from public, anon;
revoke execute on function public.staff_revoke_license_endorsement(
  uuid, bigint, text, uuid
) from public, anon;

grant execute on function public.get_staff_license_queue(text) to authenticated;
grant execute on function public.get_staff_license(uuid) to authenticated;
grant execute on function public.get_staff_licensing_reference_data() to authenticated;
grant execute on function public.staff_issue_license(
  uuid, uuid, text, text, text, timestamptz, timestamptz, boolean, text, text, text[], text, uuid
) to authenticated;
grant execute on function public.staff_change_license_status(
  uuid, bigint, text, text, uuid
) to authenticated;
grant execute on function public.staff_grant_license_endorsement(
  uuid, bigint, text, timestamptz, timestamptz, boolean, text, uuid
) to authenticated;
grant execute on function public.staff_revoke_license_endorsement(
  uuid, bigint, text, uuid
) to authenticated;
