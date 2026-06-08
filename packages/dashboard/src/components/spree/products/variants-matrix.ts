// Pure helpers for the variants matrix on the product page.
//
// The matrix lets a merchant pick option types + values and writes the
// resulting cartesian product as RHF form state. These helpers stay pure
// (no React, no SDK) so they can evolve independently of the UI shell.

import type { VariantFormValues } from '@/schemas/product'

export interface SelectedOptionValue {
  name: string
  label?: string
}

export interface SelectedOptionType {
  // OptionType prefixed_id — only used for picker UX (re-selecting the row).
  id: string
  // Canonical option name (e.g. "size"). What the API matches on.
  name: string
  // Display label for the option type (e.g. "Size").
  label: string
  position: number
  // Ordered list of selected option values for this type.
  values: SelectedOptionValue[]
}

export interface VariantCombination {
  options: { name: string; value: string }[]
}

export function cartesianProduct<T>(arrays: T[][]): T[][] {
  return arrays.reduce<T[][]>(
    (acc, arr) => acc.flatMap((combo) => arr.map((v) => [...combo, v])),
    [[]],
  )
}

// Build the cartesian product of selected option values, preserving the
// option-type order (matters for the label "Red / Small" vs "Small / Red"
// and for stable row identity across re-renders).
export function generateVariantCombinations(selected: SelectedOptionType[]): VariantCombination[] {
  const ordered = [...selected]
    .sort((a, b) => a.position - b.position)
    .filter((ot) => ot.values.length > 0)
  if (ordered.length === 0) return []

  const valueMatrix = ordered.map((ot) => ot.values.map((v) => v.name))
  return cartesianProduct(valueMatrix).map((combo) => ({
    options: combo.map((value, idx) => ({ name: ordered[idx].name, value })),
  }))
}

// Stable key for an options set, used to match existing variants against
// newly-generated combinations. Sorted by name so order of insertion can't
// affect equality.
export function optionsKey(options: { name: string; value: string }[]): string {
  return [...options]
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((o) => `${o.name}=${o.value}`)
    .join('|')
}

export interface ReconcileResult {
  // Carries persisted id/sku/prices/stock_items forward for matched combos,
  // and stamps new entries with defaults. Position is the array index.
  next: VariantFormValues[]
  // Options-keys of variants that no longer match any generated combination
  // AND carry merchant data (typed SKU, prices, stock, weight, etc.). Drives
  // the amber "N variants no longer match…" banner so the merchant can
  // choose "Keep all" (leave them, ride the next save) or "Remove all"
  // (drop them from form state). We use options-keys instead of ids so
  // unsaved orphans — typed values on a single-option row that gets
  // overshadowed by adding a second option type — show up in the banner
  // too. Previously these were silently appended to form state.
  orphanedKeys: string[]
}

// Match generated combinations against existing variants by options-set
// equality. The reconcile is non-destructive: persisted variants that no
// longer match any combination are KEPT in `next` (appended after the
// matched/new rows) and surfaced via `orphanedIds`. The UI uses that list
// to show a confirm-before-drop banner; "Keep all" dismisses the banner
// without changing the array, "Remove" filters them out.
//
// Blank variants ship with empty `prices` + `stock_items`. The inventory
// grid renders editable rows for every (variant × location) and creates
// entries on first edit; the pricing editor does the same per currency.
// No pre-seeding here means the payload stays clean — only locations the
// merchant actually touched land in the PATCH.
export function reconcileVariants(
  existing: VariantFormValues[],
  combinations: VariantCombination[],
): ReconcileResult {
  const existingByKey = new Map<string, VariantFormValues>()
  existing.forEach((v) => {
    existingByKey.set(optionsKey(v.options), v)
  })

  const matchedKeys = new Set<string>()
  const next: VariantFormValues[] = combinations.map((combo, index) => {
    const key = optionsKey(combo.options)
    const match = existingByKey.get(key)
    if (match) {
      matchedKeys.add(key)
      return { ...match, options: combo.options, position: index }
    }
    return blankVariant(combo.options, index)
  })

  // Carry unmatched variants forward when the row has merchant data.
  //
  // Persisted rows (have an `id`) always carry forward — if dropped, the
  // next product save would delete them server-side, blowing away SKUs,
  // pricing, and inventory even when the merchant chose "Keep all".
  //
  // Unsaved rows (no `id`) carry forward only when they hold merchant data
  // (SKU, barcode, price, stock count, positive shipping field). Without
  // this, building variants from one option type then adding a second
  // option type would leave every transient first-pass row hanging around
  // in form state even though the matrix already replaced them with the
  // 3×3 (or whatever) Cartesian product.
  //
  // Both persisted and unsaved carry-forwards seed the orphan banner so
  // the merchant gets a chance to drop them. Banner identity is the
  // options-key (uniquely identifies an orphan within the form state) —
  // ids alone would miss the unsaved case.
  const orphanedKeys: string[] = []
  existing.forEach((v) => {
    const key = optionsKey(v.options)
    if (matchedKeys.has(key)) return
    if (!variantHasMerchantData(v) && (v.options.length === 0 || !v.id)) return
    next.push({ ...v, position: next.length })
    orphanedKeys.push(key)
  })

  return { next, orphanedKeys }
}

