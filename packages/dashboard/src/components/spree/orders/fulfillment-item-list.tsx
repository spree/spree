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
import { type FulfillmentItemRow, isRemovableRow } from '../../../lib/fulfillment-items'

/**
 * One item inside a fulfillment group: what it looks like, what it costs and
 * how many units this group holds. Editing quantity and removing act on the
 * underlying line item, so they are offered wherever that line item shows up.
 */
function ItemRow({
  row,
  onEdit,
  onRemove,
}: {
  row: FulfillmentItemRow
  // Required, like on the exported list: making these optional once let a
  // caller render rows with no menu at all, which silently removed the only
  // route to editing or removing a line item.
  onEdit: (row: FulfillmentItemRow) => void
  onRemove: (row: FulfillmentItemRow) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const hasMenu = !!row.lineItem

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
            {row.lineItem && (
              <DropdownMenuItem onClick={() => onEdit(row)}>
                <PencilIcon className="size-4" />
                {t('admin.orders.detail.dropdown.edit_quantity')}
              </DropdownMenuItem>
            )}
            {isRemovableRow(row) && <DropdownMenuSeparator />}
            {isRemovableRow(row) && (
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
 * Every row that still maps to a line item can have its quantity edited and be
 * removed — those act on the order's line item, which exists whichever group
 * the row happens to be displayed in. Removal is withheld only when the row
 * shows part of a line item whose other units sit elsewhere, since deleting
 * would take those too.
 *
 * @param onEdit opens the quantity dialog for the row's line item
 * @param onRemove deletes the row's line item from the order
 */
export function FulfillmentItemList({
  rows,
  onEdit,
  onRemove,
}: {
  rows: FulfillmentItemRow[]
  onEdit: (row: FulfillmentItemRow) => void
  onRemove: (row: FulfillmentItemRow) => void
}) {
  if (rows.length === 0) return null

  return (
    <div className="divide-y">
      {rows.map((row) => (
        <ItemRow key={row.key} row={row} onEdit={onEdit} onRemove={onRemove} />
      ))}
    </div>
  )
}
