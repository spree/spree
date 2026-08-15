// Customs field normalization, shared by the variant edit sheet and the bulk
// variants editor so both commit the same value for the same keystrokes.
//
// These mirror `Spree::Variant`'s `normalizes` declarations. Doing it in the
// browser too means a merchant pasting a dotted tariff code from a customs
// broker's spreadsheet sees it accepted, rather than bouncing off the
// server's 6–13 digit format validation.

/**
 * Strips everything but digits from a Harmonized System code, so `6404.11`
 * and `6404 11` both become `640411`.
 *
 * @returns the digits, or null when nothing is left (the field is optional).
 */
export function normalizeHsCode(value: unknown): string | null {
  const digits = String(value ?? '').replace(/[^0-9]/g, '')
  return digits === '' ? null : digits
}

/**
 * Trims a customs description, collapsing a blank field to null so clearing
 * it actually clears it rather than storing an empty string.
 */
export function normalizeCustomsDescription(value: unknown): string | null {
  const trimmed = String(value ?? '').trim()
  return trimmed === '' ? null : trimmed
}
