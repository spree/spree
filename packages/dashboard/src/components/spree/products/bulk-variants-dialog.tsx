import { useCountries, useCountryDisplayName } from '@spree/dashboard-core'
import {
  type BulkVariantsChange,
  type BulkVariantsRow,
  BulkVariantsTable,
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@spree/dashboard-ui'
import { useCallback, useEffect, useMemo, useRef } from 'react'
import { type UseFormReturn, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOptionTypes } from '../../../hooks/use-option-types'
import { useTaxCategories } from '../../../hooks/use-tax-categories'
import type { ProductFormValues, VariantFormValues } from '../../../schemas/product'
import { normalizeCustomsDescription, normalizeHsCode } from './normalize-customs'
import { composeOptionsText } from './variants-matrix'

const WEIGHT_UNITS = ['g', 'kg', 'lb', 'oz'] as const
const DIMENSION_UNITS = ['mm', 'cm', 'in'] as const

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  open: boolean
  onOpenChange: (open: boolean) => void
}

/**
 * Full-page bulk variant editor: a spreadsheet of every per-variant field
 * from the variant edit sheet (SKU, barcode, shipping measurements + units,
 * availability, tax category) across all of a product's variants at once.
 * Selection, copy/paste, and drag-fill come from the shared DataGrid.
 *
 * Form-backed like the edit sheet: cells read from and write to the parent
 * product form's `variants[]`, so Done keeps the edits in form state (the
 * product Save button commits them) and Cancel restores the snapshot taken
 * when the dialog opened. Closing via Esc/overlay/X cancels, mirroring the
 * sheet.
 */