// Does this variant carry merchant data we'd lose if dropped?
//
// Server-propagated default variants come back with `weight: 0` (NOT NULL
// column with default) and zero-count stock_items for every active location.
// Treat those zero/default sentinels as "no data" — only truthy fields
// count the row as carrying intent. Without this, every saved
// single-variant product would be treated as an orphan on upgrade and the
// natural simple→multi-variant flow surfaces a confusing banner.
//
// Shipping fields (weight, dimensions) count when *positive* — `weight: 0`
// is the server's NOT NULL default and the initial form snapshot also
// writes `weight: 0`, so treating it as data would re-trigger the
// false-positive banner for every untouched product. A positive value
// means the merchant typed something (likely via the VariantEditSheet
// shipping section).
function variantHasMerchantData(v: VariantFormValues): boolean {
  return (
    !!v.sku ||
    !!v.barcode ||
    (v.prices?.length ?? 0) > 0 ||
    (v.stock_items?.some((s) => (s.count_on_hand ?? 0) > 0) ?? false) ||
    (v.weight ?? 0) > 0 ||
    (v.height ?? 0) > 0 ||
    (v.width ?? 0) > 0 ||
    (v.depth ?? 0) > 0
  )
}

export function blankVariant(
  options: { name: string; value: string }[],
  position: number,
): VariantFormValues {
  return {
    sku: null,
    barcode: null,
    position,
    options,
    weight: null,
    height: null,
    width: null,
    depth: null,
    weight_unit: null,
    dimensions_unit: null,
    track_inventory: true,
    tax_category_id: null,
    prices: [],
    stock_items: [],
  }
}

export interface OptionTypeForLabel {
  name: string
  label: string
  position?: number
  option_values?: { name: string; label: string }[]
}

// Mirrors backend `Spree::Variant#options_text`: "Color: Silver, Size: XS" or
// "Color: Silver, Size: XS, and Material: Steel". Sorts by option-type position
// (backend `option_values.sort_by(&:option_type.position)`) and joins with the
// same `to_sentence(words_connector: ', ', two_words_connector: ', ')` rules —
// `, ` between items and `, and ` before the last when there are 3+. Falls back
// to slugs when a label isn't in the registry (e.g. a value the merchant just
// created in this session) and to input order for types not in the registry.
export function composeOptionsText(
  options: { name: string; value: string }[],
  optionTypes: OptionTypeForLabel[],
): string {
  const parts = options
    .map((o, idx) => {
      const ot = optionTypes.find((x) => x.name === o.name)
      const typeLabel = ot?.label ?? o.name
      const valueLabel = ot?.option_values?.find((v) => v.name === o.value)?.label ?? o.value
      // Stable position: registry value when present, otherwise the input index
      // pushed above any registry value so unknown types trail in input order.
      const position = ot?.position ?? Number.MAX_SAFE_INTEGER - options.length + idx
      return { text: `${typeLabel}: ${valueLabel}`, position, idx }
    })
    .sort((a, b) => a.position - b.position || a.idx - b.idx)
    .map((p) => p.text)

  if (parts.length < 3) return parts.join(', ')
  return `${parts.slice(0, -1).join(', ')}, and ${parts[parts.length - 1]}`
}

export function variantDisplayLabel(
  variant: Pick<VariantFormValues, 'options' | 'sku'>,
  fallback: string,
  optionTypes: OptionTypeForLabel[],
): string {
  if (variant.options.length > 0) {
    return composeOptionsText(variant.options, optionTypes)
  }
  if (variant.sku) return variant.sku
  return fallback
}
