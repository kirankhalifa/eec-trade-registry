alter table public.actor_profiles
  drop constraint actor_profiles_actor_type_check;

alter table public.actor_profiles
  add constraint actor_profiles_actor_type_check
  check (actor_type in ('staff', 'dealer'));

create table public.representative_role_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{0,49}$'),
  display_name text not null check (btrim(display_name) <> ''),
  description text not null check (btrim(description) <> ''),
  default_scope jsonb not null default '{}'::jsonb
    check (jsonb_typeof(default_scope) = 'object'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.party_representatives (
  id uuid primary key default extensions.gen_random_uuid(),
  principal_party_id uuid not null references public.parties(id) on delete restrict,
  actor_id uuid references public.actor_profiles(id) on delete restrict,
  representative_party_id uuid references public.parties(id) on delete restrict,
  role_definition_id uuid not null
    references public.representative_role_definitions(id) on delete restrict,
  authority_scope jsonb not null default '{}'::jsonb
    check (jsonb_typeof(authority_scope) = 'object'),
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  revoked_at timestamptz,
  verified_at timestamptz not null,
  verified_by uuid references public.actor_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (num_nonnulls(actor_id, representative_party_id) >= 1),
  check (effective_until is null or effective_until > effective_from),
  check (revoked_at is null or revoked_at >= effective_from),
  check (
    not (authority_scope ? 'portal.read')
    or jsonb_typeof(authority_scope -> 'portal.read') = 'boolean'
  ),
  unique (principal_party_id, actor_id, role_definition_id, effective_from),
  exclude using gist (
    principal_party_id with =,
    actor_id with =,
    role_definition_id with =,
    tstzrange(effective_from, coalesce(effective_until, 'infinity'::timestamptz), '[)') with &&
  ) where (revoked_at is null and actor_id is not null)
);

comment on table public.party_representatives is
  'Effective-dated authority to act for a principal party. Authentication alone grants no dealer access.';
comment on column public.party_representatives.authority_scope is
  'Constrained machine scopes resolved by secure functions. The initial slice recognizes portal.read only.';

create index party_representatives_actor_idx
  on public.party_representatives(actor_id, effective_from, effective_until)
  where revoked_at is null;
create index party_representatives_principal_idx
  on public.party_representatives(principal_party_id, effective_from, effective_until)
  where revoked_at is null;

create trigger representative_roles_set_updated_at
before update on public.representative_role_definitions
for each row execute function private.set_updated_at();

create trigger party_representatives_set_updated_at
before update on public.party_representatives
for each row execute function private.set_updated_at();

create trigger representative_roles_audit
after insert or update or delete on public.representative_role_definitions
for each row execute function private.capture_audit_row();

create trigger party_representatives_audit
after insert or update or delete on public.party_representatives
for each row execute function private.capture_audit_row();

alter table public.representative_role_definitions enable row level security;
alter table public.party_representatives enable row level security;

insert into public.representative_role_definitions (
  code,
  display_name,
  description,
  default_scope
)
values (
  'portal-representative',
  'Dealer portal representative',
  'May read the private portal overview for an actively represented authorized dealer.',
  '{"portal.read": true}'::jsonb
);

create function public.get_dealer_portal_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_actor record;
  representations jsonb;
begin
  select
    actor.id,
    actor.display_name
  into current_actor
  from public.actor_profiles as actor
  where actor.auth_user_id = auth.uid()
    and actor.actor_type = 'dealer'
    and actor.status = 'active'
  limit 1;

  if not found then
    raise sqlstate '28000' using
      message = 'dealer_authentication_required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'representation_id', representative_grant.id,
        'role_label', representative_role.display_name,
        'party_id', principal_party.id,
        'party_name', principal_party.display_name,
        'jurisdiction_label', jurisdiction.public_name,
        'dealer_authorizations', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'public_reference', dealer_record.public_reference,
                'dealer_type_label', dealer_type.display_name,
                'status_label', dealer_status.display_name,
                'is_currently_authorized', (
                  dealer_status.confers_authority
                  and dealer_record.effective_from <= current_timestamp
                  and (
                    dealer_record.effective_until is null
                    or dealer_record.effective_until > current_timestamp
                  )
                ),
                'effective_from', dealer_record.effective_from,
                'effective_until', dealer_record.effective_until,
                'premises_label', dealer_record.approved_premises_public,
                'notice', nullif(btrim(dealer_record.public_notes), '')
              )
              order by dealer_record.effective_from desc, dealer_record.public_reference
            )
            from public.dealer_authorizations as dealer_record
            join public.dealer_types as dealer_type
              on dealer_type.id = dealer_record.dealer_type_id
            join public.dealer_status_definitions as dealer_status
              on dealer_status.id = dealer_record.status_definition_id
            where dealer_record.dealer_party_id = principal_party.id
          ),
          '[]'::jsonb
        ),
        'licenses', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'public_reference', license_record.public_reference,
                'license_class_label', license_class.display_name,
                'jurisdiction_label', license_jurisdiction.public_name,
                'status_label', license_status.display_name,
                'is_currently_authorized', (
                  license_status.confers_authority
                  and license_record.effective_from <= current_timestamp
                  and (
                    license_record.expires_at is null
                    or license_record.expires_at > current_timestamp
                  )
                ),
                'effective_from', license_record.effective_from,
                'expires_at', license_record.expires_at,
                'notice', nullif(btrim(license_record.public_notes), ''),
                'endorsements', coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'label', endorsement.display_name,
                        'effective_from', granted.effective_from,
                        'expires_at', granted.expires_at
                      )
                      order by endorsement.display_name
                    )
                    from public.license_endorsements as granted
                    join public.endorsement_definitions as endorsement
                      on endorsement.id = granted.endorsement_definition_id
                    where granted.license_id = license_record.id
                      and granted.revoked_at is null
                      and granted.effective_from <= current_timestamp
                      and (
                        granted.expires_at is null
                        or granted.expires_at > current_timestamp
                      )
                  ),
                  '[]'::jsonb
                ),
                'public_conditions', coalesce(
                  (
                    select jsonb_agg(
                      public_condition.public_text
                      order by public_condition.condition_code
                    )
                    from public.license_conditions as public_condition
                    where public_condition.license_id = license_record.id
                      and public_condition.public_visibility
                      and public_condition.effective_from <= current_timestamp
                      and (
                        public_condition.effective_until is null
                        or public_condition.effective_until > current_timestamp
                      )
                  ),
                  '[]'::jsonb
                )
              )
              order by license_record.effective_from desc, license_record.public_reference
            )
            from public.licenses as license_record
            join public.license_classes as license_class
              on license_class.id = license_record.license_class_id
            join public.license_status_definitions as license_status
              on license_status.id = license_record.status_definition_id
            join public.jurisdictions as license_jurisdiction
              on license_jurisdiction.id = license_record.jurisdiction_id
            where license_record.holder_party_id = principal_party.id
          ),
          '[]'::jsonb
        )
      )
      order by principal_party.display_name, principal_party.id
    ),
    '[]'::jsonb
  )
  into representations
  from public.party_representatives as representative_grant
  join public.representative_role_definitions as representative_role
    on representative_role.id = representative_grant.role_definition_id
    and representative_role.active
  join public.parties as principal_party
    on principal_party.id = representative_grant.principal_party_id
    and principal_party.status = 'active'
  left join public.jurisdictions as jurisdiction
    on jurisdiction.id = principal_party.primary_jurisdiction_id
  where representative_grant.actor_id = current_actor.id
    and representative_grant.revoked_at is null
    and representative_grant.effective_from <= current_timestamp
    and (
      representative_grant.effective_until is null
      or representative_grant.effective_until > current_timestamp
    )
    and coalesce(
      (representative_grant.authority_scope ->> 'portal.read')::boolean,
      false
    )
    and exists (
      select 1
      from public.dealer_authorizations as current_dealer_record
      join public.dealer_status_definitions as current_dealer_status
        on current_dealer_status.id = current_dealer_record.status_definition_id
        and current_dealer_status.confers_authority
      where current_dealer_record.dealer_party_id = principal_party.id
        and current_dealer_record.effective_from <= current_timestamp
        and (
          current_dealer_record.effective_until is null
          or current_dealer_record.effective_until > current_timestamp
        )
    );

  if jsonb_array_length(representations) = 0 then
    raise sqlstate '42501' using
      message = 'dealer_access_denied';
  end if;

  return jsonb_build_object(
    'actor_display_name', current_actor.display_name,
    'generated_at', current_timestamp,
    'representations', representations
  );
end;
$$;

revoke all on public.representative_role_definitions from anon, authenticated;
revoke all on public.party_representatives from anon, authenticated;
revoke all on function public.get_dealer_portal_overview() from public, anon;
grant execute on function public.get_dealer_portal_overview() to authenticated;
