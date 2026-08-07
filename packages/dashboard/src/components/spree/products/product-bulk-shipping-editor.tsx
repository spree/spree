import {
  type BulkShippingField,
  type BulkShippingRow,
  BulkShippingTable,
} from '@spree/dashboard-ui'
import { useCallback, useMemo } from 'react'
import { type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOptionTypes } from '../../../hooks/use-option-types'
import type { ProductFormValues } from '../../../schemas/product'
import { composeOptionsText } from './variants-matrix'

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
}

/**
 * Form-backed shipping spreadsheet for ONE product's variants: weight,
 * height, width, depth. Reads from and writes to the parent product form's
 * `variants[]` array — works equally for persisted and unsaved variants —
 * so edits ride the product form's Save like the prices grid. Units are
 * deliberately not columns here: they rarely vary per variant and stay
 * editable in the variant edit sheet.
 */
export function ProductBulkShippingEditor({ form }: Props) {
  const { t } = useTranslation()
  const variants = useWatch({ control: form.control, name: 'variants' }) ?? []
  const { data: optionTypesData } = useOptionTypes({ limit: 100 })
  const optionTypes = useMemo(() => optionTypesData?.data ?? [], [optionTypesData])

  // Row id is the variant's array index so onChange can write back
  // unambiguously, even for variants without a persisted id.
  const rows = useMemo<BulkShippingRow[]>(
    () =>
      variants.map((v, idx) => ({
        id: `variant:${idx}`,
        variantLabel: v.options.length > 0 ? composeOptionsText(v.options, optionTypes) : null,
        sku: v.sku ?? null,
        weight: v.weight != null ? String(v.weight) : null,
        height: v.height != null ? String(v.height) : null,
        width: v.width != null ? String(v.width) : null,
        depth: v.depth != null ? String(v.depth) : null,
      })),
    [variants, optionTypes],
  )

  const handleChange = useCallback(
    (rowId: string, field: BulkShippingField, next: string | null) => {
      if (!rowId.startsWith('variant:')) return
      const idx = Number.parseInt(rowId.slice('variant:'.length), 10)
      if (Number.isNaN(idx)) return

      const path = `variants.${idx}.${field}` as const
      if (next == null || next.trim() === '') {
        form.setValue(path, null, { shouldDirty: true })
        return
      }
      // Accept a comma decimal (the cell ships raw input); ignore anything
      // that doesn't parse to a non-negative number rather than mangling it.
      const parsed = Number(next.trim().replace(',', '.'))
      if (!Number.isFinite(parsed) || parsed < 0) return
      form.setValue(path, parsed, { shouldDirty: true })
    },
    [form],
  )

  return (
    <BulkShippingTable
      rows={rows}
      onChange={handleChange}
      labels={{
        variant: t('admin.pages.products.price_lists.edit_prices.columns.variant'),
        sku: t('admin.fields.variant.sku.label'),
        weight: t('admin.fields.variant.weight.label'),
        height: t('admin.fields.variant.height.label'),
        width: t('admin.fields.variant.width.label'),
        depth: t('admin.fields.variant.depth.label'),
        variantDefault: t('admin.pages.products.price_lists.edit_prices.variant_default'),
        emptyMessage: t('admin.pages.products.edit.bulk_shipping.no_variants'),
        gridAriaLabel: t('admin.pages.products.edit.bulk_shipping.grid_aria'),
      }}
    />
  )
}
