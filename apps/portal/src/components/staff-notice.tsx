const notices: Record<string, string> = {
  active: "The item is active again.",
  archived: "The item was archived and removed from public results.",
  created: "The canonical item was created as an unpublished record.",
  endorsement_granted: "The endorsement was granted and recorded in license history.",
  endorsement_revoked: "The endorsement was revoked without deleting its history.",
  license_issued: "The license was issued and its public reference was allocated.",
  license_status_changed: "The license status decision was recorded.",
  integration_destination_saved: "The integration destination configuration was saved.",
  export_schedule_saved: "The public export schedule was saved.",
  export_queued: "A public projection snapshot was queued for the next worker cycle.",
  export_requeued: "The failed export was returned to the worker queue.",
  delivery_requeued: "The failed notification was returned to the worker queue.",
  role_granted: "The staff role was granted and its effective authority is now visible.",
  role_revoked: "The staff role was revoked without deleting its assignment history.",
  saved: "The catalogue record was saved.",
};

const errors: Record<string, string> = {
  access_denied: "Your current staff assignment does not permit that action.",
  conflict:
    "Another staff member changed this record first. Review the current values before saving again.",
  duplicate: "That item code or public slug is already in use.",
  invalid_input: "Review the form fields and provide a clear audit reason.",
  last_administrator: "The last active platform administrator cannot be revoked.",
  not_found: "The requested authoritative record no longer exists.",
  save_failed: "The change could not be saved. No authoritative data was changed.",
};

export function StaffNotice({
  error,
  notice,
}: {
  error?: string;
  notice?: string;
}) {
  const errorMessage = error ? errors[error] : undefined;
  const noticeMessage = notice ? notices[notice] : undefined;
  if (!errorMessage && !noticeMessage) {
    return null;
  }

  return (
    <div
      className={`staff-flash ${errorMessage ? "staff-flash-error" : ""}`}
      role={errorMessage ? "alert" : "status"}
    >
      {errorMessage ?? noticeMessage}
    </div>
  );
}
