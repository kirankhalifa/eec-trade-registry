-- Discord access requests, simplified Owner/Agent staff access, and a dedicated
-- license-application review projection. Authentication still grants no authority.

insert into public.staff_roles (
  code, display_name, description, is_assignable, is_elevated
)
values
  (
    'owner',
    'Owner',
    'Platform owner with complete authority, including staff access administration and audit review.',
    false,
    true
  ),
  (
    'agent',
    'Agent',
    'Authorized company agent for day-to-day trade, licensing, inventory, finance, compliance, and configuration work.',
    false,
    false
  )
on conflict (code) do update
set display_name = excluded.display_name,
    description = excluded.description,
    is_assignable = excluded.is_assignable,
    is_elevated = excluded.is_elevated,
    active = true;

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'owner' and permission.active
on conflict (staff_role_id, permission_scope_id) do nothing;

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'agent'
  and permission.active
  and permission.code not in (
    'access.private.read',
    'access.assignment.manage',
    'audit.private.read'
  )
on conflict (staff_role_id, permission_scope_id) do nothing;

-- Preserve all existing authority while giving every current platform
-- administrator the new user-facing Owner access class.
insert into public.staff_assignments (
  actor_id, staff_role_id, effective_from, assignment_scope
)
select distinct assignment.actor_id, owner_role.id, statement_timestamp(), '{}'::jsonb
from public.staff_assignments as assignment
join public.staff_roles as legacy_role
  on legacy_role.id = assignment.staff_role_id
cross join public.staff_roles as owner_role
where legacy_role.code = 'platform_administrator'
  and owner_role.code = 'owner'
  and assignment.revoked_at is null
  and assignment.effective_from <= statement_timestamp()
  and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
  and not exists (
    select 1
    from public.staff_assignments as existing
    where existing.actor_id = assignment.actor_id
      and existing.staff_role_id = owner_role.id
      and existing.revoked_at is null
      and existing.effective_from <= statement_timestamp()
      and (existing.effective_until is null or existing.effective_until > statement_timestamp())
  );

create table public.staff_access_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete restrict,
  discord_user_id text not null unique
    check (btrim(discord_user_id) <> '' and char_length(discord_user_id) <= 100),
  display_name text not null
    check (btrim(display_name) <> '' and char_length(display_name) <= 200),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'denied', 'blocked')),
  requested_at timestamptz not null default now(),
  last_attempted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  approved_actor_id uuid references public.actor_profiles(id) on delete restrict,
  review_reason text check (review_reason is null or char_length(review_reason) <= 500),
  first_request_id uuid unique,
  review_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (last_attempted_at >= requested_at),
  check ((status = 'approved') = (approved_actor_id is not null))
);

comment on table public.staff_access_requests is
  'Discord identities awaiting explicit owner review. A row is not staff authority; only an active actor assignment authorizes work.';

create index staff_access_requests_review_queue_idx
  on public.staff_access_requests(status, requested_at, id);

create trigger staff_access_requests_set_updated_at
before update on public.staff_access_requests
for each row execute function private.set_updated_at();

create trigger staff_access_requests_audit
after insert or update or delete on public.staff_access_requests
for each row execute function private.capture_audit_row();

alter table public.staff_access_requests enable row level security;
revoke all on public.staff_access_requests from public, anon, authenticated;

-- Recover Discord users who authenticated before an approval queue existed.
-- Current staff are marked approved; all other Discord identities become pending.
insert into public.staff_access_requests (
  auth_user_id,
  discord_user_id,
  display_name,
  status,
  requested_at,
  last_attempted_at,
  approved_actor_id
)
select
  user_record.id,
  coalesce(
    nullif(identity_record.identity_data ->> 'sub', ''),
    nullif(identity_record.provider_id, ''),
    identity_record.id::text
  ),
  left(coalesce(
    nullif(identity_record.identity_data ->> 'full_name', ''),
    nullif(identity_record.identity_data ->> 'name', ''),
    nullif(identity_record.identity_data ->> 'preferred_username', ''),
    nullif(identity_record.identity_data ->> 'user_name', ''),
    'Discord user ' || right(user_record.id::text, 8)
  ), 200),
  case when actor.id is null then 'pending' else 'approved' end,
  coalesce(user_record.created_at, statement_timestamp()),
  greatest(
    coalesce(user_record.created_at, statement_timestamp()),
    coalesce(user_record.last_sign_in_at, user_record.created_at, statement_timestamp())
  ),
  actor.id
