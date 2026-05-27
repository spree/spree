import { type Control, Controller, type FieldPath, type FieldValues } from 'react-hook-form'
import { Field, FieldLabel } from '@/components/ui/field'
import { Switch } from '@/components/ui/switch'

interface StorefrontVisibleSwitchProps<TFieldValues extends FieldValues> {
  control: Control<TFieldValues>
  name: FieldPath<TFieldValues>
  /** Defaults to "Visible on storefront". */
  label?: string
  /** Helper text under the row. Defaults to the on/off explanation. */
  description?: string
  /** Switch id — defaults to the field name. */
  id?: string
}

/**
 * Canonical 5.5+ "Visible on storefront" control. Wraps a `Switch` with
 * a labelled row mirroring the Active / Auto-capture rows on the same
 * forms. Used by every resource that exposes `storefront_visible` on
 * the API (PaymentMethod today; ShippingMethod/DeliveryMethod when
 * those admin pages land — see `docs/plans/5.5-6.0-display-on-to-boolean.md`).
 *
 * For column-cell rendering use `<ActiveBadge active={…} activeLabel="Visible"
 * inactiveLabel="Admin only" />` so the visibility column matches the
 * Active column's visual treatment.
 */
export function StorefrontVisibleSwitch<TFieldValues extends FieldValues>({
  control,
  name,
  label = 'Visible on storefront',
  description = 'When off, only admin staff see this option (back-office orders, manual entry).',
  id,
}: StorefrontVisibleSwitchProps<TFieldValues>) {
  const fieldId = id ?? name
  return (
    <Field>
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col">
          <FieldLabel htmlFor={fieldId} className="cursor-pointer">
            {label}
          </FieldLabel>
          <span className="text-xs text-muted-foreground">{description}</span>
        </div>
        <Controller
          name={name}
          control={control}
          render={({ field }) => (
            <Switch id={fieldId} checked={!!field.value} onCheckedChange={field.onChange} />
          )}
        />
      </div>
    </Field>
  )
}
