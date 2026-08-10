const notices: Record<string, string> = {
  expired: "The elapsed reservation was finalized and its stock claim released.",
  extended: "The reservation expiration was extended with an audited reason.",
  receipt_posted: "The balanced receipt was posted to the immutable inventory ledger.",
  released: "The unconsumed reservation was released back to available stock.",
  reservation_created: "The approved order quantity was reserved for 48 hours.",
  reversed: "A linked reversal was posted. The original receipt remains immutable.",
};

const errors: Record<string, string> = {
  access_denied: "Your current assignment does not permit that warehouse action.",
  conflict: "The record changed first. Reload its current version before trying again.",
  insufficient_stock: "The requested quantity is no longer available for reservation.",
  invalid_input: "Review the item, location, quantity, expiration, provenance, and audit reason.",
  not_found: "The requested inventory or reservation record is not available.",
  player_source_required: "This keystone material can enter stock only through a registered supplier delivery on the economy desk.",
  save_failed: "The inventory command was rejected. No partial ledger state was accepted.",
};

export function InventoryNotice({ error, notice }: { error?: string; notice?: string }) {
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
