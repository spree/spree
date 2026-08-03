import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import '../../../tables/post-sale'

export const Route = createFileRoute('/_authenticated/$storeId/claims')({
  validateSearch: resourceSearchSchema,
  component: ClaimsPage,
})

/**
 * Cross-order view — "what is still waiting on us". Records are opened and
 * actioned from the order they belong to, so this list is read-only.
 */
function ClaimsPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()

  return (
    <ResourceTable
      tableKey="claims"
      queryKey="claims"
      queryFn={(params) => adminClient.claims.list(params)}
      searchParams={searchParams}
      defaultParams={{ expand: ['order'] }}
      title={t('admin.nav.claims')}
    />
  )
}
