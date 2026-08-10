begin;

select plan(6);

select has_function('public', 'integration_queue_due_exports', array['timestamp with time zone'], 'schedule queue function exists');

update public.integration_destinations
set active = true, external_reference = 'test-spreadsheet'
where code = 'public-registry-sheet';

update public.export_definitions
set active = (code = 'public-catalogue'),
    next_run_at = case
      when code = 'public-catalogue' then '2030-01-01T00:00:30Z'::timestamptz
      else '2030-01-01T00:01:01Z'::timestamptz
    end
where destination_id = (select id from public.integration_destinations where code = 'public-registry-sheet');

set local role service_role;

select is(
  public.integration_queue_due_exports('2030-01-01T00:00:00Z'),
  1,
  'a definition thirty seconds after the worker tick is queued within tolerance'
);
select is(
  (select count(*)::integer from public.export_runs where scheduled_for = '2030-01-01T00:00:30Z'),
  1,
  'the queued run preserves its configured schedule instant'
);
select is(
  (select next_run_at from public.export_definitions where code = 'public-catalogue'),
  '2030-01-01T00:15:30Z'::timestamptz,
  'the next schedule retains cadence without accumulating early-worker drift'
);
select is(
  public.integration_queue_due_exports('2030-01-01T00:00:00Z'),
  0,
  'repeating the same worker instant is idempotent'
);

update public.export_definitions
set active = true
where code = 'public-dealers';

select is(
  public.integration_queue_due_exports('2030-01-01T00:00:00Z'),
  0,
  'a definition more than sixty seconds ahead is not queued early'
);
select is(
  (select count(*)::integer from public.export_runs where scheduled_for = '2030-01-01T00:01:01Z'),
  0,
  'no premature run is created outside the bounded tolerance'
);

select * from finish();
rollback;
