import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    background_color: "#EAE6DC",
    description: "Public catalogue and operating registry for East Empire Company trade.",
    display: "standalone",
    name: "East Empire Company Trade Registry",
    short_name: "EEC Registry",
    start_url: "/",
    theme_color: "#33414A",
  };
}
