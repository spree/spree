import type { Claim, Exchange, Order } from '@spree/admin-sdk'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  BanIcon,
  BanknoteIcon,
  CheckCircleIcon,
  EllipsisVerticalIcon,
  PackageCheckIcon,
  PlusIcon,
  RepeatIcon,
  ShieldAlertIcon,
  TruckIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useClaimActions,
  useExchangeActions,
  useOrderClaims,
  useOrderExchanges,
} from '../../hooks/use-post-sale'
import {
  CreateClaimDialog,
  CreateExchangeDialog,
  fulfilledUnits,
  ResolveClaimDialog,
} from './post-sale-create-dialogs'

// Statuses that still offer an action. A terminal record would otherwise
// show a menu button that opens onto nothing.
const EXCHANGE_ACTIONABLE = ['requested', 'approved', 'received']
const CLAIM_ACTIONABLE = ['open', 'approved']

/** Exchanges on an order, with the actions available at each status. */
export function OrderExchangesCard({ order }: { order: Order }) {
  const orderId = order.id
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderExchanges(orderId)
  const { create, approve, receive, fulfill, cancel } = useExchangeActions(orderId)
  const [creating, setCreating] = useState(false)

  const exchanges = data?.data ?? []
  const canCreate = fulfilledUnits(order).length > 0

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <RepeatIcon className="size-4" />
            {t('admin.pages.orders.detail.section_exchanges')}
            {exchanges.length > 0 && <Badge variant="outline">{exchanges.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button
              variant="outline"
              size="sm"
              disabled={!canCreate}
              title={canCreate ? undefined : t('admin.pages.orders.detail.returns.empty_no_units')}
              onClick={() => setCreating(true)}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.orders.detail.exchanges.actions.create')}
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {exchanges.length === 0 && (
            <p className="text-sm text-muted-foreground">
              {canCreate
                ? t('admin.pages.orders.detail.exchanges.empty')
                : t('admin.pages.orders.detail.returns.empty_no_units')}
            </p>
          )}
          {exchanges.map((exchange: Exchange) => (
            <Card key={exchange.id} variant="nested">
              <CardHeader className="p-0 pb-3">
                <CardTitle className="text-sm font-medium">
                  <StatusBadge status={exchange.status} />
                  <span className="text-sm font-medium">{exchange.number}</span>
                </CardTitle>

                {EXCHANGE_ACTIONABLE.includes(exchange.status) && (
                  <CardAction>
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
                            <CheckCircleIcon className="size-4" />
                            {t('admin.pages.orders.detail.returns.actions.approve')}
                          </DropdownMenuItem>
                        )}
                        {exchange.status === 'approved' && (
                          <DropdownMenuItem
                            onClick={() => receive.mutate({ exchangeId: exchange.id })}
                          >
                            <PackageCheckIcon className="size-4" />
                            {t('admin.pages.orders.detail.returns.actions.receive')}
                          </DropdownMenuItem>
                        )}
                        {exchange.status === 'received' && (
                          <DropdownMenuItem
                            onClick={() => fulfill.mutate({ exchangeId: exchange.id })}
                          >
                            <TruckIcon className="size-4" />
                            {t('admin.pages.orders.detail.exchanges.actions.fulfill')}
                          </DropdownMenuItem>
                        )}
                        {['requested', 'approved'].includes(exchange.status) && (
                          <>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                              variant="destructive"
                              onClick={async () => {
                                if (
                                  await confirm({
                                    message: t('admin.pages.orders.detail.returns.confirm.cancel'),
                                    variant: 'destructive',
                                    confirmLabel: t('admin.actions.cancel'),
                                  })
                                ) {
                                  cancel.mutate({ exchangeId: exchange.id })
                                }
                              }}
                            >
                              <XCircleIcon className="size-4" />
                              {t('admin.actions.cancel')}
                            </DropdownMenuItem>
                          </>
                        )}
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </CardAction>
                )}
              </CardHeader>

              <CardContent className="flex flex-col gap-1.5">
                {(exchange.exchange_line_items ?? []).map((line) => (
                  <div key={line.id} className="flex items-center justify-between text-sm">
                    <span className="truncate">
                      {line.original_variant?.product_name ?? line.original_variant_id}
                      {' → '}
                      {line.new_variant?.options_text ||
                        line.new_variant?.sku ||
                        line.new_variant_id}
                    </span>
                    <span className="text-muted-foreground">×{line.quantity}</span>
                  </div>
                ))}
              </CardContent>

              <CardFooter className="justify-between text-sm">
                <span className="text-muted-foreground">
                  {t('admin.pages.orders.detail.exchanges.price_difference')}
                </span>
                <span className="font-medium">{exchange.display_price_difference}</span>
              </CardFooter>
            </Card>
          ))}
        </CardContent>
      </Card>

      {creating && (
        <CreateExchangeDialog
          order={order}
          onClose={() => setCreating(false)}
          onSubmit={(params) => {
            create.mutate(params)
            setCreating(false)
          }}
        />
      )}
    </>
  )
}

