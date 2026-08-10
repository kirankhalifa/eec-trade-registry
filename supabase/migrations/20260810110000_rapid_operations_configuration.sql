insert into public.permission_scopes (code, display_name, description)
values
  (
    'configuration.read',
    'Read platform configuration',
    'View configurable catalogue, licensing, publication, pricing, and warehouse reference data.'
  ),
  (
    'configuration.manage',
    'Manage platform configuration',
    'Create and update configurable reference records through audited commands.'
  ),
  (
    'publication.manage',
    'Manage catalogue publication',
    'Publish, replace, or withdraw effective-dated public catalogue presentations.'
  ),
  (
    'pricing.manage',
    'Manage catalogue prices',
    'Set, replace, or clear effective-dated prices on an explicit configured schedule.'
  )
on conflict (code) do update set
  display_name = excluded.display_name,
  description = excluded.description,
  active = true;

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where (
  role.code = 'platform_administrator'
  and permission.code in ('configuration.read', 'configuration.manage')
) or (
  role.code = 'catalogue_manager'
  and permission.code in ('configuration.read', 'publication.manage', 'pricing.manage')
)
on conflict (staff_role_id, permission_scope_id) do nothing;

alter table public.units_of_measure
  add column version bigint not null default 1 check (version > 0);
alter table public.item_categories
  add column version bigint not null default 1 check (version > 0);
alter table public.control_profiles
  add column version bigint not null default 1 check (version > 0);
alter table public.availability_profiles
  add column version bigint not null default 1 check (version > 0);
alter table public.license_classes
  add column version bigint not null default 1 check (version > 0);
alter table public.endorsement_definitions
  add column version bigint not null default 1 check (version > 0);

