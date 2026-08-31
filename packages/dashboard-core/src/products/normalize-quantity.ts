// Purchasing-rule normalization for the variant editors, mirroring
// `Spree::Variant`'s own validations so a merchant hears about a bad value
// while typing rather than on save.

/** What a buyer is quoted in. Stored quantities stay units at every level. */
export const PURCHASE_UNITS = ['unit', 'carton'] as const

export type PurchaseUnit = (typeof PURCHASE_UNITS)[number]

/**
 * Reads a quantity rule from a number input. Blank means the rule is unset,
 * which is not the same as zero: an empty minimum lets a buyer take one, a
 * minimum of zero is meaningless and the server refuses it.
 *
 * A fraction is refused rather than truncated. These rules are whole units,
 * and this feature exists because silently adjusting a wholesale quantity is
 * a five-figure surprise — a rule of 2.5 saved as 2 is the same mistake one
 * level up.
 *
 * @returns a positive whole number, or null when the field says nothing or
 *   cannot be one.
 */
export function normalizeQuantityRule(value: unknown): number | null {
  const trimmed = String(value ?? '').trim()
  if (trimmed === '') return null

  const parsed = Number(trimmed)
  if (!Number.isInteger(parsed) || parsed < 1) return null

  return parsed
}
