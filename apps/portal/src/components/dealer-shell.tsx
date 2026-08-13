"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { signOutDealerAction } from "@/app/dealer/actions";
import { UiIcon } from "@/components/ui-icon";

const items = [
  ["/dealer", "Overview", "dashboard"],
  ["/dealer/orders", "Orders", "clipboard"],
  ["/dealer/consignments", "Consigned stock", "box"],
] as const;

export function DealerShell({ children, institutionName }: { children: React.ReactNode; institutionName: string }) {
  const pathname = usePathname();
  if (pathname === "/dealer/login") return <>{children}</>;
  return <div className="dealer-app-shell"><header className="dealer-app-header"><Link className="app-brand" href="/dealer"><span className="app-brand-mark">EEC</span><span><strong>{institutionName}</strong><small>Business portal</small></span></Link><nav aria-label="Business portal navigation">{items.map(([href,label,icon])=><Link className={pathname === href || (href !== "/dealer" && pathname.startsWith(`${href}/`)) ? "is-active" : ""} href={href} key={href}><UiIcon name={icon}/>{label}</Link>)}</nav><div className="dealer-account-actions"><Link href="/" target="_blank"><UiIcon name="external"/>Public site</Link><form action={signOutDealerAction}><button type="submit"><UiIcon name="logout"/>Sign out</button></form></div></header>{children}</div>;
}
