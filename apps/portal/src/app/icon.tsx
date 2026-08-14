import { ImageResponse } from "next/og";

export const size = { height: 64, width: 64 };
export const contentType = "image/png";

export default function Icon() {
  return new ImageResponse(
    <div style={{ alignItems: "center", background: "#33414A", color: "#EAE6DC", display: "flex", fontFamily: "sans-serif", fontSize: 23, fontWeight: 800, height: "100%", justifyContent: "center", letterSpacing: -1, width: "100%" }}>EEC</div>,
    size,
  );
}
