import type { StockLevel } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Input,
  Popover,
  PopoverContent,
  PopoverTrigger,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { CheckIcon, ChevronDownIcon } from '@spree/dashboard-ui/icons'
import { Link, useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateStockLevel } from '../../hooks/use-stock-levels'

/**
 * The corrections a merchant reaches for on the Inventory page, sent as the
 * `reason` the stock history shows beside the movement. Canonical values
 * here; the labels are built at render time from the locale.
 */
export const STOCK_ADJUSTMENT_REASONS = [
  'correction',
  'count',
  'received',
  'return_restock',
  'damaged',
  'theft_or_loss',
  'promotion_or_donation',
] as const

const QUICK_EDIT_MODES = ['set', 'adjust'] as const
type QuickEditMode = (typeof QUICK_EDIT_MODES)[number]

/** Right-aligned figure, the way every number on the page reads. */
export function CountCell({ value }: { value: number }) {
  return <span className="block w-full text-right tabular-nums">{value}</span>
}

/**
 * On hand, edited in place. Clicking the figure opens a small form: set the
 * shelf to a count or move it by a delta, name why, confirm. Either way the
 * API records the change as an `adjusted` movement in the stock history.
 */
export function OnHandCell({ level }: { level: StockLevel }) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState<QuickEditMode>('set')
  const [amount, setAmount] = useState(String(level.count_on_hand))
  const [reason, setReason] = useState<string>(STOCK_ADJUSTMENT_REASONS[0])
  const update = useUpdateStockLevel(level.id)

  if (!permissions.can('update', Subject.StockLevel)) {
    return <CountCell value={level.count_on_hand} />
  }

  const modeOptions = QUICK_EDIT_MODES.map((value) => ({
    value,
    label: t(`admin.stock_levels.quick_edit.modes.${value}`),
  }))
  const reasonOptions = STOCK_ADJUSTMENT_REASONS.map((value) => ({
    value,
    label: t(`admin.stock_levels.reasons.${value}`),
  }))

  function openWith(nextOpen: boolean) {
    if (nextOpen) {
      setMode('set')
      setAmount(String(level.count_on_hand))
      setReason(STOCK_ADJUSTMENT_REASONS[0])
    }
    setOpen(nextOpen)
  }

  async function submit() {
    const parsed = Number.parseInt(amount, 10)
    if (Number.isNaN(parsed)) return
    // Stored on the movement as free text and shown raw in every admin's
    // stock history, so it is written in English whatever this admin's
    // locale — the same language the API's own default reason uses.
    const reasonLabel = t(`admin.stock_levels.reasons.${reason}`, { lng: 'en' })
    const params =
      mode === 'set'
        ? { count_on_hand: parsed, reason: reasonLabel }
        : { adjustment: parsed, reason: reasonLabel }
    try {
      await update.mutateAsync(params)
      setOpen(false)
    } catch {
      // The mutation hook has already shown the error.
    }
  }

  const name = [level.variant_name, level.options_text].filter(Boolean).join(' · ')

  return (
    <Popover open={open} onOpenChange={openWith}>
      <PopoverTrigger asChild>
        <button
          type="button"
          data-testid="on-hand-cell"
          aria-label={t('admin.stock_levels.quick_edit.open_aria', { name })}
          className="flex w-full cursor-pointer items-center justify-end gap-1 rounded px-1 tabular-nums hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {level.count_on_hand}
          <ChevronDownIcon className="size-3 text-muted-foreground" />
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-auto p-2">
        <form
          className="flex items-center gap-2"
          onSubmit={(event) => {
            event.preventDefault()
            event.stopPropagation()
            void submit()
          }}
        >
          <Select
            items={modeOptions}
            value={mode}
            onValueChange={(value) => setMode(value as QuickEditMode)}
          >
            <SelectTrigger
              className="w-32"
              aria-label={t('admin.stock_levels.quick_edit.mode_aria')}
            >
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {modeOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Input
            type="number"
            step={1}
            min={mode === 'set' ? 0 : undefined}
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            aria-label={t('admin.stock_levels.quick_edit.amount_aria')}
            className="w-24 text-right tabular-nums"
            autoFocus
          />
          <Select
            items={reasonOptions}
            value={reason}
            onValueChange={(value) => setReason(String(value))}
          >
            <SelectTrigger
              className="w-44"
              aria-label={t('admin.stock_levels.quick_edit.reason_aria')}
            >
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
          <Button
            type="submit"
            size="icon"
            variant="outline"
            disabled={update.isPending || Number.isNaN(Number.parseInt(amount, 10))}
            aria-label={t('admin.stock_levels.quick_edit.confirm')}
          >
            <CheckIcon className="size-4" />
          </Button>
        </form>
      </PopoverContent>
    </Popover>
  )
}

/**
 * Incoming, with the two ways to make it grow: a transfer from another
 * warehouse or an order from a supplier. The figure itself is a column
 * read — nothing is created from here.
 */
export function IncomingCell({ level }: { level: StockLevel }) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId: string }
  const { permissions } = usePermissions()
  const canTransfer = permissions.can('create', Subject.StockTransfer)
  const canOrder = permissions.can('create', Subject.PurchaseOrder)

  if (!canTransfer && !canOrder) {
    return <CountCell value={level.incoming_count} />
  }

  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label={t('admin.stock_levels.incoming.open_aria')}
          className="flex w-full cursor-pointer items-center justify-end gap-1 rounded px-1 tabular-nums hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {level.incoming_count}
          <ChevronDownIcon className="size-3 text-muted-foreground" />
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="flex w-auto flex-col gap-1 p-2">
        {canTransfer && (
          <Link
            to="/$storeId/transfers/new"
            params={{ storeId }}
            className="rounded px-2 py-1 text-sm hover:bg-accent"
          >
            {t('admin.stock_levels.incoming.create_transfer')}
          </Link>
        )}
        {canOrder && (
          <Link
            to="/$storeId/purchase-orders/new"
            params={{ storeId }}
            className="rounded px-2 py-1 text-sm hover:bg-accent"
          >
            {t('admin.stock_levels.incoming.create_purchase_order')}
          </Link>
        )}
      </PopoverContent>
    </Popover>
  )
}
