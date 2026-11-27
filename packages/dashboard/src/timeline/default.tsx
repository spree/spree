import type { OrderChangeAction } from '@spree/admin-sdk'
import {
  type ActivityKind,
  type ActivityProps,
  activityRegistry,
  formatAmount,
  useMoneyLocale,
} from '@spree/dashboard-core'
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
import { useTranslation } from 'react-i18next'
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
  const lastDigits = detail(activity, 'last_digits')
  const method = lastDigits
    ? `${brand} •••• ${lastDigits}`.trim()
    : detail(activity, 'payment_method')
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

/** What an order change did, line by line, and how it moved the total. */
function OrderChangeDetails({ activity, order }: ActivityProps) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const change = activity.order_change
  if (!change) return null

  return (
    <div className="flex flex-col gap-0.5 text-muted-foreground">
      <ul className="flex flex-col gap-0.5">
        {change.actions.map((action) => (
          <li key={action.id}>{describeAction(action, order.currency, moneyLocale, t)}</li>
        ))}
      </ul>
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

export function describeAction(
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

const kinds: ActivityKind[] = [
  { kind: 'comment', icon: MessageSquareIcon, Summary: CommentSummary },
  { kind: 'order.placed', icon: ShoppingCartIcon, Summary: KindSummary },
  { kind: 'order.approved', icon: CircleCheckIcon, Summary: KindSummary },
  { kind: 'order.canceled', icon: BanIcon, Summary: KindSummary },
  ...['payment.completed', 'payment.capture_failed', 'payment.voided', 'payment.void_failed'].map(
    (kind) => ({ kind, icon: CreditCardIcon, Summary: KindSummary, Details: PaymentDetails }),
  ),
  ...['refund.created', 'refund.failed'].map((kind) => ({
    kind,
    icon: RotateCcwIcon,
    Summary: KindSummary,
    Details: PaymentDetails,
  })),
  ...['fulfillment.fulfilled', 'fulfillment.canceled'].map((kind) => ({
    kind,
    icon: TruckIcon,
    Summary: KindSummary,
  })),
  { kind: 'fulfillment.delivered', icon: PackageCheckIcon, Summary: KindSummary },
  ...['order_change.requested', 'order_change.confirmed', 'order_change.canceled'].map((kind) => ({
    kind,
    icon: PencilIcon,
    Summary: KindSummary,
    Details: OrderChangeDetails,
  })),
  ...[
    'return.requested',
    'return.received',
    'return.refunded',
    'return.canceled',
    'exchange.requested',
    'exchange.received',
    'exchange.fulfilled',
    'exchange.canceled',
    'claim.opened',
    'claim.resolved',
    'claim.denied',
    'claim.canceled',
  ].map((kind) => ({
    kind,
    icon: RotateCcwIcon,
    Summary: KindSummary,
    Details: OrderChangeDetails,
  })),
]

for (const kind of kinds) activityRegistry.register(kind)
