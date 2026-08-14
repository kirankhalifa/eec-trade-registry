import { ImageResponse } from "next/og";

export const alt = "Verify an East Empire Company dealer or license";
export const size = { height: 630, width: 1200 };
export const contentType = "image/png";

export default function VerificationOpenGraphImage() {
  return new ImageResponse(
    <div
      style={{
        background: "#EAE6DC",
        color: "#1C1B18",
        display: "flex",
        flexDirection: "column",
        height: "100%",
        justifyContent: "space-between",
        padding: "66px 76px",
        width: "100%",
      }}
    >
      <div style={{ color: "#33414A", display: "flex", fontSize: 25, letterSpacing: 5 }}>
        OFFICIAL PUBLIC VERIFICATION
      </div>
      <div style={{ display: "flex", flexDirection: "column" }}>
        <div style={{ display: "flex", fontFamily: "sans-serif", fontSize: 78, fontWeight: 800 }}>
          Verify a dealer or license
        </div>
        <div style={{ color: "#33414A", display: "flex", fontFamily: "monospace", fontSize: 34, marginTop: 30 }}>
          EEC-DLR-… / EEC-LIC-…
        </div>
      </div>
      <div style={{ alignItems: "center", display: "flex", justifyContent: "space-between" }}>
        <div style={{ background: "#C6BFB0", display: "flex", height: 3, width: "78%" }} />
        <div style={{ border: "3px solid #9B2118", color: "#9B2118", display: "flex", fontSize: 22, padding: "12px 16px", transform: "rotate(-3deg)" }}>
          QUERY LIVE
        </div>
      </div>
    </div>,
    size,
  );
}
