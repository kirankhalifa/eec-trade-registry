import type { Metadata } from "next";

import { PublicFooter, PublicHeader } from "@/components/public-chrome";
import { getInstitutionName } from "@/lib/env";

import "./globals.css";
import "./interface.css";

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
        <PublicHeader institutionName={institutionName} />
        {children}
        <PublicFooter institutionName={institutionName} />
      </body>
    </html>
  );
}
