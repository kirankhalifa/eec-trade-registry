create or replace function public.integration_queue_due_exports(
  p_now timestamptz default current_timestamp
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  definition record;
  inserted_count integer := 0;
begin
  for definition in
    select export_definition.*
    from public.export_definitions as export_definition
    join public.integration_destinations as destination
      on destination.id = export_definition.destination_id
      and destination.active
      and destination.destination_type = 'google_sheets'
    where export_definition.active
      and export_definition.next_run_at <= p_now + make_interval(secs => 60)
    order by export_definition.next_run_at
    for update of export_definition skip locked
  loop
    insert into public.export_runs (
      export_definition_id,
      run_key,
      scheduled_for
    )
    values (
      definition.id,
      definition.code || ':' || extract(epoch from definition.next_run_at)::bigint::text,
      definition.next_run_at
    )
    on conflict (run_key) do nothing;

    if found then
      inserted_count := inserted_count + 1;
    end if;

    update public.export_definitions
    set next_run_at = greatest(
      definition.next_run_at
        + make_interval(mins => definition.refresh_interval_minutes),
      p_now + make_interval(mins => definition.refresh_interval_minutes)
    )
    where id = definition.id;
  end loop;

  return inserted_count;
end;
$$;

comment on function public.integration_queue_due_exports(timestamptz) is
  'Queues active projections with a bounded one-minute scheduler tolerance so second-level drift cannot skip a 15-minute worker cycle.';
