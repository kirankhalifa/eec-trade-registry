create table private.public_verification_rate_limits (
  fingerprint text primary key,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  updated_at timestamptz not null default current_timestamp,
  constraint public_verification_rate_limit_fingerprint_check
    check (fingerprint ~ '^[a-f0-9]{64}$')
);

create index public_verification_rate_limits_updated_idx
  on private.public_verification_rate_limits(updated_at);

create function public.consume_public_verification_rate_limit(
  p_ip_fingerprint text,
  p_reference_fingerprint text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_window interval := interval '10 minutes';
  ip_count integer;
  reference_count integer;
begin
  if p_ip_fingerprint !~ '^[a-f0-9]{64}$'
    or p_reference_fingerprint !~ '^[a-f0-9]{64}$'
  then
    raise exception using errcode = '22023', message = 'invalid_verification_fingerprint';
  end if;

  insert into private.public_verification_rate_limits as bucket (
    fingerprint,
    window_started_at,
    request_count,
    updated_at
  )
  values (p_ip_fingerprint, current_timestamp, 1, current_timestamp)
  on conflict (fingerprint) do update
  set
    window_started_at = case
      when bucket.window_started_at <= current_timestamp - current_window
        then current_timestamp
      else bucket.window_started_at
    end,
    request_count = case
      when bucket.window_started_at <= current_timestamp - current_window then 1
      else bucket.request_count + 1
    end,
    updated_at = current_timestamp
  returning request_count into ip_count;

  insert into private.public_verification_rate_limits as bucket (
    fingerprint,
    window_started_at,
    request_count,
    updated_at
  )
  values (p_reference_fingerprint, current_timestamp, 1, current_timestamp)
  on conflict (fingerprint) do update
  set
    window_started_at = case
      when bucket.window_started_at <= current_timestamp - current_window
        then current_timestamp
      else bucket.window_started_at
    end,
    request_count = case
      when bucket.window_started_at <= current_timestamp - current_window then 1
      else bucket.request_count + 1
    end,
    updated_at = current_timestamp
  returning request_count into reference_count;

  delete from private.public_verification_rate_limits
  where updated_at < current_timestamp - interval '1 day';

  return ip_count <= 60 and reference_count <= 10;
end;
$$;

create function public.get_public_catalogue_entry_state(p_slug text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select 1
      from public.items as item
      join public.item_publications as publication on publication.item_id = item.id
      where item.slug = lower(btrim(p_slug))
        and item.status = 'active'
        and publication.audience_code = 'public'
        and publication.publication_status = 'published'
        and publication.effective_from <= current_timestamp
        and (publication.effective_until is null or publication.effective_until > current_timestamp)
    ) then 'published'
    when exists (
      select 1
      from public.items as item
      join public.item_publications as publication on publication.item_id = item.id
      where item.slug = lower(btrim(p_slug))
        and publication.audience_code = 'public'
        and publication.effective_from <= current_timestamp
        and (
          publication.publication_status = 'withdrawn'
          or (
            item.status = 'archived'
            and publication.publication_status = 'published'
          )
        )
    ) then 'withdrawn'
    else 'not_found'
  end;
$$;

revoke all on private.public_verification_rate_limits from public, anon, authenticated;
revoke execute on function public.consume_public_verification_rate_limit(text, text)
  from public, anon, authenticated;
grant execute on function public.consume_public_verification_rate_limit(text, text)
  to service_role;

revoke execute on function public.public_dealer_verification(text)
  from anon, authenticated;
revoke execute on function public.public_license_verification(text)
  from anon, authenticated;
grant execute on function public.public_dealer_verification(text) to service_role;
grant execute on function public.public_license_verification(text) to service_role;

revoke execute on function public.get_public_catalogue_entry_state(text)
  from public;
grant execute on function public.get_public_catalogue_entry_state(text)
  to anon, authenticated, service_role;

alter table public.endorsement_definitions
  add column application_group text not null default 'Other authority',
  add column application_sort_order integer not null default 500
    check (application_sort_order between 0 and 10000);

update public.endorsement_definitions
set application_group = 'Goods and services', application_sort_order = 100
where code in (
  'raw-materials',
  'smithing-metalwork',
  'alchemical-goods',
  'arcane-goods',
  'tailoring-textiles'
);

update public.endorsement_definitions
set application_group = 'Distribution and custody', application_sort_order = 200
where code in ('bulk-distribution', 'consignment', 'serialized-custody');

update public.endorsement_definitions
set application_group = 'Additional controls', application_sort_order = 300
where code = 'regulated-goods';

update public.endorsement_definitions
set active = false
where code = 'instrument-trade'
  and description ilike '%fictional%production policy%';

create or replace function public.get_public_license_application_options()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'license_classes', coalesce((
      select jsonb_agg(
        jsonb_build_object('code', class.code, 'label', class.public_display_name)
        order by class.public_display_name
      )
      from public.license_classes as class
      where class.active
    ), '[]'::jsonb),
    'jurisdictions', coalesce((
      select jsonb_agg(
        jsonb_build_object('code', jurisdiction.code, 'label', jurisdiction.public_name)
        order by jurisdiction.public_name
      )
      from public.jurisdictions as jurisdiction
      where jurisdiction.status = 'active'
    ), '[]'::jsonb),
    'endorsements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'code', definition.code,
          'label', definition.public_display_name,
          'description', definition.description,
          'group', definition.application_group
        )
        order by definition.application_sort_order, definition.public_display_name
      )
      from public.endorsement_definitions as definition
      where definition.active
    ), '[]'::jsonb)
  );
