import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '../ui/dialog'
import { Field, FieldLabel } from '../ui/field'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '../ui/input-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'
import { Switch } from '../ui/switch'
import type { RefundMethod } from './return-dialogs'

/** How a claim is settled. */
export type ClaimResolution = 'refund' | 'replacement' | 'refund_and_replacement'

/** One claimed line, as the resolve form needs it. */
export type ClaimLineForResolve = {
  id: string
  label: string
  quantity: number
  /** Whether the claim was opened asking for this line to be replaced. */
  sendReplacement: boolean
}

/**
 * Settles a claim: money back, a replacement shipment, or both.
 *
 * The resolution is chosen here rather than at claim creation, so the
 * merchant decides how to make things right once they have the facts. The
 * currency symbol comes from the caller — the operator reads it from the
 * store, and a seller has no currency of their own.
 *
 * Shared by the operator's order page and the seller's.
 */
export function ClaimResolveDialog({
  lines,
  defaultAmount,
  currencySymbol,
  onClose,
  onSubmit,
  pending = false,
}: {
  lines: ClaimLineForResolve[]
  /** What to offer as the refund, already resolved by the caller. */
  defaultAmount: string
  currencySymbol: string
  onClose: () => void
  onSubmit: (params: {
    resolution: ClaimResolution
    refundMethod: RefundMethod
    amount?: string
    replacementLineItemIds: string[]
  }) => void
  pending?: boolean
}) {
  const { t } = useTranslation()

  const [resolution, setResolution] = useState<ClaimResolution>('refund')
  const [refundMethod, setRefundMethod] = useState<RefundMethod>('store_credit')
  const [amount, setAmount] = useState(defaultAmount)
  const [replacing, setReplacing] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(lines.map((line) => [line.id, line.sendReplacement])),
  )

  const refunding = resolution.includes('refund')
  const sendingReplacement = resolution.includes('replacement')
  const chosenReplacements = Object.entries(replacing)
    .filter(([, on]) => on)
    .map(([id]) => id)

  const resolutionOptions = (['refund', 'replacement', 'refund_and_replacement'] as const).map(
    (value) => ({
      value,
      label: t(`admin.pages.orders.detail.claims.resolutions.${value}`),
    }),
  )

  const methodOptions = [
    {
      value: 'store_credit',
      label: t('admin.pages.orders.detail.returns.refund_methods.store_credit'),
    },
    {
      value: 'original_payment',
      label: t('admin.pages.orders.detail.returns.refund_methods.original_payment'),
    },
  ]

  // Refunding nothing, or replacing nothing, is what the server rejects —
  // say so here instead of letting the request fail.
  const ready =
    (!refunding || Number(amount) > 0) && (!sendingReplacement || chosenReplacements.length > 0)

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.orders.detail.claims.resolve_title')}</DialogTitle>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-4">
          <Field>
            <FieldLabel htmlFor="claim-resolution">
              {t('admin.pages.orders.detail.claims.resolution')}
            </FieldLabel>
            <Select
              items={resolutionOptions}
              value={resolution}
              onValueChange={(value) => setResolution(value as ClaimResolution)}
            >
              <SelectTrigger id="claim-resolution">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {resolutionOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>

          {refunding && (
            <>
              <Field>
                <FieldLabel htmlFor="claim-resolve-amount">
                  {t('admin.pages.orders.detail.claims.refund_amount')}
                </FieldLabel>
                <InputGroup>
                  <InputGroupAddon>
                    <InputGroupText>{currencySymbol}</InputGroupText>
                  </InputGroupAddon>
                  <InputGroupInput
                    id="claim-resolve-amount"
                    type="number"
                    step="0.01"
                    min="0"
                    value={amount}
                    onChange={(event) => setAmount(event.target.value)}
                  />
                </InputGroup>
              </Field>
              <Field>
                <FieldLabel htmlFor="claim-refund-method">
                  {t('admin.pages.orders.detail.returns.refund_method')}
                </FieldLabel>
                <Select
                  items={methodOptions}
                  value={refundMethod}
                  onValueChange={(value) => setRefundMethod(value as RefundMethod)}
                >
                  <SelectTrigger id="claim-refund-method">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {methodOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
            </>
          )}

          {sendingReplacement && (
            <div className="flex flex-col gap-2">
              <span className="font-medium text-sm">
                {t('admin.pages.orders.detail.claims.replacement_items')}
              </span>
              {lines.map((line) => (
                <div
                  key={line.id}
                  className="flex items-center justify-between gap-4 rounded-lg border p-3"
                >
                  <span className="truncate text-sm">
                    {line.label}
                    <span className="text-muted-foreground"> ×{line.quantity}</span>
                  </span>
                  <Switch
                    checked={replacing[line.id] ?? false}
                    onCheckedChange={(checked) =>
                      setReplacing({ ...replacing, [line.id]: checked })
                    }
                  />
                </div>
              ))}
            </div>
          )}
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose} disabled={pending}>
            {t('admin.actions.cancel')}
          </Button>
          <Button
            type="button"
            disabled={!ready || pending}
            onClick={() =>
              onSubmit({
                resolution,
                refundMethod,
                amount: refunding ? amount : undefined,
                replacementLineItemIds: chosenReplacements,
              })
            }
          >
            {t('admin.pages.orders.detail.claims.actions.resolve')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
