import { useDisplayName } from '@spree/dashboard-core'
import { useTranslation } from 'react-i18next'

/**
 * Where a tax rate or exemption certificate applies. Both store the
 * jurisdiction as codes rather than country rows, and both treat "no country"
 * as everywhere rather than as missing data — so a blank pair reads as a
 * worldwide scope, never as a dash.
 */
export function JurisdictionLabel({
  countryCode,
  stateCode,
}: {
  countryCode?: string | null
  stateCode?: string | null
}) {
  const { t } = useTranslation()
  const regionName = useDisplayName('region')

  if (!countryCode) return <>{t('admin.jurisdiction.everywhere')}</>

  const country = regionName(countryCode) ?? countryCode
  return <>{stateCode ? `${country} — ${stateCode}` : country}</>
}
