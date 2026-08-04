begin;

select plan(21);

select has_table('public', 'items', 'items table exists');
select has_table('public', 'item_publications', 'publication table exists');
select has_table('public', 'audit_log', 'audit table exists');
select has_function(
  'public',
  'get_public_catalogue',
  array['text', 'text'],
  'public catalogue RPC exists'
);
select has_function(
  'public',
  'get_public_catalogue_categories',
  array[]::text[],
  'public category RPC exists'
);
select has_function(
  'public',
  'get_public_catalogue_item',
  array['text'],
  'public item detail RPC exists'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.items'::regclass),
  'items has row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.item_publications'::regclass),
  'publications have row-level security enabled'
);
select ok(
  not has_table_privilege('anon', 'public.items', 'select'),
  'anonymous callers cannot select item rows directly'
);
select ok(
  not has_table_privilege('anon', 'public.item_publications', 'select'),
  'anonymous callers cannot select publication rows directly'
);
select ok(
  has_function_privilege('anon', 'public.get_public_catalogue(text,text)', 'execute'),
  'anonymous callers can execute the public catalogue RPC'
);

insert into public.currencies (
  id, code, display_name, symbol, symbol_position, minor_unit_scale
) values (
  'a0000000-0000-0000-0000-000000000001',
  'TEST',
  'Test currency',
  'T',
  'prefix',
  0
);

insert into public.units_of_measure (id, code, display_name, symbol)
values (
  'a0000000-0000-0000-0000-000000000002',
  'test-each',
  'Test each',
  'ea'
);

insert into public.item_categories (id, code, display_name, sort_order)
values (
  'a0000000-0000-0000-0000-000000000003',
  'test-category',
  'Test category',
  999
);

insert into public.item_tags (id, code, display_name)
values (
  'a0000000-0000-0000-0000-000000000004',
  'test-tag',
  'Test tag'
);

insert into public.control_profiles (
  id, code, display_name, public_description
) values (
  'a0000000-0000-0000-0000-000000000005',
  'test-control',
  'Test control',
  'A public test control description.'
);

insert into public.availability_profiles (
  id, code, display_name, public_description
) values (
  'a0000000-0000-0000-0000-000000000006',
  'test-available',
  'Test available',
  'A public test availability description.'
);

insert into public.items (
  id,
  item_code,
  slug,
  display_name,
  description,
  category_id,
  unit_id,
  inventory_mode,
  internal_notes
)
values
  (
    'a0000000-0000-0000-0000-000000000007',
    'TEST-PUBLIC-1',
    'test-public-item',
    'Internal source name',
    'Internal source description',
    'a0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000002',
    'fungible',
    'secret internal note'
  ),
  (
    'a0000000-0000-0000-0000-000000000008',
    'TEST-PRIVATE-1',
    'test-private-item',
    'Private item',
    'Private description',
    'a0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000002',
    'serialized',
    'must not leak'
  );

insert into public.item_tag_assignments (item_id, tag_id)
values (
  'a0000000-0000-0000-0000-000000000007',
  'a0000000-0000-0000-0000-000000000004'
);

insert into public.item_publications (
  item_id,
  audience_code,
  publication_status,
  public_name,
  public_description,
  control_profile_id,
  availability_profile_id,
  requirement_summary,
  order_increment,
  effective_from
)
values
  (
    'a0000000-0000-0000-0000-000000000007',
    'public',
    'published',
    'Public test item',
    'A published item used for projection tests.',
    'a0000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000006',
    'A public test requirement.',
    1,
    '2026-01-01T00:00:00Z'
  ),
  (
    'a0000000-0000-0000-0000-000000000008',
    'public',
    'draft',
    'Private draft item',
    'A draft item that must not be exposed.',
    'a0000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000006',
    'Not public.',
    1,
    '2026-01-01T00:00:00Z'
  );

insert into public.price_schedules (
  id,
  code,
  display_name,
  audience_code,
  currency_id,
  status,
  effective_from
)
values (
  'a0000000-0000-0000-0000-000000000009',
  'test-public-schedule',
  'Test public schedule',
  'public',
  'a0000000-0000-0000-0000-000000000001',
  'active',
  '2026-01-01T00:00:00Z'
);

insert into public.price_rules (
  price_schedule_id,
  item_id,
  amount_minor,
  effective_from,
  approved_at
)
values (
  'a0000000-0000-0000-0000-000000000009',
  'a0000000-0000-0000-0000-000000000007',
  999,
  '2026-01-01T00:00:00Z',
  '2026-01-01T00:00:00Z'
);

set local role anon;

select is(
  (
    select count(*)::integer
    from public.get_public_catalogue(null, null)
    where item_code like 'TEST-%'
  ),
  1,
  'only the published test item appears publicly'
);
select is(
  (
    select count(*)::integer
    from public.get_public_catalogue('Public test', null)
    where item_code = 'TEST-PUBLIC-1'
  ),
  1,
  'public search finds the approved presentation'
);
select is(
  (
    select count(*)::integer
    from public.get_public_catalogue(null, 'test-category')
    where item_code = 'TEST-PUBLIC-1'
  ),
  1,
  'category filtering is performed by the public RPC'
);
select ok(
  not (
    select to_jsonb(entry) ? 'internal_notes'
    from public.get_public_catalogue(null, null) as entry
    where item_code = 'TEST-PUBLIC-1'
  ),
  'the public response has no internal_notes field'
);
select is(
  (
    select price_amount_minor
    from public.get_public_catalogue(null, null)
    where item_code = 'TEST-PUBLIC-1'
  ),
  999::bigint,
  'the public response returns integer minor-unit pricing'
);
select is(
  (
    select tags
    from public.get_public_catalogue(null, null)
    where item_code = 'TEST-PUBLIC-1'
  ),
  array['Test tag']::text[],
  'the public response returns approved active tags'
);
select is(
  (
    select count(*)::integer
    from public.get_public_catalogue_item('test-public-item')
  ),
  1,
  'the public detail RPC returns a published item'
);
select is(
  (
    select count(*)::integer
    from public.get_public_catalogue_item('test-private-item')
  ),
  0,
  'the public detail RPC does not reveal a draft item'
);
select is(
  (
    select item_count
    from public.get_public_catalogue_categories()
    where code = 'test-category'
  ),
  1::bigint,
  'the category projection counts only published items'
);
select ok(
  (
    select generated_at is not null
    from public.get_public_catalogue(null, null)
    where item_code = 'TEST-PUBLIC-1'
  ),
  'the public response includes a projection timestamp'
);

select * from finish();
rollback;