from auth.users as user_record
join lateral (
  select identity.*
  from auth.identities as identity
  where identity.user_id = user_record.id and identity.provider = 'discord'
  order by identity.created_at
  limit 1
) as identity_record on true
left join lateral (
  select profile.id
  from public.actor_profiles as profile
  where profile.auth_user_id = user_record.id
    and profile.actor_type = 'staff'
    and profile.status = 'active'
    and exists (
      select 1
      from public.staff_assignments as assignment
      join public.staff_roles as role on role.id = assignment.staff_role_id and role.active
      where assignment.actor_id = profile.id
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    )
  limit 1
) as actor on true
on conflict (auth_user_id) do nothing;

create function public.get_my_staff_access_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  result jsonb;
begin
  if user_id is null then
    raise exception using errcode = '28000', message = 'staff_authentication_required';
  end if;

  select jsonb_build_object(
    'state', case when staff_authority.actor_id is not null then 'authorized'
      when request.status = 'approved' then 'blocked'
      else coalesce(request.status, 'unregistered') end,
    'access_class', case
      when staff_authority.is_owner then 'owner'
      when staff_authority.actor_id is not null then 'agent'
      else null
    end,
    'display_name', coalesce(staff_authority.display_name, request.display_name),
    'request_id', request.id,
    'requested_at', request.requested_at,
    'last_attempted_at', request.last_attempted_at,
    'reviewed_at', request.reviewed_at,
    'review_reason', request.review_reason
  )
  into result
  from (select user_id as auth_user_id) as caller
  left join lateral (
    select profile.id as actor_id, profile.display_name,
      bool_or(role.code in ('owner', 'platform_administrator')) as is_owner
    from public.actor_profiles as profile
    join public.staff_assignments as assignment
      on assignment.actor_id = profile.id
      and assignment.revoked_at is null
      and assignment.effective_from <= statement_timestamp()
      and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    join public.staff_roles as role on role.id = assignment.staff_role_id and role.active
    where profile.auth_user_id = caller.auth_user_id
      and profile.actor_type = 'staff'
      and profile.status = 'active'
    group by profile.id, profile.display_name
    limit 1
  ) as staff_authority on true
  left join public.staff_access_requests as request
    on request.auth_user_id = caller.auth_user_id;

  return coalesce(result, jsonb_build_object(
    'state', 'unregistered',
    'access_class', null,
    'display_name', null,
    'request_id', null,
    'requested_at', null,
    'last_attempted_at', null,
    'reviewed_at', null,
    'review_reason', null
  ));
end;
$$;

