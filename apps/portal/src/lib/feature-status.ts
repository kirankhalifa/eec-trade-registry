import manifest from "./feature-status.json";

export type FeatureStatus = "live" | "external_setup" | "gated";

export interface FeatureDefinition {
  label: string;
  route: string | null;
  status: FeatureStatus;
}

export const FEATURES = manifest as Record<string, FeatureDefinition>;
