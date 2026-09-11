import {
  Button,
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
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Ending a transfer or an order whose missing units are not coming. Nothing
 * moves; the outstanding count stays on each line as the record of the gap,
 * and the reason goes on the document.
 */
export function CloseShortDialog({
  title,
  description,
  pending,
  onConfirm,
  onClose,
}: {
  title: string
  description: string
  pending: boolean
  onConfirm: (reason: string | undefined) => Promise<unknown>
  onClose: () => void
}) {
  const { t } = useTranslation()
  const [reason, setReason] = useState('')

  async function handleConfirm() {
    const closed = await onConfirm(reason.trim() || undefined)
      .then(() => true)
      .catch(() => false)
    if (closed) onClose()
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <DialogBody>
          <Field>
            <FieldLabel htmlFor="close-short-reason">
              {t('admin.stock_receipts.close_short.reason_label')}
            </FieldLabel>
            <Textarea
              id="close-short-reason"
              value={reason}
              placeholder={t('admin.stock_receipts.close_short.reason_placeholder')}
              onChange={(event) => setReason(event.target.value)}
            />
          </Field>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={handleConfirm} disabled={pending}>
            {pending ? t('admin.actions.saving') : t('admin.stock_receipts.close_short.confirm')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
