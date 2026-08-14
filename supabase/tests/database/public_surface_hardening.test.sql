begin;

select plan(23);

select has_table(
  'private',
  'public_verification_rate_limits',
  'private verification rate-limit buckets exist'
);
select has_function(
  'public',
  'consume_public_verification_rate_limit',
  array['text', 'text'],
  'verification rate-limit command exists'
);
select has_table('private', 'scope_key_definitions', 'scope key definitions are explicit data');
select has_function('private', 'scope_object_is_valid', array['text', 'jsonb'], 'scope validator exists');
select ok(private.scope_object_is_valid('staff_assignment', '{}'::jsonb), 'global staff scope is valid');
select ok(not private.scope_object_is_valid('staff_assignment', '{"warehose_ids": []}'::jsonb), 'unknown staff scope keys fail loudly');
select ok(not private.scope_object_is_valid('staff_assignment', '{"warehouse_ids": ["not-a-uuid"]}'::jsonb), 'malformed warehouse scopes fail loudly');
select matches(private.allocate_license_reference(), '^EEC-LIC-[0-9]{4}-[A-F0-9]{10}$', 'new license references include entropy');
select matches(private.allocate_dealer_reference(), '^EEC-DLR-[0-9]{4}-[A-F0-9]{10}$', 'new dealer references include entropy');
select has_function(
  'public',
  'get_public_catalogue_entry_state',
  array['text'],
  'catalogue state query exists'
);
select ok(
  not has_function_privilege('anon', 'public.public_dealer_verification(text)', 'execute'),
  'anonymous clients cannot bypass the web verification limiter'
);
select ok(
  has_function_privilege('service_role', 'public.public_dealer_verification(text)', 'execute'),
  'the secure server can perform dealer verification'
);
select ok(
  not has_function_privilege('anon', 'public.consume_public_verification_rate_limit(text,text)', 'execute'),
  'anonymous clients cannot reset or consume arbitrary limit buckets'
);
select ok(
  has_function_privilege('service_role', 'public.consume_public_verification_rate_limit(text,text)', 'execute'),
  'the secure server can consume limit buckets'
);

set local role anon;

select is(
  public.get_public_catalogue_entry_state('harbor-lantern'),
  'withdrawn',
  'an archived formerly published entry is explicitly withdrawn'
);
select is(
  public.get_public_catalogue_entry_state('unpublished-prototype'),
  'not_found',
  'a never-published draft is not disclosed'
);
select is(
  public.get_public_catalogue_entry_state('building-stone'),
  'published',
  'a current entry is published'
);
select is(
  public.get_public_catalogue_entry_state('does-not-exist'),
  'not_found',
  'an unknown slug remains indistinguishable from a private draft'
);
select ok(
  not exists (
    select 1
    from public.get_public_catalogue(null, null) as entry
    where not exists (
      select 1
      from public.get_public_catalogue_item(entry.slug)
    )
  ),
  'every published catalogue link resolves to its authoritative detail record'
);

reset role;
set local role service_role;

select ok(
  public.consume_public_verification_rate_limit(repeat('a', 64), repeat('b', 64)),
  'the first lookup is accepted'
);
select ok(
  public.consume_public_verification_rate_limit(repeat('a', 64), repeat('b', 64)),
  'a routine repeated lookup is accepted'
);
select is(
  (
    select request_count
    from private.public_verification_rate_limits
    where fingerprint = repeat('b', 64)
  ),
  2,
  'the per-reference bucket is consumed atomically'
);

do $$
begin
  for attempt in 1..8 loop
    perform public.consume_public_verification_rate_limit(
      repeat('a', 64),
      repeat('b', 64)
    );
  end loop;
end;
$$;

select ok(
  not public.consume_public_verification_rate_limit(repeat('a', 64), repeat('b', 64)),
  'the eleventh lookup in a window is rejected'
);

select * from finish();
rollback;
