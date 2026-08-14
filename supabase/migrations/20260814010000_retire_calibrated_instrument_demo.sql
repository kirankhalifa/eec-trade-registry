-- The original fixture uses calibrated-instruments, not instrument-trade.
-- Retire its development-only copy from every public application projection.
update public.endorsement_definitions
set active = false
where code = 'calibrated-instruments'
  and description ilike '%fictional%production policy%';
