/**
 * How one unit of an order reads wherever it is listed.
 *
 * A variant carries a SKU and its option values but never a name — the name
 * lives on the product — so the label is built from the line's own name with
 * the options after it, falling back to the SKU and then the raw id.
 *
 * One helper because the same unit appears on the parcel, the fulfil form,
 * the split dialog and all three post-sale cards: built separately they drift,
 * and the same goods were reading as "Shirt — Blue" in one card and
 * "Shirt · Blue" in the next.
 */
export function lineLabel(
  name: string | null | undefined,
  variant: { sku?: string | null; options_text?: string | null } | null | undefined,
  fallback: string | null | undefined,
): string {
  return [name, variant?.options_text].filter(Boolean).join(' · ') || variant?.sku || fallback || ''
}

/** The same label for a row that carries its own name and options directly. */
export function unitLabel(item: {
  name?: string | null
  options_text?: string | null
  id: string
}): string {
  return lineLabel(item.name, { options_text: item.options_text }, item.id)
}
