-- Qualify optimistic-lock updates so the table's version column cannot be
-- confused with the function's returned version column.

create or replace function public.owner_review_staff_access_request(
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

    update public.staff_access_requests as stored_request
    set status = 'approved',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = target_actor_id,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = stored_request.version + 1
    where stored_request.id = access_request.id
    returning stored_request.* into access_request;
  elsif p_decision = 'deny' then
    update public.staff_access_requests as stored_request
    set status = 'denied',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = null,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = stored_request.version + 1
    where stored_request.id = access_request.id
    returning stored_request.* into access_request;
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

    update public.staff_access_requests as stored_request
    set status = 'blocked',
        reviewed_at = statement_timestamp(),
        reviewed_by_actor_id = reviewer_id,
        approved_actor_id = null,
        review_reason = btrim(p_reason),
        review_request_id = p_request_id,
        version = stored_request.version + 1
    where stored_request.id = access_request.id
    returning stored_request.* into access_request;
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
