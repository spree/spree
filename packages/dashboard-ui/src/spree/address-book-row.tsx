import { useTranslation } from 'react-i18next'
import { Badge } from '../ui/badge'
import { Button } from '../ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu'
import { Item, ItemActions, ItemContent, ItemTitle } from '../ui/item'
import { AddressBlock, type AddressBlockValue } from './address-block'
import { EllipsisVerticalIcon, PencilIcon, TrashIcon } from './icons'

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
    <Item variant="outline" className="items-start">
      <ItemContent className="min-w-0">
        {(address.label || address.is_default_billing || address.is_default_shipping) && (
          <ItemTitle className="flex-wrap">
            {address.label}
            {address.is_default_billing && (
              <Badge variant="outline">{t('admin.address_book.default_billing')}</Badge>
            )}
            {address.is_default_shipping && (
              <Badge variant="outline">{t('admin.address_book.default_shipping')}</Badge>
            )}
          </ItemTitle>
        )}
        <AddressBlock address={address} />
      </ItemContent>

      {canEdit && (
        <ItemActions>
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
              <DropdownMenuItem variant="destructive" onClick={onRemove}>
                <TrashIcon className="size-4" />
                {t('admin.actions.delete')}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </ItemActions>
      )}
    </Item>
  )
}
