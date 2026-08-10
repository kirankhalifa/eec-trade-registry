const notices: Record<string, string> = {
  agreement_created: "The consignment agreement was recorded.",
  agreement_status: "The agreement status was updated with an audit record.",
  issued: "Stock was moved into dealer custody while ownership remained unchanged.",
  report_submitted: "The custody report was submitted for staff review.",
  report_accepted: "The report was accepted and its authoritative settlement was posted.",
  report_rejected: "The report was rejected without changing inventory.",
};
const errors: Record<string, string> = {
  access_denied: "Your current authority does not permit that consignment action.",
  conflict: "The record changed first. Reload the latest version and try again.",
  duplicate_report: "A submitted report is already awaiting review for this issue.",
  exception_review: "Lost or damaged quantities require the separate exception process and cannot be settled here.",
  insufficient_stock: "Available warehouse stock is insufficient after active reservations.",
  invalid_input: "Review the selected agreement, quantities, observation, destination, dates, and audit reason.",
  not_found: "The selected agreement, issue, report, account, or jurisdiction is unavailable.",
  observation_mismatch: "The observed custody count does not reconcile to sold and returned quantities.",
  save_failed: "The command was rejected. No partial authoritative state was accepted.",
};

export function ConsignmentNotice({ error, notice }: { error?: string; notice?: string }) {
  const errorMessage = error ? errors[error] : undefined;
  const noticeMessage = notice ? notices[notice] : undefined;
  if (!errorMessage && !noticeMessage) return null;
  return <div className={`staff-flash ${errorMessage ? "staff-flash-error" : ""}`} role={errorMessage ? "alert" : "status"}>{errorMessage ?? noticeMessage}</div>;
}
