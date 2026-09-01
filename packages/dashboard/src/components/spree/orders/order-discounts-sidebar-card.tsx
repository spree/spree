import type { Order } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  Separator,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

export function DiscountsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const confirm = useConfirm()
  const [giftCardOpen, setGiftCardOpen] = useState(false)
  const [couponOpen, setCouponOpen] = useState(false)

  const removeGiftCardMutation = useOrderMutation(orderId, () =>
    adminClient.orders.giftCards.remove(orderId, order.gift_card?.id ?? ''),
  )
  const removeCouponMutation = useOrderMutation(orderId, () =>
    adminClient.orders.discountCodes.delete(orderId, order.coupon_code ?? ''),
  )
  const applyStoreCreditMutation = useOrderMutation(orderId, () =>
    adminClient.orders.storeCredits.apply(orderId),
  )
  const removeStoreCreditMutation = useOrderMutation(orderId, () =>
    adminClient.orders.storeCredits.remove(orderId),
  )

  const hasStoreCredit = Number.parseFloat(order.store_credit_total) > 0
  const hasCustomer = Boolean(order.customer_id)
  const isEditable = !order.completed_at
  const couponPending = Boolean(order.coupon_code) && Number.parseFloat(order.discount_total) === 0

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.orders.detail.gift_card_section.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {/* Discount code — editable on drafts; frozen after completion */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-col">
              <span className="text-sm font-medium">
                {t('admin.orders.detail.discount_section.label')}
              </span>
              {order.coupon_code ? (
                <span className="font-mono text-xs text-muted-foreground">
                  {order.coupon_code}
                  {couponPending && ` · ${t('admin.orders.detail.discount_section.pending_hint')}`}
                </span>
              ) : (
                <span className="text-xs text-muted-foreground">
                  {t('admin.orders.detail.gift_card_section.none_applied')}
                </span>
              )}
            </div>
            {isEditable &&
              (order.coupon_code ? (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={async () => {
                    if (
                      await confirm({
                        message: t('admin.orders.detail.discount_section.remove_confirm_message'),
                        confirmLabel: t('admin.actions.remove'),
                      })
                    ) {
                      removeCouponMutation.mutate(undefined)
                    }
                  }}
                  disabled={removeCouponMutation.isPending}
                >
                  {t('admin.actions.remove')}
                </Button>
              ) : (
                <Button size="sm" variant="outline" onClick={() => setCouponOpen(true)}>
                  <PlusIcon className="size-4" />
                  {t('admin.actions.apply')}
                </Button>
              ))}
          </div>

          <Separator />

          {/* Gift card */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-col">
              <span className="text-sm font-medium">
                {t('admin.orders.detail.gift_card_section.gift_card_label')}
              </span>
              {order.gift_card ? (
                <span className="text-xs text-muted-foreground">
                  {order.gift_card.code} · {order.display_gift_card_total}
                </span>
              ) : (
                <span className="text-xs text-muted-foreground">
                  {t('admin.orders.detail.gift_card_section.none_applied')}
                </span>
              )}
            </div>
            {order.gift_card ? (
              <Button
                size="sm"
                variant="outline"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.remove_gift_card_message'),
                      confirmLabel: t('admin.actions.remove'),
                    })
                  ) {
                    removeGiftCardMutation.mutate(undefined)
                  }
                }}
                disabled={removeGiftCardMutation.isPending}
              >
                {t('admin.actions.remove')}
              </Button>
            ) : (
              <Button size="sm" variant="outline" onClick={() => setGiftCardOpen(true)}>
                <PlusIcon className="size-4" />
                {t('admin.actions.apply')}
              </Button>
            )}
          </div>

          <Separator />

          {/* Store credit */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-col">
              <span className="text-sm font-medium">
                {t('admin.orders.detail.gift_card_section.store_credit_label')}
              </span>
              {hasStoreCredit ? (
                <span className="text-xs text-muted-foreground">
                  {order.display_store_credit_total}{' '}
                  {t('admin.orders.detail.gift_card_section.applied_suffix')}
                </span>
              ) : (
                <span className="text-xs text-muted-foreground">
                  {hasCustomer
                    ? t('admin.orders.detail.gift_card_section.apply_balance')
                    : t('admin.orders.detail.gift_card_section.requires_customer')}
                </span>
              )}
            </div>
            {hasStoreCredit ? (
              <Button
                size="sm"
                variant="outline"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.remove_store_credit_message'),
                      confirmLabel: t('admin.actions.remove'),
                    })
                  ) {
                    removeStoreCreditMutation.mutate(undefined)
                  }
                }}
                disabled={removeStoreCreditMutation.isPending}
              >
                {t('admin.actions.remove')}
              </Button>
            ) : (
              <Button
                size="sm"
                variant="outline"
                disabled={!hasCustomer || applyStoreCreditMutation.isPending}
                onClick={() => applyStoreCreditMutation.mutate(undefined)}
              >
                <PlusIcon className="size-4" />
                {t('admin.actions.apply')}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      <ApplyGiftCardDialog orderId={orderId} open={giftCardOpen} onOpenChange={setGiftCardOpen} />
      <CouponCodeDialog orderId={orderId} open={couponOpen} onOpenChange={setCouponOpen} />
    </>
  )
}

function CouponCodeDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const [code, setCode] = useState('')

  const promotionsQuery = useQuery({
    queryKey: useResourceKey('promotions', 'coupon-options'),
    queryFn: () => adminClient.promotions.list({ q: { kind_eq: 'coupon_code' }, per_page: 100 }),
    enabled: open,
  })
  const couponPromotions = (promotionsQuery.data?.data ?? []).filter((promotion) => promotion.code)

  const mutation = useOrderMutation(orderId, (params: { code: string }) =>
    adminClient.orders.discountCodes.create(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const trimmed = code.trim()
    if (!trimmed) return
    mutation.mutate(
      { code: trimmed },
      {
        onSuccess: () => {
          setCode('')
          onOpenChange(false)
        },
      },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.discount_section.apply_dialog_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.discount_section.apply_dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="coupon-code">{t('admin.fields.code.label')}</FieldLabel>
                <Input
                  id="coupon-code"
                  name="code"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder={t('admin.orders.detail.discount_section.code_placeholder')}
                  required
                  autoFocus
                />
              </Field>
              {couponPromotions.length > 0 && (
                <Field>
                  <FieldLabel>
                    {t('admin.orders.detail.discount_section.promotions_label')}
                  </FieldLabel>
                  <div className="flex max-h-48 flex-col gap-1 overflow-y-auto">
                    {couponPromotions.map((promotion) => (
                      <button
                        type="button"
                        key={promotion.id}
                        onClick={() => setCode(promotion.code ?? '')}
                        className={cn(
                          'flex items-center justify-between rounded-md border px-3 py-2 text-left text-sm hover:bg-accent',
                          code === promotion.code && 'border-primary',
                        )}
                      >
                        <span className="truncate">{promotion.name}</span>
                        <span className="ml-2 shrink-0 font-mono text-xs text-muted-foreground">
                          {promotion.code}
                        </span>
                      </button>
                    ))}
                  </div>
                </Field>
              )}
              {mutation.isError && (
                <p className="text-sm text-destructive">{(mutation.error as Error).message}</p>
              )}
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {t('admin.actions.apply')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function ApplyGiftCardDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const mutation = useOrderMutation(orderId, (params: { code: string }) =>
    adminClient.orders.giftCards.apply(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    const code = (fd.get('code') as string).trim()
    if (!code) return
    mutation.mutate({ code }, { onSuccess: () => onOpenChange(false) })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.gift_card_section.apply_dialog_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.gift_card_section.apply_dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="gift-card-code">{t('admin.fields.code.label')}</FieldLabel>
                <Input
                  id="gift-card-code"
                  name="code"
                  placeholder={t('admin.orders.detail.gift_card_section.code_placeholder')}
                  required
                  autoFocus
                />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
