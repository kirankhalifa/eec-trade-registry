const notices: Record<string, string> = {
  authorized: "The transfer is authorized and ready for dispatch.",
  cancelled: "The pending transfer was cancelled without moving stock.",
  created: "The transfer request was recorded for authorization.",
  dispatched: "Stock moved from the source warehouse into in-transit custody.",
  disputed: "The receiving discrepancy was recorded; stock remains in transit.",
  received: "Transit custody was cleared and the destination stock was posted.",
};

const errors: Record<string, string> = {
  access_denied: "Your current warehouse assignment does not permit that transfer action.",
  conflict: "The transfer changed first. Reload its current version before trying again.",
  insufficient_stock: "Unreserved source stock is insufficient for dispatch.",
  invalid_input: "Review the accounts, quantity, current state, and audit reason.",
  not_found: "The selected transfer or inventory account is not available.",
  save_failed: "The transfer command was rejected; no partial custody movement was accepted.",
};

export function TransferNotice({ error, notice }: { error?: string; notice?: string }) {
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
