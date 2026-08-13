"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { signOutAction } from "@/app/staff/actions";
import { CommandPaletteButton, StaffCommandPalette } from "@/components/staff-command-palette";
import { type IconName, UiIcon } from "@/components/ui-icon";

type NavigationItem = { href: string; icon: IconName; label: string; exact?: boolean; ownerOnly?: boolean };
const groups: Array<{ label: string; items: NavigationItem[] }> = [
  { label: "Overview", items: [
    { href: "/staff/dashboard", icon: "dashboard", label: "Dashboard", exact: true },
  ] },
  { label: "Trade", items: [
    { href: "/staff/orders", icon: "clipboard", label: "Orders" },
    { href: "/staff/fulfillment", icon: "package", label: "Fulfillment" },
    { href: "/staff/inventory", icon: "box", label: "Inventory" },
    { href: "/staff/economy", icon: "coins", label: "Economy" },
  ] },
  { label: "Registry", items: [
    { href: "/staff", icon: "catalogue", label: "Catalogue", exact: true },
    { href: "/staff/applications", icon: "clipboard", label: "Applications" },
    { href: "/staff/licensing", icon: "license", label: "Licenses" },
    { href: "/staff/dealers", icon: "building", label: "Businesses" },
  ] },
  { label: "Operations", items: [
    { href: "/staff/transfers", icon: "transfer", label: "Transfers" },
    { href: "/staff/consignments", icon: "truck", label: "Consignments" },
    { href: "/staff/assets", icon: "key", label: "Unique assets" },
    { href: "/staff/compliance", icon: "shield", label: "Compliance" },
  ] },
  { label: "Administration", items: [
    { href: "/staff/configuration", icon: "gear", label: "Configuration" },
    { href: "/staff/documents", icon: "document", label: "Documents" },
    { href: "/staff/integrations", icon: "external", label: "Integrations" },
    { href: "/staff/access", icon: "people", label: "Staff access", ownerOnly: true },
    { href: "/staff/operations", icon: "heart", label: "System health", ownerOnly: true },
  ] },
];

function isCurrent(pathname: string, item: NavigationItem) {
  if (item.href === "/staff" && pathname.startsWith("/staff/items")) return true;
  return item.exact ? pathname === item.href : pathname === item.href || pathname.startsWith(`${item.href}/`);
}

function Navigation({ isOwner, pathname, mobile = false }: { isOwner: boolean; pathname: string; mobile?: boolean }) {
  return <nav className={mobile ? "app-mobile-navigation" : "app-navigation"} aria-label="Staff navigation">{groups.map((group)=>{
    const items = group.items.filter((item) => !item.ownerOnly || isOwner);
    if (!items.length) return null;
    return <section className="app-nav-group" key={group.label}><p>{group.label}</p>{items.map((item)=><Link aria-current={isCurrent(pathname,item) ? "page" : undefined} className={isCurrent(pathname,item) ? "app-nav-link is-active" : "app-nav-link"} href={item.href} key={item.href}><UiIcon name={item.icon}/><span>{item.label}</span></Link>)}</section>;
  })}</nav>;
}

export function StaffShell({ accessClass, children, displayName, institutionName }: { accessClass: "owner" | "agent" | null; children: React.ReactNode; displayName: string | null; institutionName: string }) {
  const pathname = usePathname();
  if (pathname === "/staff/login" || pathname === "/staff/access/pending") return <>{children}</>;
  const isOwner = accessClass === "owner";
  return <div className="app-shell">
    <aside className="app-sidebar"><Link className="app-brand" href="/staff/dashboard"><span className="app-brand-mark">EEC</span><span><strong>{institutionName}</strong><small>Operations console</small></span></Link><div className="app-sidebar-main"><CommandPaletteButton/><Navigation isOwner={isOwner} pathname={pathname}/></div><div className="app-sidebar-footer">{displayName&&<div className="app-user"><span>{displayName.slice(0,1).toUpperCase()}</span><div><strong>{displayName}</strong><small>{isOwner ? "Owner" : "Agent"}</small></div></div>}<Link href="/" target="_blank"><UiIcon name="external"/>Public site</Link><form action={signOutAction}><button type="submit"><UiIcon name="logout"/>Sign out</button></form></div></aside>
    <div className="app-workspace"><header className="app-mobile-bar"><Link className="app-brand" href="/staff/dashboard"><span className="app-brand-mark">EEC</span><span><strong>Staff console</strong><small>{displayName ?? institutionName}</small></span></Link><CommandPaletteButton compact/><details><summary><UiIcon name="menu"/><span>Menu</span></summary><div className="app-mobile-menu"><Navigation isOwner={isOwner} mobile pathname={pathname}/><form action={signOutAction}><button className="button button-secondary" type="submit"><UiIcon name="logout"/>Sign out</button></form></div></details></header>{children}</div>
    <StaffCommandPalette isOwner={isOwner}/>
  </div>;
}