/** Claims on an order. Resolution is chosen at resolve time, not up front. */
export function OrderClaimsCard({ order }: { order: Order }) {
  const orderId = order.id
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { data } = useOrderClaims(orderId)
  const { create, approve, resolve, deny, cancel } = useClaimActions(orderId)
  const [creatingClaim, setCreatingClaim] = useState(false)
  const [resolving, setResolving] = useState<Claim | null>(null)

  const claims = data?.data ?? []
  // A claim is about ordered items, so it never depends on anything shipping.
  const canCreate = (order.items ?? []).length > 0

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <ShieldAlertIcon className="size-4" />
            {t('admin.pages.orders.detail.section_claims')}
            {claims.length > 0 && <Badge variant="outline">{claims.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button
              variant="outline"
              size="sm"
              disabled={!canCreate}
              onClick={() => setCreatingClaim(true)}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.orders.detail.claims.actions.create')}
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {claims.length === 0 && (
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.orders.detail.claims.empty')}
            </p>
          )}
          {claims.map((claim: Claim) => (
            <Card key={claim.id} variant="nested">
              <CardHeader className="p-0 pb-3">
                <CardTitle className="text-sm font-medium">
                  <StatusBadge status={claim.status} />
                  <span className="text-sm font-medium">{claim.number}</span>
                </CardTitle>

                {CLAIM_ACTIONABLE.includes(claim.status) && (
                  <CardAction>
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
                            <CheckCircleIcon className="size-4" />
                            {t('admin.pages.orders.detail.returns.actions.approve')}
                          </DropdownMenuItem>
                        )}
                        {claim.status === 'approved' && (
                          <DropdownMenuItem onClick={() => setResolving(claim)}>
                            <BanknoteIcon className="size-4" />
                            {t('admin.pages.orders.detail.claims.actions.resolve')}
                          </DropdownMenuItem>
                        )}
                        {['open', 'approved'].includes(claim.status) && <DropdownMenuSeparator />}
                        {claim.status === 'open' && (
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t('admin.pages.orders.detail.claims.confirm.deny'),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.pages.orders.detail.claims.actions.deny'),
                                })
                              ) {
                                deny.mutate({ claimId: claim.id })
                              }
                            }}
                          >
                            <BanIcon className="size-4" />
                            {t('admin.pages.orders.detail.claims.actions.deny')}
                          </DropdownMenuItem>
                        )}
                        {['open', 'approved'].includes(claim.status) && (
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t('admin.pages.orders.detail.returns.confirm.cancel'),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.actions.cancel'),
                                })
                              ) {
                                cancel.mutate({ claimId: claim.id })
                              }
                            }}
                          >
                            <XCircleIcon className="size-4" />
                            {t('admin.actions.cancel')}
                          </DropdownMenuItem>
                        )}
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </CardAction>
                )}
              </CardHeader>

              <CardContent className="flex flex-col gap-1.5">
                {(claim.claim_line_items ?? []).map((line) => (
                  <div key={line.id} className="flex items-center justify-between text-sm">
                    <span className="truncate">
                      {line.variant?.product_name ?? line.variant_id}
                      {line.description && (
                        <span className="text-muted-foreground"> — {line.description}</span>
                      )}
                    </span>
                    <span className="text-muted-foreground">×{line.quantity}</span>
                  </div>
                ))}
              </CardContent>

              <CardFooter className="justify-between text-sm">
                <span className="text-muted-foreground">
                  {t('admin.pages.orders.detail.returns.refund_total')}
                </span>
                <span className="font-medium">{claim.display_refund_total}</span>
              </CardFooter>
            </Card>
          ))}
        </CardContent>
      </Card>

      {resolving && (
        <ResolveClaimDialog
          claim={resolving}
          onClose={() => setResolving(null)}
          onSubmit={({ resolution, refundMethod, amount, replacementLineItemIds }) => {
            resolve.mutate({
              claimId: resolving.id,
              resolution,
              refundMethod,
              amount,
              replacementLineItemIds,
            })
            setResolving(null)
          }}
        />
      )}

      {creatingClaim && (
        <CreateClaimDialog
          order={order}
          onClose={() => setCreatingClaim(false)}
          onSubmit={(params) => {
            create.mutate(params)
            setCreatingClaim(false)
          }}
        />
      )}
    </>
  )
}
