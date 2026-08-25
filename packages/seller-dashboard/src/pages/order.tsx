import {
  AddressBlock,
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Input,
  StatusBadge,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import type { Fulfillment } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

/** One order, as the seller needs it to pack and post the parcel. */
export function OrderPage() {
  const { t } = useTranslation()
  const { sellerId, orderId } = useParams({ from: '/_authenticated/$sellerId/orders/$orderId' })
  const queryClient = useQueryClient()
  const confirm = useConfirm()

  const orderKey = ['seller', sellerId, 'order', orderId]
  const { data: order, isLoading } = useQuery({
    queryKey: orderKey,
    queryFn: () => sellerClient().orders.get(orderId),
  })

  const cancel = useMutation({
    mutationFn: () => sellerClient().orders.cancel(orderId),
    onSuccess: (updated) => {
      queryClient.setQueryData(orderKey, updated)
      void queryClient.invalidateQueries({ queryKey: ['seller-orders'] })
      toastManager.add({ type: 'success', title: t('orders.canceled') })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (!order) return <CenteredMessage>{t('orders.not_found')}</CenteredMessage>

  async function handleCancel() {
    const ok = await confirm({
      title: t('orders.cancel_confirm.title'),
      message: t('orders.cancel_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('orders.cancel'),
    })
    if (!ok) return
    await cancel.mutateAsync().catch(() => undefined)
  }

  const cancelable = order.status !== 'canceled'

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="font-medium text-2xl">{order.number}</h1>
          <p className="text-muted-foreground text-sm">
            {order.completed_at ? new Date(order.completed_at).toLocaleString() : null}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
          {cancelable && (
            <Button variant="outline" disabled={cancel.isPending} onClick={handleCancel}>
              {t('orders.cancel')}
            </Button>
          )}
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('orders.items')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {order.items.map((item) => (
            <div key={item.id} className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{item.name}</div>
                <div className="truncate text-muted-foreground text-xs">
                  {[item.sku, item.options_text].filter(Boolean).join(' · ')}
                </div>
              </div>
              <div className="flex shrink-0 items-center gap-4 text-sm">
                <span className="text-muted-foreground">× {item.quantity}</span>
                <span>{item.display_total as string}</span>
              </div>
            </div>
          ))}
        </CardContent>
      </Card>

      {order.fulfillments.map((fulfillment) => (
        <FulfillmentCard key={fulfillment.id} orderId={orderId} fulfillment={fulfillment} />
      ))}

      {order.shipping_address && (
        <Card>
          <CardHeader>
            <CardTitle>{t('orders.shipping_address')}</CardTitle>
          </CardHeader>
          <CardContent>
            <AddressBlock address={order.shipping_address} />
          </CardContent>
        </Card>
      )}
    </div>
  )
}

/**
 * One parcel. Shipping it is the seller's own action, so the tracking number
 * is entered here rather than on a separate screen — it is the thing they
 * have in hand when they come to mark it sent.
 */
function FulfillmentCard({ orderId, fulfillment }: { orderId: string; fulfillment: Fulfillment }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [tracking, setTracking] = useState('')

  const fulfill = useMutation({
    mutationFn: () =>
      sellerClient().orders.fulfillments.fulfill(orderId, fulfillment.id, {
        tracking: tracking.trim() || undefined,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'order', orderId] })
      void queryClient.invalidateQueries({ queryKey: ['seller-orders'] })
      toastManager.add({ type: 'success', title: t('orders.fulfilled') })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const shipped = fulfillment.status !== 'unfulfilled'

  return (
    <Card>
      <CardHeader>
        <CardTitle>{fulfillment.number}</CardTitle>
        <CardAction>
          <Badge variant={shipped ? 'success' : 'secondary'}>{fulfillment.status}</Badge>
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {fulfillment.stock_location_name && (
          <p className="text-muted-foreground text-sm">
            {t('orders.ships_from', { name: fulfillment.stock_location_name })}
          </p>
        )}

        {fulfillment.fulfillment_items?.map((item) => (
          <div key={item.id} className="flex items-center justify-between gap-3 text-sm">
            <span className="truncate">{item.name}</span>
            <span className="text-muted-foreground">× {item.quantity}</span>
          </div>
        ))}

        {shipped ? (
          fulfillment.tracking && (
            <p className="text-sm">{t('orders.tracking', { number: fulfillment.tracking })}</p>
          )
        ) : (
          <div className="flex items-end gap-2">
            <Field className="flex-1">
              <FieldLabel htmlFor={`tracking-${fulfillment.id}`}>
                {t('orders.tracking_label')}
              </FieldLabel>
              <Input
                id={`tracking-${fulfillment.id}`}
                value={tracking}
                placeholder={t('orders.tracking_placeholder')}
                onChange={(event) => setTracking(event.target.value)}
              />
            </Field>
            <Button disabled={fulfill.isPending} onClick={() => fulfill.mutate()}>
              {fulfill.isPending ? t('orders.fulfilling') : t('orders.fulfill')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
