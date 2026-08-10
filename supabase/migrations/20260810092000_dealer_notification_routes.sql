insert into public.notification_templates (
  code, event_type, destination_type, message_template
)
values
  (
    'staff-dealer-created-v1',
    'dealer.authorization_created',
    'discord_channel',
    'Dealer {{public_reference}} was onboarded with status {{status_code}}.'
  ),
  (
    'staff-dealer-updated-v1',
    'dealer.authorization_updated',
    'discord_channel',
    'Dealer authorization {{dealer_authorization_id}} details were updated to version {{version}}.'
  ),
  (
    'staff-dealer-status-v1',
    'dealer.authorization_status_changed',
    'discord_channel',
    'Dealer authorization {{dealer_authorization_id}} changed from {{previous_status_code}} to {{status_code}}.'
  );

insert into public.integration_event_routes (
  event_type, destination_id, notification_template_id, active
)
select template.event_type, destination.id, template.id, true
from public.notification_templates as template
join public.integration_destinations as destination
  on destination.code = 'staff-alerts'
where template.event_type in (
  'dealer.authorization_created',
  'dealer.authorization_updated',
  'dealer.authorization_status_changed'
);
