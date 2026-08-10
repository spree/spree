import type { Order } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
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
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusBadge,
  Switch,
  useConfirm,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { CreditCardIcon, EllipsisVerticalIcon, PlusIcon, XCircleIcon } from 'lucide-react'
import { type FormEvent, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

export function PaymentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const confirm = useConfirm()
  const [addOpen, setAddOpen] = useState(false)

  const payments = order.payments ?? []

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
          <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
            <PlusIcon data-icon="inline-start" />
            {t('admin.actions.add')}
          </Button>
        </CardAction>
      </CardHeader>
      {payments.length === 0 ? (
        <CardContent>
          <p className="text-center text-muted-foreground py-8">
            {t('admin.pages.orders.detail.empty_payments')}
          </p>
        </CardContent>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-muted-foreground">
                <th className="p-3 pl-5 text-left font-normal">
                  {t('admin.orders.detail.payments_table.number')}
                </th>
                <th className="p-3 text-left font-normal">
                  {t('admin.orders.detail.payments_table.method')}
                </th>
                <th className="p-3 text-left font-normal">
                  {t('admin.orders.detail.payments_table.state')}
                </th>
                <th className="p-3 text-right font-normal">{t('admin.fields.amount.label')}</th>
                <th className="p-3 pr-5 w-10" />
              </tr>
            </thead>
            <tbody>
              {payments.map((payment) => (
                <tr key={payment.id} className="border-b last:border-b-0">
                  <td className="p-3 pl-5 font-medium">{payment.number}</td>
                  <td className="p-3 text-muted-foreground">
                    {payment.payment_method?.name ?? '—'}
                  </td>
                  <td className="p-3">
                    <StatusBadge status={payment.status} />
                  </td>
                  <td className="p-3 text-right font-medium whitespace-nowrap">
                    {payment.display_amount}
                  </td>
                  <td className="p-3 pr-5">
                    {(payment.status === 'checkout' ||
                      payment.status === 'pending' ||
                      payment.status === 'completed') && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          {(payment.status === 'checkout' || payment.status === 'pending') && (
                            <DropdownMenuItem
                              onClick={async () => {
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
                            >
                              <CreditCardIcon className="size-4" />
                              {t('admin.pages.orders.detail.actions.capture')}
                            </DropdownMenuItem>
                          )}
                          {(payment.status === 'checkout' ||
                            payment.status === 'pending' ||
                            payment.status === 'completed') && (
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onClick={async () => {
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
                            >
                              <XCircleIcon className="size-4" />
                              {t('admin.pages.orders.detail.actions.void')}
                            </DropdownMenuItem>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <AddPaymentDialog order={order} open={addOpen} onOpenChange={setAddOpen} />
    </Card>
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
  const sourceRequired = selectedMethod?.source_required ?? false

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
    adminClient.orders.payments.create(orderId, {
      payment_method_id: paymentMethodId,
      ...(sourceId ? { source_id: sourceId } : {}),
      // Ship raw merchant input; `Spree::LocalizedNumber.parse` on the
      // backend handles locale-aware decoding (comma decimals etc.).
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
      onSuccess: (payment) => {
        if (capture && payment && (payment as { id?: string }).id) {
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
                <Input
                  id="pay-amount"
                  type="number"
                  step="0.01"
                  placeholder={order.amount_due ?? '0.00'}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
                <p className="text-xs text-muted-foreground mt-1">
                  {t('admin.orders.detail.payment_form.amount_help')}
                </p>
              </Field>

              <Field>
                <label className="flex items-center gap-2 text-sm" htmlFor="pay-capture">
                  <Switch id="pay-capture" checked={capture} onCheckedChange={setCapture} />
                  {t('admin.orders.detail.payment_form.capture_immediately')}
                </label>
              </Field>
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
