"use client";

import { useState } from "react";

interface ReferenceBlockProps {
  label: string;
  reference: string;
  status?: string;
}

export function ReferenceBlock({
  label,
  reference,
  status,
}: ReferenceBlockProps) {
  const [copied, setCopied] = useState(false);
  const prefixParts = reference.split("-");
  const prefixLength = prefixParts[0] === "EEC" && prefixParts.length > 2 ? 2 : 1;
  const prefix = prefixParts.slice(0, prefixLength).join("-");
  const remainder = prefixParts.slice(prefixLength).join("-");

  async function copyReference() {
    await navigator.clipboard.writeText(reference);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  }

  return (
    <div className="reference-block">
      <div>
        <span>{label}</span>
        <code><span className="reference-prefix">{prefix}</span>{remainder ? `-${remainder}` : ""}</code>
      </div>
      {status && <strong>{status}</strong>}
      <button className="button button-secondary button-compact" onClick={copyReference} type="button">
        {copied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}
