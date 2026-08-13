import type { ReactNode } from "react";

export type IconName =
  | "archive"
  | "arrow"
  | "box"
  | "briefcase"
  | "building"
  | "catalogue"
  | "check"
  | "clipboard"
  | "coins"
  | "dashboard"
  | "document"
  | "external"
  | "gear"
  | "heart"
  | "key"
  | "license"
  | "logout"
  | "menu"
  | "package"
  | "people"
  | "search"
  | "shield"
  | "spark"
  | "transfer"
  | "truck";

const drawings: Record<IconName, ReactNode> = {
  archive: <><path d="M4 7.5h16v12H4z"/><path d="M3 4.5h18v3H3zM9 11h6"/></>,
  arrow: <><path d="M5 12h14M14 7l5 5-5 5"/></>,
  box: <><path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="m4 7 8 4 8-4v10l-8 4-8-4V7Zm8 4v10"/></>,
  briefcase: <><path d="M4 7h16v12H4zM9 7V4h6v3"/><path d="M4 12h16M10 12v2h4v-2"/></>,
  building: <><path d="M5 21V7l7-4 7 4v14M3 21h18"/><path d="M9 9h1m4 0h1m-6 4h1m4 0h1m-6 4h6"/></>,
  catalogue: <><path d="M5 4h14v16H5zM9 4v16"/><path d="M12 8h4m-4 4h4m-4 4h3"/></>,
  check: <path d="m5 12 4 4L19 6"/>,
  clipboard: <><path d="M7 5h10v16H5V7h2"/><path d="M9 3h6v4H9zM9 12h6m-6 4h6"/></>,
  coins: <><ellipse cx="9" cy="7" rx="5" ry="3"/><path d="M4 7v4c0 1.7 2.2 3 5 3s5-1.3 5-3V7"/><path d="M10 17c.9.6 2.2 1 3.7 1 2.9 0 5.3-1.3 5.3-3v-4c0-1.4-1.6-2.5-3.8-2.9"/></>,
  dashboard: <><rect x="4" y="4" width="6" height="7"/><rect x="14" y="4" width="6" height="4"/><rect x="4" y="15" width="6" height="5"/><rect x="14" y="12" width="6" height="8"/></>,
  document: <><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h4M9 12h6m-6 4h6"/></>,
  external: <><path d="M14 5h5v5M19 5l-8 8"/><path d="M17 13v6H5V7h6"/></>,
  gear: <><circle cx="12" cy="12" r="3"/><path d="M19 13.5v-3l-2-.7-.7-1.7.9-1.9-2.1-2.1-1.9.9-1.7-.7-.7-2h-3l-.7 2-1.7.7-1.9-.9-2.1 2.1.9 1.9-.7 1.7-2 .7v3l2 .7.7 1.7-.9 1.9 2.1 2.1 1.9-.9 1.7.7.7 2h3l.7-2 1.7-.7 1.9.9 2.1-2.1-.9-1.9.7-1.7 2-.7Z"/></>,
  heart: <path d="M20 8.5c0 5-8 10-8 10s-8-5-8-10a4.5 4.5 0 0 1 8-2.8 4.5 4.5 0 0 1 8 2.8Z"/>,
  key: <><circle cx="8" cy="12" r="4"/><path d="M12 12h9m-3 0v3m-3-3v2"/></>,
  license: <><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8" cy="11" r="2"/><path d="M5.5 16c.8-1.4 4.2-1.4 5 0M13 9h5m-5 4h5"/></>,
  logout: <><path d="M10 5H5v14h5M13 8l4 4-4 4m4-4H9"/></>,
  menu: <path d="M4 7h16M4 12h16M4 17h16"/>,
  package: <><path d="M5 8h14v12H5zM8 4h8l3 4H5l3-4Z"/><path d="M9 12h6"/></>,
  people: <><circle cx="9" cy="8" r="3"/><path d="M3.5 19c.5-4 2.3-6 5.5-6s5 2 5.5 6"/><path d="M15 6.5a3 3 0 0 1 0 5.5m1 1c2.7.4 4.2 2.4 4.5 5"/></>,
  search: <><circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 5 5"/></>,
  shield: <><path d="M12 3 5 6v5c0 4.8 2.8 8.2 7 10 4.2-1.8 7-5.2 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-5"/></>,
  spark: <><path d="m12 3 1.5 5.5L19 10l-5.5 1.5L12 17l-1.5-5.5L5 10l5.5-1.5L12 3Z"/><path d="m19 16 .6 2.4L22 19l-2.4.6L19 22l-.6-2.4L16 19l2.4-.6L19 16Z"/></>,
  transfer: <><path d="M5 8h13M15 5l3 3-3 3M19 16H6m3 3-3-3 3-3"/></>,
  truck: <><path d="M3 6h11v11H3zM14 10h4l3 3v4h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/></>,
};

export function UiIcon({ name, size = 18 }: { name: IconName; size?: number }) {
  return <svg aria-hidden="true" className="ui-icon" fill="none" height={size} viewBox="0 0 24 24" width={size} stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.7">{drawings[name]}</svg>;
}
