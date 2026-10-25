import { PageHeader } from '@spree/dashboard-core'
import { createFileRoute, Outlet } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { TaxProviderSummary } from '../../../../components/spree/taxes/market-tax-providers'
import { TaxesTabs } from '../../../../components/spree/taxes/taxes-tabs'

export const Route = createFileRoute('/_authenticated/$storeId/settings/taxes')({
  component: TaxesLayout,
})

function TaxesLayout() {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        docsPath="settings/taxes"
        title={t('admin.taxes.title')}
        description={t('admin.taxes.description')}
      />
      <TaxProviderSummary />
      <TaxesTabs />
      <Outlet />
    </div>
  )
}
