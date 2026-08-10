create table public.compliance_case_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.compliance_violation_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.compliance_action_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null default '',
  effect_mode text not null default 'record_only' check (effect_mode = 'record_only'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.compliance_cases (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  case_type_id uuid not null references public.compliance_case_types(id) on delete restrict,
  subject_party_id uuid references public.parties(id) on delete restrict,
  related_record_type text not null default 'none' check (related_record_type in (
    'none', 'license', 'dealer_authorization', 'order', 'stock_transfer',
    'serialized_asset', 'consignment_issue'
  )),
  related_record_id uuid,
  status text not null default 'open' check (status in (
    'open', 'triage', 'investigating', 'awaiting_response', 'deciding',
    'resolved', 'no_action', 'closed', 'reopened'
  )),
  confidentiality_level text not null default 'internal'
    check (confidentiality_level in ('internal', 'restricted')),
  summary text not null check (btrim(summary) <> '' and char_length(summary) <= 4000),
  assigned_actor_id uuid references public.actor_profiles(id) on delete restrict,
  opened_at timestamptz not null default now(),
  opened_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  resolution text,
  resolved_at timestamptz,
  closed_at timestamptz,
  source_request_id uuid not null unique,
  transition_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((related_record_type = 'none') = (related_record_id is null)),
  check (resolution is null or (btrim(resolution) <> '' and char_length(resolution) <= 4000)),
  check ((status in ('resolved', 'no_action', 'closed')) = (resolved_at is not null)),
  check ((status = 'closed') = (closed_at is not null)),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128)
);

create table public.compliance_inspections (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  status text not null default 'planned' check (status in ('planned', 'completed', 'cancelled')),
  scheduled_for timestamptz,
  location_summary text not null default '' check (char_length(location_summary) <= 1000),
  scope_summary text not null check (btrim(scope_summary) <> '' and char_length(scope_summary) <= 4000),
  observations text,
  completed_at timestamptz,
  created_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  completed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  completion_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (observations is null or (btrim(observations) <> '' and char_length(observations) <= 4000)),
  check ((status = 'completed') = (completed_at is not null)),
  check ((status = 'completed') = (completed_by_actor_id is not null)),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.compliance_allegations (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  violation_type_id uuid not null references public.compliance_violation_types(id) on delete restrict,
  status text not null default 'alleged' check (status = 'alleged'),
  statement text not null check (btrim(statement) <> '' and char_length(statement) <= 4000),
  recorded_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  recorded_at timestamptz not null default now()
);

create table public.compliance_findings (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  allegation_id uuid references public.compliance_allegations(id) on delete restrict,
  outcome text not null check (outcome in ('substantiated', 'not_substantiated', 'inconclusive')),
  rationale text not null check (btrim(rationale) <> '' and char_length(rationale) <= 4000),
  decided_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  decided_at timestamptz not null default now()
);

create table public.compliance_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  inspection_id uuid references public.compliance_inspections(id) on delete restrict,
  evidence_type text not null check (evidence_type in ('document', 'image', 'statement', 'system_record', 'other')),
  confidentiality_level text not null default 'restricted'
    check (confidentiality_level in ('internal', 'restricted')),
  evidence_reference text not null check (btrim(evidence_reference) <> '' and char_length(evidence_reference) <= 500),
  description text not null check (btrim(description) <> '' and char_length(description) <= 4000),
  collected_at timestamptz not null,
  recorded_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  recorded_at timestamptz not null default now()
);

create table public.compliance_actions (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  action_type_id uuid not null references public.compliance_action_types(id) on delete restrict,
  subject_party_id uuid references public.parties(id) on delete restrict,
  related_record_type text not null default 'none' check (related_record_type in (
    'none', 'license', 'dealer_authorization', 'order', 'stock_transfer',
    'serialized_asset', 'consignment_issue'
  )),
  related_record_id uuid,
  status text not null default 'recommended'
    check (status in ('recommended', 'approved', 'declined', 'voided')),
  recommendation text not null check (btrim(recommendation) <> '' and char_length(recommendation) <= 4000),
  recommended_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  recommended_at timestamptz not null default now(),
  reviewed_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_reason text,
  effect_applied boolean not null default false check (not effect_applied),
  source_request_id uuid not null unique,
  review_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((related_record_type = 'none') = (related_record_id is null)),
  check (
    (status = 'recommended' and reviewed_by_actor_id is null and reviewed_at is null and review_reason is null)
    or (status in ('approved', 'declined', 'voided') and reviewed_by_actor_id is not null
      and reviewed_at is not null and btrim(review_reason) <> '')
  ),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.compliance_appeals (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  compliance_action_id uuid not null references public.compliance_actions(id) on delete restrict,
  appellant_party_id uuid not null references public.parties(id) on delete restrict,
  status text not null default 'filed' check (status in ('filed', 'decided', 'withdrawn')),
  filing_summary text not null check (btrim(filing_summary) <> '' and char_length(filing_summary) <= 4000),
  filed_at timestamptz not null default now(),
  recorded_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  outcome text check (outcome in ('affirmed', 'varied', 'remanded', 'reversed')),
  decision_reason text,
  decided_at timestamptz,
  decided_by_actor_id uuid references public.actor_profiles(id) on delete restrict,
  source_request_id uuid not null unique,
  decision_request_id uuid unique,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'filed' and outcome is null and decision_reason is null and decided_at is null and decided_by_actor_id is null)
    or (status = 'decided' and outcome is not null and btrim(decision_reason) <> '' and decided_at is not null and decided_by_actor_id is not null)
    or (status = 'withdrawn' and outcome is null and btrim(decision_reason) <> '' and decided_at is not null and decided_by_actor_id is not null)
  ),
  check (public_reference = private.normalize_registry_reference(public_reference))
);

create table public.compliance_events (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null references public.compliance_cases(id) on delete restrict,
  event_type text not null check (event_type in (
    'case_opened', 'case_transitioned', 'inspection_planned', 'inspection_completed',
    'inspection_cancelled', 'allegation_recorded', 'evidence_recorded', 'finding_recorded',
    'action_recommended', 'action_reviewed', 'appeal_filed', 'appeal_decided', 'appeal_withdrawn'
  )),
  related_record_type text,
  related_record_id uuid,
  previous_state jsonb,
  new_state jsonb not null,
  changed_by_actor_id uuid not null references public.actor_profiles(id) on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  request_id uuid not null unique,
  occurred_at timestamptz not null default now()
);

