import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
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
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useClaimActions,
  useExchangeActions,
  useOrderClaims,
  useOrderExchanges,
} from '../../hooks/use-post-sale'
import { CreateClaimDialog } from './post-sale-create-dialogs'

/**
 * How a variant reads on a post-sale line. A seller's variant serializer
 * carries the SKU and its option values, never a name — the name lives on the
 * product — so the label is built from what is actually there.
 */
function variantLabel(
  variant: { sku?: string | null; options_text?: string | null } | undefined,
  fallback: string | null | undefined,
): string {
  const parts = [variant?.sku, variant?.options_text].filter(Boolean)
  return parts.length > 0 ? parts.join(' · ') : (fallback ?? '')
}

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
        <CardTitle className="flex items-center gap-2">
          <ArrowLeftRightIcon className="size-4" />
          {t('orders.post_sale.exchanges.title')}
        </CardTitle>
      </CardHeader>

      <CardContent className="flex flex-col gap-3">
        {exchanges.map((exchange) => (
          <Card key={exchange.id} variant="nested">
            <CardHeader>
              <CardTitle className="text-sm">{exchange.number}</CardTitle>
              <CardAction className="flex items-center gap-2">
                <StatusBadge
                  status={exchange.status}
                  label={t(`orders.post_sale.statuses.${exchange.status}`, {
                    defaultValue: exchange.status,
                  })}
                />
                {EXCHANGE_ACTIONABLE.includes(exchange.status) && (
                  <DropdownMenu>
                    <DropdownMenuTrigger
                      render={
                        <Button variant="ghost" size="icon" aria-label={t('common.actions')}>
                          <EllipsisVerticalIcon className="size-4" />
                        </Button>
                      }
                    />
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

            <CardContent className="flex flex-col gap-2">
              {exchange.exchange_line_items?.map((line) => (
                <div key={line.id} className="flex items-center justify-between gap-3 text-sm">
                  <span className="truncate">
                    {variantLabel(line.original_variant, line.original_variant_id)} →{' '}
                    {variantLabel(line.new_variant, line.new_variant_id)}
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
        <CardTitle className="flex items-center gap-2">
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

      <CardContent className="flex flex-col gap-3">
        {claims.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('orders.post_sale.claims.empty')}</p>
        ) : (
          claims.map((claim) => (
            <Card key={claim.id} variant="nested">
              <CardHeader>
                <CardTitle className="text-sm">{claim.number}</CardTitle>
                <CardAction className="flex items-center gap-2">
                  <StatusBadge
                    status={claim.status}
                    label={t(`orders.post_sale.statuses.${claim.status}`, {
                      defaultValue: claim.status,
                    })}
                  />
                  {CLAIM_ACTIONABLE.includes(claim.status) && (
                    <DropdownMenu>
                      <DropdownMenuTrigger
                        render={
                          <Button variant="ghost" size="icon" aria-label={t('common.actions')}>
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        }
                      />
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
                          onClick={() => cancel.mutate(claim.id)}
                        >
                          {t('orders.post_sale.cancel')}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </CardAction>
              </CardHeader>

              <CardContent className="flex flex-col gap-2">
                {claim.claim_line_items?.map((line) => (
                  <div key={line.id} className="flex items-center justify-between gap-3 text-sm">
                    <span className="min-w-0 truncate">
                      {variantLabel(line.variant, line.variant_id)}
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
          claim={resolving}
          open
          onOpenChange={() => setResolving(null)}
        />
      )}
    </Card>
  )
}

/** Money back, a replacement, or both. */
function ResolveClaimDialog({
  orderId,
  claim,
  open,
  onOpenChange,
}: {
  orderId: string
  claim: Claim
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { resolve } = useClaimActions(orderId)

  const [resolution, setResolution] = useState<'refund' | 'replacement' | 'refund_and_replacement'>(
    'refund',
  )
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<'original_payment' | 'store_credit'>('store_credit')

  const resolutionOptions = [
    { value: 'refund', label: t('orders.post_sale.claims.resolutions.refund') },
    { value: 'replacement', label: t('orders.post_sale.claims.resolutions.replacement') },
    {
      value: 'refund_and_replacement',
      label: t('orders.post_sale.claims.resolutions.refund_and_replacement'),
    },
  ]
  const methodOptions = [
    { value: 'store_credit', label: t('orders.post_sale.returns.store_credit') },
    { value: 'original_payment', label: t('orders.post_sale.returns.original_payment') },
  ]

  const refunding = resolution.includes('refund')

  async function handleResolve() {
    await resolve
      .mutateAsync({
        claimId: claim.id,
        resolution,
        refundMethod: refunding ? method : undefined,
        amount: refunding && amount ? amount : undefined,
      })
      .then(() => onOpenChange(false))
      .catch(() => undefined)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('orders.post_sale.claims.resolve_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody>
          <div className="flex flex-col gap-4">
            <Field>
              <FieldLabel htmlFor="claim-resolution">
                {t('orders.post_sale.claims.resolution')}
              </FieldLabel>
              <Select
                items={resolutionOptions}
                value={resolution}
                onValueChange={(value) =>
                  setResolution(
                    (value as 'refund' | 'replacement' | 'refund_and_replacement') ?? 'refund',
                  )
                }
              >
                <SelectTrigger id="claim-resolution">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {resolutionOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>

            {refunding && (
              <>
                <Field>
                  <FieldLabel htmlFor="claim-amount">
                    {t('orders.post_sale.returns.amount')}
                  </FieldLabel>
                  <Input
                    id="claim-amount"
                    type="number"
                    step="0.01"
                    min={0}
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                  />
                </Field>

                <Field>
                  <FieldLabel htmlFor="claim-refund-method">
                    {t('orders.post_sale.returns.refund_method')}
                  </FieldLabel>
                  <Select
                    items={methodOptions}
                    value={method}
                    onValueChange={(value) =>
                      setMethod((value as 'original_payment' | 'store_credit') ?? 'store_credit')
                    }
                  >
                    <SelectTrigger id="claim-refund-method">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {methodOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
              </>
            )}
          </div>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={resolve.isPending} onClick={handleResolve}>
            {t('orders.post_sale.claims.resolve')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
