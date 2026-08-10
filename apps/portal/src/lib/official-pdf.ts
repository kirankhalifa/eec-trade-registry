import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFPage } from "pdf-lib";

export interface OfficialDocumentSnapshot {
  checksum_sha256: string;
  document_type: string;
  generated_at: string;
  public_reference: string;
  snapshot_payload: Record<string, unknown>;
  source_record_type: string;
  source_version: number;
}

const PAGE = { width: 612, height: 792, margin: 54 };

function label(value: string) {
  return value.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function stringify(value: unknown): string {
  if (value === null || value === undefined || value === "") return "Not specified";
  if (Array.isArray(value)) return value.map(stringify).join(", ");
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

function wrap(text: string, font: PDFFont, size: number, width: number): string[] {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (font.widthOfTextAtSize(candidate, size) <= width) line = candidate;
    else {
      if (line) lines.push(line);
      line = word;
    }
  }
  if (line) lines.push(line);
  return lines.length ? lines : [""];
}

export async function buildOfficialPdf(snapshot: OfficialDocumentSnapshot): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  const regular = await pdf.embedFont(StandardFonts.TimesRoman);
  const bold = await pdf.embedFont(StandardFonts.TimesRomanBold);
  const navy = rgb(0.08, 0.15, 0.23);
  const gold = rgb(0.62, 0.43, 0.13);
  let page: PDFPage;
  let y = 0;

  const startPage = () => {
    page = pdf.addPage([PAGE.width, PAGE.height]);
    page.drawRectangle({ x: 36, y: 36, width: 540, height: 720, borderColor: gold, borderWidth: 1.5 });
    page.drawText("EAST EMPIRE COMPANY", { x: PAGE.margin, y: 724, font: bold, size: 16, color: navy });
    page.drawText("OFFICIAL TRADE REGISTRY", { x: PAGE.margin, y: 707, font: regular, size: 9, color: gold });
    page.drawLine({ start: { x: PAGE.margin, y: 695 }, end: { x: 558, y: 695 }, thickness: 1, color: gold });
    y = 674;
  };
  startPage();

  const title = stringify(snapshot.snapshot_payload.document_title ?? label(snapshot.document_type));
  page!.drawText(title, { x: PAGE.margin, y, font: bold, size: 20, color: navy });
  y -= 34;

  for (const [key, value] of Object.entries(snapshot.snapshot_payload)) {
    if (key === "document_title") continue;
    const lines = wrap(stringify(value), regular, 10.5, 500);
    const needed = 22 + lines.length * 14;
    if (y - needed < 72) startPage();
    page!.drawText(label(key), { x: PAGE.margin, y, font: bold, size: 9, color: gold });
    y -= 15;
    for (const line of lines) {
      page!.drawText(line, { x: PAGE.margin, y, font: regular, size: 10.5, color: navy });
      y -= 14;
    }
    y -= 9;
  }

  for (const currentPage of pdf.getPages()) {
    currentPage.drawLine({ start: { x: PAGE.margin, y: 62 }, end: { x: 558, y: 62 }, thickness: 0.6, color: gold });
    currentPage.drawText(`${snapshot.public_reference}  |  Source ${snapshot.source_record_type} v${snapshot.source_version}`, {
      x: PAGE.margin, y: 48, font: regular, size: 7.5, color: navy,
    });
    currentPage.drawText(`SHA-256 ${snapshot.checksum_sha256}`, { x: PAGE.margin, y: 39, font: regular, size: 6.5, color: navy });
  }
  pdf.setTitle(title);
  pdf.setAuthor("East Empire Company");
  pdf.setSubject(`${snapshot.document_type} generated ${snapshot.generated_at}`);
  return pdf.save();
}
