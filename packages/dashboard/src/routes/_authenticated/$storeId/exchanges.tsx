import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import '../../../tables/post-sale'

export const Route = createFileRoute('/_authenticated/$storeId/exchanges')({
  validateSearch: resourceSearchSchema,
  component: ExchangesPage,
})

/**
 * Cross-order view — "what is still waiting on us". Records are opened and
 * actioned from the order they belong to, so this list is read-only.
 */
function ExchangesPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="exchanges"
      queryKey="exchanges"
      queryFn={(params) => adminClient.exchanges.list(params)}
      searchParams={searchParams}
      defaultParams={{ expand: ['order'] }}
      title={t('admin.nav.exchanges')}
    />
  )
}
