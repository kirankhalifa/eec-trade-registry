create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'integration.private.read',
    'Read integration operations',
    'View configured destinations, export runs, delivery attempts, and outbox health.'
  ),
  (
    'integration.manage',
    'Manage integration operations',
    'Configure non-secret destination identifiers and request approved exports.'
  ),
  (
    'integration.replay',
    'Replay integration work',
    'Retry failed export runs and notification deliveries without changing business state.'
  );

insert into public.staff_roles (
  code,
  display_name,
  description,
  is_elevated
)
values (
  'integration_operator',
  'Integration operator',
  'May monitor, configure, and safely replay approved projection deliveries.',
  true
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'integration_operator'
  and permission.code in (
    'integration.private.read',
    'integration.manage',
    'integration.replay'
  );

create table public.integration_destinations (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  display_name text not null check (btrim(display_name) <> ''),
  destination_type text not null
    check (destination_type in ('google_sheets', 'discord_channel')),
  visibility text not null
    check (visibility in ('public', 'dealer_private', 'staff_private')),
  external_reference text,
  configuration jsonb not null default '{}'::jsonb
    check (jsonb_typeof(configuration) = 'object'),
  active boolean not null default false,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    not active
    or (
      external_reference is not null
      and btrim(external_reference) <> ''
    )
  ),
  check (
    external_reference is null
    or case destination_type
      when 'google_sheets' then
        char_length(external_reference) between 10 and 256
        and external_reference ~ '^[A-Za-z0-9_-]+$'
      when 'discord_channel' then external_reference ~ '^[0-9]{16,22}$'
      else false
    end
  )
);

create table public.notification_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  event_type text not null
    check (event_type ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  destination_type text not null
    check (destination_type in ('discord_channel')),
  template_version integer not null default 1 check (template_version > 0),
  message_template text not null
    check (btrim(message_template) <> '' and char_length(message_template) <= 1800),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_type, destination_type, template_version)
);

create table public.integration_event_routes (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null
    check (event_type ~ '^[a-z][a-z0-9_.-]{2,99}$'),
  destination_id uuid not null
    references public.integration_destinations(id) on delete restrict,
  notification_template_id uuid not null
    references public.notification_templates(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_type, destination_id)
);

create table public.integration_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  outbox_event_id uuid not null
    references public.outbox_events(id) on delete restrict,
  event_route_id uuid not null
    references public.integration_event_routes(id) on delete restrict,
  destination_id uuid not null
    references public.integration_destinations(id) on delete restrict,
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'delivered', 'failed', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  first_attempted_at timestamptz,
  last_attempted_at timestamptz,
  delivered_at timestamptz,
  lease_token uuid,
  lease_expires_at timestamptz,
  worker_id text,
  external_message_id text,
  last_error text,
  deduplication_key text not null unique check (btrim(deduplication_key) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (outbox_event_id, destination_id),
  check (
    (status = 'processing' and lease_token is not null and lease_expires_at is not null)
    or status <> 'processing'
  )
);

create table public.export_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  display_name text not null check (btrim(display_name) <> ''),
  projection_code text not null
    check (projection_code in ('public_catalogue', 'public_dealers', 'public_licenses')),
  destination_id uuid not null
    references public.integration_destinations(id) on delete restrict,
  sheet_tab_name text not null
    check (btrim(sheet_tab_name) <> '' and char_length(sheet_tab_name) <= 100),
  column_contract jsonb not null
    check (jsonb_typeof(column_contract) = 'array'),
  refresh_interval_minutes integer not null default 15
    check (refresh_interval_minutes between 5 and 1440),
  visibility text not null default 'public' check (visibility = 'public'),
  active boolean not null default false,
  next_run_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.export_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  export_definition_id uuid not null
    references public.export_definitions(id) on delete restrict,
  run_key text not null unique check (btrim(run_key) <> ''),
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null,
  available_at timestamptz not null default now(),
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'delivered', 'failed', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  lease_token uuid,
  lease_expires_at timestamptz,
  worker_id text,
  watermark_at timestamptz,
  generated_at timestamptz,
  row_count integer check (row_count is null or row_count >= 0),
  checksum text,
  destination_version text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'processing' and lease_token is not null and lease_expires_at is not null)
    or status <> 'processing'
  )
);

comment on table public.integration_destinations is
  'Non-secret external destination identifiers. Credentials remain in managed server environment configuration.';
comment on table public.integration_deliveries is
  'Retryable, idempotent delivery metadata. External messages never become business authority.';
comment on table public.export_definitions is
  'Approved one-way public projection contracts and schedules.';
comment on table public.export_runs is
  'Immutable run identity plus mutable delivery status for one-way public exports. Sheet edits are never imported.';

create index integration_deliveries_claim_idx
  on public.integration_deliveries(status, available_at, lease_expires_at)
  where status in ('queued', 'processing', 'failed');
create index integration_deliveries_event_idx
  on public.integration_deliveries(outbox_event_id, status);
