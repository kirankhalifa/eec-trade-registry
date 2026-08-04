import type { Metadata } from "next";
import Link from "next/link";

import { getInstitutionName } from "@/lib/env";

import "./globals.css";

const institutionName = getInstitutionName();

export const metadata: Metadata = {
  title: {
    default: institutionName,
    template: `%s | ${institutionName}`,
  },
  description:
    "Public trade catalogue and verification registry for authorized goods and counterparties.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <header className="site-header">
          <Link className="brand" href="/" aria-label={`${institutionName} home`}>
            <span className="brand-mark" aria-hidden="true">
              EEC
            </span>
            <span>
              <strong>{institutionName}</strong>
              <small>Public trade catalogue</small>
            </span>
          </Link>
          <nav aria-label="Primary navigation">
            <Link href="/">Catalogue</Link>
            <span aria-disabled="true">Verification coming later</span>
            <Link href="/staff/login">Staff access</Link>
          </nav>
        </header>
        {children}
        <footer className="site-footer">
          <p>{institutionName}</p>
          <p>
            Public information is projected from the authoritative trade
            registry. Availability does not guarantee purchase eligibility.
          </p>
        </footer>
      </body>
    </html>
  );
}
