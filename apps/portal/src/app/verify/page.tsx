import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Public verification",
  description:
    "Verify published dealer authorizations and licenses by exact public reference.",
};

export default function VerificationLandingPage() {
  return (
    <main>
      <section className="verification-hero">
        <p className="eyebrow">Official public registry</p>
        <h1>Verify a published record.</h1>
        <p>
          Use the exact public reference printed on an authorization or license.
          The registry returns a privacy-safe result directly from the
          authoritative database.
        </p>
      </section>
      <section className="verification-choices" aria-labelledby="choose-record">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Reference lookup</p>
            <h2 id="choose-record">Choose a record type</h2>
          </div>
        </div>
        <div className="verification-choice-grid">
          <Link className="verification-choice" href="/verify/dealer">
            <span>01</span>
            <div>
              <h3>Dealer authorization</h3>
              <p>
                Confirm the published identity, type, region, term, and related
                public license summaries for an authorized counterparty.
              </p>
            </div>
            <strong>Verify dealer →</strong>
          </Link>
          <Link className="verification-choice" href="/verify/license">
            <span>02</span>
            <div>
              <h3>License</h3>
              <p>
                Confirm the published holder, class, jurisdiction, term,
                endorsements, and public conditions for an issued license.
              </p>
            </div>
            <strong>Verify license →</strong>
          </Link>
        </div>
        <aside className="verification-privacy-note">
          <strong>Privacy by design</strong>
          <p>
            Unknown, malformed, private, and unpublished references share the
            same “not verifiable” response. Holder-name search is disabled.
          </p>
        </aside>
      </section>
    </main>
  );
}
