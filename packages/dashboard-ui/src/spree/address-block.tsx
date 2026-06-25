import i18n from 'i18next'

/**
 * Structural shape of the fields `<AddressBlock>` renders. Lets the design
 * system stay decoupled from `@spree/admin-sdk`'s `Address` type — any
 * object carrying these fields renders fine.
 */
export interface AddressBlockValue {
  full_name?: string | null
  company?: string | null
  address1?: string | null
  address2?: string | null
  city?: string | null
  state_text?: string | null
  postal_code?: string | null
  country_name?: string | null
  phone?: string | null
}

export function AddressBlock({
  title,
  address,
}: {
  title: string
  address: AddressBlockValue | null | undefined
}) {
  return (
    <div>
      <h6 className="font-semibold text-sm mb-1.5">{title}</h6>
      {address ? (
        <div className="text-sm text-muted-foreground flex flex-col gap-0.5">
          <div>{address.full_name}</div>
          {address.company && <div>{address.company}</div>}
          <div>{address.address1}</div>
          {address.address2 && <div>{address.address2}</div>}
          <div>
            {[address.city, address.state_text, address.postal_code].filter(Boolean).join(', ')}
          </div>
          <div>{address.country_name}</div>
          {address.phone && <div>{address.phone}</div>}
        </div>
      ) : (
        <span className="text-sm text-muted-foreground">
          {i18n.t('admin.components.address_block.not_provided')}
        </span>
      )}
    </div>
  )
}
