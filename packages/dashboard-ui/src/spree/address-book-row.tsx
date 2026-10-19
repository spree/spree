import { useTranslation } from 'react-i18next'
import { Badge } from '../ui/badge'
import { Item, ItemActions, ItemContent, ItemTitle } from '../ui/item'
import { AddressBlock, type AddressBlockValue } from './address-block'
import { RowActions } from './row-actions'

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
          <RowActions
            actions={[
              { key: 'edit', onSelect: onEdit },
              {
                key: 'set_default_billing',
                label: t('admin.address_book.set_default_billing'),
                visible: !!onSetDefaultBilling && !address.is_default_billing,
                onSelect: () => onSetDefaultBilling?.(),
              },
              {
                key: 'set_default_shipping',
                label: t('admin.address_book.set_default_shipping'),
                visible: !!onSetDefaultShipping && !address.is_default_shipping,
                onSelect: () => onSetDefaultShipping?.(),
              },
              { key: 'delete', destructive: true, onSelect: onRemove },
            ]}
          />
        </ItemActions>
      )}
    </Item>
  )
}
