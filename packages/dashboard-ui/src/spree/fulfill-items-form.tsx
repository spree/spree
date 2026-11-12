import type { UseFormReturn } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { Alert, AlertDescription } from '../ui/alert'
import { Button } from '../ui/button'
import { Checkbox } from '../ui/checkbox'
import { Field, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'
import { TriangleAlertIcon } from './icons'
import { ProductIdentity } from './product-identity'

/** A pickable row: what it looks like and how many units are on offer. */
export type FulfillableRowData = {
  key: string
  itemId: string
  name: string
  optionsText?: string | null
  thumbnailUrl?: string | null
  quantity: number
}

/** The form shape both panels bind — see the shared fulfillment schema. */
export type FulfillItemsValues = {
  items: Array<{ item_id: string; selected: boolean; quantity: number }>
  tracking: string
  tracking_carrier: string
  notify_customer: boolean
}

function ItemQuantityRow({
  row,
  index,
  selected,
  idPrefix,
  form,
}: {
  row: FulfillableRowData
  index: number
  selected: boolean
  /** Scopes the field ids, since an order can show several of these forms. */
  idPrefix: string
  form: UseFormReturn<FulfillItemsValues>
}) {
  const { t } = useTranslation()
  const checkboxId = `${idPrefix}-item-${index}`

  return (
    <div
      className={cn('my-2 flex items-center gap-3 rounded-lg p-2', selected && 'bg-accent-strong')}
    >
      <Controller
        control={form.control}
        name={`items.${index}.selected`}
        render={({ field }) => (
          <Checkbox
            id={checkboxId}
            checked={field.value}
            aria-label={t('admin.orders.fulfill.include_item', { name: row.name })}
            onCheckedChange={(checked) => {
              const include = checked === true
              field.onChange(include)
              // Re-checking restores the full held quantity, so the merchant
              // never has to retype what they just excluded.
              form.setValue(`items.${index}.quantity`, include ? row.quantity : 0, {
                shouldDirty: true,
              })
            }}
          />
        )}
      />

      <ProductIdentity
        name={row.name}
        subtitle={row.optionsText}
        thumbnailUrl={row.thumbnailUrl}
        className="flex-1"
      />

      <Controller
        control={form.control}
        name={`items.${index}.quantity`}
        render={({ field }) => (
          <div className="flex shrink-0 items-center gap-2">
            <Input
              type="number"
              min={0}
              max={row.quantity}
              className="w-20 text-right"
              disabled={!selected}
              aria-label={t('admin.orders.fulfill.quantity_for', { name: row.name })}
              value={field.value}
              onChange={(event) => {
                const parsed = Number(event.target.value)
                const quantity = Number.isFinite(parsed)
                  ? Math.max(0, Math.min(parsed, row.quantity))
                  : 0
                field.onChange(quantity)
                // Typing the quantity down to zero is the same statement as
                // unticking the row, so keep the two in step.
                form.setValue(`items.${index}.selected`, quantity > 0, { shouldDirty: true })
              }}
              onBlur={field.onBlur}
            />
            <span className="w-16 whitespace-nowrap text-muted-foreground text-base">
              {t('admin.orders.fulfill.of_units', { count: row.quantity })}
            </span>
          </div>
        )}
      />
    </div>
  )
}

/**
 * Picks what to ship out of one fulfillment, in place of the card's normal
 * contents. Shipping everything is the default; lowering a quantity or
 * unticking an item splits the chosen units into a new fulfillment that ships,
 * leaving the rest of this one open.
 *
 * Shared by the operator's order page and the seller's. Headless: the caller
 * owns the form instance and the submit, so each panel keeps its own mutation
 * and its own idea of who may ship — this holds the shape and the
 * select/quantity coupling so the two cannot drift.
 */
export function FulfillItemsForm({
  form,
  rows,
  idPrefix,
  carrierOptions,
  onSubmit,
  onCancel,
  canShipWholeParcel = false,
  pending = false,
}: {
  form: UseFormReturn<FulfillItemsValues>
  rows: FulfillableRowData[]
  idPrefix: string
  /** Carriers to choose between; the first is normally "detect from number". */
  carrierOptions: Array<{ value: string; label: string }>
  onSubmit: (values: FulfillItemsValues) => void | Promise<void>
  onCancel: () => void
  /**
   * Whether the parcel can ship with nothing picked.
   *
   * True when it holds items that no row can address — the workflow reads an
   * empty selection as "everything", so blocking submit would leave such a
   * parcel unshippable. Never inferred from `rows` being empty here: that
   * cannot tell an unaddressable parcel from an empty one, and an empty
   * fulfillment must stay unsubmittable.
   */
  canShipWholeParcel?: boolean
  pending?: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  const watched = form.watch('items')
  const totalSelected = watched.reduce(
    (sum, item) => sum + (item.selected ? item.quantity || 0 : 0),
    0,
  )
  const totalAvailable = rows.reduce((sum, row) => sum + row.quantity, 0)
  const shipsEverything = totalSelected === totalAvailable

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col">
      {errors.root?.message && (
        <p className="px-4 pt-3 text-destructive text-base" role="alert">
          {errors.root.message}
        </p>
      )}

      {rows.length === 0 ? (
        <p className="py-6 text-center text-muted-foreground">{t('admin.orders.fulfill.empty')}</p>
      ) : (
        // Rows are inset 8px so a selected row's fill sits inside the card,
        // and their own 8px padding lines the content up with the 16px card
        // content below.
        <div className="divide-y px-2">
          {rows.map((row, index) => (
            <ItemQuantityRow
              key={row.key}
              row={row}
              index={index}
              selected={watched[index]?.selected ?? true}
              idPrefix={idPrefix}
              form={form}
            />
          ))}
        </div>
      )}

      <div className="mx-4 grid grid-cols-1 gap-4 border-border-subtle border-t py-3 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${idPrefix}-tracking`}>
            {t('admin.orders.fulfill.tracking_label')}
          </FieldLabel>
          <Input
            id={`${idPrefix}-tracking`}
            placeholder={t('admin.orders.fulfill.tracking_placeholder')}
            {...form.register('tracking')}
          />
        </Field>

        <Field>
          <FieldLabel htmlFor={`${idPrefix}-tracking-carrier`}>
            {t('admin.orders.detail.fulfillments.carrier_label')}
          </FieldLabel>
          <Controller
            control={form.control}
            name="tracking_carrier"
            render={({ field }) => (
              <Select
                items={carrierOptions}
                value={field.value}
                onValueChange={(value) => field.onChange(value ?? '')}
              >
                <SelectTrigger id={`${idPrefix}-tracking-carrier`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {carrierOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </Field>
      </div>

      <Controller
        control={form.control}
        name="notify_customer"
        render={({ field }) => (
          <label
            htmlFor={`${idPrefix}-notify`}
            className="flex cursor-pointer items-center gap-2 px-4 py-3 text-base"
          >
            <Checkbox
              id={`${idPrefix}-notify`}
              checked={field.value}
              onCheckedChange={(checked) => field.onChange(checked === true)}
            />
            {t('admin.orders.fulfill.notify_customer')}
          </label>
        )}
      />

      {!shipsEverything && totalSelected > 0 && (
        <div className="px-4 pb-3">
          <Alert variant="warning">
            <TriangleAlertIcon />
            <AlertDescription>{t('admin.orders.fulfill.partial_hint')}</AlertDescription>
          </Alert>
        </div>
      )}

      <div className="mx-4 flex items-center justify-end gap-2 border-border-subtle border-t py-3">
        <span className="mr-auto text-muted-foreground text-base">
          {t('admin.orders.fulfill.units_selected')}: {totalSelected} / {totalAvailable}
        </span>
        <Button type="button" size="sm" variant="outline" onClick={onCancel}>
          {t('admin.actions.cancel')}
        </Button>
        <Button
          type="submit"
          size="sm"
          disabled={(totalSelected === 0 && !canShipWholeParcel) || pending}
        >
          {pending ? t('admin.actions.saving') : t('admin.orders.fulfill.submit')}
        </Button>
      </div>
    </form>
  )
}
