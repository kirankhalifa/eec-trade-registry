import { readFile, writeFile } from "node:fs/promises";

const manifestPath = new URL("../apps/portal/src/lib/feature-status.json", import.meta.url);
const handbookPath = new URL("../docs/PLAYER_ADMIN_HANDBOOK.md", import.meta.url);
const start = "<!-- FEATURE_STATUS:START -->";
const end = "<!-- FEATURE_STATUS:END -->";

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const statusLabel = {
  live: "Live",
  external_setup: "Built; external setup required",
  gated: "Policy-gated",
};
const rows = Object.values(manifest).map((feature) =>
  `| ${feature.label} | ${statusLabel[feature.status]} | ${feature.route ? `\`${feature.route}\`` : "—"} |`,
);
const generated = `${start}\n## Current feature status\n\nThis table is generated from the same manifest used by the application. Do not edit it by hand.\n\n| Capability | Status | Portal route |\n| --- | --- | --- |\n${rows.join("\n")}\n${end}`;

const handbook = await readFile(handbookPath, "utf8");
const pattern = new RegExp(`${start}[\\s\\S]*?${end}`);
const next = pattern.test(handbook)
  ? handbook.replace(pattern, generated)
  : `${handbook.trimEnd()}\n\n${generated}\n`;

if (process.argv.includes("--check")) {
  if (next !== handbook) {
    console.error("Feature status documentation is stale. Run npm run docs:generate.");
    process.exit(1);
  }
} else {
  await writeFile(handbookPath, next, "utf8");
}