create index compliance_cases_status_idx on public.compliance_cases(status, opened_at desc);
create index compliance_cases_subject_idx on public.compliance_cases(subject_party_id, opened_at desc);
create index compliance_inspections_case_idx on public.compliance_inspections(compliance_case_id, status, scheduled_for);
create index compliance_allegations_case_idx on public.compliance_allegations(compliance_case_id, recorded_at);
create index compliance_findings_case_idx on public.compliance_findings(compliance_case_id, decided_at);
create index compliance_evidence_case_idx on public.compliance_evidence(compliance_case_id, recorded_at);
create index compliance_actions_case_idx on public.compliance_actions(compliance_case_id, status, recommended_at);
create index compliance_appeals_case_idx on public.compliance_appeals(compliance_case_id, status, filed_at);
create index compliance_events_case_idx on public.compliance_events(compliance_case_id, occurred_at, id);

create trigger compliance_case_types_set_updated_at before update on public.compliance_case_types for each row execute function private.set_updated_at();
create trigger compliance_violation_types_set_updated_at before update on public.compliance_violation_types for each row execute function private.set_updated_at();
create trigger compliance_action_types_set_updated_at before update on public.compliance_action_types for each row execute function private.set_updated_at();
create trigger compliance_cases_set_updated_at before update on public.compliance_cases for each row execute function private.set_updated_at();
create trigger compliance_inspections_set_updated_at before update on public.compliance_inspections for each row execute function private.set_updated_at();
create trigger compliance_actions_set_updated_at before update on public.compliance_actions for each row execute function private.set_updated_at();
create trigger compliance_appeals_set_updated_at before update on public.compliance_appeals for each row execute function private.set_updated_at();

create trigger compliance_cases_audit after insert or update or delete on public.compliance_cases for each row execute function private.capture_audit_row();
create trigger compliance_inspections_audit after insert or update or delete on public.compliance_inspections for each row execute function private.capture_audit_row();
create trigger compliance_allegations_audit after insert or update or delete on public.compliance_allegations for each row execute function private.capture_audit_row();
create trigger compliance_findings_audit after insert or update or delete on public.compliance_findings for each row execute function private.capture_audit_row();
create trigger compliance_evidence_audit after insert or update or delete on public.compliance_evidence for each row execute function private.capture_audit_row();
create trigger compliance_actions_audit after insert or update or delete on public.compliance_actions for each row execute function private.capture_audit_row();
create trigger compliance_appeals_audit after insert or update or delete on public.compliance_appeals for each row execute function private.capture_audit_row();

create trigger compliance_allegations_immutable before update or delete on public.compliance_allegations for each row execute function private.reject_immutable_inventory_change();
create trigger compliance_findings_immutable before update or delete on public.compliance_findings for each row execute function private.reject_immutable_inventory_change();
create trigger compliance_evidence_immutable before update or delete on public.compliance_evidence for each row execute function private.reject_immutable_inventory_change();
create trigger compliance_events_immutable before update or delete on public.compliance_events for each row execute function private.reject_immutable_inventory_change();

alter table public.compliance_case_types enable row level security;
alter table public.compliance_violation_types enable row level security;
alter table public.compliance_action_types enable row level security;
alter table public.compliance_cases enable row level security;
alter table public.compliance_inspections enable row level security;
alter table public.compliance_allegations enable row level security;
alter table public.compliance_findings enable row level security;
alter table public.compliance_evidence enable row level security;
alter table public.compliance_actions enable row level security;
alter table public.compliance_appeals enable row level security;
alter table public.compliance_events enable row level security;

insert into public.compliance_case_types (code, display_name, description)
values ('general-review', 'General review', 'Policy-neutral case container pending configured institutional taxonomy.');
insert into public.compliance_violation_types (code, display_name, description)
values ('unclassified-matter', 'Unclassified matter', 'Allegation category that makes no finding or legal conclusion.');
insert into public.compliance_action_types (code, display_name, description)
values ('recorded-notice', 'Recorded notice', 'Record-only action with no automatic effect on another domain.');

insert into public.permission_scopes (code, display_name, description)
values
  ('compliance.private.read', 'Read compliance casework', 'Read private case, inspection, allegation, finding, action, appeal, and event records.'),
  ('compliance.case.manage', 'Manage compliance cases', 'Open, assign, and transition policy-neutral cases.'),
  ('compliance.inspection.manage', 'Manage compliance inspections', 'Plan, complete, or cancel compliance inspections.'),
  ('compliance.evidence.manage', 'Record compliance evidence', 'Record restricted evidence metadata without granting object-storage access.'),
  ('compliance.finding.record', 'Record compliance findings', 'Record an explicit outcome separate from an allegation.'),
  ('compliance.action.recommend', 'Recommend compliance actions', 'Recommend configured record-only actions.'),
  ('compliance.action.approve', 'Review compliance actions', 'Approve or decline record-only action recommendations.'),
  ('compliance.appeal.manage', 'Manage compliance appeals', 'Record and decide policy-neutral appeal records without automatic domain effects.');

insert into public.staff_roles (code, display_name, description, is_elevated)
values ('compliance_officer', 'Compliance officer', 'May manage private compliance casework under the policy-neutral recorded-action boundary.', true);

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
cross join public.permission_scopes as permission
where role.code = 'compliance_officer' and permission.code like 'compliance.%';

insert into public.staff_role_permissions (staff_role_id, permission_scope_id)
select role.id, permission.id
from public.staff_roles as role
join public.permission_scopes as permission on permission.code = 'compliance.private.read'
where role.code = 'auditor';

insert into public.reference_sequences (document_type, prefix, next_value, padding)
values
  ('compliance_case', 'EEC-CMP', 1001, 4),
  ('compliance_inspection', 'EEC-INSP', 1001, 4),
  ('compliance_action', 'EEC-ACT', 1001, 4),
  ('compliance_appeal', 'EEC-APL', 1001, 4);