$$;

create function public.public_submit_license_renewal(
  p_existing_license_reference text,
  p_request_id uuid
)
returns table(application_id uuid, public_reference text, status_token text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  existing_license record;
  created_id uuid;
  created_reference text;
  token text;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'application_request_id_required';
  end if;

  select
    license.id,
    license.holder_party_id,
    license.license_class_id,
    license.jurisdiction_id,
    party.display_name as applicant_name
  into existing_license
  from public.licenses as license
  join public.parties as party on party.id = license.holder_party_id
  where license.public_reference = private.normalize_registry_reference(
    p_existing_license_reference
  );
  if not found then
    raise exception using errcode = '22023', message = 'renewal_license_not_found';
  end if;

  if exists (
    select 1
    from public.license_applications as application
    where application.existing_license_id = existing_license.id
      and application.status in ('submitted', 'under_review')
  ) then
    raise exception using errcode = '22023', message = 'renewal_application_already_pending';
  end if;

  perform set_config('app.actor_id', '', true);
  perform set_config('app.permission_code', 'public.license.apply', true);
  perform set_config('app.audit_reason', 'Public license renewal submitted.', true);
  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.source_surface', 'public_portal', true);

  created_reference := private.allocate_launch_reference('license_application');
  token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.license_applications (
    public_reference,
    application_type,
    applicant_name,
    contact_label,
    requested_license_class_id,
    requested_jurisdiction_id,
    existing_license_id,
    statement,
    status_token_digest,
    source_request_id
  ) values (
    created_reference,
    'renewal',
    existing_license.applicant_name,
    'Existing license holder renewal',
    existing_license.license_class_id,
    existing_license.jurisdiction_id,
    existing_license.id,
    'Renewal requested for the existing issued authority.',
    encode(extensions.digest(token, 'sha256'), 'hex'),
    p_request_id
  ) returning id into created_id;

  insert into public.license_application_endorsements (
    application_id,
    endorsement_definition_id
  )
  select created_id, endorsement.endorsement_definition_id
  from public.license_endorsements as endorsement
  where endorsement.license_id = existing_license.id
    and endorsement.effective_from <= statement_timestamp()
    and (endorsement.expires_at is null or endorsement.expires_at > statement_timestamp())
    and endorsement.revoked_at is null;

  insert into public.outbox_events (
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    deduplication_key
  ) values (
    'license.application_submitted',
    'license_application',
    created_id,
    jsonb_build_object(
      'public_reference', created_reference,
      'application_type', 'renewal'
    ),
    'license.application_submitted:' || p_request_id::text
  );

  return query select created_id, created_reference, token;
end;
$$;

revoke execute on function public.public_submit_license_renewal(text, uuid)
  from public;
grant execute on function public.public_submit_license_renewal(text, uuid)
  to anon, authenticated;

create function public.staff_preview_trade_order(
  p_channel text,
  p_customer_party_id uuid,
  p_customer_name text,
  p_dealer_authorization_id uuid,
  p_license_id uuid,
  p_jurisdiction_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  dealer_record record;
  license_record record;
  line jsonb;
  item_record record;
  price_record record;
  policy_record record;
  resolved_party_id uuid := p_customer_party_id;
  resolved_jurisdiction_id uuid := p_jurisdiction_id;
  local_now timestamp;
  starts_at timestamptz;
  used_quantity numeric;
  requested_quantity numeric;
  remaining_quantity numeric;
  preview_lines jsonb := '[]'::jsonb;
  warnings jsonb := '[]'::jsonb;
  total_amount numeric := 0;
  preview_valid boolean := true;
  resolved_currency text;
  source_description text;
begin
  perform 1 from private.require_staff_permission('order.assisted.create');

  if p_channel not in ('staff_assisted_business', 'direct_individual')
    or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0
    or jsonb_array_length(p_lines) > 50
  then
    raise exception using errcode = '22023', message = 'assisted_order_invalid';
  end if;

  if p_channel = 'staff_assisted_business' then
    select dealer.*, status.confers_authority
    into dealer_record
    from public.dealer_authorizations as dealer
    join public.dealer_status_definitions as status
      on status.id = dealer.status_definition_id
    where dealer.id = p_dealer_authorization_id
      and dealer.dealer_party_id = p_customer_party_id
      and status.confers_authority
      and dealer.effective_from <= statement_timestamp()
      and (dealer.effective_until is null or dealer.effective_until > statement_timestamp());
    if not found then
      raise exception using errcode = '22023', message = 'assisted_dealer_not_authorized';
    end if;

    select license.* into license_record
    from public.licenses as license
    join public.license_status_definitions as status
      on status.id = license.status_definition_id
      and status.confers_authority
    where license.id = p_license_id
      and license.holder_party_id = p_customer_party_id
      and license.dealer_authorization_id = p_dealer_authorization_id
      and license.effective_from <= statement_timestamp()
      and (license.expires_at is null or license.expires_at > statement_timestamp());
    if not found then
      raise exception using errcode = '22023', message = 'assisted_license_not_authorized';
    end if;
    resolved_jurisdiction_id := dealer_record.jurisdiction_id;
  else
    if not exists (
      select 1 from public.jurisdictions as jurisdiction
      where jurisdiction.id = resolved_jurisdiction_id
        and jurisdiction.status = 'active'
    ) or (resolved_party_id is null and btrim(coalesce(p_customer_name, '')) = '') then
      raise exception using errcode = '22023', message = 'direct_customer_invalid';
    end if;
  end if;

  for line in select value from jsonb_array_elements(p_lines) loop
    requested_quantity := (line ->> 'quantity')::numeric;
    if requested_quantity <= 0 then
      raise exception using errcode = '22023', message = 'order_line_quantity_invalid';
    end if;

    select item.id, item.item_code, item.display_name, unit.symbol
    into item_record
    from public.items as item
    join public.units_of_measure as unit on unit.id = item.unit_id
    where item.id = (line ->> 'item_id')::uuid
      and item.status = 'active';
    if not found then
      raise exception using errcode = '22023', message = 'order_item_invalid';
    end if;

    select * into price_record
    from private.resolve_trade_price(
      p_channel,
      resolved_party_id,
      p_dealer_authorization_id,
      p_license_id,
      resolved_jurisdiction_id,
      item_record.id
    );

    remaining_quantity := null;
    used_quantity := null;
    if p_channel = 'direct_individual' then
      if not found then
        raise exception using errcode = '22023', message = 'direct_price_unavailable';
      end if;
      select supply.*, channel.weekly_window_timezone
      into policy_record
      from public.item_supply_policies as supply
      join public.commercial_channel_policies as channel
        on channel.channel_code = 'direct_individual'
        and channel.active
      where supply.item_id = item_record.id
        and supply.direct_individual_allowed;
      if not found then
        raise exception using errcode = '22023', message = 'direct_item_not_allowed';
      end if;

      local_now := statement_timestamp() at time zone policy_record.weekly_window_timezone;
      starts_at := date_trunc('week', local_now) at time zone policy_record.weekly_window_timezone;
      if resolved_party_id is null then
        used_quantity := 0;
      else
        select coalesce(sum(quota.quantity), 0) into used_quantity
        from public.personal_quota_entries as quota
        where quota.party_id = resolved_party_id
          and quota.item_id = item_record.id
          and quota.window_start = starts_at
          and quota.status in ('held', 'consumed');
      end if;
      if policy_record.direct_weekly_limit is not null then
        remaining_quantity := greatest(policy_record.direct_weekly_limit - used_quantity, 0);
        if requested_quantity > remaining_quantity then
          preview_valid := false;
          warnings := warnings || jsonb_build_array(
            item_record.display_name || ' exceeds the current personal weekly limit.'
          );
        end if;
      end if;
    end if;

    if price_record.amount_minor is not null then
      total_amount := total_amount + price_record.amount_minor * requested_quantity;
      resolved_currency := coalesce(resolved_currency, price_record.currency_code);
    end if;
    source_description := case split_part(coalesce(price_record.source_label, ''), ':', 1)
      when 'party' then 'Dealer-specific price'
      when 'license_class' then 'License-class price'
      when 'dealer_type' then 'Dealer-type price'
      when 'jurisdiction' then 'Regional price'
      when 'channel_default' then 'Channel default price'
      when 'audience' then 'Published audience price'
      else 'Price to be confirmed by staff'
    end;

    preview_lines := preview_lines || jsonb_build_array(jsonb_build_object(
      'item_id', item_record.id,
      'item_code', item_record.item_code,
      'item_name', item_record.display_name,
      'quantity', requested_quantity,
      'unit', item_record.symbol,
      'unit_price_minor', price_record.amount_minor,
      'base_price_minor', price_record.base_amount_minor,
      'currency_code', price_record.currency_code,
      'multiplier_basis_points', price_record.multiplier_basis_points,
      'price_source', source_description,
      'weekly_limit', case when p_channel = 'direct_individual'
        then policy_record.direct_weekly_limit else null end,
      'weekly_used', used_quantity,
      'weekly_remaining', remaining_quantity
    ));
  end loop;

  return jsonb_build_object(
    'valid', preview_valid,
    'channel', p_channel,
    'channel_label', case p_channel
      when 'direct_individual' then 'Direct individual · premium pricing'
      else 'Verified business · licensed pricing'
    end,
    'lines', preview_lines,
    'total_amount_minor', case when resolved_currency is null then null else total_amount end,
    'currency_code', resolved_currency,
    'warnings', warnings,
    'reservation_message', 'Approval does not require stock. Any later reservation lasts 48 hours.'
  );
end;
$$;

revoke execute on function public.staff_preview_trade_order(
  text, uuid, text, uuid, uuid, uuid, jsonb
) from public, anon;
grant execute on function public.staff_preview_trade_order(
  text, uuid, text, uuid, uuid, uuid, jsonb
) to authenticated;

create or replace function public.get_staff_inventory_receipt_item_ids()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1
  from private.require_staff_permission('inventory.receipt.post');

  return coalesce((
    select jsonb_agg(item.id order by item.display_name, item.item_code)
    from public.items as item
    join public.item_supply_policies as policy on policy.item_id = item.id
    where item.status = 'active'
      and item.inventory_mode = 'fungible'
      and policy.admin_receipt_allowed
      and not policy.player_sourced_only
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_staff_inventory_receipt_item_ids()
  from public, anon;
grant execute on function public.get_staff_inventory_receipt_item_ids()
  to authenticated;

create function public.get_staff_price_preview_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare direct_multiplier integer;
begin
  perform 1 from private.require_staff_permission('pricing.binding.manage');
  select policy.price_multiplier_basis_points into direct_multiplier
  from public.commercial_channel_policies as policy
  where policy.channel_code = 'direct_individual' and policy.active;

  return jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id, 'label', item.display_name, 'code', item.item_code
      ) order by item.display_name)
      from public.items as item where item.status = 'active'
    ), '[]'::jsonb),
    'rules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'schedule_id', schedule.id,
        'item_id', rule.item_id,
        'amount_minor', rule.amount_minor,
        'direct_amount_minor', case when direct_multiplier is null then null
          else round(rule.amount_minor * direct_multiplier / 10000.0)::bigint end,
        'currency_code', currency.code
      ) order by schedule.display_name, item.display_name)
      from public.price_schedules as schedule
      join public.price_rules as rule on rule.price_schedule_id = schedule.id
      join public.items as item on item.id = rule.item_id
      join public.currencies as currency on currency.id = schedule.currency_id
      where schedule.status <> 'retired'
        and rule.effective_from <= statement_timestamp()
        and (rule.effective_until is null or rule.effective_until > statement_timestamp())
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_staff_price_preview_options() from public, anon;
grant execute on function public.get_staff_price_preview_options() to authenticated;

