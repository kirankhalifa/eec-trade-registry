-- Correct the Discord registration and owner-roster queries without rewriting
-- migration history that has already been applied to production.

create or replace function public.register_staff_access_request(p_request_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  authenticated_user_id uuid := auth.uid();
  discord_identity record;
  request_record public.staff_access_requests%rowtype;
  actor_record record;
  normalized_name text;
  created_request boolean := false;
begin
  if authenticated_user_id is null then
    raise exception using errcode = '28000', message = 'staff_authentication_required';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'request_id_required';
  end if;

  select identity.id, identity.provider_id, identity.identity_data
  into discord_identity
  from auth.identities as identity
  where identity.user_id = authenticated_user_id and identity.provider = 'discord'
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
    'Discord user ' || right(authenticated_user_id::text, 8)
  ), 200);

  perform set_config('app.request_id', p_request_id::text, true);
  perform set_config('app.correlation_id', p_request_id::text, true);
  perform set_config('app.source_surface', 'staff_oauth', true);
  perform set_config('app.audit_reason', 'Discord identity requested staff access.', true);

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(authenticated_user_id::text, 0)
  );

  select profile.id, profile.display_name
  into actor_record
  from public.actor_profiles as profile
  where profile.auth_user_id = authenticated_user_id
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

  select access_request.* into request_record
  from public.staff_access_requests as access_request
  where access_request.auth_user_id = authenticated_user_id
  for update;

  if found then
    update public.staff_access_requests as access_request
    set last_attempted_at = greatest(statement_timestamp(), access_request.requested_at),
        discord_user_id = coalesce(
          nullif(discord_identity.identity_data ->> 'sub', ''),
          nullif(discord_identity.provider_id, ''),
          discord_identity.id::text
        ),
        display_name = case when access_request.status = 'approved'
          then access_request.display_name else normalized_name end
    where access_request.id = request_record.id
    returning access_request.* into request_record;
  else
    insert into public.staff_access_requests (
      auth_user_id, discord_user_id, display_name, status,
      approved_actor_id, first_request_id
    ) values (
      authenticated_user_id,
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

create or replace function public.get_owner_access_workspace()
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
        'id', access_request.id,
        'display_name', access_request.display_name,
        'discord_user_id', access_request.discord_user_id,
        'status', access_request.status,
        'requested_at', access_request.requested_at,
        'last_attempted_at', access_request.last_attempted_at,
        'reviewed_at', access_request.reviewed_at,
        'review_reason', access_request.review_reason,
        'protected_owner', exists (
          select 1
          from public.staff_assignments as protected_assignment
          join public.staff_roles as protected_role
            on protected_role.id = protected_assignment.staff_role_id
          where protected_assignment.actor_id = access_request.approved_actor_id
            and protected_role.code in ('owner', 'platform_administrator')
            and protected_assignment.revoked_at is null
            and protected_assignment.effective_from <= statement_timestamp()
            and (protected_assignment.effective_until is null or protected_assignment.effective_until > statement_timestamp())
        ),
        'version', access_request.version
      ) order by
        case access_request.status when 'pending' then 0 when 'denied' then 1 when 'blocked' then 2 else 3 end,
        access_request.requested_at desc
      )
      from public.staff_access_requests as access_request
    ), '[]'::jsonb),
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'actor_id', staff_member.actor_id,
        'display_name', staff_member.display_name,
        'status', staff_member.status,
        'access_class', staff_member.access_class,
        'active_since', staff_member.active_since,
        'discord_user_id', staff_member.discord_user_id
      ) order by staff_member.display_name)
      from (
        select
          actor.id as actor_id,
          actor.display_name,
          actor.status,
          case when bool_or(role.code in ('owner', 'platform_administrator'))
            then 'owner' else 'agent' end as access_class,
          min(assignment.effective_from) as active_since,
          max(access_request.discord_user_id) as discord_user_id
        from public.actor_profiles as actor
        join public.staff_assignments as assignment
          on assignment.actor_id = actor.id
          and assignment.revoked_at is null
          and assignment.effective_from <= statement_timestamp()
          and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
        join public.staff_roles as role on role.id = assignment.staff_role_id and role.active
        left join public.staff_access_requests as access_request
          on access_request.auth_user_id = actor.auth_user_id
        where actor.actor_type = 'staff' and actor.status = 'active'
        group by actor.id, actor.display_name, actor.status
      ) as staff_member
    ), '[]'::jsonb)
  );
end;
$$;