create function public.register_staff_access_request(p_request_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  user_id uuid := auth.uid();
  discord_identity record;
  request_record public.staff_access_requests%rowtype;
  actor_record record;
  normalized_name text;
  created_request boolean := false;
begin
  if user_id is null then
    raise exception using errcode = '28000', message = 'staff_authentication_required';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'request_id_required';
  end if;

  select identity.id, identity.provider_id, identity.identity_data
  into discord_identity
  from auth.identities as identity
  where identity.user_id = user_id and identity.provider = 'discord'
  order by identity.created_at
  limit 1;
  if not found then
    raise exception using errcode = '42501', message = 'discord_identity_required';
  end if;

  normalized_name := left(coalesce(
    nullif(discord_identity.identity_data ->> 'full_name', ''),
    nullif(discord_identity.identity_data ->> 'name', ''),
    nullif(discord_identity.identity_data ->> 'preferred_username', ''),
    nullif(discord_identity.identity_data ->> 'user_name', ''),
    'Discord user ' || right(user_id::text, 8)
  ), 200);

  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.correlation_id', p_request_id::text, true);
  perform set_config('app.source_surface', 'staff_oauth', true);
  perform set_config('app.audit_reason', 'Discord identity requested staff access.', true);

  -- Serialize registration for one authenticated identity so two callback retries
  -- cannot create duplicate requests or duplicate notification work.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(user_id::text, 0)
  );

  select profile.id, profile.display_name
  into actor_record
  from public.actor_profiles as profile
  where profile.auth_user_id = user_id
    and profile.actor_type = 'staff'
    and profile.status = 'active'
    and exists (
      select 1
      from public.staff_assignments as assignment
      join public.staff_roles as role on role.id = assignment.staff_role_id and role.active
      where assignment.actor_id = profile.id
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    );

  select request.* into request_record
  from public.staff_access_requests as request
  where request.auth_user_id = user_id
  for update;

  if found then
    update public.staff_access_requests as request
    set last_attempted_at = greatest(statement_timestamp(), request.requested_at),
        discord_user_id = coalesce(
          nullif(discord_identity.identity_data ->> 'sub', ''),
          nullif(discord_identity.provider_id, ''),
          discord_identity.id::text
        ),
        display_name = case when request.status = 'approved'
          then request.display_name else normalized_name end
    where request.id = request_record.id;
  else
    insert into public.staff_access_requests (
      auth_user_id, discord_user_id, display_name, status,
      approved_actor_id, first_request_id
    ) values (
      user_id,
      coalesce(
        nullif(discord_identity.identity_data ->> 'sub', ''),
        nullif(discord_identity.provider_id, ''),
        discord_identity.id::text
      ),
      coalesce(actor_record.display_name, normalized_name),
      case when actor_record.id is null then 'pending' else 'approved' end,
      actor_record.id,
      p_request_id
    ) returning * into request_record;
    created_request := true;
  end if;

  if created_request and request_record.status = 'pending' then
    insert into public.outbox_events (
      event_type, aggregate_type, aggregate_id, payload, deduplication_key
    ) values (
      'access.request_submitted',
      'staff_access_request',
      request_record.id,
      jsonb_build_object(
        'staff_access_request_id', request_record.id,
        'display_name', request_record.display_name,
        'requested_at', request_record.requested_at
      ),
      'access.request_submitted:' || p_request_id::text
    );
  end if;

  return public.get_my_staff_access_state();
end;
$$;

create function public.get_owner_access_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('access.assignment.manage');

  return jsonb_build_object(
    'generated_at', statement_timestamp(),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', request.id,
        'display_name', request.display_name,
        'discord_user_id', request.discord_user_id,
        'status', request.status,
        'requested_at', request.requested_at,
        'last_attempted_at', request.last_attempted_at,
        'reviewed_at', request.reviewed_at,
        'review_reason', request.review_reason,
        'protected_owner', exists (
          select 1
          from public.staff_assignments as protected_assignment
          join public.staff_roles as protected_role
            on protected_role.id = protected_assignment.staff_role_id
          where protected_assignment.actor_id = request.approved_actor_id
            and protected_role.code in ('owner', 'platform_administrator')
            and protected_assignment.revoked_at is null
            and protected_assignment.effective_from <= statement_timestamp()
            and (protected_assignment.effective_until is null or protected_assignment.effective_until > statement_timestamp())
        ),
        'version', request.version
      ) order by
        case request.status when 'pending' then 0 when 'denied' then 1 when 'blocked' then 2 else 3 end,
        request.requested_at desc
      )
      from public.staff_access_requests as request
    ), '[]'::jsonb),
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'actor_id', actor.id,
        'display_name', actor.display_name,
        'status', actor.status,
        'access_class', case when bool_or(role.code in ('owner', 'platform_administrator'))
          then 'owner' else 'agent' end,
        'active_since', min(assignment.effective_from),
        'discord_user_id', max(request.discord_user_id)
      ) order by actor.display_name)
      from public.actor_profiles as actor
      join public.staff_assignments as assignment
        on assignment.actor_id = actor.id
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
      join public.staff_roles as role on role.id = assignment.staff_role_id and role.active
      left join public.staff_access_requests as request on request.auth_user_id = actor.auth_user_id
      where actor.actor_type = 'staff' and actor.status = 'active'
      group by actor.id, actor.display_name, actor.status
    ), '[]'::jsonb)
  );
