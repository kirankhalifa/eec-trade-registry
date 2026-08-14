import Link from "next/link";

import { ReferenceBlock } from "@/components/reference-block";

import type {
  DealerVerification,
  LicenseVerification,
  VerificationResultCode,
} from "@/lib/verification";

const resultLabels: Record<VerificationResultCode, string> = {
  valid: "Valid",
  provisional: "Provisional",
  suspended: "Suspended",
  revoked: "Revoked",
  expired: "Expired",
  not_verifiable: "Not verifiable",
};

interface ResultHeaderProps {
  code: VerificationResultCode;
  reference: string | null;
  verifiedAt: string;
  locale: string;
}

function formatDate(value: string, locale: string, includeTime = false): string {
  return new Intl.DateTimeFormat(locale, {
    dateStyle: "medium",
    ...(includeTime ? { timeStyle: "short" as const } : {}),
  }).format(new Date(value));
}

function ResultHeader({ code, reference, verifiedAt, locale }: ResultHeaderProps) {
  return (
    <header className="verification-result-header">
      <div>
        <p className="eyebrow">Verification result</p>
        <h2>{resultLabels[code]}</h2>
        {reference && (
          <ReferenceBlock
            label="Public reference"
            reference={reference}
            status={resultLabels[code]}
          />
        )}
      </div>
      <span className={`verification-badge verification-badge-${code}`}>
        {resultLabels[code]}
      </span>
      <p className="verification-timestamp">
        Queried {formatDate(verifiedAt, locale, true)}
      </p>
    </header>
  );
}

export function UnsupportedVerificationReference({
  reference,
}: {
  reference: string;
}) {
  return (
    <section className="verification-result" aria-live="polite">
      <div className="verification-generic-miss">
        <p className="eyebrow">Reference not recognized</p>
        <h2>Use a dealer or license reference.</h2>
        <p>
          Current dealer references begin with EEC-DLR- and license references
          begin with EEC-LIC-. Earlier DLR- and LIC- records remain valid. Order, fulfillment, and private application references
          are not public verification records.
        </p>
        <ReferenceBlock label="Entered reference" reference={reference} />
      </div>
    </section>
  );
}

export function VerificationRateLimited() {
  return (
    <section className="notice-panel" role="status">
      <p className="eyebrow">Lookup limit reached</p>
      <h2>Wait a few minutes, then try again.</h2>
      <p>
        Public verification is intentionally rate limited to protect the
        registry from automated reference guessing.
      </p>
    </section>
  );
}

function NotVerifiableResult({
  verifiedAt,
  locale,
}: Pick<ResultHeaderProps, "verifiedAt" | "locale">) {
  return (
    <section className="verification-result" aria-live="polite">
      <ResultHeader
        code="not_verifiable"
        reference={null}
        verifiedAt={verifiedAt}
        locale={locale}
      />
      <div className="verification-generic-miss">
        <h3>No public record can be verified for that reference.</h3>
        <p>
          This result is also used for malformed, private, unpublished, and
          unknown records. It does not confirm whether a private record exists.
        </p>
      </div>
    </section>
  );
}

interface DealerVerificationResultProps {
  result: DealerVerification;
  locale: string;
}

