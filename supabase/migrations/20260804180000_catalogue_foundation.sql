create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.currencies (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9_]{2,12}$'),
  display_name text not null check (btrim(display_name) <> ''),
  symbol text not null check (btrim(symbol) <> ''),
  symbol_position text not null check (symbol_position in ('prefix', 'suffix')),
  minor_unit_scale smallint not null default 0 check (minor_unit_scale between 0 and 6),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.units_of_measure (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  symbol text,
  quantity_scale smallint not null default 0 check (quantity_scale between 0 and 6),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.item_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.item_tags (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.control_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_description text not null check (btrim(public_description) <> ''),
  requires_staff_review boolean not null default false,
  requires_transaction_approval boolean not null default false,
  requires_serial_tracking boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.availability_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_description text not null check (btrim(public_description) <> ''),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.items (
  id uuid primary key default extensions.gen_random_uuid(),
  item_code text not null unique check (item_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,79}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  category_id uuid not null references public.item_categories(id),
  unit_id uuid not null references public.units_of_measure(id),
  inventory_mode text not null check (inventory_mode in ('fungible', 'serialized')),
  status text not null default 'active' check (status in ('active', 'archived')),
  internal_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.item_tag_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  tag_id uuid not null references public.item_tags(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (item_id, tag_id)
);

create table public.item_publications (
  id uuid primary key default extensions.gen_random_uuid(),
  item_id uuid not null references public.items(id),
  audience_code text not null check (audience_code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  publication_status text not null default 'draft'
    check (publication_status in ('draft', 'published', 'withdrawn')),
  public_name text not null check (btrim(public_name) <> ''),
  public_description text not null check (btrim(public_description) <> ''),
  control_profile_id uuid not null references public.control_profiles(id),
  availability_profile_id uuid not null references public.availability_profiles(id),
  requirement_summary text not null check (btrim(requirement_summary) <> ''),
  bulk_minimum numeric(18, 3) check (bulk_minimum is null or bulk_minimum > 0),
  order_increment numeric(18, 3) not null default 1 check (order_increment > 0),
  media_url text,
  effective_from timestamptz not null,
  effective_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  unique (item_id, audience_code, effective_from),
  exclude using gist (
    item_id with =,
    audience_code with =,
    tstzrange(effective_from, coalesce(effective_until, 'infinity'::timestamptz), '[)') with &&
  ) where (publication_status = 'published')
);

create table public.price_schedules (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  audience_code text not null check (audience_code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  currency_id uuid not null references public.currencies(id),
  priority integer not null default 0,
  status text not null default 'active' check (status in ('draft', 'active', 'retired')),
  effective_from timestamptz not null,
  effective_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from)
);

create table public.price_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  price_schedule_id uuid not null references public.price_schedules(id),
  item_id uuid not null references public.items(id),
  amount_minor bigint not null check (amount_minor >= 0),
  effective_from timestamptz not null,
  effective_until timestamptz,
  approved_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  unique (price_schedule_id, item_id, effective_from),
  exclude using gist (
    price_schedule_id with =,
    item_id with =,
    tstzrange(effective_from, coalesce(effective_until, 'infinity'::timestamptz), '[)') with &&
  )
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  record_type text not null,
  record_id uuid not null,
  previous_state jsonb,
  new_state jsonb,
  occurred_at timestamptz not null default now(),
  reason text,
  request_id uuid,
  source_surface text not null default 'database'
);

comment on table public.audit_log is
  'Append-only audit evidence. Writes occur only through trusted trigger functions.';
comment on column public.items.internal_notes is
  'Internal-only catalogue notes. This column must never appear in a public projection.';

create index items_category_id_idx on public.items(category_id);
create index items_status_idx on public.items(status);
create index item_publications_lookup_idx
  on public.item_publications(item_id, audience_code, publication_status, effective_from);
create index price_rules_lookup_idx
  on public.price_rules(item_id, price_schedule_id, effective_from);
create index item_tag_assignments_item_id_idx on public.item_tag_assignments(item_id);
create index audit_log_record_idx on public.audit_log(record_type, record_id, occurred_at desc);

create function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

create function private.capture_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_row jsonb;
  current_row jsonb;
  affected_id uuid;
begin
  previous_row := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  current_row := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  affected_id := coalesce(
    nullif(current_row ->> 'id', '')::uuid,
    nullif(previous_row ->> 'id', '')::uuid
  );

  insert into public.audit_log (
    actor_id,
    action,
    record_type,
    record_id,
    previous_state,
    new_state
  )
  values (
    auth.uid(),
    lower(tg_op),
    format('%I.%I', tg_table_schema, tg_table_name),
    affected_id,
    previous_row,
    current_row
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger currencies_set_updated_at before update on public.currencies
for each row execute function private.set_updated_at();
create trigger units_set_updated_at before update on public.units_of_measure
for each row execute function private.set_updated_at();
create trigger categories_set_updated_at before update on public.item_categories
for each row execute function private.set_updated_at();
create trigger tags_set_updated_at before update on public.item_tags
for each row execute function private.set_updated_at();
create trigger controls_set_updated_at before update on public.control_profiles
for each row execute function private.set_updated_at();
create trigger availability_set_updated_at before update on public.availability_profiles
for each row execute function private.set_updated_at();
create trigger items_set_updated_at before update on public.items
for each row execute function private.set_updated_at();
create trigger publications_set_updated_at before update on public.item_publications
for each row execute function private.set_updated_at();
create trigger price_schedules_set_updated_at before update on public.price_schedules
for each row execute function private.set_updated_at();
create trigger price_rules_set_updated_at before update on public.price_rules
for each row execute function private.set_updated_at();

create trigger currencies_audit after insert or update or delete on public.currencies
for each row execute function private.capture_audit_row();
create trigger units_audit after insert or update or delete on public.units_of_measure
for each row execute function private.capture_audit_row();
create trigger categories_audit after insert or update or delete on public.item_categories
for each row execute function private.capture_audit_row();
create trigger tags_audit after insert or update or delete on public.item_tags
for each row execute function private.capture_audit_row();
create trigger controls_audit after insert or update or delete on public.control_profiles
for each row execute function private.capture_audit_row();
create trigger availability_audit after insert or update or delete on public.availability_profiles
for each row execute function private.capture_audit_row();
create trigger items_audit after insert or update or delete on public.items
for each row execute function private.capture_audit_row();
create trigger item_tag_assignments_audit after insert or update or delete on public.item_tag_assignments
for each row execute function private.capture_audit_row();
create trigger publications_audit after insert or update or delete on public.item_publications
for each row execute function private.capture_audit_row();
create trigger price_schedules_audit after insert or update or delete on public.price_schedules
for each row execute function private.capture_audit_row();
create trigger price_rules_audit after insert or update or delete on public.price_rules
for each row execute function private.capture_audit_row();

alter table public.currencies enable row level security;
alter table public.units_of_measure enable row level security;
alter table public.item_categories enable row level security;
alter table public.item_tags enable row level security;
alter table public.control_profiles enable row level security;
alter table public.availability_profiles enable row level security;
alter table public.items enable row level security;
alter table public.item_tag_assignments enable row level security;
alter table public.item_publications enable row level security;
alter table public.price_schedules enable row level security;
alter table public.price_rules enable row level security;
alter table public.audit_log enable row level security;

create function public.get_public_catalogue(
  p_search text default null,
  p_category_code text default null
)
returns table (
  item_code text,
  slug text,
  display_name text,
  description text,
  category_code text,
  category_name text,
  unit_code text,
  unit_name text,
  unit_symbol text,
  tags text[],
  control_code text,
  control_label text,
  control_description text,
  availability_code text,
  availability_label text,
  availability_description text,
  price_amount_minor bigint,
  currency_code text,
  currency_symbol text,
  currency_symbol_position text,
  minor_unit_scale smallint,
  bulk_minimum numeric,
  order_increment numeric,
  requirement_summary text,
  published_at timestamptz,
  generated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    i.item_code,
    i.slug,
    publication.public_name,
    publication.public_description,
    category.code,
    category.display_name,
    unit.code,
    unit.display_name,
    unit.symbol,
    coalesce(tag_list.tags, array[]::text[]),
    control.code,
    control.display_name,
    control.public_description,
    availability.code,
    availability.display_name,
    availability.public_description,
    price.amount_minor,
    price.currency_code,
    price.currency_symbol,
    price.currency_symbol_position,
    price.minor_unit_scale,
    publication.bulk_minimum,
    publication.order_increment,
    publication.requirement_summary,
    publication.effective_from,
    current_timestamp
  from public.items as i
  join public.item_categories as category
    on category.id = i.category_id
    and category.active
  join public.units_of_measure as unit
    on unit.id = i.unit_id
    and unit.active
  join lateral (
    select p.*
    from public.item_publications as p
    where p.item_id = i.id
      and p.audience_code = 'public'
      and p.publication_status = 'published'
      and p.effective_from <= current_timestamp
      and (p.effective_until is null or p.effective_until > current_timestamp)
    order by p.effective_from desc
    limit 1
  ) as publication on true
  join public.control_profiles as control
    on control.id = publication.control_profile_id
    and control.active
  join public.availability_profiles as availability
    on availability.id = publication.availability_profile_id
    and availability.active
  left join lateral (
    select array_agg(tag.display_name order by tag.display_name) as tags
    from public.item_tag_assignments as assignment
    join public.item_tags as tag
      on tag.id = assignment.tag_id
      and tag.active
    where assignment.item_id = i.id
  ) as tag_list on true
  left join lateral (
    select
      rule.amount_minor,
      currency.code as currency_code,
      currency.symbol as currency_symbol,
      currency.symbol_position as currency_symbol_position,
      currency.minor_unit_scale
    from public.price_rules as rule
    join public.price_schedules as schedule
      on schedule.id = rule.price_schedule_id
      and schedule.status = 'active'
      and schedule.audience_code = 'public'
      and schedule.effective_from <= current_timestamp
      and (schedule.effective_until is null or schedule.effective_until > current_timestamp)
    join public.currencies as currency
      on currency.id = schedule.currency_id
      and currency.active
    where rule.item_id = i.id
      and rule.effective_from <= current_timestamp
      and (rule.effective_until is null or rule.effective_until > current_timestamp)
    order by schedule.priority desc, rule.effective_from desc, rule.approved_at desc, schedule.code
    limit 1
  ) as price on true
  where i.status = 'active'
    and (
      p_category_code is null
      or btrim(p_category_code) = ''
      or category.code = lower(btrim(p_category_code))
    )
    and (
      p_search is null
      or btrim(p_search) = ''
      or publication.public_name ilike '%' || btrim(p_search) || '%'
      or publication.public_description ilike '%' || btrim(p_search) || '%'
      or i.item_code ilike '%' || btrim(p_search) || '%'
      or exists (
        select 1
        from public.item_tag_assignments as search_assignment
        join public.item_tags as search_tag
          on search_tag.id = search_assignment.tag_id
          and search_tag.active
        where search_assignment.item_id = i.id
          and search_tag.display_name ilike '%' || btrim(p_search) || '%'
      )
    )
  order by category.sort_order, publication.public_name, i.item_code;
$$;

create function public.get_public_catalogue_categories()
returns table (
  code text,
  display_name text,
  item_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    category.code,
    category.display_name,
    count(distinct i.id)
  from public.item_categories as category
  join public.items as i
    on i.category_id = category.id
    and i.status = 'active'
  join public.item_publications as publication
    on publication.item_id = i.id
    and publication.audience_code = 'public'
    and publication.publication_status = 'published'
    and publication.effective_from <= current_timestamp
    and (publication.effective_until is null or publication.effective_until > current_timestamp)
  where category.active
  group by category.id, category.code, category.display_name, category.sort_order
  order by category.sort_order, category.display_name;
$$;

create function public.get_public_catalogue_item(p_slug text)
returns table (
  item_code text,
  slug text,
  display_name text,
  description text,
  category_code text,
  category_name text,
  unit_code text,
  unit_name text,
  unit_symbol text,
  tags text[],
  control_code text,
  control_label text,
  control_description text,
  availability_code text,
  availability_label text,
  availability_description text,
  price_amount_minor bigint,
  currency_code text,
  currency_symbol text,
  currency_symbol_position text,
  minor_unit_scale smallint,
  bulk_minimum numeric,
  order_increment numeric,
  requirement_summary text,
  published_at timestamptz,
  generated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select catalogue.*
  from public.get_public_catalogue(null, null) as catalogue
  where catalogue.slug = p_slug
  limit 1;
$$;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public;

grant usage on schema public to anon, authenticated;
grant execute on function public.get_public_catalogue(text, text) to anon, authenticated;
grant execute on function public.get_public_catalogue_categories() to anon, authenticated;
grant execute on function public.get_public_catalogue_item(text) to anon, authenticated;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public;

revoke all on function private.set_updated_at() from public, anon, authenticated;
revoke all on function private.capture_audit_row() from public, anon, authenticated;