end;
$$;

create function public.owner_review_staff_access_request(
  p_access_request_id uuid,
  p_expected_version bigint,
  p_decision text,
  p_reason text,
  p_request_id uuid
)
returns table(access_request_id uuid, status text, actor_id uuid, version bigint)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  reviewer_id uuid;
  access_request public.staff_access_requests%rowtype;
  target_actor_id uuid;
  agent_role_id uuid;
begin
  reviewer_id := private.set_staff_audit_context(
    'access.assignment.manage', p_reason, p_request_id, 'staff_access_review'
  );

  select request.* into access_request
  from public.staff_access_requests as request
  where request.id = p_access_request_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'staff_access_request_not_found';
  end if;
  if access_request.review_request_id = p_request_id then
    return query select access_request.id, access_request.status,
      access_request.approved_actor_id, access_request.version;
    return;
  end if;

  select request.* into access_request
  from public.staff_access_requests as request
  where request.id = p_access_request_id
  for update;
  if access_request.review_request_id = p_request_id then
    return query select access_request.id, access_request.status,
      access_request.approved_actor_id, access_request.version;
    return;
  end if;
  if access_request.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'staff_access_request_version_conflict';
  end if;
  if p_decision not in ('approve', 'deny', 'block') then
    raise exception using errcode = '22023', message = 'staff_access_decision_invalid';
  end if;
  if p_decision = 'deny' and access_request.status = 'approved' then
    raise exception using errcode = '22023', message = 'approved_staff_must_be_blocked';
  end if;

  select profile.id into target_actor_id
  from public.actor_profiles as profile
  where profile.auth_user_id = access_request.auth_user_id
  for update;

  if p_decision = 'approve' then
    if target_actor_id is null then
      insert into public.actor_profiles (
        auth_user_id, display_name, actor_type, status
      ) values (
        access_request.auth_user_id, access_request.display_name, 'staff', 'active'
      ) returning id into target_actor_id;
    else
      update public.actor_profiles
      set status = 'active'
      where id = target_actor_id;
    end if;

    select role.id into agent_role_id
    from public.staff_roles as role
    where role.code = 'agent' and role.active;
    if agent_role_id is null then
      raise exception using errcode = 'P0002', message = 'agent_role_not_found';
    end if;

    if not exists (
      select 1
      from public.staff_assignments as assignment
      where assignment.actor_id = target_actor_id
        and assignment.staff_role_id = agent_role_id
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    ) then
      insert into public.staff_assignments (
        actor_id, staff_role_id, effective_from, assignment_scope, source_request_id
      ) values (
        target_actor_id, agent_role_id, statement_timestamp(), '{}'::jsonb, p_request_id
      );
    end if;

    update public.staff_access_requests
    set status = 'approved',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = target_actor_id,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = version + 1
    where id = access_request.id
    returning * into access_request;
  elsif p_decision = 'deny' then
    update public.staff_access_requests
    set status = 'denied',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = null,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = version + 1
    where id = access_request.id
    returning * into access_request;
  else
    if target_actor_id is not null and exists (
      select 1
      from public.staff_assignments as assignment
      join public.staff_roles as role on role.id = assignment.staff_role_id
      where assignment.actor_id = target_actor_id
        and role.code in ('owner', 'platform_administrator')
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
    ) then
      raise exception using errcode = '55000', message = 'owner_access_cannot_be_blocked_here';
    end if;

    if target_actor_id is not null then
      update public.actor_profiles set status = 'disabled' where id = target_actor_id;
      update public.staff_assignments as assignment
      set revoked_at = statement_timestamp(), revocation_request_id = p_request_id
      from public.staff_roles as role
      where assignment.actor_id = target_actor_id
        and assignment.staff_role_id = role.id
        and role.code = 'agent'
        and assignment.revoked_at is null;
    end if;

    update public.staff_access_requests
    set status = 'blocked',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = null,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = version + 1
    where id = access_request.id
    returning * into access_request;
  end if;

  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'access.request_reviewed',
    'staff_access_request',
    access_request.id,
    jsonb_build_object(
      'staff_access_request_id', access_request.id,
      'status', access_request.status,
      'actor_id', access_request.approved_actor_id,
      'reviewed_by_actor_id', reviewer_id
    ),
    'access.request_reviewed:' || p_request_id::text
  );

  return query select access_request.id, access_request.status,
    access_request.approved_actor_id, access_request.version;
