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
 * @returns a positive whole number, or null when the field says nothing.
 */
export function normalizeQuantityRule(value: unknown): number | null {
  const trimmed = String(value ?? '').trim()
  if (trimmed === '') return null

  const parsed = Number(trimmed)
  if (!Number.isFinite(parsed) || parsed < 1) return null

  return Math.trunc(parsed)
}
