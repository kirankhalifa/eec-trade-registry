import { ImageResponse } from "next/og";

import { getPublicCatalogueItem } from "@/lib/catalogue";

export const alt = "East Empire Company catalogue entry";
export const size = { height: 630, width: 1200 };
export const contentType = "image/png";
export const revalidate = 60;

export default async function CatalogueOpenGraphImage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const result = await getPublicCatalogueItem(slug);
  const item = result.ok ? result.data : null;

  return new ImageResponse(
    <div
      style={{
        background: "#EAE6DC",
        color: "#1C1B18",
        display: "flex",
        flexDirection: "column",
        height: "100%",
        justifyContent: "space-between",
        padding: "64px 74px",
        width: "100%",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <div style={{ color: "#33414A", display: "flex", fontSize: 25, letterSpacing: 5 }}>
          EEC · PUBLIC CATALOGUE
        </div>
        <div style={{ border: "3px solid #8A6E3C", display: "flex", fontSize: 24, padding: "13px 18px" }}>
          CURRENT ENTRY
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column" }}>
        <div style={{ color: "#33414A", display: "flex", fontFamily: "monospace", fontSize: 26 }}>
          {item?.item_code ?? slug.toUpperCase()}
        </div>
        <div style={{ display: "flex", fontFamily: "sans-serif", fontSize: 82, fontWeight: 800, marginTop: 22 }}>
          {item?.display_name ?? "Catalogue entry"}
        </div>
        <div style={{ color: "#33414A", display: "flex", fontSize: 28, marginTop: 24 }}>
          {item ? `${item.control_label} · ${item.availability_label}` : "East Empire Company trade registry"}
        </div>
      </div>
      <div style={{ background: "#C6BFB0", display: "flex", height: 3, width: "100%" }} />
    </div>,
    size,
  );
}