create index export_definitions_due_idx
  on public.export_definitions(active, next_run_at)
  where active;
create index export_runs_claim_idx
  on public.export_runs(status, available_at, lease_expires_at)
  where status in ('queued', 'processing', 'failed');

create trigger integration_destinations_set_updated_at
before update on public.integration_destinations
for each row execute function private.set_updated_at();
create trigger notification_templates_set_updated_at
before update on public.notification_templates
for each row execute function private.set_updated_at();
create trigger integration_event_routes_set_updated_at
before update on public.integration_event_routes
for each row execute function private.set_updated_at();
create trigger integration_deliveries_set_updated_at
before update on public.integration_deliveries
for each row execute function private.set_updated_at();
create trigger export_definitions_set_updated_at
before update on public.export_definitions
for each row execute function private.set_updated_at();
create trigger export_runs_set_updated_at
before update on public.export_runs
for each row execute function private.set_updated_at();

create trigger integration_destinations_audit
after insert or update or delete on public.integration_destinations
for each row execute function private.capture_audit_row();
create trigger notification_templates_audit
after insert or update or delete on public.notification_templates
for each row execute function private.capture_audit_row();
create trigger integration_event_routes_audit
after insert or update or delete on public.integration_event_routes
for each row execute function private.capture_audit_row();
create trigger integration_deliveries_audit
after insert or update or delete on public.integration_deliveries
for each row execute function private.capture_audit_row();
create trigger export_definitions_audit
after insert or update or delete on public.export_definitions
for each row execute function private.capture_audit_row();
create trigger export_runs_audit
after insert or update or delete on public.export_runs
for each row execute function private.capture_audit_row();

alter table public.integration_destinations enable row level security;
alter table public.notification_templates enable row level security;
alter table public.integration_event_routes enable row level security;
alter table public.integration_deliveries enable row level security;
alter table public.export_definitions enable row level security;
alter table public.export_runs enable row level security;

