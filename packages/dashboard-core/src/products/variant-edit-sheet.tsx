import type { ProductFormValues, VariantFormValues } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useFormOptionTypes as useOptionTypes,
  useFormTaxCategories as useTaxCategories,
} from './use-product-form-data'
import {
  VariantAvailabilityFields,
  VariantCustomsFields,
  VariantIdentityFields,
  VariantOrderingFields,
  VariantShippingFields,
} from './variant-field-sections'
import { variantDisplayLabel } from './variants-matrix'

interface Props {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
  variantIndex: number
  open: boolean
  onOpenChange: (open: boolean) => void
}

// Per-variant detail editor. Binds to variants.${i}.* on the parent product
// form — no own form state. Save closes the sheet (changes are already in
// form state; the product Save button commits them). Cancel restores the
// snapshot captured when the sheet opened.
export function VariantEditSheet({ form, variantIndex, open, onOpenChange }: Props) {
  const { t } = useTranslation()
  const { data: taxCategoriesResponse } = useTaxCategories()
  const taxCategories = taxCategoriesResponse?.data ?? []
  const hasTaxCategories = taxCategories.length > 0
  const { data: optionTypesData } = useOptionTypes()
  const optionTypes = optionTypesData?.data ?? []

  // Snapshot the variant when the sheet opens so Cancel can restore it.
  // Re-snapshot if the user switches between variant rows without closing
  // (variantIndex changes while open) so the next Cancel restores the right row.
  //
  // Deep-clone via structuredClone — `form.getValues` returns a reference
  // to RHF's internal field state, and the inline cell editors mutate
  // nested arrays (prices, stock_levels) in place. Without the clone, Cancel
  // would write back the already-edited object.
  //
  // We also stash the variant's `id` (for persisted rows). The sheet is
  // modal so it's hard but not impossible for the matrix array to reorder
  // underneath (e.g. keyboard reorder while focus is in the sheet). On
  // Cancel, re-resolve the index by id and only restore if the snapshot
  // still maps to a unique row — otherwise drop the restore rather than
  // overwriting a different variant's values.
  const snapshotRef = useRef<{ value: VariantFormValues; id: string | undefined } | null>(null)
  useEffect(() => {
    if (!open) {
      snapshotRef.current = null
      return
    }
    const current = form.getValues(`variants.${variantIndex}`)
    snapshotRef.current = current
      ? { value: structuredClone(current) as VariantFormValues, id: current.id }
      : null
  }, [open, variantIndex, form])

  const variant = form.watch(`variants.${variantIndex}`)
  if (!variant) return null

  const label = variantDisplayLabel(
    variant,
    t('admin.products.variants.default_variant'),
    optionTypes,
  )

  const handleCancel = () => {
    const snap = snapshotRef.current
    if (snap) {
      // Resolve the target index by stable id when we have one — the array
      // may have reordered while the sheet was open. For unsaved rows
      // (no id) trust the current index.
      let targetIndex = variantIndex
      if (snap.id) {
        const all = form.getValues('variants') ?? []
        const found = all.findIndex((v) => v.id === snap.id)
        if (found === -1) return onOpenChange(false)
        targetIndex = found
      }
      // Restore the snapshot via resetField so the variant's dirty bit is
      // cleared too — `setValue` with `shouldDirty: true` would leave the
      // form falsely dirty after a no-op cancel (same trap MediaEditSheet
      // hit). `resetField` re-baselines just this subtree, leaving sibling
      // dirty fields elsewhere on the form untouched.
      form.resetField(`variants.${targetIndex}`, { defaultValue: snap.value })
    }
    onOpenChange(false)
  }

  const handleDone = () => {
    onOpenChange(false)
  }

  // One definition for both dashboards: the shared sections address their
  // fields through this prefix, so the seller panel's offer page renders the
  // same inputs at the root of its own form
  // (docs/plans/6.0-seller-master-catalog-listings.md).
  const prefix = `variants.${variantIndex}`
  const variantErrors = form.formState.errors.variants?.[variantIndex]

  return (
    <Sheet open={open} onOpenChange={(o) => (o ? onOpenChange(o) : handleCancel())}>
      <SheetContent side="right" showCloseButton={false} className="flex flex-col">
        <SheetHeader>
          <SheetTitle>{t('admin.products.variants.edit_variant', { name: label })}</SheetTitle>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-6">
          <Section title={t('admin.products.variants.sheet.identity')}>
            <VariantIdentityFields form={form} prefix={prefix} errors={variantErrors} />
          </Section>

          <Section title={t('admin.fields.shipping.label')}>
            <VariantShippingFields form={form} prefix={prefix} errors={variantErrors} />
          </Section>

          <Section title={t('admin.products.variants.sheet.customs')}>
            <VariantCustomsFields form={form} prefix={prefix} errors={variantErrors} />
          </Section>

          <Section title={t('admin.products.variants.sheet.ordering')}>
            <p className="text-muted-foreground text-sm">
              {t('admin.products.variants.sheet.ordering_help')}
            </p>
            <VariantOrderingFields form={form} prefix={prefix} errors={variantErrors} />
          </Section>

          <Section title={t('admin.products.variants.sheet.availability')}>
            <VariantAvailabilityFields form={form} prefix={prefix} errors={variantErrors} />
          </Section>

          {hasTaxCategories && (
            <Section title={t('admin.fields.tax.label')}>
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-tax-cat`}>
                  {t('admin.fields.tax_category_id.label')}
                </FieldLabel>
                <Controller
                  name={`variants.${variantIndex}.tax_category_id`}
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      value={field.value ?? ''}
                      onValueChange={(v) => field.onChange(v || null)}
                    >
                      <SelectTrigger id={`variant-${variantIndex}-tax-cat`} className="w-full">
                        <SelectValue
                          placeholder={t('admin.products.variants.sheet.tax_category_placeholder')}
                        >
                          {(v) =>
                            taxCategories.find((c) => c.id === v)?.name ??
                            t('admin.products.variants.sheet.tax_category_placeholder')
                          }
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {taxCategories.map((cat) => (
                          <SelectItem key={cat.id} value={cat.id}>
                            {cat.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </Field>
            </Section>
          )}
        </div>

        <SheetFooter>
          <Button type="button" variant="outline" onClick={handleCancel}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleDone}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <h3 className="text-sm font-medium">{title}</h3>
      {children}
    </section>
  )
}
