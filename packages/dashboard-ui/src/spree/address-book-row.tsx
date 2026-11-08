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
  inheritedFrom,
  onEdit,
  onRemove,
  onSetDefaultBilling,
  onSetDefaultShipping,
}: {
  address: AddressBookEntry
  canEdit?: boolean
  /**
   * Names the book this entry is inherited from. An inherited entry is read
   * only here, and its defaults are its owner's, so neither is shown.
   */
  inheritedFrom?: string | null
  onEdit: () => void
  onRemove: () => void
  /** Omit either to hide that action — a book with one address has no choice. */
  onSetDefaultBilling?: () => void
  onSetDefaultShipping?: () => void
}) {
  const { t } = useTranslation()
  const inherited = inheritedFrom != null
  const isDefaultBilling = !inherited && address.is_default_billing
  const isDefaultShipping = !inherited && address.is_default_shipping

  return (
    <Item variant="outline" className="items-start">
      <ItemContent className="min-w-0">
        {(address.label || inherited || isDefaultBilling || isDefaultShipping) && (
          <ItemTitle className="flex-wrap">
            {address.label}
            {inherited && (
              <Badge variant="secondary">
                {t('admin.address_book.inherited_from', { name: inheritedFrom })}
              </Badge>
            )}
            {isDefaultBilling && (
              <Badge variant="outline">{t('admin.address_book.default_billing')}</Badge>
            )}
            {isDefaultShipping && (
              <Badge variant="outline">{t('admin.address_book.default_shipping')}</Badge>
            )}
          </ItemTitle>
        )}
        <AddressBlock address={address} />
      </ItemContent>

      {canEdit && !inherited && (
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
