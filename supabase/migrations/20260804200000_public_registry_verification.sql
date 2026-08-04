create function private.normalize_registry_reference(p_reference text)
returns text
language sql
immutable
returns null on null input
set search_path = ''
as $$
  select nullif(
    upper(regexp_replace(btrim(p_reference), '\s+', ' ', 'g')),
    ''
  );
$$;

create table public.jurisdictions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  internal_name text not null check (btrim(internal_name) <> ''),
  public_name text not null check (btrim(public_name) <> ''),
  parent_id uuid references public.jurisdictions(id) on delete restrict,
  default_timezone text not null default 'UTC' check (btrim(default_timezone) <> ''),
  status text not null default 'active' check (status in ('active', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id is null or parent_id <> id)
);

create table public.party_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.parties (
  id uuid primary key default extensions.gen_random_uuid(),
  party_type_id uuid not null references public.party_types(id) on delete restrict,
  legal_name text not null check (btrim(legal_name) <> ''),
  display_name text not null check (btrim(display_name) <> ''),
  public_display_name text,
  public_reference text unique,
  primary_jurisdiction_id uuid references public.jurisdictions(id) on delete restrict,
  public_profile_enabled boolean not null default false,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (
    not public_profile_enabled
    or (public_display_name is not null and btrim(public_display_name) <> '')
  ),
  check (
    public_reference is null
    or (
      public_reference = private.normalize_registry_reference(public_reference)
      and char_length(public_reference) between 6 and 128
    )
  )
);

create table public.dealer_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.dealer_status_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_result_code text not null check (
    public_result_code in (
      'valid',
      'provisional',
      'suspended',
      'revoked',
      'expired',
      'not_verifiable'
    )
  ),
  confers_authority boolean not null default false,
  publicly_verifiable boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.dealer_authorizations (
  id uuid primary key default extensions.gen_random_uuid(),
  dealer_party_id uuid not null references public.parties(id) on delete restrict,
  public_reference text not null unique,
  dealer_type_id uuid not null references public.dealer_types(id) on delete restrict,
  jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  status_definition_id uuid not null references public.dealer_status_definitions(id) on delete restrict,
  approved_premises_public text,
  public_notes text not null default '',
  private_notes text not null default '',
  effective_from timestamptz not null,
  effective_until timestamptz,
  public_disclosure_enabled boolean not null default false,
  approved_by uuid references public.actor_profiles(id) on delete restrict,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (effective_until is null or effective_until > effective_from),
  check (approved_at is null or approved_by is not null)
);

create table public.license_classes (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_display_name text not null check (btrim(public_display_name) <> ''),
  description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.license_status_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_result_code text not null check (
    public_result_code in (
      'valid',
      'provisional',
      'suspended',
      'revoked',
      'expired',
      'not_verifiable'
    )
  ),
  confers_authority boolean not null default false,
  publicly_verifiable boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.endorsement_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  public_display_name text not null check (btrim(public_display_name) <> ''),
  description text not null default '',
  prerequisite_endorsement_id uuid references public.endorsement_definitions(id) on delete restrict,
  exclusivity_group text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (prerequisite_endorsement_id is null or prerequisite_endorsement_id <> id)
);

create table public.licenses (
  id uuid primary key default extensions.gen_random_uuid(),
  public_reference text not null unique,
  holder_party_id uuid not null references public.parties(id) on delete restrict,
  dealer_authorization_id uuid references public.dealer_authorizations(id) on delete restrict,
  license_class_id uuid not null references public.license_classes(id) on delete restrict,
  jurisdiction_id uuid not null references public.jurisdictions(id) on delete restrict,
  status_definition_id uuid not null references public.license_status_definitions(id) on delete restrict,
  issued_at timestamptz not null,
  effective_from timestamptz not null,
  expires_at timestamptz,
  public_notes text not null default '',
  private_notes text not null default '',
  public_disclosure_enabled boolean not null default false,
  issued_by uuid references public.actor_profiles(id) on delete restrict,
  approved_by uuid references public.actor_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (public_reference = private.normalize_registry_reference(public_reference)),
  check (char_length(public_reference) between 6 and 128),
  check (expires_at is null or expires_at > effective_from),
  check (issued_at <= effective_from)
);

