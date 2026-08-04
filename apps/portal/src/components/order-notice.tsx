const notices: Record<string, string> = {
  cancelled: "The unfulfilled order was cancelled and its history was preserved.",
  line_priced: "The line price was recorded from the staff review command.",
  line_reviewed: "The line decision was recorded and the order status was refreshed.",
  submitted:
    "The requisition was submitted for review. Submission did not reserve or require stock.",
};

const errors: Record<string, string> = {
  access_denied: "Your current assignment or representative grant does not permit that action.",
  conflict: "The order changed first. Review its current version before trying again.",
  invalid_input: "Review the requested items, quantities, decision, and audit reason.",
  not_found: "The requested order record is not available.",
  save_failed: "The command could not be completed. No partial state was accepted.",
};

export function OrderNotice({
  error,
  notice,
}: {
  error?: string;
  notice?: string;
}) {
  const errorMessage = error ? errors[error] : undefined;
  const noticeMessage = notice ? notices[notice] : undefined;
  if (!errorMessage && !noticeMessage) return null;

  return (
    <div
      className={`staff-flash ${errorMessage ? "staff-flash-error" : ""}`}
      role={errorMessage ? "alert" : "status"}
    >
      {errorMessage ?? noticeMessage}
    </div>
  );
}
