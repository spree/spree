import { type BulkPriceRow, BulkPriceTable } from '@spree/dashboard-ui'
import { useCallback, useMemo } from 'react'
import { type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { ProductFormValues, VariantPriceFormValues } from '@/schemas/product'
import { currencyParts } from './currency-parts'

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  /** ISO currency code (e.g. "USD", "EUR"). */
  currency: string
  /** Display label for the product, used as the table's section header. */
  productName: string
}

/**
 * Form-backed prices spreadsheet for ONE product's variants in ONE currency.
 * Reads from and writes to the parent product form's `variants[].prices`
 * array — works equally for persisted and unsaved variants, since both live
 * in form state the same way. No server fetch, no edit-tracking map: the
 * parent form's `isDirty` is the single source of truth for save gating.
 *
 * Amounts are STRINGS, not numbers. The merchant's raw input flows straight
 * through to the API; the backend's `Spree::LocalizedNumber.parse` handles
 * locale-aware parsing (comma decimals, grouped digits, etc.) so the
 * frontend doesn't have to reimplement it. Frontend coercion via `Number()`
 * would silently mangle inputs like `"1.234,56"` into `NaN` and drop the
 * price entirely.
 */
export function ProductBulkPriceEditor({ form, currency, productName }: Props) {
  const { t, i18n } = useTranslation()
  const variants = useWatch({ control: form.control, name: 'variants' }) ?? []

  const { symbol, decimal } = useMemo(
    () => currencyParts(currency, i18n.language || 'en'),
    [currency, i18n.language],
  )

  // Project the form's variants into BulkPriceRow[] for the picked currency.
  // One header row per product (always this product), then one row per variant.
  // Row id is the variant's array index so onChange can write back unambiguously,
  // even for variants without a persisted id.
  const rows = useMemo<BulkPriceRow[]>(() => {
    if (variants.length === 0) return []
    const out: BulkPriceRow[] = [{ id: `header:product`, kind: 'header', groupLabel: productName }]
    variants.forEach((v, idx) => {
      const price = (v.prices ?? []).find((p) => p.currency === currency)
      const label = v.options.length > 0 ? v.options.map((o) => o.value).join(' / ') : null
      out.push({
        id: `variant:${idx}`,
        kind: 'item',
        variantLabel: label,
        sku: v.sku ?? null,
        // Display the canonical-decimal string swapped into the user's
        // locale separator. The merchant's raw input is stored as-is in
        // form state — this swap is presentation-only.
        amount: price?.amount ? price.amount.replace('.', decimal) : null,
        compareAt: price?.compare_at_amount ? price.compare_at_amount.replace('.', decimal) : null,
      })
    })
    return out
  }, [variants, currency, productName, decimal])

  const handleChange = useCallback(
    (rowId: string, field: 'amount' | 'compareAt', next: string | null) => {
      if (!rowId.startsWith('variant:')) return
      const idx = Number.parseInt(rowId.slice('variant:'.length), 10)
      if (Number.isNaN(idx)) return

      const current = form.getValues(`variants.${idx}.prices`) ?? []
      const existingIdx = current.findIndex((p) => p.currency === currency)
      // Treat empty/whitespace string as "no value"; everything else is
      // shipped verbatim to the backend's locale-aware parser.
      const raw = next == null || next.trim() === '' ? null : next.trim()

      const nextPrices: VariantPriceFormValues[] = [...current]

      if (existingIdx === -1) {
        // No price entry in this currency yet. Only create one when the user
        // sets the AMOUNT — a compare-at-only edit without a base amount is
        // meaningless (and would otherwise persist a real $0 price). Defer
        // compare-at until amount exists.
        if (raw == null) return
        if (field !== 'amount') return
        nextPrices.push({
          currency,
          amount: raw,
          compare_at_amount: null,
        })
      } else {
        const existing = nextPrices[existingIdx]
        if (field === 'amount') {
          // Clearing the amount removes the price entry for this currency.
          // Coercing to "0" would persist a real $0 price and never allow
          // the merchant to drop a currency from a variant.
          if (raw == null) {
            nextPrices.splice(existingIdx, 1)
          } else {
            nextPrices[existingIdx] = { ...existing, amount: raw }
          }
        } else {
          nextPrices[existingIdx] = { ...existing, compare_at_amount: raw }
        }
      }

      form.setValue(`variants.${idx}.prices`, nextPrices, {
        shouldDirty: true,
      })
    },
    [form, currency],
  )

  return (
    <BulkPriceTable
      rows={rows}
      symbol={symbol}
      decimal={decimal}
      onChange={handleChange}
      labels={{
        variant: t('admin.pages.products.price_lists.edit_prices.columns.variant'),
        sku: t('admin.pages.products.price_lists.edit_prices.columns.sku'),
        price: t('admin.pages.products.price_lists.edit_prices.columns.price'),
        compareAt: t('admin.pages.products.price_lists.edit_prices.columns.compare_at_price'),
        variantDefault: t('admin.pages.products.price_lists.edit_prices.variant_default'),
        loading: t('admin.common.loading'),
        pageOf: t('admin.common.page_of', { page: '{page}', total: '{total}' }),
        prev: t('admin.common.prev'),
        next: t('admin.common.next'),
        emptyMessage: t('admin.pages.products.edit.bulk_prices.no_variants'),
        gridAriaLabel: t('admin.pages.products.price_lists.edit_prices.grid_aria'),
        priceAriaTemplate: t('admin.pages.products.price_lists.edit_prices.price_aria', {
          label: '{label}',
        }),
        compareAtAriaTemplate: t('admin.pages.products.price_lists.edit_prices.compare_at_aria', {
          label: '{label}',
        }),
      }}
    />
  )
}
