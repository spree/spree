import { FieldLabel, QuantityTierEditor, type QuantityTierRow } from '@spree/dashboard-ui'
import { type FieldValues, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { type AdjustmentTierValue, MAXIMUM_QUANTITY_TIERS } from '../../schemas/price-list'

interface AdjustmentTierFormValues {
  adjustment_tiers: AdjustmentTierValue[]
}

/**
 * A list's quantity bands, edited as magnitudes — the form's direction
 * control carries the sign for the whole ladder. Shared by the catalog's
 * pricing card and the standalone price list page, so "10% off from ten
 * units" reads and validates the same in both places.
 */
export function AdjustmentTierFields<T extends FieldValues & AdjustmentTierFormValues>({
  form,
  canEdit,
  showLabel = true,
  emptyLabel,
  hint,
}: {
  form: UseFormReturn<T>
  canEdit: boolean
  showLabel?: boolean
  /** Page-specific copy; the defaults describe bands under a catalog's own percentage. */
  emptyLabel?: string
  hint?: string
}) {
  const { t } = useTranslation()
  // React Hook Form cannot narrow a path through a generic form type, so the
  // fields are addressed through the one shape every caller shares.
  const tierForm = form as unknown as UseFormReturn<AdjustmentTierFormValues>
  const { fields, append, remove } = useFieldArray({
    control: tierForm.control,
    name: 'adjustment_tiers',
  })
  const tiers = tierForm.watch('adjustment_tiers')
  const error = tierForm.formState.errors.adjustment_tiers

  const rows: QuantityTierRow[] = fields.map((field, index) => ({
    id: field.id,
    minQuantity: tiers?.[index]?.min_quantity ?? '',
    value: tiers?.[index]?.percentage ?? '',
  }))

  return (
    <div className="flex flex-col gap-2">
      {showLabel && <FieldLabel>{t('admin.fields.price_list.adjustment_tiers.label')}</FieldLabel>}
      <QuantityTierEditor
        rows={rows}
        labels={{
          quantity: t('admin.fields.price_list.adjustment_tiers.quantity'),
          value: t('admin.fields.price_list.adjustment_tiers.percentage'),
          add: t('admin.fields.price_list.adjustment_tiers.add'),
          remove: t('admin.fields.price_list.adjustment_tiers.remove'),
          empty: emptyLabel ?? t('admin.fields.price_list.adjustment_tiers.empty'),
          hint: hint ?? t('admin.fields.price_list.adjustment_tiers.help'),
        }}
        valueAddon="%"
        valueAddonAlign="inline-end"
        canAdd={canEdit && fields.length < MAXIMUM_QUANTITY_TIERS}
        disabled={!canEdit}
        error={typeof error?.message === 'string' ? error.message : undefined}
        onChange={(id, field, next) => {
          const index = fields.findIndex((row) => row.id === id)
          if (index < 0) return

          tierForm.setValue(
            `adjustment_tiers.${index}.${field === 'minQuantity' ? 'min_quantity' : 'percentage'}`,
            next,
            { shouldDirty: true, shouldValidate: true },
          )
        }}
        onAdd={() => append({ min_quantity: '', percentage: '' }, { shouldFocus: true })}
        onRemove={(id) => {
          const index = fields.findIndex((row) => row.id === id)
          if (index >= 0) remove(index)
        }}
      />
    </div>
  )
}
