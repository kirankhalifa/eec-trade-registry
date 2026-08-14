import type { Metadata } from "next";

import { PublicFooter, PublicHeader } from "@/components/public-chrome";
import { getInstitutionName, getSiteOrigin } from "@/lib/env";

import "./globals.css";
import "./interface.css";

const institutionName = getInstitutionName();
const metadataOrigin = process.env.NEXT_PUBLIC_SITE_URL
  ? getSiteOrigin()
  : "https://eec-trade-registry-portal.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(metadataOrigin),
  title: {
    default: institutionName,
    template: `%s | ${institutionName}`,
  },
  description:
    "Public trade catalogue and verification registry for authorized goods and counterparties.",
  openGraph: {
    description:
      "Official catalogue, dealer authorizations, and license verification for East Empire Company trade.",
    siteName: institutionName,
    title: institutionName,
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    description:
      "Official catalogue, dealer authorizations, and license verification for East Empire Company trade.",
    title: institutionName,
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <PublicHeader institutionName={institutionName} />
        {children}
        <PublicFooter institutionName={institutionName} />
      </body>
    </html>
  );
}
