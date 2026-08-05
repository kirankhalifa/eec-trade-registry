const notices: Record<string, string> = {
  custody: "Accepted custody was recorded without changing ownership.",
  inspected: "Inspection evidence and the next due date were recorded.",
  registered: "The serialized asset and its initial custody event were registered.",
  released: "The exclusive allocation was released or finalized as expired and remains in history.",
  reserved: "The asset was exclusively allocated for 48 hours.",
  status: "The controlled lifecycle event was recorded.",
};
const errors: Record<string, string> = {
  access_denied: "Your current assignment does not permit that asset action.",
  conflict: "The asset changed first. Reload its current version before trying again.",
  duplicate: "That serial or marking is already registered for the item.",
  invalid_input: "Review the asset state, selected record, evidence, and audit reason.",
  not_found: "The selected asset, location, party, reservation, or order line is unavailable.",
  save_failed: "The asset command was rejected; no partial custody history was accepted.",
};

export function AssetNotice({ error, notice }: { error?: string; notice?: string }) {
  const errorMessage = error ? errors[error] : undefined;
  const noticeMessage = notice ? notices[notice] : undefined;
  if (!errorMessage && !noticeMessage) return null;
  return <div className={`staff-flash ${errorMessage ? "staff-flash-error" : ""}`} role={errorMessage ? "alert" : "status"}>{errorMessage ?? noticeMessage}</div>;
}
