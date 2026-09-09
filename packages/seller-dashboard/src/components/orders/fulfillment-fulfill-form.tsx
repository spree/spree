import { zodResolver } from '@hookform/resolvers/zod'
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
import type { Fulfillment, Order } from '@spree/seller-sdk'
import { useEffect, useRef } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../hooks/use-reasons'
import { type FulfillItemsFormValues, fulfillItemsFormSchema } from '../../schemas/fulfillment'

/**
 * Rows whose fulfillment item no longer maps to a line item are dropped: the
 * fulfill endpoint addresses items by line item, so there is nothing to send
 * for them. They still ship — selecting everything else sends no `items` at
 * all, which ships the whole parcel including them.
 */
function fulfillableRows(rows: FulfillmentItemRow[]): FulfillableRowData[] {
  return rows.flatMap((row) => (row.lineItem ? [{ ...row, itemId: row.lineItem.id }] : []))
}

/** What the seller sends out of one parcel. */
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
  // The parcel holds units, but none of them can be named by line item — the
  // only case where shipping with nothing picked is right. An empty parcel
  // has nothing to ship and stays unsubmittable.
  const canShipWholeParcel = rows.length === 0 && (fulfillment.fulfillment_items?.length ?? 0) > 0

  const form = useForm<FulfillItemsFormValues>({
    resolver: zodResolver(fulfillItemsFormSchema),
    defaultValues: {
      items: rows.map((row) => ({ item_id: row.itemId, selected: true, quantity: row.quantity })),
      tracking: fulfillment.tracking ?? '',
      // Detected from the number, or picked in the tracking dialog once the
      // parcel has one.
      tracking_carrier: '',
      notify_customer: true,
    },
  })

  // A refetch re-renders this form with fresh rows, so the values it mirrors
  // have to follow. The effect keys on the parcel's composition rather than on
  // the rows array, so a refetch returning the same units does not wipe what
  // the seller typed.
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
    // An omitted `items` ships the whole parcel, which is only right when
    // nothing was addressable. A partial pick that came out empty, or an
    // empty parcel, is a no-op worth refusing.
    if (items.length === 0 && !canShipWholeParcel) return

    const everything = items.reduce((sum, item) => sum + item.quantity, 0) === totalAvailable
    const tracking = values.tracking.trim()

    try {
      // Omitting `items` ships the whole parcel, avoiding a pointless split
      // when every unit was selected anyway.
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
      canShipWholeParcel={canShipWholeParcel}
      pending={fulfill.isPending}
    />
  )
}
