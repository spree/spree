import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Checkbox,
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { useEffect, useRef } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../hooks/use-reasons'
import { type FulfillItemsFormValues, fulfillItemsFormSchema } from '../../schemas/fulfillment'

type Row = { itemId: string; label: string; available: number }

/**
 * One row per line item, not per fulfillment item.
 *
 * A parcel routinely holds two rows for the same line item — the packer
 * splits a partly-stocked line into an on-hand unit and a backordered one —
 * and the server addresses what to ship by line item. Left unmerged, the two
 * rows share a React key, one stepper silently moves the other, and the
 * payload sends the same `item_id` twice, where last-wins makes a seller who
 * selected everything ship only half of it.
 */
function fulfillableRows(fulfillment: Fulfillment): Row[] {
  const byLineItem = new Map<string, Row>()

  for (const item of fulfillment.fulfillment_items ?? []) {
    const itemId = item.line_item_id ?? item.id
    const existing = byLineItem.get(itemId)

    if (existing) {
      existing.available += item.quantity
    } else {
      byLineItem.set(itemId, {
        itemId,
        label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
        available: item.quantity,
      })
    }
  }

  return [...byLineItem.values()]
}

/**
 * Marking a parcel sent.
 *
 * Replaces the card's body rather than opening a dialog: the seller has the
 * parcel and the tracking number in hand, and shipping part of it is a
 * normal thing to do — what is left splits onto a parcel of its own.
 */
export function FulfillmentFulfillForm({
  orderId,
  fulfillment,
  onDone,
}: {
  orderId: string
  fulfillment: Fulfillment
  onDone: () => void
}) {
  const { t } = useTranslation()
  const { fulfill } = useFulfillmentActions(orderId)
  const { data: carriersData } = useTrackingCarriers()

  const carrierOptions = [
    { value: '', label: t('orders.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((option) => ({ value: option.id, label: option.name })),
  ]

  const rows = fulfillableRows(fulfillment)

  const form = useForm<FulfillItemsFormValues>({
    resolver: zodResolver(fulfillItemsFormSchema),
    defaultValues: {
      items: rows.map((row) => ({ item_id: row.itemId, selected: true, quantity: row.available })),
      tracking: '',
      tracking_carrier: '',
      notify_customer: true,
    },
  })
  const { errors } = form.formState

  // Sending part of a parcel splits the rest onto a new one, and the source
  // keeps its id with fewer units — so the values this form mirrors have to
  // follow. Keyed on the parcel's composition rather than the rows array, so
  // a refetch returning the same units does not wipe what was typed.
  const rowsRef = useRef(rows)
  rowsRef.current = rows
  const rowsKey = rows.map((row) => `${row.itemId}:${row.available}`).join('|')
  const seededKey = useRef(rowsKey)

  useEffect(() => {
    if (seededKey.current === rowsKey) return
    seededKey.current = rowsKey
    form.reset({
      ...form.getValues(),
      items: rowsRef.current.map((row) => ({
        item_id: row.itemId,
        selected: true,
        quantity: row.available,
      })),
    })
  }, [rowsKey, form])

  const watched = form.watch('items')
  const selectedUnits = watched.reduce(
    (total, item) => total + (item.selected ? item.quantity || 0 : 0),
    0,
  )
  const totalUnits = rows.reduce((total, row) => total + row.available, 0)
  const partial = selectedUnits > 0 && selectedUnits < totalUnits

  async function onSubmit(values: FulfillItemsFormValues) {
    const items = values.items
      .filter((item) => item.selected && item.quantity > 0)
      .map((item) => ({ item_id: item.item_id, quantity: item.quantity }))
    if (items.length === 0) return

    // Recomputed from what is being sent rather than the watched total, so
    // the branch is decided by exactly this payload.
    const everything = items.reduce((total, item) => total + item.quantity, 0) === totalUnits
    const tracking = values.tracking.trim()

    try {
      // Omitting `items` is how the whole parcel ships, and it avoids a
      // pointless split when every unit was selected anyway.
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
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-4">
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <div className="flex flex-col gap-2">
        {rows.map((row, index) => (
          <div key={row.itemId} className="flex items-center justify-between gap-3">
            <label
              className="flex min-w-0 items-center gap-2 text-sm"
              htmlFor={`ship-${row.itemId}`}
            >
              <Controller
                control={form.control}
                name={`items.${index}.selected`}
                render={({ field }) => (
                  <Checkbox
                    id={`ship-${row.itemId}`}
                    checked={field.value}
                    onCheckedChange={(checked) => field.onChange(!!checked)}
                  />
                )}
              />
              <span className="truncate">{row.label}</span>
            </label>
            <Controller
              control={form.control}
              name={`items.${index}.quantity`}
              render={({ field }) => (
                <Input
                  type="number"
                  min={0}
                  max={row.available}
                  className="w-20"
                  aria-label={t('orders.fulfillments.quantity_for', { name: row.label })}
                  value={field.value}
                  onChange={(event) =>
                    field.onChange(
                      Math.max(0, Math.min(row.available, Number(event.target.value) || 0)),
                    )
                  }
                />
              )}
            />
          </div>
        ))}
      </div>

      <FieldError errors={[errors.items?.message ? errors.items : undefined]} />

      <p className="text-muted-foreground text-xs">
        {t('orders.fulfillments.units_selected', { selected: selectedUnits, total: totalUnits })}
      </p>

      {partial && (
        <Alert>
          <AlertDescription>{t('orders.fulfillments.partial_warning')}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`fulfill-tracking-${fulfillment.id}`}>
            {t('orders.tracking_label')}
          </FieldLabel>
          <Input
            id={`fulfill-tracking-${fulfillment.id}`}
            placeholder={t('orders.tracking_placeholder')}
            {...form.register('tracking')}
          />
        </Field>

        <Field>
          <FieldLabel htmlFor={`fulfill-carrier-${fulfillment.id}`}>
            {t('orders.fulfillments.carrier_label')}
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
                <SelectTrigger id={`fulfill-carrier-${fulfillment.id}`}>
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

      <label className="flex items-center gap-2 text-sm" htmlFor={`notify-${fulfillment.id}`}>
        <Controller
          control={form.control}
          name="notify_customer"
          render={({ field }) => (
            <Checkbox
              id={`notify-${fulfillment.id}`}
              checked={field.value}
              onCheckedChange={(checked) => field.onChange(!!checked)}
            />
          )}
        />
        {t('orders.fulfillments.notify_customer')}
      </label>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" disabled={fulfill.isPending || selectedUnits === 0}>
          {fulfill.isPending ? t('orders.fulfilling') : t('orders.fulfill')}
        </Button>
      </div>
    </form>
  )
}
