"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { UiIcon } from "@/components/ui-icon";

const links = [
  ["/", "Catalogue"],
  ["/verify", "Verify"],
  ["/apply", "Apply or renew"],
] as const;

export function PublicHeader({ institutionName }: { institutionName: string }) {
  const pathname = usePathname();
  if (pathname.startsWith("/staff") || pathname.startsWith("/dealer")) return null;
  return <header className="site-header"><div className="site-header-inner">
    <Link className="brand" href="/" aria-label={`${institutionName} home`}><span className="brand-mark" aria-hidden="true">EEC</span><span><strong>{institutionName}</strong><small>Trade registry</small></span></Link>
    <nav className="public-desktop-nav" aria-label="Primary navigation">{links.map(([href,label])=><Link className={pathname === href || (href !== "/" && pathname.startsWith(href)) ? "is-active" : ""} href={href} key={href}>{label}</Link>)}<Link className="public-login-link" href="/dealer/login">Dealer portal</Link><Link className="button button-primary button-compact" href="/staff/login">Staff sign in</Link></nav>
    <details className="public-mobile-nav"><summary aria-label="Open navigation"><UiIcon name="menu"/><span>Menu</span></summary><nav aria-label="Mobile navigation">{links.map(([href,label])=><Link href={href} key={href}>{label}</Link>)}<Link href="/dealer/login">Dealer portal</Link><Link href="/staff/login">Staff sign in</Link></nav></details>
  </div></header>;
}

export function PublicFooter({ institutionName }: { institutionName: string }) {
  const pathname = usePathname();
  if (pathname.startsWith("/staff") || pathname.startsWith("/dealer")) return null;
  return <footer className="site-footer"><div><strong>{institutionName}</strong><p>Official catalogue, licensing, and dealer verification.</p></div><p>Public information is projected from the authoritative trade registry. Availability does not guarantee purchase eligibility.</p></footer>;
}
