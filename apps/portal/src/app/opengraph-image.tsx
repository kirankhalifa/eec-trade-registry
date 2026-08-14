import { ImageResponse } from "next/og";

export const alt = "East Empire Company public trade registry";
export const size = { height: 630, width: 1200 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    <div
      style={{
        alignItems: "stretch",
        background: "#EAE6DC",
        color: "#1C1B18",
        display: "flex",
        flexDirection: "column",
        height: "100%",
        justifyContent: "space-between",
        padding: "68px 78px",
        width: "100%",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <div style={{ color: "#33414A", display: "flex", fontSize: 26, letterSpacing: 6 }}>
          PUBLIC TRADE REGISTRY
        </div>
        <div style={{ border: "3px solid #8A6E3C", display: "flex", fontSize: 28, padding: "16px 20px" }}>
          EEC
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column" }}>
        <div style={{ display: "flex", fontFamily: "sans-serif", fontSize: 78, fontWeight: 800 }}>
          East Empire Company
        </div>
        <div style={{ color: "#33414A", display: "flex", fontSize: 32, marginTop: 22 }}>
          Catalogue · dealer verification · licensing
        </div>
      </div>
      <div style={{ background: "#C6BFB0", display: "flex", height: 3, width: "100%" }} />
    </div>,
    size,
  );
}
