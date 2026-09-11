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
import { type ComponentProps, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateStockLevel } from '../../hooks/use-stock-levels'

/**
 * The corrections a merchant reaches for on the Inventory page. These are
 * codes the API knows (`Spree::StockMovement::ADJUSTMENT_REASONS`), not text:
 * the server resolves each to one stored string, so a cause reads the same in
 * the stock history whatever language the admin who recorded it works in.
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

/**
 * A figure that opens something when clicked, styled like the plain ones.
 * Spreads whatever the popover trigger hands it, since it is rendered as the
 * trigger itself.
 *
 * While its popover is open the figure stays filled — Base UI stamps
 * `data-popup-open` on the trigger — so a merchant reading a form that floats
 * over the next row can still see which cell it is editing. The fill comes
 * from the same scale the table's own hover uses, and the row is shaded with
 * it (see the rule in styles.css), for the same reason: a form covering two
 * rows should not leave you counting upwards to work out which SKU you are
 * correcting.
 */
function CountTrigger({
  value,
  label,
  ...props
}: { value: number; label: string } & ComponentProps<'button'>) {
  return (
    <button
      type="button"
      aria-label={label}
      className="-mr-1.5 flex w-full cursor-pointer items-center justify-end gap-1 rounded-sm px-1.5 py-1 tabular-nums hover:bg-accent-strong/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring data-[popup-open]:bg-accent-strong"
      {...props}
    >
      {value}
      <ChevronDownIcon className="size-3 text-muted-foreground" />
    </button>
  )
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

  if (!permissions.can('update', Subject.StockLevel)) return level.count_on_hand

  const name = [level.variant_name, level.options_text].filter(Boolean).join(' · ')

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <CountTrigger
          value={level.count_on_hand}
          label={t('admin.stock_levels.quick_edit.open_aria', { name })}
        />
      </PopoverTrigger>
      <PopoverContent align="end" className="w-auto">
        {open && <OnHandEditor level={level} onSaved={() => setOpen(false)} />}
      </PopoverContent>
    </Popover>
  )
}

// Mounted only while its popover is open, so a hundred-row page carries one
// mutation and one set of options instead of a hundred.
function OnHandEditor({ level, onSaved }: { level: StockLevel; onSaved: () => void }) {
  const { t } = useTranslation()
  const [mode, setMode] = useState<QuickEditMode>('set')
  const [amount, setAmount] = useState(String(level.count_on_hand))
  const [reason, setReason] = useState<string>(STOCK_ADJUSTMENT_REASONS[0])
  const update = useUpdateStockLevel(level.id)
  const parsed = Number.parseInt(amount, 10)

  const modeOptions = QUICK_EDIT_MODES.map((value) => ({
    value,
    label: t(`admin.stock_levels.quick_edit.modes.${value}`),
  }))
  const reasonOptions = STOCK_ADJUSTMENT_REASONS.map((value) => ({
    value,
    label: t(`admin.stock_levels.reasons.${value}`),
  }))

  async function submit() {
    if (Number.isNaN(parsed)) return
    const params =
      mode === 'set' ? { count_on_hand: parsed, reason } : { adjustment: parsed, reason }
    try {
      await update.mutateAsync(params)
      onSaved()
    } catch {
      // The mutation hook has already shown the error.
    }
  }

  return (
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
        onValueChange={(value) => {
          // The amount means something different in each mode — a target
          // count against the shelf, or a difference from it. Carrying the
          // on-hand figure into "adjust" would double the level for anyone
          // who switched mode and confirmed without retyping.
          const next = value as QuickEditMode
          setMode(next)
          setAmount(next === 'set' ? String(level.count_on_hand) : '0')
        }}
      >
        <SelectTrigger className="w-32" aria-label={t('admin.stock_levels.quick_edit.mode_aria')}>
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
        <SelectTrigger className="w-44" aria-label={t('admin.stock_levels.quick_edit.reason_aria')}>
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
        variant="default"
        disabled={update.isPending || Number.isNaN(parsed)}
        aria-label={t('admin.stock_levels.quick_edit.confirm')}
      >
        <CheckIcon className="size-4" />
      </Button>
    </form>
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

  if (!canTransfer && !canOrder) return level.incoming_count

  // The new document opens with this row already on it — the SKU the merchant
  // was looking at, arriving where they were looking at it — so the shortcut
  // is one click rather than a form and two pickers.
  const seed = {
    variant_id: level.variant_id ?? undefined,
    variant_sku: level.variant_sku ?? undefined,
    variant_name: level.variant_name ?? undefined,
    thumbnail_url: level.thumbnail_url ?? undefined,
    stock_location_id: level.stock_location_id ?? undefined,
  }

  return (
    <Popover>
      <PopoverTrigger asChild>
        <CountTrigger
          value={level.incoming_count}
          label={t('admin.stock_levels.incoming.open_aria')}
        />
      </PopoverTrigger>
      <PopoverContent align="end" className="flex w-auto flex-col gap-1 p-1">
        {canTransfer && (
          <Link
            to="/$storeId/transfers/new"
            params={{ storeId }}
            search={seed}
            className="rounded-md px-2 py-1 text-sm hover:bg-accent"
          >
            {t('admin.stock_levels.incoming.create_transfer')}
          </Link>
        )}
        {canOrder && (
          <Link
            to="/$storeId/purchase-orders/new"
            params={{ storeId }}
            search={seed}
            className="rounded-md px-2 py-1 text-sm hover:bg-accent"
          >
            {t('admin.stock_levels.incoming.create_purchase_order')}
          </Link>
        )}
      </PopoverContent>
    </Popover>
  )
}