create table public.staff_command_receipts (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null unique,
  operation_code text not null check (operation_code ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  result_id uuid,
  result_version bigint,
  result jsonb not null default '{}'::jsonb check (jsonb_typeof(result) = 'object'),
  actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

comment on table public.staff_command_receipts is
  'Idempotency receipts for audited staff configuration commands. They are not business-state projections.';

create trigger staff_command_receipts_audit
after insert or update or delete on public.staff_command_receipts
for each row execute function private.capture_audit_row();

alter table public.staff_command_receipts enable row level security;

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values ('catalogue_item', 'ITM', 1001, 4)
on conflict (document_type) do nothing;

create function private.current_staff_has_permission(p_permission_code text)
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
    join public.staff_roles as role
      on role.id = assignment.staff_role_id and role.active
    join public.staff_role_permissions as role_permission
      on role_permission.staff_role_id = role.id
    join public.permission_scopes as permission
      on permission.id = role_permission.permission_scope_id
      and permission.active
      and permission.code = p_permission_code
    where actor.auth_user_id = auth.uid()
      and actor.actor_type = 'staff'
      and actor.status = 'active'
  );
$$;

create function private.allocate_catalogue_item_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  sequence_record record;
  allocated text;
begin
  select reference.id, reference.prefix, reference.next_value, reference.padding
  into sequence_record
  from public.reference_sequences as reference
  where reference.document_type = 'catalogue_item'
  for update;
  if not found then
    raise exception using errcode = '55000', message = 'catalogue_item_sequence_missing';
  end if;

  allocated := sequence_record.prefix || '-' ||
    lpad(sequence_record.next_value::text, sequence_record.padding, '0');
  update public.reference_sequences as reference
  set next_value = reference.next_value + 1
  where reference.id = sequence_record.id;
  return allocated;
end;
$$;

create function public.get_staff_configuration_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('configuration.read');

  return jsonb_build_object(
    'generated_at', statement_timestamp(),
    'capabilities', jsonb_build_object(
      'can_manage_configuration', private.current_staff_has_permission('configuration.manage'),
      'can_manage_catalogue', private.current_staff_has_permission('catalogue.manage'),
      'can_manage_publication', private.current_staff_has_permission('publication.manage'),
      'can_manage_pricing', private.current_staff_has_permission('pricing.manage'),
      'can_manage_supply_policy', private.current_staff_has_permission('procurement.policy.manage'),
      'can_post_receipts', private.current_staff_has_permission('inventory.receipt.post')
    ),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', category.id, 'code', category.code, 'display_name', category.display_name,
        'description', category.description, 'sort_order', category.sort_order,
        'active', category.active, 'version', category.version
      ) order by category.sort_order, category.display_name)
      from public.item_categories as category
    ), '[]'::jsonb),
    'units', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', unit.id, 'code', unit.code, 'display_name', unit.display_name,
        'symbol', unit.symbol, 'quantity_scale', unit.quantity_scale,
        'active', unit.active, 'version', unit.version
      ) order by unit.display_name)
      from public.units_of_measure as unit
    ), '[]'::jsonb),
    'control_profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', control.id, 'code', control.code, 'display_name', control.display_name,
        'public_description', control.public_description,
        'requires_staff_review', control.requires_staff_review,
        'requires_transaction_approval', control.requires_transaction_approval,
        'requires_serial_tracking', control.requires_serial_tracking,
        'active', control.active, 'version', control.version
      ) order by control.display_name)
      from public.control_profiles as control
    ), '[]'::jsonb),
    'availability_profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', availability.id, 'code', availability.code,
        'display_name', availability.display_name,
        'public_description', availability.public_description,
        'sort_order', availability.sort_order, 'active', availability.active,
        'version', availability.version
      ) order by availability.sort_order, availability.display_name)
      from public.availability_profiles as availability
    ), '[]'::jsonb),
    'license_classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', class.id, 'code', class.code, 'display_name', class.display_name,
        'public_display_name', class.public_display_name, 'description', class.description,
        'active', class.active, 'version', class.version
      ) order by class.display_name)
      from public.license_classes as class
    ), '[]'::jsonb),
    'endorsements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', endorsement.id, 'code', endorsement.code,
        'display_name', endorsement.display_name,
        'public_display_name', endorsement.public_display_name,
        'description', endorsement.description, 'active', endorsement.active,
        'version', endorsement.version
      ) order by endorsement.display_name)
      from public.endorsement_definitions as endorsement
    ), '[]'::jsonb),
    'price_schedules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', schedule.id, 'code', schedule.code, 'display_name', schedule.display_name,
        'audience_code', schedule.audience_code, 'currency_code', currency.code,
        'priority', schedule.priority
      ) order by schedule.audience_code, schedule.priority desc, schedule.display_name)
      from public.price_schedules as schedule
      join public.currencies as currency on currency.id = schedule.currency_id
      where schedule.status = 'active'
        and schedule.effective_from <= statement_timestamp()
        and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
    ), '[]'::jsonb),
    'warehouses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', warehouse.id, 'code', warehouse.code, 'display_name', warehouse.display_name,
        'locations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', location.id, 'code', location.code,
            'display_name', location.display_name, 'location_type', location.location_type
          ) order by location.display_name)
          from public.stock_locations as location
          where location.warehouse_id = warehouse.id and location.active
        ), '[]'::jsonb)
      ) order by warehouse.display_name)
      from public.warehouses as warehouse
      where warehouse.status = 'active'
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id, 'item_code', item.item_code, 'slug', item.slug,
        'display_name', item.display_name, 'description', item.description,
        'category_code', category.code, 'unit_code', unit.code,
        'inventory_mode', item.inventory_mode, 'status', item.status,
        'publication_status', publication.publication_status,
        'public_name', publication.public_name,
        'public_description', publication.public_description,
        'control_profile_code', publication.control_profile_code,
        'availability_profile_code', publication.availability_profile_code,
        'requirement_summary', publication.requirement_summary,
        'bulk_minimum', publication.bulk_minimum,
        'order_increment', publication.order_increment,
        'supply_mode', policy.supply_mode,
        'procurement_enabled', coalesce(policy.procurement_enabled, false),
        'admin_receipt_allowed', coalesce(policy.admin_receipt_allowed, true),
        'price_schedule_id', price.price_schedule_id,
        'price_amount_minor', price.amount_minor,
        'currency_code', price.currency_code
      ) order by item.display_name, item.item_code)
      from public.items as item
      join public.item_categories as category on category.id = item.category_id
      join public.units_of_measure as unit on unit.id = item.unit_id
      left join public.item_supply_policies as policy on policy.item_id = item.id
      left join lateral (
        select candidate.publication_status, candidate.public_name,
          candidate.public_description, control.code as control_profile_code,
          availability.code as availability_profile_code,
          candidate.requirement_summary, candidate.bulk_minimum, candidate.order_increment
        from public.item_publications as candidate
        join public.control_profiles as control on control.id = candidate.control_profile_id
        join public.availability_profiles as availability
          on availability.id = candidate.availability_profile_id
        where candidate.item_id = item.id
          and candidate.audience_code = 'public'
          and candidate.effective_from <= statement_timestamp()
          and (candidate.effective_until is null or candidate.effective_until > statement_timestamp())
        order by candidate.effective_from desc
        limit 1
      ) as publication on true
      left join lateral (
        select rule.price_schedule_id, rule.amount_minor, currency.code as currency_code
        from public.price_rules as rule
        join public.price_schedules as schedule on schedule.id = rule.price_schedule_id
          and schedule.status = 'active' and schedule.audience_code = 'public'
          and schedule.effective_from <= statement_timestamp()
          and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
        join public.currencies as currency on currency.id = schedule.currency_id
        where rule.item_id = item.id
          and rule.effective_from <= statement_timestamp()
          and (rule.effective_until is null or rule.effective_until > statement_timestamp())
        order by schedule.priority desc, rule.effective_from desc
        limit 1
      ) as price on true
    ), '[]'::jsonb)
  );
