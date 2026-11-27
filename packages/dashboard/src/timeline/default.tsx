import type { Order, OrderChange, OrderChangeAction } from '@spree/admin-sdk'
import {
  type ActivityKind,
  type ActivityProps,
  activityRegistry,
  Can,
  formatAmount,
  Subject,
  useAuth,
  useMoneyLocale,
} from '@spree/dashboard-core'
import { Button, useConfirm } from '@spree/dashboard-ui'
import {
  BanIcon,
  CircleCheckIcon,
  CreditCardIcon,
  MessageSquareIcon,
  PackageCheckIcon,
  PencilIcon,
  RotateCcwIcon,
  ShoppingCartIcon,
  TruckIcon,
} from '@spree/dashboard-ui/icons'
import type { TFunction } from 'i18next'
import type { ComponentType } from 'react'
import { useTranslation } from 'react-i18next'
import { useDeleteOrderComment } from '../hooks/use-order'
import { variantLabel } from '../lib/variant-label'

/**
 * The timeline entries Spree records itself. Each sentence comes from
 * `admin.orders.detail.timeline.kinds.<kind>`, filled from the entry's details.
 */

function detail(activity: ActivityProps['activity'], key: string): string {
  const value = activity.details?.[key]
  return value == null ? '' : String(value)
}

function KindSummary({ activity, order }: ActivityProps) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const money = (key: string) => {
    const value = detail(activity, key)
    return value ? formatAmount(value, order.currency, moneyLocale) : ''
  }
  const brand = detail(activity, 'brand')
  const last4 = detail(activity, 'last4')
  const method = last4 ? `${brand} •••• ${last4}`.trim() : detail(activity, 'payment_method')
  const sentence = t(`admin.orders.detail.timeline.kinds.${activity.kind.replace('.', '_')}`, {
    amount: money('amount'),
    total: money('total'),
    number: detail(activity, 'number'),
    defaultValue: activity.kind,
  })

  return <>{[sentence, method, detail(activity, 'tracking')].filter(Boolean).join(' · ')}</>
}

function CommentSummary({ activity }: ActivityProps) {
  return <span className="whitespace-pre-wrap">{activity.body}</span>
}

/** Its author can delete a comment; no other entry can be removed. */
function CommentDetails({ activity, order }: ActivityProps) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const confirm = useConfirm()
  const deleteComment = useDeleteOrderComment(order.id)
  if (!user || activity.actor_id !== user.id) return null

  async function handleDelete() {
    const confirmed = await confirm({
      message: t('admin.orders.detail.timeline.delete_comment_confirm'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (confirmed) deleteComment.mutate(activity.id)
  }

  return (
    <Can I="update" a={Subject.Order}>
      <Button
        variant="ghost"
        size="sm"
        className="self-start"
        disabled={deleteComment.isPending}
        onClick={handleDelete}
      >
        {t('admin.orders.detail.timeline.delete_comment')}
      </Button>
    </Can>
  )
}

/** What a change does, line by line. */
export function OrderChangeActions({ change, order }: { change: OrderChange; order: Order }) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()

  return (
    <ul className="flex flex-col gap-0.5 text-muted-foreground">
      {change.actions.map((action) => (
        <li key={action.id}>{describeAction(action, order.currency, moneyLocale, t)}</li>
      ))}
    </ul>
  )
}

/** What an order change did, line by line, and how it moved the total. */
function OrderChangeDetails({ activity, order }: ActivityProps) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const change = activity.order_change
  if (!change) return null

  return (
    <div className="flex flex-col gap-0.5 text-muted-foreground">
      <OrderChangeActions change={change} order={order} />
      {change.previous_total && change.new_total && change.previous_total !== change.new_total && (
        <p>
          {t('admin.orders.detail.timeline.total_moved', {
            previous: formatAmount(change.previous_total, order.currency, moneyLocale),
            next: formatAmount(change.new_total, order.currency, moneyLocale),
          })}
        </p>
      )}
    </div>
  )
}

function PaymentDetails({ activity }: ActivityProps) {
  const { t } = useTranslation()
  const transactionId = detail(activity, 'transaction_id')
  if (!transactionId) return null

  return (
    <p className="text-muted-foreground">
      {t('admin.orders.detail.timeline.transaction', { id: transactionId })}
    </p>
  )
}

function describeAction(
  action: OrderChangeAction,
  currency: string,
  moneyLocale: string,
  t: TFunction,
): string {
  const name =
    variantLabel(action.variant, null) || t('admin.orders.detail.order_changes.unknown_item')
  const value =
    action.value_type === 'percent'
      ? `${action.value}%`
      : formatAmount(action.value, currency, moneyLocale)

  // A discount edit can rename it, re-amount it, or both.
  const kind =
    action.kind === 'update_discount'
      ? action.label && action.amount
        ? 'update_discount'
        : action.label
          ? 'update_discount_label'
          : 'update_discount_amount'
      : action.kind

  return t(`admin.orders.detail.order_changes.actions.${kind}`, {
    name,
    quantity: action.quantity,
    label: action.label ?? '',
    value,
    amount: formatAmount(action.amount, currency, moneyLocale),
    // An extension's own kind has no copy here, so it is named as sent.
    defaultValue: action.kind,
  })
}

function group(
  icon: ComponentType<{ className?: string }>,
  names: string[],
  Details?: ActivityKind['Details'],
): ActivityKind[] {
  return names.map((kind) => ({ kind, icon, Summary: KindSummary, Details }))
}

const kinds: ActivityKind[] = [
  { kind: 'comment', icon: MessageSquareIcon, Summary: CommentSummary, Details: CommentDetails },
  ...group(ShoppingCartIcon, ['order.placed']),
  ...group(CircleCheckIcon, ['order.approved']),
  ...group(BanIcon, ['order.canceled']),
  ...group(
    CreditCardIcon,
    ['payment.completed', 'payment.capture_failed', 'payment.voided', 'payment.void_failed'],
    PaymentDetails,
  ),
  ...group(
    RotateCcwIcon,
    ['payment.refunded', 'refund.requested', 'refund.failed'],
    PaymentDetails,
  ),
  ...group(TruckIcon, ['fulfillment.fulfilled', 'fulfillment.canceled']),
  ...group(PackageCheckIcon, ['fulfillment.delivered']),
  ...group(
    PencilIcon,
    ['order_change.requested', 'order_change.confirmed', 'order_change.canceled'],
    OrderChangeDetails,
  ),
  ...group(
    RotateCcwIcon,
    [
      'return.requested',
      'return.approved',
      'return.received',
      'return.refunded',
      'return.canceled',
      'exchange.requested',
      'exchange.approved',
      'exchange.received',
      'exchange.fulfilled',
      'exchange.canceled',
      'claim.opened',
      'claim.approved',
      'claim.resolved',
      'claim.denied',
      'claim.canceled',
    ],
    OrderChangeDetails,
  ),
]

for (const kind of kinds) activityRegistry.register(kind)
