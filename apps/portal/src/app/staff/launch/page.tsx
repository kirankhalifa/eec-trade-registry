import Link from "next/link";

import { UiIcon, type IconName } from "@/components/ui-icon";

const actions: Array<{
  description: string;
  href: string;
  icon: IconName;
  label: string;
}> = [
  { href: "/staff/orders/new", icon: "clipboard", label: "Create an order", description: "Business or individual intake with a price and quota preview." },
  { href: "/staff/applications", icon: "license", label: "Review applications", description: "Approve or deny new licenses and renewals." },
  { href: "/staff/consignments/finance", icon: "coins", label: "Settle consignments", description: "Set commission terms, freeze settlements, and record payment." },
  { href: "/staff/assets/fulfillment", icon: "key", label: "Hand over a unique asset", description: "Complete an active unique reservation and custody transfer." },
  { href: "/staff/pricing", icon: "coins", label: "Publish a price rule", description: "Choose the binding level, target, schedule, and effective dates." },
  { href: "/staff/documents/new", icon: "document", label: "Generate a document", description: "Create an official PDF snapshot from an authoritative record." },
];

export default function LaunchPage() {
  return (
    <main className="staff-main">
      <header className="staff-page-header">
        <div>
          <p className="eyebrow">Quick actions</p>
          <h1>What do you need to do?</h1>
          <p>Each action opens its own short, guided workspace. Records and references never need to be copied between desks.</p>
        </div>
      </header>
      <section className="action-launcher-grid" aria-label="Available quick actions">
        {actions.map((action) => (
          <Link href={action.href} key={action.href}>
            <span><UiIcon name={action.icon} size={22} /></span>
            <div><h2>{action.label}</h2><p>{action.description}</p></div>
            <UiIcon name="arrow" size={18} />
          </Link>
        ))}
      </section>
    </main>
  );
}
