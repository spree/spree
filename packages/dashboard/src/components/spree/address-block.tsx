import type { Address } from '@spree/admin-sdk'

export function AddressBlock({
  title,
  address,
}: {
  title: string
  address: Address | null | undefined
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
        <span className="text-sm text-muted-foreground">Not provided</span>
      )}
    </div>
  )
}
