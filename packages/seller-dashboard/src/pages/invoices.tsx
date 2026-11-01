import { PageHeader, type ResourceSearch, ResourceTable } from '@spree/dashboard-core'
import type { Invoice } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/invoices'

/**
 * Invoices on this seller's orders, issued in their name, and the commission
 * invoices the marketplace issued them. Uploaded from each order's page.
 */
export function InvoicesPage({ search }: { search: ResourceSearch }) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('invoices.title')} subtitle={t('invoices.subtitle')} />

      <ResourceTable<Invoice>
        hideHeader
        tableKey="seller-invoices"
        queryKey="seller-invoices-list"
        queryFn={(params) => sellerClient().invoices.list(params)}
        searchParams={search}
      />
    </div>
  )
}