export function BulkVariantsDialog({ form, open, onOpenChange }: Props) {
  const { t } = useTranslation()
  const variants = useWatch({ control: form.control, name: 'variants' }) ?? []
  const { data: optionTypesData } = useOptionTypes({ limit: 100 })
  const optionTypes = useMemo(() => optionTypesData?.data ?? [], [optionTypesData])
  const { data: taxCategoriesResponse } = useTaxCategories()
  const taxCategories = taxCategoriesResponse?.data ?? []
  const { countries } = useCountries()
  const countryName = useCountryDisplayName()

  // ISO codes as values — customs data must survive the countries table, and
  // a country record id would not.
  const countryOptions = useMemo(
    () =>
      countries.map((country) => ({
        value: country.iso,
        label: countryName({ iso: country.iso, iso3: country.iso3, name: country.name }),
      })),
    [countries, countryName],
  )

  // Snapshot the variants when the dialog opens so Cancel can restore them.
  // Deep-clone — `form.getValues` returns references into RHF's internal
  // state, and cell edits mutate them in place (same trap the edit sheet
  // documents).
  const snapshotRef = useRef<VariantFormValues[] | null>(null)
  useEffect(() => {
    if (!open) return
    snapshotRef.current = structuredClone(form.getValues('variants') ?? []) as VariantFormValues[]
  }, [open, form])

  const handleCancel = useCallback(() => {
    const snapshot = snapshotRef.current
    if (snapshot) {
      // Restore element-by-element via resetField so each variant's dirty
      // bit clears too (the edit sheet's Cancel does the same). The bulk
      // editor never adds or removes rows, so indices are stable.
      snapshot.forEach((value, index) => {
        form.resetField(`variants.${index}`, { defaultValue: value })
      })
    }
    snapshotRef.current = null
    onOpenChange(false)
  }, [form, onOpenChange])

  const handleDone = useCallback(() => {
    snapshotRef.current = null
    onOpenChange(false)
  }, [onOpenChange])

  const rows = useMemo<BulkVariantsRow[]>(
    () =>
      variants.map((v, idx) => ({
        id: `variant:${idx}`,
        variantLabel: v.options.length > 0 ? composeOptionsText(v.options, optionTypes) : null,
        sku: v.sku ?? null,
        barcode: v.barcode ?? null,
        weight: v.weight != null ? String(v.weight) : null,
        weightUnit: v.weight_unit ?? null,
        height: v.height != null ? String(v.height) : null,
        width: v.width != null ? String(v.width) : null,
        depth: v.depth != null ? String(v.depth) : null,
        dimensionsUnit: v.dimensions_unit ?? null,
        preorderable: !!v.preorderable,
        backorderLimit: v.backorder_limit != null ? String(v.backorder_limit) : null,
        taxCategoryId: v.tax_category_id ?? null,
        hsCode: v.hs_code ?? null,
        countryOfOrigin: v.country_of_origin ?? null,
        customsDescription: v.customs_description ?? null,
      })),
    [variants, optionTypes],
  )

  const handleChange = useCallback(
    (rowId: string, change: BulkVariantsChange) => {
      if (!rowId.startsWith('variant:')) return
      const idx = Number.parseInt(rowId.slice('variant:'.length), 10)
      if (Number.isNaN(idx)) return
      const set = (path: Parameters<typeof form.setValue>[0], value: unknown) =>
        form.setValue(path, value as never, { shouldDirty: true })

      switch (change.field) {
        case 'sku':
          set(`variants.${idx}.sku`, change.value)
          break
        case 'barcode':
          set(`variants.${idx}.barcode`, change.value)
          break
        case 'weightUnit':
          set(`variants.${idx}.weight_unit`, change.value)
          break
        case 'dimensionsUnit':
          set(`variants.${idx}.dimensions_unit`, change.value)
          break
        case 'taxCategoryId':
          set(`variants.${idx}.tax_category_id`, change.value)
          break
        case 'hsCode':
          set(`variants.${idx}.hs_code`, normalizeHsCode(change.value))
          break
        case 'countryOfOrigin':
          // Already an ISO code — SelectCell resolves pasted country names
          // against the option list before committing.
          set(`variants.${idx}.country_of_origin`, change.value)
          break
        case 'customsDescription':
          set(`variants.${idx}.customs_description`, normalizeCustomsDescription(change.value))
          break
        case 'preorderable':
          set(`variants.${idx}.preorderable`, change.value)
          break
        case 'backorderLimit': {
          if (change.value == null || change.value.trim() === '') {
            set(`variants.${idx}.backorder_limit`, null)
            break
          }
          const parsed = Number(change.value.trim().replace(',', '.'))
          if (!Number.isFinite(parsed) || parsed < 0) break
          set(`variants.${idx}.backorder_limit`, Math.trunc(parsed))
          break
        }
        default: {
          // weight / height / width / depth — decimals. Accept a comma
          // decimal (the cell ships raw input); ignore anything that doesn't
          // parse to a non-negative number rather than mangling it.
          if (change.value == null || change.value.trim() === '') {
            set(`variants.${idx}.${change.field}`, null)
            break
          }
          const parsed = Number(change.value.trim().replace(',', '.'))
          if (!Number.isFinite(parsed) || parsed < 0) break
          set(`variants.${idx}.${change.field}`, parsed)
          break
        }
      }
    },
    [form],
  )

  const unitOptions = (units: readonly string[]) => units.map((u) => ({ value: u, label: u }))

  return (
    <Dialog open={open} onOpenChange={(next) => (next ? onOpenChange(true) : handleCancel())} modal>
      <DialogContent
        // Edge-to-edge minus a 3-unit gutter, same overrides as the bulk
        // price dialog (see BulkPriceEditorDialog for why each is needed).
        className="!inset-3 !w-auto !max-w-none !translate-x-0 !translate-y-0 flex flex-col p-0"
        style={{ maxHeight: 'none' }}
        showCloseButton={false}
      >
        <DialogHeader className="flex flex-row items-center justify-between gap-3 space-y-0 border-b p-3">
          <DialogTitle className="truncate">
            {t('admin.products.variants.bulk_edit.title')}
          </DialogTitle>
          <div className="flex items-center gap-2">
            <Button type="button" size="sm" variant="outline" onClick={handleCancel}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="button" size="sm" onClick={handleDone}>
              {t('admin.actions.done')}
            </Button>
          </div>
        </DialogHeader>
        <DialogBody className="min-h-0 flex-1 overflow-auto p-3">
          <BulkVariantsTable
            rows={rows}
            onChange={handleChange}
            weightUnitOptions={unitOptions(WEIGHT_UNITS)}
            dimensionUnitOptions={unitOptions(DIMENSION_UNITS)}
            taxCategoryOptions={
              taxCategories.length > 0
                ? taxCategories.map((c) => ({ value: c.id, label: c.name }))
                : undefined
            }
            countryOptions={countryOptions.length > 0 ? countryOptions : undefined}
            labels={{
              variant: t('admin.pages.products.price_lists.edit_prices.columns.variant'),
              sku: t('admin.fields.variant.sku.label'),
              barcode: t('admin.fields.variant.barcode.label'),
              weight: t('admin.fields.variant.weight.label'),
              weightUnit: t('admin.fields.variant.weight_unit.label'),
              height: t('admin.fields.variant.height.label'),
              width: t('admin.fields.variant.width.label'),
              depth: t('admin.fields.variant.depth.label'),
              dimensionsUnit: t('admin.fields.variant.dimensions_unit.label'),
              preorderable: t('admin.fields.variant.preorderable.label'),
              backorderLimit: t('admin.fields.variant.backorder_limit.label'),
              taxCategory: t('admin.fields.tax_category_id.label'),
              hsCode: t('admin.fields.variant.hs_code.label'),
              countryOfOrigin: t('admin.fields.variant.country_of_origin.label'),
              customsDescription: t('admin.fields.variant.customs_description.label'),
              variantDefault: t('admin.products.variants.default_variant'),
              unitDefault: t('admin.products.variants.bulk_edit.unset'),
              taxCategoryNone: t('admin.products.variants.sheet.tax_category_placeholder'),
              countryOfOriginNone: t('admin.products.variants.bulk_edit.unset'),
              gridAriaLabel: t('admin.products.variants.bulk_edit.grid_aria'),
            }}
          />
        </DialogBody>
      </DialogContent>
    </Dialog>
  )
}
