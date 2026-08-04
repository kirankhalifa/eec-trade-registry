-- Non-sensitive development data only. Institution-wide values may mirror
-- approved configuration, while parties, goods, prices, and references remain
-- fictional fixtures rather than production records.

insert into public.currencies (
  id, code, display_name, symbol, symbol_position, minor_unit_scale, is_default
) values (
  '10000000-0000-0000-0000-000000000001',
  'SEP',
  'Septims',
  'Septims',
  'suffix',
  0,
  true
);

insert into public.units_of_measure (id, code, display_name, symbol, quantity_scale)
values
  ('20000000-0000-0000-0000-000000000001', 'each', 'Individual item', 'ea', 0),
  ('20000000-0000-0000-0000-000000000002', 'crate', 'Crate', 'crate', 0),
  ('20000000-0000-0000-0000-000000000003', 'lot', 'Trade lot', 'lot', 0);

insert into public.item_categories (id, code, display_name, description, sort_order)
values
  ('30000000-0000-0000-0000-000000000001', 'equipment', 'Equipment', 'Durable tools and instruments.', 10),
  ('30000000-0000-0000-0000-000000000002', 'materials', 'Materials', 'Imported and controlled trade materials.', 20),
  ('30000000-0000-0000-0000-000000000003', 'special-goods', 'Special goods', 'Individually reviewed or serialized goods.', 30);

insert into public.item_tags (id, code, display_name)
values
  ('40000000-0000-0000-0000-000000000001', 'navigation', 'Navigation'),
  ('40000000-0000-0000-0000-000000000002', 'fragile', 'Fragile'),
  ('40000000-0000-0000-0000-000000000003', 'bulk', 'Bulk trade'),
  ('40000000-0000-0000-0000-000000000004', 'secure-storage', 'Secure storage');

insert into public.control_profiles (
  id,
  code,
  display_name,
  public_description,
  requires_staff_review,
  requires_transaction_approval,
  requires_serial_tracking
)
values
  (
    '50000000-0000-0000-0000-000000000001',
    'ordinary',
    'Standard trade',
    'Normal eligibility and fulfilment checks apply.',
    false,
    false,
    false
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    'restricted',
    'Restricted trade',
    'Additional authority or staff review is required before allocation.',
    true,
    false,
    false
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    'unique',
    'Individually controlled',
    'The specific serialized asset requires transaction approval and custody tracking.',
    true,
    true,
    true
  );

insert into public.availability_profiles (
  id, code, display_name, public_description, sort_order
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    'available',
    'Normally available',
    'Published for ordinary requisition, subject to current eligibility and stock.',
    10
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    'limited',
    'Limited allocation',
    'Supply is limited and an allocation review may be required.',
    20
  ),
  (
    '60000000-0000-0000-0000-000000000003',
    'by-request',
    'Available by request',
    'Terms and availability are confirmed after a formal request.',
    30
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
    '70000000-0000-0000-0000-000000000001',
    'EQ-LANTERN-001',
    'harbor-lantern',
    'Harbor Lantern',
    'A weather-resistant lantern intended for commercial docks and transport offices.',
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'fungible',
    'Internal demonstration note: never expose this text.'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    'EQ-SURVEY-001',
    'surveyor-instrument-set',
    'Surveyor Instrument Set',
    'A calibrated set of instruments for licensed survey and navigation work.',
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'fungible',
    'Review calibration certificate before issue.'
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    'MT-FIBER-001',
    'treated-packing-fiber',
    'Treated Packing Fiber',
    'Moisture-resistant packing material supplied in commercial lots.',
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000003',
    'fungible',
    ''
  ),
  (
    '70000000-0000-0000-0000-000000000004',
    'SG-CHRONO-001',
    'master-navigation-chronometer',
    'Master Navigation Chronometer',
    'An individually registered precision instrument released only under special authorization.',
    '30000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    'serialized',
    'Serialized asset registration will be implemented in a later slice.'
  ),
  (
    '70000000-0000-0000-0000-000000000005',
    'INT-PROTOTYPE-001',
    'unpublished-prototype',
    'Unpublished Prototype',
    'This internal item must not appear in the public catalogue.',
    '30000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    'serialized',
    'Restricted internal record used to validate projection leakage.'
  );