-- New lookup references add 40 bits of non-sequential entropy. Existing
-- references remain valid and keep their current public contracts.
create or replace function private.allocate_license_reference()
returns text language plpgsql volatile security definer set search_path = ''
as $$
declare sequence_record record; allocated_reference text;
begin
  select reference.prefix, reference.next_value, reference.padding
  into strict sequence_record from public.reference_sequences as reference
  where reference.document_type = 'license' and reference.active for update;
  allocated_reference := sequence_record.prefix || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0') || '-'
    || upper(encode(extensions.gen_random_bytes(5), 'hex'));
  update public.reference_sequences as reference
  set next_value = reference.next_value + 1 where reference.document_type = 'license';
  return allocated_reference;
exception when no_data_found then
  raise exception using errcode = '55000', message = 'license_reference_sequence_unavailable';
end;
$$;

create or replace function private.allocate_dealer_reference()
returns text language plpgsql volatile security definer set search_path = ''
as $$
declare sequence_record record; allocated_reference text;
begin
  select reference.prefix, reference.next_value, reference.padding
  into strict sequence_record from public.reference_sequences as reference
  where reference.document_type = 'dealer_authorization' and reference.active for update;
  allocated_reference := sequence_record.prefix || '-'
    || lpad(sequence_record.next_value::text, sequence_record.padding, '0') || '-'
    || upper(encode(extensions.gen_random_bytes(5), 'hex'));
  update public.reference_sequences as reference
  set next_value = reference.next_value + 1 where reference.document_type = 'dealer_authorization';
  return allocated_reference;
