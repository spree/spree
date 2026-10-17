import type { Order, Payment } from '@spree/admin-sdk'
import { adminClient, currencyParts, Money } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldGroup,
  FieldLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  StatusBadge,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  CreditCardIcon,
  EllipsisVerticalIcon,
  ExternalLinkIcon,
  InfoIcon,
  PlusIcon,
  ShieldAlertIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'
import { type FormEvent, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'
import { useOrderGroup } from '../../../hooks/use-seller-ledger'
import { PaymentDetailsDialog } from './payment-details-dialog'

export function PaymentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const confirm = useConfirm()
  const [addOpen, setAddOpen] = useState(false)

  // An order from a split checkout has no payments of its own: the customer
  // paid once, against the group. Reading `order.payments` there would render
  // "no payments" on an order that was paid in full.
  const {
    data: group,
    isPending: groupPending,
    isError: groupFailed,
  } = useOrderGroup(order.order_group_id)
  const grouped = !!order.order_group_id
  const payments = (grouped ? group?.payments : order.payments) ?? []
  // On a grouped order the payments arrive with the group, so until they do
  // there is nothing to say — rendering the empty state here would show "no
  // payments" on an order that was paid in full, which is the misreading this
  // whole branch exists to prevent.
  const awaitingGroup = grouped && groupPending
  const splits = order.payment_splits ?? []

  const captureMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.capture(orderId, paymentId, {}),
  )
  const voidMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.void(orderId, paymentId, {}),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <CreditCardIcon className="size-4" />
          {t('admin.pages.orders.detail.section_payments')}
          {payments.length > 0 && <Badge variant="outline">{payments.length}</Badge>}
        </CardTitle>
        <CardAction className="flex items-center gap-2">
          {order.payment_status && <StatusBadge status={order.payment_status} />}
          {/* Adding, capturing and voting a grouped payment acts on every
              order in the checkout, not just this one — so this order's page
              reads that money rather than moving it. */}
          {!grouped && (
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon data-icon="inline-start" />
              {t('admin.actions.add')}
            </Button>
          )}
        </CardAction>
      </CardHeader>
      {awaitingGroup ? (
        <CardContent>
          <Skeleton className="h-24 w-full" />
        </CardContent>
      ) : grouped && groupFailed ? (
        // Distinct from the empty state below: a request that failed says
        // nothing about whether this order was paid, and reading "no payments"
        // off a network error is the misreading this branch exists to prevent.
        <CardContent>
          <p className="text-center text-destructive py-8">
            {t('admin.orders.detail.payments_table.load_error')}
          </p>
        </CardContent>
      ) : payments.length === 0 ? (
        <CardContent>
          <p className="text-center text-muted-foreground py-8">
            {t('admin.pages.orders.detail.empty_payments')}
          </p>
        </CardContent>
      ) : (
        <>
          {grouped && (
            <p className="px-6 pb-2 text-sm text-muted-foreground">
              {t('admin.orders.detail.payments_table.shared_help')}
            </p>
          )}
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.orders.detail.payments_table.number')}</TableHead>
                <TableHead>{t('admin.orders.detail.payments_table.method')}</TableHead>
                <TableHead>{t('admin.orders.detail.payments_table.state')}</TableHead>
                <TableHead className="text-right">{t('admin.fields.amount.label')}</TableHead>
                {grouped && (
                  <TableHead className="text-right">
                    {t('admin.orders.detail.payments_table.this_order')}
                  </TableHead>
                )}
                <TableHead className="w-10" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {payments.map((payment) => (
                <TableRow key={payment.id}>
                  <TableCell className="font-medium">{payment.number}</TableCell>
                  <TableCell className="text-muted-foreground">
                    {payment.payment_method?.name ?? '—'}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-wrap items-center gap-1.5">
                      <StatusBadge status={payment.status} />
                      {(payment.avs_risky || payment.cvv_risky) && (
                        <Badge variant="warning">
                          <ShieldAlertIcon />
                          {t('admin.orders.detail.payments_table.failed_card_checks')}
                        </Badge>
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="text-right font-medium whitespace-nowrap tabular-nums">
                    <Money amount={payment.amount} currency={order.currency} />
                  </TableCell>
                  {grouped && (
                    <TableCell className="text-right whitespace-nowrap tabular-nums">
                      <Money
                        amount={
                          splits.find((split) => split.payment_id === payment.id)?.captured_amount
                        }
                        currency={order.currency}
                      />
                    </TableCell>
                  )}
                  <TableCell>
                    <PaymentActionsMenu
                      payment={payment}
                      currency={order.currency}
                      // Capturing or voiding a grouped payment acts on every
                      // order in the checkout, so this page only links out.
                      canCapture={
                        !grouped && (payment.status === 'checkout' || payment.status === 'pending')
                      }
                      canVoid={
                        !grouped &&
                        (payment.status === 'checkout' ||
                          payment.status === 'pending' ||
                          payment.status === 'completed')
                      }
                      onCapture={async () => {
                        if (
                          await confirm({
                            message: t('admin.orders.detail.confirm.capture_message'),
                            variant: 'default',
                            confirmLabel: t('admin.pages.orders.detail.actions.capture'),
                          })
                        ) {
                          captureMutation.mutate(payment.id)
                        }
                      }}
                      onVoid={async () => {
                        if (
                          await confirm({
                            message: t('admin.orders.detail.confirm.void_message'),
                            variant: 'destructive',
                            confirmLabel: t('admin.pages.orders.detail.actions.void'),
                          })
                        ) {
                          voidMutation.mutate(payment.id)
                        }
                      }}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </>
      )}
      <AddPaymentDialog order={order} open={addOpen} onOpenChange={setAddOpen} />
    </Card>
  )
}

function PaymentActionsMenu({
  payment,
  currency,
  canCapture,
  canVoid,
  onCapture,
  onVoid,
}: {
  payment: Payment
  currency: string
  canCapture: boolean
  canVoid: boolean
  onCapture: () => void
  onVoid: () => void
}) {
  const { t } = useTranslation()
  const [detailsOpen, setDetailsOpen] = useState(false)
  const dashboardUrl = payment.gateway_dashboard_payment_url

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-xs">
            <EllipsisVerticalIcon className="size-4" />
            <span className="sr-only">{t('admin.actions.actions_menu')}</span>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setDetailsOpen(true)}>
            <InfoIcon className="size-4" />
            {t('admin.orders.detail.payments_table.view_details')}
          </DropdownMenuItem>
          {dashboardUrl && (
            <DropdownMenuItem asChild>
              <a href={dashboardUrl} target="_blank" rel="noopener noreferrer">
                <ExternalLinkIcon className="size-4" />
                {t('admin.orders.detail.payments_table.view_at_gateway', {
                  gateway: payment.payment_method?.name,
                })}
              </a>
            </DropdownMenuItem>
          )}
          {canCapture && (
            <DropdownMenuItem onClick={onCapture}>
              <CreditCardIcon className="size-4" />
              {t('admin.pages.orders.detail.actions.capture')}
            </DropdownMenuItem>
          )}
          {canVoid && (
            <DropdownMenuItem variant="destructive" onClick={onVoid}>
              <XCircleIcon className="size-4" />
              {t('admin.pages.orders.detail.actions.void')}
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      <PaymentDetailsDialog
        payment={payment}
        currency={currency}
        open={detailsOpen}
        onOpenChange={setDetailsOpen}
      />
    </>
  )
}

function AddPaymentDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const orderId = order.id
  const customerId = order.customer_id ?? undefined
  const [paymentMethodId, setPaymentMethodId] = useState<string>('')
  const [sourceId, setSourceId] = useState<string>('')
  const [amount, setAmount] = useState<string>(order.amount_due ?? '')
  const [capture, setCapture] = useState(false)
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  // Re-seed amount from outstanding balance whenever the dialog opens.
  useEffect(() => {
    if (open) setAmount(order.amount_due ?? '')
  }, [open, order.amount_due])

  const { data: methodsData } = useQuery({
    queryKey: ['payment-methods'],
    queryFn: () => adminClient.paymentMethods.list({ limit: 50 }),
    enabled: open,
    staleTime: 60_000,
  })
  const paymentMethods = methodsData?.data ?? []
  const selectedMethod = paymentMethods.find((m) => m.id === paymentMethodId)
  const isStoreCredit = selectedMethod?.type === 'store_credit'
  const sourceRequired = (selectedMethod?.source_required ?? false) && !isStoreCredit

  const { data: cardsData } = useQuery({
    queryKey: ['customer-credit-cards', customerId],
    queryFn: () =>
      customerId
        ? adminClient.customers.creditCards.list(customerId, { limit: 50 })
        : Promise.resolve(null),
    enabled: open && Boolean(customerId) && sourceRequired,
    staleTime: 30_000,
  })
  const savedCards = cardsData?.data ?? []
  const canSubmit = Boolean(paymentMethodId) && (!sourceRequired || Boolean(sourceId))

  const mutation = useOrderMutation(orderId, () =>
    isStoreCredit
      ? adminClient.orders.storeCredits.apply(orderId, amount ? { amount } : {})
      : adminClient.orders.payments.create(orderId, {
          payment_method_id: paymentMethodId,
          ...(sourceId ? { source_id: sourceId } : {}),
          // A number input, so the value is already canonical ("49.5").
          ...(amount ? { amount } : {}),
        }),
  )

  const captureMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.capture(orderId, paymentId, {}),
  )

  function reset() {
    setPaymentMethodId('')
    setSourceId('')
    setAmount('')
    setCapture(false)
  }

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!canSubmit) return

    mutation.mutate(undefined, {
      // A store credit charge answers with the order, not a payment, so there
      // is no payment id to capture — and no gateway to capture it at.
      onSuccess: (payment) => {
        if (capture && !isStoreCredit && payment && (payment as { id?: string }).id) {
          captureMutation.mutate((payment as { id: string }).id, {
            onSuccess: () => {
              onOpenChange(false)
              reset()
            },
          })
        } else {
          onOpenChange(false)
          reset()
        }
      },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.payment_form.title')}</DialogTitle>
          <DialogDescription>{t('admin.orders.detail.payment_form.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="pay-method">
                  {t('admin.orders.detail.payment_form.method_label')}
                </FieldLabel>
                <Select
                  value={paymentMethodId}
                  onValueChange={(v) => {
                    setPaymentMethodId(v)
                    setSourceId('')
                  }}
                >
                  <SelectTrigger id="pay-method">
                    <SelectValue
                      placeholder={t('admin.orders.detail.payment_form.method_placeholder')}
                    >
                      {(value) =>
                        paymentMethods.find((m) => m.id === value)?.name ??
                        t('admin.orders.detail.payment_form.method_placeholder')
                      }
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {paymentMethods.map((m) => (
                      <SelectItem key={m.id} value={m.id}>
                        {m.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>

              {sourceRequired && (
                <Field>
                  <FieldLabel htmlFor="pay-source">
                    {t('admin.orders.detail.payment_form.source_label')}
                  </FieldLabel>
                  {!customerId ? (
                    <p className="text-sm text-destructive">
                      {t('admin.orders.detail.payment_form.source_requires_customer')}
                    </p>
                  ) : savedCards.length === 0 ? (
                    <p className="text-sm text-muted-foreground">
                      {t('admin.orders.detail.payment_form.no_saved_cards')}
                    </p>
                  ) : (
                    <Select value={sourceId} onValueChange={setSourceId}>
                      <SelectTrigger id="pay-source">
                        <SelectValue
                          placeholder={t('admin.orders.detail.payment_form.source_placeholder')}
                        >
                          {(value) => {
                            const card = savedCards.find((c) => c.id === value)
                            return card
                              ? `${card.brand} •••• ${card.last4} (${card.month}/${card.year})`
                              : t('admin.orders.detail.payment_form.source_placeholder')
                          }}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {savedCards.map((c) => (
                          <SelectItem key={c.id} value={c.id}>
                            {c.brand} •••• {c.last4} ({c.month}/{c.year})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                </Field>
              )}

              <Field>
                <FieldLabel htmlFor="pay-amount">{t('admin.fields.amount.label')}</FieldLabel>
                <InputGroup>
                  <InputGroupAddon>
                    <InputGroupText>{currencySymbol}</InputGroupText>
                  </InputGroupAddon>
                  <InputGroupInput
                    id="pay-amount"
                    type="number"
                    step="any"
                    placeholder={order.amount_due ?? '0.00'}
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                  />
                </InputGroup>
                <p className="text-xs text-muted-foreground mt-1">
                  {t('admin.orders.detail.payment_form.amount_help')}
                </p>
              </Field>

              {!isStoreCredit && (
                <Field>
                  <label className="flex items-center gap-2 text-sm" htmlFor="pay-capture">
                    <Switch id="pay-capture" checked={capture} onCheckedChange={setCapture} />
                    {t('admin.orders.detail.payment_form.capture_immediately')}
                  </label>
                </Field>
              )}
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button
              type="submit"
              disabled={!canSubmit || mutation.isPending || captureMutation.isPending}
            >
              {mutation.isPending || captureMutation.isPending
                ? t('admin.actions.saving')
                : t('admin.actions.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
