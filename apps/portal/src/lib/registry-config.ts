export const REGISTRY_CONFIG = {
  currency: {
    code: "SEP",
    label: "Septims",
  },
  jurisdiction: {
    code: "harbor-district",
    mode: "fixed",
  },
  orderChannels: ["business", "direct"] as const,
  pricing: {
    directMultiplier: 3,
    exposeTiePriority: false,
  },
  warehouse: {
    mode: "single",
  },
} as const;
export type RegistryOrderChannel =
  (typeof REGISTRY_CONFIG.orderChannels)[number];

export function isConfiguredOrderChannel(
  value: string,
): value is RegistryOrderChannel {
  return REGISTRY_CONFIG.orderChannels.some((channel) => channel === value);
}
