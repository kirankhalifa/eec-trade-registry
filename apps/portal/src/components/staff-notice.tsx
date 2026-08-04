const notices: Record<string, string> = {
  active: "The item is active again.",
  archived: "The item was archived and removed from public results.",
  created: "The canonical item was created as an unpublished record.",
  saved: "The catalogue record was saved.",
};

const errors: Record<string, string> = {
  access_denied: "Your current staff assignment does not permit that action.",
  conflict:
    "Another staff member changed this item first. Review the current values before saving again.",
  duplicate: "That item code or public slug is already in use.",
  invalid_input: "Review the form fields and provide a clear audit reason.",
  not_found: "The catalogue item no longer exists.",
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