end;
$$;

create function public.get_staff_license_application_review_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform 1 from private.require_staff_permission('license.application.review');

  return jsonb_build_object(
    'generated_at', statement_timestamp(),
    'applications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', application.id,
        'reference', application.public_reference,
        'type', application.application_type,
        'applicant_name', application.applicant_name,
        'contact_label', application.contact_label,
        'class_name', license_class.public_display_name,
        'jurisdiction_name', jurisdiction.public_name,
        'statement', application.statement,
        'status', application.status,
        'version', application.version,
        'submitted_at', application.submitted_at,
        'reviewed_at', application.reviewed_at,
        'review_reason', application.review_reason,
        'existing_license_reference', existing_license.public_reference,
        'issued_license_reference', issued_license.public_reference,
        'requested_endorsements', coalesce((
          select jsonb_agg(jsonb_build_object(
            'code', definition.code,
            'label', definition.public_display_name
          ) order by definition.public_display_name)
          from public.license_application_endorsements as requested
          join public.endorsement_definitions as definition
            on definition.id = requested.endorsement_definition_id
          where requested.application_id = application.id
        ), '[]'::jsonb)
      ) order by
        case when application.status in ('submitted', 'under_review') then 0 else 1 end,
        application.submitted_at desc
      )
      from public.license_applications as application
      join public.license_classes as license_class
        on license_class.id = application.requested_license_class_id
      join public.jurisdictions as jurisdiction
        on jurisdiction.id = application.requested_jurisdiction_id
      left join public.licenses as existing_license
        on existing_license.id = application.existing_license_id
      left join public.licenses as issued_license
        on issued_license.id = application.issued_license_id
      where application.status in ('submitted', 'under_review')
        or application.reviewed_at >= statement_timestamp() - interval '90 days'
    ), '[]'::jsonb),
    'parties', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', party.id,
        'name', party.display_name,
        'type', party_type.display_name
      ) order by party.display_name)
      from public.parties as party
      join public.party_types as party_type on party_type.id = party.party_type_id
      where party.status = 'active'
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.get_staff_command_dashboard()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$ begin
  perform 1 from private.require_staff_permission('dashboard.read');
  return jsonb_build_object(
    'generated_at',statement_timestamp(),
    'capabilities',jsonb_build_object(
      'can_manage_access',private.staff_has_permission('access.assignment.manage'),
      'can_review_applications',private.staff_has_permission('license.application.review')),
    'access',jsonb_build_object(
      'requests_pending',case when private.staff_has_permission('access.assignment.manage')
        then (select count(*) from public.staff_access_requests where status='pending') else 0 end),
    'orders',jsonb_build_object(
      'submitted',(select count(*) from public.orders where status='submitted'),
      'under_review',(select count(*) from public.orders where status='under_review'),
      'awaiting_stock',(select count(*) from public.orders where status='awaiting_stock'),
      'processing',(select count(*) from public.orders where status='processing'),
      'direct_this_week',(select count(*) from public.orders where source_channel='direct_individual' and submitted_at>=date_trunc('week',statement_timestamp()))),
    'inventory',jsonb_build_object(
      'critical_reserves',(select count(*) from public.item_supply_policies policy where policy.critical_level is not null and coalesce((
        select sum(entry.quantity_delta) from public.inventory_ledger_entries entry join public.inventory_accounts account on account.id=entry.inventory_account_id
        where entry.item_id=policy.item_id and account.account_kind='physical'),0)<=policy.critical_level),
      'expired_reservations',(select count(*) from public.reservations where status='active' and expires_at<=statement_timestamp()),
      'asset_exceptions',(select count(*) from public.serialized_assets where status in ('missing','damaged','seized'))),
    'licensing',jsonb_build_object(
      'applications_pending',(select count(*) from public.license_applications where status in ('submitted','under_review')),
      'active_licenses',(select count(*) from public.licenses license join public.license_status_definitions status on status.id=license.status_definition_id where status.confers_authority and (license.expires_at is null or license.expires_at>statement_timestamp())),
      'expiring_30_days',(select count(*) from public.licenses where expires_at between statement_timestamp() and statement_timestamp()+interval '30 days')),
    'finance',jsonb_build_object(
      'settlements_pending',(select count(*) from public.consignment_settlements where status='pending'),
      'procurement_payments_pending',(select count(*) from public.procurement_deliveries where settlement_status='pending')),
    'compliance',jsonb_build_object(
      'open_cases',(select count(*) from public.compliance_cases where status not in ('resolved','no_action','closed')),
      'actions_pending',(select count(*) from public.compliance_actions where status='recommended')),
    'integrations',jsonb_build_object(
      'outbox_failed',(select count(*) from public.outbox_events where status='failed'),
      'deliveries_failed',(select count(*) from public.integration_deliveries where status='failed'),
      'exports_failed',(select count(*) from public.export_runs where status='failed')),
    'documents',jsonb_build_object('generated_7_days',(select count(*) from public.generated_documents where generated_at>=statement_timestamp()-interval '7 days')),
    'recent_orders',coalesce((select jsonb_agg(row_data) from (select jsonb_build_object('id',order_item.id,'reference',order_item.public_reference,
      'customer',party.display_name,'channel',order_item.source_channel,'status',order_item.status,'submitted_at',order_item.submitted_at) row_data
      from public.orders order_item join public.parties party on party.id=order_item.ordering_party_id order by order_item.submitted_at desc limit 8) recent),'[]'::jsonb),
    'recent_audit',case when private.staff_has_permission('audit.private.read') then coalesce((select jsonb_agg(row_data) from (
      select jsonb_build_object('id',audit.id,'action',audit.action,'record_type',audit.record_type,'occurred_at',audit.occurred_at,'reason',audit.reason) row_data
      from public.audit_log audit order by audit.occurred_at desc limit 12) recent),'[]'::jsonb) else '[]'::jsonb end
  );
