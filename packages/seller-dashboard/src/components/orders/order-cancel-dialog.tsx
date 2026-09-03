import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from '@spree/dashboard-ui'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCancelOrder } from '../../hooks/use-order'
import { useReasons } from '../../hooks/use-reasons'

type CancelFormValues = {
  cancel_reason_id: string
  cancel_note: string
  notify_customer: boolean
}

/**
 * Withdrawing from an order this seller cannot fulfil.
 *
 * A dialog rather than a bare confirm, because a cancellation carries a
 * reason the marketplace wants recorded — without one, operator reporting has
 * nothing to say about why a seller pulled out.
 *
 * Deliberately offers no refund control. The goods return to the shelf and
 * the authorization is released either way; giving back money already taken
 * is the operator's decision, and the endpoint accepts no refund arguments at
 * all rather than showing a seller a switch that would be refused.
 */
export function OrderCancelDialog({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { t } = useTranslation()
  const cancel = useCancelOrder(orderId)
  const { data: reasonsData } = useReasons('order-cancellation-reasons')

  const reasons = (reasonsData?.data ?? []).filter((reason) => reason.active)
  const reasonOptions = [
    // A marketplace that has not curated the vocabulary can still be pulled
    // out of, so the empty choice stays rather than forcing a reason.
    { value: '', label: t('orders.cancel_dialog.no_reason') },
    ...reasons.map((reason) => ({ value: reason.id, label: reason.name })),
  ]

  const form = useForm<CancelFormValues>({
    defaultValues: { cancel_reason_id: '', cancel_note: '', notify_customer: false },
  })

  async function onSubmit(values: CancelFormValues) {
    try {
      await cancel.mutateAsync({
        cancel_reason_id: values.cancel_reason_id || undefined,
        cancel_note: values.cancel_note.trim() || undefined,
        notify_customer: values.notify_customer,
      })
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
            <DialogTitle>{t('orders.cancel_confirm.title')}</DialogTitle>
            <DialogDescription>{t('orders.cancel_dialog.description')}</DialogDescription>
          </DialogHeader>

          <DialogBody>
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}

            <div className="flex flex-col gap-4">
              {reasons.length > 0 && (
                <Field>
                  <FieldLabel htmlFor="cancel-reason">
                    {t('orders.cancel_dialog.reason_label')}
                  </FieldLabel>
                  <Controller
                    control={form.control}
                    name="cancel_reason_id"
                    render={({ field }) => (
                      <Select
                        items={reasonOptions}
                        value={field.value}
                        onValueChange={(value) => field.onChange(value ?? '')}
                      >
                        <SelectTrigger id="cancel-reason">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {reasonOptions.map((option) => (
                            <SelectItem key={option.value} value={option.value}>
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </Field>
              )}

              <Field>
                <FieldLabel htmlFor="cancel-note">
                  {t('orders.cancel_dialog.note_label')}
                </FieldLabel>
                <Textarea id="cancel-note" {...form.register('cancel_note')} />
              </Field>

              <label className="flex items-center gap-2 text-sm" htmlFor="cancel-notify">
                <Controller
                  control={form.control}
                  name="notify_customer"
                  render={({ field }) => (
                    <Checkbox
                      id="cancel-notify"
                      checked={field.value}
                      onCheckedChange={(checked) => field.onChange(!!checked)}
                    />
                  )}
                />
                {t('orders.cancel_dialog.notify_customer')}
              </label>
            </div>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" variant="destructive" disabled={cancel.isPending}>
              {t('orders.cancel')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
