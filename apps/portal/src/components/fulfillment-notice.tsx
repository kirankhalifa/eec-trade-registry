const notices: Record<string, string> = {
  completed:
    "The reservation was consumed, the balanced stock issue posted, and the order state updated.",
  reversed:
    "A linked reversal restored stock and reopened demand. The consumed reservation remains historical evidence.",
};

const errors: Record<string, string> = {
  access_denied: "Your current assignment does not permit that fulfillment action.",
  conflict: "The record changed first. Reload its current version before trying again.",
  insufficient_stock: "The reserved physical stock is no longer sufficient for completion.",
  invalid_input: "Review the selected record, optimistic version, and audit reason.",
  not_found: "The requested reservation or fulfillment is not available.",
  save_failed: "The fulfillment command was rejected. No partial ledger state was accepted.",
};

export function FulfillmentNotice({
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
