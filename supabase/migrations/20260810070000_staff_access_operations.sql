alter table public.staff_assignments
  add column source_request_id uuid unique,
  add column revocation_request_id uuid unique;

insert into public.permission_scopes (code, display_name, description)
values
  ('access.private.read', 'Read staff access', 'Read staff actors, assignable roles, effective assignments, and permission composition.'),
  ('access.assignment.manage', 'Manage staff assignments', 'Grant and revoke effective-dated staff role assignments.'),
  ('audit.private.read', 'Read private audit history', 'Read restricted audit entries for independent operational review.'),
  ('operations.health.read', 'Read operational health', 'Read policy-neutral counts for expired work, failed projections, and open operational queues.');

insert into public.staff_roles (code, display_name, description, is_elevated)
values (
  'platform_administrator',
  'Platform administrator',
  'May administer staff authority and review private operational health and audit evidence.',
  true
);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'platform_administrator'
  and permission.code in (
    'access.private.read', 'access.assignment.manage',
    'audit.private.read', 'operations.health.read'
  );

create function private.active_platform_administrator_count()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct assignment.actor_id)
  from public.staff_assignments as assignment
  join public.staff_roles as role on role.id = assignment.staff_role_id
  join public.actor_profiles as actor on actor.id = assignment.actor_id
  where role.code = 'platform_administrator'
    and role.active
    and actor.status = 'active'
    and assignment.revoked_at is null
    and assignment.effective_from <= statement_timestamp()
    and (assignment.effective_until is null or assignment.effective_until > statement_timestamp());
$$;