end;
$$;

create function public.staff_create_configuration_reference(
  p_kind text,
  p_code text,
  p_display_name text,
  p_public_display_name text,
  p_description text,
  p_symbol text,
  p_quantity_scale smallint,
  p_sort_order integer,
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
  created_id uuid;
  existing_receipt public.staff_command_receipts%rowtype;
  normalized_code text;
  normalized_name text;
begin
  actor_id := private.set_staff_audit_context(
    'configuration.manage', p_reason, p_request_id, 'staff_configuration'
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into existing_receipt
  from public.staff_command_receipts as receipt
  where receipt.request_id = p_request_id;
  if found then
    if existing_receipt.operation_code <> 'configuration.reference.create' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    id := existing_receipt.result_id;
    version := existing_receipt.result_version;
    return next;
    return;
  end if;

  normalized_code := lower(btrim(coalesce(p_code, '')));
  normalized_name := btrim(coalesce(p_display_name, ''));
  if normalized_code !~ '^[a-z0-9][a-z0-9_-]{0,49}$' or normalized_name = '' then
    raise exception using errcode = '22023', message = 'configuration_reference_invalid';
  end if;

  case p_kind
    when 'item_category' then
      insert into public.item_categories (code, display_name, description, sort_order)
      values (normalized_code, normalized_name, btrim(coalesce(p_description, '')), coalesce(p_sort_order, 0))
      returning item_categories.id into created_id;
    when 'unit' then
      insert into public.units_of_measure (code, display_name, symbol, quantity_scale)
      values (
        normalized_code, normalized_name, nullif(btrim(coalesce(p_symbol, '')), ''),
        coalesce(p_quantity_scale, 0)
      ) returning units_of_measure.id into created_id;
    when 'license_class' then
      insert into public.license_classes (code, display_name, public_display_name, description)
      values (
        normalized_code, normalized_name,
        coalesce(nullif(btrim(coalesce(p_public_display_name, '')), ''), normalized_name),
        btrim(coalesce(p_description, ''))
      ) returning license_classes.id into created_id;
    when 'endorsement' then
      insert into public.endorsement_definitions (
        code, display_name, public_display_name, description
      ) values (
        normalized_code, normalized_name,
        coalesce(nullif(btrim(coalesce(p_public_display_name, '')), ''), normalized_name),
        btrim(coalesce(p_description, ''))
      ) returning endorsement_definitions.id into created_id;
    when 'availability_profile' then
      insert into public.availability_profiles (
        code, display_name, public_description, sort_order
      ) values (
        normalized_code, normalized_name,
        coalesce(nullif(btrim(coalesce(p_description, '')), ''), normalized_name),
        coalesce(p_sort_order, 0)
      ) returning availability_profiles.id into created_id;
    else
      raise exception using errcode = '22023', message = 'configuration_kind_invalid';
  end case;

  insert into public.staff_command_receipts (
    request_id, operation_code, result_id, result_version, result, actor_id
  ) values (
    p_request_id, 'configuration.reference.create', created_id, 1,
    jsonb_build_object('kind', p_kind, 'code', normalized_code), actor_id
  );
  id := created_id;
  version := 1;
  return next;
end;
$$;

create function public.staff_create_control_profile(
  p_code text,
  p_display_name text,
  p_public_description text,
  p_requires_staff_review boolean,
  p_requires_transaction_approval boolean,
  p_requires_serial_tracking boolean,
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
  created_id uuid;
  existing_receipt public.staff_command_receipts%rowtype;
begin
  actor_id := private.set_staff_audit_context(
    'configuration.manage', p_reason, p_request_id, 'staff_configuration'
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into existing_receipt from public.staff_command_receipts
  where request_id = p_request_id;
  if found then
    if existing_receipt.operation_code <> 'configuration.control.create' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    id := existing_receipt.result_id;
    version := existing_receipt.result_version;
    return next;
    return;
  end if;

  insert into public.control_profiles (
    code, display_name, public_description, requires_staff_review,
    requires_transaction_approval, requires_serial_tracking
  ) values (
    lower(btrim(p_code)), btrim(p_display_name), btrim(p_public_description),
    coalesce(p_requires_staff_review, false),
    coalesce(p_requires_transaction_approval, false),
    coalesce(p_requires_serial_tracking, false)
  ) returning control_profiles.id into created_id;

  insert into public.staff_command_receipts (
    request_id, operation_code, result_id, result_version, result, actor_id
  ) values (
    p_request_id, 'configuration.control.create', created_id, 1,
    jsonb_build_object('code', lower(btrim(p_code))), actor_id
  );
  id := created_id;
  version := 1;
  return next;
end;
$$;

create function public.staff_quick_create_item(
  p_item_code text,
  p_slug text,
  p_display_name text,
  p_description text,
  p_category_code text,
  p_unit_code text,
  p_supply_mode text,
  p_control_profile_code text,
  p_availability_profile_code text,
  p_publish boolean,
  p_requirement_summary text,
  p_price_schedule_id uuid,
  p_price_amount_minor bigint,
  p_critical_level numeric,
  p_minimum_level numeric,
  p_target_level numeric,
  p_surplus_level numeric,
  p_direct_individual_allowed boolean,
  p_direct_weekly_limit numeric,
  p_business_bulk_review_threshold numeric,
  p_opening_stock_location_id uuid,
  p_opening_quantity numeric,
  p_source_reference text,
  p_reason text,
  p_request_id uuid
)
returns table (
  item_id uuid,
  item_code text,
  slug text,
  inventory_transaction_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  created_item record;
  receipt_result record;
  existing_receipt public.staff_command_receipts%rowtype;
  resolved_code text;
  resolved_slug text;
  resolved_description text;
  resolved_inventory_mode text;
  resolved_procurement_enabled boolean;
  resolved_player_sourced_only boolean;
  resolved_admin_receipt_allowed boolean;
  resolved_control_id uuid;
  resolved_availability_id uuid;
  resolved_currency_id uuid;
  created_inventory_transaction_id uuid;
  slug_base text;
  slug_suffix integer := 1;
begin
  actor_id := private.set_staff_audit_context(
    'catalogue.manage', p_reason, p_request_id, 'staff_quick_operations'
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into existing_receipt
  from public.staff_command_receipts as command_receipt
  where command_receipt.request_id = p_request_id;
  if found then
    if existing_receipt.operation_code <> 'catalogue.item.quick_create' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    item_id := existing_receipt.result_id;
    item_code := existing_receipt.result ->> 'item_code';
    slug := existing_receipt.result ->> 'slug';
    inventory_transaction_id := nullif(existing_receipt.result ->> 'inventory_transaction_id', '')::uuid;
    return next;
    return;
  end if;

  if btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = '22023', message = 'catalogue_display_name_required';
  end if;
  if p_supply_mode not in (
    'warehouse_stocked', 'player_sourced_reserve', 'made_to_order',
    'limited_release', 'serialized_unique'
  ) then
    raise exception using errcode = '22023', message = 'supply_mode_invalid';
  end if;

  resolved_code := upper(btrim(coalesce(p_item_code, '')));
  if resolved_code = '' then
    resolved_code := private.allocate_catalogue_item_code();
  end if;

  resolved_slug := lower(btrim(coalesce(p_slug, '')));
  if resolved_slug = '' then
    slug_base := trim(both '-' from regexp_replace(
      lower(btrim(p_display_name)), '[^a-z0-9]+', '-', 'g'
    ));
    if char_length(slug_base) < 2 then
      slug_base := lower(resolved_code);
    end if;
    slug_base := left(slug_base, 70);
    resolved_slug := slug_base;
    while exists (select 1 from public.items where items.slug = resolved_slug) loop
      slug_suffix := slug_suffix + 1;
      resolved_slug := left(slug_base, 70) || '-' || slug_suffix::text;
    end loop;
  end if;

  resolved_description := coalesce(
    nullif(btrim(coalesce(p_description, '')), ''),
    btrim(p_display_name)
  );
  resolved_inventory_mode := case when p_supply_mode = 'serialized_unique'
    then 'serialized' else 'fungible' end;
  resolved_procurement_enabled := p_supply_mode = 'player_sourced_reserve';
  resolved_player_sourced_only := p_supply_mode = 'player_sourced_reserve';
  resolved_admin_receipt_allowed := p_supply_mode not in (
    'player_sourced_reserve', 'serialized_unique'
  );

  select * into created_item
  from public.staff_create_catalogue_item(
    resolved_code, resolved_slug, p_display_name, resolved_description,
    p_category_code, p_unit_code, resolved_inventory_mode, '', p_reason, p_request_id
  );

  perform * from public.staff_upsert_item_supply_policy(
    created_item.id, p_supply_mode, resolved_procurement_enabled,
    resolved_player_sourced_only, resolved_admin_receipt_allowed,
    p_critical_level, p_minimum_level, p_target_level, p_surplus_level,
    coalesce(p_direct_individual_allowed, false), p_direct_weekly_limit,
    p_business_bulk_review_threshold, null, p_reason, p_request_id
  );

  if coalesce(p_publish, false) then
    perform private.set_staff_audit_context(
      'publication.manage', p_reason, p_request_id, 'staff_quick_operations'
    );
    select control.id into resolved_control_id
    from public.control_profiles as control
    where control.code = lower(btrim(p_control_profile_code)) and control.active;
    select availability.id into resolved_availability_id
    from public.availability_profiles as availability
    where availability.code = lower(btrim(p_availability_profile_code)) and availability.active;
    if resolved_control_id is null or resolved_availability_id is null then
      raise exception using errcode = '22023', message = 'publication_profile_invalid';
    end if;
    insert into public.item_publications (
      item_id, audience_code, publication_status, public_name, public_description,
      control_profile_id, availability_profile_id, requirement_summary,
      order_increment, effective_from
    ) values (
      created_item.id, 'public', 'published', btrim(p_display_name), resolved_description,
      resolved_control_id, resolved_availability_id,
      coalesce(nullif(btrim(coalesce(p_requirement_summary, '')), ''),
        'Contact an authorized representative for current terms and availability.'),
      1, statement_timestamp()
    );
  end if;

  if p_price_amount_minor is not null then
    perform private.set_staff_audit_context(
      'pricing.manage', p_reason, p_request_id, 'staff_quick_operations'
    );
    if p_price_amount_minor < 0 or p_price_schedule_id is null then
      raise exception using errcode = '22023', message = 'price_input_invalid';
    end if;
    select schedule.currency_id into resolved_currency_id
    from public.price_schedules as schedule
    where schedule.id = p_price_schedule_id and schedule.status = 'active'
      and schedule.effective_from <= statement_timestamp()
      and (schedule.effective_until is null or schedule.effective_until > statement_timestamp());
    if resolved_currency_id is null then
      raise exception using errcode = '22023', message = 'price_schedule_invalid';
    end if;
    insert into public.price_rules (
      price_schedule_id, item_id, amount_minor, effective_from, approved_at
    ) values (
      p_price_schedule_id, created_item.id, p_price_amount_minor,
      statement_timestamp(), statement_timestamp()
    );
  end if;

  if p_opening_quantity is not null and p_opening_quantity > 0 then
    if p_opening_stock_location_id is null then
      raise exception using errcode = '22023', message = 'opening_location_required';
    end if;
    select * into receipt_result
    from public.staff_post_inventory_receipt(
      p_opening_stock_location_id, created_item.id, p_opening_quantity,
      coalesce(nullif(btrim(coalesce(p_source_reference, '')), ''),
        'ONBOARDING-' || resolved_code || '-' || left(replace(p_request_id::text, '-', ''), 8)),
      p_reason, p_request_id
    );
    created_inventory_transaction_id := receipt_result.transaction_id;
  end if;

  perform private.set_staff_audit_context(
    'catalogue.manage', p_reason, p_request_id, 'staff_quick_operations'
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'catalogue.item_onboarded', 'item', created_item.id,
    jsonb_build_object(
      'item_id', created_item.id, 'item_code', resolved_code,
      'published', coalesce(p_publish, false), 'supply_mode', p_supply_mode,
      'inventory_transaction_id', created_inventory_transaction_id
    ),
    'catalogue.item_onboarded:' || p_request_id::text
  );

  insert into public.staff_command_receipts (
    request_id, operation_code, result_id, result_version, result, actor_id
  ) values (
    p_request_id, 'catalogue.item.quick_create', created_item.id, created_item.version,
    jsonb_build_object(
      'item_code', resolved_code, 'slug', resolved_slug,
      'inventory_transaction_id', created_inventory_transaction_id
    ), actor_id
  );

  item_id := created_item.id;
  item_code := resolved_code;
  slug := resolved_slug;
  inventory_transaction_id := created_inventory_transaction_id;
  return next;
end;
$$;

create function public.staff_quick_post_inventory_receipt(
  p_stock_location_id uuid,
  p_item_code text,
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
  resolved_item_id uuid;
  normalized_code text;
  normalized_reason text;
  normalized_source text;
begin
  normalized_code := upper(btrim(coalesce(p_item_code, '')));
  select item.id into resolved_item_id
  from public.items as item
  left join public.item_supply_policies as policy on policy.item_id = item.id
  where item.item_code = normalized_code
    and item.status = 'active'
    and item.inventory_mode = 'fungible'
    and coalesce(policy.admin_receipt_allowed, true);
  if resolved_item_id is null then
    raise exception using errcode = 'P0002', message = 'quick_receipt_item_not_found';
  end if;
  normalized_reason := coalesce(
    nullif(btrim(coalesce(p_reason, '')), ''),
    'Quick inventory receipt for ' || normalized_code || '.'
  );
  normalized_source := coalesce(
    nullif(btrim(coalesce(p_source_reference, '')), ''),
    'QUICK-' || normalized_code || '-' || left(replace(p_request_id::text, '-', ''), 8)
  );
  return query
  select posted.transaction_id, posted.inventory_account_id, posted.on_hand, posted.available
  from public.staff_post_inventory_receipt(
    p_stock_location_id, resolved_item_id, p_quantity, normalized_source,
    normalized_reason, p_request_id
  ) as posted;
end;
$$;

create function public.staff_set_item_public_terms(
  p_item_id uuid,
  p_publish boolean,
  p_public_name text,
  p_public_description text,
  p_control_profile_code text,
  p_availability_profile_code text,
  p_requirement_summary text,
  p_bulk_minimum numeric,
  p_order_increment numeric,
  p_price_action text,
  p_price_schedule_id uuid,
  p_price_amount_minor bigint,
  p_reason text,
  p_request_id uuid
)
returns table (item_id uuid, publication_status text, price_amount_minor bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing_receipt public.staff_command_receipts%rowtype;
  resolved_control_id uuid;
  resolved_availability_id uuid;
begin
  actor_id := private.set_staff_audit_context(
    'publication.manage', p_reason, p_request_id, 'staff_configuration'
  );
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into existing_receipt from public.staff_command_receipts
  where request_id = p_request_id;
  if found then
    if existing_receipt.operation_code <> 'catalogue.item.public_terms' then
      raise exception using errcode = '22023', message = 'request_id_reused';
    end if;
    item_id := existing_receipt.result_id;
    publication_status := existing_receipt.result ->> 'publication_status';
    price_amount_minor := nullif(existing_receipt.result ->> 'price_amount_minor', '')::bigint;
    return next;
    return;
  end if;

  if not exists (select 1 from public.items where id = p_item_id and status = 'active') then
    raise exception using errcode = 'P0002', message = 'catalogue_item_not_found';
  end if;
  if p_order_increment is null or p_order_increment <= 0
    or (p_bulk_minimum is not null and p_bulk_minimum <= 0) then
    raise exception using errcode = '22023', message = 'publication_quantity_invalid';
  end if;

  update public.item_publications as publication
  set effective_until = statement_timestamp()
  where publication.item_id = p_item_id
    and publication.audience_code = 'public'
    and publication.publication_status = 'published'
    and publication.effective_from <= statement_timestamp()
    and (publication.effective_until is null or publication.effective_until > statement_timestamp());

  if coalesce(p_publish, false) then
    select control.id into resolved_control_id
    from public.control_profiles as control
    where control.code = lower(btrim(p_control_profile_code)) and control.active;
    select availability.id into resolved_availability_id
    from public.availability_profiles as availability
    where availability.code = lower(btrim(p_availability_profile_code)) and availability.active;
    if resolved_control_id is null or resolved_availability_id is null
      or btrim(coalesce(p_public_name, '')) = ''
      or btrim(coalesce(p_public_description, '')) = ''
      or btrim(coalesce(p_requirement_summary, '')) = '' then
      raise exception using errcode = '22023', message = 'publication_input_invalid';
    end if;
    insert into public.item_publications (
      item_id, audience_code, publication_status, public_name, public_description,
      control_profile_id, availability_profile_id, requirement_summary,
      bulk_minimum, order_increment, effective_from
    ) values (
      p_item_id, 'public', 'published', btrim(p_public_name),
      btrim(p_public_description), resolved_control_id, resolved_availability_id,
      btrim(p_requirement_summary), p_bulk_minimum, p_order_increment,
      statement_timestamp()
    );
    publication_status := 'published';
  else
    publication_status := 'withdrawn';
  end if;

  if p_price_action not in ('keep', 'set', 'clear') then
    raise exception using errcode = '22023', message = 'price_action_invalid';
  end if;
  if p_price_action <> 'keep' then
    perform private.set_staff_audit_context(
      'pricing.manage', p_reason, p_request_id, 'staff_configuration'
    );
    if p_price_schedule_id is null or not exists (
      select 1 from public.price_schedules as schedule
      where schedule.id = p_price_schedule_id and schedule.status = 'active'
        and schedule.effective_from <= statement_timestamp()
        and (schedule.effective_until is null or schedule.effective_until > statement_timestamp())
    ) then
      raise exception using errcode = '22023', message = 'price_schedule_invalid';
    end if;
    update public.price_rules as rule
    set effective_until = statement_timestamp()
    where rule.item_id = p_item_id
      and rule.price_schedule_id = p_price_schedule_id
      and rule.effective_from <= statement_timestamp()
      and (rule.effective_until is null or rule.effective_until > statement_timestamp());
    if p_price_action = 'set' then
      if p_price_amount_minor is null or p_price_amount_minor < 0 then
        raise exception using errcode = '22023', message = 'price_amount_invalid';
      end if;
      insert into public.price_rules (
        price_schedule_id, item_id, amount_minor, effective_from, approved_at
      ) values (
        p_price_schedule_id, p_item_id, p_price_amount_minor,
        statement_timestamp(), statement_timestamp()
      );
      price_amount_minor := p_price_amount_minor;
    else
      price_amount_minor := null;
    end if;
  else
    select rule.amount_minor into price_amount_minor
    from public.price_rules as rule
    join public.price_schedules as schedule on schedule.id = rule.price_schedule_id
      and schedule.status = 'active' and schedule.audience_code = 'public'
    where rule.item_id = p_item_id
      and rule.effective_from <= statement_timestamp()
      and (rule.effective_until is null or rule.effective_until > statement_timestamp())
    order by schedule.priority desc, rule.effective_from desc
    limit 1;
  end if;

  perform private.set_staff_audit_context(
    'publication.manage', p_reason, p_request_id, 'staff_configuration'
  );
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'catalogue.public_terms_changed', 'item', p_item_id,
    jsonb_build_object(
      'item_id', p_item_id, 'publication_status', publication_status,
      'price_action', p_price_action, 'price_amount_minor', price_amount_minor
    ),
    'catalogue.public_terms_changed:' || p_request_id::text
  );
  insert into public.staff_command_receipts (
    request_id, operation_code, result_id, result, actor_id
  ) values (
    p_request_id, 'catalogue.item.public_terms', p_item_id,
    jsonb_build_object(
      'publication_status', publication_status,
      'price_amount_minor', price_amount_minor
    ), actor_id
  );
  item_id := p_item_id;
  return next;
end;
$$;

revoke all on public.staff_command_receipts from public, anon, authenticated;
revoke all on function private.current_staff_has_permission(text) from public, anon, authenticated;
revoke all on function private.allocate_catalogue_item_code() from public, anon, authenticated;
revoke all on function public.get_staff_configuration_workspace() from public, anon;
revoke all on function public.staff_create_configuration_reference(
  text, text, text, text, text, text, smallint, integer, text, uuid
) from public, anon;
revoke all on function public.staff_create_control_profile(
  text, text, text, boolean, boolean, boolean, text, uuid
) from public, anon;
revoke all on function public.staff_quick_create_item(
  text, text, text, text, text, text, text, text, text, boolean, text,
  uuid, bigint, numeric, numeric, numeric, numeric, boolean, numeric, numeric,
  uuid, numeric, text, text, uuid
) from public, anon;
revoke all on function public.staff_quick_post_inventory_receipt(
  uuid, text, numeric, text, text, uuid
) from public, anon;
revoke all on function public.staff_set_item_public_terms(
  uuid, boolean, text, text, text, text, text, numeric, numeric,
  text, uuid, bigint, text, uuid
) from public, anon;

grant execute on function public.get_staff_configuration_workspace() to authenticated;
grant execute on function public.staff_create_configuration_reference(
  text, text, text, text, text, text, smallint, integer, text, uuid
) to authenticated;
grant execute on function public.staff_create_control_profile(
  text, text, text, boolean, boolean, boolean, text, uuid
) to authenticated;
grant execute on function public.staff_quick_create_item(
  text, text, text, text, text, text, text, text, text, boolean, text,
  uuid, bigint, numeric, numeric, numeric, numeric, boolean, numeric, numeric,
  uuid, numeric, text, text, uuid
) to authenticated;
grant execute on function public.staff_quick_post_inventory_receipt(
  uuid, text, numeric, text, text, uuid
) to authenticated;
grant execute on function public.staff_set_item_public_terms(
  uuid, boolean, text, text, text, text, text, numeric, numeric,
  text, uuid, bigint, text, uuid
) to authenticated;
