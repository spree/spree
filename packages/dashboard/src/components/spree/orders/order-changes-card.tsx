import type { Order, OrderChange, OrderChangeAction } from '@spree/admin-sdk'
import { formatAmount, useMoneyLocale } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  Pagination,
  RelativeTime,
  Section,
  SectionHeader,
  SectionTitle,
  StatusBadge,
} from '@spree/dashboard-ui'
import { HistoryIcon } from '@spree/dashboard-ui/icons'
import type { TFunction } from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderChanges } from '../../../hooks/use-order'
import { useOrderClaims, useOrderExchanges } from '../../../hooks/use-post-sale'
import { useOrderReturns } from '../../../hooks/use-returns'
import { variantLabel } from '../../../lib/variant-label'
import { ActorLabel } from '../actor-label'

/**
 * Every change made to a placed order since checkout, newest first: admin
 * edits, discounts, and the restocks and replacements of its returns,
 * exchanges and claims.
 */
export function OrderChangesCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useOrderChanges(order.id, page)
  const changes = data?.data ?? []

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <HistoryIcon />
          {t('admin.orders.detail.order_changes.title')}
        </SectionTitle>
      </SectionHeader>
      <Card>
        <CardContent className="p-0">
          {isLoading ? (
            <p className="p-3 text-muted-foreground text-base">{t('admin.common.loading')}</p>
          ) : changes.length === 0 ? (
            <p className="p-3 text-muted-foreground text-base">
              {t('admin.orders.detail.order_changes.empty')}
            </p>
          ) : (
            <ul className="divide-y">
              {changes.map((change) => (
                <OrderChangeRow key={change.id} change={change} order={order} />
              ))}
            </ul>
          )}
          {(data?.meta?.pages ?? 1) > 1 && data?.meta && (
            <Pagination inset meta={data.meta} onPageChange={setPage} />
          )}
        </CardContent>
      </Card>
    </Section>
  )
}

function OrderChangeRow({ change, order }: { change: OrderChange; order: Order }) {
  const { t } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const source = useChangeSource(change, order.id)

  return (
    <li className="flex flex-col gap-1.5 p-3 text-base">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-muted-foreground">
          <RelativeTime iso={change.confirmed_at ?? change.requested_at ?? change.created_at} />
          {change.requested_by && (
            <>
              {' · '}
              <ActorLabel actor={change.requested_by} />
            </>
          )}
          {source && ` · ${source}`}
        </span>
        <StatusBadge
          status={change.status}
          label={t(`admin.orders.detail.order_changes.statuses.${change.status}`, {
            defaultValue: change.status,
          })}
        />
      </div>
      <ul className="flex flex-col gap-0.5">
        {change.actions.map((action) => (
          <li key={action.id}>{describeAction(action, order.currency, moneyLocale, t)}</li>
        ))}
      </ul>
    </li>
  )
}

/** The return, exchange or claim that made the change, by its number. */
function useChangeSource(change: OrderChange, orderId: string): string | null {
  const { t } = useTranslation()
  const { data: returns } = useOrderReturns(change.return_id ? orderId : '')
  const { data: exchanges } = useOrderExchanges(change.exchange_id ? orderId : '')
  const { data: claims } = useOrderClaims(change.claim_id ? orderId : '')

  const find = (list: { id: string; number: string }[] | undefined, id: string | null) =>
    id ? (list?.find((record) => record.id === id)?.number ?? id) : null

  const returnNumber = find(returns?.data, change.return_id)
  if (returnNumber)
    return t('admin.orders.detail.order_changes.from_return', { number: returnNumber })
  const exchangeNumber = find(exchanges?.data, change.exchange_id)
  if (exchangeNumber) {
    return t('admin.orders.detail.order_changes.from_exchange', { number: exchangeNumber })
  }
  const claimNumber = find(claims?.data, change.claim_id)
  if (claimNumber) return t('admin.orders.detail.order_changes.from_claim', { number: claimNumber })
  return null
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
