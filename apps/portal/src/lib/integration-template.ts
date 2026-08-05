const placeholderPattern = /\{\{([a-z][a-z0-9_]*)\}\}/g;

function safeValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (["string", "number", "boolean"].includes(typeof value)) {
    return String(value);
  }
  return "";
}

export function escapeDiscordMentions(value: string): string {
  return value.replaceAll("@", "@\u200b");
}

export function renderNotificationTemplate(
  template: string,
  payload: Record<string, unknown>,
): string {
  const rendered = template.replace(
    placeholderPattern,
    (_match, key: string) => safeValue(payload[key]),
  );
  return escapeDiscordMentions(rendered).slice(0, 1900);
}
