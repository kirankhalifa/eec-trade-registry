import { createHash, createSign } from "node:crypto";

import type { GoogleServiceEnvironment } from "@/lib/integration-env";

export type SheetCell = string | number | boolean | null;

export interface SheetColumn {
  key: string;
  label: string;
}

interface GoogleTokenResponse {
  access_token?: string;
}

function base64Url(value: string): string {
  return Buffer.from(value, "utf8").toString("base64url");
}

function createServiceAccountAssertion(
  environment: GoogleServiceEnvironment,
  nowSeconds = Math.floor(Date.now() / 1000),
): string {
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(
    JSON.stringify({
      aud: "https://oauth2.googleapis.com/token",
      exp: nowSeconds + 3600,
      iat: nowSeconds,
      iss: environment.GOOGLE_SERVICE_ACCOUNT_EMAIL,
      scope: "https://www.googleapis.com/auth/spreadsheets",
    }),
  );
  const unsigned = `${header}.${claims}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsigned);
  signer.end();
  const privateKey = environment.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY.replaceAll(
    "\\n",
    "\n",
  );
  return `${unsigned}.${signer.sign(privateKey).toString("base64url")}`;
}

async function requestAccessToken(
  environment: GoogleServiceEnvironment,
): Promise<string> {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      assertion: createServiceAccountAssertion(environment),
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`google_token_${response.status}`);
  const data = (await response.json()) as GoogleTokenResponse;
  if (!data.access_token) throw new Error("google_token_invalid_response");
  return data.access_token;
}

function sheetRange(tabName: string, range: string): string {
  return `'${tabName.replaceAll("'", "''")}'!${range}`;
}

function columnName(index: number): string {
  let value = index + 1;
  let result = "";
  while (value > 0) {
    value -= 1;
    result = String.fromCharCode(65 + (value % 26)) + result;
    value = Math.floor(value / 26);
  }
  return result;
}

async function googleRequest(
  url: string,
  accessToken: string,
  init?: RequestInit,
): Promise<Response> {
  const response = await fetch(url, {
    ...init,
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
      ...init?.headers,
    },
    signal: init?.signal ?? AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`google_sheets_${response.status}`);
  return response;
}

async function ensureSheetTab(
  spreadsheetId: string,
  tabName: string,
  accessToken: string,
): Promise<void> {
  const metadataResponse = await googleRequest(
    `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(spreadsheetId)}?fields=sheets.properties.title`,
    accessToken,
  );
  const metadata = (await metadataResponse.json()) as {
    sheets?: Array<{ properties?: { title?: string } }>;
  };
  const exists = metadata.sheets?.some(
    (sheet) => sheet.properties?.title === tabName,
  );
  if (exists) return;
  await googleRequest(
    `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(spreadsheetId)}:batchUpdate`,
    accessToken,
    {
      method: "POST",
      body: JSON.stringify({ requests: [{ addSheet: { properties: { title: tabName } } }] }),
    },
  );
}

function normalizeCell(value: unknown, siteOrigin: string, key: string): SheetCell {
  if (value === null || value === undefined) return null;
  if (key === "source_url" && typeof value === "string" && value.startsWith("/")) {
    return `${siteOrigin}${value}`;
  }
  if (typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return String(value);
}

export function buildSheetMatrix(
  projectionCode: string,
  columns: SheetColumn[],
  rows: Array<Record<string, unknown>>,
  generatedAt: string,
  siteOrigin: string,
): SheetCell[][] {
  if (columns.length < 1 || columns.length > 50) {
    throw new Error("sheet_column_contract_invalid");
  }
  if (rows.length > 20_000) throw new Error("sheet_row_limit_exceeded");
  return [
    ["Source", `${siteOrigin}/`],
    ["Projection", projectionCode],
    ["Generated at", generatedAt],
    [],
    columns.map((column) => column.label),
    ...rows.map((row) =>
      columns.map((column) => normalizeCell(row[column.key], siteOrigin, column.key)),
    ),
  ];
}

export function checksumSheetMatrix(matrix: SheetCell[][]): string {
  return createHash("sha256").update(JSON.stringify(matrix)).digest("hex");
}

export async function writeGoogleSheetSnapshot(input: {
  columns: SheetColumn[];
  environment: GoogleServiceEnvironment;
  generatedAt: string;
  projectionCode: string;
  rows: Array<Record<string, unknown>>;
  siteOrigin: string;
  spreadsheetId: string;
  tabName: string;
}): Promise<{ checksum: string; destinationVersion: string; rowCount: number }> {
  const matrix = buildSheetMatrix(
    input.projectionCode,
    input.columns,
    input.rows,
    input.generatedAt,
    input.siteOrigin,
  );
  const accessToken = await requestAccessToken(input.environment);
  await ensureSheetTab(input.spreadsheetId, input.tabName, accessToken);
  const clearRange = sheetRange(input.tabName, "A:ZZZ");
  await googleRequest(
    `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(input.spreadsheetId)}/values/${encodeURIComponent(clearRange)}:clear`,
    accessToken,
    { method: "POST", body: "{}" },
  );
  const updateRange = sheetRange(input.tabName, "A1");
  await googleRequest(
    `https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(input.spreadsheetId)}/values/${encodeURIComponent(updateRange)}?valueInputOption=RAW`,
    accessToken,
    { method: "PUT", body: JSON.stringify({ majorDimension: "ROWS", values: matrix }) },
  );
  const finalRange = `${input.tabName}!A1:${columnName(input.columns.length - 1)}${matrix.length}`;
  return {
    checksum: checksumSheetMatrix(matrix),
    destinationVersion: finalRange,
    rowCount: input.rows.length,
  };
}
