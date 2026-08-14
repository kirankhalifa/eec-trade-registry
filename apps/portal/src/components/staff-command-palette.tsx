"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { type IconName, UiIcon } from "@/components/ui-icon";

type Command = {
  description: string;
  href: string;
  icon: IconName;
  keywords: string;
  label: string;
  ownerOnly?: boolean;
};

const commands: Command[] = [
  { href: "/staff/orders/new", icon: "spark", label: "Create an order", description: "Enter a business or direct customer request", keywords: "new submit requisition customer" },
  { href: "/staff/orders", icon: "clipboard", label: "Find an order", description: "Review demand and continue fulfillment", keywords: "approve reserve fulfill handoff" },
  { href: "/staff/configuration#quick-add-item", icon: "box", label: "Add a catalogue item", description: "Create and publish a new good", keywords: "new product material catalogue" },
  { href: "/staff/inventory", icon: "package", label: "Receive or inspect stock", description: "Post receipts and see physical balances", keywords: "inventory warehouse quantity" },
  { href: "/staff/economy", icon: "coins", label: "Receive a supplier delivery", description: "Buy player-sourced reserve materials", keywords: "procurement floor bulk ore leather" },
  { href: "/staff/pricing", icon: "coins", label: "Publish a price rule", description: "Bind a schedule to a business, class, region, or channel", keywords: "dealer pricing wholesale" },
  { href: "/staff/consignments", icon: "truck", label: "Open consignments", description: "Manage custody, reports, commission, and settlement", keywords: "consignment finance commission" },
  { href: "/staff/assets", icon: "key", label: "Open unique assets", description: "Manage serialized goods and ready handoffs", keywords: "unique custody reservation" },
  { href: "/staff/documents", icon: "document", label: "Open documents", description: "Generate or download official PDF snapshots", keywords: "certificate receipt pdf" },
  { href: "/staff/applications", icon: "document", label: "Review applications", description: "Approve or deny license intake", keywords: "pending renew application" },
  { href: "/staff/licensing/new", icon: "license", label: "Issue a license", description: "Create configured trade authority", keywords: "permit endorsement" },
  { href: "/staff/dealers/new", icon: "building", label: "Add a business", description: "Register an authorized dealer", keywords: "dealer organization shop" },
  { href: "/staff/access", icon: "people", label: "Approve staff access", description: "Review a Discord identity", keywords: "agent permissions role", ownerOnly: true },
  { href: "/staff/operations", icon: "heart", label: "Check system health", description: "Inspect authoritative services and workers", keywords: "status cron export", ownerOnly: true },
];

export function CommandPaletteButton({ compact = false }: { compact?: boolean }) {
  return (
    <button
      className={compact ? "command-palette-trigger is-compact" : "command-palette-trigger"}
      onClick={() => window.dispatchEvent(new Event("eec:open-command-palette"))}
      type="button"
    >
      <UiIcon name="search" size={16} />
      <span>Find or do anything</span>
      <kbd>⌘ K</kbd>
    </button>
  );
}

export function StaffCommandPalette({ isOwner }: { isOwner: boolean }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const available = useMemo(() => commands.filter((command) => !command.ownerOnly || isOwner), [isOwner]);
  const results = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return available;
    return available.filter((command) => `${command.label} ${command.description} ${command.keywords}`.toLowerCase().includes(term));
  }, [available, query]);

  useEffect(() => {
    function openPalette() { setQuery(""); setOpen(true); }
    function keyboard(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpen((current) => {
          if (!current) setQuery("");
          return !current;
        });
      }
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("eec:open-command-palette", openPalette);
    window.addEventListener("keydown", keyboard);
    return () => {
      window.removeEventListener("eec:open-command-palette", openPalette);
      window.removeEventListener("keydown", keyboard);
    };
  }, []);

  useEffect(() => {
    if (!open) return;
    const timer = window.setTimeout(() => inputRef.current?.focus(), 0);
    return () => window.clearTimeout(timer);
  }, [open]);

  if (!open) return null;
  return (
    <div className="command-palette-backdrop" onMouseDown={() => setOpen(false)}>
      <section aria-label="Find or do anything" aria-modal="true" className="command-palette" onMouseDown={(event) => event.stopPropagation()} role="dialog">
        <label className="command-palette-search">
          <UiIcon name="search" size={20} />
          <span className="sr-only">Search actions</span>
          <input onChange={(event) => setQuery(event.target.value)} placeholder="What do you need to do?" ref={inputRef} value={query} />
          <kbd>Esc</kbd>
        </label>
        <p className="command-palette-hint">Actions and places</p>
        <div className="command-palette-results">
          {results.map((command) => (
            <Link href={command.href} key={command.href} onClick={() => setOpen(false)}>
              <span><UiIcon name={command.icon} size={18} /></span>
              <span><strong>{command.label}</strong><small>{command.description}</small></span>
              <UiIcon name="arrow" size={15} />
            </Link>
          ))}
          {!results.length && <p className="command-palette-empty">No match. Try “order”, “stock”, “license”, or “business”.</p>}
        </div>
      </section>
    </div>
  );
}
