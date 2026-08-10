import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PackageIcon, PencilIcon, TrashIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import type { FulfillmentItemRow } from '../../../lib/fulfillment-items'

/**
 * One item inside a fulfillment group: what it looks like, what it costs and
 * how many units this group holds. The row-level menu is optional — only the
 * unfulfilled group can still edit or remove a line item, since units already
 * handed to a fulfillment are edited through the fulfillment itself.
 */
function ItemRow({
  row,
  onEdit,
  onRemove,
}: {
  row: FulfillmentItemRow
  onEdit?: (row: FulfillmentItemRow) => void
  onRemove?: (row: FulfillmentItemRow) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const hasMenu = !!onEdit || !!onRemove

  return (
    <div className="flex items-center gap-3 py-3">
      {row.thumbnailUrl ? (
        <img
          src={row.thumbnailUrl}
          alt={row.name}
          className="size-10 shrink-0 rounded-lg border object-cover"
        />
      ) : (
        <div className="flex size-10 shrink-0 items-center justify-center rounded-lg border bg-muted">
          <PackageIcon className="size-4 text-muted-foreground" />
        </div>
      )}

      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{row.name}</div>
        {row.optionsText && (
          <div className="truncate text-xs text-muted-foreground">{row.optionsText}</div>
        )}
      </div>

      <div className="shrink-0 text-right text-sm whitespace-nowrap text-muted-foreground">
        {row.displayPrice ? (
          <span>
            {row.displayPrice} × {row.quantity}
          </span>
        ) : (
          <span>× {row.quantity}</span>
        )}
      </div>

      {hasMenu && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon-xs"
              aria-label={t('admin.orders.detail.items_table.item_actions', { name: row.name })}
            >
              <EllipsisVerticalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {onEdit && (
              <DropdownMenuItem onClick={() => onEdit(row)}>
                <PencilIcon className="size-4" />
                {t('admin.orders.detail.dropdown.edit_quantity')}
              </DropdownMenuItem>
            )}
            {onEdit && onRemove && <DropdownMenuSeparator />}
            {onRemove && (
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.remove_item_message'),
                      variant: 'destructive',
                      confirmLabel: t('admin.actions.remove'),
                    })
                  ) {
                    onRemove(row)
                  }
                }}
              >
                <TrashIcon className="size-4" />
                {t('admin.actions.remove')}
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      )}
    </div>
  )
}

/**
 * The item list rendered inside a fulfillment group.
 *
 * @param canRemove decides per row whether removal is offered at all; a row it
 *   rejects shows no remove action rather than one that would do nothing.
 */
export function FulfillmentItemList({
  rows,
  onEdit,
  onRemove,
  canRemove,
}: {
  rows: FulfillmentItemRow[]
  onEdit?: (row: FulfillmentItemRow) => void
  onRemove?: (row: FulfillmentItemRow) => void
  canRemove?: (row: FulfillmentItemRow) => boolean
}) {
  if (rows.length === 0) return null

  return (
    <div className="divide-y">
      {rows.map((row) => (
        <ItemRow
          key={row.key}
          row={row}
          onEdit={onEdit}
          onRemove={onRemove && (!canRemove || canRemove(row)) ? onRemove : undefined}
        />
      ))}
    </div>
  )
}
