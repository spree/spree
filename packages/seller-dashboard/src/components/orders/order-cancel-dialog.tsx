import { zodResolver } from '@hookform/resolvers/zod'
import {
  CANCEL_ORDER_DEFAULTS,
  type CancelOrderFormValues,
  cancelOrderFormSchema,
  mapSpreeErrorsToForm,
} from '@spree/dashboard-core'
import { ReasonField, OrderCancelDialog as SharedOrderCancelDialog } from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCancelOrder } from '../../hooks/use-order'
import { useReasons } from '../../hooks/use-reasons'

/**
 * Withdrawing from an order this seller cannot fulfil.
 *
 * The refund is offered because a seller is merchant of record for their own
 * child order — the party who owes the buyer their money back is the party
 * who took it. On a split checkout the workflow settles through this order's
 * own payment shares, so a seller can never reach a sibling's money.
 */
export function OrderCancelDialog({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { t } = useTranslation()
  const cancel = useCancelOrder(orderId)
  const { data: reasonsData } = useReasons('order-cancellation-reasons')

  const form = useForm<CancelOrderFormValues>({
    resolver: zodResolver(cancelOrderFormSchema),
    defaultValues: CANCEL_ORDER_DEFAULTS,
  })

  async function onSubmit(values: CancelOrderFormValues) {
    try {
      await cancel.mutateAsync({
        cancel_reason_id: values.cancel_reason_id || undefined,
        cancel_note: values.cancel_note.trim() || undefined,
        refund_payments: values.refund_payments,
        notify_customer: values.notify_customer,
      })
      onClose()
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <SharedOrderCancelDialog
      form={form}
      showRefund
      reasonField={
        /* The reasons are the marketplace's — the operator decides what they
           are. A marketplace that has not curated them can still be pulled
           out of, so the empty choice stays rather than forcing one. */
        <Controller
          control={form.control}
          name="cancel_reason_id"
          render={({ field }) => (
            <ReasonField
              id="order-cancellation"
              reasons={(reasonsData?.data ?? []).filter((reason) => reason.active)}
              value={field.value}
              onChange={field.onChange}
              label={t('admin.orders.detail.cancel.reason_label')}
              emptyOptionLabel={t('admin.orders.detail.cancel.no_reason')}
            />
          )}
        />
      }
      onSubmit={onSubmit}
      onClose={onClose}
      pending={cancel.isPending}
    />
  )
}
