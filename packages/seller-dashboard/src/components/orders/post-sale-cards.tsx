import { currencyParts } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  ClaimResolveDialog,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  ArrowLeftRightIcon,
  BanIcon,
  EllipsisVerticalIcon,
  PlusIcon,
  ShieldAlertIcon,
} from '@spree/dashboard-ui/icons'
import type { Claim, Order } from '@spree/seller-sdk'
import i18n from 'i18next'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useClaimActions,
  useExchangeActions,
  useOrderClaims,
  useOrderExchanges,
} from '../../hooks/use-post-sale'
import { lineLabel } from './line-label'
import { CreateClaimDialog } from './post-sale-create-dialogs'

const EXCHANGE_ACTIONABLE = ['requested', 'approved', 'received']
const CLAIM_ACTIONABLE = ['open', 'approved']

/**
 * Goods swapped for different ones.
 *
 * Read plus the status moves; opening one needs a replacement variant picker,
 * which the seller's own catalogue search will bring — until then an exchange
 * is opened by the operator or the customer and worked here.
 */
export function ExchangesCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderExchanges(order.id)
  const { approve, receive, fulfill, cancel } = useExchangeActions(order.id)

  const exchanges = data?.data ?? []
  if (exchanges.length === 0) return null

  async function handleCancel(id: string) {
    const ok = await confirm({
      title: t('orders.post_sale.exchanges.cancel_title'),
      message: t('orders.post_sale.exchanges.cancel_message'),
      variant: 'destructive',
      confirmLabel: t('orders.post_sale.cancel'),
    })
    if (!ok) return
    cancel.mutate(id)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <ArrowLeftRightIcon className="size-4" />
          {t('orders.post_sale.exchanges.title')}
        </CardTitle>
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        {exchanges.map((exchange) => (
          <Card key={exchange.id} variant="nested">
            <CardHeader>
              <CardTitle className="text-sm font-medium">{exchange.number}</CardTitle>
              <CardAction className="flex items-center gap-2">
                <StatusBadge
                  status={exchange.status}
                  label={t(`orders.post_sale.statuses.${exchange.status}`, {
                    defaultValue: exchange.status,
                  })}
                />
                {EXCHANGE_ACTIONABLE.includes(exchange.status) && (
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon-xs">
                        <EllipsisVerticalIcon className="size-4" />
                        <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      {exchange.status === 'requested' && (
                        <DropdownMenuItem onClick={() => approve.mutate(exchange.id)}>
                          {t('orders.post_sale.approve')}
                        </DropdownMenuItem>
                      )}
                      {exchange.status === 'approved' && (
                        <DropdownMenuItem
                          onClick={() => receive.mutate({ exchangeId: exchange.id })}
                        >
                          {t('orders.post_sale.exchanges.receive')}
                        </DropdownMenuItem>
                      )}
                      {exchange.status === 'received' && (
                        <DropdownMenuItem
                          onClick={() => fulfill.mutate({ exchangeId: exchange.id })}
                        >
                          {t('orders.post_sale.exchanges.fulfill')}
                        </DropdownMenuItem>
                      )}
                      <DropdownMenuSeparator />
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => handleCancel(exchange.id)}
                      >
                        {t('orders.post_sale.cancel')}
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                )}
              </CardAction>
            </CardHeader>

            <CardContent className="flex flex-col gap-1.5">
              {exchange.exchange_line_items?.map((line) => (
                <div key={line.id} className="flex items-center justify-between gap-3 text-sm">
                  <span className="truncate">
                    {lineLabel(line.name, line.original_variant, line.original_variant_id)} →{' '}
                    {lineLabel(line.new_variant_name, line.new_variant, line.new_variant_id)}
                  </span>
                  <span className="shrink-0 text-muted-foreground">× {line.quantity}</span>
                </div>
              ))}
              <p className="text-muted-foreground text-sm">
                {t('orders.post_sale.exchanges.price_difference', {
                  amount: exchange.display_price_difference,
                })}
              </p>
            </CardContent>
          </Card>
        ))}
      </CardContent>
    </Card>
  )
}

