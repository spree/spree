import type { ReactNode } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import { Checkbox } from '../ui/checkbox'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { Field, FieldLabel } from '../ui/field'
import { Textarea } from '../ui/textarea'

/** The form shape both panels bind for a cancellation. */
export type CancelOrderFields = {
  cancel_reason_id: string
  cancel_note: string
  refund_payments: boolean
  notify_customer: boolean
}

/**
 * Cancels an order, asking why first.
 *
 * A dialog rather than a bare confirm, because a cancellation carries a
 * reason the merchant wants recorded — this doubles as the confirmation, so
 * there is no second dialog in front of it.
 *
 * `showRefund` is off by default: releasing an unclaimed authorization happens
 * either way, but handing back money already taken is not every surface's
 * decision. On the seller branch the endpoint accepts no refund argument at
 * all, so showing the switch would offer something that would be refused.
 */
export function OrderCancelDialog({
  form,
  reasonField,
  showRefund = false,
  showNotify = true,
  onSubmit,
  onClose,
  pending = false,
}: {
  form: UseFormReturn<CancelOrderFields>
  /** The reason picker, wired to whichever vocabulary the caller reads. */
  reasonField?: ReactNode
  showRefund?: boolean
  showNotify?: boolean
  onSubmit: (values: CancelOrderFields) => void | Promise<void>
  onClose: () => void
  pending?: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <Dialog open onOpenChange={(next) => !next && onClose()}>
      <DialogContent>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogHeader>
            <DialogTitle>{t('admin.pages.orders.detail.dialogs.cancel_title')}</DialogTitle>
            <DialogDescription>{t('admin.orders.detail.cancel.description')}</DialogDescription>
          </DialogHeader>

          <DialogBody>
            {errors.root?.message && (
              <p className="text-destructive text-sm" role="alert">
                {errors.root.message}
              </p>
            )}

            <div className="flex flex-col gap-4">
              {reasonField}

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

              {showRefund && (
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
              )}

              {showNotify && (
                <Controller
                  control={form.control}
                  name="notify_customer"
                  render={({ field }) => (
                    <label
                      htmlFor="order-cancel-notify"
                      className="flex cursor-pointer items-center gap-2 text-sm"
                    >
                      <Checkbox
                        id="order-cancel-notify"
                        checked={field.value}
                        onCheckedChange={(checked) => field.onChange(checked === true)}
                      />
                      {t('admin.orders.detail.cancel.notify_customer')}
                    </label>
                  )}
                />
              )}
            </div>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
              {t('admin.orders.detail.cancel.keep_order')}
            </Button>
            <Button type="submit" variant="destructive" disabled={pending}>
              {t('admin.pages.orders.detail.actions.cancel')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
