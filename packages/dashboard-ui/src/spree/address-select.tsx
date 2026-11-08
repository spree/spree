import { useTranslation } from 'react-i18next'
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from '../ui/select'
import type { AddressBlockValue } from './address-block'

/** One entry a picker may offer, from whichever book it came out of. */
export interface AddressOption extends AddressBlockValue {
  id: string
  label?: string | null
}

/**
 * A set of entries under the name of the book they came from — a customer's
 * own addresses, a company's sites. Groups are rendered in the order given.
 */
export interface AddressOptionGroup {
  key: string
  heading: string
  addresses: AddressOption[]
}

/** The one-line form a picker shows: the entry's own name, then the street. */
export function summarizeAddress(address: AddressOption): string {
  const place = [address.address1, address.city, address.state_text, address.postal_code]
    .filter(Boolean)
    .join(', ')

  const who = address.label || address.company || address.full_name

  return [who, place].filter(Boolean).join(' — ')
}

/**
 * Picks one saved address out of the books a purchase may draw on.
 *
 * Headless: the groups arrive as props, so the same control serves a buyer's
 * own book, a company's sites, and both at once — which is the B2B case, where
 * an order for a company may ship to that company's sites and to the ones it
 * inherits from the companies above it.
 *
 * Base UI resolves the trigger's label from `items`, so the summary line shows
 * instead of the raw prefixed id.
 */
export function AddressSelect({
  id,
  value,
  onValueChange,
  groups,
  placeholder,
  emptyLabel,
  disabled,
}: {
  id?: string
  /** The chosen address id, or `''` for "none picked". */
  value: string
  onValueChange: (value: string) => void
  groups: AddressOptionGroup[]
  placeholder?: string
  /** Offered first so a merchant can take the choice back. */
  emptyLabel?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const none = emptyLabel ?? t('admin.address_select.none')

  const items = [
    { value: '', label: none },
    ...groups.flatMap((group) =>
      group.addresses.map((address) => ({
        value: address.id,
        label: summarizeAddress(address),
      })),
    ),
  ]

  return (
    <Select items={items} value={value} onValueChange={onValueChange} disabled={disabled}>
      <SelectTrigger id={id}>
        <SelectValue placeholder={placeholder ?? none} />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="">{none}</SelectItem>
        {groups
          .filter((group) => group.addresses.length > 0)
          .map((group) => (
            <SelectGroup key={group.key}>
              <SelectLabel>{group.heading}</SelectLabel>
              {group.addresses.map((address) => (
                <SelectItem key={address.id} value={address.id}>
                  {summarizeAddress(address)}
                </SelectItem>
              ))}
            </SelectGroup>
          ))}
      </SelectContent>
    </Select>
  )
}
