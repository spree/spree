import type { Fulfillment } from '@spree/admin-sdk'
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
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

export function FulfillmentMarkDeliveredDialog({
  fulfillment,
  open,
  onOpenChange,
  onConfirm,
  pending,
}: {
  fulfillment: Fulfillment
  open: boolean
  onOpenChange: (open: boolean) => void
  onConfirm: (notifyCustomer: boolean) => void
  pending: boolean
}) {
  const { t } = useTranslation()
  const [notifyCustomer, setNotifyCustomer] = useState(true)
  const checkboxId = `mark-delivered-notify-${fulfillment.id}`

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (next) setNotifyCustomer(true)
        onOpenChange(next)
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.fulfillments.mark_delivered_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.fulfillments.mark_delivered_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <label htmlFor={checkboxId} className="flex cursor-pointer items-center gap-2 text-base">
            <Checkbox
              id={checkboxId}
              checked={notifyCustomer}
              onCheckedChange={(checked) => setNotifyCustomer(checked === true)}
            />
            {t('admin.orders.detail.fulfillments.mark_delivered_notify')}
          </label>
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" disabled={pending} onClick={() => onConfirm(notifyCustomer)}>
            {pending
              ? t('admin.actions.saving')
              : t('admin.orders.detail.fulfillments.mark_delivered')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