create table public.license_endorsements (
  id uuid primary key default extensions.gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete restrict,
  endorsement_definition_id uuid not null references public.endorsement_definitions(id) on delete restrict,
  effective_from timestamptz not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  public_disclosure_enabled boolean not null default false,
  scope_configuration jsonb not null default '{}'::jsonb check (
    jsonb_typeof(scope_configuration) = 'object'
  ),
  granted_by uuid references public.actor_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at is null or expires_at > effective_from),
  check (revoked_at is null or revoked_at >= effective_from),
  unique (id, license_id),
  exclude using gist (
    license_id with =,
    endorsement_definition_id with =,
    tstzrange(effective_from, coalesce(expires_at, 'infinity'::timestamptz), '[)') with &&
  ) where (revoked_at is null)
);

create table public.license_conditions (
  id uuid primary key default extensions.gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete restrict,
  license_endorsement_id uuid,
  condition_code text not null check (condition_code ~ '^[a-z0-9][a-z0-9_-]{0,79}$'),
  public_text text,
  private_text text not null default '',
  parameters jsonb not null default '{}'::jsonb check (jsonb_typeof(parameters) = 'object'),
  public_visibility boolean not null default false,
  effective_from timestamptz not null,
  effective_until timestamptz,
  imposed_by uuid references public.actor_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  check (
    not public_visibility
    or (public_text is not null and btrim(public_text) <> '')
  ),
  foreign key (license_endorsement_id, license_id)
    references public.license_endorsements(id, license_id) on delete restrict,
  unique (license_id, condition_code, effective_from)
);

comment on function private.normalize_registry_reference(text) is
  'Applies the public lookup normalization contract without imposing a deployment-specific numbering format.';
comment on table public.parties is
  'Private party source records. Anonymous callers receive only explicit verification projections.';
comment on table public.dealer_authorizations is
  'Dealer authority is separate from party identity and licensing.';
comment on table public.licenses is
  'Issued authority only. Applications and issuance commands are introduced after their policies are approved.';

create index jurisdictions_parent_idx on public.jurisdictions(parent_id);
create index parties_jurisdiction_idx on public.parties(primary_jurisdiction_id);
create index dealer_authorizations_party_idx on public.dealer_authorizations(dealer_party_id);
create index dealer_authorizations_status_idx
  on public.dealer_authorizations(status_definition_id, effective_from, effective_until);
create index licenses_holder_idx on public.licenses(holder_party_id);
create index licenses_dealer_idx on public.licenses(dealer_authorization_id);
create index licenses_status_idx on public.licenses(status_definition_id, effective_from, expires_at);
create index license_endorsements_license_idx on public.license_endorsements(license_id);
create index license_conditions_license_idx on public.license_conditions(license_id);

create trigger jurisdictions_set_updated_at before update on public.jurisdictions
for each row execute function private.set_updated_at();
create trigger party_types_set_updated_at before update on public.party_types
for each row execute function private.set_updated_at();
create trigger parties_set_updated_at before update on public.parties
for each row execute function private.set_updated_at();
create trigger dealer_types_set_updated_at before update on public.dealer_types
for each row execute function private.set_updated_at();
create trigger dealer_status_definitions_set_updated_at before update on public.dealer_status_definitions
for each row execute function private.set_updated_at();
create trigger dealer_authorizations_set_updated_at before update on public.dealer_authorizations
for each row execute function private.set_updated_at();
create trigger license_classes_set_updated_at before update on public.license_classes
for each row execute function private.set_updated_at();
create trigger license_status_definitions_set_updated_at before update on public.license_status_definitions
for each row execute function private.set_updated_at();
create trigger endorsement_definitions_set_updated_at before update on public.endorsement_definitions
for each row execute function private.set_updated_at();
create trigger licenses_set_updated_at before update on public.licenses
for each row execute function private.set_updated_at();
create trigger license_endorsements_set_updated_at before update on public.license_endorsements
for each row execute function private.set_updated_at();
create trigger license_conditions_set_updated_at before update on public.license_conditions
for each row execute function private.set_updated_at();

