/** Strip phone numbers, emails, and address-like strings before Anthropic. */

const EMAIL_RE = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;

// Ethiopian mobiles (+2517/9… or 07/09…) and generic long digit runs.
const PHONE_RE =
  /\b(?:\+?251[\s.-]?)?(?:0)?[79](?:[\s.-]?\d){8}\b|\b\+?\d[\d\s().-]{7,}\d\b/g;

// Exact-looking street / house lines (Latin or Ethiopic digits).
const ADDRESS_RE =
  /\b(?:house\s*(?:no\.?|number|#)?\s*\d+|kebele\s*\d+|wereda\s*\d+|woreda\s*\d+|apartment\s*\d+|apt\.?\s*\d+|room\s*\d+|\d{1,5}\s+[A-Za-z][A-Za-z\s]{2,40}\s(?:st|street|rd|road|ave|avenue|blvd|lane|ln|way|close|plaza)\b)/gi;

export function redactSurvivorText(raw: string, maxChars = 2000): string {
  return raw
    .replace(EMAIL_RE, "[redacted-email]")
    .replace(PHONE_RE, "[redacted-phone]")
    .replace(ADDRESS_RE, "[redacted-address]")
    .replace(/\s{2,}/g, " ")
    .trim()
    .slice(0, maxChars);
}

export function looksAmharic(text: string): boolean {
  return /[\u1200-\u137F]/.test(text);
}
