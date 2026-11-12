import { PageHeader, ReadRow, SettingsSection } from '@spree/dashboard-core'
import { CardContent, ResourceLayout } from '@spree/dashboard-ui'
import { ReceiptTextIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { SellerTaxIdentifiersCard } from '../components/seller-tax-identifiers-card'
import { useProfile } from '../hooks/use-profile'

/**
 * The seller's tax registrations, then who remits tax on their sales. The
 * second is the marketplace's decision, so it is shown read-only: the seller
 * API refuses to write it.
 */
export function TaxesPage() {
  const { t } = useTranslation()
  const { data: profile } = useProfile()

  return (
    <ResourceLayout
      header={
        <PageHeader title={t('taxes.title')} description={t('taxes.description')} sticky={false} />
      }
      main={
        <>
          <SellerTaxIdentifiersCard />
          <SettingsSection
            title={t('profile.tax_remittance')}
            icon={<ReceiptTextIcon />}
            description={t('profile.operator_managed')}
          >
            <CardContent>
              <ReadRow label={t('profile.tax_remittance')}>{profile?.tax_remittance}</ReadRow>
            </CardContent>
          </SettingsSection>
        </>
      }
    />
  )
}
