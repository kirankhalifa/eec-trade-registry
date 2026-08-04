begin;

select plan(26);

select has_table(
  'public',
  'representative_role_definitions',
  'representative role definitions table exists'
);
select has_table(
  'public',
  'party_representatives',
  'party representatives table exists'
);
select has_function(
  'public',
  'get_dealer_portal_overview',
  array[]::text[],
  'dealer portal overview RPC exists'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.party_representatives'::regclass),
  'party representatives have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.representative_role_definitions'::regclass),
  'representative roles have row-level security enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.party_representatives', 'select'),
  'authenticated callers cannot select representative grants directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.parties', 'select'),
  'authenticated callers cannot select party rows directly'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_dealer_portal_overview()',
    'execute'
  ),
  'anonymous callers cannot execute the dealer overview'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_dealer_portal_overview()',
    'execute'
  ),
  'authenticated callers can reach the secured dealer overview boundary'
);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
values
  (
    'da000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'active.dealer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'other.dealer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'expired.representative@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'unscoped.representative@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'revoked.representative@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000006',
    'authenticated',
    'authenticated',
    'staff.with.representation@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    'da000000-0000-0000-0000-000000000007',
    'authenticated',
    'authenticated',
    'inactive.dealer@example.test',
    extensions.crypt('test-password', extensions.gen_salt('bf')),
    now(),
    now(),
    now()
  );

insert into public.actor_profiles (
  id, auth_user_id, display_name, actor_type
)
values
  (
    'db000000-0000-0000-0000-000000000001',
    'da000000-0000-0000-0000-000000000001',
    'Active Dealer Representative',
    'dealer'
  ),
  (
    'db000000-0000-0000-0000-000000000002',
    'da000000-0000-0000-0000-000000000002',
    'Other Dealer Representative',
    'dealer'
  ),
  (
    'db000000-0000-0000-0000-000000000003',
    'da000000-0000-0000-0000-000000000003',
    'Expired Dealer Representative',
    'dealer'
  ),
  (
    'db000000-0000-0000-0000-000000000004',
    'da000000-0000-0000-0000-000000000004',
    'Unscoped Dealer Representative',
    'dealer'
  ),
  (
    'db000000-0000-0000-0000-000000000005',
    'da000000-0000-0000-0000-000000000005',
    'Revoked Dealer Representative',
    'dealer'
  ),
  (
    'db000000-0000-0000-0000-000000000006',
    'da000000-0000-0000-0000-000000000006',
    'Staff Identity',
    'staff'
  ),
  (
    'db000000-0000-0000-0000-000000000007',
    'da000000-0000-0000-0000-000000000007',
    'Inactive Dealer Representative',
    'dealer'
  );

insert into public.parties (
  id,
  party_type_id,
  legal_name,
  display_name,
  public_display_name,
  primary_jurisdiction_id,
  public_profile_enabled
)
values (
  'dd000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001',
  'Fictional Other Dealer Legal Name',
  'Other Dealer Organization',
  'Other Dealer Organization',
  '90000000-0000-0000-0000-000000000001',
  true
);

insert into public.dealer_authorizations (
  id,
  dealer_party_id,
  public_reference,
  dealer_type_id,
  jurisdiction_id,
  status_definition_id,
  effective_from,
  effective_until,
  public_disclosure_enabled
)
values (
  'de000000-0000-0000-0000-000000000001',
  'dd000000-0000-0000-0000-000000000001',
  'DLR-OTHER-DEMO',
  '93000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001',
  '2026-01-01T00:00:00Z',
  '2028-01-01T00:00:00Z',
  false
);

insert into public.licenses (
  id,
  public_reference,
  holder_party_id,
  dealer_authorization_id,
  license_class_id,
  jurisdiction_id,
  status_definition_id,
  issued_at,
  effective_from,
  expires_at,
  private_notes,
  public_disclosure_enabled
)
values (
  'df000000-0000-0000-0000-000000000001',
  'LIC-OTHER-DEMO',
  'dd000000-0000-0000-0000-000000000001',
  'de000000-0000-0000-0000-000000000001',
  '96000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001',
  '97000000-0000-0000-0000-000000000001',
  '2026-01-01T00:00:00Z',
  '2026-01-01T00:00:00Z',
  '2028-01-01T00:00:00Z',
  'Other dealer private note must not cross organization scope.',
  false
);