export function DealerVerificationResult({
  result,
  locale,
}: DealerVerificationResultProps) {
  if (result.result_code === "not_verifiable") {
    return <NotVerifiableResult verifiedAt={result.verified_at} locale={locale} />;
  }

  return (
    <section className="verification-result" aria-live="polite">
      <ResultHeader
        code={result.result_code}
        reference={result.public_reference}
        verifiedAt={result.verified_at}
        locale={locale}
      />
      <div className="verification-record-heading">
        <p className="eyebrow">Public dealer record</p>
        <h3>{result.public_name ?? "Public name unavailable"}</h3>
        {result.public_notice && <p>{result.public_notice}</p>}
      </div>
      <dl className="verification-facts">
        <div>
          <dt>Dealer type</dt>
          <dd>{result.dealer_type_label ?? "Not published"}</dd>
        </div>
        <div>
          <dt>Jurisdiction</dt>
          <dd>{result.jurisdiction_label ?? "Not published"}</dd>
        </div>
        <div>
          <dt>Public premises</dt>
          <dd>{result.premises_label ?? "Not published"}</dd>
        </div>
        <div>
          <dt>Status</dt>
          <dd>{result.status_label ?? resultLabels[result.result_code]}</dd>
        </div>
        <div>
          <dt>Effective from</dt>
          <dd>
            {result.effective_from
              ? formatDate(result.effective_from, locale)
              : "Not published"}
          </dd>
        </div>
        <div>
          <dt>Effective until</dt>
          <dd>
            {result.effective_until
              ? formatDate(result.effective_until, locale)
              : "No published end date"}
          </dd>
        </div>
      </dl>
      <div className="verification-authority-note">
        <strong>
          {result.is_currently_authorized
            ? "This dealer authorization is currently in force."
            : "This dealer authorization does not currently confer authority."}
        </strong>
        <p>
          Item eligibility, licensing, stock, pricing, and transaction approval
          are evaluated separately.
        </p>
      </div>
      {result.license_summaries.length > 0 && (
        <div className="verification-related">
          <h3>Published related licenses</h3>
          <ul>
            {result.license_summaries.map((license) => (
              <li key={license.public_reference}>
                <Link
                  href={{
                    pathname: "/verify",
                    query: { reference: license.public_reference },
                  }}
                >
                  <strong>{license.license_class_label}</strong>
                  <span>{license.public_reference}</span>
                  <span>{resultLabels[license.result_code]}</span>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}

interface LicenseVerificationResultProps {
  result: LicenseVerification;
  locale: string;
}

export function LicenseVerificationResult({
  result,
  locale,
}: LicenseVerificationResultProps) {
  if (result.result_code === "not_verifiable") {
    return <NotVerifiableResult verifiedAt={result.verified_at} locale={locale} />;
  }

  return (
    <section className="verification-result" aria-live="polite">
      <ResultHeader
        code={result.result_code}
        reference={result.public_reference}
        verifiedAt={result.verified_at}
        locale={locale}
      />
      <div className="verification-record-heading">
        <p className="eyebrow">Public license record</p>
        <h3>{result.holder_name ?? "Public holder name unavailable"}</h3>
        {result.public_notice && <p>{result.public_notice}</p>}
      </div>
      <dl className="verification-facts">
        <div>
          <dt>License class</dt>
          <dd>{result.license_class_label ?? "Not published"}</dd>
        </div>
        <div>
          <dt>Jurisdiction</dt>
          <dd>{result.jurisdiction_label ?? "Not published"}</dd>
        </div>
        <div>
          <dt>Status</dt>
          <dd>{result.status_label ?? resultLabels[result.result_code]}</dd>
        </div>
        <div>
          <dt>Effective from</dt>
          <dd>
            {result.effective_from
              ? formatDate(result.effective_from, locale)
              : "Not published"}
          </dd>
        </div>
        <div>
          <dt>Expires</dt>
          <dd>
            {result.expires_at
              ? formatDate(result.expires_at, locale)
              : "No published expiration"}
          </dd>
        </div>
      </dl>
      <div className="verification-authority-note">
        <strong>
          {result.is_currently_authorized
            ? "This license is currently in force."
            : "This license does not currently confer authority."}
        </strong>
        <p>
          Dealer status, item eligibility, allocation, stock, and transaction
          approval are evaluated separately.
        </p>
      </div>
      {result.endorsements.length > 0 && (
        <div className="verification-list">
          <h3>Published endorsements</h3>
          <ul>
            {result.endorsements.map((endorsement) => (
              <li key={endorsement}>{endorsement}</li>
            ))}
          </ul>
        </div>
      )}
      {result.public_conditions.length > 0 && (
        <div className="verification-list">
          <h3>Public conditions</h3>
          <ul>
            {result.public_conditions.map((condition) => (
              <li key={condition}>{condition}</li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}

interface VerificationUnavailableProps {
  notConfigured: boolean;
}

export function VerificationUnavailable({
  notConfigured,
}: VerificationUnavailableProps) {
  return (
    <section className="notice-panel" role="status">
      <p className="eyebrow">Registry notice</p>
      <h2>Public verification is temporarily unavailable.</h2>
      <p>
        The authoritative registry could not be reached. No cached document,
        message, or spreadsheet has been substituted.
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