create trigger jurisdictions_audit after insert or update or delete on public.jurisdictions
for each row execute function private.capture_audit_row();
create trigger party_types_audit after insert or update or delete on public.party_types
for each row execute function private.capture_audit_row();
create trigger parties_audit after insert or update or delete on public.parties
for each row execute function private.capture_audit_row();
create trigger dealer_types_audit after insert or update or delete on public.dealer_types
for each row execute function private.capture_audit_row();
create trigger dealer_status_definitions_audit after insert or update or delete on public.dealer_status_definitions
for each row execute function private.capture_audit_row();
create trigger dealer_authorizations_audit after insert or update or delete on public.dealer_authorizations
for each row execute function private.capture_audit_row();
create trigger license_classes_audit after insert or update or delete on public.license_classes
for each row execute function private.capture_audit_row();
create trigger license_status_definitions_audit after insert or update or delete on public.license_status_definitions
for each row execute function private.capture_audit_row();
create trigger endorsement_definitions_audit after insert or update or delete on public.endorsement_definitions
for each row execute function private.capture_audit_row();
create trigger licenses_audit after insert or update or delete on public.licenses
for each row execute function private.capture_audit_row();
create trigger license_endorsements_audit after insert or update or delete on public.license_endorsements
for each row execute function private.capture_audit_row();
create trigger license_conditions_audit after insert or update or delete on public.license_conditions
for each row execute function private.capture_audit_row();

alter table public.jurisdictions enable row level security;
alter table public.party_types enable row level security;
alter table public.parties enable row level security;
alter table public.dealer_types enable row level security;
alter table public.dealer_status_definitions enable row level security;
alter table public.dealer_authorizations enable row level security;
alter table public.license_classes enable row level security;
alter table public.license_status_definitions enable row level security;
alter table public.endorsement_definitions enable row level security;
alter table public.licenses enable row level security;
alter table public.license_endorsements enable row level security;
alter table public.license_conditions enable row level security;

