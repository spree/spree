import { useTranslation } from 'react-i18next'

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
  country_iso?: string | null
  country_name?: string | null
  phone?: string | null
}

/**
 * Resolves a country name localized to the admin UI language via
 * `Intl.DisplayNames`, falling back to the API-provided name (then the ISO
 * code) when the ISO is missing or the runtime lacks coverage.
 */
function localizedCountryName(
  locale: string,
  iso?: string | null,
  name?: string | null,
): string | null {
  if (iso) {
    try {
      const localized = new Intl.DisplayNames([locale, 'en'], { type: 'region' }).of(iso)
      if (localized) return localized
    } catch {
      // Runtime without Intl.DisplayNames coverage — fall back below.
    }
  }
  return name ?? iso ?? null
}

export function AddressBlock({
  title,
  address,
}: {
  title: string
  address: AddressBlockValue | null | undefined
}) {
  const { t, i18n } = useTranslation()
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
          <div>
            {localizedCountryName(i18n.language, address.country_iso, address.country_name)}
          </div>
          {address.phone && <div>{address.phone}</div>}
        </div>
      ) : (
        <span className="text-sm text-muted-foreground">
          {t('admin.components.address_block.not_provided')}
        </span>
      )}
    </div>
  )
}