create function private.allocate_compliance_reference(p_document_type text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare sequence_record record; allocated_reference text;
begin
  if p_document_type not in ('compliance_case', 'compliance_inspection', 'compliance_action', 'compliance_appeal') then
    raise exception using errcode = '22023', message = 'compliance_reference_type_invalid';
  end if;
  select reference.prefix, reference.next_value, reference.padding into strict sequence_record
  from public.reference_sequences as reference
  where reference.document_type = p_document_type and reference.active for update;
  allocated_reference := sequence_record.prefix || '-' || lpad(sequence_record.next_value::text, sequence_record.padding, '0');
  update public.reference_sequences as reference set next_value = reference.next_value + 1
  where reference.document_type = p_document_type;
  return allocated_reference;
exception when no_data_found then
  raise exception using errcode = '55000', message = 'compliance_reference_sequence_unavailable';
end;
$$;

create function private.compliance_related_record_exists(p_record_type text, p_record_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_record_type
    when 'none' then p_record_id is null
    when 'license' then exists (select 1 from public.licenses where id = p_record_id)
    when 'dealer_authorization' then exists (select 1 from public.dealer_authorizations where id = p_record_id)
    when 'order' then exists (select 1 from public.orders where id = p_record_id)
    when 'stock_transfer' then exists (select 1 from public.stock_transfers where id = p_record_id)
    when 'serialized_asset' then exists (select 1 from public.serialized_assets where id = p_record_id)
    when 'consignment_issue' then exists (select 1 from public.consignment_issues where id = p_record_id)
    else false
  end;
$$;

create function public.get_staff_compliance_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.staff_has_permission('compliance.private.read') then
    raise exception using errcode = '42501', message = 'staff_permission_denied';
  end if;
  return jsonb_build_object(
    'capabilities', jsonb_build_object(
      'can_manage_cases', private.staff_has_permission('compliance.case.manage'),
      'can_manage_inspections', private.staff_has_permission('compliance.inspection.manage'),
      'can_manage_evidence', private.staff_has_permission('compliance.evidence.manage'),
      'can_record_findings', private.staff_has_permission('compliance.finding.record'),
      'can_recommend_actions', private.staff_has_permission('compliance.action.recommend'),
      'can_approve_actions', private.staff_has_permission('compliance.action.approve'),
      'can_manage_appeals', private.staff_has_permission('compliance.appeal.manage')
    ),
    'case_types', coalesce((select jsonb_agg(jsonb_build_object(
      'id', type.id, 'code', type.code, 'display_name', type.display_name
    ) order by type.display_name) from public.compliance_case_types as type where type.active), '[]'::jsonb),
    'parties', coalesce((select jsonb_agg(jsonb_build_object(
      'id', party.id, 'display_name', party.display_name
    ) order by party.display_name) from public.parties as party where party.status = 'active'), '[]'::jsonb),
    'staff_actors', coalesce((select jsonb_agg(distinct jsonb_build_object(
      'id', actor.id, 'display_name', actor.display_name
    )) from public.actor_profiles as actor
      join public.staff_assignments as assignment on assignment.actor_id = actor.id
        and assignment.revoked_at is null
        and assignment.effective_from <= statement_timestamp()
        and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
      where actor.actor_type = 'staff' and actor.status = 'active'), '[]'::jsonb),
    'related_records', coalesce((select jsonb_agg(to_jsonb(related) order by related.record_type, related.label)
      from (
        select 'license'::text as record_type, license.id, license.public_reference as label from public.licenses as license
        union all select 'dealer_authorization', dealer.id, dealer.public_reference from public.dealer_authorizations as dealer
        union all select 'order', order_record.id, order_record.public_reference from public.orders as order_record
        union all select 'stock_transfer', transfer.id, transfer.public_reference from public.stock_transfers as transfer
        union all select 'serialized_asset', asset.id, asset.asset_code from public.serialized_assets as asset
        union all select 'consignment_issue', issue.id, issue.public_reference from public.consignment_issues as issue
      ) as related), '[]'::jsonb),
    'cases', coalesce((select jsonb_agg(jsonb_build_object(
      'id', case_record.id, 'public_reference', case_record.public_reference,
      'case_type', case_type.display_name, 'status', case_record.status,
      'confidentiality_level', case_record.confidentiality_level,
      'subject_party_id', case_record.subject_party_id, 'subject_name', subject.display_name,
      'related_record_type', case_record.related_record_type,
      'related_record_id', case_record.related_record_id,
      'summary', case_record.summary, 'assigned_actor_id', case_record.assigned_actor_id,
      'assigned_actor_name', assignee.display_name, 'opened_at', case_record.opened_at,
      'version', case_record.version,
      'allegation_count', (select count(*) from public.compliance_allegations as allegation where allegation.compliance_case_id = case_record.id),
      'finding_count', (select count(*) from public.compliance_findings as finding where finding.compliance_case_id = case_record.id),
      'pending_action_count', (select count(*) from public.compliance_actions as action where action.compliance_case_id = case_record.id and action.status = 'recommended'),
      'open_appeal_count', (select count(*) from public.compliance_appeals as appeal where appeal.compliance_case_id = case_record.id and appeal.status = 'filed')
    ) order by case_record.opened_at desc) from public.compliance_cases as case_record
      join public.compliance_case_types as case_type on case_type.id = case_record.case_type_id
      left join public.parties as subject on subject.id = case_record.subject_party_id
      left join public.actor_profiles as assignee on assignee.id = case_record.assigned_actor_id), '[]'::jsonb)
  );
end;
$$;

create function public.get_staff_compliance_case(p_compliance_case_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare case_payload jsonb;
begin
  if not private.staff_has_permission('compliance.private.read') then
    raise exception using errcode = '42501', message = 'staff_permission_denied';
  end if;
  select jsonb_build_object(
    'id', case_record.id, 'public_reference', case_record.public_reference,
    'case_type', case_type.display_name, 'status', case_record.status,
    'confidentiality_level', case_record.confidentiality_level,
    'subject_party_id', case_record.subject_party_id, 'subject_name', subject.display_name,
    'related_record_type', case_record.related_record_type,
    'related_record_id', case_record.related_record_id,
    'summary', case_record.summary, 'assigned_actor_id', case_record.assigned_actor_id,
    'assigned_actor_name', assignee.display_name, 'opened_at', case_record.opened_at,
    'resolution', case_record.resolution, 'version', case_record.version,
    'capabilities', jsonb_build_object(
      'can_manage_cases', private.staff_has_permission('compliance.case.manage'),
      'can_manage_inspections', private.staff_has_permission('compliance.inspection.manage'),
      'can_manage_evidence', private.staff_has_permission('compliance.evidence.manage'),
      'can_record_findings', private.staff_has_permission('compliance.finding.record'),
      'can_recommend_actions', private.staff_has_permission('compliance.action.recommend'),
      'can_approve_actions', private.staff_has_permission('compliance.action.approve'),
      'can_manage_appeals', private.staff_has_permission('compliance.appeal.manage')
    ),
    'violation_types', coalesce((select jsonb_agg(jsonb_build_object('id', type.id, 'display_name', type.display_name)
      order by type.display_name) from public.compliance_violation_types as type where type.active), '[]'::jsonb),
    'action_types', coalesce((select jsonb_agg(jsonb_build_object('id', type.id, 'display_name', type.display_name, 'effect_mode', type.effect_mode)
      order by type.display_name) from public.compliance_action_types as type where type.active), '[]'::jsonb),
    'parties', coalesce((select jsonb_agg(jsonb_build_object('id', party.id, 'display_name', party.display_name)
      order by party.display_name) from public.parties as party where party.status = 'active'), '[]'::jsonb),
    'staff_actors', coalesce((select jsonb_agg(distinct jsonb_build_object('id', actor.id, 'display_name', actor.display_name))
      from public.actor_profiles as actor join public.staff_assignments as assignment on assignment.actor_id = actor.id
      and assignment.revoked_at is null and assignment.effective_from <= statement_timestamp()
      and (assignment.effective_until is null or assignment.effective_until > statement_timestamp())
      where actor.actor_type = 'staff' and actor.status = 'active'), '[]'::jsonb),
    'inspections', coalesce((select jsonb_agg(jsonb_build_object(
      'id', inspection.id, 'public_reference', inspection.public_reference, 'status', inspection.status,
      'scheduled_for', inspection.scheduled_for, 'location_summary', inspection.location_summary,
      'scope_summary', inspection.scope_summary, 'observations', inspection.observations,
      'completed_at', inspection.completed_at, 'version', inspection.version
    ) order by inspection.created_at desc) from public.compliance_inspections as inspection where inspection.compliance_case_id = case_record.id), '[]'::jsonb),
    'allegations', coalesce((select jsonb_agg(jsonb_build_object(
      'id', allegation.id, 'violation_type', violation.display_name, 'status', allegation.status,
      'statement', allegation.statement, 'recorded_at', allegation.recorded_at
    ) order by allegation.recorded_at) from public.compliance_allegations as allegation
      join public.compliance_violation_types as violation on violation.id = allegation.violation_type_id
      where allegation.compliance_case_id = case_record.id), '[]'::jsonb),
    'findings', coalesce((select jsonb_agg(jsonb_build_object(
      'id', finding.id, 'allegation_id', finding.allegation_id, 'outcome', finding.outcome,
      'rationale', finding.rationale, 'decided_at', finding.decided_at
    ) order by finding.decided_at) from public.compliance_findings as finding where finding.compliance_case_id = case_record.id), '[]'::jsonb),
    'evidence', coalesce((select jsonb_agg(jsonb_build_object(
      'id', evidence.id, 'inspection_id', evidence.inspection_id, 'evidence_type', evidence.evidence_type,
      'confidentiality_level', evidence.confidentiality_level, 'evidence_reference', evidence.evidence_reference,
      'description', evidence.description, 'collected_at', evidence.collected_at
    ) order by evidence.recorded_at) from public.compliance_evidence as evidence where evidence.compliance_case_id = case_record.id), '[]'::jsonb),
    'actions', coalesce((select jsonb_agg(jsonb_build_object(
      'id', action.id, 'public_reference', action.public_reference, 'action_type', action_type.display_name,
      'effect_mode', action_type.effect_mode, 'subject_party_id', action.subject_party_id,
      'related_record_type', action.related_record_type, 'related_record_id', action.related_record_id,
      'status', action.status, 'recommendation', action.recommendation,
      'recommended_at', action.recommended_at, 'review_reason', action.review_reason,
      'version', action.version
    ) order by action.recommended_at desc) from public.compliance_actions as action
      join public.compliance_action_types as action_type on action_type.id = action.action_type_id
      where action.compliance_case_id = case_record.id), '[]'::jsonb),
    'appeals', coalesce((select jsonb_agg(jsonb_build_object(
      'id', appeal.id, 'public_reference', appeal.public_reference,
      'compliance_action_id', appeal.compliance_action_id, 'appellant_party_id', appeal.appellant_party_id,
      'appellant_name', appellant.display_name, 'status', appeal.status,
      'filing_summary', appeal.filing_summary, 'filed_at', appeal.filed_at,
      'outcome', appeal.outcome, 'decision_reason', appeal.decision_reason, 'version', appeal.version
    ) order by appeal.filed_at desc) from public.compliance_appeals as appeal
      join public.parties as appellant on appellant.id = appeal.appellant_party_id
      where appeal.compliance_case_id = case_record.id), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
      'event_type', event.event_type, 'previous_state', event.previous_state,
      'new_state', event.new_state, 'reason', event.reason, 'occurred_at', event.occurred_at
    ) order by event.occurred_at, event.id) from public.compliance_events as event where event.compliance_case_id = case_record.id), '[]'::jsonb)
  ) into case_payload
  from public.compliance_cases as case_record
  join public.compliance_case_types as case_type on case_type.id = case_record.case_type_id
  left join public.parties as subject on subject.id = case_record.subject_party_id
  left join public.actor_profiles as assignee on assignee.id = case_record.assigned_actor_id
  where case_record.id = p_compliance_case_id;
  if case_payload is null then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  return case_payload;
