begin;

select plan(44);

select has_table('public', 'parties', 'parties table exists');
select has_table('public', 'dealer_authorizations', 'dealer authorizations table exists');
select has_table('public', 'licenses', 'licenses table exists');
select has_table('public', 'license_endorsements', 'license endorsements table exists');
select has_table('public', 'license_conditions', 'license conditions table exists');
select has_function(
  'public',
  'public_dealer_verification',
  array['text'],
  'public dealer verification RPC exists'
);
select has_function(
  'public',
  'public_license_verification',
  array['text'],
  'public license verification RPC exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.parties'::regclass),
  'parties have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.licenses'::regclass),
  'licenses have row-level security enabled'
);
select ok(
  not has_table_privilege('anon', 'public.parties', 'select'),
  'anonymous callers cannot select parties directly'
);
select ok(
  not has_table_privilege('anon', 'public.dealer_authorizations', 'select'),
  'anonymous callers cannot select dealer authorizations directly'
);
select ok(
  not has_table_privilege('anon', 'public.licenses', 'select'),
  'anonymous callers cannot select licenses directly'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.public_dealer_verification(text)',
    'execute'
  ),
  'anonymous callers cannot bypass the web dealer-verification limiter'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.public_license_verification(text)',
    'execute'
  ),
  'anonymous callers cannot bypass the web license-verification limiter'
);

insert into public.licenses (
  id,
  public_reference,
  holder_party_id,
  license_class_id,
  jurisdiction_id,
  status_definition_id,
  issued_at,
  effective_from,
  expires_at,
  public_disclosure_enabled
)
values (
  'a3000000-0000-0000-0000-000000000001',
  'LIC-DEMO-EXPIRED',
  '92000000-0000-0000-0000-000000000002',
  '96000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001',
  '97000000-0000-0000-0000-000000000001',
  '2024-01-01T00:00:00Z',
  '2024-01-01T00:00:00Z',
  '2025-01-01T00:00:00Z',
  true
);

set local role service_role;

select is(
  (
    select result_code
    from public.public_dealer_verification('  dlr-demo-a7k9  ')
  ),
  'valid',
  'dealer verification normalizes surrounding whitespace and case'
);
select is(
  (
    select public_name
    from public.public_dealer_verification('DLR-DEMO-A7K9')
  ),
  'Harbor Supply Cooperative',
  'dealer verification returns only the approved public name'
);
select ok(
  (
    select is_currently_authorized
    from public.public_dealer_verification('DLR-DEMO-A7K9')
  ),
  'current dealer term and status confer authority'
);
select ok(
  (
    select license_summaries @> '[{"public_reference":"LIC-DEMO-4Q2M"}]'::jsonb
    from public.public_dealer_verification('DLR-DEMO-A7K9')
  ),
  'dealer verification includes an approved public license summary'
);
select ok(
  not (
    select to_jsonb(result) ? 'private_notes'
    from public.public_dealer_verification('DLR-DEMO-A7K9') as result
  ),
  'dealer response has no private notes field'
);
select is(
  (
    select result_code
    from public.public_dealer_verification('DLR-PRIVATE-DEMO')
  ),
  'not_verifiable',
  'non-public dealer records use the generic miss result'
);
select is(
  (
    select public_reference
    from public.public_dealer_verification('DLR-PRIVATE-DEMO')
  ),
  null,
  'non-public dealer records do not echo a stored reference'
);
select is(
  (
    select result_code
    from public.public_dealer_verification('Harbor Supply Cooperative')
  ),
  'not_verifiable',
  'dealer verification does not provide name search'
);

select is(
  (
    select result_code
    from public.public_license_verification(' lic-demo-4q2m ')
  ),
  'valid',
  'license verification normalizes surrounding whitespace and case'
);
select is(
  (
    select holder_name
    from public.public_license_verification('LIC-DEMO-4Q2M')
  ),
  'Harbor Supply Cooperative',
  'license verification returns the approved holder name'
);
select ok(
  (
    select is_currently_authorized
    from public.public_license_verification('LIC-DEMO-4Q2M')
  ),
  'current license status and dates confer authority'
);
select is(
  (
    select endorsements
    from public.public_license_verification('LIC-DEMO-4Q2M')
  ),
  array['Calibrated instrument trade']::text[],
  'license verification returns approved current endorsements'
);
select is(
  (
    select public_conditions
    from public.public_license_verification('LIC-DEMO-4Q2M')
  ),
  array['Valid only for the published registered premises.']::text[],
  'license verification returns only public current conditions'
);
select is(
  (
    select public_notice
    from public.public_license_verification('LIC-DEMO-4Q2M')
  ),
  'Demonstration public license record.',
  'license verification returns the approved public notice'
);
select ok(
  not (
    select to_jsonb(result) ? 'private_notes'
    from public.public_license_verification('LIC-DEMO-4Q2M') as result
  ),
  'license response has no private notes field'
);
select ok(
  not (
    select to_jsonb(result) ? 'private_text'
    from public.public_license_verification('LIC-DEMO-4Q2M') as result
  ),
  'license response has no private condition text field'
);
select ok(
  not (
    select to_jsonb(result) ? 'legal_name'
    from public.public_license_verification('LIC-DEMO-4Q2M') as result
  ),
  'license response has no private legal-name field'
);
select is(
  (
    select result_code
    from public.public_license_verification('LIC-PRIVATE-DEMO')
  ),
  'not_verifiable',
  'non-public licenses use the generic miss result'
);
select is(
  (
    select public_reference
    from public.public_license_verification('LIC-PRIVATE-DEMO')
  ),
  null,
  'non-public licenses do not echo a stored reference'
);
select is(
  (
    select result_code
    from public.public_license_verification('LIC-DEMO-EXPIRED')
  ),
  'expired',
  'an elapsed license term is reported as expired'
);
select ok(
  not (
    select is_currently_authorized
    from public.public_license_verification('LIC-DEMO-EXPIRED')
  ),
  'an elapsed license term does not confer authority'
);
select is(
  (
    select result_code
    from public.public_license_verification('LIC-DOES-NOT-EXIST')
  ),
  'not_verifiable',
  'unknown references use the generic miss result'
);
select is(
  (
    select count(*)::integer
    from public.public_license_verification('LIC-DOES-NOT-EXIST')
  ),
  1,
  'license verification always returns one fixed-contract row'
);
select ok(
  (
    select verified_at is not null
    from public.public_license_verification('LIC-DOES-NOT-EXIST')
  ),
  'generic misses include a verification timestamp'
);
select is(
  (
    select result_code
    from public.public_dealer_verification('   ')
  ),
  'not_verifiable',
  'blank dealer references use the generic miss result'
);
select is(
  (
    select count(*)::integer
    from public.public_dealer_verification('DLR-DOES-NOT-EXIST')
  ),
  1,
  'dealer verification always returns one fixed-contract row'
);

set local role authenticated;

select ok(
  has_function_privilege(
    'authenticated',
    'public.public_dealer_verification(text)',
    'execute'
  ),
  'authenticated callers can execute public dealer verification'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.public_license_verification(text)',
    'execute'
  ),
  'authenticated callers can execute public license verification'
);
select ok(
  not has_table_privilege('authenticated', 'public.parties', 'select'),
  'authenticated callers cannot select parties directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.licenses', 'select'),
  'authenticated callers cannot select licenses directly'
);

select * from finish();
rollback;
