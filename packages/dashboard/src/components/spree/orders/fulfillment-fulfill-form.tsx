import { zodResolver } from '@hookform/resolvers/zod'
import type { Fulfillment, Order } from '@spree/admin-sdk'
import {
  type FulfillmentItemRow,
  fulfillmentItemRows,
  mapSpreeErrorsToForm,
} from '@spree/dashboard-core'
import {
  type FulfillableRowData,
  FulfillItemsForm,
  type FulfillItemsValues,
} from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../../hooks/use-tracking-carriers'
import { type FulfillItemsFormValues, fulfillItemsFormSchema } from '../../../schemas/fulfillment'

/**
 * Rows whose fulfillment item no longer maps to a line item are dropped: the
 * fulfill endpoint addresses items by line item, so there is nothing to send
 * for them. They still ship — selecting everything else sends no `items` at
 * all, which ships the whole fulfillment including them.
 */
function fulfillableRows(rows: FulfillmentItemRow[]): FulfillableRowData[] {
  return rows.flatMap((row) => (row.lineItem ? [{ ...row, itemId: row.lineItem.id }] : []))
}

/** What the operator ships out of one fulfillment. */
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
      // The carrier is detected from the number, or picked in the tracking
      // dialog once the parcel has one.
      tracking_carrier: '',
      notify_customer: true,
    },
  })

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

  const totalAvailable = rows.reduce((sum, row) => sum + row.quantity, 0)

  async function onSubmit(values: FulfillItemsValues) {
    const items = values.items
      .filter((item) => item.selected && item.quantity > 0)
      .map((item) => ({ item_id: item.item_id, quantity: item.quantity }))
    if (items.length === 0) return

    // Recomputed from the submitted values rather than a watched total, so the
    // branch is decided by exactly what is being sent.
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
    <FulfillItemsForm
      form={form}
      rows={rows}
      idPrefix={idPrefix}
      carrierOptions={carrierOptions}
      onSubmit={onSubmit}
      onCancel={onDone}
      pending={fulfill.isPending}
    />
  )
}
