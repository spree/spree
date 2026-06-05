import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { createFileRoute, Link } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import '@/tables/orders'

export const Route = createFileRoute('/_authenticated/$storeId/orders/drafts')({
  validateSearch: resourceSearchSchema,
  component: DraftOrdersPage,
})

function DraftOrdersPage() {
  const { t } = useTranslation()
  const searchParams = Route.useSearch()
  const { storeId } = Route.useParams()

  return (
    <ResourceTable
      tableKey="orders"
      queryKey="draft-orders"
      queryFn={(params) => adminClient.orders.list(params)}
      searchParams={searchParams}
      defaultParams={{ incomplete: 1, expand: ['channel'] }}
      title={t('admin.pages.orders.drafts_title')}
      actions={
        <Button size="sm" className="h-[2.125rem]" asChild>
          <Link to="/$storeId/orders/new" params={{ storeId }}>
            <PlusIcon className="size-4" />
            {t('admin.pages.orders.new.title')}
          </Link>
        </Button>
      }
    />
  )
}
