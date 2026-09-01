import { zodResolver } from '@hookform/resolvers/zod'
import type { Fulfillment, Order } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Checkbox,
  cn,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Thumbnail,
} from '@spree/dashboard-ui'
import { PackageIcon, TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import { useEffect, useRef } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'
import { type FulfillmentItemRow, fulfillmentItemRows } from '../../../lib/fulfillment-items'
import { type FulfillItemsFormValues, fulfillItemsFormSchema } from '../../../schemas/fulfillment'

/** A row the merchant can pick a quantity for, and the line item it addresses. */
interface FulfillableRow extends FulfillmentItemRow {
  itemId: string
}

/**
 * Rows whose fulfillment item no longer maps to a line item are dropped: the
 * fulfill endpoint addresses items by line item, so there is nothing to send
 * for them. They still ship — selecting everything else sends no `items` at
 * all, which ships the whole fulfillment including them.
 */
function fulfillableRows(rows: FulfillmentItemRow[]): FulfillableRow[] {
  return rows.flatMap((row) => (row.lineItem ? [{ ...row, itemId: row.lineItem.id }] : []))
}

function ItemQuantityRow({
  row,
  index,
  selected,
  idPrefix,
  form,
}: {
  row: FulfillableRow
  index: number
  selected: boolean
  /** Scopes the field ids, since an order can show several of these forms. */
  idPrefix: string
  form: UseFormReturn<FulfillItemsFormValues>
}) {
  const { t } = useTranslation()
  const checkboxId = `${idPrefix}-item-${index}`

  return (
    <div className={cn('flex items-center gap-3 p-3', selected && 'bg-accent')}>
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

      <Thumbnail src={row.thumbnailUrl} fallback={<PackageIcon />} />

      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{row.name}</div>
        {row.optionsText && (
          <div className="truncate text-xs text-muted-foreground">{row.optionsText}</div>
        )}
      </div>

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
            <span className="w-16 text-sm whitespace-nowrap text-muted-foreground">
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
 */
export function FulfillmentFulfillForm({
  order,
  fulfillment,
  onDone,
}: {
  order: Order
  fulfillment: Fulfillment
  onDone: () => void
}) {
  const { t } = useTranslation()
  const { fulfill } = useFulfillmentActions(order.id)
  const { data: carriersData } = useTrackingCarriers()

  const carrierOptions = [
    { value: '', label: t('admin.orders.detail.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((carrier) => ({ value: carrier.id, label: carrier.name })),
  ]

  const idPrefix = `fulfill-${fulfillment.id}`
  const rows = fulfillableRows(fulfillmentItemRows(fulfillment, order.items ?? []))

  const form = useForm<FulfillItemsFormValues>({
    resolver: zodResolver(fulfillItemsFormSchema),
    defaultValues: {
      items: rows.map((row) => ({ item_id: row.itemId, selected: true, quantity: row.quantity })),
      tracking: fulfillment.tracking ?? '',
      tracking_carrier: fulfillment.tracking_carrier ?? '',
      notify_customer: true,
    },
  })
  const { errors } = form.formState

  // A refetch re-renders this form with fresh rows, so the values it mirrors
  // have to follow. The effect keys on the fulfillment's composition, not on
  // the rows array itself, so a refetch that returns the same units does not
  // wipe what the merchant typed. The ref carries the rows across without
  // making them a dependency.
  const rowsRef = useRef(rows)
  rowsRef.current = rows
  const rowsKey = rows.map((row) => `${row.itemId}:${row.quantity}`).join('|')
  const seededKey = useRef(rowsKey)

  useEffect(() => {
    if (seededKey.current === rowsKey) return
    seededKey.current = rowsKey
    form.reset({
      ...form.getValues(),
      items: rowsRef.current.map((row) => ({
        item_id: row.itemId,
        selected: true,
        quantity: row.quantity,
      })),
    })
  }, [rowsKey, form])

  const watched = form.watch('items')
  const totalSelected = watched.reduce(
    (sum, item) => sum + (item.selected ? item.quantity || 0 : 0),
    0,
  )
  const totalAvailable = rows.reduce((sum, row) => sum + row.quantity, 0)
  const shipsEverything = totalSelected === totalAvailable

  async function onSubmit(values: FulfillItemsFormValues) {
    const items = values.items
      .filter((item) => item.selected && item.quantity > 0)
      .map((item) => ({ item_id: item.item_id, quantity: item.quantity }))
    if (items.length === 0) return

    // Recomputed from the submitted values rather than reusing the watched
    // total, so the branch is decided by exactly what is being sent.
    const everything = items.reduce((sum, item) => sum + item.quantity, 0) === totalAvailable
    const tracking = values.tracking.trim()

    try {
      // Omitting `items` is the documented way to ship the whole fulfillment,
      // and it avoids a pointless split when every unit was selected anyway.
      await fulfill.mutateAsync({
        fulfillmentId: fulfillment.id,
        items: everything ? undefined : items,
        tracking: tracking || undefined,
        tracking_carrier: values.tracking_carrier || undefined,
        notify_customer: values.notify_customer,
      })
      onDone()
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col">
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      {rows.length === 0 ? (
        <p className="py-6 text-center text-muted-foreground">{t('admin.orders.fulfill.empty')}</p>
      ) : (
        <div className="divide-y">
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

      <div className="grid grid-cols-1 gap-4 p-3 border-t sm:grid-cols-2">
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
            className="flex cursor-pointer items-center gap-2 text-sm p-3"
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
        <div className="px-3 pb-3">
          <Alert variant="warning">
            <TriangleAlertIcon />
            <AlertDescription>{t('admin.orders.fulfill.partial_hint')}</AlertDescription>
          </Alert>
        </div>
      )}

      <div className="flex items-center justify-end gap-2 p-3 border-t">
        <span className="mr-auto text-sm text-muted-foreground">
          {t('admin.orders.fulfill.units_selected')}: {totalSelected} / {totalAvailable}
        </span>
        <Button type="button" size="sm" variant="outline" onClick={onDone}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="submit" size="sm" disabled={totalSelected === 0 || fulfill.isPending}>
          {fulfill.isPending ? t('admin.actions.saving') : t('admin.orders.fulfill.submit')}
        </Button>
      </div>
    </form>
  )
}