insert into public.item_tag_assignments (item_id, tag_id)
values
  ('70000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002'),
  ('70000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003'),
  ('70000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000002');

insert into public.item_publications (
  item_id,
  audience_code,
  publication_status,
  public_name,
  public_description,
  control_profile_id,
  availability_profile_id,
  requirement_summary,
  bulk_minimum,
  order_increment,
  effective_from
)
values
  (
    '70000000-0000-0000-0000-000000000001',
    'public',
    'published',
    'Harbor Lantern',
    'A weather-resistant lantern intended for commercial docks and transport offices.',
    '50000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'No special public authorization is listed; final eligibility is checked when ordering.',
    null,
    1,
    '2026-01-01T00:00:00Z'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    'public',
    'published',
    'Surveyor Instrument Set',
    'A calibrated set of instruments for licensed survey and navigation work.',
    '50000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000002',
    'Documented professional use and staff review are required.',
    null,
    1,
    '2026-01-01T00:00:00Z'
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    'public',
    'published',
    'Treated Packing Fiber',
    'Moisture-resistant packing material supplied in commercial lots.',
    '50000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'Commercial quantities are supplied in complete trade lots.',
    5,
    1,
    '2026-01-01T00:00:00Z'
  ),
  (
    '70000000-0000-0000-0000-000000000004',
    'public',
    'published',
    'Master Navigation Chronometer',
    'An individually registered precision instrument released only under special authorization.',
    '50000000-0000-0000-0000-000000000003',
    '60000000-0000-0000-0000-000000000003',
    'Transaction-specific approval and named-custodian acceptance are required.',
    null,
    1,
    '2026-01-01T00:00:00Z'
  ),
  (
    '70000000-0000-0000-0000-000000000005',
    'public',
    'draft',
    'Unpublished Prototype',
    'This draft publication must remain private.',
    '50000000-0000-0000-0000-000000000003',
    '60000000-0000-0000-0000-000000000003',
    'Not publicly available.',
    null,
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
  '80000000-0000-0000-0000-000000000001',
  'public-standard',
  'Public standard schedule',
  'public',
  '10000000-0000-0000-0000-000000000001',
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
values
  (
    '80000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000001',
    180,
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z'
  ),
  (
    '80000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000002',
    1250,
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z'
  ),
  (
    '80000000-0000-0000-0000-000000000001',
    '70000000-0000-0000-0000-000000000003',
    90,
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z'
  );

insert into public.jurisdictions (
  id, code, internal_name, public_name, default_timezone
)
values (
  '90000000-0000-0000-0000-000000000001',
  'harbor-district',
  'Demonstration Harbor District',
  'Harbor District',
  'America/New_York'
);

insert into public.party_types (id, code, display_name)
values
  ('91000000-0000-0000-0000-000000000001', 'organization', 'Organization'),
  ('91000000-0000-0000-0000-000000000002', 'individual', 'Individual');

insert into public.parties (
  id,
  party_type_id,
  legal_name,
  display_name,
  public_display_name,
  primary_jurisdiction_id,
  public_profile_enabled
)
values
  (
    '92000000-0000-0000-0000-000000000001',
    '91000000-0000-0000-0000-000000000001',
    'Fictional Harbor Supply Cooperative',
    'Harbor Supply Cooperative',
    'Harbor Supply Cooperative',
    '90000000-0000-0000-0000-000000000001',
    true
  ),
  (
    '92000000-0000-0000-0000-000000000002',
    '91000000-0000-0000-0000-000000000002',
    'Fictional Registry Holder',
    'Registry Holder',
    'Registry Holder',
    '90000000-0000-0000-0000-000000000001',
    true
  ),
  (
    '92000000-0000-0000-0000-000000000003',
    '91000000-0000-0000-0000-000000000001',
    'Private Demonstration Counterparty',
    'Private Counterparty',
    null,
    '90000000-0000-0000-0000-000000000001',
    false
  );

insert into public.dealer_types (id, code, display_name, public_description)
values (
  '93000000-0000-0000-0000-000000000001',
  'wholesale-counterparty',
  'Authorized wholesale counterparty',
  'Approved for wholesale requisitions subject to current licensing and item rules.'
);

insert into public.dealer_status_definitions (
  id,
  code,
  display_name,
  public_result_code,
  confers_authority,
  publicly_verifiable
)
values
  (
    '94000000-0000-0000-0000-000000000001',
    'active',
    'Current authorization',
    'valid',
    true,
    true
  ),
  (
    '94000000-0000-0000-0000-000000000002',
    'internal-review',
    'Internal review',
    'not_verifiable',
    false,
    false
  );

insert into public.dealer_authorizations (
  id,
  dealer_party_id,
  public_reference,
  dealer_type_id,
  jurisdiction_id,
  status_definition_id,
  approved_premises_public,
  public_notes,
  private_notes,
  effective_from,
  effective_until,
  public_disclosure_enabled
)
values
  (
    '95000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000001',
    'DLR-DEMO-A7K9',
    '93000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    '94000000-0000-0000-0000-000000000001',
    'Registered Harbor District premises',
    'Demonstration public authorization record.',
    'Private dealer note: this text must never be projected.',
    '2026-01-01T00:00:00Z',
    '2028-01-01T00:00:00Z',
    true
  ),
  (
    '95000000-0000-0000-0000-000000000002',
    '92000000-0000-0000-0000-000000000003',
    'DLR-PRIVATE-DEMO',
    '93000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    '94000000-0000-0000-0000-000000000002',
    null,
    '',
    'Hidden dealer record used for leakage tests.',
    '2026-01-01T00:00:00Z',
    null,
    false
  );

insert into public.endorsement_definitions (
  id, code, display_name, public_display_name, description
)
values (
  '98000000-0000-0000-0000-000000000001',
  'calibrated-instruments',
  'Calibrated instrument trade',
  'Calibrated instrument trade',
  'A fictional modular endorsement with no production policy effect.'
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
  public_notes,
  private_notes,
  public_disclosure_enabled
)
values
  (
    '99000000-0000-0000-0000-000000000001',
    'LIC-DEMO-4Q2M',
    '92000000-0000-0000-0000-000000000001',
    '95000000-0000-0000-0000-000000000001',
    '96000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    '97000000-0000-0000-0000-000000000001',
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z',
    '2028-01-01T00:00:00Z',
    'Demonstration public license record.',
    'Private license note: this text must never be projected.',
    true
  ),
  (
    '99000000-0000-0000-0000-000000000002',
    'LIC-PRIVATE-DEMO',
    '92000000-0000-0000-0000-000000000003',
    null,
    '96000000-0000-0000-0000-000000000001',
    '90000000-0000-0000-0000-000000000001',
    '97000000-0000-0000-0000-000000000002',
    '2026-01-01T00:00:00Z',
    '2026-01-01T00:00:00Z',
    null,
    '',
    'Hidden license record used for leakage tests.',
    false
  );

insert into public.license_endorsements (
  id,
  license_id,
  endorsement_definition_id,
  effective_from,
  expires_at,
  public_disclosure_enabled
)
values (
  'b1000000-0000-0000-0000-000000000001',
  '99000000-0000-0000-0000-000000000001',
  '98000000-0000-0000-0000-000000000001',
  '2026-01-01T00:00:00Z',
  '2028-01-01T00:00:00Z',
  true
);

insert into public.license_conditions (
  id,
  license_id,
  condition_code,
  public_text,
  private_text,
  public_visibility,
  effective_from
)
values
  (
    'b2000000-0000-0000-0000-000000000001',
    '99000000-0000-0000-0000-000000000001',
    'registered-premises',
    'Valid only for the published registered premises.',
    '',
    true,
    '2026-01-01T00:00:00Z'
  ),
  (
    'b2000000-0000-0000-0000-000000000002',
    '99000000-0000-0000-0000-000000000001',
    'internal-review-note',
    null,
    'Private condition: this text must never be projected.',
    false,
    '2026-01-01T00:00:00Z'
  );