create function public.get_public_catalogue_export()
returns table (
  item_code text,
  public_name text,
  public_description text,
  category text,
  unit text,
  tags text,
  control_level text,
  availability text,
  public_price_minor bigint,
  currency_code text,
  bulk_minimum numeric,
  order_increment numeric,
  requirements text,
  source_url text,
  published_at timestamptz,
  generated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    item.item_code,
    item.display_name,
    item.description,
    item.category_name,
    item.unit_name,
    array_to_string(item.tags, ', '),
    item.control_label,
    item.availability_label,
    item.price_amount_minor,
    item.currency_code,
    item.bulk_minimum,
    item.order_increment,
    item.requirement_summary,
    '/catalogue/' || item.slug,
    item.published_at,
    item.generated_at
  from public.get_public_catalogue(null, null) as item;
$$;

create function public.get_public_dealer_export()
returns table (
  public_reference text,
  public_name text,
  dealer_type text,
  jurisdiction text,
  public_premises text,
  status text,
  currently_authorized boolean,
  effective_from timestamptz,
  effective_until timestamptz,
  related_public_licenses text,
  public_notice text,
  generated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    dealer_authorization.public_reference,
    party.public_display_name,
    dealer_type.display_name,
    jurisdiction.public_name,
    nullif(btrim(dealer_authorization.approved_premises_public), ''),
    status.display_name,
    (
      status.confers_authority
      and dealer_authorization.effective_from <= current_timestamp
      and (
        dealer_authorization.effective_until is null
        or dealer_authorization.effective_until > current_timestamp
      )
    ),
    dealer_authorization.effective_from,
    dealer_authorization.effective_until,
    coalesce(related.public_references, ''),
    nullif(btrim(dealer_authorization.public_notes), ''),
    current_timestamp
  from public.dealer_authorizations as dealer_authorization
  join public.parties as party
    on party.id = dealer_authorization.dealer_party_id
    and party.status = 'active'
    and party.public_profile_enabled
  join public.dealer_types as dealer_type
    on dealer_type.id = dealer_authorization.dealer_type_id
  join public.jurisdictions as jurisdiction
    on jurisdiction.id = dealer_authorization.jurisdiction_id
  join public.dealer_status_definitions as status
    on status.id = dealer_authorization.status_definition_id
    and status.publicly_verifiable
  left join lateral (
    select string_agg(license.public_reference, ', ' order by license.public_reference) as public_references
    from public.licenses as license
    join public.license_status_definitions as license_status
      on license_status.id = license.status_definition_id
      and license_status.publicly_verifiable
    join public.parties as license_holder
      on license_holder.id = license.holder_party_id
      and license_holder.status = 'active'
      and license_holder.public_profile_enabled
    where license.dealer_authorization_id = dealer_authorization.id
      and license.public_disclosure_enabled
  ) as related on true
  where dealer_authorization.public_disclosure_enabled
  order by party.public_display_name, dealer_authorization.public_reference;
$$;

create function public.get_public_license_export()
returns table (
  public_reference text,
  holder_name text,
  license_class text,
  jurisdiction text,
  status text,
  currently_authorized boolean,
  effective_from timestamptz,
  expires_at timestamptz,
  endorsements text,
  public_conditions text,
  public_notice text,
  generated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    license.public_reference,
    holder.public_display_name,
    license_class.public_display_name,
    jurisdiction.public_name,
    status.display_name,
    (
      status.confers_authority
      and license.effective_from <= current_timestamp
      and (license.expires_at is null or license.expires_at > current_timestamp)
    ),
    license.effective_from,
    license.expires_at,
    coalesce(endorsement_list.labels, ''),
    coalesce(condition_list.labels, ''),
    nullif(btrim(license.public_notes), ''),
    current_timestamp
  from public.licenses as license
  join public.parties as holder
    on holder.id = license.holder_party_id
    and holder.status = 'active'
    and holder.public_profile_enabled
  join public.license_classes as license_class
    on license_class.id = license.license_class_id
  join public.jurisdictions as jurisdiction
    on jurisdiction.id = license.jurisdiction_id
  join public.license_status_definitions as status
    on status.id = license.status_definition_id
    and status.publicly_verifiable
  left join lateral (
    select string_agg(
      distinct endorsement.public_display_name,
      ', ' order by endorsement.public_display_name
    ) as labels
    from public.license_endorsements as granted
    join public.endorsement_definitions as endorsement
      on endorsement.id = granted.endorsement_definition_id
    where granted.license_id = license.id
      and granted.public_disclosure_enabled
      and granted.revoked_at is null
      and granted.effective_from <= current_timestamp
      and (granted.expires_at is null or granted.expires_at > current_timestamp)
  ) as endorsement_list on true
  left join lateral (
    select string_agg(condition.public_text, '; ' order by condition.condition_code) as labels
    from public.license_conditions as condition
    where condition.license_id = license.id
      and condition.public_visibility
      and condition.effective_from <= current_timestamp
      and (
        condition.effective_until is null
        or condition.effective_until > current_timestamp
      )
  ) as condition_list on true
  where license.public_disclosure_enabled
  order by holder.public_display_name, license.public_reference;
$$;

create function private.refresh_outbox_delivery_status(p_outbox_event_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  delivery_count integer;
  delivered_count integer;
  failed_count integer;
  pending_count integer;
  latest_error text;
begin
  select
    count(*),
    count(*) filter (where delivery.status in ('delivered', 'cancelled')),
    count(*) filter (where delivery.status = 'failed'),
    count(*) filter (where delivery.status in ('queued', 'processing')),
    max(delivery.last_error) filter (where delivery.status = 'failed')
  into
    delivery_count,
    delivered_count,
    failed_count,
    pending_count,
    latest_error
  from public.integration_deliveries as delivery
  where delivery.outbox_event_id = p_outbox_event_id;

  if delivery_count = 0 then
    return;
  end if;

  update public.outbox_events
  set status = case
      when delivered_count = delivery_count then 'delivered'
      when pending_count > 0 then 'processing'
      when failed_count > 0 then 'failed'
      else 'cancelled'
    end,
    last_error = case when failed_count > 0 then latest_error else null end
  where id = p_outbox_event_id;
end;
$$;

create function private.materialize_integration_deliveries()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  insert into public.integration_deliveries (
    outbox_event_id,
    event_route_id,
    destination_id,
    available_at,
    deduplication_key
  )
  select
    event.id,
    route.id,
    destination.id,
    event.available_at,
    event.deduplication_key || ':' || destination.code
  from public.outbox_events as event
  join public.integration_event_routes as route
    on route.event_type = event.event_type
    and route.active
  join public.integration_destinations as destination
    on destination.id = route.destination_id
    and destination.active
  join public.notification_templates as template
    on template.id = route.notification_template_id
    and template.active
    and template.event_type = event.event_type
    and template.destination_type = destination.destination_type
  where event.status in ('pending', 'processing', 'failed')
    and event.available_at <= current_timestamp
  on conflict (outbox_event_id, destination_id) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create function private.invoke_integration_worker()
returns bigint
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  worker_url text;
  worker_secret text;
  request_id bigint;
begin
  select decrypted_secret into worker_url
  from vault.decrypted_secrets
  where name = 'eec_integration_worker_url';

  select decrypted_secret into worker_secret
  from vault.decrypted_secrets
  where name = 'eec_integration_cron_secret';

  if worker_url is null
    or worker_url !~ '^https://[^[:space:]]+/api/cron/integrations$'
    or worker_secret is null
    or char_length(worker_secret) < 16 then
    return null;
  end if;

  select net.http_get(
    url := worker_url,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || worker_secret,
      'User-Agent', 'eec-supabase-cron/1.0'
    ),
    timeout_milliseconds := 300000
  ) into request_id;

  return request_id;
end;
$$;

select cron.schedule(
  'eec-integration-worker',
  '*/15 * * * *',
  $cron$select private.invoke_integration_worker()$cron$
);

create function public.integration_claim_deliveries(
  p_worker_id text,
  p_batch_size integer default 10,
  p_lease_seconds integer default 120
)
returns table (
  delivery_id uuid,
  lease_token uuid,
  event_type text,
  aggregate_type text,
  aggregate_id uuid,
  payload_version smallint,
  payload jsonb,
  destination_type text,
  destination_reference text,
  destination_configuration jsonb,
  template_code text,
  template_version integer,
  message_template text,
  attempt_count integer
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  candidate record;
  claimed_token uuid;
begin
  if btrim(coalesce(p_worker_id, '')) = '' or char_length(p_worker_id) > 100 then
    raise exception using errcode = '22023', message = 'worker_id_invalid';
  end if;
  if p_batch_size < 1 or p_batch_size > 50 then
    raise exception using errcode = '22023', message = 'batch_size_invalid';
  end if;
  if p_lease_seconds < 30 or p_lease_seconds > 900 then
    raise exception using errcode = '22023', message = 'lease_invalid';
  end if;

  perform private.materialize_integration_deliveries();

  for candidate in
    select delivery.id
    from public.integration_deliveries as delivery
    join public.outbox_events as event on event.id = delivery.outbox_event_id
    join public.integration_event_routes as route
      on route.id = delivery.event_route_id
      and route.active
    join public.integration_destinations as destination
      on destination.id = delivery.destination_id
      and destination.active
    join public.notification_templates as template
      on template.id = route.notification_template_id
      and template.active
    where delivery.attempt_count < 8
      and delivery.available_at <= current_timestamp
      and (
        delivery.status in ('queued', 'failed')
        or (
          delivery.status = 'processing'
          and delivery.lease_expires_at <= current_timestamp
        )
      )
      and event.available_at <= current_timestamp
    order by delivery.available_at, delivery.created_at
    limit p_batch_size
    for update of delivery skip locked
  loop
    claimed_token := extensions.gen_random_uuid();

    update public.integration_deliveries as claimed_delivery
    set status = 'processing',
        attempt_count = claimed_delivery.attempt_count + 1,
        first_attempted_at = coalesce(
          claimed_delivery.first_attempted_at,
          current_timestamp
        ),
        last_attempted_at = current_timestamp,
        lease_token = claimed_token,
        lease_expires_at = current_timestamp + make_interval(secs => p_lease_seconds),
        worker_id = p_worker_id,
        last_error = null
    where id = candidate.id;

    update public.outbox_events as event
    set status = 'processing',
        attempt_count = event.attempt_count + 1,
        last_error = null
    from public.integration_deliveries as delivery
    where delivery.id = candidate.id
      and event.id = delivery.outbox_event_id;

    return query
    select
      delivery.id,
      delivery.lease_token,
      event.event_type,
      event.aggregate_type,
      event.aggregate_id,
      event.payload_version,
      event.payload,
      destination.destination_type,
      destination.external_reference,
      destination.configuration,
      template.code,
      template.template_version,
      template.message_template,
      delivery.attempt_count
    from public.integration_deliveries as delivery
    join public.outbox_events as event on event.id = delivery.outbox_event_id
    join public.integration_destinations as destination
      on destination.id = delivery.destination_id
    join public.integration_event_routes as route
      on route.id = delivery.event_route_id
    join public.notification_templates as template
      on template.id = route.notification_template_id
    where delivery.id = candidate.id;
  end loop;
end;
$$;

create function public.integration_complete_delivery(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_external_message_id text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  event_id uuid;
begin
  update public.integration_deliveries
  set status = 'delivered',
      delivered_at = current_timestamp,
      external_message_id = nullif(btrim(p_external_message_id), ''),
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = null
  where id = p_delivery_id
    and status = 'processing'
    and lease_token = p_lease_token
    and lease_expires_at > current_timestamp
  returning outbox_event_id into event_id;

  if event_id is null then
    raise exception using errcode = '40001', message = 'delivery_lease_conflict';
  end if;

  perform private.refresh_outbox_delivery_status(event_id);
end;
$$;

create function public.integration_fail_delivery(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_error text,
  p_retry_at timestamptz
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  event_id uuid;
  normalized_error text;
begin
  normalized_error := left(btrim(coalesce(p_error, 'delivery_failed')), 500);
  if p_retry_at is null or p_retry_at <= current_timestamp then
    raise exception using errcode = '22023', message = 'retry_at_invalid';
  end if;

  update public.integration_deliveries
  set status = 'failed',
      available_at = p_retry_at,
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = normalized_error
  where id = p_delivery_id
    and status = 'processing'
    and lease_token = p_lease_token
  returning outbox_event_id into event_id;

  if event_id is null then
    raise exception using errcode = '40001', message = 'delivery_lease_conflict';
  end if;

  perform private.refresh_outbox_delivery_status(event_id);
end;
$$;

create function public.integration_queue_due_exports(
  p_now timestamptz default current_timestamp
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  definition record;
  inserted_count integer := 0;
begin
  for definition in
    select export_definition.*
    from public.export_definitions as export_definition
    join public.integration_destinations as destination
      on destination.id = export_definition.destination_id
      and destination.active
      and destination.destination_type = 'google_sheets'
    where export_definition.active
      and export_definition.next_run_at <= p_now
    order by export_definition.next_run_at
    for update of export_definition skip locked
  loop
    insert into public.export_runs (
      export_definition_id,
      run_key,
      scheduled_for
    )
    values (
      definition.id,
      definition.code || ':' || extract(epoch from definition.next_run_at)::bigint::text,
      definition.next_run_at
    )
    on conflict (run_key) do nothing;

    if found then
      inserted_count := inserted_count + 1;
    end if;

    update public.export_definitions
    set next_run_at = greatest(
      definition.next_run_at
        + make_interval(mins => definition.refresh_interval_minutes),
      p_now + make_interval(mins => definition.refresh_interval_minutes)
    )
    where id = definition.id;
  end loop;

  return inserted_count;
end;
$$;

create function public.integration_claim_export_runs(
  p_worker_id text,
  p_batch_size integer default 3,
  p_lease_seconds integer default 300
)
returns table (
  export_run_id uuid,
  lease_token uuid,
  definition_code text,
  projection_code text,
  sheet_tab_name text,
  column_contract jsonb,
  destination_reference text,
  destination_configuration jsonb,
  scheduled_for timestamptz,
  attempt_count integer
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  candidate record;
  claimed_token uuid;
begin
  if btrim(coalesce(p_worker_id, '')) = '' or char_length(p_worker_id) > 100 then
    raise exception using errcode = '22023', message = 'worker_id_invalid';
  end if;
  if p_batch_size < 1 or p_batch_size > 10 then
    raise exception using errcode = '22023', message = 'batch_size_invalid';
  end if;
  if p_lease_seconds < 60 or p_lease_seconds > 900 then
    raise exception using errcode = '22023', message = 'lease_invalid';
  end if;

  for candidate in
    select run.id
    from public.export_runs as run
    join public.export_definitions as definition
      on definition.id = run.export_definition_id
      and definition.active
    join public.integration_destinations as destination
      on destination.id = definition.destination_id
      and destination.active
      and destination.destination_type = 'google_sheets'
    where run.attempt_count < 8
      and run.available_at <= current_timestamp
      and (
        run.status in ('queued', 'failed')
        or (
          run.status = 'processing'
          and run.lease_expires_at <= current_timestamp
        )
      )
    order by run.scheduled_for, run.created_at
    limit p_batch_size
    for update of run skip locked
  loop
    claimed_token := extensions.gen_random_uuid();

    update public.export_runs as claimed_run
    set status = 'processing',
        attempt_count = claimed_run.attempt_count + 1,
        started_at = coalesce(claimed_run.started_at, current_timestamp),
        lease_token = claimed_token,
        lease_expires_at = current_timestamp + make_interval(secs => p_lease_seconds),
        worker_id = p_worker_id,
        last_error = null
    where id = candidate.id;

    return query
    select
      run.id,
      run.lease_token,
      definition.code,
      definition.projection_code,
      definition.sheet_tab_name,
      definition.column_contract,
      destination.external_reference,
      destination.configuration,
      run.scheduled_for,
      run.attempt_count
    from public.export_runs as run
    join public.export_definitions as definition
      on definition.id = run.export_definition_id
    join public.integration_destinations as destination
      on destination.id = definition.destination_id
    where run.id = candidate.id;
  end loop;
end;
$$;

create function public.integration_complete_export_run(
  p_export_run_id uuid,
  p_lease_token uuid,
  p_row_count integer,
  p_checksum text,
  p_destination_version text,
  p_generated_at timestamptz,
  p_watermark_at timestamptz
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_row_count < 0
    or btrim(coalesce(p_checksum, '')) = ''
    or btrim(coalesce(p_destination_version, '')) = ''
    or p_generated_at is null
    or p_watermark_at is null then
    raise exception using errcode = '22023', message = 'export_result_invalid';
  end if;

  update public.export_runs
  set status = 'delivered',
      completed_at = current_timestamp,
      watermark_at = p_watermark_at,
      generated_at = p_generated_at,
      row_count = p_row_count,
      checksum = p_checksum,
      destination_version = p_destination_version,
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = null
  where id = p_export_run_id
    and status = 'processing'
    and lease_token = p_lease_token
    and lease_expires_at > current_timestamp;

  if not found then
    raise exception using errcode = '40001', message = 'export_lease_conflict';
  end if;
end;
$$;

create function public.integration_fail_export_run(
  p_export_run_id uuid,
  p_lease_token uuid,
  p_error text,
  p_retry_at timestamptz
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_retry_at is null or p_retry_at <= current_timestamp then
    raise exception using errcode = '22023', message = 'retry_at_invalid';
  end if;

  update public.export_runs
  set status = 'failed',
      available_at = p_retry_at,
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = left(btrim(coalesce(p_error, 'export_failed')), 500)
  where id = p_export_run_id
    and status = 'processing'
    and lease_token = p_lease_token;

  if not found then
    raise exception using errcode = '40001', message = 'export_lease_conflict';
  end if;
end;
$$;

create function public.get_staff_integration_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('integration.private.read');

  return jsonb_build_object(
    'destinations', coalesce((
      select jsonb_agg(to_jsonb(destination) order by destination.code)
      from public.integration_destinations as destination
    ), '[]'::jsonb),
    'definitions', coalesce((
      select jsonb_agg(to_jsonb(definition) order by definition.code)
      from public.export_definitions as definition
    ), '[]'::jsonb),
    'export_runs', coalesce((
      select jsonb_agg(to_jsonb(run_view) order by run_view.created_at desc)
      from (
        select
          run.id,
          definition.code as definition_code,
          run.status,
          run.attempt_count,
          run.scheduled_for,
          run.generated_at,
          run.row_count,
          run.checksum,
          run.destination_version,
          run.last_error,
          run.created_at
        from public.export_runs as run
        join public.export_definitions as definition
          on definition.id = run.export_definition_id
        order by run.created_at desc
        limit 50
      ) as run_view
    ), '[]'::jsonb),
    'deliveries', coalesce((
      select jsonb_agg(to_jsonb(delivery_view) order by delivery_view.created_at desc)
      from (
        select
          delivery.id,
          event.event_type,
          destination.code as destination_code,
          delivery.status,
          delivery.attempt_count,
          delivery.delivered_at,
          delivery.external_message_id,
          delivery.last_error,
          delivery.created_at
        from public.integration_deliveries as delivery
        join public.outbox_events as event on event.id = delivery.outbox_event_id
        join public.integration_destinations as destination
          on destination.id = delivery.destination_id
        order by delivery.created_at desc
        limit 50
      ) as delivery_view
    ), '[]'::jsonb),
    'outbox', jsonb_build_object(
      'pending', (select count(*) from public.outbox_events where status = 'pending'),
      'processing', (select count(*) from public.outbox_events where status = 'processing'),
      'failed', (select count(*) from public.outbox_events where status = 'failed')
    ),
    'scheduler', jsonb_build_object(
      'active', coalesce((
        select job.active
        from cron.job as job
        where job.jobname = 'eec-integration-worker'
        order by job.jobid desc
        limit 1
      ), false),
      'last_run_at', (
        select run.start_time
        from cron.job_run_details as run
        join cron.job as job on job.jobid = run.jobid
        where job.jobname = 'eec-integration-worker'
        order by run.start_time desc
        limit 1
      ),
      'last_run_status', (
        select run.status
        from cron.job_run_details as run
        join cron.job as job on job.jobid = run.jobid
        where job.jobname = 'eec-integration-worker'
        order by run.start_time desc
        limit 1
      )
    ),
    'generated_at', current_timestamp
  );
end;
$$;

create function public.staff_configure_integration_destination(
  p_destination_id uuid,
  p_expected_version bigint,
  p_external_reference text,
  p_active boolean,
  p_reason text,
  p_request_id uuid
)
returns table (destination_id uuid, version bigint, active boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  next_version bigint;
begin
  perform private.set_staff_audit_context(
    'integration.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  update public.integration_destinations as destination
  set external_reference = nullif(btrim(p_external_reference), ''),
      active = p_active,
      version = destination.version + 1
  where destination.id = p_destination_id
    and destination.version = p_expected_version
  returning destination.version into next_version;

  if next_version is null then
    if exists (
      select 1 from public.integration_destinations where id = p_destination_id
    ) then
      raise exception using errcode = '40001', message = 'version_conflict';
    end if;
    raise exception using errcode = 'P0002', message = 'destination_not_found';
  end if;

  return query select p_destination_id, next_version, p_active;
end;
$$;

create function public.staff_set_export_definition_status(
  p_export_definition_id uuid,
  p_expected_version bigint,
  p_active boolean,
  p_reason text,
  p_request_id uuid
)
returns table (export_definition_id uuid, version bigint, active boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  next_version bigint;
begin
  perform private.set_staff_audit_context(
    'integration.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  update public.export_definitions as definition
  set active = p_active,
      next_run_at = case when p_active then current_timestamp else definition.next_run_at end,
      version = definition.version + 1
  where definition.id = p_export_definition_id
    and definition.version = p_expected_version
  returning definition.version into next_version;

  if next_version is null then
    if exists (
      select 1 from public.export_definitions where id = p_export_definition_id
    ) then
      raise exception using errcode = '40001', message = 'version_conflict';
    end if;
    raise exception using errcode = 'P0002', message = 'export_definition_not_found';
  end if;

  return query select p_export_definition_id, next_version, p_active;
end;
$$;

create function public.staff_queue_export_run(
  p_export_definition_id uuid,
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
  created_run_id uuid;
begin
  perform private.set_staff_audit_context(
    'integration.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  if not exists (
    select 1
    from public.export_definitions as definition
    join public.integration_destinations as destination
      on destination.id = definition.destination_id
      and destination.active
    where definition.id = p_export_definition_id
      and definition.active
  ) then
    raise exception using errcode = '22023', message = 'export_definition_inactive';
  end if;

  insert into public.export_runs (
    export_definition_id,
    run_key,
    scheduled_for
  )
  values (
    p_export_definition_id,
    'manual:' || p_request_id::text,
    current_timestamp
  )
  on conflict (run_key) do update
    set run_key = excluded.run_key
  returning id into created_run_id;

  return created_run_id;
end;
$$;

create function public.staff_replay_export_run(
  p_export_run_id uuid,
  p_reason text,
  p_request_id uuid
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform private.set_staff_audit_context(
    'integration.replay',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  update public.export_runs
  set status = 'queued',
      attempt_count = 0,
      available_at = current_timestamp,
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = null
  where id = p_export_run_id
    and status = 'failed';

  if not found then
    raise exception using errcode = '22023', message = 'export_run_not_replayable';
  end if;

  return p_export_run_id;
end;
$$;

create function public.staff_replay_integration_delivery(
  p_delivery_id uuid,
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
  event_id uuid;
begin
  perform private.set_staff_audit_context(
    'integration.replay',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  update public.integration_deliveries
  set status = 'queued',
      attempt_count = 0,
      available_at = current_timestamp,
      lease_token = null,
      lease_expires_at = null,
      worker_id = null,
      last_error = null
  where id = p_delivery_id
    and status = 'failed'
  returning outbox_event_id into event_id;

  if event_id is null then
    raise exception using errcode = '22023', message = 'delivery_not_replayable';
  end if;

  update public.outbox_events
  set status = 'pending',
      available_at = current_timestamp,
      last_error = null
  where id = event_id;

  return p_delivery_id;
end;
$$;

insert into public.integration_destinations (
  code,
  display_name,
  destination_type,
  visibility,
  active
)
values
  (
    'public-registry-sheet',
    'Public registry Google Sheet',
    'google_sheets',
    'public',
    false
  ),
  (
    'staff-alerts',
    'Private staff alerts',
    'discord_channel',
    'staff_private',
    false
  );

insert into public.export_definitions (
  code,
  display_name,
  projection_code,
  destination_id,
  sheet_tab_name,
  column_contract,
  refresh_interval_minutes,
  active
)
select
  export.code,
  export.display_name,
  export.projection_code,
  destination.id,
  export.sheet_tab_name,
  export.column_contract,
  15,
  false
from public.integration_destinations as destination
cross join (
  values
    (
      'public-catalogue',
      'Public catalogue export',
      'public_catalogue',
      'Catalogue',
      '[{"key":"item_code","label":"Item code"},{"key":"public_name","label":"Name"},{"key":"public_description","label":"Description"},{"key":"category","label":"Category"},{"key":"unit","label":"Unit"},{"key":"tags","label":"Tags"},{"key":"control_level","label":"Control"},{"key":"availability","label":"Availability"},{"key":"public_price_minor","label":"Price (minor units)"},{"key":"currency_code","label":"Currency"},{"key":"bulk_minimum","label":"Minimum order"},{"key":"order_increment","label":"Order increment"},{"key":"requirements","label":"Requirements"},{"key":"source_url","label":"Source path"},{"key":"published_at","label":"Published at"},{"key":"generated_at","label":"Generated at"}]'::jsonb
    ),
    (
      'public-dealers',
      'Public dealer registry export',
      'public_dealers',
      'Dealers',
      '[{"key":"public_reference","label":"Dealer reference"},{"key":"public_name","label":"Public name"},{"key":"dealer_type","label":"Dealer type"},{"key":"jurisdiction","label":"Jurisdiction"},{"key":"public_premises","label":"Public premises"},{"key":"status","label":"Status"},{"key":"currently_authorized","label":"Currently authorized"},{"key":"effective_from","label":"Effective from"},{"key":"effective_until","label":"Effective until"},{"key":"related_public_licenses","label":"Related public licenses"},{"key":"public_notice","label":"Public notice"},{"key":"generated_at","label":"Generated at"}]'::jsonb
    ),
    (
      'public-licenses',
      'Public license registry export',
      'public_licenses',
      'Licenses',
      '[{"key":"public_reference","label":"License reference"},{"key":"holder_name","label":"Holder"},{"key":"license_class","label":"License class"},{"key":"jurisdiction","label":"Jurisdiction"},{"key":"status","label":"Status"},{"key":"currently_authorized","label":"Currently authorized"},{"key":"effective_from","label":"Effective from"},{"key":"expires_at","label":"Expires at"},{"key":"endorsements","label":"Endorsements"},{"key":"public_conditions","label":"Public conditions"},{"key":"public_notice","label":"Public notice"},{"key":"generated_at","label":"Generated at"}]'::jsonb
    )
) as export(
  code,
  display_name,
  projection_code,
  sheet_tab_name,
  column_contract
)
where destination.code = 'public-registry-sheet';

insert into public.notification_templates (
  code,
  event_type,
  destination_type,
  message_template
)
values
  ('staff-order-submitted-v1', 'order.submitted', 'discord_channel', 'New wholesale order {{public_reference}} was submitted with {{line_count}} line(s). Pricing: {{pricing_status}}.'),
  ('staff-order-reviewed-v1', 'order.line_reviewed', 'discord_channel', 'Order line {{order_line_id}} was reviewed. Line: {{line_status}}. Order: {{order_status}}.'),
  ('staff-license-issued-v1', 'license.issued', 'discord_channel', 'License {{public_reference}} was issued with status {{status_code}}.'),
  ('staff-license-status-v1', 'license.status_changed', 'discord_channel', 'License {{license_id}} changed from {{previous_status_code}} to {{status_code}}.'),
  ('staff-reservation-created-v1', 'reservation.created', 'discord_channel', 'Reservation {{public_reference}} was created for quantity {{quantity}} and expires {{expires_at}}.'),
  ('staff-reservation-expired-v1', 'reservation.expired', 'discord_channel', 'Reservation {{reservation_id}} expired for order line {{order_line_id}}.'),
  ('staff-inventory-receipt-v1', 'inventory.receipt_posted', 'discord_channel', 'Inventory receipt {{transaction_id}} posted quantity {{quantity}} for item {{item_id}}.');

insert into public.integration_event_routes (
  event_type,
  destination_id,
  notification_template_id
)
select template.event_type, destination.id, template.id
from public.notification_templates as template
join public.integration_destinations as destination
  on destination.code = 'staff-alerts'
where template.destination_type = 'discord_channel';

revoke all on public.integration_destinations from anon, authenticated;
revoke all on public.notification_templates from anon, authenticated;
revoke all on public.integration_event_routes from anon, authenticated;
revoke all on public.integration_deliveries from anon, authenticated;
revoke all on public.export_definitions from anon, authenticated;
revoke all on public.export_runs from anon, authenticated;

revoke all on function public.get_public_catalogue_export() from public, anon, authenticated;
revoke all on function public.get_public_dealer_export() from public, anon, authenticated;
revoke all on function public.get_public_license_export() from public, anon, authenticated;
revoke all on function public.integration_claim_deliveries(text, integer, integer) from public, anon, authenticated;
revoke all on function public.integration_complete_delivery(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.integration_fail_delivery(uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.integration_queue_due_exports(timestamptz) from public, anon, authenticated;
revoke all on function public.integration_claim_export_runs(text, integer, integer) from public, anon, authenticated;
revoke all on function public.integration_complete_export_run(uuid, uuid, integer, text, text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.integration_fail_export_run(uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.get_staff_integration_workspace() from public, anon, authenticated;
revoke all on function public.staff_configure_integration_destination(uuid, bigint, text, boolean, text, uuid) from public, anon, authenticated;
revoke all on function public.staff_set_export_definition_status(uuid, bigint, boolean, text, uuid) from public, anon, authenticated;
revoke all on function public.staff_queue_export_run(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.staff_replay_export_run(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.staff_replay_integration_delivery(uuid, text, uuid) from public, anon, authenticated;

grant execute on function public.get_public_catalogue_export() to service_role;
grant execute on function public.get_public_dealer_export() to service_role;
grant execute on function public.get_public_license_export() to service_role;
grant execute on function public.integration_claim_deliveries(text, integer, integer) to service_role;
grant execute on function public.integration_complete_delivery(uuid, uuid, text) to service_role;
grant execute on function public.integration_fail_delivery(uuid, uuid, text, timestamptz) to service_role;
grant execute on function public.integration_queue_due_exports(timestamptz) to service_role;
grant execute on function public.integration_claim_export_runs(text, integer, integer) to service_role;
grant execute on function public.integration_complete_export_run(uuid, uuid, integer, text, text, timestamptz, timestamptz) to service_role;
grant execute on function public.integration_fail_export_run(uuid, uuid, text, timestamptz) to service_role;

grant execute on function public.get_staff_integration_workspace() to authenticated;
grant execute on function public.staff_configure_integration_destination(uuid, bigint, text, boolean, text, uuid) to authenticated;
grant execute on function public.staff_set_export_definition_status(uuid, bigint, boolean, text, uuid) to authenticated;
grant execute on function public.staff_queue_export_run(uuid, text, uuid) to authenticated;
grant execute on function public.staff_replay_export_run(uuid, text, uuid) to authenticated;
grant execute on function public.staff_replay_integration_delivery(uuid, text, uuid) to authenticated;

revoke all on function private.refresh_outbox_delivery_status(uuid) from public, anon, authenticated;
revoke all on function private.materialize_integration_deliveries() from public, anon, authenticated;
revoke all on function private.invoke_integration_worker() from public, anon, authenticated, service_role;
