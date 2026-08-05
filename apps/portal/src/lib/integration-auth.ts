import { timingSafeEqual } from "node:crypto";

export function hasValidBearerSecret(
  authorizationHeader: string | null,
  expectedSecret: string,
): boolean {
  if (!authorizationHeader?.startsWith("Bearer ")) return false;
  const suppliedSecret = authorizationHeader.slice("Bearer ".length);
  const supplied = Buffer.from(suppliedSecret, "utf8");
  const expected = Buffer.from(expectedSecret, "utf8");
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}