/** Something went wrong with a delivery, and the seller puts it right. */
export function ClaimsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderClaims(order.id)
  const { approve, deny, cancel } = useClaimActions(order.id)

  const [createOpen, setCreateOpen] = useState(false)
  const [resolving, setResolving] = useState<Claim | null>(null)

  const claims = data?.data ?? []
  const canCreate = (order.items ?? []).length > 0

  async function handleCancel(id: string) {
    const ok = await confirm({
      title: t('orders.post_sale.claims.cancel_title'),
      message: t('orders.post_sale.claims.cancel_message'),
      variant: 'destructive',
      confirmLabel: t('orders.post_sale.cancel'),
    })
    if (!ok) return
    cancel.mutate(id)
  }

  async function handleDeny(id: string) {
    const ok = await confirm({
      title: t('orders.post_sale.claims.deny_title'),
      message: t('orders.post_sale.claims.deny_message'),
      variant: 'destructive',
      confirmLabel: t('orders.post_sale.claims.deny'),
    })
    if (!ok) return
    deny.mutate(id)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <ShieldAlertIcon className="size-4" />
          {t('orders.post_sale.claims.title')}
        </CardTitle>
        {canCreate && (
          <CardAction>
            <Button variant="outline" size="sm" onClick={() => setCreateOpen(true)}>
              <PlusIcon className="size-4" />
              {t('orders.post_sale.claims.create')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        {claims.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('orders.post_sale.claims.empty')}</p>
        ) : (
          claims.map((claim) => (
            <Card key={claim.id} variant="nested">
              <CardHeader>
                <CardTitle className="text-sm font-medium">{claim.number}</CardTitle>
                <CardAction className="flex items-center gap-2">
                  <StatusBadge
                    status={claim.status}
                    label={t(`orders.post_sale.statuses.${claim.status}`, {
                      defaultValue: claim.status,
                    })}
                  />
                  {CLAIM_ACTIONABLE.includes(claim.status) && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon-xs">
                          <EllipsisVerticalIcon className="size-4" />
                          <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        {claim.status === 'open' && (
                          <DropdownMenuItem onClick={() => approve.mutate(claim.id)}>
                            {t('orders.post_sale.approve')}
                          </DropdownMenuItem>
                        )}
                        {claim.status === 'approved' && (
                          <DropdownMenuItem onClick={() => setResolving(claim)}>
                            {t('orders.post_sale.claims.resolve')}
                          </DropdownMenuItem>
                        )}
                        <DropdownMenuItem onClick={() => handleDeny(claim.id)}>
                          <BanIcon className="size-4" />
                          {t('orders.post_sale.claims.deny')}
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          variant="destructive"
                          onClick={() => handleCancel(claim.id)}
                        >
                          {t('orders.post_sale.cancel')}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </CardAction>
              </CardHeader>

              <CardContent className="flex flex-col gap-1.5">
                {claim.claim_line_items?.map((line) => (
                  <div key={line.id} className="flex items-center justify-between gap-3 text-sm">
                    <span className="min-w-0 truncate">
                      {lineLabel(line.name, line.variant, line.variant_id)}
                      {line.description && (
                        <span className="text-muted-foreground"> — {line.description}</span>
                      )}
                    </span>
                    <span className="shrink-0 text-muted-foreground">× {line.quantity}</span>
                  </div>
                ))}
              </CardContent>
            </Card>
          ))
        )}
      </CardContent>

      <CreateClaimDialog order={order} open={createOpen} onOpenChange={setCreateOpen} />
      {resolving && (
        <ResolveClaimDialog
          orderId={order.id}
          order={order}
          claim={resolving}
          onOpenChange={() => setResolving(null)}
        />
      )}
    </Card>
  )
}

/** Money back, a replacement, or both. */

/**
 * How the seller puts a delivery right: money back, a replacement, or both.
 *
 * The currency is the order's — a seller has none of their own.
 */
function ResolveClaimDialog({
  orderId,
  order,
  claim,
  onOpenChange,
}: {
  orderId: string
  order: Order
  claim: Claim
  onOpenChange: (open: boolean) => void
}) {
  const { resolve } = useClaimActions(orderId)
  const lines = claim.claim_line_items ?? []
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  // A claim opened without per-item amounts has a refund_total of zero, and
  // the workflow refuses to refund nothing — offer what the customer paid for
  // the claimed items instead, which is also the ceiling it enforces.
  const recorded = Number(claim.refund_total)
  const paid = lines.reduce((sum, line) => sum + Number(line.paid_amount ?? 0), 0)
  const defaultAmount =
    Number.isFinite(recorded) && recorded > 0
      ? claim.refund_total
      : paid > 0
        ? paid.toFixed(2)
        : claim.refund_total

  return (
    <ClaimResolveDialog
      lines={lines.map((line) => ({
        id: line.id,
        label: lineLabel(line.name, line.variant, line.variant_id),
        quantity: line.quantity,
        sendReplacement: line.send_replacement,
      }))}
      defaultAmount={defaultAmount}
      currencySymbol={currencySymbol}
      onClose={() => onOpenChange(false)}
      pending={resolve.isPending}
      onSubmit={({ resolution, refundMethod, amount, replacementLineItemIds }) => {
        resolve
          .mutateAsync({
            claimId: claim.id,
            resolution,
            refundMethod,
            amount,
            replacementLineItemIds,
          })
          .then(() => onOpenChange(false))
          .catch(() => undefined)
      }}
    />
  )
}
