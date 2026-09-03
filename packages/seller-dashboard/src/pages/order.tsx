import { PageHeader } from '@spree/dashboard-core'
import {
  DropdownMenuItem,
  ResourceLayout,
  StatusBadge,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { FulfillmentsCard } from '../components/orders/fulfillments-card'
import {
  OrderCustomerCard,
  OrderItemsCard,
  OrderNoteCard,
  OrderSummaryCard,
} from '../components/orders/order-cards'
import { ClaimsCard, ExchangesCard } from '../components/orders/post-sale-cards'
import { ReturnsCard } from '../components/orders/returns-card'
import { RetryableError } from '../components/retryable-error'
import { useOrder, useOrderMutation } from '../hooks/use-order'

/**
 * One order, as the seller needs it to pack, post, and put right.
 *
 * Laid out like the operator's order page — parcels and post-sale on the
 * left, who and what on the right — minus the marketplace's own surfaces:
 * the payment the customer made, the tax and discount breakdown, and the
 * operator's bookkeeping all belong to whoever runs the marketplace.
 */
export function OrderPage() {
  const { t } = useTranslation()
  const { orderId } = useParams({ from: '/_authenticated/$sellerId/orders/$orderId' })
  const confirm = useConfirm()

  const { data: order, isLoading, isError, refetch } = useOrder(orderId)

  const cancel = useOrderMutation(orderId, () => sellerClient().orders.cancel(orderId))

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (isError) return <RetryableError onRetry={() => refetch()} />
  if (!order) return <CenteredMessage>{t('orders.not_found')}</CenteredMessage>

  async function handleCancel() {
    const ok = await confirm({
      title: t('orders.cancel_confirm.title'),
      message: t('orders.cancel_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('orders.cancel'),
    })
    if (!ok) return

    await cancel
      .mutateAsync(undefined)
      .then(() => toastManager.add({ type: 'success', title: t('orders.canceled') }))
      .catch(() => undefined)
  }

  const cancelable = order.status !== 'canceled'
  // Nothing can come back from an order that never went out, so the post-sale
  // cards would only render empty with a disabled button.
  const placed = !!order.completed_at

  return (
    <ResourceLayout
      header={
        // Cancel sits in the menu's destructive group rather than beside the
        // title: it is easy to hit by mistake there, and this is where the
        // operator dashboard puts the same action.
        <PageHeader
          title={order.number}
          backTo="orders"
          subtitle={order.completed_at ? new Date(order.completed_at).toLocaleString() : undefined}
          badges={
            <>
              {order.fulfillment_status && (
                <StatusBadge
                  status={order.fulfillment_status}
                  label={t(`orders.fulfillment_statuses.${order.fulfillment_status}`)}
                />
              )}
              {order.payment_status && (
                <StatusBadge
                  status={order.payment_status}
                  label={t(`orders.payment_statuses.${order.payment_status}`)}
                />
              )}
            </>
          }
          resource={{ id: order.id, number: order.number }}
          destructiveItems={
            cancelable ? (
              <DropdownMenuItem
                variant="destructive"
                disabled={cancel.isPending}
                onClick={handleCancel}
              >
                {t('orders.cancel')}
              </DropdownMenuItem>
            ) : undefined
          }
        />
      }
      main={
        <>
          <FulfillmentsCard order={order} />
          {placed && (
            <>
              <ReturnsCard order={order} />
              <ExchangesCard order={order} />
              <ClaimsCard order={order} />
            </>
          )}
          <OrderItemsCard order={order} />
          <OrderSummaryCard order={order} />
        </>
      }
      sidebar={
        <>
          <OrderCustomerCard order={order} />
          <OrderNoteCard order={order} />
        </>
      }
    />
  )
}