end $$;

insert into public.notification_templates (
  code, event_type, destination_type, message_template
)
values
  (
    'staff-access-requested-v1',
    'access.request_submitted',
    'discord_channel',
    'A Discord identity requested staff access. Review the pending request in the owner access workspace.'
  ),
  (
    'staff-access-reviewed-v1',
    'access.request_reviewed',
    'discord_channel',
    'A staff access request was reviewed. Status: {{status}}.'
  )
on conflict (event_type, destination_type, template_version) do nothing;

insert into public.integration_event_routes (
  event_type, destination_id, notification_template_id, active
)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type in ('access.request_submitted', 'access.request_reviewed')
on conflict (event_type, destination_id) do update
set notification_template_id = excluded.notification_template_id,
    active = true;

revoke all on function public.get_my_staff_access_state() from public, anon;
revoke all on function public.register_staff_access_request(uuid) from public, anon;
revoke all on function public.get_owner_access_workspace() from public, anon;
revoke all on function public.owner_review_staff_access_request(uuid,bigint,text,text,uuid) from public, anon;
revoke all on function public.get_staff_license_application_review_workspace() from public, anon;

grant execute on function public.get_my_staff_access_state() to authenticated;
grant execute on function public.register_staff_access_request(uuid) to authenticated;
grant execute on function public.get_owner_access_workspace() to authenticated;
grant execute on function public.owner_review_staff_access_request(uuid,bigint,text,text,uuid) to authenticated;
grant execute on function public.get_staff_license_application_review_workspace() to authenticated;
