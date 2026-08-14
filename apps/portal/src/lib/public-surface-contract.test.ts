import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), "utf8");
}

describe("public rendering contracts", () => {
  it("ships a useful catalogue h1 in the server-rendered route source", () => {
    const catalogue = source("../app/page.tsx");
    expect(catalogue).toContain("<h1>Published trade catalogue</h1>");
    expect(catalogue).not.toContain("Retrieving current catalogue records");
  });

  it("ships the authoritative item name and description metadata on detail pages", () => {
    const detail = source("../app/catalogue/[slug]/page.tsx");
    expect(detail).toContain("<h1>{item.display_name}</h1>");
    expect(detail).toContain("description: result.data.description");
  });

  it("keeps fixture instructions off public verification and application routes", () => {
    const routes = [
      source("../app/verify/page.tsx"),
      source("../app/verify/dealer/page.tsx"),
      source("../app/verify/license/page.tsx"),
      source("../app/apply/application-forms.tsx"),
    ].join("\n");
    expect(routes).not.toMatch(/fictional development fixture|local database is seeded/i);
  });
});
