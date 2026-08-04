interface CatalogueUnavailableProps {
  notConfigured?: boolean;
}

export function CatalogueUnavailable({
  notConfigured = false,
}: CatalogueUnavailableProps) {
  return (
    <section className="notice-panel" role="status">
      <p className="eyebrow">Registry notice</p>
      <h2>The public catalogue is temporarily unavailable.</h2>
      <p>
        The authoritative registry could not be reached. No spreadsheet or
        cached copy has been substituted.
      </p>
      {notConfigured && process.env.NODE_ENV === "development" && (
        <p className="development-note">
          Development setup: configure the public Supabase URL and anon key in
          your local environment.
        </p>
      )}
    </section>
  );
}
