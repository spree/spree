import { StoreDatePicker } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldLabel,
  Input,
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
  Switch,
} from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useOptionTypes } from '../../../hooks/use-option-types'
import { useTaxCategories } from '../../../hooks/use-tax-categories'
import type { ProductFormValues, VariantFormValues } from '../../../schemas/product'
import { variantDisplayLabel } from './variants-matrix'

const WEIGHT_UNITS = ['g', 'kg', 'lb', 'oz'] as const
const DIMENSION_UNITS = ['mm', 'cm', 'in'] as const

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
  const { data: optionTypesData } = useOptionTypes({ limit: 100 })
  const optionTypes = optionTypesData?.data ?? []

  // Snapshot the variant when the sheet opens so Cancel can restore it.
  // Re-snapshot if the user switches between variant rows without closing
  // (variantIndex changes while open) so the next Cancel restores the right row.
  //
  // Deep-clone via structuredClone — `form.getValues` returns a reference
  // to RHF's internal field state, and the inline cell editors mutate
  // nested arrays (prices, stock_items) in place. Without the clone, Cancel
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

  return (
    <Sheet open={open} onOpenChange={(o) => (o ? onOpenChange(o) : handleCancel())}>
      <SheetContent side="right" showCloseButton={false} className="flex flex-col">
        <SheetHeader>
          <SheetTitle>{t('admin.products.variants.edit_variant', { name: label })}</SheetTitle>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-6">
          <Section title={t('admin.products.variants.sheet.identity')}>
            <Field>
              <FieldLabel htmlFor={`variant-${variantIndex}-sku`}>
                {t('admin.fields.variant.sku.label')}
              </FieldLabel>
              {/*
                Use Controller instead of register here: the matrix row in
                VariantsSection also registers `variants.${i}.sku`, and two
                `register` calls on the same field path share a single ref
                slot — the second mount wins, so typing in one input never
                updates the other's display. A Controller subscribes to the
                field via useController and renders a controlled input, so
                both surfaces stay in sync whichever one the merchant edits.
              */}
              <Controller
                name={`variants.${variantIndex}.sku`}
                control={form.control}
                render={({ field }) => (
                  <Input
                    id={`variant-${variantIndex}-sku`}
                    placeholder={t('admin.fields.variant.sku.placeholder')}
                    value={field.value ?? ''}
                    onChange={(e) => field.onChange(e.target.value)}
                    onBlur={field.onBlur}
                  />
                )}
              />
              <FieldError errors={[form.formState.errors.variants?.[variantIndex]?.sku]} />
            </Field>
            <Field>
              <FieldLabel htmlFor={`variant-${variantIndex}-barcode`}>
                {t('admin.fields.variant.barcode.label')}
              </FieldLabel>
              <Input
                id={`variant-${variantIndex}-barcode`}
                {...form.register(`variants.${variantIndex}.barcode`)}
              />
              <FieldError errors={[form.formState.errors.variants?.[variantIndex]?.barcode]} />
            </Field>
          </Section>

          <Section title={t('admin.fields.shipping.label')}>
            <div className="grid grid-cols-[1fr_120px] gap-3">
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-weight`}>
                  {t('admin.fields.variant.weight.label')}
                </FieldLabel>
                <Input
                  id={`variant-${variantIndex}-weight`}
                  type="number"
                  step="0.01"
                  min="0"
                  {...form.register(`variants.${variantIndex}.weight`)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-weight-unit`}>
                  {t('admin.fields.variant.weight_unit.label')}
                </FieldLabel>
                <Controller
                  name={`variants.${variantIndex}.weight_unit`}
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      value={field.value ?? ''}
                      onValueChange={(v) => field.onChange(v || null)}
                    >
                      <SelectTrigger id={`variant-${variantIndex}-weight-unit`} className="w-full">
                        <SelectValue>{(v) => (v as string) || '—'}</SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {WEIGHT_UNITS.map((u) => (
                          <SelectItem key={u} value={u}>
                            {u}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </Field>
            </div>

            <div className="grid grid-cols-[1fr_1fr_1fr_120px] gap-3">
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-height`}>
                  {t('admin.fields.variant.height.label')}
                </FieldLabel>
                <Input
                  id={`variant-${variantIndex}-height`}
                  type="number"
                  step="0.01"
                  min="0"
                  {...form.register(`variants.${variantIndex}.height`)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-width`}>
                  {t('admin.fields.variant.width.label')}
                </FieldLabel>
                <Input
                  id={`variant-${variantIndex}-width`}
                  type="number"
                  step="0.01"
                  min="0"
                  {...form.register(`variants.${variantIndex}.width`)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-depth`}>
                  {t('admin.fields.variant.depth.label')}
                </FieldLabel>
                <Input
                  id={`variant-${variantIndex}-depth`}
                  type="number"
                  step="0.01"
                  min="0"
                  {...form.register(`variants.${variantIndex}.depth`)}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor={`variant-${variantIndex}-dim-unit`}>
                  {t('admin.fields.variant.dimensions_unit.label')}
                </FieldLabel>
                <Controller
                  name={`variants.${variantIndex}.dimensions_unit`}
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      value={field.value ?? ''}
                      onValueChange={(v) => field.onChange(v || null)}
                    >
                      <SelectTrigger id={`variant-${variantIndex}-dim-unit`} className="w-full">
                        <SelectValue>{(v) => (v as string) || '—'}</SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {DIMENSION_UNITS.map((u) => (
                          <SelectItem key={u} value={u}>
                            {u}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </Field>
            </div>
          </Section>

          <Section title={t('admin.products.variants.sheet.availability')}>
            <Field>
              <div className="flex items-start justify-between gap-4">
                <div className="flex flex-col">
                  <FieldLabel
                    htmlFor={`variant-${variantIndex}-preorderable`}
                    className="cursor-pointer"
                  >
                    {t('admin.fields.variant.preorderable.label')}
                  </FieldLabel>
                  <span className="text-xs text-muted-foreground">
                    {t('admin.fields.variant.preorderable.help')}
                  </span>
                </div>
                <Controller
                  name={`variants.${variantIndex}.preorderable`}
                  control={form.control}
                  render={({ field }) => (
                    <Switch
                      id={`variant-${variantIndex}-preorderable`}
                      checked={!!field.value}
                      onCheckedChange={field.onChange}
                    />
                  )}
                />
              </div>
            </Field>

            {variant.preorderable && (
              <Field>
                <FieldLabel>{t('admin.fields.variant.preorder_ships_at.label')}</FieldLabel>
                <Controller
                  control={form.control}
                  name={`variants.${variantIndex}.preorder_ships_at`}
                  render={({ field }) => (
                    <StoreDatePicker
                      value={field.value ?? null}
                      onChange={(next) => field.onChange(next ?? null)}
                      placeholder={t('admin.fields.variant.preorder_ships_at.placeholder')}
                      includeTime
                      inline
                    />
                  )}
                />
                <span className="text-xs text-muted-foreground">
                  {t('admin.fields.variant.preorder_ships_at.help')}
                </span>
              </Field>
            )}

            <Field>
              <FieldLabel htmlFor={`variant-${variantIndex}-backorder-limit`}>
                {t('admin.fields.variant.backorder_limit.label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name={`variants.${variantIndex}.backorder_limit`}
                render={({ field }) => (
                  <Input
                    id={`variant-${variantIndex}-backorder-limit`}
                    type="number"
                    min="0"
                    step="1"
                    placeholder={t('admin.fields.variant.backorder_limit.placeholder')}
                    value={field.value ?? ''}
                    onChange={(event) => {
                      const parsed = Number(event.target.value)
                      field.onChange(
                        event.target.value === '' || Number.isNaN(parsed)
                          ? null
                          : Math.max(0, Math.trunc(parsed)),
                      )
                    }}
                  />
                )}
              />
              <span className="text-xs text-muted-foreground">
                {t('admin.fields.variant.backorder_limit.help')}
              </span>
              <FieldError
                errors={[form.formState.errors.variants?.[variantIndex]?.backorder_limit]}
              />
            </Field>
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
          <Button type="button" variant="ghost" onClick={handleCancel}>
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
