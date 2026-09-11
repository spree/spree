import type { SellerPayout } from '@spree/admin-sdk'
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
  FieldDescription,
  FieldLabel,
  Input,
} from '@spree/dashboard-ui'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCompletePayout } from '../../../hooks/use-seller-ledger'

/**
 * The operator saying a settlement reached the seller's bank.
 *
 * What the built-in payout provider waits for: it records what to send and is
 * then told it went. The reference is what makes the claim checkable against
 * a bank statement later, so it is asked for here rather than assumed — and
 * asking is itself the confirmation, which is why there is no second dialog
 * on top of this one.
 */
export function PayoutCompleteDialog({
  payout,
  open,
  onOpenChange,
}: {
  payout: SellerPayout
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const [reference, setReference] = useState(payout.reference ?? '')
  const complete = useCompletePayout(payout.id)

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    await complete.mutateAsync({ reference: reference.trim() || undefined })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>{t('admin.payouts.complete.title')}</DialogTitle>
            <DialogDescription>
              {t('admin.payouts.complete.description', {
                amount: payout.display_amount,
                seller: payout.seller_name ?? '',
              })}
            </DialogDescription>
          </DialogHeader>

          <DialogBody>
            <Field>
              <FieldLabel htmlFor="payout-reference">
                {t('admin.payouts.columns.reference')}
              </FieldLabel>
              <Input
                id="payout-reference"
                value={reference}
                onChange={(event) => setReference(event.target.value)}
                placeholder={t('admin.payouts.complete.reference_placeholder')}
              />
              <FieldDescription>{t('admin.payouts.complete.reference_help')}</FieldDescription>
            </Field>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={complete.isPending}>
              {t('admin.payouts.complete.action')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
