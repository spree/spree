import { EllipsisVerticalIcon, PencilIcon, TrashIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Badge } from '../ui/badge'
import { Button } from '../ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu'
import { AddressBlock, type AddressBlockValue } from './address-block'

/** What every address book row needs, whoever owns the book. */
export interface AddressBookEntry extends AddressBlockValue {
  id: string
  label?: string | null
  is_default_billing?: boolean | null
  is_default_shipping?: boolean | null
}

/**
 * One row of an address book — the labelled address, which defaults it holds,
 * and the actions on it behind a menu.
 *
 * Shared so a customer's book and a company node's read the same: they are the
 * same thing seen from different owners, and a merchant moving between them
 * should not have to learn two layouts.
 */
export function AddressBookRow({
  address,
  canEdit = true,
  onEdit,
  onRemove,
  onSetDefaultBilling,
  onSetDefaultShipping,
}: {
  address: AddressBookEntry
  canEdit?: boolean
  onEdit: () => void
  onRemove: () => void
  /** Omit either to hide that action — a book with one address has no choice. */
  onSetDefaultBilling?: () => void
  onSetDefaultShipping?: () => void
}) {
  const { t } = useTranslation()

  return (
    <div className="flex items-start justify-between gap-2 rounded-md border p-3">
      <div className="flex min-w-0 flex-col gap-1">
        <span className="flex flex-wrap items-center gap-2">
          {address.label && (
            <span className="font-medium text-foreground text-sm">{address.label}</span>
          )}
          {address.is_default_billing && (
            <Badge variant="outline">{t('admin.address_book.default_billing')}</Badge>
          )}
          {address.is_default_shipping && (
            <Badge variant="outline">{t('admin.address_book.default_shipping')}</Badge>
          )}
        </span>
        <AddressBlock address={address} />
      </div>

      {canEdit && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-xs" className="shrink-0">
              <EllipsisVerticalIcon className="size-4" />
              <span className="sr-only">{t('admin.actions.actions_menu')}</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={onEdit}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
            </DropdownMenuItem>
            {onSetDefaultBilling && !address.is_default_billing && (
              <DropdownMenuItem onClick={onSetDefaultBilling}>
                {t('admin.address_book.set_default_billing')}
              </DropdownMenuItem>
            )}
            {onSetDefaultShipping && !address.is_default_shipping && (
              <DropdownMenuItem onClick={onSetDefaultShipping}>
                {t('admin.address_book.set_default_shipping')}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem
              className="text-destructive focus:text-destructive"
              onClick={onRemove}
            >
              <TrashIcon className="size-4" />
              {t('admin.actions.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      )}
    </div>
  )
}
