import type { StockTransfer } from '@spree/admin-sdk'
import {
  Button,
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
import { useCancelStockTransfer } from '../../hooks/use-stock-transfers'
import {
  IN_TRANSIT_RESOLUTIONS,
  type InTransitResolution,
  isInFlight,
} from '../../schemas/inventory-operations'
import { ChoiceCardPicker } from './choice-card-picker'

/**
 * Calling a transfer off, and — once the van has gone — what happened to the
 * units.
 *
 * Nothing is preselected while the transfer is in flight. The two answers put
 * stock in different places, and the workflow refuses to guess between them,
 * so neither does this dialog: the merchant chooses before Cancel is live.
 */
export function TransferCancelDialog({
  transfer,
  onClose,
}: {
  transfer: StockTransfer
  onClose: () => void
}) {
  const { t } = useTranslation()
  const cancelTransfer = useCancelStockTransfer(transfer.id)
  const inFlight = isInFlight(transfer.status)
  const [resolution, setResolution] = useState<InTransitResolution | ''>('')

  const options = IN_TRANSIT_RESOLUTIONS.map((value) => ({
    value,
    label: t(`admin.stock_transfers.in_transit_resolutions.${value}`),
    description: t(`admin.stock_transfers.cancel_confirm.in_flight_${value}`),
  }))

  async function handleConfirm() {
    try {
      await cancelTransfer.mutateAsync(
        inFlight ? { on_in_transit: resolution as InTransitResolution } : {},
      )
      onClose()
    } catch {
      // The mutation hook surfaces the refusal; the dialog stays open so the
      // merchant can answer differently.
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.stock_transfers.cancel_confirm.title')}</DialogTitle>
          {!inFlight && (
            <DialogDescription>
              {t('admin.stock_transfers.cancel_confirm.message')}
            </DialogDescription>
          )}
        </DialogHeader>

        {inFlight && (
          <DialogBody>
            <ChoiceCardPicker<InTransitResolution | ''>
              label={t('admin.stock_transfers.fields.in_transit_resolution')}
              options={options}
              value={resolution}
              onChange={setResolution}
            />
          </DialogBody>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            {t('admin.actions.close')}
          </Button>
          <Button
            type="button"
            variant="destructive"
            onClick={handleConfirm}
            disabled={cancelTransfer.isPending || (inFlight && resolution === '')}
          >
            {t('admin.stock_transfers.actions.cancel_transfer')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
