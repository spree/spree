import {
  Alert,
  AlertDescription,
  Button,
  Checkbox,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useFulfillmentActions } from '../../hooks/use-fulfillments'
import { useTrackingCarriers } from '../../hooks/use-reasons'

type Row = { itemId: string; label: string; available: number; quantity: number }

function initialRows(fulfillment: Fulfillment): Row[] {
  return (fulfillment.fulfillment_items ?? []).map((item) => ({
    // The server addresses what to ship by line item, not by fulfillment item.
    itemId: item.line_item_id ?? item.id,
    label: [item.name, item.options_text].filter(Boolean).join(' — ') || item.id,
    available: item.quantity,
    quantity: item.quantity,
  }))
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

  const [rows, setRows] = useState<Row[]>(() => initialRows(fulfillment))
  const [tracking, setTracking] = useState('')
  const [carrier, setCarrier] = useState('')
  const [notifyCustomer, setNotifyCustomer] = useState(true)

  const carrierOptions = [
    { value: '', label: t('orders.fulfillments.carrier_auto') },
    ...(carriersData?.data ?? []).map((option) => ({ value: option.id, label: option.name })),
  ]

  const selectedUnits = rows.reduce((total, row) => total + row.quantity, 0)
  const totalUnits = rows.reduce((total, row) => total + row.available, 0)
  const partial = selectedUnits > 0 && selectedUnits < totalUnits

  function setQuantity(itemId: string, quantity: number) {
    setRows((current) =>
      current.map((row) =>
        row.itemId === itemId
          ? { ...row, quantity: Math.max(0, Math.min(row.available, quantity)) }
          : row,
      ),
    )
  }

  async function handleShip() {
    await fulfill
      .mutateAsync({
        fulfillmentId: fulfillment.id,
        tracking: tracking.trim() || undefined,
        tracking_carrier: carrier || undefined,
        notify_customer: notifyCustomer,
        // Omitted entirely when everything is going, so the server ships the
        // parcel as it stands rather than splitting it against itself.
        items: partial
          ? rows
              .filter((row) => row.quantity > 0)
              .map((row) => ({ item_id: row.itemId, quantity: row.quantity }))
          : undefined,
      })
      .then(onDone)
      .catch(() => undefined)
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        {rows.map((row) => (
          <div key={row.itemId} className="flex items-center justify-between gap-3">
            <label
              className="flex min-w-0 items-center gap-2 text-sm"
              htmlFor={`ship-${row.itemId}`}
            >
              <Checkbox
                id={`ship-${row.itemId}`}
                checked={row.quantity > 0}
                onCheckedChange={(checked) => setQuantity(row.itemId, checked ? row.available : 0)}
              />
              <span className="truncate">{row.label}</span>
            </label>
            <Input
              type="number"
              min={0}
              max={row.available}
              value={row.quantity}
              className="w-20"
              aria-label={t('orders.fulfillments.quantity_for', { name: row.label })}
              onChange={(event) => setQuantity(row.itemId, Number(event.target.value))}
            />
          </div>
        ))}
      </div>

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
            value={tracking}
            placeholder={t('orders.tracking_placeholder')}
            onChange={(event) => setTracking(event.target.value)}
          />
        </Field>

        <Field>
          <FieldLabel htmlFor={`fulfill-carrier-${fulfillment.id}`}>
            {t('orders.fulfillments.carrier_label')}
          </FieldLabel>
          <Select
            items={carrierOptions}
            value={carrier}
            onValueChange={(value) => setCarrier((value as string) ?? '')}
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
        </Field>
      </div>

      <label className="flex items-center gap-2 text-sm" htmlFor={`notify-${fulfillment.id}`}>
        <Checkbox
          id={`notify-${fulfillment.id}`}
          checked={notifyCustomer}
          onCheckedChange={(checked) => setNotifyCustomer(!!checked)}
        />
        {t('orders.fulfillments.notify_customer')}
      </label>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button
          type="button"
          disabled={fulfill.isPending || selectedUnits === 0}
          onClick={handleShip}
        >
          {fulfill.isPending ? t('orders.fulfilling') : t('orders.fulfill')}
        </Button>
      </div>
    </div>
  )
}
