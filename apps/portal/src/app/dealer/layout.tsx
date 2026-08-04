import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Dealer portal",
  robots: { index: false, follow: false },
};

export default function DealerLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
