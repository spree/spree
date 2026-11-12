import { usePermissions } from '@spree/dashboard-core'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { TAXES_TABS } from '../../../../../components/spree/taxes/taxes-tabs'

export const Route = createFileRoute('/_authenticated/$storeId/settings/taxes/')({
  component: TaxesIndex,
})

/** Opens the first tab the staff member may read. */
function TaxesIndex() {
  const { storeId } = Route.useParams()
  const { permissions } = usePermissions()
  const tab = TAXES_TABS.find((entry) => permissions.can('read', entry.subject)) ?? TAXES_TABS[0]

  return <Navigate to={`/$storeId/settings/taxes/${tab.value}`} params={{ storeId }} replace />
}