exception when no_data_found then
  raise exception using errcode = '55000', message = 'dealer_reference_sequence_unavailable';
end;
$$;

create table private.scope_key_definitions (
  scope_family text not null check (scope_family in ('staff_assignment', 'dealer_authority')),
  scope_key text not null,
  value_type text not null check (value_type in ('boolean', 'warehouse_uuid_array')),
  primary key (scope_family, scope_key)
);

insert into private.scope_key_definitions (scope_family, scope_key, value_type)
values
  ('staff_assignment', 'warehouse_ids', 'warehouse_uuid_array'),
  ('dealer_authority', 'portal.read', 'boolean'),
  ('dealer_authority', 'order.read', 'boolean'),
  ('dealer_authority', 'order.create', 'boolean'),
  ('dealer_authority', 'order.cancel', 'boolean'),
  ('dealer_authority', 'consignment.read', 'boolean'),
  ('dealer_authority', 'consignment.report', 'boolean');

create function private.scope_object_is_valid(p_family text, p_scope jsonb)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare supplied record; warehouse_value text;
begin
  if jsonb_typeof(p_scope) <> 'object' then return false; end if;
  for supplied in
    select entry.key as scope_key, entry.value as scope_value, definition.value_type
    from jsonb_each(p_scope) as entry
    left join private.scope_key_definitions as definition
      on definition.scope_family = p_family and definition.scope_key = entry.key
  loop
    if supplied.value_type is null then return false; end if;
    if supplied.value_type = 'boolean' then
      if jsonb_typeof(supplied.scope_value) <> 'boolean' then return false; end if;
    elsif supplied.value_type = 'warehouse_uuid_array' then
      if jsonb_typeof(supplied.scope_value) <> 'array' then return false; end if;
      for warehouse_value in select jsonb_array_elements_text(supplied.scope_value) loop
        if warehouse_value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
          or not exists (
            select 1 from public.warehouses as warehouse
            where warehouse.id::text = warehouse_value
          )
        then return false; end if;
      end loop;
    end if;
  end loop;
  return true;
end;
$$;

alter table public.staff_assignments add constraint staff_assignments_scope_keys_valid
  check (private.scope_object_is_valid('staff_assignment', assignment_scope)) not valid;
alter table public.staff_assignments validate constraint staff_assignments_scope_keys_valid;
alter table public.party_representatives add constraint party_representatives_scope_keys_valid
  check (private.scope_object_is_valid('dealer_authority', authority_scope)) not valid;
alter table public.party_representatives validate constraint party_representatives_scope_keys_valid;
alter table public.representative_role_definitions add constraint representative_roles_scope_keys_valid
  check (private.scope_object_is_valid('dealer_authority', default_scope)) not valid;
alter table public.representative_role_definitions validate constraint representative_roles_scope_keys_valid;

revoke all on table private.scope_key_definitions from public, anon, authenticated;
revoke all on function private.scope_object_is_valid(text, jsonb) from public, anon, authenticated;