create function public.public_dealer_verification(p_reference text)
returns table (
  result_code text,
  public_reference text,
  public_name text,
  dealer_type_label text,
  jurisdiction_label text,
  premises_label text,
  status_label text,
  is_currently_authorized boolean,
  effective_from timestamptz,
  effective_until timestamptz,
  public_notice text,
  license_summaries jsonb,
  verified_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with matched as (
    select
      case
        when dealer_record.effective_until is not null
          and dealer_record.effective_until <= current_timestamp
          then 'expired'
        else dealer_status.public_result_code
      end as result_code,
      dealer_record.public_reference,
      party.public_display_name as public_name,
      dealer_type.display_name as dealer_type_label,
      jurisdiction.public_name as jurisdiction_label,
      nullif(btrim(dealer_record.approved_premises_public), '') as premises_label,
      dealer_status.display_name as status_label,
      (
        dealer_status.confers_authority
        and dealer_record.effective_from <= current_timestamp
        and (
          dealer_record.effective_until is null
          or dealer_record.effective_until > current_timestamp
        )
      ) as is_currently_authorized,
      dealer_record.effective_from,
      dealer_record.effective_until,
      nullif(btrim(dealer_record.public_notes), '') as public_notice,
      coalesce(license_list.license_summaries, '[]'::jsonb) as license_summaries,
      current_timestamp as verified_at
    from public.dealer_authorizations as dealer_record
    join public.parties as party
      on party.id = dealer_record.dealer_party_id
      and party.status = 'active'
      and party.public_profile_enabled
    join public.dealer_types as dealer_type
      on dealer_type.id = dealer_record.dealer_type_id
    join public.jurisdictions as jurisdiction
      on jurisdiction.id = dealer_record.jurisdiction_id
    join public.dealer_status_definitions as dealer_status
      on dealer_status.id = dealer_record.status_definition_id
      and dealer_status.publicly_verifiable
    left join lateral (
      select jsonb_agg(
        jsonb_build_object(
          'public_reference', related_license.public_reference,
          'license_class_label', license_class.public_display_name,
          'result_code', case
            when related_license.expires_at is not null
              and related_license.expires_at <= current_timestamp
              then 'expired'
            else related_license_status.public_result_code
          end,
          'is_currently_authorized', (
            related_license_status.confers_authority
            and related_license.effective_from <= current_timestamp
            and (
              related_license.expires_at is null
              or related_license.expires_at > current_timestamp
            )
          )
        )
        order by license_class.public_display_name, related_license.public_reference
      ) as license_summaries
      from public.licenses as related_license
      join public.license_classes as license_class
        on license_class.id = related_license.license_class_id
      join public.license_status_definitions as related_license_status
        on related_license_status.id = related_license.status_definition_id
        and related_license_status.publicly_verifiable
      join public.parties as license_holder
        on license_holder.id = related_license.holder_party_id
        and license_holder.status = 'active'
        and license_holder.public_profile_enabled
      where related_license.dealer_authorization_id = dealer_record.id
        and related_license.public_disclosure_enabled
    ) as license_list on true
    where dealer_record.public_disclosure_enabled
      and dealer_record.public_reference = private.normalize_registry_reference(p_reference)
    limit 1
  )
  select matched.* from matched
  union all
  select
    'not_verifiable'::text,
    null::text,
    null::text,
    null::text,
    null::text,
    null::text,
    null::text,
    false,
    null::timestamptz,
    null::timestamptz,
    null::text,
    '[]'::jsonb,
    current_timestamp
  where not exists (select 1 from matched);
$$;

create function public.public_license_verification(p_reference text)
returns table (
  result_code text,
  public_reference text,
  holder_name text,
  license_class_label text,
  jurisdiction_label text,
  status_label text,
  is_currently_authorized boolean,
  effective_from timestamptz,
  expires_at timestamptz,
  endorsements text[],
  public_conditions text[],
  public_notice text,
  verified_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with matched as (
    select
      case
        when license_record.expires_at is not null
          and license_record.expires_at <= current_timestamp
          then 'expired'
        else license_status.public_result_code
      end as result_code,
      license_record.public_reference,
      holder.public_display_name as holder_name,
      license_class.public_display_name as license_class_label,
      jurisdiction.public_name as jurisdiction_label,
      license_status.display_name as status_label,
      (
        license_status.confers_authority
        and license_record.effective_from <= current_timestamp
        and (
          license_record.expires_at is null
          or license_record.expires_at > current_timestamp
        )
      ) as is_currently_authorized,
      license_record.effective_from,
      license_record.expires_at,
      coalesce(endorsement_list.endorsements, array[]::text[]) as endorsements,
      coalesce(condition_list.public_conditions, array[]::text[]) as public_conditions,
      nullif(btrim(license_record.public_notes), '') as public_notice,
      current_timestamp as verified_at
    from public.licenses as license_record
    join public.parties as holder
      on holder.id = license_record.holder_party_id
      and holder.status = 'active'
      and holder.public_profile_enabled
    join public.license_classes as license_class
      on license_class.id = license_record.license_class_id
    join public.jurisdictions as jurisdiction
      on jurisdiction.id = license_record.jurisdiction_id
    join public.license_status_definitions as license_status
      on license_status.id = license_record.status_definition_id
      and license_status.publicly_verifiable
    left join lateral (
      select array_agg(
        distinct endorsement.public_display_name
        order by endorsement.public_display_name
      ) as endorsements
      from public.license_endorsements as granted
      join public.endorsement_definitions as endorsement
        on endorsement.id = granted.endorsement_definition_id
      where granted.license_id = license_record.id
        and granted.public_disclosure_enabled
        and granted.revoked_at is null
        and granted.effective_from <= current_timestamp
        and (granted.expires_at is null or granted.expires_at > current_timestamp)
    ) as endorsement_list on true
    left join lateral (
      select array_agg(
        public_condition.public_text
        order by public_condition.condition_code
      ) as public_conditions
      from public.license_conditions as public_condition
      where public_condition.license_id = license_record.id
        and public_condition.public_visibility
        and public_condition.effective_from <= current_timestamp
        and (
          public_condition.effective_until is null
          or public_condition.effective_until > current_timestamp
        )
    ) as condition_list on true
    where license_record.public_disclosure_enabled
      and license_record.public_reference = private.normalize_registry_reference(p_reference)
    limit 1
  )
  select matched.* from matched
  union all
  select
    'not_verifiable'::text,
    null::text,
    null::text,
    null::text,
    null::text,
    null::text,
    false,
    null::timestamptz,
    null::timestamptz,
    array[]::text[],
    array[]::text[],
    null::text,
    current_timestamp
  where not exists (select 1 from matched);
$$;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public;

grant usage on schema public to anon, authenticated;
grant execute on function public.public_dealer_verification(text) to anon, authenticated;
grant execute on function public.public_license_verification(text) to anon, authenticated;

revoke all on function private.normalize_registry_reference(text) from public, anon, authenticated;
