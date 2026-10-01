/** "Product — Small / Blue", falling back to the SKU or the raw id. */
export function variantLabel(
  variant:
    | { product_name?: string | null; options_text?: string | null; sku?: string | null }
    | null
    | undefined,
  variantId: string | null | undefined,
): string {
  if (!variant) return variantId ?? ''

  const parts = [variant.product_name, variant.options_text].filter(Boolean)
  return parts.length > 0 ? parts.join(' — ') : (variant.sku ?? variantId ?? '')
}