create function public.get_staff_operations_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  can_read_audit boolean;
begin
  if not private.staff_has_permission('access.private.read')
    or not private.staff_has_permission('operations.health.read')
  then
    raise exception using errcode = '42501', message = 'staff_permission_denied';
  end if;

  can_read_audit := private.staff_has_permission('audit.private.read');

  return jsonb_build_object(
    'generated_at', statement_timestamp(),
    'capabilities', jsonb_build_object(
      'can_manage_assignments', private.staff_has_permission('access.assignment.manage'),
      'can_read_audit', can_read_audit
    ),
    'health', jsonb_build_object(
      'outbox_pending', (select count(*) from public.outbox_events where status = 'pending' and available_at <= statement_timestamp()),
      'outbox_failed', (select count(*) from public.outbox_events where status = 'failed'),
      'delivery_failed', (select count(*) from public.integration_deliveries where status = 'failed'),
      'delivery_lease_expired', (select count(*) from public.integration_deliveries where status = 'processing' and lease_expires_at <= statement_timestamp()),
      'export_failed', (select count(*) from public.export_runs where status = 'failed'),
      'export_lease_expired', (select count(*) from public.export_runs where status = 'processing' and lease_expires_at <= statement_timestamp()),
      'export_definitions_overdue', (select count(*) from public.export_definitions where active and next_run_at < statement_timestamp()),
      'reservations_expired_active', (select count(*) from public.reservations where status = 'active' and expires_at <= statement_timestamp()),
      'asset_reservations_expired_active', (select count(*) from public.asset_reservations where status = 'active' and expires_at <= statement_timestamp()),
      'transfers_in_transit', (select count(*) from public.stock_transfers where status in ('dispatched', 'disputed')),
      'compliance_open', (select count(*) from public.compliance_cases where status not in ('resolved', 'no_action', 'closed'))
    ),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', role.id,
        'code', role.code,
        'display_name', role.display_name,
        'description', role.description,
        'is_elevated', role.is_elevated,
        'permissions', coalesce((
          select jsonb_agg(jsonb_build_object(
            'code', permission.code,
            'display_name', permission.display_name
          ) order by permission.code)
          from public.staff_role_permissions as role_permission
          join public.permission_scopes as permission
            on permission.id = role_permission.permission_scope_id
          where role_permission.staff_role_id = role.id and permission.active
        ), '[]'::jsonb)
      ) order by role.display_name)
      from public.staff_roles as role
      where role.active and role.is_assignable
    ), '[]'::jsonb),
    'actors', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', actor.id,
        'display_name', actor.display_name,
        'status', actor.status,
        'assignments', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', assignment.id,
            'role_id', role.id,
            'role_code', role.code,
            'role_name', role.display_name,
            'is_elevated', role.is_elevated,
            'effective_from', assignment.effective_from,
            'effective_until', assignment.effective_until,
            'revoked_at', assignment.revoked_at,
            'assignment_scope', assignment.assignment_scope,
            'active_now', assignment.revoked_at is null
              and assignment.effective_from <= statement_timestamp()
              and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
          ) order by assignment.effective_from desc, assignment.id)
          from public.staff_assignments as assignment
          join public.staff_roles as role on role.id = assignment.staff_role_id
          where assignment.actor_id = actor.id
        ), '[]'::jsonb)
      ) order by actor.display_name)
      from public.actor_profiles as actor
      where actor.actor_type = 'staff'
    ), '[]'::jsonb),
    'recent_access_audit', case when can_read_audit then coalesce((
      select jsonb_agg(to_jsonb(entry) order by entry.created_at desc, entry.id desc)
      from (
        select audit.id, audit.action, audit.record_type, audit.record_id,
          audit.actor_id, actor.display_name as actor_name,
          audit.previous_state, audit.new_state, audit.reason,
          audit.request_id, audit.source_surface, audit.occurred_at as created_at
        from public.audit_log as audit
        left join public.actor_profiles as actor on actor.id = audit.actor_id
        where audit.record_type in ('public.staff_assignments', 'public.actor_profiles', 'public.staff_roles', 'public.staff_role_permissions')
        order by audit.occurred_at desc, audit.id desc
        limit 100
      ) as entry
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

create function public.staff_grant_role_assignment(
  p_actor_id uuid,
  p_staff_role_id uuid,
  p_effective_from timestamptz,
  p_effective_until timestamptz,
  p_assignment_scope jsonb,
  p_reason text,
  p_request_id uuid
)
returns table (staff_assignment_id uuid, effective_from timestamptz, effective_until timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  author_actor_id uuid;
  existing_record record;
  created_record record;
begin
  author_actor_id := private.set_staff_audit_context(
    'access.assignment.manage', p_reason, p_request_id, 'staff_operations'
  );

  select assignment.id, assignment.effective_from, assignment.effective_until
  into existing_record
  from public.staff_assignments as assignment
  where assignment.source_request_id = p_request_id;
  if found then
    return query select existing_record.id, existing_record.effective_from, existing_record.effective_until;
    return;
  end if;

  if p_effective_from is null
    or (p_effective_until is not null and p_effective_until <= p_effective_from)
    or p_assignment_scope is null
    or jsonb_typeof(p_assignment_scope) <> 'object'
  then
    raise exception using errcode = '22023', message = 'staff_assignment_invalid';
  end if;

  if not exists (
    select 1 from public.actor_profiles as actor
    where actor.id = p_actor_id and actor.actor_type = 'staff' and actor.status = 'active'
  ) then
    raise exception using errcode = 'P0002', message = 'staff_actor_not_found';
  end if;

  if not exists (
    select 1 from public.staff_roles as role
    where role.id = p_staff_role_id and role.active and role.is_assignable
  ) then
    raise exception using errcode = 'P0002', message = 'staff_role_not_found';
  end if;

  insert into public.staff_assignments as inserted (
    actor_id, staff_role_id, effective_from, effective_until,
    assignment_scope, source_request_id
  ) values (
    p_actor_id, p_staff_role_id, p_effective_from, p_effective_until,
    p_assignment_scope, p_request_id
  )
  returning inserted.id, inserted.effective_from, inserted.effective_until
  into created_record;

  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'access.assignment_granted', 'staff_assignment', created_record.id,
    jsonb_build_object(
      'staff_assignment_id', created_record.id,
      'actor_id', p_actor_id,
      'staff_role_id', p_staff_role_id,
      'effective_from', created_record.effective_from,
      'effective_until', created_record.effective_until,
      'changed_by_actor_id', author_actor_id
    ),
    'access.assignment_granted:' || p_request_id::text
  );

  return query select created_record.id, created_record.effective_from, created_record.effective_until;
exception
  when exclusion_violation or unique_violation then
    raise exception using errcode = '23P01', message = 'staff_assignment_conflict';
end;
$$;

create function public.staff_revoke_role_assignment(
  p_staff_assignment_id uuid,
  p_reason text,
  p_request_id uuid
)
returns table (staff_assignment_id uuid, revoked_at timestamptz)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  author_actor_id uuid;
  assignment_record record;
  revoked_time timestamptz;
begin
  author_actor_id := private.set_staff_audit_context(
    'access.assignment.manage', p_reason, p_request_id, 'staff_operations'
  );

  select assignment.id, assignment.actor_id, assignment.revoked_at,
    assignment.revocation_request_id, assignment.effective_from,
    assignment.effective_until, role.code as role_code
  into assignment_record
  from public.staff_assignments as assignment
  join public.staff_roles as role on role.id = assignment.staff_role_id
  where assignment.id = p_staff_assignment_id
  for update of assignment;

  if not found then
    raise exception using errcode = 'P0002', message = 'staff_assignment_not_found';
  end if;

  if assignment_record.revoked_at is not null then
    if assignment_record.revocation_request_id = p_request_id then
      return query select assignment_record.id, assignment_record.revoked_at;
      return;
    end if;
    raise exception using errcode = '22023', message = 'staff_assignment_already_revoked';
  end if;

  if assignment_record.role_code = 'platform_administrator'
    and assignment_record.effective_from <= statement_timestamp()
    and (assignment_record.effective_until is null or assignment_record.effective_until > statement_timestamp())
    and private.active_platform_administrator_count() <= 1
  then
    raise exception using errcode = '55000', message = 'last_platform_administrator_required';
  end if;

  revoked_time := statement_timestamp();
  update public.staff_assignments as assignment
  set revoked_at = revoked_time, revocation_request_id = p_request_id
  where assignment.id = p_staff_assignment_id;

  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, deduplication_key
  ) values (
    'access.assignment_revoked', 'staff_assignment', assignment_record.id,
    jsonb_build_object(
      'staff_assignment_id', assignment_record.id,
      'actor_id', assignment_record.actor_id,
      'role_code', assignment_record.role_code,
      'revoked_at', revoked_time,
      'changed_by_actor_id', author_actor_id
    ),
    'access.assignment_revoked:' || p_request_id::text
  );

  return query select assignment_record.id, revoked_time;
end;
$$;

insert into public.notification_templates (code, event_type, destination_type, message_template)
values
  ('staff-access-granted-v1', 'access.assignment_granted', 'discord_channel', 'Staff authority was granted for actor {{actor_id}}.'),
  ('staff-access-revoked-v1', 'access.assignment_revoked', 'discord_channel', 'Staff authority was revoked for actor {{actor_id}}.');

insert into public.integration_event_routes (event_type, destination_id, notification_template_id, active)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type in ('access.assignment_granted', 'access.assignment_revoked');

revoke all on function private.active_platform_administrator_count() from public, anon, authenticated;
revoke all on function public.get_staff_operations_workspace() from public, anon;
revoke all on function public.staff_grant_role_assignment(uuid,uuid,timestamptz,timestamptz,jsonb,text,uuid) from public, anon;
revoke all on function public.staff_revoke_role_assignment(uuid,text,uuid) from public, anon;

grant execute on function public.get_staff_operations_workspace() to authenticated;
grant execute on function public.staff_grant_role_assignment(uuid,uuid,timestamptz,timestamptz,jsonb,text,uuid) to authenticated;
grant execute on function public.staff_revoke_role_assignment(uuid,text,uuid) to authenticated;
