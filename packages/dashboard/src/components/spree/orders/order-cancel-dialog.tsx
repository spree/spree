import { zodResolver } from '@hookform/resolvers/zod'
import {
  adminClient,
  CANCEL_ORDER_DEFAULTS,
  type CancelOrderFormValues,
  cancelOrderFormSchema,
  mapSpreeErrorsToForm,
  useResourceMutation,
} from '@spree/dashboard-core'
import { OrderCancelDialog as SharedOrderCancelDialog } from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { orderQueryKey } from '../../../hooks/use-order'
import { ReasonField } from '../reason-field'

/**
 * What the operator records when cancelling an order, and what they choose to
 * do with money already taken.
 */
export function OrderCancelDialog({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { t } = useTranslation()

  const cancelMutation = useResourceMutation({
    mutationFn: (values: CancelOrderFormValues) =>
      adminClient.orders.cancel(orderId, {
        cancel_reason_id: values.cancel_reason_id || undefined,
        cancel_note: values.cancel_note.trim() || undefined,
        refund_payments: values.refund_payments,
        notify_customer: values.notify_customer,
      }),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.canceled'),
    errorMessage: t('admin.orders.detail.errors.cancel_failed'),
  })

  const form = useForm<CancelOrderFormValues>({
    resolver: zodResolver(cancelOrderFormSchema),
    defaultValues: CANCEL_ORDER_DEFAULTS,
  })

  async function onSubmit(values: CancelOrderFormValues) {
    try {
      await cancelMutation.mutateAsync(values)
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
        /* A merchant who has not curated the vocabulary can still cancel, so
           the empty choice stays available rather than forcing a reason. */
        <Controller
          control={form.control}
          name="cancel_reason_id"
          render={({ field }) => (
            <ReasonField
              kind="order-cancellation-reasons"
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
      pending={cancelMutation.isPending}
    />
  )
}
