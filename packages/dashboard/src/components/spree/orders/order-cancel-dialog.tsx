import { zodResolver } from '@hookform/resolvers/zod'
import { adminClient, mapSpreeErrorsToForm, useResourceMutation } from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldLabel,
  Textarea,
} from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { orderQueryKey } from '../../../hooks/use-order'
import {
  CANCEL_ORDER_DEFAULTS,
  type CancelOrderFormValues,
  cancelOrderFormSchema,
} from '../../../schemas/order'
import { ReasonField } from '../reason-field'

/**
 * Cancels an order, asking why first. The reason comes from the store's own
 * cancellation vocabulary and is stamped on the order along with the note, so
 * this doubles as the confirmation step — there is no separate confirm dialog
 * in front of it.
 */
export function OrderCancelDialog({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { t } = useTranslation()

  const cancelMutation = useResourceMutation({
    mutationFn: (values: CancelOrderFormValues) =>
      adminClient.orders.cancel(orderId, {
        cancel_reason_id: values.cancel_reason_id || undefined,
        cancel_note: values.cancel_note.trim() || undefined,
        refund_payments: values.refund_payments,
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
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogHeader>
            <DialogTitle>{t('admin.pages.orders.detail.dialogs.cancel_title')}</DialogTitle>
            <DialogDescription>{t('admin.orders.detail.cancel.description')}</DialogDescription>
          </DialogHeader>

          <DialogBody>
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <div className="flex flex-col gap-4">
              {/* A merchant who has not curated the vocabulary can still
                  cancel, so the empty choice stays available rather than
                  forcing a reason. */}
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

              <Field>
                <FieldLabel htmlFor="order-cancel-note">
                  {t('admin.orders.detail.cancel.note_label')}
                </FieldLabel>
                <Textarea
                  id="order-cancel-note"
                  rows={3}
                  placeholder={t('admin.orders.detail.cancel.note_placeholder')}
                  {...form.register('cancel_note')}
                />
              </Field>

              {/* An unclaimed authorization is released either way, so this
                  only decides what happens to money actually taken. */}
              <Controller
                control={form.control}
                name="refund_payments"
                render={({ field }) => (
                  <label
                    htmlFor="order-cancel-refund"
                    className="flex cursor-pointer items-start gap-2 text-sm"
                  >
                    <Checkbox
                      id="order-cancel-refund"
                      checked={field.value}
                      onCheckedChange={(checked) => field.onChange(checked === true)}
                    />
                    <span>
                      {t('admin.orders.detail.cancel.refund_payments')}
                      <span className="block text-muted-foreground">
                        {t('admin.orders.detail.cancel.refund_payments_help')}
                      </span>
                    </span>
                  </label>
                )}
              />
            </div>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('admin.orders.detail.cancel.keep_order')}
            </Button>
            <Button type="submit" variant="destructive" disabled={cancelMutation.isPending}>
              {t('admin.pages.orders.detail.actions.cancel')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