insert into public.party_representatives (
  id,
  principal_party_id,
  actor_id,
  role_definition_id,
  authority_scope,
  effective_from,
  effective_until,
  revoked_at,
  verified_at
)
values
  (
    'dc000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000001',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    null,
    '2026-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000002',
    'dd000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000002',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    null,
    '2026-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000003',
    '92000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000003',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2024-01-01T00:00:00Z',
    '2025-01-01T00:00:00Z',
    null,
    '2024-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000004',
    '92000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000004',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    null,
    '2026-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000005',
    '92000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000005',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    '2026-06-01T00:00:00Z',
    '2026-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000006',
    '92000000-0000-0000-0000-000000000001',
    'db000000-0000-0000-0000-000000000006',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    null,
    '2026-01-01T00:00:00Z'
  ),
  (
    'dc000000-0000-0000-0000-000000000007',
    '92000000-0000-0000-0000-000000000003',
    'db000000-0000-0000-0000-000000000007',
    (select id from public.representative_role_definitions where code = 'portal-representative'),
    '{"portal.read": true}'::jsonb,
    '2026-01-01T00:00:00Z',
    null,
    null,
    '2026-01-01T00:00:00Z'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  public.get_dealer_portal_overview() ->> 'actor_display_name',
  'Active Dealer Representative',
  'the overview identifies the authenticated dealer actor'
);
select is(
  jsonb_array_length(public.get_dealer_portal_overview() -> 'representations'),
  1,
  'the actor sees only one active represented organization'
);
select is(
  public.get_dealer_portal_overview() #>> '{representations,0,party_name}',
  'Harbor Supply Cooperative',
  'the actor sees the represented organization name'
);
select ok(
  public.get_dealer_portal_overview() @> '{"representations":[{"dealer_authorizations":[{"public_reference":"DLR-DEMO-A7K9"}]}]}'::jsonb,
  'the actor sees the represented organization dealer authorization'
);
select ok(
  public.get_dealer_portal_overview() @> '{"representations":[{"licenses":[{"public_reference":"LIC-DEMO-4Q2M"}]}]}'::jsonb,
  'the actor sees the represented organization license'
);
select ok(
  public.get_dealer_portal_overview() @> '{"representations":[{"licenses":[{"endorsements":[{"label":"Calibrated instrument trade"}]}]}]}'::jsonb,
  'the actor sees current endorsement labels for the represented organization'
);
select ok(
  public.get_dealer_portal_overview() @> '{"representations":[{"licenses":[{"public_conditions":["Valid only for the published registered premises."]}]}]}'::jsonb,
  'the actor sees public conditions on the represented organization license'
);
select ok(
  public.get_dealer_portal_overview()::text not like '%Private license note:%'
  and public.get_dealer_portal_overview()::text not like '%Private dealer note:%'
  and public.get_dealer_portal_overview()::text not like '%Fictional Harbor Supply Cooperative%',
  'private notes and legal names are absent from the dealer overview'
);
select ok(
  public.get_dealer_portal_overview()::text not like '%LIC-OTHER-DEMO%'
  and public.get_dealer_portal_overview()::text not like '%Other dealer private note%',
  'another dealer organization cannot leak into the overview'
);
select ok(
  (public.get_dealer_portal_overview() ->> 'generated_at') is not null,
  'the dealer overview includes a generated-at timestamp'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
select ok(
  public.get_dealer_portal_overview() @> '{"representations":[{"licenses":[{"public_reference":"LIC-OTHER-DEMO"}]}]}'::jsonb,
  'the other representative sees its own organization license'
);
select ok(
  public.get_dealer_portal_overview()::text not like '%LIC-DEMO-4Q2M%',
  'the other representative cannot see the first organization license'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_dealer_portal_overview()$test$,
  '42501',
  'dealer_access_denied',
  'an expired representation is denied'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_dealer_portal_overview()$test$,
  '42501',
  'dealer_access_denied',
  'a representation without portal.read scope is denied'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_dealer_portal_overview()$test$,
  '42501',
  'dealer_access_denied',
  'a revoked representation is denied'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_dealer_portal_overview()$test$,
  '28000',
  'dealer_authentication_required',
  'a staff actor cannot use the dealer overview even with a representation row'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"da000000-0000-0000-0000-000000000007","role":"authenticated"}',
  true
);
select throws_ok(
  $test$select public.get_dealer_portal_overview()$test$,
  '42501',
  'dealer_access_denied',
  'a represented party without a current dealer authorization is denied'
);

select * from finish();
rollback;
