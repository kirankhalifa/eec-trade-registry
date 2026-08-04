create table public.actor_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete restrict,
  display_name text not null check (btrim(display_name) <> ''),
  actor_type text not null default 'staff' check (actor_type in ('staff')),
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.permission_scopes (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null check (btrim(description) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.staff_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_-]{2,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null check (btrim(description) <> ''),
  is_assignable boolean not null default true,
  is_elevated boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.staff_role_permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  staff_role_id uuid not null references public.staff_roles(id) on delete cascade,
  permission_scope_id uuid not null references public.permission_scopes(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (staff_role_id, permission_scope_id)
);

create table public.staff_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  staff_role_id uuid not null references public.staff_roles(id) on delete restrict,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  revoked_at timestamptz,
  assignment_scope jsonb not null default '{}'::jsonb
    check (jsonb_typeof(assignment_scope) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  check (revoked_at is null or revoked_at >= effective_from),
  unique (actor_id, staff_role_id, effective_from),
  exclude using gist (
    actor_id with =,
    staff_role_id with =,
    tstzrange(effective_from, coalesce(effective_until, 'infinity'::timestamptz), '[)') with &&
  ) where (revoked_at is null)
);

comment on table public.actor_profiles is
  'Application actors linked to Supabase Auth. Authentication alone grants no business authority.';
comment on table public.staff_assignments is
  'Effective-dated staff authority. Empty assignment_scope means global only for permissions whose policy supports global scope.';

alter table public.items
  add column version bigint not null default 1 check (version > 0);

alter table public.audit_log rename column actor_id to auth_user_id;
alter table public.audit_log
  add column actor_id uuid references public.actor_profiles(id),
  add column permission_code text,
  add column staff_assignment_id uuid references public.staff_assignments(id),
  add column correlation_id uuid;

create index actor_profiles_auth_user_idx on public.actor_profiles(auth_user_id);
create index staff_assignments_actor_idx
  on public.staff_assignments(actor_id, effective_from, effective_until)
  where revoked_at is null;
create index staff_role_permissions_role_idx
  on public.staff_role_permissions(staff_role_id, permission_scope_id);

create trigger actor_profiles_set_updated_at before update on public.actor_profiles
for each row execute function private.set_updated_at();
create trigger permission_scopes_set_updated_at before update on public.permission_scopes
for each row execute function private.set_updated_at();
create trigger staff_roles_set_updated_at before update on public.staff_roles
for each row execute function private.set_updated_at();
create trigger staff_assignments_set_updated_at before update on public.staff_assignments
for each row execute function private.set_updated_at();

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
  resolved_request_id := nullif(current_setting('app.request_id', true), '')::uuid;
  resolved_correlation_id := nullif(current_setting('app.correlation_id', true), '')::uuid;

  insert into public.audit_log (
    auth_user_id,
    actor_id,
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

create trigger actor_profiles_audit after insert or update or delete on public.actor_profiles
for each row execute function private.capture_audit_row();
create trigger permission_scopes_audit after insert or update or delete on public.permission_scopes
for each row execute function private.capture_audit_row();
create trigger staff_roles_audit after insert or update or delete on public.staff_roles
for each row execute function private.capture_audit_row();
create trigger staff_role_permissions_audit after insert or update or delete on public.staff_role_permissions
for each row execute function private.capture_audit_row();
create trigger staff_assignments_audit after insert or update or delete on public.staff_assignments
for each row execute function private.capture_audit_row();

alter table public.actor_profiles enable row level security;
alter table public.permission_scopes enable row level security;
alter table public.staff_roles enable row level security;
alter table public.staff_role_permissions enable row level security;
alter table public.staff_assignments enable row level security;

insert into public.permission_scopes (code, display_name, description)
values
  (
    'catalogue.private.read',
    'Read internal catalogue',
    'View the internal catalogue work queue and non-public catalogue fields.'
  ),
  (
    'catalogue.manage',
    'Manage catalogue drafts',
    'Create, edit, archive, and restore canonical catalogue records through secure commands.'
  );

insert into public.staff_roles (code, display_name, description)
values (
  'catalogue_manager',
  'Catalogue manager',
  'Initial configurable role for internal catalogue maintenance. Pricing and publication authority are not included.'
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'catalogue_manager'
  and permission.code in ('catalogue.private.read', 'catalogue.manage');

create function private.require_staff_permission(p_permission_code text)
returns table (
  actor_id uuid,
  staff_assignment_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'staff_authentication_required';
  end if;

  return query
  select
    actor.id,
    assignment.id
  from public.actor_profiles as actor
  join public.staff_assignments as assignment
    on assignment.actor_id = actor.id
    and assignment.revoked_at is null
    and assignment.effective_from <= statement_timestamp()
    and (
      assignment.effective_until is null
      or assignment.effective_until > statement_timestamp()
    )
  join public.staff_roles as role
    on role.id = assignment.staff_role_id
    and role.active
  join public.staff_role_permissions as role_permission
    on role_permission.staff_role_id = role.id
  join public.permission_scopes as permission
    on permission.id = role_permission.permission_scope_id
    and permission.active
    and permission.code = p_permission_code
  where actor.auth_user_id = auth.uid()
    and actor.actor_type = 'staff'
    and actor.status = 'active'
  order by assignment.effective_from, assignment.id
  limit 1;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'staff_permission_denied';
  end if;
end;
$$;

create function private.set_staff_audit_context(
  p_permission_code text,
  p_reason text,
  p_request_id uuid,
  p_source_surface text default 'staff_portal'
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
    raise exception using
      errcode = '22023',
      message = 'reason_required';
  end if;

  if p_request_id is null then
    raise exception using
      errcode = '22023',
      message = 'request_id_required';
  end if;

  select * into strict permission_grant
  from private.require_staff_permission(p_permission_code);

  perform set_config('app.actor_id', permission_grant.actor_id::text, true);
  perform set_config(
    'app.staff_assignment_id',
    permission_grant.staff_assignment_id::text,
    true
  );
  perform set_config('app.permission_code', p_permission_code, true);
  perform set_config('app.audit_reason', normalized_reason, true);
  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.correlation_id', p_request_id::text, true);
  perform set_config(
    'app.source_surface',
    coalesce(nullif(btrim(p_source_surface), ''), 'staff_portal'),
    true
  );

  return permission_grant.actor_id;
end;
$$;

create function public.get_staff_catalogue_items(p_search text default null)
returns table (
  id uuid,
  item_code text,
  slug text,
  display_name text,
  description text,
  internal_notes text,
  category_code text,
  category_name text,
  unit_code text,
  unit_name text,
  inventory_mode text,
  status text,
  version bigint,
  publication_status text,
  public_name text,
  price_amount_minor bigint,
  currency_code text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('catalogue.private.read');

  return query
  select
    item.id,
    item.item_code,
    item.slug,
    item.display_name,
    item.description,
    item.internal_notes,
    category.code,
    category.display_name,
    unit.code,
    unit.display_name,
    item.inventory_mode,
    item.status,
    item.version,
    publication.publication_status,
    publication.public_name,
    price.amount_minor,
    price.currency_code,
    item.updated_at
  from public.items as item
  join public.item_categories as category on category.id = item.category_id
  join public.units_of_measure as unit on unit.id = item.unit_id
  left join lateral (
    select candidate.publication_status, candidate.public_name
    from public.item_publications as candidate
    where candidate.item_id = item.id
      and candidate.audience_code = 'public'
      and candidate.effective_from <= statement_timestamp()
      and (
        candidate.effective_until is null
        or candidate.effective_until > statement_timestamp()
      )
    order by
      case candidate.publication_status
        when 'published' then 0
        when 'draft' then 1
        else 2
      end,
      candidate.effective_from desc
    limit 1
  ) as publication on true
  left join lateral (
    select rule.amount_minor, currency.code as currency_code
    from public.price_rules as rule
    join public.price_schedules as schedule
      on schedule.id = rule.price_schedule_id
      and schedule.status = 'active'
      and schedule.audience_code = 'public'
      and schedule.effective_from <= statement_timestamp()
      and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
    join public.currencies as currency on currency.id = schedule.currency_id
    where rule.item_id = item.id
      and rule.effective_from <= statement_timestamp()
      and (rule.effective_until is null or rule.effective_until > statement_timestamp())
    order by schedule.priority desc, rule.effective_from desc, rule.approved_at desc
    limit 1
  ) as price on true
  where p_search is null
    or btrim(p_search) = ''
    or item.item_code ilike '%' || btrim(p_search) || '%'
    or item.display_name ilike '%' || btrim(p_search) || '%'
    or item.slug ilike '%' || btrim(p_search) || '%'
  order by
    case item.status when 'active' then 0 else 1 end,
    category.sort_order,
    item.display_name,
    item.item_code;
end;
$$;

create function public.get_staff_catalogue_item(p_item_id uuid)
returns table (
  id uuid,
  item_code text,
  slug text,
  display_name text,
  description text,
  internal_notes text,
  category_code text,
  category_name text,
  unit_code text,
  unit_name text,
  inventory_mode text,
  status text,
  version bigint,
  publication_status text,
  public_name text,
  price_amount_minor bigint,
  currency_code text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select catalogue.*
  from public.get_staff_catalogue_items(null) as catalogue
  where catalogue.id = p_item_id
  limit 1;
$$;

create function public.get_staff_catalogue_reference_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform 1 from private.require_staff_permission('catalogue.private.read');

  select jsonb_build_object(
    'categories', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', category.code, 'display_name', category.display_name)
          order by category.sort_order, category.display_name
        )
        from public.item_categories as category
        where category.active
      ),
      '[]'::jsonb
    ),
    'units', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('code', unit.code, 'display_name', unit.display_name)
          order by unit.display_name
        )
        from public.units_of_measure as unit
        where unit.active
      ),
      '[]'::jsonb
    )
  ) into result;

  return result;
end;
$$;

create function public.staff_create_catalogue_item(
  p_item_code text,
  p_slug text,
  p_display_name text,
  p_description text,
  p_category_code text,
  p_unit_code text,
  p_inventory_mode text,
  p_internal_notes text,
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
  resolved_category_id uuid;
  resolved_unit_id uuid;
  created_id uuid;
  created_version bigint;
begin
  perform private.set_staff_audit_context(
    'catalogue.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select category.id into resolved_category_id
  from public.item_categories as category
  where category.code = lower(btrim(p_category_code))
    and category.active;
  if resolved_category_id is null then
    raise exception using errcode = '22023', message = 'invalid_category';
  end if;

  select unit.id into resolved_unit_id
  from public.units_of_measure as unit
  where unit.code = lower(btrim(p_unit_code))
    and unit.active;
  if resolved_unit_id is null then
    raise exception using errcode = '22023', message = 'invalid_unit';
  end if;

  if p_inventory_mode not in ('fungible', 'serialized') then
    raise exception using errcode = '22023', message = 'invalid_inventory_mode';
  end if;

  insert into public.items (
    item_code,
    slug,
    display_name,
    description,
    category_id,
    unit_id,
    inventory_mode,
    internal_notes
  ) values (
    upper(btrim(p_item_code)),
    lower(btrim(p_slug)),
    btrim(p_display_name),
    btrim(coalesce(p_description, '')),
    resolved_category_id,
    resolved_unit_id,
    p_inventory_mode,
    btrim(coalesce(p_internal_notes, ''))
  )
  returning public.items.id, public.items.version
  into created_id, created_version;

  return query select created_id, created_version;
end;
$$;

create function public.staff_update_catalogue_item(
  p_item_id uuid,
  p_expected_version bigint,
  p_display_name text,
  p_description text,
  p_category_code text,
  p_unit_code text,
  p_inventory_mode text,
  p_internal_notes text,
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
  current_version bigint;
  resolved_category_id uuid;
  resolved_unit_id uuid;
  updated_version bigint;
begin
  perform private.set_staff_audit_context(
    'catalogue.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  select item.version into current_version
  from public.items as item
  where item.id = p_item_id
  for update;
  if current_version is null then
    raise exception using errcode = 'P0002', message = 'catalogue_item_not_found';
  end if;
  if current_version <> p_expected_version then
    raise exception using errcode = '40001', message = 'catalogue_version_conflict';
  end if;

  select category.id into resolved_category_id
  from public.item_categories as category
  where category.code = lower(btrim(p_category_code))
    and category.active;
  if resolved_category_id is null then
    raise exception using errcode = '22023', message = 'invalid_category';
  end if;

  select unit.id into resolved_unit_id
  from public.units_of_measure as unit
  where unit.code = lower(btrim(p_unit_code))
    and unit.active;
  if resolved_unit_id is null then
    raise exception using errcode = '22023', message = 'invalid_unit';
  end if;

  if p_inventory_mode not in ('fungible', 'serialized') then
    raise exception using errcode = '22023', message = 'invalid_inventory_mode';
  end if;

  update public.items as item
  set
    display_name = btrim(p_display_name),
    description = btrim(coalesce(p_description, '')),
    category_id = resolved_category_id,
    unit_id = resolved_unit_id,
    inventory_mode = p_inventory_mode,
    internal_notes = btrim(coalesce(p_internal_notes, '')),
    version = item.version + 1
  where item.id = p_item_id
  returning item.version into updated_version;

  return query select p_item_id, updated_version;
end;
$$;

create function public.staff_set_catalogue_item_status(
  p_item_id uuid,
  p_expected_version bigint,
  p_status text,
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
  current_version bigint;
  current_status text;
  updated_version bigint;
begin
  perform private.set_staff_audit_context(
    'catalogue.manage',
    p_reason,
    p_request_id,
    'staff_portal'
  );

  if p_status not in ('active', 'archived') then
    raise exception using errcode = '22023', message = 'invalid_catalogue_status';
  end if;

  select item.version, item.status
  into current_version, current_status
  from public.items as item
  where item.id = p_item_id
  for update;
  if current_version is null then
    raise exception using errcode = 'P0002', message = 'catalogue_item_not_found';
  end if;
  if current_version <> p_expected_version then
    raise exception using errcode = '40001', message = 'catalogue_version_conflict';
  end if;
  if current_status = p_status then
    raise exception using errcode = '22023', message = 'catalogue_status_unchanged';
  end if;

  update public.items as item
  set status = p_status, version = item.version + 1
  where item.id = p_item_id
  returning item.version into updated_version;

  return query select p_item_id, updated_version, p_status;
end;
$$;

revoke all on public.actor_profiles from anon, authenticated;
revoke all on public.permission_scopes from anon, authenticated;
revoke all on public.staff_roles from anon, authenticated;
revoke all on public.staff_role_permissions from anon, authenticated;
revoke all on public.staff_assignments from anon, authenticated;

revoke all on function private.require_staff_permission(text) from public, anon, authenticated;
revoke all on function private.set_staff_audit_context(text, text, uuid, text)
  from public, anon, authenticated;

revoke execute on function public.get_staff_catalogue_items(text) from public, anon;
revoke execute on function public.get_staff_catalogue_item(uuid) from public, anon;
revoke execute on function public.get_staff_catalogue_reference_data() from public, anon;
revoke execute on function public.staff_create_catalogue_item(
  text, text, text, text, text, text, text, text, text, uuid
) from public, anon;
revoke execute on function public.staff_update_catalogue_item(
  uuid, bigint, text, text, text, text, text, text, text, uuid
) from public, anon;
revoke execute on function public.staff_set_catalogue_item_status(
  uuid, bigint, text, text, uuid
) from public, anon;

grant execute on function public.get_staff_catalogue_items(text) to authenticated;
grant execute on function public.get_staff_catalogue_item(uuid) to authenticated;
grant execute on function public.get_staff_catalogue_reference_data() to authenticated;
grant execute on function public.staff_create_catalogue_item(
  text, text, text, text, text, text, text, text, text, uuid
) to authenticated;
grant execute on function public.staff_update_catalogue_item(
  uuid, bigint, text, text, text, text, text, text, text, uuid
) to authenticated;
grant execute on function public.staff_set_catalogue_item_status(
  uuid, bigint, text, text, uuid
) to authenticated;