end;
$$;

create function public.staff_create_compliance_case(
  p_case_type_id uuid, p_subject_party_id uuid, p_related_record_type text,
  p_related_record_id uuid, p_confidentiality_level text, p_summary text,
  p_assigned_actor_id uuid, p_reason text, p_request_id uuid
)
returns table (compliance_case_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; existing_record record; created_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('compliance.case.manage', p_reason, p_request_id);
  select case_record.id, case_record.public_reference, case_record.version, case_record.status into existing_record
  from public.compliance_cases as case_record where case_record.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.public_reference, existing_record.version, existing_record.status; return; end if;
  if p_confidentiality_level not in ('internal', 'restricted')
    or btrim(coalesce(p_summary, '')) = '' or char_length(p_summary) > 4000
    or not private.compliance_related_record_exists(coalesce(p_related_record_type, 'none'), p_related_record_id)
  then raise exception using errcode = '22023', message = 'compliance_case_invalid'; end if;
  if not exists (select 1 from public.compliance_case_types as type where type.id = p_case_type_id and type.active)
  then raise exception using errcode = 'P0002', message = 'compliance_case_type_not_found'; end if;
  if p_subject_party_id is not null and not exists (select 1 from public.parties as party where party.id = p_subject_party_id)
  then raise exception using errcode = 'P0002', message = 'compliance_subject_not_found'; end if;
  if p_assigned_actor_id is not null and not exists (select 1 from public.actor_profiles as assignee where assignee.id = p_assigned_actor_id and assignee.actor_type = 'staff' and assignee.status = 'active')
  then raise exception using errcode = 'P0002', message = 'compliance_assignee_not_found'; end if;
  created_reference := private.allocate_compliance_reference('compliance_case');
  insert into public.compliance_cases (
    public_reference, case_type_id, subject_party_id, related_record_type, related_record_id,
    confidentiality_level, summary, assigned_actor_id, opened_by_actor_id, source_request_id
  ) values (
    created_reference, p_case_type_id, p_subject_party_id, coalesce(p_related_record_type, 'none'), p_related_record_id,
    p_confidentiality_level, btrim(p_summary), p_assigned_actor_id, actor_id, p_request_id
  ) returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, new_state, changed_by_actor_id, reason, request_id
  ) values (
    created_id, 'case_opened', jsonb_build_object('status', 'open', 'confidentiality_level', p_confidentiality_level),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values ('compliance.case_opened', 'compliance_case', created_id,
    jsonb_build_object('public_reference', created_reference, 'status', 'open'),
    'compliance.case_opened:' || p_request_id::text);
  return query select created_id, created_reference, 1::bigint, 'open'::text;
end;
$$;

create function public.staff_transition_compliance_case(
  p_compliance_case_id uuid, p_expected_version bigint, p_status text,
  p_assigned_actor_id uuid, p_resolution text, p_reason text, p_request_id uuid
)
returns table (compliance_case_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; case_record record; previous_status text; next_resolution text;
begin
  actor_id := private.set_staff_audit_context('compliance.case.manage', p_reason, p_request_id);
  select case_item.* into case_record from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_record.transition_request_id = p_request_id then return query select case_record.id, case_record.version, case_record.status; return; end if;
  select case_item.* into case_record from public.compliance_cases as case_item where case_item.id = p_compliance_case_id for update;
  if case_record.version <> p_expected_version then raise exception using errcode = '40001', message = 'compliance_case_version_conflict'; end if;
  previous_status := case_record.status;
  if not (
    (previous_status = 'open' and p_status in ('triage', 'investigating', 'no_action'))
    or (previous_status = 'triage' and p_status in ('investigating', 'awaiting_response', 'no_action'))
    or (previous_status = 'investigating' and p_status in ('awaiting_response', 'deciding', 'no_action'))
    or (previous_status = 'awaiting_response' and p_status in ('investigating', 'deciding', 'no_action'))
    or (previous_status = 'deciding' and p_status in ('resolved', 'no_action'))
    or (previous_status in ('resolved', 'no_action') and p_status = 'closed')
    or (previous_status = 'closed' and p_status = 'reopened')
    or (previous_status = 'reopened' and p_status in ('triage', 'investigating'))
  ) then raise exception using errcode = '22023', message = 'compliance_case_transition_invalid'; end if;
  if p_assigned_actor_id is not null and not exists (select 1 from public.actor_profiles as assignee where assignee.id = p_assigned_actor_id and assignee.actor_type = 'staff' and assignee.status = 'active')
  then raise exception using errcode = 'P0002', message = 'compliance_assignee_not_found'; end if;
  if p_status in ('resolved', 'no_action') and btrim(coalesce(p_resolution, '')) = ''
  then raise exception using errcode = '22023', message = 'compliance_resolution_required'; end if;
  next_resolution := case when p_status = 'reopened' then null when p_status in ('resolved', 'no_action') then btrim(p_resolution) else case_record.resolution end;
  update public.compliance_cases as case_item set
    status = p_status, assigned_actor_id = p_assigned_actor_id,
    resolution = next_resolution,
    resolved_at = case when p_status in ('resolved', 'no_action') then statement_timestamp() when p_status = 'reopened' then null else case_item.resolved_at end,
    closed_at = case when p_status = 'closed' then statement_timestamp() when p_status = 'reopened' then null else case_item.closed_at end,
    transition_request_id = p_request_id, version = case_item.version + 1
  where case_item.id = p_compliance_case_id returning case_item.* into case_record;
  insert into public.compliance_events (
    compliance_case_id, event_type, previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    case_record.id, 'case_transitioned', jsonb_build_object('status', previous_status),
    jsonb_build_object('status', p_status, 'assigned_actor_id', p_assigned_actor_id, 'resolution', next_resolution),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values ('compliance.case_transitioned', 'compliance_case', case_record.id,
    jsonb_build_object('public_reference', case_record.public_reference, 'previous_status', previous_status, 'status', p_status),
    'compliance.case_transitioned:' || p_request_id::text);
  return query select case_record.id, case_record.version, case_record.status;
end;
$$;

create function public.staff_create_compliance_inspection(
  p_compliance_case_id uuid, p_scheduled_for timestamptz,
  p_location_summary text, p_scope_summary text, p_reason text, p_request_id uuid
)
returns table (inspection_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; case_record record; existing_record record; created_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('compliance.inspection.manage', p_reason, p_request_id);
  select inspection.id, inspection.public_reference, inspection.version, inspection.status into existing_record
  from public.compliance_inspections as inspection where inspection.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.public_reference, existing_record.version, existing_record.status; return; end if;
  select case_item.* into case_record from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_record.status in ('resolved', 'no_action', 'closed')
    or btrim(coalesce(p_scope_summary, '')) = '' or char_length(p_scope_summary) > 4000
    or char_length(coalesce(p_location_summary, '')) > 1000
  then raise exception using errcode = '22023', message = 'compliance_inspection_invalid'; end if;
  created_reference := private.allocate_compliance_reference('compliance_inspection');
  insert into public.compliance_inspections (
    public_reference, compliance_case_id, scheduled_for, location_summary,
    scope_summary, created_by_actor_id, source_request_id
  ) values (
    created_reference, p_compliance_case_id, p_scheduled_for, coalesce(btrim(p_location_summary), ''),
    btrim(p_scope_summary), actor_id, p_request_id
  ) returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    p_compliance_case_id, 'inspection_planned', 'compliance_inspection', created_id,
    jsonb_build_object('status', 'planned', 'scheduled_for', p_scheduled_for),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select created_id, created_reference, 1::bigint, 'planned'::text;
end;
$$;

create function public.staff_finish_compliance_inspection(
  p_inspection_id uuid, p_expected_version bigint, p_status text,
  p_observations text, p_reason text, p_request_id uuid
)
returns table (inspection_id uuid, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; inspection_record record;
begin
  actor_id := private.set_staff_audit_context('compliance.inspection.manage', p_reason, p_request_id);
  select inspection.* into inspection_record from public.compliance_inspections as inspection where inspection.id = p_inspection_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_inspection_not_found'; end if;
  if inspection_record.completion_request_id = p_request_id then return query select inspection_record.id, inspection_record.version, inspection_record.status; return; end if;
  select inspection.* into inspection_record from public.compliance_inspections as inspection where inspection.id = p_inspection_id for update;
  if inspection_record.version <> p_expected_version then raise exception using errcode = '40001', message = 'compliance_inspection_version_conflict'; end if;
  if inspection_record.status <> 'planned' or p_status not in ('completed', 'cancelled')
    or (p_status = 'completed' and btrim(coalesce(p_observations, '')) = '')
    or char_length(coalesce(p_observations, '')) > 4000
  then raise exception using errcode = '22023', message = 'compliance_inspection_transition_invalid'; end if;
  update public.compliance_inspections as inspection set
    status = p_status, observations = case when p_status = 'completed' then btrim(p_observations) else null end,
    completed_at = case when p_status = 'completed' then statement_timestamp() else null end,
    completed_by_actor_id = case when p_status = 'completed' then actor_id else null end,
    completion_request_id = p_request_id, version = inspection.version + 1
  where inspection.id = p_inspection_id returning inspection.* into inspection_record;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    inspection_record.compliance_case_id,
    case when p_status = 'completed' then 'inspection_completed' else 'inspection_cancelled' end,
    'compliance_inspection', inspection_record.id, jsonb_build_object('status', 'planned'),
    jsonb_build_object('status', p_status, 'observations', inspection_record.observations),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select inspection_record.id, inspection_record.version, inspection_record.status;
end;
$$;

create function public.staff_record_compliance_allegation(
  p_compliance_case_id uuid, p_violation_type_id uuid,
  p_statement text, p_reason text, p_request_id uuid
)
returns table (allegation_id uuid, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; case_record record; existing_record record; created_id uuid;
begin
  actor_id := private.set_staff_audit_context('compliance.case.manage', p_reason, p_request_id);
  select allegation.id, allegation.status into existing_record from public.compliance_allegations as allegation where allegation.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.status; return; end if;
  select case_item.* into case_record from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_record.status in ('resolved', 'no_action', 'closed') or btrim(coalesce(p_statement, '')) = '' or char_length(p_statement) > 4000
  then raise exception using errcode = '22023', message = 'compliance_allegation_invalid'; end if;
  if not exists (select 1 from public.compliance_violation_types as type where type.id = p_violation_type_id and type.active)
  then raise exception using errcode = 'P0002', message = 'compliance_violation_type_not_found'; end if;
  insert into public.compliance_allegations (
    compliance_case_id, violation_type_id, statement, recorded_by_actor_id, source_request_id
  ) values (p_compliance_case_id, p_violation_type_id, btrim(p_statement), actor_id, p_request_id)
  returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    p_compliance_case_id, 'allegation_recorded', 'compliance_allegation', created_id,
    jsonb_build_object('status', 'alleged', 'violation_type_id', p_violation_type_id),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select created_id, 'alleged'::text;
end;
$$;

create function public.staff_record_compliance_evidence(
  p_compliance_case_id uuid, p_inspection_id uuid, p_evidence_type text,
  p_confidentiality_level text, p_evidence_reference text, p_description text,
  p_collected_at timestamptz, p_reason text, p_request_id uuid
)
returns table (evidence_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; existing_id uuid; case_status text; created_id uuid;
begin
  actor_id := private.set_staff_audit_context('compliance.evidence.manage', p_reason, p_request_id);
  select evidence.id into existing_id from public.compliance_evidence as evidence where evidence.source_request_id = p_request_id;
  if found then return query select existing_id; return; end if;
  select case_item.status into case_status from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_status = 'closed' or p_evidence_type not in ('document', 'image', 'statement', 'system_record', 'other')
    or p_confidentiality_level not in ('internal', 'restricted')
    or btrim(coalesce(p_evidence_reference, '')) = '' or char_length(p_evidence_reference) > 500
    or btrim(coalesce(p_description, '')) = '' or char_length(p_description) > 4000
    or p_collected_at is null or p_collected_at > statement_timestamp()
  then raise exception using errcode = '22023', message = 'compliance_evidence_invalid'; end if;
  if p_inspection_id is not null and not exists (select 1 from public.compliance_inspections as inspection where inspection.id = p_inspection_id and inspection.compliance_case_id = p_compliance_case_id)
  then raise exception using errcode = 'P0002', message = 'compliance_inspection_not_found'; end if;
  insert into public.compliance_evidence (
    compliance_case_id, inspection_id, evidence_type, confidentiality_level,
    evidence_reference, description, collected_at, recorded_by_actor_id, source_request_id
  ) values (
    p_compliance_case_id, p_inspection_id, p_evidence_type, p_confidentiality_level,
    btrim(p_evidence_reference), btrim(p_description), p_collected_at, actor_id, p_request_id
  ) returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    p_compliance_case_id, 'evidence_recorded', 'compliance_evidence', created_id,
    jsonb_build_object('evidence_type', p_evidence_type, 'confidentiality_level', p_confidentiality_level,
      'evidence_reference', p_evidence_reference), actor_id, btrim(p_reason), p_request_id
  );
  return query select created_id;
end;
$$;

create function public.staff_record_compliance_finding(
  p_compliance_case_id uuid, p_allegation_id uuid, p_outcome text,
  p_rationale text, p_reason text, p_request_id uuid
)
returns table (finding_id uuid, outcome text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; case_status text; existing_record record; created_id uuid;
begin
  actor_id := private.set_staff_audit_context('compliance.finding.record', p_reason, p_request_id);
  select finding.id, finding.outcome into existing_record from public.compliance_findings as finding where finding.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.outcome; return; end if;
  select case_item.status into case_status from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_status not in ('investigating', 'awaiting_response', 'deciding')
    or p_outcome not in ('substantiated', 'not_substantiated', 'inconclusive')
    or btrim(coalesce(p_rationale, '')) = '' or char_length(p_rationale) > 4000
  then raise exception using errcode = '22023', message = 'compliance_finding_invalid'; end if;
  if p_allegation_id is not null and not exists (select 1 from public.compliance_allegations as allegation where allegation.id = p_allegation_id and allegation.compliance_case_id = p_compliance_case_id)
  then raise exception using errcode = 'P0002', message = 'compliance_allegation_not_found'; end if;
  insert into public.compliance_findings (
    compliance_case_id, allegation_id, outcome, rationale, decided_by_actor_id, source_request_id
  ) values (p_compliance_case_id, p_allegation_id, p_outcome, btrim(p_rationale), actor_id, p_request_id)
  returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    p_compliance_case_id, 'finding_recorded', 'compliance_finding', created_id,
    jsonb_build_object('outcome', p_outcome, 'allegation_id', p_allegation_id),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select created_id, p_outcome;
end;
$$;

create function public.staff_recommend_compliance_action(
  p_compliance_case_id uuid, p_action_type_id uuid, p_subject_party_id uuid,
  p_related_record_type text, p_related_record_id uuid, p_recommendation text,
  p_reason text, p_request_id uuid
)
returns table (compliance_action_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; case_status text; existing_record record; created_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('compliance.action.recommend', p_reason, p_request_id);
  select action.id, action.public_reference, action.version, action.status into existing_record
  from public.compliance_actions as action where action.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.public_reference, existing_record.version, existing_record.status; return; end if;
  select case_item.status into case_status from public.compliance_cases as case_item where case_item.id = p_compliance_case_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_case_not_found'; end if;
  if case_status not in ('investigating', 'awaiting_response', 'deciding')
    or btrim(coalesce(p_recommendation, '')) = '' or char_length(p_recommendation) > 4000
    or not private.compliance_related_record_exists(coalesce(p_related_record_type, 'none'), p_related_record_id)
  then raise exception using errcode = '22023', message = 'compliance_action_invalid'; end if;
  if not exists (select 1 from public.compliance_action_types as type where type.id = p_action_type_id and type.active and type.effect_mode = 'record_only')
  then raise exception using errcode = 'P0002', message = 'compliance_action_type_not_found'; end if;
  if p_subject_party_id is not null and not exists (select 1 from public.parties as party where party.id = p_subject_party_id)
  then raise exception using errcode = 'P0002', message = 'compliance_subject_not_found'; end if;
  created_reference := private.allocate_compliance_reference('compliance_action');
  insert into public.compliance_actions (
    public_reference, compliance_case_id, action_type_id, subject_party_id,
    related_record_type, related_record_id, recommendation, recommended_by_actor_id, source_request_id
  ) values (
    created_reference, p_compliance_case_id, p_action_type_id, p_subject_party_id,
    coalesce(p_related_record_type, 'none'), p_related_record_id, btrim(p_recommendation), actor_id, p_request_id
  ) returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    p_compliance_case_id, 'action_recommended', 'compliance_action', created_id,
    jsonb_build_object('status', 'recommended', 'action_type_id', p_action_type_id, 'effect_applied', false),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values ('compliance.action_recommended', 'compliance_action', created_id,
    jsonb_build_object('public_reference', created_reference, 'case_id', p_compliance_case_id, 'effect_mode', 'record_only'),
    'compliance.action_recommended:' || p_request_id::text);
  return query select created_id, created_reference, 1::bigint, 'recommended'::text;
end;
$$;

create function public.staff_review_compliance_action(
  p_compliance_action_id uuid, p_expected_version bigint, p_status text,
  p_reason text, p_request_id uuid
)
returns table (compliance_action_id uuid, version bigint, status text, effect_applied boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; action_record record;
begin
  actor_id := private.set_staff_audit_context('compliance.action.approve', p_reason, p_request_id);
  select action.* into action_record from public.compliance_actions as action where action.id = p_compliance_action_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_action_not_found'; end if;
  if action_record.review_request_id = p_request_id then return query select action_record.id, action_record.version, action_record.status, action_record.effect_applied; return; end if;
  select action.* into action_record from public.compliance_actions as action where action.id = p_compliance_action_id for update;
  if action_record.version <> p_expected_version then raise exception using errcode = '40001', message = 'compliance_action_version_conflict'; end if;
  if action_record.status <> 'recommended' or p_status not in ('approved', 'declined', 'voided')
  then raise exception using errcode = '22023', message = 'compliance_action_transition_invalid'; end if;
  update public.compliance_actions as action set
    status = p_status, reviewed_by_actor_id = actor_id, reviewed_at = statement_timestamp(),
    review_reason = btrim(p_reason), review_request_id = p_request_id,
    effect_applied = false, version = action.version + 1
  where action.id = p_compliance_action_id returning action.* into action_record;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    action_record.compliance_case_id, 'action_reviewed', 'compliance_action', action_record.id,
    jsonb_build_object('status', 'recommended'),
    jsonb_build_object('status', p_status, 'effect_applied', false),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values ('compliance.action_reviewed', 'compliance_action', action_record.id,
    jsonb_build_object('public_reference', action_record.public_reference, 'status', p_status, 'effect_applied', false),
    'compliance.action_reviewed:' || p_request_id::text);
  return query select action_record.id, action_record.version, action_record.status, action_record.effect_applied;
end;
$$;

create function public.staff_record_compliance_appeal(
  p_compliance_action_id uuid, p_appellant_party_id uuid,
  p_filing_summary text, p_reason text, p_request_id uuid
)
returns table (appeal_id uuid, public_reference text, version bigint, status text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; action_record record; existing_record record; created_id uuid; created_reference text;
begin
  actor_id := private.set_staff_audit_context('compliance.appeal.manage', p_reason, p_request_id);
  select appeal.id, appeal.public_reference, appeal.version, appeal.status into existing_record
  from public.compliance_appeals as appeal where appeal.source_request_id = p_request_id;
  if found then return query select existing_record.id, existing_record.public_reference, existing_record.version, existing_record.status; return; end if;
  select action.* into action_record from public.compliance_actions as action where action.id = p_compliance_action_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_action_not_found'; end if;
  if action_record.status <> 'approved' or btrim(coalesce(p_filing_summary, '')) = '' or char_length(p_filing_summary) > 4000
  then raise exception using errcode = '22023', message = 'compliance_appeal_invalid'; end if;
  if not exists (select 1 from public.parties as party where party.id = p_appellant_party_id)
  then raise exception using errcode = 'P0002', message = 'compliance_appellant_not_found'; end if;
  if exists (select 1 from public.compliance_appeals as appeal where appeal.compliance_action_id = p_compliance_action_id and appeal.status = 'filed')
  then raise exception using errcode = '23505', message = 'compliance_appeal_already_filed'; end if;
  created_reference := private.allocate_compliance_reference('compliance_appeal');
  insert into public.compliance_appeals (
    public_reference, compliance_case_id, compliance_action_id, appellant_party_id,
    filing_summary, recorded_by_actor_id, source_request_id
  ) values (
    created_reference, action_record.compliance_case_id, action_record.id, p_appellant_party_id,
    btrim(p_filing_summary), actor_id, p_request_id
  ) returning id into created_id;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    new_state, changed_by_actor_id, reason, request_id
  ) values (
    action_record.compliance_case_id, 'appeal_filed', 'compliance_appeal', created_id,
    jsonb_build_object('status', 'filed', 'action_id', action_record.id, 'appellant_party_id', p_appellant_party_id),
    actor_id, btrim(p_reason), p_request_id
  );
  insert into public.outbox_events (event_type, aggregate_type, aggregate_id, payload, deduplication_key)
  values ('compliance.appeal_filed', 'compliance_appeal', created_id,
    jsonb_build_object('public_reference', created_reference, 'action_reference', action_record.public_reference),
    'compliance.appeal_filed:' || p_request_id::text);
  return query select created_id, created_reference, 1::bigint, 'filed'::text;
end;
$$;

create unique index compliance_appeals_one_filed_per_action_idx
  on public.compliance_appeals(compliance_action_id) where status = 'filed';

create function public.staff_decide_compliance_appeal(
  p_appeal_id uuid, p_expected_version bigint, p_status text, p_outcome text,
  p_decision_reason text, p_reason text, p_request_id uuid
)
returns table (appeal_id uuid, version bigint, status text, outcome text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor_id uuid; appeal_record record;
begin
  actor_id := private.set_staff_audit_context('compliance.appeal.manage', p_reason, p_request_id);
  select appeal.* into appeal_record from public.compliance_appeals as appeal where appeal.id = p_appeal_id;
  if not found then raise exception using errcode = 'P0002', message = 'compliance_appeal_not_found'; end if;
  if appeal_record.decision_request_id = p_request_id then return query select appeal_record.id, appeal_record.version, appeal_record.status, appeal_record.outcome; return; end if;
  select appeal.* into appeal_record from public.compliance_appeals as appeal where appeal.id = p_appeal_id for update;
  if appeal_record.version <> p_expected_version then raise exception using errcode = '40001', message = 'compliance_appeal_version_conflict'; end if;
  if appeal_record.status <> 'filed' or p_status not in ('decided', 'withdrawn')
    or (p_status = 'decided' and p_outcome not in ('affirmed', 'varied', 'remanded', 'reversed'))
    or (p_status = 'withdrawn' and p_outcome is not null)
    or btrim(coalesce(p_decision_reason, '')) = '' or char_length(p_decision_reason) > 4000
  then raise exception using errcode = '22023', message = 'compliance_appeal_decision_invalid'; end if;
  update public.compliance_appeals as appeal set
    status = p_status, outcome = case when p_status = 'decided' then p_outcome else null end,
    decision_reason = btrim(p_decision_reason), decided_at = statement_timestamp(),
    decided_by_actor_id = actor_id, decision_request_id = p_request_id,
    version = appeal.version + 1
  where appeal.id = p_appeal_id returning appeal.* into appeal_record;
  insert into public.compliance_events (
    compliance_case_id, event_type, related_record_type, related_record_id,
    previous_state, new_state, changed_by_actor_id, reason, request_id
  ) values (
    appeal_record.compliance_case_id,
    case when p_status = 'decided' then 'appeal_decided' else 'appeal_withdrawn' end,
    'compliance_appeal', appeal_record.id, jsonb_build_object('status', 'filed'),
    jsonb_build_object('status', p_status, 'outcome', appeal_record.outcome, 'effect_applied', false),
    actor_id, btrim(p_reason), p_request_id
  );
  return query select appeal_record.id, appeal_record.version, appeal_record.status, appeal_record.outcome;
end;
$$;

insert into public.notification_templates (code, event_type, destination_type, message_template)
values
  ('staff-compliance-case-v1', 'compliance.case_opened', 'discord_channel', 'Compliance case {{public_reference}} was opened.'),
  ('staff-compliance-action-v1', 'compliance.action_recommended', 'discord_channel', 'Compliance action {{public_reference}} requires review.'),
  ('staff-compliance-appeal-v1', 'compliance.appeal_filed', 'discord_channel', 'Compliance appeal {{public_reference}} was recorded.');

insert into public.integration_event_routes (event_type, destination_id, notification_template_id, active)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination on destination.code = 'staff-alerts'
where template.event_type in ('compliance.case_opened', 'compliance.action_recommended', 'compliance.appeal_filed');

revoke all on public.compliance_case_types from anon, authenticated;
revoke all on public.compliance_violation_types from anon, authenticated;
revoke all on public.compliance_action_types from anon, authenticated;
revoke all on public.compliance_cases from anon, authenticated;
revoke all on public.compliance_inspections from anon, authenticated;
revoke all on public.compliance_allegations from anon, authenticated;
revoke all on public.compliance_findings from anon, authenticated;
revoke all on public.compliance_evidence from anon, authenticated;
revoke all on public.compliance_actions from anon, authenticated;
revoke all on public.compliance_appeals from anon, authenticated;
revoke all on public.compliance_events from anon, authenticated;
revoke all on function private.allocate_compliance_reference(text) from public, anon, authenticated;
revoke all on function private.compliance_related_record_exists(text,uuid) from public, anon, authenticated;

revoke all on function public.get_staff_compliance_workspace() from public, anon;
revoke all on function public.get_staff_compliance_case(uuid) from public, anon;
revoke all on function public.staff_create_compliance_case(uuid,uuid,text,uuid,text,text,uuid,text,uuid) from public, anon;
revoke all on function public.staff_transition_compliance_case(uuid,bigint,text,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_create_compliance_inspection(uuid,timestamptz,text,text,text,uuid) from public, anon;
revoke all on function public.staff_finish_compliance_inspection(uuid,bigint,text,text,text,uuid) from public, anon;
revoke all on function public.staff_record_compliance_allegation(uuid,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_record_compliance_evidence(uuid,uuid,text,text,text,text,timestamptz,text,uuid) from public, anon;
revoke all on function public.staff_record_compliance_finding(uuid,uuid,text,text,text,uuid) from public, anon;
revoke all on function public.staff_recommend_compliance_action(uuid,uuid,uuid,text,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_review_compliance_action(uuid,bigint,text,text,uuid) from public, anon;
revoke all on function public.staff_record_compliance_appeal(uuid,uuid,text,text,uuid) from public, anon;
revoke all on function public.staff_decide_compliance_appeal(uuid,bigint,text,text,text,text,uuid) from public, anon;

grant execute on function public.get_staff_compliance_workspace() to authenticated;
grant execute on function public.get_staff_compliance_case(uuid) to authenticated;
grant execute on function public.staff_create_compliance_case(uuid,uuid,text,uuid,text,text,uuid,text,uuid) to authenticated;
grant execute on function public.staff_transition_compliance_case(uuid,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_create_compliance_inspection(uuid,timestamptz,text,text,text,uuid) to authenticated;
grant execute on function public.staff_finish_compliance_inspection(uuid,bigint,text,text,text,uuid) to authenticated;
grant execute on function public.staff_record_compliance_allegation(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_record_compliance_evidence(uuid,uuid,text,text,text,text,timestamptz,text,uuid) to authenticated;
grant execute on function public.staff_record_compliance_finding(uuid,uuid,text,text,text,uuid) to authenticated;
grant execute on function public.staff_recommend_compliance_action(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_review_compliance_action(uuid,bigint,text,text,uuid) to authenticated;
grant execute on function public.staff_record_compliance_appeal(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function public.staff_decide_compliance_appeal(uuid,bigint,text,text,text,text,uuid) to authenticated;
